import Foundation
import CryptoKit

/// Finds byte-for-byte duplicate files across a set of folders. Groups candidates by
/// file size first (cheap), then confirms matches within each group with a SHA-256
/// hash of the full file contents — never trusts name or size alone.
final class DuplicateFinderService {
    static let shared = DuplicateFinderService()

    func defaultSearchFolders() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Pictures")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func findDuplicates(in folders: [URL], progress: ((String) -> Void)? = nil) -> [DuplicateGroup] {
        var bySize: [Int64: [URL]] = [:]

        for folder in folders {
            progress?("Indexing \(folder.lastPathComponent)…")
            guard let enumerator = FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let size = values.fileSize, size > 0 else { continue }
                bySize[Int64(size), default: []].append(fileURL)
            }
        }

        var groups: [DuplicateGroup] = []
        let candidates = bySize.filter { $0.value.count > 1 }

        for (size, urls) in candidates {
            progress?("Comparing \(urls.count) files of the same size…")
            var byHash: [String: [URL]] = [:]
            for url in urls {
                guard let hash = sha256(of: url) else { continue }
                byHash[hash, default: []].append(url)
            }
            for (_, matching) in byHash where matching.count > 1 {
                groups.append(DuplicateGroup(size: size, files: matching))
            }
        }

        return groups.sorted { $0.wastedSpace > $1.wastedSpace }
    }

    private func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
