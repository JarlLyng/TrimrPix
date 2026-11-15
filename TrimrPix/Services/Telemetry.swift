//
//  Telemetry.swift
//  TrimrPix
//
//  Anonymous crash reports, crash-free sessions, MetricKit diagnostics and two
//  feature counts, sent to Sentry (#106). Anonymous is a recipe, not Sentry's
//  default: out of the box sentry-cocoa sends a random installation ID as the user,
//  as every session's `did` and on every metric, plus a hash of the vendor ID on
//  every event. Everything here exists so that no ID, and nothing about the user's
//  images, leaves the Mac. The rules are in SENTRY.md.
//

import Foundation
// sentry-cocoa's static API (SentrySDK.metrics) isn't annotated for Swift 6's
// concurrency checks yet; the SDK is thread-safe.
@preconcurrency import Sentry

enum Telemetry {
    /// The one user every install reports as.
    static let anonymousUser = "anonymous"

    /// The only attributes a metric may carry: the SDK's coarse facts (release,
    /// environment, OS, device model) plus ours. Anything else, `user.id` included,
    /// is dropped in `beforeSendMetric`.
    static let allowedMetricAttributes: Set<String> = [
        "sentry.sdk.name", "sentry.sdk.version", "sentry.environment", "sentry.release",
        "os.name", "os.version", "device.brand", "device.model", "device.family",
        "format",
    ]

    /// The output formats a count may name, and nothing else.
    static let formats: Set<String> = ["jpeg", "png", "gif", "avif", "heic", "pdf"]

    /// Starts Sentry if the build has a DSN. Not under XCTest, where it would only
    /// send the test harness's noise.
    static func start() {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestSessionIdentifier"] != nil {
            return
        }

        let dsn = (environment["SENTRY_DSN"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard dsn.hasPrefix("http") else {
            #if DEBUG
            print("[Sentry] No DSN, so crash reporting is off. Set it in Sentry.xcconfig (SENTRY.md).")
            #endif
            return
        }

        let options = Options()
        options.dsn = dsn
        options.environment = Self.environment
        // Its own folder under Caches, so the installation file pinned below is ours
        // even in a build without the sandbox, where Caches is shared.
        options.cacheDirectoryPath = cacheDirectory.path
        options.sendDefaultPii = false

        // Crashes, hangs, crash-free sessions and MetricKit's diagnostics, nothing more.
        options.enableAutoSessionTracking = true
        options.enableMetricKit = true
        // No performance tracing: the policy names no spans, and the file I/O spans
        // would carry paths.
        options.tracesSampleRate = 0
        options.enableAutoPerformanceTracing = false
        options.enableFileIOTracing = false
        options.enableCoreDataTracing = false
        options.enableNetworkBreadcrumbs = false
        options.enableCaptureFailedRequests = false

        options.beforeSend = { event in anonymize(event) }
        options.beforeBreadcrumb = { breadcrumb in scrub(breadcrumb) }
        options.beforeSendMetric = { metric in anonymize(metric) }

        // Sessions can't be given a user: sentry-cocoa sets every session's `did` from
        // the INSTALLATION file in its cache directory, and writes that file with a
        // random UUID when it's missing. Writing the shared user into it before the SDK
        // starts makes every install report the same `did`. Checked against the outgoing
        // session envelope with sentry-cocoa 9.34.0 (SENTRY.md); check again after
        // every SDK upgrade.
        pinInstallationID(in: cacheDirectory)

        SentrySDK.start(options: options)
        // Before any event or metric, so nothing falls back to an installation ID.
        SentrySDK.setUser(User(userId: anonymousUser))

        #if DEBUG
        SentrySDK.capture(message: "TrimrPix macOS: Sentry test (Debug build)")
        #endif
    }

    // MARK: - Feature counts

    /// One image optimized: a count, and the kilobytes it saved, with its output
    /// format as the only attribute. Never a file name, path, size or anything else
    /// from the image itself.
    static func imageOptimized(fileExtension: String, bytesSaved: Int64) {
        guard SentrySDK.isEnabled else { return }
        let format = formatAttribute(fileExtension)
        SentrySDK.metrics.count(
            "image.optimized", value: 1,
            options: SentryMetricOptions(attributes: ["format": format]))
        SentrySDK.metrics.distribution(
            "image.saved", value: Double(kilobytesSaved(bytesSaved)),
            options: SentryMetricOptions(unit: .kilobyte, attributes: ["format": format]))
    }

    /// The output format from a fixed list; anything else is "other".
    static func formatAttribute(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": "jpeg"
        case "heif", "heic": "heic"
        case let format where formats.contains(format): format
        default: "other"
        }
    }

