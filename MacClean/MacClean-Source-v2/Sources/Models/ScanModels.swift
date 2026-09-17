import Foundation

/// A single file or folder found during a scan, with its size on disk.
struct SizedItem: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
}

/// A group of top-level items (e.g. "App Caches") that Quick Clean can remove together.
struct CleanableCategory: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let urls: [URL]
    var size: Int64
}

/// A set of files that are byte-for-byte identical.
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let size: Int64
    var files: [URL]

    /// Space that would be freed if every copy but one were removed.
    var wastedSpace: Int64 { size * Int64(max(0, files.count - 1)) }
}

/// Leftover support/cache/preference files from an app that is no longer installed.
struct LeftoverAppItem: Identifiable {
    let id = UUID()
    let name: String
    let paths: [URL]
    var totalSize: Int64
}

enum UpdateSource: String {
    case macOS = "macOS"
    case homebrew = "Homebrew"
}

struct UpdateItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let source: UpdateSource
}

struct DiskSpaceInfo {
    let totalBytes: Int64
    let freeBytes: Int64
    var usedBytes: Int64 { totalBytes - freeBytes }
}

/// A snapshot of basic system health: CPU load, memory usage, and battery level.
struct SystemStats {
    let cpuUsagePercent: Double
    let memoryUsedBytes: Int64
    let memoryTotalBytes: Int64
    /// nil on Macs without a battery (Mac mini, Mac Studio, etc.).
    let batteryPercent: Int?
}
