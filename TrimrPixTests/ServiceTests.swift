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
import PDFKit

// MARK: - Test doubles

/// Compression service stub. Writes a real output file of a fixed size (so the view
/// model can read its attributes) or throws on demand.
final class MockCompressionService: CompressionServiceProtocol, @unchecked Sendable {
    let shouldThrow: Bool
    let outputBytes: Int
    let delayNanos: UInt64

    init(shouldThrow: Bool = false, outputBytes: Int = 16, delayNanos: UInt64 = 0) {
        self.shouldThrow = shouldThrow
        self.outputBytes = outputBytes
        self.delayNanos = delayNanos
    }

    func optimizeImage(at url: URL, settings: CompressionSettings) async throws -> URL {
        if delayNanos > 0 {
            try? await Task.sleep(nanoseconds: delayNanos)
        }
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
    settings: StubSettings = StubSettings(),
    onReview: (@MainActor () -> Void)? = nil
) -> ImageOptimizationViewModel {
    ImageOptimizationViewModel(
        compressionService: compression,
        watchFolderService: watch,
        settings: settings,
        requestReviewAction: onReview
    )
}

/// Mutable main-actor counter for asserting the review prompt fired.
@MainActor
final class ReviewSpy {
    private(set) var count = 0
    func fire() { count += 1 }
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

    @Test func optimizeAllReportsBatchProgress() async throws {
        let tmp = TempDir()
        // A small per-image delay makes the mid-flight progress state observable.
        let vm = makeViewModel(compression: MockCompressionService(outputBytes: 8, delayNanos: 30_000_000))
        vm.images = try (0..<3).map { try makeImageItem(in: tmp, name: "img\($0).jpg") }

        #expect(vm.batchProgress == nil)
        vm.optimizeAllImages()

        // Progress appears with the right total while the batch runs...
        try await waitUntil { vm.batchProgress != nil }
        #expect(vm.batchProgress?.total == 3)

        // ...and clears when the batch completes.
        try await waitUntil { vm.batchProgress == nil && !vm.isOptimizing }
        #expect(vm.images.allSatisfy { $0.isOptimized })
    }

    @Test func optimizeRegistersSessionAndAsksForReviewWhenDue() async throws {
        let tmp = TempDir()
        let settings = StubSettings()
        settings.shouldRequestReviewResult = true
        let spy = ReviewSpy()
        let vm = makeViewModel(settings: settings, onReview: { spy.fire() })
        vm.images = [try makeImageItem(in: tmp)]

        await vm.optimizeImage(at: 0)

        #expect(settings.registeredSessions == 1)
        #expect(spy.count == 1)
    }

