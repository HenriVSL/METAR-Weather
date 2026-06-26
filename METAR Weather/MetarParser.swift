//
//  MetarParser.swift
//  METAR Weather
//
//  Created by Henri Lavikainen on 24.6.2026.
//

import Foundation

// MARK: - Parsed METAR model types

struct ParsedMetar {
    var stationId:         String        = ""
    var observationTime:   String        = ""
    var isAuto:            Bool          = false
    var isCorrected:       Bool          = false
    var wind:              ParsedWind?   = nil
    var variableWindRange: String?       = nil
    var isCavok:           Bool          = false
    var visibility:        String        = ""
    var rvr:               [String]      = []
    var weather:           [String]      = []
    var clouds:            [ParsedCloud] = []
    var temperature:       String        = ""
    var dewPoint:          String        = ""
    var qnh:               String        = ""
    var trend:             String        = ""
}

struct ParsedWind {
    let direction: String   // "260°", "Variable", or "Calm"
    let speed:     String   // "4 kt", or "" when calm
    let gust:      String?  // "30 kt" if present
}

struct ParsedCloud: Identifiable {
    let id        = UUID()
    let coverage:  String   // "Few (1–2 oktas)", etc.
    let height:    String   // "1200 ft AGL", or "" for clear sky
    let cloudType: String?  // "Cumulonimbus", "Towering Cumulus"
}

// MARK: - MetarParser

struct MetarParser {

    // MARK: Quick parse — produces AirfieldData for card display

    static func parse(rawMetar: String, icao: String, locationName: String, frequencies: [AirportFrequency]) -> AirfieldData {
        let temp      = extractTemperature(from: rawMetar) ?? 0
        let wind      = extractWind(from: rawMetar)
        let vis       = extractVisibility(from: rawMetar) ?? 9999
        let condition = determineFlightCondition(visibilityMeters: vis, rawMetar: rawMetar)

        return AirfieldData(
            icao: icao,
            locationName: locationName,
            flightCondition: condition,
            temperatureC: temp,
            windDirectionDeg: wind.dir,
            windSpeedKt: wind.speed,
            visibilityMeters: vis,
            rawMetar: rawMetar,
            frequencies: frequencies
        )
    }

    // MARK: Full token-by-token parse — produces ParsedMetar for the expanded card view

