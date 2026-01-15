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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text("Settings")
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Compression preset
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Compression Preset")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    
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
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Quality")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    
                    HStack {
                        Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.1)
                        Text("\(Int(settings.jpegQuality * 100))%")
                            .frame(width: 40)
                            .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    }
                    .disabled(settings.compressionPreset != .custom)
                    
                    Text("Higher value = better quality, larger file")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                }
                
                Divider()
                
                // Save settings
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Save Settings")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    
                    Toggle("Overwrite original files", isOn: $settings.overwriteOriginal)
                        .help("Overwrites the original images instead of creating new ones")
                    
                    Toggle("Auto-save optimized images", isOn: $settings.autoSave)
                        .help("Automatically saves optimized images in the same folder as the original")
                        .disabled(settings.overwriteOriginal)
                }
                
                Divider()
                
                // Watch Folder settings
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Watch Folder")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                    
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
                        
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Processing Delay")
                                .font(DesignTokens.Typography.subheadline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                            
                            HStack {
                                Slider(value: $settings.watchFolderDelay, in: 0.5...10.0, step: 0.5)
                                Text("\(settings.watchFolderDelay, specifier: "%.1f")s")
                                    .frame(width: 50)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary(for: colorScheme))
                            }
                            
                            Text("Delay before processing new files (prevents processing incomplete files)")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
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
                        // Validate watch folder path if enabled
                        if settings.watchFolderEnabled {
                            try settings.validateWatchFolderPath()
                        }
                        try settings.saveSettings()
                    } catch {
                        Logger.shared.error("Failed to save settings: \(error.localizedDescription)")
                        // Show error alert to user
                        let alert = NSAlert()
                        alert.messageText = "Fejl ved gemning"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                        return
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.xxxl)
        .frame(width: 500, height: 520)
    }
    
    private func selectWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Watch Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                // Create security-scoped bookmark for persistent access
                try settings.setWatchFolder(url: url)
            } catch {
                Logger.shared.error("Failed to create bookmark for watch folder: \(error.localizedDescription)")
                // Fallback to just setting the path
                settings.watchFolderPath = url.path
            }
        }
    }
}

#Preview {
    SettingsView()
}

