//
//  WeatherViewModel.swift
//  METAR Weather
//
//  Created by Henri Lavikainen on 24.6.2026.
//

import Foundation
import SwiftUI

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var airfields: [AirfieldData] = []
    @Published var lastUpdated: String = "Not updated yet"
    @Published var timeZ: String = "--:--Z"
    @Published var isRefreshing = false
    
    // 1. Dynamic list backed by UserDefaults
    @Published var targetIcaos: [String] = [] {
        didSet {
            UserDefaults.standard.set(targetIcaos, forKey: "savedICAOs")
        }
    }
    
    private let service = WeatherService()
    
    init() {
        // 2. Load saved airfields on startup, or provide initial defaults
        if let saved = UserDefaults.standard.stringArray(forKey: "savedICAOs"), !saved.isEmpty {
            self.targetIcaos = saved
        } else {
            self.targetIcaos = ["EFHA", "EFTP"] // Default starter pack
        }
    }
    
    // 3. Update refresh logic to use the dynamic array
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

        } catch {
            print("Weather fetch failed: \(error)")
        }

        isRefreshing = false
    }
    
    // 4. Function to add a new ICAO code
    func addAirfield(icao: String) {
        let cleanIcao = icao.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Prevent duplicates and ensure it's a 4-letter code
        guard cleanIcao.count == 4, !targetIcaos.contains(cleanIcao) else { return }
        
        targetIcaos.append(cleanIcao)
        
        // Immediately fetch data for the new station
        Task { await refreshWeather() }
    }
    
    // (Optional) Function to remove one if needed later
    func removeAirfield(icao: String) {
        targetIcaos.removeAll { $0 == icao }
        airfields.removeAll { $0.icao == icao }
    }
    
    private func updateTimestamps() {
        // ... (Keep your existing timestamp logic here)
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
