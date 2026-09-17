import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var showEmptyTrashConfirm = false
    @State private var isEmptyingTrash = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statsList
            scanButton
            Divider()
            footer
        }
        .frame(width: 300)
        .onAppear {
            if appState.diskSpace == nil {
                appState.scanAll()
            }
            appState.refreshTrashSize()
        }
        .confirmationDialog(
            "Permanently empty the Trash?",
            isPresented: $showEmptyTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) { performEmptyTrash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("MacClean").fontWeight(.bold)
            }
            Spacer()
            if let disk = appState.diskSpace {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ByteFormat.string(disk.freeBytes) + " free")
                        .font(.caption).fontWeight(.semibold)
                    Text("of \(ByteFormat.string(disk.totalBytes))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var statsList: some View {
        VStack(spacing: 2) {
            statRow(
                title: "Junk Files",
                detail: "\(ByteFormat.string(appState.totalReclaimableJunk)) reclaimable",
                action: "Clean"
            ) {
                appState.selectedSection = .quickClean
                openWindow(id: "dashboard")
            }
            trashRow
            statRow(
                title: "Duplicates",
                detail: "\(ByteFormat.string(appState.totalDuplicateWaste)) wasted",
                action: "Review"
            ) {
                appState.selectedSection = .duplicates
                openWindow(id: "dashboard")
            }
            statRow(
                title: "Updates",
                detail: "\(appState.updates.count) available",
                action: appState.updates.isEmpty ? "" : "\(appState.updates.count)"
            ) {
                appState.selectedSection = .updates
                openWindow(id: "dashboard")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func statRow(title: String, detail: String, action: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12.5, weight: .semibold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if !action.isEmpty {
                    Text(action)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trashRow: some View {
        HStack(spacing: 8) {
            Button {
                appState.selectedSection = .trash
                openWindow(id: "dashboard")
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Trash").font(.system(size: 12.5, weight: .semibold))
                        Text(trashDetail).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if appState.trashAccessDenied {
                Button("Fix Access") {
                    TrashService.shared.openFullDiskAccessSettings()
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(isEmptyingTrash ? "…" : "Empty") {
                    showEmptyTrashConfirm = true
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled((appState.trashSize ?? 0) == 0 || isEmptyingTrash)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }

    private var trashDetail: String {
        if appState.trashAccessDenied {
            return "Needs permission to check"
        }
        if let size = appState.trashSize {
            return size > 0 ? "\(ByteFormat.string(size)) can be freed" : "Empty"
        }
        return "Checking…"
    }

    private func performEmptyTrash() {
        isEmptyingTrash = true
        Task.detached(priority: .userInitiated) {
            TrashService.shared.empty()
            await MainActor.run {
                isEmptyingTrash = false
                appState.refreshTrashSize()
            }
        }
    }

    private var scanButton: some View {
        Button {
            appState.scanAll()
        } label: {
            Text(appState.isScanning ? "Scanning…" : "Scan Now")
                .frame(maxWidth: .infinity)
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(appState.isScanning)
        .padding(12)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            } label: {
                Label("Open MacClean", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(8)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit MacClean", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}