    /// Whole kilobytes, never negative: a file the size guard kept saved nothing.
    static func kilobytesSaved(_ bytes: Int64) -> Int64 {
        max(0, (bytes + 500) / 1000)
    }

    // MARK: - Environment

    /// `production` only for builds from the App Store, so local, debug and
    /// TestFlight runs aren't read as real crashes. A Mac App Store install has a
    /// receipt; TestFlight's is a sandbox receipt; a local Release build has none.
    static var environment: String {
        #if DEBUG
        return "debug"
        #else
        guard let receipt = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receipt.path) else { return "local" }
        return receipt.lastPathComponent == "sandboxReceipt" ? "testflight" : "production"
        #endif
    }

    // MARK: - Anonymizing

    static var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("com.iamjarl.trimrpix.sentry", isDirectory: true)
    }

    /// Covers errors, crashes and MetricKit diagnostics: one shared user, no device
    /// or vendor-ID hash, and no file path in a message or an exception.
    static func anonymize(_ event: Event) -> Event {
        event.user = User(userId: anonymousUser)
        if var context = event.context {
            context["app"]?.removeValue(forKey: "device_app_hash")
            context["device"]?.removeValue(forKey: "id")
            event.context = context
        }
        if let message = event.message {
            event.message = SentryMessage(formatted: redactPaths(message.formatted))
        }
        event.exceptions?.forEach { exception in
            exception.value = exception.value.map(redactPaths)
        }
        event.breadcrumbs = event.breadcrumbs?.compactMap { scrub($0) }
        // The app's own location on disk travels in the loaded images and the stack
        // frames. It stays (it helps read a crash), but not the user's name in it.
        event.debugMeta?.forEach { $0.codeFile = withoutUserName($0.codeFile) }
        let stacks = (event.exceptions ?? []).compactMap { $0.stacktrace } + (event.threads ?? []).compactMap { $0.stacktrace }
        for frame in stacks.flatMap(\.frames) {
            frame.package = withoutUserName(frame.package)
            frame.fileName = withoutUserName(frame.fileName)
        }
        return event
    }

    /// `/Users/<name>/...` becomes `/Users/<user>/...`; the rest of the path stays.
    static func withoutUserName(_ path: String?) -> String? {
        path?.replacingOccurrences(of: #"/Users/[^/]+"#, with: "/Users/<user>", options: .regularExpression)
    }

    static func scrub(_ breadcrumb: Breadcrumb) -> Breadcrumb? {
        if let message = breadcrumb.message {
            breadcrumb.message = redactPaths(message)
        }
        breadcrumb.data = nil
        return breadcrumb
    }

    static func anonymize(_ metric: SentryMetric) -> SentryMetric {
        var metric = metric
        metric.attributes = allowedAttributes(metric.attributes)
        return metric
    }

    /// Only the attributes on the list, so `user.id` and anything else is dropped.
    static func allowedAttributes<Value>(_ attributes: [String: Value]) -> [String: Value] {
        attributes.filter { allowedMetricAttributes.contains($0.key) }
    }

    /// Replaces anything that looks like a file path or a file URL, so an error that
    /// names an image never sends its name or its folder.
    static func redactPaths(_ text: String) -> String {
        let pattern = #"(file://)?(~|/(Users|Volumes|private|var|tmp|Library|System|Applications))(/[^\s"',:;)\]]*)?"#
        return text.replacingOccurrences(of: pattern, with: "<path>", options: .regularExpression)
    }

    static func pinInstallationID(in directory: URL) {
        let url = directory.appendingPathComponent("INSTALLATION")
        let pinned = Data(anonymousUser.utf8)
        guard (try? Data(contentsOf: url)) != pinned else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? pinned.write(to: url, options: .atomic)
    }
}
