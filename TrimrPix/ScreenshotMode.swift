//
//  ScreenshotMode.swift
//  TrimrPix
//
//  A launch mode for the website's captures (#86). Debug builds only: none of this ships.
//

#if DEBUG
import AppKit
import Foundation

/// Opens the window in a known state, so it can be photographed for the website.
///
/// Drag and drop can't be scripted, so without this the window can only be staged by hand.
/// Launched with a folder, the app opens with that folder's images in the list, can press
/// Optimize All and open Settings (scrolled to its end with `-screenshotSettingsAtEnd YES`),
/// and shows itself in light appearance, as the site is:
///
///     open -n TrimrPix.app --args -screenshotFolder ~/capture \
///       -screenshotOptimize YES -screenshotWindowSize 1000x711 \
///       -resizeEnabled YES -maxDimension 2048 -AppleLocale en_US -AppleLanguages '(en)'
///
/// 1000x711 is the site tour's shape (height 0.711 of the width) and holds the 700-point
/// Settings sheet. The window goes to the sharpest screen, so `screencapture -o -l <window>`
/// gives a 2x capture with the sheet included. macOS only lets the app come to the front
/// while the app it was launched from is in front; otherwise it is captured inactive.
///
/// The app is sandboxed, so it can read and write the folder only in a build without the
/// sandbox: `xcodebuild -configuration Debug ENABLE_APP_SANDBOX=NO CODE_SIGN_ENTITLEMENTS= build`.
///
/// Settings come from a store of their own that is emptied at every launch, so the mode
/// never reads or changes the user's settings, which a Debug build shares with the App Store
/// build. A setting can still be given as an argument under its own key, as above. The mode
/// never starts Watch Folder. With auto-save on (the default) the optimized copies are
/// written beside the originals, so give it a copy of the images.
struct ScreenshotMode: Sendable {
    let folder: URL
    let optimize: Bool
    let showsSettings: Bool
    let settingsAtEnd: Bool
    let windowSize: CGSize?

    /// The mode the app was launched in, or nil for a normal launch.
    static let current: ScreenshotMode? = {
        let arguments = UserDefaults.standard
        guard let path = arguments.string(forKey: "screenshotFolder") else { return nil }
        let size = arguments.string(forKey: "screenshotWindowSize")?
            .split(separator: "x")
            .compactMap { Double($0) }
        return ScreenshotMode(
            folder: URL(fileURLWithPath: (path as NSString).expandingTildeInPath),
            optimize: arguments.bool(forKey: "screenshotOptimize"),
            showsSettings: arguments.bool(forKey: "screenshotSettings"),
            settingsAtEnd: arguments.bool(forKey: "screenshotSettingsAtEnd"),
            windowSize: size?.count == 2 ? CGSize(width: size![0], height: size![1]) : nil
        )
    }()

    private static let settingsSuite = "com.iamjarl.trimrpix.screenshots"

    /// A settings store holding nothing but what the launch arguments give.
    static func emptySettings() -> UserDefaults {
        let defaults = UserDefaults(suiteName: settingsSuite)!
        defaults.removePersistentDomain(forName: settingsSuite)
        return defaults
    }

    /// The folder's files, in the order Finder lists them by name.
    private var imageURLs: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    @MainActor
    func stage(_ viewModel: ImageOptimizationViewModel) {
        NSApp.appearance = NSAppearance(named: .aqua)
        if let windowSize, let window = NSApp.windows.first(where: { $0.isVisible }) {
            // Centred on the sharpest screen, so a capture comes out at 2x on any desk.
            let screen = NSScreen.screens.max { $0.backingScaleFactor < $1.backingScaleFactor }
            if let visible = screen?.visibleFrame {
                let size = window.frameRect(forContentRect: CGRect(origin: .zero, size: windowSize)).size
                let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
                window.setFrame(CGRect(origin: origin, size: size), display: true)
            }
        }
        // In front, so the capture shows the window as it looks in use.
        NSApp.activate()
        viewModel.images = imageURLs.compactMap { try? ImageItem(url: $0) }
        if optimize {
            viewModel.optimizeAllImages()
        }
        if settingsAtEnd {
            Task { await scrollSettingsToEnd() }
        }
    }

    /// Scrolls Settings to its end once the sheet is up, where Watch Folder is.
    @MainActor
    private func scrollSettingsToEnd() async {
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            guard let sheet = NSApp.windows.first(where: { $0.sheetParent != nil }),
                  let content = sheet.contentView,
                  let scrollView = Self.scrollViews(in: content).max(by: { $0.frame.height < $1.frame.height }),
                  let document = scrollView.documentView,
                  document.bounds.height > scrollView.contentView.bounds.height
            else { continue }
            let clip = scrollView.contentView
            let end = document.isFlipped ? document.bounds.height - clip.bounds.height : 0
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: end))
            scrollView.reflectScrolledClipView(clip)
            return
        }
    }

    @MainActor
    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}
#endif