    @Test func optimizeDoesNotAskForReviewWhenNotDue() async throws {
        let tmp = TempDir()
        let settings = StubSettings()
        settings.shouldRequestReviewResult = false
        let spy = ReviewSpy()
        let vm = makeViewModel(settings: settings, onReview: { spy.fire() })
        vm.images = [try makeImageItem(in: tmp)]

        await vm.optimizeImage(at: 0)

        #expect(settings.registeredSessions == 1) // session still counted
        #expect(spy.count == 0)                    // but no prompt
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

// MARK: - ImageItem thumbnails

@Suite("ImageItem.loadThumbnail", .serialized)
struct ImageItemThumbnailTests {

    @Test func generatesThumbnailAtPreviewSize() async throws {
        let tmp = TempDir()
        let url = tmp.file("big.jpg")
        try TestImage.write(to: url, type: .jpeg, width: 1000, height: 600)

        let thumb = await ImageItem.loadThumbnail(from: url)
        let unwrapped = try #require(thumb)
        // Decoded at thumbnail size, not full resolution.
        #expect(max(unwrapped.width, unwrapped.height) <= 240)
        // Aspect ratio preserved (wide image stays wide).
        #expect(unwrapped.width > unwrapped.height)
    }

    @Test func returnsNilForMissingFile() async {
        let missing = URL(fileURLWithPath: "/tmp/trimrpix-missing-\(UUID().uuidString).jpg")
        let thumb = await ImageItem.loadThumbnail(from: missing)
        #expect(thumb == nil)
    }

    @Test func returnsNilForNonImageFile() async throws {
        let tmp = TempDir()
        let bogus = tmp.file("notes.txt")
        try Data("not an image".utf8).write(to: bogus)

        let thumb = await ImageItem.loadThumbnail(from: bogus)
        #expect(thumb == nil)
    }
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

// MARK: - PDF compression

/// Builds test PDFs: `withText` controls whether a real text layer is present.
private enum TestPDF {
    /// Writes a PDF that behaves like a real scan.
    ///
    /// The page carries a high-resolution, photographic-looking image. That matters:
    /// an earlier fixture drew flat colour blocks, which a PDF stores very compactly,
    /// so re-encoding made the file *larger*, the size guard returned the original
    /// untouched, and every assertion below silently described the input rather than
    /// the compressed output. A noisy image compresses the way a scan does.
    static func write(to url: URL, pages: Int = 2, withText: Bool, imgW: Int = 1400, imgH: Int = 2100) {
        // Deliberately NOT 612x792: that is Core Graphics' default page size, so a
        // fixture using it passes even when the media box is dropped entirely.
        var pageRect = CGRect(x: 0, y: 0, width: 594, height: 911)
        guard let ctx = CGContext(url as CFURL, mediaBox: &pageRect, nil) else { return }
        for p in 0..<pages {
            ctx.beginPDFPage(nil)
            if let bmp = CGContext(data: nil, width: imgW, height: imgH, bitsPerComponent: 8,
                                   bytesPerRow: imgW * 4, space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
               let pixels = bmp.data {
                // Paper-coloured grain plus darker marks, deterministic per page.
                var seed = UInt64(p &+ 1) &* 0x9E3779B97F4A7C15
                for index in stride(from: 0, to: imgW * imgH * 4, by: 4) {
                    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                    let noise = UInt8(truncatingIfNeeded: seed >> 24)
                    let ink: UInt8 = (index / 4) % imgW < imgW / 3 ? 90 : 215
                    let value = UInt8(clamping: Int(ink) &+ Int(noise % 60) &- 30)
                    pixels.storeBytes(of: value, toByteOffset: index, as: UInt8.self)
                    pixels.storeBytes(of: value, toByteOffset: index + 1, as: UInt8.self)
                    pixels.storeBytes(of: value, toByteOffset: index + 2, as: UInt8.self)
                    pixels.storeBytes(of: UInt8(255), toByteOffset: index + 3, as: UInt8.self)
                }
                if let img = bmp.makeImage() { ctx.draw(img, in: pageRect) }
            }
            if withText {
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                let attr = NSAttributedString(
                    string: "This page carries a genuine selectable text layer for testing purposes.",
                    attributes: [.font: NSFont.systemFont(ofSize: 14)])
                let line = CTLineCreateWithAttributedString(attr)
                ctx.textPosition = CGPoint(x: 40, y: 80)
                CTLineDraw(line, ctx)
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }
}

@Suite("PDF compression", .serialized)
@MainActor
struct PDFCompressionTests {

    /// A scanned PDF (no text layer) is compressed and stays a readable PDF.
    @Test func compressesScannedPDF() async throws {
        let tmp = TempDir()
        let input = tmp.file("scan.pdf")
        TestPDF.write(to: input, withText: false)

        let settings = StubSettings()
        settings.compressionQuality = 0.6
        let service = CompressionService()

        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(output.pathExtension.lowercased() == "pdf")
        let doc = try #require(PDFDocument(url: output))
        #expect(doc.pageCount == 2)

        // Without this the size guard could be returning the original file, which would
        // make every other assertion in this suite describe the input instead.
        let originalSize = try #require(try Data(contentsOf: input).count)
        let compressedSize = try #require(try Data(contentsOf: output).count)
        #expect(compressedSize < originalSize, "the fixture did not actually compress")
    }

    /// The compressed page keeps the original's physical size.
    ///
    /// `PDFPage(image:)` sizes a page from the bitmap's pixel count at 72 dpi, so a
    /// 150 dpi render silently came out about twice as large on paper. Printing a
    /// compressed A4 scan then produced an oversized page.
    @Test func preservesPageDimensions() async throws {
        let tmp = TempDir()
        let input = tmp.file("scan.pdf")
        TestPDF.write(to: input, withText: false)

        let before = try #require(PDFDocument(url: input)?.page(at: 0)?.bounds(for: .mediaBox))

        let settings = StubSettings()
        settings.compressionQuality = 0.95   // highest dpi, so the worst case for inflation
        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        let after = try #require(PDFDocument(url: output)?.page(at: 0)?.bounds(for: .mediaBox))
        #expect(abs(after.width - before.width) < 1.0)
        #expect(abs(after.height - before.height) < 1.0)
    }

    /// The whole page survives, not just its top-left corner.
    ///
    /// Correcting the page size with `setBounds` crops a bitmap-backed page rather than
    /// scaling it, which produced right-sized pages that had quietly lost most of their
    /// content. Checking dimensions alone does not catch that, so this samples the ink.
    @Test func preservesFullPageContent() async throws {
        let tmp = TempDir()
        let input = tmp.file("scan.pdf")
        TestPDF.write(to: input, withText: false)

        let settings = StubSettings()
        settings.compressionQuality = 0.8
        let service = CompressionService()
        let output = try await service.optimizeImage(at: input, settings: settings.compressionSnapshot)

        let page = try #require(PDFDocument(url: output)?.page(at: 0))
        let box = page.bounds(for: .mediaBox)

        // TestPDF paints an image across the entire page, so every corner carries ink.
        // A cropped page leaves the far corner blank white.
        let width = 200, height = 200
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Sample the bottom-right corner of the page.
        context.translateBy(x: CGFloat(width) - box.width, y: 0)
        page.draw(with: .mediaBox, to: context)

        let pixels = try #require(context.data)
        var inked = 0
        for index in stride(from: 0, to: width * height * 4, by: 4) {
            let byte = pixels.load(fromByteOffset: index, as: UInt8.self)
            if byte < 250 { inked += 1 }
        }
        #expect(inked > width * height / 10, "far corner of the page is blank; content was cropped")
    }

    /// A PDF with a real text layer is refused rather than silently rasterised.
    @Test func refusesPDFWithTextLayer() async throws {
        let tmp = TempDir()
        let input = tmp.file("document.pdf")
        TestPDF.write(to: input, withText: true)

        let service = CompressionService()

        do {
            _ = try await service.optimizeImage(at: input, settings: StubSettings().compressionSnapshot)
            Issue.record("Expected a text PDF to be refused")
        } catch let error as TrimrPixError {
            guard case .pdfHasTextLayer = error else {
                Issue.record("Expected .pdfHasTextLayer, got \(error)")
                return
            }
        }
    }

    /// Refusing a text PDF must leave the original file untouched.
    @Test func refusedPDFIsLeftUnchanged() async throws {
        let tmp = TempDir()
        let input = tmp.file("document.pdf")
        TestPDF.write(to: input, withText: true)
        let before = try Data(contentsOf: input)

        let service = CompressionService()
        _ = try? await service.optimizeImage(at: input, settings: StubSettings().compressionSnapshot)

        #expect(try Data(contentsOf: input) == before)
        // and no sibling output was written
        let siblings = try FileManager.default.contentsOfDirectory(atPath: tmp.url.path)
        #expect(siblings.count == 1)
    }

    /// PDF previews come from the first page, since ImageIO cannot read PDFs.
    @Test func generatesThumbnailForPDF() async throws {
        let tmp = TempDir()
        let input = tmp.file("scan.pdf")
        TestPDF.write(to: input, withText: false)

        let thumb = await ImageItem.loadThumbnail(from: input)
        let unwrapped = try #require(thumb)
        #expect(max(unwrapped.width, unwrapped.height) <= 240)
    }
}
