//
//  SettingsView.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import SwiftUI
import IAMJARLDesignTokens

/// Settings view – uses IAMJARL Design System tokens only
struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text("Settings")
                .font(.trimrPixTitle2)
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Compression Preset")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    Picker("Preset", selection: $settings.compressionPreset) {
                        ForEach(CompressionPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.compressionPreset) { _, _ in
                        settings.updateQualityFromPreset()
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Quality")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    HStack {
                        Slider(value: $settings.compressionQuality, in: 0.1...1.0, step: 0.1)
                        Text("\(Int(settings.compressionQuality * 100))%")
                            .frame(width: 40)
                            .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                    }
                    .disabled(settings.compressionPreset != .custom)

                    Text("Higher value = better quality, larger file")
                        .font(.trimrPixCaption)
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                }

                Divider()
                    .background(DesignTokens.Common.Border.subtle(colorScheme))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Image Resize")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    Toggle("Downscale large images before compression", isOn: $settings.resizeEnabled)
                        .help("Reduces image dimensions before compressing. Never upscales.")

                    if settings.resizeEnabled {
                        HStack {
                            Text("Max dimension")
                                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                            Picker("", selection: $settings.maxDimension) {
                                Text("4096 px").tag(4096)
                                Text("2048 px").tag(2048)
                                Text("1920 px").tag(1920)
                                Text("1440 px").tag(1440)
                                Text("1024 px").tag(1024)
                                Text("768 px").tag(768)
                            }
                            .frame(width: 120)
                        }

                        Text("Images larger than this will be downscaled, maintaining aspect ratio")
                            .font(.trimrPixCaption)
                            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                    }
                }

                Divider()
                    .background(DesignTokens.Common.Border.subtle(colorScheme))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("PNG Optimization")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    Toggle("Lossy PNG quantization", isOn: $settings.pngQuantizationEnabled)
                        .help("Reduces PNG colors to 256 for dramatically smaller files. Slight quality trade-off.")

                    Text("Reduces file size by 60-80% for photo PNGs by limiting to 256 colors")
                        .font(.trimrPixCaption)
                        .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                }

                Divider()
                    .background(DesignTokens.Common.Border.subtle(colorScheme))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Save Settings")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                    Toggle("Overwrite original files", isOn: $settings.overwriteOriginal)
                        .help("Overwrites the original images instead of creating new ones")

                    Toggle("Auto-save optimized images", isOn: $settings.autoSave)
                        .help("Automatically saves optimized images in the same folder as the original")
                        .disabled(settings.overwriteOriginal)
                }

                Divider()
                    .background(DesignTokens.Common.Border.subtle(colorScheme))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Watch Folder")
                        .font(.trimrPixHeadline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

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
                                .font(.trimrPixSubheadline)
                                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                            HStack {
                                Slider(value: $settings.watchFolderDelay, in: 0.5...10.0, step: 0.5)
                                Text("\(settings.watchFolderDelay, specifier: "%.1f")s")
                                    .frame(width: 50)
                                    .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                            }

                            Text("Delay before processing new files (prevents processing incomplete files)")
                                .font(.trimrPixCaption)
                                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))

                Button("Save") {
                    do {
                        if settings.watchFolderEnabled {
                            try settings.validateWatchFolderPath()
                        }
                        try settings.saveSettings()
                    } catch {
                        Logger.shared.error("Failed to save settings: \(error.localizedDescription)")
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
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Common.primary(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.xxxl)
        .frame(width: 500, height: 700)
        .background(DesignTokens.Common.Background.app(colorScheme))
    }

    private func selectWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Watch Folder"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try settings.setWatchFolder(url: url)
            } catch {
                Logger.shared.error("Failed to create bookmark for watch folder: \(error.localizedDescription)")
                settings.watchFolderPath = url.path
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
