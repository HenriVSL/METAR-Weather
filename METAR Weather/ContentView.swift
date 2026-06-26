import SwiftUI

// MARK: - Data Models

enum FlightCondition: String {
    case vfr  = "VFR"
    case mvfr = "MVFR"
    case ifr  = "IFR"
    case lifr = "LIFR"

    // Badge fill colour (solid background on the pill)
    var badgeColor: Color {
        switch self {
        case .vfr:  return Color(red: 0.13, green: 0.58, blue: 0.22)
        case .mvfr: return Color(red: 0.72, green: 0.44, blue: 0.04)
        case .ifr:  return Color(red: 0.68, green: 0.12, blue: 0.12)
        case .lifr: return Color(red: 0.50, green: 0.06, blue: 0.62)
        }
    }

    // Colour used for the metric values (vis always, wind for IFR/LIFR)
    var primaryMetricColor: Color {
        switch self {
        case .vfr:  return Color(red: 0.18, green: 0.88, blue: 0.42)
        case .mvfr: return Color(red: 1.00, green: 0.63, blue: 0.08)
        case .ifr:  return Color(red: 1.00, green: 0.25, blue: 0.25)
        case .lifr: return Color(red: 0.82, green: 0.18, blue: 1.00)
        }
    }

    // Wind column uses amber for IFR (notable wind + low vis), white otherwise
    var windMetricColor: Color {
        switch self {
        case .ifr, .lifr: return Color(red: 1.00, green: 0.63, blue: 0.08)
        default:           return .white
        }
    }

    // SF Symbol name for the badge icon
    var badgeIcon: String {
        switch self {
        case .vfr:  return "checkmark.circle.fill"
        case .mvfr: return "info.circle.fill"
        case .ifr:  return "exclamationmark.triangle.fill"
        case .lifr: return "xmark.octagon.fill"
        }
    }
}

struct AirportFrequency: Identifiable {
    let id = UUID()
    let type: String
    let freq: String
}

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
    let direction: String
    let speed:     String
    let gust:      String?
}

struct ParsedCloud: Identifiable {
    let id        = UUID()
    let coverage:  String
    let height:    String
    let cloudType: String?
}

struct AirfieldData: Identifiable {
    let id = UUID()
    let icao:             String
    let locationName:     String
    let flightCondition:  FlightCondition
    let temperatureC:     Int
    let windDirectionDeg: Int
    let windSpeedKt:      Int
    let visibilityMeters: Int
    let rawMetar:         String
    let frequencies:      [AirportFrequency]

    // Formatted display strings
    var displayTemp: String { "\(temperatureC)" }
    var displayWindDir: String { "\(windDirectionDeg)°" }
    var displayWindSpeed: String { String(format: "%02dkt", windSpeedKt) }
    var displayVis: String {
        if rawMetar.contains("CAVOK") { return "CAVOK" }
        return visibilityMeters >= 9999 ? "9999m" : "\(visibilityMeters)m"
    }
}

// MARK: - Static Sample Data

extension AirfieldData {
    static let samples: [AirfieldData] = [
        AirfieldData(
            icao: "EFHA",
            locationName: "Halli Airport",
            flightCondition: .ifr,
            temperatureC: -3,
            windDirectionDeg: 220,
            windSpeedKt: 18,
            visibilityMeters: 1200,
            rawMetar: "EFHA 141420Z 22018KT 1200 BR OVC004 M03/M04 Q1012",
            frequencies: [AirportFrequency(type: "TWR", freq: "119.7"), AirportFrequency(type: "ATIS", freq: "135.5")]
        ),
        AirfieldData(
            icao: "EFTP",
            locationName: "Tampere/Pirkkala Airport",
            flightCondition: .mvfr,
            temperatureC: 1,
            windDirectionDeg: 180,
            windSpeedKt: 9,
            visibilityMeters: 6000,
            rawMetar: "EFTP 141420Z 18009KT 6000 BKN012 01/M01 Q1014",
            frequencies: [AirportFrequency(type: "ATIS", freq: "133.55"), AirportFrequency(type: "TWR", freq: "118.7")]
        ),
        AirfieldData(
            icao: "EFJY",
            locationName: "Jyväskylä Airport",
            flightCondition: .vfr,
            temperatureC: -1,
            windDirectionDeg: 270,
            windSpeedKt: 5,
            visibilityMeters: 9999,
            rawMetar: "EFJY 141420Z 27005KT 9999 FEW035 M01/M05 Q1015",
            frequencies: []
        )
    ]
}

