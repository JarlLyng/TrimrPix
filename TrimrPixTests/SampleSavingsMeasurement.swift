//
//  SampleSavingsMeasurement.swift
//  TrimrPixTests
//

import CryptoKit
import Foundation
import Testing
@testable import TrimrPix

/// Measures the saving the site states as its big number (issue #86), with the app's own
/// compression, so the number is what TrimrPix does and not an estimate.
///
/// It runs only when given a folder, so CI skips it:
///
///     TEST_RUNNER_SAMPLE_DIR=/path/to/sample TEST_RUNNER_SAMPLE_OUT=/path/to/report \
///       xcodebuild test -project TrimrPix.xcodeproj -scheme TrimrPix -destination 'platform=macOS' \
///       -only-testing:TrimrPixTests/SampleSavingsMeasurement
///
/// The two variables go in xcodebuild's environment, before the command, not as arguments after
/// it: there they would be build settings, and the test would skip.
///
/// The folder is copied first and the originals are never touched. Every file is optimized at
/// the settings below, which are the app's defaults, written out here so a later run uses the
/// same ones. A file the app refuses (WebP, a PDF with text) counts as unchanged, and so does
/// one the size guard keeps, because that is what the user ends up with.
///
/// The report directory gets report.md, report.json (every file, its SHA-256 and its size before
/// and after, so a re-run can prove it measured the same folder) and the optimized files.
@Suite("Sample savings measurement", .serialized)
struct SampleSavingsMeasurement {

    static let environment = ProcessInfo.processInfo.environment

    /// The app's defaults: the Medium preset, PNG quantization on, no resize, saved beside the
    /// original. Metadata is always stripped; it has no setting. TEST_RUNNER_SAMPLE_MAX_DIMENSION
    /// turns on the app's optional downscale to that many pixels on the long side, for measuring
    /// the web workflow; leave it unset for the defaults.
    static let maxDimension = environment["SAMPLE_MAX_DIMENSION"].flatMap(Int.init)
    static let settings = CompressionSettings(
        compressionQuality: CompressionPreset.medium.quality,
        pngQuantizationEnabled: true,
        resizeEnabled: maxDimension != nil,
        maxDimension: maxDimension ?? 2048,
        overwriteOriginal: false,
        autoSave: true
    )
    static let settingsDescription = "Medium (80%), PNG quantization on, "
        + (maxDimension.map { "resized to \($0) px on the long side" } ?? "no resize")
        + ", metadata stripped"

    struct Row: Codable {
        let file: String
        let sha256: String
        let before: Int
        let after: Int
        let outcome: String
    }

    @Test(.enabled(if: environment["SAMPLE_DIR"] != nil, "set TEST_RUNNER_SAMPLE_DIR to measure"))
    func measure() async throws {
        let fm = FileManager.default
        let source = URL(fileURLWithPath: try #require(Self.environment["SAMPLE_DIR"]))
        let out = URL(fileURLWithPath: Self.environment["SAMPLE_OUT"]
            ?? fm.temporaryDirectory.appendingPathComponent("trimrpix-measurement").path)
        let work = fm.temporaryDirectory.appendingPathComponent("trimrpix-sample-\(UUID().uuidString)")
        try? fm.removeItem(at: out)
        try fm.createDirectory(at: out.appendingPathComponent("optimized"), withIntermediateDirectories: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let names = try fm.contentsOfDirectory(atPath: source.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
        #expect(!names.isEmpty, "the sample folder is empty")

        let service = CompressionService()
        var rows: [Row] = []
        for name in names {
            let original = source.appendingPathComponent(name)
            let copy = work.appendingPathComponent(name)
            try fm.copyItem(at: original, to: copy)
            let data = try Data(contentsOf: original)
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            do {
                let result = try await service.optimizeImage(at: copy, settings: Self.settings)
                let after = try fm.attributesOfItem(atPath: result.path)[.size] as? Int ?? data.count
                try? fm.copyItem(at: result, to: out.appendingPathComponent("optimized").appendingPathComponent(result.lastPathComponent))
                rows.append(Row(file: name, sha256: hash, before: data.count, after: after,
                                outcome: after < data.count ? "smaller" : "kept original"))
            } catch {
                rows.append(Row(file: name, sha256: hash, before: data.count, after: data.count,
                                outcome: "refused: \(error.localizedDescription)"))
            }
        }

        let before = rows.reduce(0) { $0 + $1.before }
        let after = rows.reduce(0) { $0 + $1.after }
        let saving = before > 0 ? 100.0 * Double(before - after) / Double(before) : 0
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        let summary: [String: Any] = [
            "measured": ISO8601DateFormatter().string(from: Date()),
            "app": "\(version) (\(build))",
            "settings": Self.settingsDescription,
            "files": rows.count,
            "bytesBefore": before,
            "bytesAfter": after,
            "savingPercent": (saving * 10).rounded() / 10,
        ]
        let json = try JSONSerialization.data(
            withJSONObject: ["summary": summary,
                             "files": try rows.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }],
            options: [.prettyPrinted, .sortedKeys])
        try json.write(to: out.appendingPathComponent("report.json"))

        func mb(_ b: Int) -> String { String(format: "%.2f MB", Double(b) / 1_000_000) }
        var md = "# Sample savings\n\n"
        md += "**−\(String(format: "%.0f", saving)) %**: \(rows.count) files, \(mb(before)) → \(mb(after)).\n\n"
        md += "App \(version) (\(build)). Settings: \(summary["settings"]!).\n\n"
        md += "| File | Before | After | Saving | Outcome |\n|---|---:|---:|---:|---|\n"
        for r in rows {
            let pct = r.before > 0 ? 100.0 * Double(r.before - r.after) / Double(r.before) : 0
            md += "| \(r.file) | \(mb(r.before)) | \(mb(r.after)) | \(String(format: "%.0f", pct)) % | \(r.outcome) |\n"
        }
        try md.write(to: out.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)
        print("SAMPLE-SAVINGS: −\(String(format: "%.1f", saving)) % over \(rows.count) files (\(mb(before)) → \(mb(after))). Report: \(out.path)")
    }
}
