//
//  WidgetShared.swift
//  METAR Weather
//
//  Shared between the main app and the widget extension.
//  IMPORTANT: This file's Target Membership must include BOTH
//  the "METAR Weather" app target AND the widget extension target.
//

import Foundation

/// App Group identifier. Must be enabled as an "App Groups" capability on
/// BOTH the app target and the widget target in Xcode (Signing & Capabilities).
let appGroupID = "group.henril.METAR-Weather"

extension UserDefaults {
    /// Shared store readable by both the app and the widget.
    /// Falls back to `.standard` if the App Group isn't configured yet.
    static let appGroup = UserDefaults(suiteName: appGroupID) ?? .standard
}

/// Lightweight, Codable snapshot of one airfield for the widget.
struct WidgetAirfield: Codable, Identifiable {
    var id: String { icao }
    let icao:             String
    let locationName:     String
    let condition:        String   // FlightCondition rawValue: "VFR" / "MVFR" / "IFR" / "LIFR"
    let temperatureC:     Int
    let windDirectionDeg: Int
    let windSpeedKt:      Int
    let visibilityText:   String   // pre-formatted: "CAVOK", "9999m", "1200m"
    let updatedText:      String   // e.g. "14:20Z"
}

/// Reads/writes the airfield snapshot in the shared App Group container.
enum WidgetStore {
    private static let key = "widgetAirfields"

    static func save(_ airfields: [WidgetAirfield]) {
        guard let data = try? JSONEncoder().encode(airfields) else { return }
        UserDefaults.appGroup.set(data, forKey: key)
    }

    static func load() -> [WidgetAirfield] {
        guard let data = UserDefaults.appGroup.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WidgetAirfield].self, from: data) else { return [] }
        return decoded
    }
}

/// Self-contained METAR fetch + minimal parse used by the widget so it can
/// auto-refresh on its own timeline even when the app isn't running. Only the
/// fields the widget shows are parsed; airport names are preserved from the
/// previous snapshot (they don't change between observations).
enum WidgetWeatherLoader {

    /// Fetch fresh METARs for `icaos` and return updated snapshots, keeping the
    /// previous location names. On any failure the previous entries are returned.
    static func refresh(icaos: [String], previous: [WidgetAirfield]) async -> [WidgetAirfield] {
        guard !icaos.isEmpty else { return previous }

        let idList = icaos.joined(separator: ",")
        guard let url = URL(string: "https://aviationweather.gov/api/data/metar?ids=\(idList)&format=raw") else {
            return previous
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let text = String(data: data, encoding: .utf8) else {
            return previous
        }

        // Map each ICAO to its raw report line.
        var rawMap: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "METAR ", with: "")
                .replacingOccurrences(of: "SPECI ", with: "")
            if let first = clean.components(separatedBy: .whitespaces).first,
               icaos.contains(first), rawMap[first] == nil {
                rawMap[first] = clean
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let updated = formatter.string(from: Date())

        return icaos.map { icao in
            let prev = previous.first { $0.icao == icao }
            guard let raw = rawMap[icao] else {
                return prev ?? WidgetAirfield(icao: icao, locationName: icao, condition: "VFR",
                                              temperatureC: 0, windDirectionDeg: 0, windSpeedKt: 0,
                                              visibilityText: "––", updatedText: updated)
            }
            let p = WidgetMetar.parse(raw)
            return WidgetAirfield(
                icao: icao,
                locationName: prev?.locationName ?? icao,
                condition: p.condition,
                temperatureC: p.temperatureC,
                windDirectionDeg: p.windDirectionDeg,
                windSpeedKt: p.windSpeedKt,
                visibilityText: p.visibilityText,
                updatedText: updated
            )
        }
    }
}

/// Minimal METAR extraction for the widget (temp, wind, visibility, condition).
enum WidgetMetar {
    struct Result {
        let temperatureC: Int
        let windDirectionDeg: Int
        let windSpeedKt: Int
        let visibilityText: String
        let condition: String
    }

    static func parse(_ raw: String) -> Result {
        let temp = firstMatch("\\b(M?\\d{2})/(M?\\d{2})?\\b", in: raw, group: 1).map { s -> Int in
            s.hasPrefix("M") ? -(Int(s.dropFirst()) ?? 0) : (Int(s) ?? 0)
        } ?? 0

        var windDir = 0, windSpeed = 0
        if let groups = firstMatchGroups("\\b(\\d{3}|VRB)(\\d{2,3})(?:G\\d{2,3})?KT\\b", in: raw) {
            windDir   = groups[1] == "VRB" ? 0 : (Int(groups[1]) ?? 0)
            windSpeed = Int(groups[2]) ?? 0
        }

        let cavok = raw.contains("CAVOK")
        var visMeters = 9999
        if !cavok, let v = firstMatch("\\s(\\d{4})\\s", in: raw, group: 1) { visMeters = Int(v) ?? 9999 }

        let visText = cavok ? "CAVOK" : (visMeters >= 9999 ? "9999m" : "\(visMeters)m")

        let condition: String
        if cavok { condition = "VFR" }
        else if visMeters < 1500 { condition = "LIFR" }
        else if visMeters < 3000 { condition = "IFR" }
        else if visMeters < 5000 { condition = "MVFR" }
        else { condition = "VFR" }

        return Result(temperatureC: temp, windDirectionDeg: windDir,
                      windSpeedKt: windSpeed, visibilityText: visText, condition: condition)
    }

    private static func firstMatch(_ pattern: String, in text: String, group: Int) -> String? {
        firstMatchGroups(pattern, in: text).flatMap { $0.indices.contains(group) ? $0[group] : nil }
    }

    private static func firstMatchGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let ns = text as NSString
        return (0..<m.numberOfRanges).map { idx in
            let r = m.range(at: idx)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
}

/// Unit conversion shared by the app and the widget. Reads the user's unit
/// preferences from the shared App Group store so the widget matches the app.
enum WidgetUnits {
    static func temperature(_ celsius: Int) -> String {
        let raw = UserDefaults.appGroup.string(forKey: "temperatureUnit") ?? "C"
        if raw == "F" { return "\(Int(Double(celsius) * 9 / 5 + 32))°F" }
        return "\(celsius)°C"
    }

    static func windSpeed(_ knots: Int) -> String {
        let raw = UserDefaults.appGroup.string(forKey: "windUnit") ?? "kt"
        switch raw {
        case "ms":  return String(format: "%.1f m/s", Double(knots) * 0.514444)
        case "mph": return String(format: "%.0f mph", Double(knots) * 1.15078)
        default:    return String(format: "%02d kt", knots)
        }
    }
}
