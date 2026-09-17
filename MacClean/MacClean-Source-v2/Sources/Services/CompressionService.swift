import Foundation

/// Transparently compresses large files and folders in place using macOS's
/// own built-in HFS+/APFS compression — the same technology Apple uses for
/// its own system files. A compressed item keeps the exact same name and
/// location: Finder, Preview, and every other app opens it completely
/// normally, and the OS quietly decompresses it on the fly when it's read.
/// No extra tools or installs are needed — this uses `ditto`, which ships
/// with every Mac.
final class CompressionService {
    static let shared = CompressionService()

    struct Result {
        /// URLs that were successfully compressed in place (safe to drop from a "large files" list).
        var compressedURLs: Set<URL> = []
        var bytesSaved: Int64 = 0
        /// Items left untouched because compressing them didn't meaningfully shrink them
        /// (already-compressed formats like photos, videos, zips).
        var skippedCount = 0
        var errors: [URL: String] = [:]
    }

    /// Compresses each URL in place, one at a time. Safe to call from a background thread.
    func compress(_ urls: [URL], progress: ((String) -> Void)? = nil) -> Result {
        var result = Result()

        for url in urls {
            progress?("Compressing \(url.lastPathComponent)…")

            let originalSize = CacheCleanerService.shared.directorySize(url)
            guard originalSize > 0 else { continue }

            let tempDest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["--hfsCompression", url.path, tempDest.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                result.errors[url] = error.localizedDescription
                try? FileManager.default.removeItem(at: tempDest)
                continue
            }

            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: tempDest.path) else {
                result.errors[url] = "ditto failed"
                try? FileManager.default.removeItem(at: tempDest)
                continue
            }

            let compressedSize = CacheCleanerService.shared.directorySize(tempDest)

            // Only keep the compressed copy if it's meaningfully smaller. If it's not,
            // the file's contents are already compressed (photos, videos, archives) —
            // swapping it in would just waste time and disk churn for no benefit.
            guard compressedSize > 0, compressedSize < Int64(Double(originalSize) * 0.95) else {
                try? FileManager.default.removeItem(at: tempDest)
                result.skippedCount += 1
                continue
            }

            do {
                // Trash the original (reversible, never a permanent delete), then move the
                // compressed version into that exact same spot — nothing about how you find
                // or open the file changes afterward.
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                try FileManager.default.moveItem(at: tempDest, to: url)
                result.compressedURLs.insert(url)
                result.bytesSaved += (originalSize - compressedSize)
            } catch {
                result.errors[url] = error.localizedDescription
                try? FileManager.default.removeItem(at: tempDest)
            }
        }

        return result
    }
}
