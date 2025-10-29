//
//  Settings.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation

enum CompressionPreset: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case custom = "Custom"
    
    var quality: Double {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 0.95
        case .custom: return 0.8
        }
    }
}

class Settings: ObservableObject {
    @Published var jpegQuality: Double = 0.8
    @Published var compressionPreset: CompressionPreset = .medium
    @Published var overwriteOriginal: Bool = false
    @Published var autoSave: Bool = true
    @Published var watchFolderEnabled: Bool = false
    @Published var watchFolderPath: String = ""
    
    static let shared = Settings()
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        // Load from UserDefaults
        jpegQuality = UserDefaults.standard.double(forKey: "jpegQuality")
        if jpegQuality == 0 {
            jpegQuality = 0.8 // Default value
        }
        
        if let presetString = UserDefaults.standard.string(forKey: "compressionPreset"),
           let preset = CompressionPreset(rawValue: presetString) {
            compressionPreset = preset
        }
        
        overwriteOriginal = UserDefaults.standard.bool(forKey: "overwriteOriginal")
        autoSave = UserDefaults.standard.bool(forKey: "autoSave")
        watchFolderEnabled = UserDefaults.standard.bool(forKey: "watchFolderEnabled")
        watchFolderPath = UserDefaults.standard.string(forKey: "watchFolderPath") ?? ""
    }
    
    func saveSettings() {
        UserDefaults.standard.set(jpegQuality, forKey: "jpegQuality")
        UserDefaults.standard.set(compressionPreset.rawValue, forKey: "compressionPreset")
        UserDefaults.standard.set(overwriteOriginal, forKey: "overwriteOriginal")
        UserDefaults.standard.set(autoSave, forKey: "autoSave")
        UserDefaults.standard.set(watchFolderEnabled, forKey: "watchFolderEnabled")
        UserDefaults.standard.set(watchFolderPath, forKey: "watchFolderPath")
    }
    
    func updateQualityFromPreset() {
        if compressionPreset != .custom {
            jpegQuality = compressionPreset.quality
        }
    }
}