    static func parseFull(rawMetar: String) -> ParsedMetar {
        var r = ParsedMetar()

        let cleaned = rawMetar
            .replacingOccurrences(of: "^METAR ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^SPECI ", with: "", options: .regularExpression)

        let tokens = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var i = 0

        // Station ID
        if i < tokens.count, tokens[i].range(of: "^[A-Z]{4}$", options: .regularExpression) != nil {
            r.stationId = tokens[i]; i += 1
        }

        // Date/time: DDHHMMz
        if i < tokens.count, tokens[i].range(of: "^\\d{6}Z$", options: .regularExpression) != nil {
            let dt   = tokens[i]; i += 1
            let day  = String(dt.prefix(2))
            let hour = String(dt.dropFirst(2).prefix(2))
            let min  = String(dt.dropFirst(4).prefix(2))
            r.observationTime = "Day \(day) · \(hour):\(min) UTC"
        }

        // AUTO / COR flags
        while i < tokens.count, ["AUTO", "COR", "NIL"].contains(tokens[i]) {
            if tokens[i] == "AUTO" { r.isAuto = true }
            if tokens[i] == "COR"  { r.isCorrected = true }
            i += 1
        }

        // Wind: (DDD|VRB)(SS|SSS)(GGGG)?KT
        if i < tokens.count,
           tokens[i].range(of: "^(\\d{3}|VRB)\\d{2,3}(G\\d{2,3})?KT$", options: .regularExpression) != nil {
            let wt = tokens[i]; i += 1
            let m  = performRegex(pattern: "^(\\d{3}|VRB)(\\d{2,3})(?:G(\\d{2,3}))?KT$", on: wt)
            if let first = m.first, first.count > 2 {
                let dirStr   = first[1]
                let speedVal = Int(first[2]) ?? 0
                let gustRaw  = first.count > 3 ? first[3] : ""
                let direction: String
                let speed: String
                if speedVal == 0 && dirStr == "000" {
                    direction = "Calm"; speed = ""
                } else if dirStr == "VRB" {
                    direction = "Variable"; speed = "\(speedVal) kt"
                } else {
                    direction = "\(Int(dirStr) ?? 0)°"; speed = "\(speedVal) kt"
                }
                let gust = gustRaw.isEmpty ? nil : "\(Int(gustRaw) ?? 0) kt"
                r.wind = ParsedWind(direction: direction, speed: speed, gust: gust)
            }
        }

        // Variable wind direction: DDDVDDD
        if i < tokens.count,
           tokens[i].range(of: "^\\d{3}V\\d{3}$", options: .regularExpression) != nil {
            let parts = tokens[i].components(separatedBy: "V"); i += 1
            if parts.count == 2 { r.variableWindRange = "\(parts[0])° to \(parts[1])°" }
        }

        // CAVOK
        if i < tokens.count, tokens[i] == "CAVOK" {
            r.isCavok    = true
            r.visibility = "CAVOK (≥10 km, no cloud below 5000 ft, no CB)"
            i += 1
        } else {
            // Visibility
            if i < tokens.count {
                let vt = tokens[i]
                if vt.range(of: "^\\d{4}$", options: .regularExpression) != nil {
                    i += 1
                    let m    = Int(vt) ?? 0
                    r.visibility = m >= 9999 ? "10 km or more"
                                 : m >= 1000 ? String(format: "%.1f km", Double(m) / 1000)
                                 : "\(m) m"
                } else if vt.range(of: "^\\d+SM$", options: .regularExpression) != nil {
                    r.visibility = vt.replacingOccurrences(of: "SM", with: " SM"); i += 1
                }
            }
            // Skip directional visibility suffix e.g. "0800NE"
            if i < tokens.count,
               tokens[i].range(of: "^\\d{4}[NSEW]{1,2}$", options: .regularExpression) != nil {
                i += 1
            }
            // RVR
            while i < tokens.count,
                  tokens[i].range(of: "^R\\d{2}[LRC]?/", options: .regularExpression) != nil {
                r.rvr.append(parseRVR(tokens[i])); i += 1
            }
            // Present weather
            while i < tokens.count, isWeatherToken(tokens[i]) {
                r.weather.append(decodeWeather(tokens[i])); i += 1
            }
            // Clouds
            while i < tokens.count, isCloudToken(tokens[i]) {
                if let cloud = parseCloud(tokens[i]) { r.clouds.append(cloud) }
                i += 1
            }
        }

        // Temperature / dew point: TT/TdTd
        if i < tokens.count,
           tokens[i].range(of: "^M?\\d{2}/M?\\d{2}$", options: .regularExpression) != nil {
            let parts = tokens[i].components(separatedBy: "/"); i += 1
            if parts.count == 2 {
                r.temperature = formatTemp(parts[0])
                r.dewPoint    = formatTemp(parts[1])
            }
        }

        // QNH: Q1014 (hPa) or A2992 (inHg × 100)
        if i < tokens.count,
           tokens[i].range(of: "^[QA]\\d{4}$", options: .regularExpression) != nil {
            let qnh = tokens[i]; i += 1
            if qnh.hasPrefix("Q") {
                r.qnh = "\(qnh.dropFirst()) hPa"
            } else {
                let inHg = (Double(String(qnh.dropFirst())) ?? 0) / 100.0
                r.qnh = String(format: "%.2f inHg", inHg)
            }
        }

        // Trend: everything remaining
        if i < tokens.count {
            r.trend = decodeTrend(tokens[i...].joined(separator: " "))
        }

        return r
    }

    // MARK: - Private helpers

    private static func isWeatherToken(_ t: String) -> Bool {
        let pattern = "^(-|\\+|VC)?(MI|PR|BC|DR|BL|SH|TS|FZ)?(DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$"
        return performRegex(pattern: pattern, on: t).first != nil
    }

    private static func isCloudToken(_ t: String) -> Bool {
        if ["SKC", "CLR", "NSC", "NCD"].contains(t) { return true }
        if t.range(of: "^(FEW|SCT|BKN|OVC)\\d{3}(CB|TCU)?$", options: .regularExpression) != nil { return true }
        return t.range(of: "^VV\\d{3}$", options: .regularExpression) != nil
    }

    private static func parseRVR(_ t: String) -> String {
        let m = performRegex(pattern: "^R(\\d{2}[LRC]?)/([MP]?)(\\d{4})([UDN]?)$", on: t)
        guard let first = m.first, first.count > 3 else { return t }
        let mod = first[2] == "M" ? "<" : first[2] == "P" ? ">" : ""
        let val = Int(first[3]) ?? 0
        let trend: String
        switch first.count > 4 ? first[4] : "" {
        case "U": trend = ", improving"
        case "D": trend = ", deteriorating"
        case "N": trend = ", no change"
        default:  trend = ""
        }
        return "Rwy \(first[1]): \(mod)\(val) m\(trend)"
    }

