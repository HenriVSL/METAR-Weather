//
//  METAR_WeatherApp.swift
//  METAR Weather
//
//  Created by Henri Lavikainen on 24.6.2026.
//

import SwiftUI

@main
struct METAR_WeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 380, idealWidth: 440, minHeight: 560, idealHeight: 760)
                .preferredColorScheme(.dark)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}
