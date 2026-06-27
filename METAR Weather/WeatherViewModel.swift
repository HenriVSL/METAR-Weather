//
//  WeatherViewModel.swift
//  METAR Weather
//
//  Created by Henri Lavikainen on 24.6.2026.
//

import Foundation
import SwiftUI
import WidgetKit

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var airfields: [AirfieldData] = []
    @Published var lastUpdated: String = "Not updated yet"
    @Published var timeZ: String = "--:--Z"
    @Published var isRefreshing = false

    /// Auto-refresh cadence. METAR reports are typically issued every 30 min.
    let autoRefreshInterval: TimeInterval = 30 * 60
    private var lastRefreshDate: Date?

    /// User's chosen airports, persisted to UserDefaults.
    @Published var targetIcaos: [String] = [] {
        didSet {
            UserDefaults.standard.set(targetIcaos, forKey: "savedICAOs")
            // Keep airfields in the same order as targetIcaos after any reorder/remove.
            // Disable animation so the (off-screen) main view layout is already settled
            // by the time the user switches back — otherwise the queued move animation
            // plays out on appear, causing overlapping cards and gaps.
            let reordered = targetIcaos.compactMap { icao in airfields.first { $0.icao == icao } }
            if reordered.map(\.icao) != airfields.map(\.icao) {
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    airfields = reordered
                }
            }
        }
    }
    
    private let service = WeatherService()
    
    init() {
        self.targetIcaos = UserDefaults.standard.stringArray(forKey: "savedICAOs") ?? []
    }

    func refreshWeather() async {
        isRefreshing = true

        do {
            async let metarFetch = service.fetchRawMetars(for: targetIcaos)
            async let airportFetch = service.fetchAirportInfo(for: targetIcaos)
            let rawDataMap = try await metarFetch
            let airportInfoMap = (try? await airportFetch) ?? [:]

            var updatedAirfields: [AirfieldData] = []
            for icao in targetIcaos {
                if let rawText = rawDataMap[icao] {
                    let info = airportInfoMap[icao]
                    let parsedData = MetarParser.parse(
                        rawMetar: rawText,
                        icao: icao,
                        locationName: info?.name ?? icao,
                        frequencies: info?.frequencies ?? []
                    )
                    updatedAirfields.append(parsedData)
                }
            }

            self.airfields = updatedAirfields
            updateTimestamps()
            writeWidgetSnapshot()

        } catch {
            print("Weather fetch failed: \(error)")
        }

        lastRefreshDate = Date()
        isRefreshing = false
    }

    /// Refresh only if the data is older than `autoRefreshInterval`.
    /// Used by the periodic timer and when the app returns to the foreground,
    /// so we don't re-fetch immediately after a manual refresh or launch.
    func refreshIfStale() async {
        if isRefreshing { return }   // a refresh (e.g. the launch .task) is already running
        if let last = lastRefreshDate,
           Date().timeIntervalSince(last) < autoRefreshInterval {
            return
        }
        await refreshWeather()
    }

    /// Publish a snapshot of the current airfields to the shared App Group
    /// container and ask WidgetKit to refresh the home-screen widget.
    private func writeWidgetSnapshot() {
        let snapshot = airfields.map { a in
            WidgetAirfield(
                icao: a.icao,
                locationName: a.locationName,
                condition: a.flightCondition.rawValue,
                temperatureC: a.temperatureC,
                windDirectionDeg: a.windDirectionDeg,
                windSpeedKt: a.windSpeedKt,
                visibilityText: a.displayVis,
                updatedText: timeZ
            )
        }
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func addAirfield(icao: String) {
        let cleanIcao = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Prevent duplicates and ensure it's a 4-letter code.
        guard cleanIcao.count == 4, !targetIcaos.contains(cleanIcao) else { return }

        targetIcaos.append(cleanIcao)
        Task { await refreshWeather() }   // fetch data for the new station
    }

    func removeAirfield(icao: String) {
        targetIcaos.removeAll { $0 == icao }
        airfields.removeAll { $0.icao == icao }
        writeWidgetSnapshot()
    }

    private func updateTimestamps() {
        let now = Date()
        let zuluFormatter = DateFormatter()
        zuluFormatter.dateFormat = "HH:mm'Z'"
        zuluFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.timeZ = zuluFormatter.string(from: now)
        
        let localFormatter = DateFormatter()
        localFormatter.timeStyle = .short
        self.lastUpdated = "Updated \(localFormatter.string(from: now))"
    }
}
