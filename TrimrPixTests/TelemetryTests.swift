//
//  TelemetryTests.swift
//  TrimrPixTests
//
//  What leaves the Mac when Sentry is on (#106): one shared user, no device or
//  installation ID, no file path, and counts with a fixed list of attributes.
//

import Testing
@testable import TrimrPix
import Foundation
@preconcurrency import Sentry

@Suite("Telemetry")
struct TelemetryTests {

    @Test func anEventCarriesTheSharedUserAndNoDeviceIDs() {
        let event = Event(level: .error)
        event.user = User(userId: "3F2504E0-4F89-11D3-9A0C-0305E82C3301")
        event.context = [
            "app": ["device_app_hash": "a1b2c3", "app_version": "1.8.0"],
            "device": ["id": "device-id", "model": "Mac15,3"],
        ]

        let sent = Telemetry.anonymize(event)

        #expect(sent.user?.userId == "anonymous")
        #expect(sent.context?["app"]?["device_app_hash"] == nil)
        #expect(sent.context?["app"]?["app_version"] as? String == "1.8.0")
        #expect(sent.context?["device"]?["id"] == nil)
        #expect(sent.context?["device"]?["model"] as? String == "Mac15,3")
    }

    @Test func anEventNamesNoFileOrFolder() {
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: "Could not read /Users/jane/Pictures/Holiday/IMG_0042.HEIC")
        let exception = Exception(value: "No such file: file:///Volumes/Photos/scan.pdf", type: "NSError")
        event.exceptions = [exception]
        let crumb = Breadcrumb(level: .info, category: "app")
        crumb.message = "Opened ~/Desktop/secret plans.png"
        crumb.setData(value: "/Users/jane/x.jpg", key: "path")
        event.breadcrumbs = [crumb]

        let sent = Telemetry.anonymize(event)

        #expect(sent.message?.formatted == "Could not read <path>")
        #expect(sent.exceptions?.first?.value == "No such file: <path>")
        #expect(sent.breadcrumbs?.first?.message?.contains("Desktop") == false)
        #expect(sent.breadcrumbs?.first?.data?.isEmpty ?? true)
    }

    @Test func aBreadcrumbCarriesNoDataWhateverItsKeys() throws {
        let crumb = Breadcrumb(level: .info, category: "http")
        crumb.setData(value: "/Users/jane/Pictures/IMG_0042.HEIC", key: "path")
        crumb.setData(value: "3F2504E0-4F89-11D3-9A0C-0305E82C3301", key: "a-key-nobody-planned-for")
        crumb.setData(value: ["nested": "/Users/jane"], key: "context")

        let sent = try #require(Telemetry.scrub(crumb))

        #expect(sent.data?.isEmpty ?? true)
        // What goes in the envelope: no `data` at all.
        #expect(sent.serialize()["data"] == nil)
        #expect(sent.serialize()["category"] as? String == "http")
    }

    @Test func aBreadcrumbWithoutDataStaysWithout() throws {
        let sent = try #require(Telemetry.scrub(Breadcrumb(level: .info, category: "app")))

        #expect(sent.data == nil)
        #expect(sent.serialize()["data"] == nil)
    }

    @Test func theAppsOwnPathLosesTheUserName() {
        let event = Event(level: .fatal)
        let image = DebugMeta()
        image.codeFile = "/Users/jane/Applications/TrimrPix.app/Contents/MacOS/TrimrPix"
        event.debugMeta = [image]
        let frame = Frame()
        frame.package = "/Users/jane/Applications/TrimrPix.app/Contents/MacOS/TrimrPix"
        let thread = SentryThread(threadId: 0)
        thread.stacktrace = SentryStacktrace(frames: [frame], registers: [:])
        event.threads = [thread]

        let sent = Telemetry.anonymize(event)

        #expect(sent.debugMeta?.first?.codeFile == "/Users/<user>/Applications/TrimrPix.app/Contents/MacOS/TrimrPix")
        #expect(sent.threads?.first?.stacktrace?.frames.first?.package?.contains("jane") == false)
        #expect(Telemetry.withoutUserName("/Applications/TrimrPix.app/Contents/MacOS/TrimrPix") == "/Applications/TrimrPix.app/Contents/MacOS/TrimrPix")
    }

    @Test func pathsAreRedactedAndOtherTextIsLeftAlone() {
        #expect(Telemetry.redactPaths("Index out of range") == "Index out of range")
        #expect(Telemetry.redactPaths("at /private/var/folders/xy/T/a.jpg, then") == "at <path>, then")
        #expect(!Telemetry.redactPaths("in /tmp/photo.png").contains("photo"))
    }

    @Test func aMetricKeepsOnlyTheListedAttributes() {
        let attributes: [String: SentryAttributeContent] = [
            "format": .string("jpeg"),
            "os.name": .string("macOS"),
            "user.id": .string("3F2504E0-4F89-11D3-9A0C-0305E82C3301"),
            "file.name": .string("IMG_0042.jpg"),
        ]

        #expect(Set(Telemetry.allowedAttributes(attributes).keys) == ["format", "os.name"])
    }

    @Test func theFormatComesFromAFixedList() {
        #expect(Telemetry.formatAttribute("JPG") == "jpeg")
        #expect(Telemetry.formatAttribute("jpeg") == "jpeg")
        #expect(Telemetry.formatAttribute("heif") == "heic")
        #expect(Telemetry.formatAttribute("pdf") == "pdf")
        #expect(Telemetry.formatAttribute("my-secret-ext") == "other")
    }

    @Test func savingsAreWholeKilobytesAndNeverNegative() {
        #expect(Telemetry.kilobytesSaved(1_499) == 1)
        #expect(Telemetry.kilobytesSaved(1_500) == 2)
        #expect(Telemetry.kilobytesSaved(0) == 0)
        #expect(Telemetry.kilobytesSaved(-4_000) == 0)
    }

    @Test func theInstallationFileHoldsTheSharedUser() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sentry-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // An existing install, with the random ID sentry-cocoa wrote.
        try Data("3F2504E0-4F89-11D3-9A0C-0305E82C3301".utf8).write(to: dir.appendingPathComponent("INSTALLATION"))

        Telemetry.pinInstallationID(in: dir)

        let pinned = try String(contentsOf: dir.appendingPathComponent("INSTALLATION"), encoding: .utf8)
        #expect(pinned == "anonymous")
    }
}
