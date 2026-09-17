import SwiftUI

struct LargeOldFilesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedIDs: Set<UUID> = []
    @State private var showConfirm = false
    @State private var lastResultMessage: String?
    @State private var isCompressing = false
    @State private var compressionStatus: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Large & Old Files").font(.title2).bold()
                Text("Over 100 MB and untouched for 6+ months. Only your home folder is scanned — never ~/Library or system files.")
                    .foregroundStyle(.secondary)

                if appState.largeOldFiles.isEmpty {
                    Text("Nothing found yet. Run a scan from the Overview tab.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                } else {
                    HStack {
                        Button("Select All") {
                            selectedIDs = Set(appState.largeOldFiles.map { $0.id })
                        }
                        .buttonStyle(.bordered)
                        Button("Deselect All") {
                            selectedIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }

                    ForEach(appState.largeOldFiles) { item in
                        fileRow(item)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button("Compress Selected (\(ByteFormat.string(selectedSize)))") {
                                performCompress()
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedIDs.isEmpty || isCompressing)

                            Button("Move Selected to Trash (\(ByteFormat.string(selectedSize)))") {
                                showConfirm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedIDs.isEmpty || isCompressing)
                        }
                        Text("Compressing keeps files exactly where they are, under the same name — every app still opens them normally. macOS just stores them more efficiently on disk. Works best on documents, logs, and uncompressed images; files that are already compressed (like most videos and photos) won't shrink much.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isCompressing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(compressionStatus ?? "Compressing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            "Move \(selectedIDs.count) file(s) to the Trash?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { performClean() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var selectedSize: Int64 {
        appState.largeOldFiles.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private func fileRow(_ item: SizedItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent).font(.system(size: 13, weight: .medium))
                Text(item.url.deletingLastPathComponent().path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormat.string(item.size)).bold()
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
        let items = appState.largeOldFiles.filter { selectedIDs.contains($0.id) }
        let errors = CacheCleanerService.shared.trash(items.map { $0.url })
        appState.largeOldFiles.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        appState.refreshTrashSize()
        lastResultMessage = errors.isEmpty
            ? "Moved the selected files to the Trash."
            : "Moved most files to the Trash; \(errors.count) couldn't be removed."
    }

    private func performCompress() {
        let items = appState.largeOldFiles.filter { selectedIDs.contains($0.id) }
        let urls = items.map { $0.url }
        isCompressing = true
        compressionStatus = "Starting…"

        Task.detached(priority: .userInitiated) {
            let result = CompressionService.shared.compress(urls) { message in
                Task { @MainActor in compressionStatus = message }
            }

            await MainActor.run {
                appState.largeOldFiles.removeAll { result.compressedURLs.contains($0.url) }
                selectedIDs.removeAll()
                isCompressing = false
                compressionStatus = nil
                appState.refreshTrashSize()

                if !result.compressedURLs.isEmpty {
                    var message = "Compressed \(result.compressedURLs.count) item(s), saving \(ByteFormat.string(result.bytesSaved))."
                    if result.skippedCount > 0 {
                        message += " \(result.skippedCount) item(s) were already efficiently compressed and left as-is."
                    }
                    lastResultMessage = message
                } else if result.skippedCount > 0 {
                    lastResultMessage = "Nothing compressed meaningfully — those items are likely already in a compressed format (photos, videos, archives)."
                } else {
                    lastResultMessage = "Compression didn't complete. Please try again."
                }
            }
        }
    }
}
