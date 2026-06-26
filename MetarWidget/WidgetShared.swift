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
