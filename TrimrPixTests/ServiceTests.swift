//
//  ServiceTests.swift
//  TrimrPixTests
//
//  Unit tests for the previously-uncovered components: ImageOptimizationViewModel,
//  WatchFolderService, and ColorQuantizer (issue #26). Reuses TestImage / TempDir /
//  StubSettings from CompressionServiceTests.swift.
//

import Testing
@testable import TrimrPix
import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Test doubles

/// Compression service stub. Writes a real output file of a fixed size (so the view
/// model can read its attributes) or throws on demand.
final class MockCompressionService: CompressionServiceProtocol, @unchecked Sendable {
    let shouldThrow: Bool
    let outputBytes: Int

    init(shouldThrow: Bool = false, outputBytes: Int = 16) {
        self.shouldThrow = shouldThrow
        self.outputBytes = outputBytes
    }

    func optimizeImage(at url: URL, settings: CompressionSettings) async throws -> URL {
        if shouldThrow {
            throw TrimrPixError.compressionFailed(url: url, underlyingError: nil)
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-optimized-\(UUID().uuidString).bin")
        try Data(repeating: 0, count: outputBytes).write(to: out)
        return out
    }
}

@MainActor
final class MockWatchFolderService: WatchFolderServiceProtocol {
    var isWatching: Bool = false
    var watchedPath: String = ""
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func startWatching(path: String) throws {
        startCount += 1
        isWatching = true
        watchedPath = path
    }

    func stopWatching() {
        stopCount += 1
        isWatching = false
        watchedPath = ""
    }
}

// MARK: - Helpers

@MainActor
private func makeViewModel(
    compression: MockCompressionService = MockCompressionService(),
    watch: MockWatchFolderService = MockWatchFolderService(),
    settings: StubSettings = StubSettings()
) -> ImageOptimizationViewModel {
    ImageOptimizationViewModel(
        compressionService: compression,
        watchFolderService: watch,
        settings: settings
    )
}

@MainActor
private func makeImageItem(in tmp: TempDir, name: String = "photo.jpg") throws -> ImageItem {
    let url = tmp.file(name)
    try TestImage.write(to: url, type: .jpeg)
    return try ImageItem(url: url)
}

// MARK: - ViewModel

@Suite("ImageOptimizationViewModel", .serialized)
@MainActor
struct ImageOptimizationViewModelTests {

    @Test func optimizeImageMarksItemOptimized() async throws {
        let tmp = TempDir()
        let vm = makeViewModel(compression: MockCompressionService(outputBytes: 8))
        vm.images = [try makeImageItem(in: tmp)]

        await vm.optimizeImage(at: 0)

        #expect(vm.images[0].isOptimized)
        #expect(vm.images[0].isOptimizing == false)
        #expect(vm.images[0].optimizedSize == 8)
        #expect(vm.showError == false)
    }

    @Test func optimizeImageSurfacesErrorOnFailure() async throws {
        let tmp = TempDir()
        let vm = makeViewModel(compression: MockCompressionService(shouldThrow: true))
        vm.images = [try makeImageItem(in: tmp)]

        await vm.optimizeImage(at: 0)

        #expect(vm.images[0].isOptimized == false)
        #expect(vm.images[0].isOptimizing == false)
        #expect(vm.showError)
        #expect(vm.errorMessage != nil)
    }

    @Test func optimizeImageWithInvalidIndexIsNoOp() async {
        let vm = makeViewModel()
        await vm.optimizeImage(at: 5) // empty list
        #expect(vm.showError == false)
        #expect(vm.images.isEmpty)
    }

    @Test func optimizeAllProcessesEveryImage() async throws {
        let tmp = TempDir()
        let vm = makeViewModel(compression: MockCompressionService(outputBytes: 8))
        vm.images = try (0..<6).map { try makeImageItem(in: tmp, name: "img\($0).jpg") }

        vm.optimizeAllImages()
        // optimizeAllImages launches a Task; wait for it to settle.
        try await waitUntil { !vm.isOptimizing && vm.images.allSatisfy { $0.isOptimized } }

        #expect(vm.images.allSatisfy { $0.isOptimized })
        #expect(vm.isOptimizing == false)
    }

    @Test func removeImageRemovesById() async throws {
        let tmp = TempDir()
        let vm = makeViewModel()
        let item = try makeImageItem(in: tmp)
        vm.images = [item]

        vm.removeImage(id: item.id)
        #expect(vm.images.isEmpty)
    }

    @Test func clearImagesEmptiesList() async throws {
        let tmp = TempDir()
        let vm = makeViewModel()
        vm.images = [try makeImageItem(in: tmp, name: "a.jpg"),
                     try makeImageItem(in: tmp, name: "b.jpg")]

        vm.clearImages()
        #expect(vm.images.isEmpty)
    }

    @Test func dismissErrorClearsState() {
        let vm = makeViewModel()
        vm.showError = true
        vm.errorMessage = "boom"
        vm.dismissError()
        #expect(vm.showError == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func watchFolderActiveReflectsService() throws {
        let watch = MockWatchFolderService()
        let settings = StubSettings()
        settings.watchFolderEnabled = true
        settings.watchFolderPath = FileManager.default.temporaryDirectory.path
        let vm = makeViewModel(watch: watch, settings: settings)

        #expect(vm.isWatchFolderActive == false)
        vm.startWatchFolder()
        #expect(vm.isWatchFolderActive)
        #expect(watch.startCount == 1)
        vm.stopWatchFolder()
        #expect(vm.isWatchFolderActive == false)
        #expect(watch.stopCount == 1)
    }
}

// MARK: - WatchFolderService

@Suite("WatchFolderService", .serialized)
@MainActor
struct WatchFolderServiceTests {

    private func makeService() -> WatchFolderService {
        WatchFolderService(compressionService: MockCompressionService(), settings: StubSettings())
    }

    @Test func throwsOnEmptyPath() {
        let service = makeService()
        #expect(throws: TrimrPixError.self) {
            try service.startWatching(path: "")
        }
    }

    @Test func throwsOnNonexistentPath() {
        let service = makeService()
        #expect(throws: TrimrPixError.self) {
            try service.startWatching(path: "/nonexistent/trimrpix-\(UUID().uuidString)")
        }
    }

    // Note: starting the real DispatchSource file-system watcher is integration-level
    // (opens an fd, spins a background source) and is environment-sensitive on CI, so
    // it isn't unit-tested here. Start/stop semantics are covered at the view-model
    // layer via MockWatchFolderService (see watchFolderActiveReflectsService).
}

// MARK: - ColorQuantizer

@Suite("ColorQuantizer", .serialized)
struct ColorQuantizerTests {

    @Test func quantizePreservesDimensions() {
        let image = TestImage.cgImage(width: 64, height: 48)
        let quantizer = ColorQuantizer(maxColors: 256, logger: Logger.shared)

        let result = quantizer.quantize(image)
        #expect(result != nil)
        #expect(result?.width == 64)
        #expect(result?.height == 48)
    }

    @Test func quantizeWithTinyPaletteStillProducesImage() {
        let image = TestImage.cgImage(width: 32, height: 32)
        let quantizer = ColorQuantizer(maxColors: 2, logger: Logger.shared)

        let result = quantizer.quantize(image)
        #expect(result != nil)
        #expect(result?.width == 32)
    }
}

// MARK: - Async test helper

/// Polls `condition` until true or a timeout elapses, yielding between checks.
@MainActor
private func waitUntil(timeout: Double = 5.0, _ condition: () -> Bool) async throws {
    let start = Date()
    while !condition() {
        if Date().timeIntervalSince(start) > timeout {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
    }
}
