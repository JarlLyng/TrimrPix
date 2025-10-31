//
//  Settings.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation

/// Compression preset options for image optimization
enum CompressionPreset: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case custom = "Custom"
    
    /// Quality value for the preset (0.0 - 1.0)
    var quality: Double {
        switch self {
        case .low: return 0.6
        case .medium: return 0.8
        case .high: return 0.95
        case .custom: return 0.8
        }
    }
}

/// Application settings management
/// Implements SettingsProtocol for dependency injection and testing
final class Settings: SettingsProtocol {
    
    // MARK: - Published Properties
    
    @Published var jpegQuality: Double = 0.8
    @Published var compressionPreset: CompressionPreset = .medium
    @Published var overwriteOriginal: Bool = false
    @Published var autoSave: Bool = true
    @Published var watchFolderEnabled: Bool = false
    @Published var watchFolderPath: String = ""
    
    // MARK: - Singleton
    
    static let shared = Settings()
    
    // MARK: - Dependencies
    
    private let logger: any LoggerProtocol
    private let userDefaults: UserDefaults
    
    // MARK: - UserDefaults Keys
    
    private enum UserDefaultsKeys {
        static let jpegQuality = "jpegQuality"
        static let compressionPreset = "compressionPreset"
        static let overwriteOriginal = "overwriteOriginal"
        static let autoSave = "autoSave"
        static let watchFolderEnabled = "watchFolderEnabled"
        static let watchFolderPath = "watchFolderPath"
    }
    
    // MARK: - Initialization
    
    /// Initializes settings with dependencies
    /// - Parameters:
    ///   - logger: Logger protocol instance (defaults to Logger.shared)
    ///   - userDefaults: UserDefaults instance (defaults to .standard)
    private init(
        logger: any LoggerProtocol = Logger.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.logger = logger
        self.userDefaults = userDefaults
        
        do {
            try loadSettings()
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings Management
    
    /// Loads settings from UserDefaults
    /// - Throws: TrimrPixError if loading fails
    func loadSettings() throws {
        logger.debug("Loading settings from UserDefaults")
        
        // Load JPEG quality
        let savedQuality = userDefaults.double(forKey: UserDefaultsKeys.jpegQuality)
        if savedQuality > 0 {
            jpegQuality = savedQuality
        } else {
            // Use default value if not set
            jpegQuality = CompressionPreset.medium.quality
            logger.debug("Using default JPEG quality: \(jpegQuality)")
        }
        
        // Validate quality range
        guard jpegQuality >= 0.1 && jpegQuality <= 1.0 else {
            let error = TrimrPixError.invalidSettingsValue("jpegQuality: \(jpegQuality)")
            logger.error("Invalid JPEG quality value: \(error.technicalDescription)")
            throw error
        }
        
        // Load compression preset
        if let presetString = userDefaults.string(forKey: UserDefaultsKeys.compressionPreset),
           let preset = CompressionPreset(rawValue: presetString) {
            compressionPreset = preset
        } else {
            compressionPreset = .medium
            logger.debug("Using default compression preset: \(compressionPreset.rawValue)")
        }
        
        // Load boolean settings
        overwriteOriginal = userDefaults.bool(forKey: UserDefaultsKeys.overwriteOriginal)
        autoSave = userDefaults.bool(forKey: UserDefaultsKeys.autoSave)
        watchFolderEnabled = userDefaults.bool(forKey: UserDefaultsKeys.watchFolderEnabled)
        
        // Load watch folder path
        watchFolderPath = userDefaults.string(forKey: UserDefaultsKeys.watchFolderPath) ?? ""
        
        // Ensure autoSave is disabled if overwriteOriginal is enabled
        if overwriteOriginal && autoSave {
            autoSave = false
            logger.warning("Auto-save disabled because overwrite original is enabled")
        }
        
        logger.info("Settings loaded successfully")
    }
    
    /// Saves settings to UserDefaults
    /// - Throws: TrimrPixError if saving fails
    func saveSettings() throws {
        logger.debug("Saving settings to UserDefaults")
        
        // Validate quality range before saving
        guard jpegQuality >= 0.1 && jpegQuality <= 1.0 else {
            let error = TrimrPixError.invalidSettingsValue("jpegQuality: \(jpegQuality)")
            logger.error("Invalid JPEG quality value: \(error.technicalDescription)")
            throw error
        }
        
        do {
            userDefaults.set(jpegQuality, forKey: UserDefaultsKeys.jpegQuality)
            userDefaults.set(compressionPreset.rawValue, forKey: UserDefaultsKeys.compressionPreset)
            userDefaults.set(overwriteOriginal, forKey: UserDefaultsKeys.overwriteOriginal)
            userDefaults.set(autoSave, forKey: UserDefaultsKeys.autoSave)
            userDefaults.set(watchFolderEnabled, forKey: UserDefaultsKeys.watchFolderEnabled)
            userDefaults.set(watchFolderPath, forKey: UserDefaultsKeys.watchFolderPath)
            
            // Synchronize UserDefaults
            if !userDefaults.synchronize() {
                let error = TrimrPixError.settingsSaveFailed(underlyingError: nil)
                logger.error("Failed to synchronize UserDefaults: \(error.technicalDescription)")
                throw error
            }
            
            logger.info("Settings saved successfully")
        } catch {
            let trimmedError = TrimrPixError.settingsSaveFailed(underlyingError: error)
            logger.error("Failed to save settings: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    /// Updates JPEG quality from the current preset
    func updateQualityFromPreset() {
        if compressionPreset != .custom {
            let oldQuality = jpegQuality
            jpegQuality = compressionPreset.quality
            logger.debug("Updated JPEG quality from preset: \(oldQuality) -> \(jpegQuality)")
        }
    }
}
