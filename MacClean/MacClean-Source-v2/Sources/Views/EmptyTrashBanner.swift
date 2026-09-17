import SwiftUI

/// A small banner offering to empty the Trash. Drop this at the bottom of any
/// screen that just moved something to the Trash (Quick Clean, Duplicates,
/// Large & Old Files, Leftover Apps) so freeing the space for real doesn't
/// require hunting down a separate "Trash" screen.
struct EmptyTrashBanner: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfirm = false
    @State private var isEmptying = false

    var body: some View {
        if let size = appState.trashSize, size > 0 {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text("The Trash now has \(ByteFormat.string(size)) in it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isEmptying ? "Emptying…" : "Empty Trash") {
                    showConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isEmptying)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
            .confirmationDialog(
                "Permanently empty the Trash?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Empty Trash", role: .destructive) { performEmpty() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone — everything currently in the Trash, not just what you just cleaned, will be permanently deleted.")
            }
        }
    }

    private func performEmpty() {
        isEmptying = true
        Task.detached(priority: .userInitiated) {
            TrashService.shared.empty()
            await MainActor.run {
                isEmptying = false
                appState.refreshTrashSize()
            }
        }
    }
}
