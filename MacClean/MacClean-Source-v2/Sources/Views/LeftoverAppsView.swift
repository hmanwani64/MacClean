import SwiftUI

struct LeftoverAppsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedIDs: Set<UUID> = []
    @State private var showConfirm = false
    @State private var showConfirmAll = false
    @State private var lastResultMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Leftover Apps").font(.title2).bold()
                Text("Support files, caches, and preferences from apps that are no longer installed.")
                    .foregroundStyle(.secondary)

                if appState.leftoverApps.isEmpty {
                    Text("Nothing found yet. Run a scan from the Overview tab.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                } else {
                    Button("Clean All Leftover Apps") {
                        showConfirmAll = true
                    }
                    .buttonStyle(.borderedProminent)

                    ForEach(appState.leftoverApps) { item in
                        itemRow(item)
                    }
                    Button("Move Selected to Trash (\(ByteFormat.string(selectedSize)))") {
                        showConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedIDs.isEmpty)
                }

                if let lastResultMessage {
                    Text(lastResultMessage).foregroundStyle(.secondary).font(.caption)
                }

                EmptyTrashBanner()
            }
            .padding(28)
        }
        .onAppear { appState.refreshTrashSize() }
        .confirmationDialog(
            "Move \(selectedIDs.count) item(s) to the Trash?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { performClean() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Clean all \(appState.leftoverApps.count) leftover apps?",
            isPresented: $showConfirmAll,
            titleVisibility: .visible
        ) {
            Button("Move All to Trash", role: .destructive) { performCleanAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var selectedSize: Int64 {
        appState.leftoverApps.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.totalSize }
    }

    private func itemRow(_ item: LeftoverAppItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 13, weight: .medium))
                Text("\(item.paths.count) file(s)/folder(s)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(ByteFormat.string(item.totalSize)).bold()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
        }
    }

    private func performClean() {
        let items = appState.leftoverApps.filter { selectedIDs.contains($0.id) }
        let urls = items.flatMap { $0.paths }
        let errors = CacheCleanerService.shared.trash(urls)
        appState.leftoverApps.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        appState.refreshTrashSize()
        lastResultMessage = errors.isEmpty
            ? "Moved selected items to the Trash."
            : "\(errors.count) item(s) couldn't be removed."
    }

    private func performCleanAll() {
        let urls = appState.leftoverApps.flatMap { $0.paths }
        let count = appState.leftoverApps.count
        let errors = CacheCleanerService.shared.trash(urls)
        appState.leftoverApps.removeAll()
        selectedIDs.removeAll()
        appState.refreshTrashSize()
        lastResultMessage = errors.isEmpty
            ? "Cleaned all \(count) leftover apps."
            : "Cleaned most leftover apps; \(errors.count) item(s) couldn't be removed."
    }
}
