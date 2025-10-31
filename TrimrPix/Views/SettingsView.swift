//
//  SettingsView.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI

/// Settings view panel for configuring application preferences
/// Allows users to configure compression quality, save options, and watch folder settings
struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                // Compression preset
                VStack(alignment: .leading, spacing: 5) {
                    Text("Compression Preset")
                        .font(.headline)
                    
                    Picker("Preset", selection: $settings.compressionPreset) {
                        ForEach(CompressionPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.compressionPreset) { newValue, oldValue in
                        settings.updateQualityFromPreset()
                    }
                }
                
                // Quality
                VStack(alignment: .leading, spacing: 5) {
                    Text("Quality")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.1)
                        Text("\(Int(settings.jpegQuality * 100))%")
                            .frame(width: 40)
                    }
                    .disabled(settings.compressionPreset != .custom)
                    
                    Text("Higher value = better quality, larger file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Save settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Save Settings")
                        .font(.headline)
                    
                    Toggle("Overwrite original files", isOn: $settings.overwriteOriginal)
                        .help("Overwrites the original images instead of creating new ones")
                    
                    Toggle("Auto-save optimized images", isOn: $settings.autoSave)
                        .help("Automatically saves optimized images in the same folder as the original")
                        .disabled(settings.overwriteOriginal)
                }
                
                Divider()
                
                // Watch Folder settings
                VStack(alignment: .leading, spacing: 10) {
                    Text("Watch Folder")
                        .font(.headline)
                    
                    Toggle("Enable Watch Folder", isOn: $settings.watchFolderEnabled)
                        .help("Automatically monitors a folder for new images")
                    
                    if settings.watchFolderEnabled {
                        HStack {
                            TextField("Folder path", text: $settings.watchFolderPath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Choose Folder") {
                                selectWatchFolder()
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    do {
                        try settings.saveSettings()
                    } catch {
                        Logger.shared.error("Failed to save settings: \(error.localizedDescription)")
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .frame(width: 500, height: 450)
    }
    
    private func selectWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Watch Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.watchFolderPath = url.path
        }
    }
}

#Preview {
    SettingsView()
}

