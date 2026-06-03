//
//  Protocols.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit

// MARK: - Compression Service Protocol

/// Protocol defining the interface for image compression operations
/// Enables dependency injection and testing.
/// `Sendable` so a compression service can be safely shared with the background
/// file-processing work in `WatchFolderService`.
protocol CompressionServiceProtocol: Sendable {
    /// Optimizes an image at the given URL
    /// - Parameters:
    ///   - url: The URL of the image to optimize
    ///   - settings: A Sendable snapshot of the settings to use for this compression.
    ///     Pass `someSettings.compressionSnapshot`, captured on the main actor.
    /// - Returns: The URL of the optimized image
    /// - Throws: TrimrPixError if optimization fails
    func optimizeImage(at url: URL, settings: CompressionSettings) async throws -> URL
}

// MARK: - Watch Folder Service Protocol

/// Protocol defining the interface for file system monitoring.
/// `@MainActor`-isolated: the service owns mutable state (watch status, processed
/// files) that is only ever touched from the main actor; background file I/O is
/// dispatched internally with Sendable values only.
@MainActor
protocol WatchFolderServiceProtocol {
    /// Starts monitoring a folder for new images
    /// - Parameter path: The folder path to monitor
    /// - Throws: TrimrPixError if monitoring setup fails
    func startWatching(path: String) throws
    
    /// Stops monitoring the current folder
    func stopWatching()
    
    /// Indicates whether a folder is currently being monitored
    var isWatching: Bool { get }
    
    /// The path of the currently monitored folder
    var watchedPath: String { get }
}

// MARK: - File Manager Protocol

/// Protocol for file system operations
/// Enables dependency injection for testing
protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
}

extension FileManager: FileManagerProtocol {}

// MARK: - Image Repository Protocol

/// Protocol for image data access operations
protocol ImageRepositoryProtocol {
    /// Loads image data from a URL
    /// - Parameter url: The URL to load from
    /// - Returns: The loaded image data
    /// - Throws: TrimrPixError if loading fails
    func loadImageData(from url: URL) async throws -> Data
    
    /// Saves image data to a URL
    /// - Parameters:
    ///   - data: The image data to save
    ///   - url: The destination URL
    /// - Throws: TrimrPixError if saving fails
    func saveImageData(_ data: Data, to url: URL) async throws
    
    /// Reads file size for a given URL
    /// - Parameter url: The URL to read size for
    /// - Returns: The file size in bytes
    /// - Throws: TrimrPixError if reading fails
    func getFileSize(for url: URL) async throws -> Int64
}

// MARK: - Settings Protocol

/// Protocol for application settings management.
/// `@MainActor`-isolated: settings are owned by the UI and only mutated/read on the
/// main actor. Background work takes an immutable `CompressionSettings` snapshot instead.
@MainActor
protocol SettingsProtocol: ObservableObject {
    var compressionQuality: Double { get set }
    var compressionPreset: CompressionPreset { get set }
    var overwriteOriginal: Bool { get set }
    var autoSave: Bool { get set }
    var watchFolderEnabled: Bool { get set }
    var watchFolderPath: String { get set }
    var watchFolderDelay: Double { get set }
    var resizeEnabled: Bool { get set }
    var maxDimension: Int { get set }
    var pngQuantizationEnabled: Bool { get set }

    func saveSettings() throws
    func loadSettings() throws
    func updateQualityFromPreset()
    func validateWatchFolderPath() throws
    func setWatchFolder(url: URL) throws
    func getWatchFolderURL() -> URL?
    func incrementOptimizationRuns() -> Int
}

extension SettingsProtocol {
    /// An immutable, `Sendable` snapshot of the settings a single compression needs.
    /// Capture this on the main actor, then hand it to background compression work so
    /// `CompressionService` never reads mutable settings state off the main thread.
    var compressionSnapshot: CompressionSettings {
        CompressionSettings(
            compressionQuality: compressionQuality,
            pngQuantizationEnabled: pngQuantizationEnabled,
            resizeEnabled: resizeEnabled,
            maxDimension: maxDimension,
            overwriteOriginal: overwriteOriginal,
            autoSave: autoSave
        )
    }
}

/// Immutable, `Sendable` snapshot of the settings required to perform one compression.
/// Decouples the background compression pipeline from the main-actor-isolated `Settings`.
struct CompressionSettings: Sendable {
    let compressionQuality: Double
    let pngQuantizationEnabled: Bool
    let resizeEnabled: Bool
    let maxDimension: Int
    let overwriteOriginal: Bool
    let autoSave: Bool
}

