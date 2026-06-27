//
//  MetarWidget.swift
//  MetarWidget
//
//  A compact home-screen card for a user-selected saved airport.
//  Configurable via AppIntents; reads/refreshes the shared App Group snapshot.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration intent (lets the user pick which airport to show)

/// One selectable airport in the widget's edit screen.
struct AirportEntity: AppEntity {
    let id: String        // ICAO
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Airport" }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)", subtitle: "\(name)")
    }
    static var defaultQuery = AirportQuery()
}

/// Supplies the list of airports (from the app's saved snapshot) to the picker.
struct AirportQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AirportEntity] {
        WidgetStore.load()
            .filter { identifiers.contains($0.icao) }
            .map { AirportEntity(id: $0.icao, name: $0.locationName) }
    }
    func suggestedEntities() async throws -> [AirportEntity] {
        WidgetStore.load().map { AirportEntity(id: $0.icao, name: $0.locationName) }
    }
}

struct SelectAirportIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Airport" }
    static var description: IntentDescription { "Choose which airport to display." }

    @Parameter(title: "Airport")
    var airport: AirportEntity?
}

// MARK: - Timeline

struct AirfieldEntry: TimelineEntry {
    let date: Date
    let airfield: WidgetAirfield?
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = AirfieldEntry
    typealias Intent = SelectAirportIntent

    private var sample: WidgetAirfield {
        WidgetAirfield(
            icao: "EFHK", locationName: "Helsinki-Vantaa", condition: "VFR",
            temperatureC: 12, windDirectionDeg: 240, windSpeedKt: 8,
            visibilityText: "CAVOK", updatedText: "12:20Z"
        )
    }

    /// Pick the configured airport from the snapshot, falling back to the first.
    private func selected(for configuration: SelectAirportIntent,
                          from list: [WidgetAirfield]) -> WidgetAirfield? {
        if let id = configuration.airport?.id, let match = list.first(where: { $0.icao == id }) {
            return match
        }
        return list.first
    }

    func placeholder(in context: Context) -> AirfieldEntry {
        AirfieldEntry(date: Date(), airfield: sample)
    }

    func snapshot(for configuration: SelectAirportIntent, in context: Context) async -> AirfieldEntry {
        if context.isPreview { return AirfieldEntry(date: Date(), airfield: sample) }
        let list = WidgetStore.load()
        return AirfieldEntry(date: Date(), airfield: selected(for: configuration, from: list) ?? sample)
    }

    func timeline(for configuration: SelectAirportIntent, in context: Context) async -> Timeline<AirfieldEntry> {
        let previous = WidgetStore.load()
        // Fetch fresh METARs so the widget updates even when the app is closed.
        let refreshed = await WidgetWeatherLoader.refresh(icaos: previous.map(\.icao),
                                                          previous: previous)
        WidgetStore.save(refreshed)   // keep the shared snapshot current

        let entry = AirfieldEntry(date: Date(), airfield: selected(for: configuration, from: refreshed))
        // Ask WidgetKit to refresh again in ~30 min (it budgets these, so the
        // actual cadence may stretch a little). The app also pushes immediate
        // reloads whenever it fetches.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Colors (mirror of the app's FlightCondition palette)

private func conditionColor(_ condition: String) -> Color {
    switch condition {
    case "VFR":  return Color(red: 0.18, green: 0.88, blue: 0.42)
    case "MVFR": return Color(red: 1.00, green: 0.63, blue: 0.08)
    case "IFR":  return Color(red: 1.00, green: 0.25, blue: 0.25)
    case "LIFR": return Color(red: 0.82, green: 0.18, blue: 1.00)
    default:     return Color(white: 0.5)
    }
}

private func conditionIcon(_ condition: String) -> String {
    switch condition {
    case "VFR":  return "checkmark.circle.fill"
    case "MVFR": return "info.circle.fill"
    case "IFR":  return "exclamationmark.triangle.fill"
    case "LIFR": return "xmark.octagon.fill"
    default:     return "circle.dotted"
    }
}

// MARK: - Views

struct MetarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AirfieldEntry

    var body: some View {
        if let af = entry.airfield {
            switch family {
            case .systemMedium: MediumCard(af: af)
            default:            SmallCard(af: af)
            }
        } else {
            EmptyState()
        }
    }
}

private struct ConditionBadge: View {
    let condition: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: conditionIcon(condition))
                .font(.system(size: 9, weight: .semibold))
            Text(condition)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(conditionColor(condition))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct Metric: View {
    let icon: String
    let value: String
    var color: Color = .white
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.5))
                .frame(width: 14)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

private struct SmallCard: View {
    let af: WidgetAirfield
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(af.icao)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                ConditionBadge(condition: af.condition)
            }

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 5) {
                Metric(icon: "thermometer.medium", value: WidgetUnits.temperature(af.temperatureC))
                Metric(icon: "wind",
                       value: "\(af.windDirectionDeg)° \(WidgetUnits.windSpeed(af.windSpeedKt))")
                Metric(icon: "eye", value: af.visibilityText,
                       color: Color(red: 0.18, green: 0.88, blue: 0.42))
            }

            Spacer(minLength: 6)

            Text("Updated \(af.updatedText)")
                .font(.system(size: 9))
                .foregroundColor(Color(white: 0.4))
        }
    }
}

private struct MediumCard: View {
    let af: WidgetAirfield
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: ICAO + condition badge
            HStack {
                Text(af.icao)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                ConditionBadge(condition: af.condition)
            }

            // Row 2: location name + update time (frees the vertical space below)
            HStack(spacing: 8) {
                Text(af.locationName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Updated \(af.updatedText)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.4))
                    .fixedSize()
            }
            .padding(.top, 2)

            Spacer(minLength: 12)

            HStack(spacing: 0) {
                metricColumn("thermometer.medium", "TEMP",
                             WidgetUnits.temperature(af.temperatureC), .white)
                divider
                metricColumn("wind", "WIND",
                             "\(af.windDirectionDeg)°\n\(WidgetUnits.windSpeed(af.windSpeedKt))", .white)
                divider
                metricColumn("eye", "VIS", af.visibilityText,
                             Color(red: 0.18, green: 0.88, blue: 0.42))
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(white: 0.2)).frame(width: 1, height: 58)
    }

    private func metricColumn(_ icon: String, _ label: String,
                              _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(white: 0.5))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(white: 0.4))
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 22))
                .foregroundColor(Color(white: 0.4))
            Text("Open METAR Weather\nto add an airport")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget configuration

struct MetarWidget: Widget {
    let kind = "MetarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectAirportIntent.self, provider: Provider()) { entry in
            MetarWidgetView(entry: entry)
                .containerBackground(Color(white: 0.07), for: .widget)
        }
        .configurationDisplayName("Airport METAR")
        .description("Current conditions for a saved airport.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
