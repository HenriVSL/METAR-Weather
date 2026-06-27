import SwiftUI
import WidgetKit

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

enum TemperatureUnit: String, CaseIterable {
    case celsius    = "C"
    case fahrenheit = "F"
    var label: String { self == .celsius ? "°C" : "°F" }
}

enum WindUnit: String, CaseIterable {
    case knots = "kt"
    case ms    = "ms"
    case mph   = "mph"
    var label: String {
        switch self {
        case .knots: return "kt"
        case .ms:    return "m/s"
        case .mph:   return "mph"
        }
    }
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
    @AppStorage("temperatureUnit", store: .appGroup) private var tempUnitRaw: String = TemperatureUnit.celsius.rawValue
    @AppStorage("windUnit",        store: .appGroup) private var windUnitRaw: String = WindUnit.knots.rawValue

    private var tempUnit: TemperatureUnit { TemperatureUnit(rawValue: tempUnitRaw) ?? .celsius }
    private var windUnit: WindUnit        { WindUnit(rawValue: windUnitRaw) ?? .knots }

    private var convertedTemp: String {
        guard tempUnit == .fahrenheit else { return airfield.displayTemp }
        return "\(Int(Double(airfield.temperatureC) * 9 / 5 + 32))"
    }

    private var convertedWindSpeed: String {
        let kt = airfield.windSpeedKt
        switch windUnit {
        case .knots: return String(format: "%02dkt", kt)
        case .ms:    return String(format: "%.1fm/s", Double(kt) * 0.514444)
        case .mph:   return String(format: "%.0fmph", Double(kt) * 1.15078)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            MetricColumn(
                iconName:      "thermometer.medium",
                label:         "TEMP",
                primaryValue:  convertedTemp,
                primarySuffix: tempUnit.label
            )

            ColumnDivider()

            MetricColumn(
                iconName:     "wind",
                label:        "WIND",
                primaryValue: airfield.displayWindDir,
                secondValue:  convertedWindSpeed,
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
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(airfield.icao)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.42))
                    }

                    Text(airfield.locationName)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.48))

                    FlightConditionBadge(condition: airfield.flightCondition)
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
                    .contentShape(Rectangle())
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
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.105))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                TopBarView(viewModel: viewModel)

                if viewModel.targetIcaos.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(Color(white: 0.28))
                        Text("No airports added")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(white: 0.35))
                        Text("Open Settings and enter an ICAO\ncode to start tracking weather.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.28))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    VStack(spacing: 12) {
                        if viewModel.airfields.isEmpty && viewModel.isRefreshing {
                            ForEach(viewModel.targetIcaos, id: \.self) { icao in
                                PlaceholderCardView(icao: icao)
                            }
                        } else {
                            ForEach(viewModel.airfields) { airfield in
                                AirfieldCardView(airfield: airfield)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Placeholder Card (first-load skeleton)

private struct PlaceholderCardView: View {
    let icao: String
    private let dimGrey = Color(white: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Text(icao)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.42))
                    }
                    Spacer()
                }

                Text("——")
                    .font(.system(size: 13))
                    .foregroundColor(dimGrey)

                // Placeholder badge
                HStack(spacing: 5) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 11, weight: .semibold))
                    Text("—")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(dimGrey)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(white: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Metric grid (dashes)
            HStack(spacing: 0) {
                MetricColumn(iconName: "thermometer.medium", label: "TEMP",
                             primaryValue: "--", valueColor: dimGrey)
                ColumnDivider()
                MetricColumn(iconName: "wind", label: "WIND",
                             primaryValue: "—°", secondValue: "--", valueColor: dimGrey)
                ColumnDivider()
                MetricColumn(iconName: "eye", label: "VIS",
                             primaryValue: "--", valueColor: dimGrey)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)

            // Separator
            Rectangle()
                .fill(Color(white: 0.17))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Raw METAR placeholder
            Text("—— —— —— ——")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(dimGrey)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.105))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Settings View