// MARK: - Reusable Subviews

/// Small coloured pill showing the flight-condition category.
struct FlightConditionBadge: View {
    let condition: FlightCondition

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: condition.badgeIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(condition.rawValue)
                .font(.system(size: 12, weight: .bold))
                .kerning(0.4)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(condition.badgeColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// One column of the three-column metric grid.
struct MetricColumn: View {
    let iconName:     String
    let label:        String
    let primaryValue: String
    let primarySuffix: String?
    let secondValue:  String?
    let valueColor:   Color

    init(
        iconName:      String,
        label:         String,
        primaryValue:  String,
        primarySuffix: String? = nil,
        secondValue:   String? = nil,
        valueColor:    Color   = .white
    ) {
        self.iconName      = iconName
        self.label         = label
        self.primaryValue  = primaryValue
        self.primarySuffix = primarySuffix
        self.secondValue   = secondValue
        self.valueColor    = valueColor
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 17))
                .foregroundColor(Color(white: 0.52))

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 1) {
                    Text(primaryValue)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(valueColor)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if let suffix = primarySuffix {
                        Text(suffix)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(valueColor)
                            .padding(.top, 2)
                    }
                }

                if let second = secondValue {
                    Text(second)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(valueColor)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .kerning(1.8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Thin vertical rule between metric columns.
private struct ColumnDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 0.20))
            .frame(width: 1, height: 76)
    }
}

/// Three-column grid: TEMP | WIND | VIS.
struct MetricGridView: View {
    let airfield: AirfieldData

    var body: some View {
        HStack(spacing: 0) {
            MetricColumn(
                iconName:      "thermometer.medium",
                label:         "TEMP",
                primaryValue:  airfield.displayTemp,
                primarySuffix: "°"
            )

            ColumnDivider()

            MetricColumn(
                iconName:     "wind",
                label:        "WIND",
                primaryValue: airfield.displayWindDir,
                secondValue:  airfield.displayWindSpeed,
                valueColor:   airfield.flightCondition.windMetricColor
            )

            ColumnDivider()

            MetricColumn(
                iconName:     "eye",
                label:        "VIS",
                primaryValue: airfield.displayVis,
                valueColor:   Color(red: 0.18, green: 0.88, blue: 0.42)
            )
        }
        .padding(.vertical, 14)
    }
}

// MARK: - AirfieldCardView

/// Full card for a single airfield station.
struct AirfieldCardView: View {
    let airfield: AirfieldData
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Text(airfield.icao)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.42))
                    }

                    Spacer()

                    let validFreqs = airfield.frequencies.filter { $0.freq.contains(where: \.isNumber) }
                    if !validFreqs.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(validFreqs) { f in
                                Text("\(f.type) \(f.freq)")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.48))
                            }
                        }
                    }
                }

                Text(airfield.locationName)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.48))

                FlightConditionBadge(condition: airfield.flightCondition)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // ── Metric grid ──────────────────────────────────────────────────
            MetricGridView(airfield: airfield)
                .padding(.horizontal, 6)

            // ── Separator ────────────────────────────────────────────────────
            Rectangle()
                .fill(Color(white: 0.17))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // ── Raw METAR (tappable) + expandable decode ─────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
                }) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(airfield.rawMetar)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.38))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.32))
                            .padding(.top, 1)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    MetarExpandedView(rawMetar: airfield.rawMetar)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.105))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Full METAR parser (extension on MetarParser, lives here alongside the model types)

