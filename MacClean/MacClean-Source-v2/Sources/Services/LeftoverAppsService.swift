import Foundation

/// Finds support/cache/preference files left behind by apps that are no longer
/// installed. Matches by bundle identifier (e.g. "com.company.AppName"), comparing
/// what's on disk against every .app currently in /Applications and ~/Applications.
final class LeftoverAppsService {
    static let shared = LeftoverAppsService()

    private func installedBundleIdentifiers() -> Set<String> {
        var ids = Set<String>()
        let appDirs = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        for dir in appDirs {
            guard let apps = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for app in apps where app.hasSuffix(".app") {
                let plistURL = URL(fileURLWithPath: dir)
                    .appendingPathComponent(app)
                    .appendingPathComponent("Contents/Info.plist")
                if let data = try? Data(contentsOf: plistURL),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let bundleID = plist["CFBundleIdentifier"] as? String {
                    ids.insert(bundleID.lowercased())
                }
            }
        }
        return ids
    }

    func findLeftovers(progress: ((String) -> Void)? = nil) -> [LeftoverAppItem] {
        let installed = installedBundleIdentifiers()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let scanDirs = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Saved Application State")
        ]

        var grouped: [String: [URL]] = [:]

        for dir in scanDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items {
                let name = item.deletingPathExtension().lastPathComponent
                guard looksLikeBundleIdentifier(name) else { continue }
                // Never flag Apple's own built-in components — they're part of macOS
                // itself and never show up as an app in /Applications, even though
                // they're very much still in use.
                guard !name.lowercased().hasPrefix("com.apple.") else { continue }
                progress?("Checking \(name)…")
                if !installed.contains(name.lowercased()) {
                    grouped[name, default: []].append(item)
                }
            }
        }

        return grouped.map { name, paths in
            let total = paths.reduce(Int64(0)) { $0 + CacheCleanerService.shared.directorySize($1) }
            return LeftoverAppItem(name: name, paths: paths, totalSize: total)
        }.sorted { $0.totalSize > $1.totalSize }
    }

    /// A crude but safe filter: only flag reverse-DNS style names (com./org./net. with
    /// at least two dots), since those are almost always third-party bundle identifiers
    /// rather than system components.
    private func looksLikeBundleIdentifier(_ name: String) -> Bool {
        let parts = name.split(separator: ".")
        guard parts.count >= 3, !name.contains(" ") else { return false }
        return name.hasPrefix("com.") || name.hasPrefix("org.") || name.hasPrefix("net.")
    }
}
