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
    
    @Published var compressionQuality: Double = 0.8
    @Published var compressionPreset: CompressionPreset = .medium
    @Published var overwriteOriginal: Bool = false
    @Published var autoSave: Bool = true
    @Published var watchFolderEnabled: Bool = false
    @Published var watchFolderPath: String = ""
    @Published var watchFolderDelay: Double = 2.0 // Delay in seconds before processing new files
    
    /// Security-scoped bookmark data for watch folder (persists across app restarts)
    /// This is required for sandboxed apps to maintain access to the folder
    private var watchFolderBookmarkData: Data?
    
    // MARK: - Singleton
    
    static let shared = Settings()
    
    // MARK: - Dependencies
    
    private let logger: any LoggerProtocol
    private let userDefaults: UserDefaults
    
    // MARK: - UserDefaults Keys
    
    private enum UserDefaultsKeys {
        static let compressionQuality = "compressionQuality"
        static let legacyJpegQuality = "jpegQuality" // migration from v1.0
        static let compressionPreset = "compressionPreset"
        static let overwriteOriginal = "overwriteOriginal"
        static let autoSave = "autoSave"
        static let watchFolderEnabled = "watchFolderEnabled"
        static let watchFolderPath = "watchFolderPath"
        static let watchFolderDelay = "watchFolderDelay"
        static let watchFolderBookmarkData = "watchFolderBookmarkData"
        static let totalOptimizationRuns = "totalOptimizationRuns"
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
        
        // Load compression quality (with migration from legacy "jpegQuality" key)
        var savedQuality = userDefaults.double(forKey: UserDefaultsKeys.compressionQuality)
        if savedQuality == 0 {
            savedQuality = userDefaults.double(forKey: UserDefaultsKeys.legacyJpegQuality)
        }
        if savedQuality > 0 {
            compressionQuality = savedQuality
        } else {
            compressionQuality = CompressionPreset.medium.quality
            logger.debug("Using default compression quality: \(compressionQuality)")
        }

        // Validate quality range
        guard compressionQuality >= 0.1 && compressionQuality <= 1.0 else {
            let error = TrimrPixError.invalidSettingsValue("compressionQuality: \(compressionQuality)")
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
        // Only use UserDefaults value if key exists, otherwise use default
        if userDefaults.object(forKey: UserDefaultsKeys.overwriteOriginal) != nil {
            overwriteOriginal = userDefaults.bool(forKey: UserDefaultsKeys.overwriteOriginal)
        }
        if userDefaults.object(forKey: UserDefaultsKeys.autoSave) != nil {
            autoSave = userDefaults.bool(forKey: UserDefaultsKeys.autoSave)
        } else {
            // Default to true if not set
            autoSave = true
        }
        if userDefaults.object(forKey: UserDefaultsKeys.watchFolderEnabled) != nil {
            watchFolderEnabled = userDefaults.bool(forKey: UserDefaultsKeys.watchFolderEnabled)
        }
        
        // Load watch folder path
        watchFolderPath = userDefaults.string(forKey: UserDefaultsKeys.watchFolderPath) ?? ""
        
        // Load watch folder bookmark data
        if let bookmarkData = userDefaults.data(forKey: UserDefaultsKeys.watchFolderBookmarkData) {
            watchFolderBookmarkData = bookmarkData
            // Try to resolve bookmark to get current path
            do {
                var isStale = false
                let bookmarkURL = try URL(resolvingBookmarkData: bookmarkData,
                                          options: [.withoutUI, .withSecurityScope],
                                          relativeTo: nil,
                                          bookmarkDataIsStale: &isStale)
                
                if !isStale {
                    // Start accessing security-scoped resource to maintain access
                    _ = bookmarkURL.startAccessingSecurityScopedResource()
                    watchFolderPath = bookmarkURL.path
                    logger.debug("Resolved watch folder bookmark: \(watchFolderPath)")
                } else {
                    logger.warning("Watch folder bookmark is stale, clearing it")
                    watchFolderBookmarkData = nil
                }
            } catch {
                logger.warning("Failed to resolve watch folder bookmark: \(error.localizedDescription)")
                watchFolderBookmarkData = nil
            }
        }
        
        // Load watch folder delay
        let savedDelay = userDefaults.double(forKey: UserDefaultsKeys.watchFolderDelay)
        if savedDelay > 0 {
            watchFolderDelay = savedDelay
        } else {
            watchFolderDelay = 2.0 // Default 2 seconds
        }
        
        // Validate watch folder delay
        if !(watchFolderDelay >= 0.5 && watchFolderDelay <= 10.0) {
            watchFolderDelay = 2.0
            logger.warning("Invalid watch folder delay, resetting to default: 2.0 seconds")
        }
        
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
        guard compressionQuality >= 0.1 && compressionQuality <= 1.0 else {
            let error = TrimrPixError.invalidSettingsValue("compressionQuality: \(compressionQuality)")
            logger.error("Invalid JPEG quality value: \(error.technicalDescription)")
            throw error
        }
        
        do {
            userDefaults.set(compressionQuality, forKey: UserDefaultsKeys.compressionQuality)
            userDefaults.set(compressionPreset.rawValue, forKey: UserDefaultsKeys.compressionPreset)
            userDefaults.set(overwriteOriginal, forKey: UserDefaultsKeys.overwriteOriginal)
            userDefaults.set(autoSave, forKey: UserDefaultsKeys.autoSave)
            userDefaults.set(watchFolderEnabled, forKey: UserDefaultsKeys.watchFolderEnabled)
            userDefaults.set(watchFolderPath, forKey: UserDefaultsKeys.watchFolderPath)
            userDefaults.set(watchFolderDelay, forKey: UserDefaultsKeys.watchFolderDelay)
            
            // Save watch folder bookmark data if available
            if let bookmarkData = watchFolderBookmarkData {
                userDefaults.set(bookmarkData, forKey: UserDefaultsKeys.watchFolderBookmarkData)
            }
            
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
            let oldQuality = compressionQuality
            compressionQuality = compressionPreset.quality
            logger.debug("Updated compression quality from preset: \(oldQuality) -> \(compressionQuality)")
        }
    }
    
    /// Validates the watch folder path
    /// - Throws: TrimrPixError if path is invalid or inaccessible
    func validateWatchFolderPath() throws {
        guard !watchFolderPath.isEmpty else {
            throw TrimrPixError.invalidFilePath("Watch folder path is empty")
        }
        
        // Check if path exists
        guard FileManager.default.fileExists(atPath: watchFolderPath) else {
            throw TrimrPixError.watchFolderNotFound(watchFolderPath)
        }
        
        // Check if it's a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: watchFolderPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TrimrPixError.invalidFilePath("Path is not a directory: \(watchFolderPath)")
        }
        
        // Check read access
        guard FileManager.default.isReadableFile(atPath: watchFolderPath) else {
            throw TrimrPixError.watchFolderPermissionDenied(watchFolderPath)
        }
        
        logger.debug("Watch folder path validated successfully: \(watchFolderPath)")
    }
    
    /// Sets the watch folder path and creates a security-scoped bookmark
    /// - Parameter url: The URL of the watch folder
    /// - Throws: TrimrPixError if bookmark creation fails
    func setWatchFolder(url: URL) throws {
        // Create security-scoped bookmark for persistent access
        // Use .withSecurityScope for read-write access to the folder
        let bookmarkData = try url.bookmarkData(options: [.withSecurityScope],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
        
        watchFolderBookmarkData = bookmarkData
        watchFolderPath = url.path
        
        logger.info("Created security-scoped bookmark for watch folder: \(watchFolderPath)")
    }
    
    /// Increments the total optimization runs counter and returns the new value
    func incrementOptimizationRuns() -> Int {
        let count = userDefaults.integer(forKey: UserDefaultsKeys.totalOptimizationRuns) + 1
        userDefaults.set(count, forKey: UserDefaultsKeys.totalOptimizationRuns)
        return count
    }

    /// Gets the watch folder URL from bookmark if available
    /// - Returns: The watch folder URL, or nil if bookmark is not available or stale
    func getWatchFolderURL() -> URL? {
        guard let bookmarkData = watchFolderBookmarkData else {
            return nil
        }
        
        do {
            var isStale = false
            let bookmarkURL = try URL(resolvingBookmarkData: bookmarkData,
                                     options: [.withoutUI, .withSecurityScope],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale)
            
            if isStale {
                logger.warning("Watch folder bookmark is stale")
                watchFolderBookmarkData = nil
                return nil
            }
            
            return bookmarkURL
        } catch {
            logger.warning("Failed to resolve watch folder bookmark: \(error.localizedDescription)")
            watchFolderBookmarkData = nil
            return nil
        }
    }
}

