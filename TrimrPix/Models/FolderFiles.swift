//
//  FolderFiles.swift
//  TrimrPix
//

import Foundation

/// Which files TrimrPix takes from a folder, whether it is watched or dropped in.
enum FolderFiles {

    /// No "webp": macOS cannot write WebP, so those files can only be skipped, and a folder's
    /// worth of them would mean a message for every one. Better not to pick them up.
    static let extensions: Set<String> = ["jpg", "jpeg", "png", "gif", "avif", "heic", "heif", "pdf"]

    /// Whether a file in a folder is one to optimize: a supported type, and not TrimrPix's
    /// own output (`name-optimized.jpg`), which would otherwise be optimized again.
    static func accepts(_ fileName: String) -> Bool {
        let name = fileName as NSString
        return extensions.contains(name.pathExtension.lowercased())
            && !name.deletingPathExtension.contains("-optimized")
    }

    /// The files to optimize in a dropped folder and its subfolders, in the order Finder
    /// lists them. Hidden files are skipped, and so is the inside of a package, such as a
    /// Photos library. Synchronous and possibly slow on a big folder, so run it off the
    /// main actor.
    static func files(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator where accepts(url.lastPathComponent) {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                files.append(url)
            }
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}