extension MetarParser {

    static func parseFull(rawMetar: String) -> ParsedMetar {
        var r = ParsedMetar()

        let cleaned = rawMetar
            .replacingOccurrences(of: "^METAR ", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^SPECI ", with: "", options: .regularExpression)

        let tokens = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var i = 0

        if i < tokens.count, tokens[i].range(of: "^[A-Z]{4}$", options: .regularExpression) != nil {
            r.stationId = tokens[i]; i += 1
        }

        if i < tokens.count, tokens[i].range(of: "^\\d{6}Z$", options: .regularExpression) != nil {
            let dt = tokens[i]; i += 1
            let day  = String(dt.prefix(2))
            let hour = String(dt.dropFirst(2).prefix(2))
            let min  = String(dt.dropFirst(4).prefix(2))
            r.observationTime = "Day \(day) · \(hour):\(min) UTC"
        }

        while i < tokens.count, ["AUTO", "COR", "NIL"].contains(tokens[i]) {
            if tokens[i] == "AUTO" { r.isAuto = true }
            if tokens[i] == "COR"  { r.isCorrected = true }
            i += 1
        }

        if i < tokens.count,
           tokens[i].range(of: "^(\\d{3}|VRB)\\d{2,3}(G\\d{2,3})?KT$", options: .regularExpression) != nil {
            let wt = tokens[i]; i += 1
            let m = performRegex(pattern: "^(\\d{3}|VRB)(\\d{2,3})(?:G(\\d{2,3}))?KT$", on: wt)
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

        if i < tokens.count,
           tokens[i].range(of: "^\\d{3}V\\d{3}$", options: .regularExpression) != nil {
            let parts = tokens[i].components(separatedBy: "V"); i += 1
            if parts.count == 2 { r.variableWindRange = "\(parts[0])° to \(parts[1])°" }
        }

        if i < tokens.count, tokens[i] == "CAVOK" {
            r.isCavok = true
            r.visibility = "CAVOK (≥10 km, no cloud below 5000 ft, no CB)"
            i += 1
        } else {
            if i < tokens.count {
                let vt = tokens[i]
                if vt.range(of: "^\\d{4}$", options: .regularExpression) != nil {
                    i += 1
                    let m = Int(vt) ?? 0
                    r.visibility = m >= 9999 ? "10 km or more"
                                 : m >= 1000 ? String(format: "%.1f km", Double(m) / 1000)
                                 : "\(m) m"
                } else if vt.range(of: "^\\d+SM$", options: .regularExpression) != nil {
                    r.visibility = vt.replacingOccurrences(of: "SM", with: " SM"); i += 1
                }
            }
            if i < tokens.count,
               tokens[i].range(of: "^\\d{4}[NSEW]{1,2}$", options: .regularExpression) != nil {
                i += 1
            }
            while i < tokens.count,
                  tokens[i].range(of: "^R\\d{2}[LRC]?/", options: .regularExpression) != nil {
                r.rvr.append(parseRVR(tokens[i])); i += 1
            }
            while i < tokens.count, isWeatherToken(tokens[i]) {
                r.weather.append(decodeWeather(tokens[i])); i += 1
            }
            while i < tokens.count, isCloudToken(tokens[i]) {
                if let cloud = parseCloud(tokens[i]) { r.clouds.append(cloud) }
                i += 1
            }
        }

        if i < tokens.count,
           tokens[i].range(of: "^M?\\d{2}/M?\\d{2}$", options: .regularExpression) != nil {
            let parts = tokens[i].components(separatedBy: "/"); i += 1
            if parts.count == 2 {
                r.temperature = formatTemp(parts[0])
                r.dewPoint    = formatTemp(parts[1])
            }
        }

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

        if i < tokens.count {
            r.trend = decodeTrend(tokens[i...].joined(separator: " "))
        }

        return r
    }

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
            "MI": "shallow", "PR": "partial", "BC": "patches of",
            "DR": "drifting", "BL": "blowing", "SH": "shower",
            "TS": "thunderstorm with", "FZ": "freezing"
        ]
        let phenomena: [String: String] = [
            "DZ": "drizzle",     "RA": "rain",         "SN": "snow",
            "SG": "snow grains", "IC": "ice crystals",  "PL": "ice pellets",
            "GR": "hail",        "GS": "small hail",   "UP": "unknown precipitation",
            "BR": "mist",        "FG": "fog",           "FU": "smoke",
            "VA": "volcanic ash","DU": "dust",           "SA": "sand",
            "HZ": "haze",        "PY": "spray",         "PO": "dust/sand whirls",
            "SQ": "squalls",     "FC": "funnel cloud",  "SS": "sandstorm",
            "DS": "duststorm"
        ]
        var rem = t
        var parts: [String] = []
        if rem.hasPrefix("-")       { parts.append("Light");        rem = String(rem.dropFirst()) }
        else if rem.hasPrefix("+")  { parts.append("Heavy");        rem = String(rem.dropFirst()) }
        else if rem.hasPrefix("VC") { parts.append("In vicinity:"); rem = String(rem.dropFirst(2)) }
        for key in ["MI","PR","BC","DR","BL","SH","TS","FZ"] {
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
            "FEW": "Few (1–2 oktas)",   "SCT": "Scattered (3–4 oktas)",
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
}

// MARK: - METAR Expanded Decode

private struct MetarRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.35))
                .kerning(1.1)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.60))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct MetarExpandedView: View {
    let rawMetar: String
    private var p: ParsedMetar { MetarParser.parseFull(rawMetar: rawMetar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Rectangle()
                .fill(Color(white: 0.17))
                .frame(height: 1)
                .padding(.bottom, 2)

            if !p.observationTime.isEmpty {
                MetarRow(label: "OBSERVED", value: p.observationTime)
            }
            if p.isAuto      { MetarRow(label: "TYPE", value: "Automated observation") }
            if p.isCorrected { MetarRow(label: "TYPE", value: "Corrected report") }

            if let wind = p.wind {
                MetarRow(label: "WIND", value: windString(wind))
            }

            if !p.visibility.isEmpty { MetarRow(label: "VISIBILITY", value: p.visibility) }

            ForEach(p.rvr, id: \.self)     { MetarRow(label: "RVR",     value: $0) }
            ForEach(p.weather, id: \.self) { MetarRow(label: "WEATHER", value: $0) }

            if p.isCavok {
                MetarRow(label: "CLOUDS", value: "No cloud below 5000 ft, no CB")
            } else {
                ForEach(p.clouds) { cloud in
                    MetarRow(label: "CLOUDS", value: cloudString(cloud))
                }
            }

            if !p.temperature.isEmpty { MetarRow(label: "TEMP",      value: p.temperature) }
            if !p.dewPoint.isEmpty    { MetarRow(label: "DEW POINT", value: p.dewPoint) }
            if !p.qnh.isEmpty         { MetarRow(label: "QNH",       value: p.qnh) }
            if !p.trend.isEmpty       { MetarRow(label: "TREND",     value: p.trend) }
        }
    }

    private func windString(_ wind: ParsedWind) -> String {
        if wind.direction == "Calm" { return "Calm" }
        var s = "\(wind.direction) at \(wind.speed)"
        if let g = wind.gust { s += ", gusting \(g)" }
        if let vr = p.variableWindRange { s += " (variable \(vr))" }
        return s
    }

    private func cloudString(_ cloud: ParsedCloud) -> String {
        if cloud.coverage == "Clear sky" { return "Clear sky" }
        if let ct = cloud.cloudType { return "\(cloud.coverage) at \(cloud.height) (\(ct))" }
        return "\(cloud.coverage) at \(cloud.height)"
    }
}

