import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                systemStatsRow
                diskCard
                summaryGrid
                if appState.isScanning {
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let last = appState.lastScanDate {
                    Text("Last scan: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .onAppear { appState.refreshTrashSize() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview").font(.title2).bold()
                Text("Here's what's using space on your Mac.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.scanAll()
            } label: {
                Label(appState.isScanning ? "Scanning…" : "Scan Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.isScanning)
        }
    }

    @ViewBuilder
    private var systemStatsRow: some View {
        if let stats = appState.systemStats {
            HStack(spacing: 12) {
                statPill(icon: "cpu", label: "CPU", value: "\(Int(stats.cpuUsagePercent.rounded()))%")
                statPill(
                    icon: "memorychip",
                    label: "Memory",
                    value: "\(ByteFormat.string(stats.memoryUsedBytes)) of \(ByteFormat.string(stats.memoryTotalBytes))"
                )
                if let battery = stats.batteryPercent {
                    statPill(icon: "battery.100", label: "Battery", value: "\(battery)%")
                }
                Spacer()
            }
        }
    }

    private func statPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(label).foregroundStyle(.secondary)
            Text(value).bold()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
    }

    private var diskCard: some View {
        HStack(spacing: 32) {
            diskDonut
            VStack(alignment: .leading, spacing: 10) {
                legendRow(color: .red, label: "Reclaimable junk", value: appState.totalReclaimableJunk)
                legendRow(color: .orange, label: "Large & old files", value: appState.totalLargeOldSize)
                legendRow(color: .purple, label: "Duplicate waste", value: appState.totalDuplicateWaste)
                if let disk = appState.diskSpace {
                    let accountedFor = appState.totalReclaimableJunk + appState.totalLargeOldSize + appState.totalDuplicateWaste
                    legendRow(color: .gray, label: "Everything else", value: max(0, disk.usedBytes - accountedFor))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor)))
    }

    private var diskDonut: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .separatorColor), lineWidth: 18)
            if let disk = appState.diskSpace, disk.totalBytes > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(disk.usedBytes) / CGFloat(disk.totalBytes))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                if let disk = appState.diskSpace {
                    Text(ByteFormat.string(disk.freeBytes)).font(.title3).bold()
                    Text("free of \(ByteFormat.string(disk.totalBytes))").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("—").font(.title3)
                }
            }
        }
        .frame(width: 170, height: 170)
    }

    private func legendRow(color: Color, label: String, value: Int64) -> some View {
        HStack {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
            Spacer(minLength: 20)
            Text(ByteFormat.string(value)).bold()
        }
        .font(.system(size: 13))
        .frame(width: 260, alignment: .leading)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            SummaryCard(
                icon: "sparkles", tint: .red,
                title: "Junk Files",
                value: ByteFormat.string(appState.totalReclaimableJunk),
                detail: "Caches, logs, and temporary files safe to remove.",
                actionTitle: "Clean Now"
            ) { appState.selectedSection = .quickClean }

            SummaryCard(
                icon: "doc.on.doc", tint: .blue,
                title: "Duplicate Files",
                value: ByteFormat.string(appState.totalDuplicateWaste),
                detail: "\(appState.duplicateGroups.reduce(0) { $0 + $1.files.count }) files in \(appState.duplicateGroups.count) groups.",
                actionTitle: "Review"
            ) { appState.selectedSection = .duplicates }

            SummaryCard(
                icon: "archivebox", tint: .orange,
                title: "Large & Old Files",
                value: ByteFormat.string(appState.totalLargeOldSize),
                detail: "Not opened in 6+ months and over 100 MB.",
                actionTitle: "Review"
            ) { appState.selectedSection = .largeOldFiles }

            SummaryCard(
                icon: "arrow.triangle.2.circlepath", tint: .green,
                title: "Software Updates",
                value: "\(appState.updates.count) available",
                detail: "macOS and Homebrew updates.",
                actionTitle: "View Updates"
            ) { appState.selectedSection = .updates }

            SummaryCard(
                icon: "trash", tint: .gray,
                title: "Trash",
                value: trashCardValue,
                detail: trashCardDetail,
                actionTitle: trashCardActionTitle
            ) { appState.selectedSection = .trash }
        }
    }

    private var trashCardValue: String {
        if appState.trashAccessDenied { return "—" }
        guard let size = appState.trashSize else { return "Checking…" }
        return ByteFormat.string(size)
    }

    private var trashCardDetail: String {
        if appState.trashAccessDenied {
            return "MacClean needs Full Disk Access to see what's in the Trash."
        }
        return "Already moved out of the way, but not freed until you empty it."
    }

    private var trashCardActionTitle: String {
        appState.trashAccessDenied ? "Fix Access" : "Review"
    }
}

private struct SummaryCard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).foregroundStyle(tint)
                }
                Spacer()
                Text(value).font(.system(size: 18, weight: .bold))
            }
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor)))
    }
}
