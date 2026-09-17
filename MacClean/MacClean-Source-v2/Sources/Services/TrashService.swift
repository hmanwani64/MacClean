import AppKit
import Foundation

/// What MacClean found when it looked at the Trash.
struct TrashStatus {
    var size: Int64 = 0
    var itemCount: Int = 0
    /// True if macOS refused to let MacClean look inside the Trash folder at all
    /// (rather than the Trash genuinely being empty). This happens when the app
    /// hasn't been granted Full Disk Access — without it, macOS silently hides
    /// the Trash's contents instead of showing an error, which is why the fix
    /// is a System Settings toggle, not a code change.
    var accessDenied = false
}

/// Reads and empties everything macOS considers "the Trash."
///
/// This isn't just `~/.Trash` — Finder blends together a couple of locations
/// into the one Trash icon you see in the Dock:
///   • `~/.Trash` — anything deleted from a normal folder on your main disk.
///   • `.Trashes/<your user id>` on any other mounted disk (an external
///     drive, etc.) — each disk keeps its own Trash.
/// Both are also subject to macOS's Full Disk Access protection: unless
/// MacClean has been granted that permission in System Settings, macOS quietly
/// hides what's in them instead of raising an error, which looks identical to
/// the Trash being empty. `status()` tells the two apart so the UI can ask for
/// the permission instead of just being wrong.
///
/// Everywhere else in MacClean, "clean" means *move to Trash* — safe and
/// reversible. This service is the one place that actually deletes data for
/// good, which is why every call site keeps it behind an explicit
/// confirmation dialog in the UI.
final class TrashService {
    static let shared = TrashService()

    /// Every Trash-like location macOS might currently be using, that actually exists on disk.
    private func candidateTrashDirectories() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var candidates: [URL] = [home.appendingPathComponent(".Trash")]

        // Any other mounted volume (external drive, etc.) keeps its own Trash.
        let uid = getuid()
        if let volumes = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: nil) {
            for volume in volumes {
                candidates.append(volume.appendingPathComponent(".Trashes/\(uid)"))
            }
        }

        return candidates.filter { fm.fileExists(atPath: $0.path) }
    }

    /// Lists one Trash directory's contents. Throws (rather than silently returning
    /// empty) so callers can tell "genuinely empty" apart from "macOS said no."
    private func topLevelItems(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    }

    /// Everything currently in the Trash, or a note that macOS wouldn't say.
    func status() -> TrashStatus {
        var result = TrashStatus()
        for directory in candidateTrashDirectories() {
            do {
                let items = try topLevelItems(in: directory)
                result.itemCount += items.count
                result.size += items.reduce(Int64(0)) { $0 + CacheCleanerService.shared.directorySize($1) }
            } catch {
                result.accessDenied = true
            }
        }
        return result
    }

    /// Permanently deletes everything in the Trash, across every location macOS uses for it.
    /// Returns any items that couldn't be removed (e.g. still open in another app, or Full
    /// Disk Access hasn't been granted), keyed by the error.
    @discardableResult
    func empty() -> [URL: Error] {
        var errors: [URL: Error] = [:]
        for directory in candidateTrashDirectories() {
            guard let items = try? topLevelItems(in: directory) else { continue }
            for item in items {
                do {
                    try FileManager.default.removeItem(at: item)
                } catch {
                    errors[item] = error
                }
            }
        }
        return errors
    }

    /// Opens System Settings directly to the Full Disk Access pane, so granting
    /// the permission is a couple of clicks rather than a hunt through menus.
    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
