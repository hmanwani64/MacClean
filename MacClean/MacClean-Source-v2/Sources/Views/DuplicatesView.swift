import SwiftUI

struct DuplicatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var lastResultMessage: String?
    @State private var isCleaningAll = false
    @State private var showConfirmAll = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Duplicate Files").font(.title2).bold()
                Text("Found in Downloads, Desktop, Documents, and Pictures. Files are matched by content, not just name.")
                    .foregroundStyle(.secondary)

                if appState.duplicateGroups.isEmpty {
                    Text("No duplicates found yet. Run a scan from the Overview tab.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                } else {
                    HStack {
                        Text("Wasted space: \(ByteFormat.string(appState.totalDuplicateWaste))")
                            .font(.headline)
                        Spacer()
                        Button(isCleaningAll ? "Cleaning…" : "Clean All Duplicates") {
                            showConfirmAll = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCleaningAll)
                    }

                    ForEach(appState.duplicateGroups) { group in
                        groupCard(group)
                    }
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
            "Clean all \(appState.duplicateGroups.count) duplicate groups?",
            isPresented: $showConfirmAll,
            titleVisibility: .visible
        ) {
            Button("Move All Extra Copies to Trash", role: .destructive) { cleanAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("For each group, this keeps the oldest copy and moves the rest to the Trash. You can restore anything from the Trash afterward.")
        }
    }

    private func groupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(group.files.count) copies · \(ByteFormat.string(group.size)) each")
                    .font(.subheadline).bold()
                Spacer()
                Text("Wastes \(ByteFormat.string(group.wastedSpace))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(group.files, id: \.self) { url in
                Text(url.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Button("Keep One, Trash the Rest") {
                trashDuplicates(in: group)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor)))
    }

    private func trashDuplicates(in group: DuplicateGroup) {
        let sorted = group.files.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantFuture
            let d1 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantFuture
            return d0 < d1
        }
        let toTrash = Array(sorted.dropFirst())
        let errors = CacheCleanerService.shared.trash(toTrash)

        appState.duplicateGroups.removeAll { $0.id == group.id }
        appState.refreshTrashSize()
        lastResultMessage = errors.isEmpty
            ? "Moved \(toTrash.count) duplicate(s) to the Trash."
            : "Moved most duplicates to the Trash; \(errors.count) couldn't be removed."
    }

    private func cleanAll() {
        let groups = appState.duplicateGroups
        isCleaningAll = true
        lastResultMessage = "Cleaning \(groups.count) groups… this may take a minute."

        Task.detached(priority: .userInitiated) {
            var totalTrashed = 0
            var totalErrors = 0

            for group in groups {
                let sorted = group.files.sorted {
                    let d0 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantFuture
                    let d1 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantFuture
                    return d0 < d1
                }
                let toTrash = Array(sorted.dropFirst())
                let errors = CacheCleanerService.shared.trash(toTrash)
                totalTrashed += toTrash.count - errors.count
                totalErrors += errors.count
            }

            await MainActor.run {
                appState.duplicateGroups.removeAll()
                isCleaningAll = false
                appState.refreshTrashSize()
                lastResultMessage = totalErrors == 0
                    ? "Moved \(totalTrashed) duplicate file(s) to the Trash across all groups."
                    : "Moved \(totalTrashed) duplicate file(s) to the Trash; \(totalErrors) couldn't be removed."
            }
        }
    }
}