private struct UnitPicker<U: RawRepresentable & CaseIterable & Hashable>: View where U.RawValue == String {
    let label: String
    let options: [U]
    @Binding var selection: U
    private func displayLabel(_ u: U) -> String {
        (u as? TemperatureUnit)?.label ?? (u as? WindUnit)?.label ?? u.rawValue
    }
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(white: 0.65))
            Spacer()
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selection = option } }) {
                        Text(displayLabel(option))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selection == option ? .black : Color(white: 0.50))
                            .frame(minWidth: 44)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(
                                selection == option
                                    ? RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white)
                                    : RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color(white: 0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var inputIcao: String = ""
    @State private var unitsExpanded = false
    @State private var draggingIcao: String? = nil
    @State private var dragStartIndex: Int = 0
    @FocusState private var fieldFocused: Bool
    @AppStorage("temperatureUnit", store: .appGroup) private var tempUnitRaw: String = TemperatureUnit.celsius.rawValue
    @AppStorage("windUnit",        store: .appGroup) private var windUnitRaw: String = WindUnit.knots.rawValue
    private var tempUnit: TemperatureUnit {
        get { TemperatureUnit(rawValue: tempUnitRaw) ?? .celsius }
        set { tempUnitRaw = newValue.rawValue }
    }
    private var windUnit: WindUnit {
        get { WindUnit(rawValue: windUnitRaw) ?? .knots }
        set { windUnitRaw = newValue.rawValue }
    }

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

                    // ── Units ───────────────────────────────────────────────
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.22)) { unitsExpanded.toggle() }
                        }) {
                            HStack {
                                Text("Units")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: unitsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(white: 0.40))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if unitsExpanded {
                            VStack(spacing: 14) {
                                Rectangle()
                                    .fill(Color(white: 0.17))
                                    .frame(height: 1)
                                    .padding(.top, 14)

                                UnitPicker(
                                    label: "Temperature",
                                    options: TemperatureUnit.allCases,
                                    selection: Binding(
                                        get: { TemperatureUnit(rawValue: tempUnitRaw) ?? .celsius },
                                        set: { tempUnitRaw = $0.rawValue; WidgetCenter.shared.reloadAllTimelines() }
                                    )
                                )
                                UnitPicker(
                                    label: "Wind speed",
                                    options: WindUnit.allCases,
                                    selection: Binding(
                                        get: { WindUnit(rawValue: windUnitRaw) ?? .knots },
                                        set: { windUnitRaw = $0.rawValue; WidgetCenter.shared.reloadAllTimelines() }
                                    )
                                )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
                                Text("Tap trash to remove · drag to reorder.")
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
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(white: 0.38))
                                        .frame(width: 36, height: 44)
                                        .contentShape(Rectangle())
                                        .highPriorityGesture(
                                            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                                .onChanged { value in
                                                    if draggingIcao != icao {
                                                        draggingIcao = icao
                                                        dragStartIndex = viewModel.targetIcaos.firstIndex(of: icao) ?? 0
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    }
                                                    let targetIdx = max(0, min(
                                                        viewModel.targetIcaos.count - 1,
                                                        dragStartIndex + Int((value.translation.height / 68).rounded())
                                                    ))
                                                    guard let currentIdx = viewModel.targetIcaos.firstIndex(of: icao),
                                                          targetIdx != currentIdx else { return }
                                                    withAnimation(.interactiveSpring()) {
                                                        viewModel.targetIcaos.move(
                                                            fromOffsets: IndexSet(integer: currentIdx),
                                                            toOffset: targetIdx > currentIdx ? targetIdx + 1 : targetIdx)
                                                    }
                                                }
                                                .onEnded { _ in
                                                    draggingIcao = nil
                                                    dragStartIndex = 0
                                                }
                                        )
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(draggingIcao == icao
                                    ? Color(white: 0.20)
                                    : Color(white: 0.13))
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
    @Environment(\.scenePhase) private var scenePhase

    // Fires once a minute; `refreshIfStale()` gates the actual fetch to the
    // 30-minute cadence, so this stays cheap while keeping timing accurate.
    private let autoRefreshTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        configureTabBar()
        UIScrollView.appearance().alwaysBounceHorizontal = false
        UIScrollView.appearance().isDirectionalLockEnabled = true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AirfieldsView(viewModel: viewModel)
                .tabItem {
                    Label("Airfields", systemImage: "mappin.circle.fill")
                }
                .tag(0)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .tint(.white)
        .task {
            await viewModel.refreshWeather()
        }
        .onReceive(autoRefreshTick) { _ in
            Task { await viewModel.refreshIfStale() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.refreshIfStale() }
            }
        }
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
            AirfieldCardView(airfield: AirfieldData(
                icao: "EFHA",
                locationName: "Halli Airport",
                flightCondition: .ifr,
                temperatureC: -3,
                windDirectionDeg: 220,
                windSpeedKt: 18,
                visibilityMeters: 1200,
                rawMetar: "EFHA 141420Z 22018KT 1200 BR OVC004 M03/M04 Q1012",
                frequencies: []
            ))
            .padding()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Single Card")
    }
}
