import Foundation

enum DiskSpaceService {
    /// Reads total/free space for the boot volume. Uses the filesystem attributes API
    /// rather than URLResourceValues so it works without any special entitlement.
    static func currentDiskSpace() -> DiskSpaceInfo? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return nil }
        guard let total = attrs[.systemSize] as? NSNumber,
              let free = attrs[.systemFreeSize] as? NSNumber else { return nil }
        return DiskSpaceInfo(totalBytes: total.int64Value, freeBytes: free.int64Value)
    }
}
