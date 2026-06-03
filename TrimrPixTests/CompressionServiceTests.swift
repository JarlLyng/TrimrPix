//
//  CompressionServiceTests.swift
//  TrimrPixTests
//
//  Unit tests for CompressionService — exercises the real compression
//  pipeline against generated test images in a temp directory.
//

import Testing
@testable import TrimrPix
import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Combine

// MARK: - Test Doubles

/// In-memory settings stub. Avoids touching UserDefaults / Settings.shared
/// so tests don't pollute the user's real preferences.
@MainActor
final class StubSettings: SettingsProtocol {
    @Published var compressionQuality: Double = 0.8
    @Published var compressionPreset: CompressionPreset = .medium
    @Published var overwriteOriginal: Bool = false
    @Published var autoSave: Bool = true
    @Published var watchFolderEnabled: Bool = false
    @Published var watchFolderPath: String = ""
    @Published var watchFolderDelay: Double = 2.0
    @Published var resizeEnabled: Bool = false
    @Published var maxDimension: Int = 2048
    @Published var pngQuantizationEnabled: Bool = true

    func saveSettings() throws {}
    func loadSettings() throws {}
    func updateQualityFromPreset() { compressionQuality = compressionPreset.quality }
    func validateWatchFolderPath() throws {}
    func setWatchFolder(url: URL) throws {}
    func getWatchFolderURL() -> URL? { nil }
    func incrementOptimizationRuns() -> Int { 0 }
}

// MARK: - Test Image Generation

private enum TestImage {
    /// Generates a solid-color test image as raw CGImage data.
    static func cgImage(width: Int = 200, height: Int = 200, color: NSColor = .systemRed) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        )!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // A second rect ensures the image isn't trivially uniform, so JPEG/PNG
        // produce non-degenerate output.
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        return context.makeImage()!
    }

    /// Writes a real image file to disk in the requested format.
    static func write(to url: URL, type: UTType, width: Int = 200, height: Int = 200) throws {
        let image = cgImage(width: width, height: height)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ) else {
            throw NSError(domain: "TestImage", code: -1)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "TestImage", code: -2)
        }
    }
}

// MARK: - Temp Directory Helper

/// Creates a unique temp directory per test and cleans up on deinit.
final class TempDir {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimrpix-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
}

// MARK: - Tests

@Suite("CompressionService")
@MainActor
struct CompressionServiceTests {

    // MARK: Error paths

    @Test func throwsFileNotFoundForMissingFile() async throws {
        let service = CompressionService()
        let settings = StubSettings().compressionSnapshot
        let missing = URL(fileURLWithPath: "/tmp/trimrpix-nonexistent-\(UUID().uuidString).jpg")

        await #expect(throws: TrimrPixError.self) {
            _ = try await service.optimizeImage(at: missing, settings: settings)
        }
    }

    @Test func throwsUnsupportedFormatForUnknownExtension() async throws {
        let tmp = TempDir()
        let bogus = tmp.file("file.xyz")
        try Data("not an image".utf8).write(to: bogus)

        let service = CompressionService()

        do {
            _ = try await service.optimizeImage(at: bogus, settings: StubSettings().compressionSnapshot)
            Issue.record("Expected unsupportedImageFormat error")
        } catch let error as TrimrPixError {
            if case .unsupportedImageFormat = error { /* ok */ }
            else { Issue.record("Expected .unsupportedImageFormat, got \(error)") }
        }
    }

    @Test func throwsInvalidImageDataForCorruptGIF() async throws {
        let tmp = TempDir()
        let fake = tmp.file("fake.gif")
        try Data("NOPE_NOT_A_GIF_HEADER".utf8).write(to: fake)

        let service = CompressionService()

        do {
            _ = try await service.optimizeImage(at: fake, settings: StubSettings().compressionSnapshot)
            Issue.record("Expected error for corrupt GIF")
        } catch let error as TrimrPixError {
            // GIF validation runs the header check, so we expect invalidImageData.
            if case .invalidImageData = error { /* ok */ }
            else { Issue.record("Expected .invalidImageData, got \(error)") }
        }
    }

    // MARK: Happy paths per format

    @Test func optimizesJPEGAndSavesAlongsideOriginal() async throws {
        let tmp = TempDir()
        let input = tmp.file("photo.jpg")
        try TestImage.write(to: input, type: .jpeg)

        let settings = StubSettings()
        settings.autoSave = true
        settings.overwriteOriginal = false

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(output.lastPathComponent.contains("-optimized"))
        #expect(output.pathExtension.lowercased() == "jpg" || output.pathExtension.lowercased() == "jpeg")
        // Original must remain untouched when not overwriting.
        #expect(FileManager.default.fileExists(atPath: input.path))
    }

    @Test func optimizesPNG() async throws {
        let tmp = TempDir()
        let input = tmp.file("graphic.png")
        try TestImage.write(to: input, type: .png)

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: StubSettings().compressionSnapshot)

        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(output.pathExtension.lowercased() == "png")
    }

    @Test func optimizesHEIC() async throws {
        let tmp = TempDir()
        let input = tmp.file("photo.heic")
        try TestImage.write(to: input, type: .heic)

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: StubSettings().compressionSnapshot)

        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(output.pathExtension.lowercased() == "heic")
    }

    // MARK: Save behavior

    @Test func overwriteOriginalReplacesSourceFile() async throws {
        let tmp = TempDir()
        let input = tmp.file("photo.jpg")
        try TestImage.write(to: input, type: .jpeg)
        let originalSize = try Data(contentsOf: input).count

        let settings = StubSettings()
        settings.overwriteOriginal = true
        settings.compressionQuality = 0.6 // force smaller output

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        #expect(output.path == input.path)
        let newSize = try Data(contentsOf: input).count
        #expect(newSize <= originalSize)
        // No sibling -optimized file should appear when overwriting.
        let siblings = try FileManager.default.contentsOfDirectory(atPath: tmp.url.path)
        #expect(siblings.count == 1)
    }

    @Test func autoSaveUsesUniqueNameWhenTargetExists() async throws {
        let tmp = TempDir()
        let input = tmp.file("photo.jpg")
        try TestImage.write(to: input, type: .jpeg)

        // Pre-create the file the service would prefer, so it must pick a unique name.
        let collision = tmp.file("photo-optimized.jpg")
        try Data("existing".utf8).write(to: collision)

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: StubSettings().compressionSnapshot)

        #expect(output.path != collision.path)
        #expect(output.lastPathComponent.hasPrefix("photo-optimized"))
        // The pre-existing file must still be there, untouched.
        #expect(try Data(contentsOf: collision) == Data("existing".utf8))
    }

    // MARK: Resize behavior

    @Test func resizeShrinksLargeImagesWhenEnabled() async throws {
        let tmp = TempDir()
        let input = tmp.file("large.jpg")
        try TestImage.write(to: input, type: .jpeg, width: 1000, height: 1000)

        let settings = StubSettings()
        settings.resizeEnabled = true
        settings.maxDimension = 256

        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        guard let src = CGImageSourceCreateWithURL(output as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Could not read pixel dimensions from output")
            return
        }
        #expect(max(w, h) <= 256)
    }
}
