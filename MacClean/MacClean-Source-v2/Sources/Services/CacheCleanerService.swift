import Foundation

/// Finds and removes caches, logs, and other safe-to-delete junk in the user's own
/// home folder. Deliberately never touches anything outside directories the user
/// owns, and never deletes — everything goes to the Trash so it's reversible.
final class CacheCleanerService {
    static let shared = CacheCleanerService()

    private var candidateDirectories: [(name: String, description: String, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("App Caches", "Cached data written by apps you use.", home.appendingPathComponent("Library/Caches")),
            ("Log Files", "Diagnostic logs apps leave behind.", home.appendingPathComponent("Library/Logs")),
            ("Crash Reports", "Crash and diagnostic reports.", home.appendingPathComponent("Library/Application Support/CrashReporter")),
            ("Saved App States", "Restorable window states for closed apps.", home.appendingPathComponent("Library/Saved Application State"))
        ]
    }

    /// Scans known-safe cache locations plus leftover installers in Downloads.
    func scan(progress: ((String) -> Void)? = nil) -> [CleanableCategory] {
        var results: [CleanableCategory] = []

        for candidate in candidateDirectories {
            progress?("Scanning \(candidate.name)…")
            guard FileManager.default.fileExists(atPath: candidate.url.path) else { continue }
            let children = topLevelChildren(of: candidate.url)
            guard !children.isEmpty else { continue }
            let size = children.reduce(Int64(0)) { $0 + directorySize($1) }
            if size > 0 {
                results.append(CleanableCategory(name: candidate.name, description: candidate.description, urls: children, size: size))
            }
        }

        progress?("Scanning Downloads for installer leftovers…")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads")
        let installers = installerFiles(in: downloads)
        if !installers.isEmpty {
            let size = installers.reduce(Int64(0)) { $0 + fileSize($1) }
            results.append(CleanableCategory(
                name: "Installer Leftovers",
                description: ".dmg and .pkg installers sitting in Downloads.",
                urls: installers,
                size: size
            ))
        }

        return results
    }

    private func installerFiles(in directory: URL) -> [URL] {
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { ["dmg", "pkg"].contains($0.pathExtension.lowercased()) }
    }

    private func topLevelChildren(of directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    private func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    /// Recursively sums the size of a file or folder.
    func directorySize(_ url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return fileSize(url) }

        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return total
    }

    /// Moves each URL to the Trash instead of permanently deleting, so cleanup is always reversible.
    /// Returns any items that couldn't be moved (e.g. in use, or permission-protected), keyed by the error.
    @discardableResult
    func trash(_ urls: [URL]) -> [URL: Error] {
        var errors: [URL: Error] = [:]
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                errors[url] = error
            }
        }
        return errors
    }
}
