//
//  ScreenMeApp.swift
//  ScreenMe
//
//  Created by Fernando De Leon on 18/5/2026.
//

import SwiftUI

@main
struct ScreenMeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
