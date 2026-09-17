import Combine
import Foundation
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case quickClean = "Quick Clean"
    case duplicates = "Duplicates"
    case largeOldFiles = "Large & Old Files"
    case leftoverApps = "Leftover Apps"
    case updates = "Software Updates"
    case trash = "Trash"
    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: DashboardSection? = .overview
    @Published var diskSpace: DiskSpaceInfo?
    @Published var systemStats: SystemStats?
    @Published var cleanableCategories: [CleanableCategory] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var largeOldFiles: [SizedItem] = []
    @Published var leftoverApps: [LeftoverAppItem] = []
    @Published var updates: [UpdateItem] = []
    @Published var trashSize: Int64?
    @Published var trashAccessDenied = false
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    @Published var statusMessage: String = ""

    func scanAll() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Starting scan…"

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let disk = DiskSpaceService.currentDiskSpace()
            let stats = SystemMonitorService.shared.currentStats()
            let cache = CacheCleanerService.shared.scan { msg in
                Task { @MainActor in self.statusMessage = msg }
            }
            let dupes = DuplicateFinderService.shared.findDuplicates(
                in: DuplicateFinderService.shared.defaultSearchFolders()
            ) { msg in
                Task { @MainActor in self.statusMessage = msg }
            }
            let largeOld = LargeOldFilesService.shared.find { msg in
                Task { @MainActor in self.statusMessage = msg }
            }
            let leftovers = LeftoverAppsService.shared.findLeftovers { msg in
                Task { @MainActor in self.statusMessage = msg }
            }

            await MainActor.run {
                self.diskSpace = disk
                self.systemStats = stats
                self.cleanableCategories = cache
                self.duplicateGroups = dupes
                self.largeOldFiles = largeOld
                self.leftoverApps = leftovers
                self.isScanning = false
                self.lastScanDate = Date()
                self.statusMessage = "Scan complete."
                self.refreshTrashSize()
            }

            SoftwareUpdateService.shared.checkAll { items in
                Task { @MainActor in self.updates = items }
            }
        }
    }

    /// Recomputes how much is currently sitting in the Trash. Cheap enough to call
    /// after any action that moves items there, or whenever the Trash view appears.
    func refreshTrashSize() {
        Task.detached(priority: .utility) { [weak self] in
            let status = TrashService.shared.status()
            await MainActor.run {
                self?.trashSize = status.size
                self?.trashAccessDenied = status.accessDenied
            }
        }
    }

    var totalReclaimableJunk: Int64 {
        cleanableCategories.reduce(0) { $0 + $1.size }
    }

    var totalDuplicateWaste: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    var totalLargeOldSize: Int64 {
        largeOldFiles.reduce(0) { $0 + $1.size }
    }
}
