//
//  FeedbackMailTests.swift
//  TrimrPixTests
//

import Foundation
import Testing
@testable import TrimrPix

@Suite("FeedbackMail")
struct FeedbackMailTests {

    /// Decodes a mailto URL the way a mail app reads it.
    private func parts(_ url: URL) throws -> (to: String, items: [String: String], count: Int) {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        return (components.path, Dictionary(items.map { ($0.name, $0.value ?? "") }) { a, _ in a }, items.count)
    }

    @Test func addressesTheSupportInbox() throws {
        let url = FeedbackMail.url(appVersion: "1.7.2", build: "27", systemVersion: "26.0")
        #expect(url.scheme == "mailto")
        #expect(try parts(url).to == "support@iamjarl.com")
    }

    @Test func subjectAndBodyCarryTheVersions() throws {
        let url = FeedbackMail.url(appVersion: "1.7.2", build: "27", systemVersion: "26.0.1")
        let p = try parts(url)
        #expect(p.items["subject"] == "TrimrPix 1.7.2 feedback")
        let body = try #require(p.items["body"])
        #expect(body.contains("TrimrPix 1.7.2 (27)"))
        #expect(body.contains("macOS 26.0.1"))
        // Room to write comes first; the version lines sit underneath.
        #expect(body.hasPrefix("\n\n"))
    }

    @Test func awkwardCharactersCannotBreakTheURL() throws {
        let version = "1.0 beta&cc=x@y.z+é"
        let url = FeedbackMail.url(appVersion: version, build: "1", systemVersion: "26.0")
        let raw = url.absoluteString
        #expect(!raw.contains(" "))
        #expect(!raw.contains("\n"))
        let p = try parts(url)
        // An unencoded & would have added a third field (a cc, here).
        #expect(p.count == 2)
        #expect(p.items["cc"] == nil)
        #expect(p.items["subject"] == "TrimrPix \(version) feedback")
    }

    @Test func systemVersionDropsAZeroPatch() {
        #expect(FeedbackMail.systemVersionString(.init(majorVersion: 26, minorVersion: 0, patchVersion: 0)) == "26.0")
        #expect(FeedbackMail.systemVersionString(.init(majorVersion: 15, minorVersion: 2, patchVersion: 1)) == "15.2.1")
    }

    @Test func currentUsesThisBundleAndSystem() throws {
        let p = try parts(FeedbackMail.current)
        #expect(p.to == "support@iamjarl.com")
        let os = FeedbackMail.systemVersionString(ProcessInfo.processInfo.operatingSystemVersion)
        #expect(try #require(p.items["body"]).contains("macOS \(os)"))
    }
}