// MARK: - Top Bar

/// "METAR BRIEF / Local Weather" title bar with timestamp and refresh.
struct TopBarView: View {
    @ObservedObject var viewModel: WeatherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("METAR WEATHER")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.44))
                        .kerning(2.0)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isRefreshing ? .yellow : .green)
                    Text(viewModel.timeZ)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack {
                Label {
                    Text(viewModel.lastUpdated)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.44))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.44))
                }

                Spacer()

                // Execute the refresh
                Button(action: {
                    Task { await viewModel.refreshWeather() }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            // Spin icon while refreshing
                            .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                            .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                        Text("Refresh")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                .disabled(viewModel.isRefreshing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Airfields Screen

struct AirfieldsView: View {
    @ObservedObject var viewModel: WeatherViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Pass viewModel to TopBar
                    TopBarView(viewModel: viewModel)

                    VStack(spacing: 12) {
                        // Loop through live data
                        ForEach(viewModel.airfields) { airfield in
                            AirfieldCardView(airfield: airfield)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var inputIcao: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Add airport ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add airport")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Type a 4-letter ICAO code.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.48))
                            }
                            Spacer()
                            Text("ICAO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(white: 0.22))
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }

                        HStack(spacing: 10) {
                            TextField("EFHK", text: $inputIcao)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(Color(white: 0.13))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .focused($fieldFocused)
                                .submitLabel(.done)
                                .onSubmit { addAirfield() }

                            Button(action: addAirfield) {
                                Text("Add")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 13)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .disabled(inputIcao.trimmingCharacters(in: .whitespaces).count != 4)
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.38))
                            Text("Examples: EFHA, EFTP, EFJY")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.38))
                        }
                    }
                    .padding(18)
                    .background(Color(white: 0.085))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // ── Selected airports ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Selected airports")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Tap delete to remove from your briefing list.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(white: 0.48))
                            }
                            Spacer()
                            Text("\(viewModel.targetIcaos.count)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(white: 0.22))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        VStack(spacing: 8) {
                            ForEach(viewModel.targetIcaos, id: \.self) { icao in
                                let airfield = viewModel.airfields.first { $0.icao == icao }
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(icao)
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("ACTIVE")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color(white: 0.55))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color(white: 0.18))
                                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        }
                                        if let name = airfield?.locationName {
                                            Text(name)
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(white: 0.48))
                                        }
                                    }
                                    Spacer()
                                    Button(action: { viewModel.removeAirfield(icao: icao) }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(red: 0.85, green: 0.22, blue: 0.22))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.13))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(white: 0.085))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func addAirfield() {
        let clean = inputIcao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count == 4 else { return }
        viewModel.addAirfield(icao: clean)
        inputIcao = ""
        fieldFocused = false
    }
}

// MARK: - Content View + Tab Bar

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var selectedTab: Int = 0

    init() {
        configureTabBar()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AirfieldsView(viewModel: viewModel)
                .tabItem {
                    Label("Airfields", systemImage: "mappin.circle.fill")
                }
                .tag(0)

            settingsPlaceholder
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .tint(.white)
        .task {
            await viewModel.refreshWeather()
        }
    }

    // MARK: Placeholder screens

    private var alertsPlaceholder: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 38))
                    .foregroundColor(Color(white: 0.28))
                Text("No active alerts")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.35))
            }
        }
    }

    private var settingsPlaceholder: some View {
        SettingsView(viewModel: viewModel)
    }

    // MARK: Tab bar appearance

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.07, alpha: 1.0)

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor  = UIColor(white: 0.42, alpha: 1.0)
        normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.42, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor  = .white
        selected.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Xcode Previews
// Uses PreviewProvider (compatible with Xcode 13 / 14).
// If you are on Xcode 15+ you can replace these with #Preview { … } macros.

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}

struct AirfieldCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AirfieldCardView(airfield: AirfieldData.samples[0])
                .padding()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Single Card")
    }
}
