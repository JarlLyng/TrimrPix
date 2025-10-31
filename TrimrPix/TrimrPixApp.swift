//
//  TrimrPixApp.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI

/// Main application entry point
/// Configures the main window and initializes the application lifecycle
@main
struct TrimrPixApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
