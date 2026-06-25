//
//  MetarParser.swift
//  METAR Weather
//
//  Created by Henri Lavikainen on 24.6.2026.
//

import Foundation

struct MetarParser {
    
    static func parse(rawMetar: String, icao: String, locationName: String, frequencies: [AirportFrequency]) -> AirfieldData {
        let temp = extractTemperature(from: rawMetar) ?? 0
        let wind = extractWind(from: rawMetar)
        let vis = extractVisibility(from: rawMetar) ?? 9999
        let condition = determineFlightCondition(visibilityMeters: vis, rawMetar: rawMetar)

        let summary = "Wind \(wind.dir)° at \(wind.speed)kt. Visibility \(vis >= 9999 ? "9999m or more" : "\(vis)m"). Temperature \(temp)°C."

        return AirfieldData(
            icao: icao,
            locationName: locationName,
            flightCondition: condition,
            temperatureC: temp,
            windDirectionDeg: wind.dir,
            windSpeedKt: wind.speed,
            visibilityMeters: vis,
            humanSummary: summary,
            rawMetar: rawMetar,
            frequencies: frequencies
        )
    }
    
    // Extracts Temperature e.g., "M03/M04" -> -3 or "01/M01" -> 1
    private static func extractTemperature(from text: String) -> Int? {
        let pattern = "\\b(M?\\d{2})/(M?\\d{2})?\\b"
        guard let match = performRegex(pattern: pattern, on: text).first, match.count > 1 else { return nil }
        
        let tempStr = match[1]
        if tempStr.hasPrefix("M") {
            return Int(tempStr.dropFirst()) != nil ? -Int(tempStr.dropFirst())! : nil
        }
        return Int(tempStr)
    }
    
    // Extracts Wind e.g., "22018KT" -> Dir: 220, Speed: 18
    private static func extractWind(from text: String) -> (dir: Int, speed: Int) {
        let pattern = "\\b(\\d{3}|VRB)(\\d{2,3})(?:G\\d{2,3})?KT\\b"
        let matches = performRegex(pattern: pattern, on: text)
        
        guard let match = matches.first, match.count > 2 else { return (0, 0) }
        
        let dir = match[1] == "VRB" ? 0 : (Int(match[1]) ?? 0)
        let speed = Int(match[2]) ?? 0
        
        return (dir, speed)
    }
    
    // Extracts Visibility in meters (standard 4 digit European format) e.g., "6000" or "9999"
    private static func extractVisibility(from text: String) -> Int? {
        // Matches a standalone 4-digit number that isn't a time (Z) or part of another block
        let pattern = "\\s(\\d{4})\\s"
        guard let match = performRegex(pattern: pattern, on: text).first, match.count > 1 else {
            // Check for CAVOK (Ceiling and Visibility OK -> essentially 9999+)
            if text.contains(" CAVOK ") { return 9999 }
            return nil
        }
        return Int(match[1])
    }
    
    // Basic ruleset mapping visibility to flight rules
    private static func determineFlightCondition(visibilityMeters vis: Int, rawMetar: String) -> FlightCondition {
        // A simplified metric focusing heavily on visibility to keep the logic tight.
        if vis < 1500 { return .lifr }
        if vis < 3000 { return .ifr }
        if vis < 5000 { return .mvfr }
        return .vfr
    }
    
    // Helper to safely execute NSRegularExpression
    private static func performRegex(pattern: String, on text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        return results.map { match in
            (0..<match.numberOfRanges).map {
                let rangeBounds = match.range(at: $0)
                guard rangeBounds.location != NSNotFound else { return "" }
                return nsString.substring(with: rangeBounds)
            }
        }
    }
}