    private static func decodeWeather(_ t: String) -> String {
        let descriptors: [String: String] = [
            "MI": "shallow", "PR": "partial",  "BC": "patches of",
            "DR": "drifting", "BL": "blowing", "SH": "shower",
            "TS": "thunderstorm with", "FZ": "freezing"
        ]
        let phenomena: [String: String] = [
            "DZ": "drizzle",      "RA": "rain",          "SN": "snow",
            "SG": "snow grains",  "IC": "ice crystals",  "PL": "ice pellets",
            "GR": "hail",         "GS": "small hail",    "UP": "unknown precipitation",
            "BR": "mist",         "FG": "fog",            "FU": "smoke",
            "VA": "volcanic ash", "DU": "dust",           "SA": "sand",
            "HZ": "haze",         "PY": "spray",          "PO": "dust/sand whirls",
            "SQ": "squalls",      "FC": "funnel cloud",   "SS": "sandstorm",
            "DS": "duststorm"
        ]
        var rem = t
        var parts: [String] = []
        if rem.hasPrefix("-")       { parts.append("Light");        rem = String(rem.dropFirst()) }
        else if rem.hasPrefix("+")  { parts.append("Heavy");        rem = String(rem.dropFirst()) }
        else if rem.hasPrefix("VC") { parts.append("In vicinity:"); rem = String(rem.dropFirst(2)) }
        for key in ["MI", "PR", "BC", "DR", "BL", "SH", "TS", "FZ"] {
            if rem.hasPrefix(key) {
                if let d = descriptors[key] { parts.append(d) }
                rem = String(rem.dropFirst(2)); break
            }
        }
        var phen: [String] = []
        while rem.count >= 2 {
            let code = String(rem.prefix(2))
            if let p = phenomena[code] { phen.append(p); rem = String(rem.dropFirst(2)) } else { break }
        }
        if !phen.isEmpty { parts.append(phen.joined(separator: " and ")) }
        let result = parts.joined(separator: " ")
        guard !result.isEmpty else { return t }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private static func parseCloud(_ t: String) -> ParsedCloud? {
        let coverageMap: [String: String] = [
            "FEW": "Few (1–2 oktas)",    "SCT": "Scattered (3–4 oktas)",
            "BKN": "Broken (5–7 oktas)", "OVC": "Overcast (8 oktas)"
        ]
        if ["SKC", "CLR", "NSC", "NCD"].contains(t) {
            return ParsedCloud(coverage: "Clear sky", height: "", cloudType: nil)
        }
        if t.hasPrefix("VV"), let h = Int(t.dropFirst(2)) {
            return ParsedCloud(coverage: "Vertical visibility", height: "\(h * 100) ft AGL", cloudType: nil)
        }
        let m = performRegex(pattern: "^(FEW|SCT|BKN|OVC)(\\d{3})(CB|TCU)?$", on: t)
        guard let first = m.first, first.count > 2 else { return nil }
        let coverage  = coverageMap[first[1]] ?? first[1]
        let heightFt  = (Int(first[2]) ?? 0) * 100
        let typeMap   = ["CB": "Cumulonimbus", "TCU": "Towering Cumulus"]
        let cloudType = (first.count > 3 && !first[3].isEmpty) ? typeMap[first[3]] : nil
        return ParsedCloud(coverage: coverage, height: "\(heightFt) ft AGL", cloudType: cloudType)
    }

    private static func formatTemp(_ raw: String) -> String {
        if raw.hasPrefix("M"), let v = Int(raw.dropFirst()) { return "-\(v)°C" }
        if let v = Int(raw) { return "\(v)°C" }
        return raw
    }

    private static func decodeTrend(_ raw: String) -> String {
        if raw.hasPrefix("NOSIG") { return "No significant change" }
        if raw.hasPrefix("TEMPO") {
            let rest = raw.dropFirst(5).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? "Temporary changes" : "Temporary: \(rest)"
        }
        if raw.hasPrefix("BECMG") {
            let rest = raw.dropFirst(5).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? "Becoming" : "Becoming: \(rest)"
        }
        return raw
    }

    // MARK: - Quick-parse helpers (used by parse())

    private static func extractTemperature(from text: String) -> Int? {
        let pattern = "\\b(M?\\d{2})/(M?\\d{2})?\\b"
        guard let match = performRegex(pattern: pattern, on: text).first, match.count > 1 else { return nil }
        let tempStr = match[1]
        if tempStr.hasPrefix("M") {
            return Int(tempStr.dropFirst()).map { -$0 }
        }
        return Int(tempStr)
    }

    private static func extractWind(from text: String) -> (dir: Int, speed: Int) {
        let pattern = "\\b(\\d{3}|VRB)(\\d{2,3})(?:G\\d{2,3})?KT\\b"
        guard let match = performRegex(pattern: pattern, on: text).first, match.count > 2 else { return (0, 0) }
        let dir   = match[1] == "VRB" ? 0 : (Int(match[1]) ?? 0)
        let speed = Int(match[2]) ?? 0
        return (dir, speed)
    }

    private static func extractVisibility(from text: String) -> Int? {
        let pattern = "\\s(\\d{4})\\s"
        guard let match = performRegex(pattern: pattern, on: text).first, match.count > 1 else {
            return text.contains(" CAVOK ") ? 9999 : nil
        }
        return Int(match[1])
    }

    private static func determineFlightCondition(visibilityMeters vis: Int, rawMetar: String) -> FlightCondition {
        if vis < 1500 { return .lifr }
        if vis < 3000 { return .ifr }
        if vis < 5000 { return .mvfr }
        return .vfr
    }

    // MARK: - Regex helper

    static func performRegex(pattern: String, on text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = text as NSString
        let results  = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        return results.map { match in
            (0..<match.numberOfRanges).map {
                let range = match.range(at: $0)
                guard range.location != NSNotFound else { return "" }
                return nsString.substring(with: range)
            }
        }
    }
}
