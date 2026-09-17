import Foundation

/// Finds files in the user's home folder that are large and haven't been touched in
/// a while — good candidates for archiving or deleting. Skips ~/Library and the Trash
/// so it never surfaces app internals or things already discarded.
final class LargeOldFilesService {
    static let shared = LargeOldFilesService()

    func find(minimumSize: Int64 = 100 * 1024 * 1024, olderThanDays: Int = 180, progress: ((String) -> Void)? = nil) -> [SizedItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let excluded: Set<String> = ["Library", ".Trash"]
        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date.distantPast

        guard let topLevel = try? FileManager.default.contentsOfDirectory(at: home, includingPropertiesForKeys: nil) else {
            return []
        }

        var results: [SizedItem] = []

        for entry in topLevel where !excluded.contains(entry.lastPathComponent) {
            progress?("Scanning \(entry.lastPathComponent)…")
            guard let enumerator = FileManager.default.enumerator(
                at: entry,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize, Int64(size) >= minimumSize,
                      let modified = values.contentModificationDate, modified < cutoff
                else { continue }
                results.append(SizedItem(url: fileURL, size: Int64(size)))
            }
        }

        return results.sorted { $0.size > $1.size }
    }
}
