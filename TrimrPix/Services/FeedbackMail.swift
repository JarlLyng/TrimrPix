//
//  FeedbackMail.swift
//  TrimrPix
//

import Foundation

/// The email behind Help › Send Feedback….
///
/// TrimrPix sends nothing itself. Opening the URL hands the message to the user's mail app,
/// where they see all of it, the version lines included, before deciding to send.
enum FeedbackMail {
    static let address = "support@iamjarl.com"

    /// The mailto URL for a given app and system version.
    static func url(appVersion: String, build: String, systemVersion: String) -> URL {
        let subject = "TrimrPix \(appVersion) feedback"
        // Blank lines first, so the message is written above the version lines.
        let body = "\n\n\n---\nTrimrPix \(appVersion) (\(build))\nmacOS \(systemVersion)\n"
        let string = "mailto:\(address)?subject=\(encode(subject))&body=\(encode(body))"
        // Every value is percent-encoded down to the unreserved set, so this cannot fail.
        return URL(string: string)!
    }

    /// The mailto URL for the running app on this Mac.
    static var current: URL {
        let info = Bundle.main.infoDictionary
        return url(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            build: info?["CFBundleVersion"] as? String ?? "unknown",
            systemVersion: systemVersionString(ProcessInfo.processInfo.operatingSystemVersion)
        )
    }

    /// "26.0" rather than "26.0.0", the way macOS itself names a release.
    static func systemVersionString(_ version: OperatingSystemVersion) -> String {
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion == 0 ? base : "\(base).\(version.patchVersion)"
    }

    /// RFC 6068 percent-encoding. Only the unreserved ASCII set is left as it is, so spaces,
    /// newlines, non-ASCII letters and any `&`, `=` or `+` in a value cannot change how the
    /// URL is read. (`CharacterSet.alphanumerics` would let non-ASCII letters through.)
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
