import SwiftUI

struct TrashView: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfirm = false
    @State private var isEmptying = false
    @State private var lastResultMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trash").font(.title2).bold()
                Text("Everything MacClean moves out of the way — junk, duplicates, leftover app files — lands here first, so it's always reversible until you empty it. This is the only place in MacClean that deletes anything for good.")
                    .foregroundStyle(.secondary)

                if appState.trashAccessDenied {
                    fullDiskAccessNotice
                } else {
                    trashCard
                }

                Button {
                    appState.refreshTrashSize()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                if let lastResultMessage {
                    Text(lastResultMessage).foregroundStyle(.secondary).font(.caption)
                }
            }
            .padding(28)
        }
        .onAppear { appState.refreshTrashSize() }
        .confirmationDialog(
            "Permanently empty the Trash?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Empty Trash", role: .destructive) { performEmpty() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone — everything currently in the Trash, including anything you didn't put there through MacClean, will be permanently deleted.")
        }
    }

    private var trashCard: some View {
        Group {
            if let size = appState.trashSize {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ByteFormat.string(size))
                            .font(.system(size: 32, weight: .bold))
                        Text(size > 0 ? "currently in the Trash" : "The Trash is empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isEmptying ? "Emptying…" : "Empty Trash") {
                        showConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(size == 0 || isEmptying)
                }
            } else {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Checking the Trash…").foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor)))
    }

    private var fullDiskAccessNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text("MacClean needs one more permission")
                    .font(.headline)
            }
            Text("macOS keeps the Trash folder locked down from apps by default, so MacClean can't see what's inside it yet — that's why it may have looked empty even though Finder shows files. Granting Full Disk Access fixes this.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("To fix it:").font(.subheadline).bold()
                Text("1. Click \"Open Full Disk Access Settings\" below.")
                Text("2. Find MacClean in the list and turn its switch on.")
                Text("3. Come back here and click Refresh.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                TrashService.shared.openFullDiskAccessSettings()
            } label: {
                Label("Open Full Disk Access Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3)))
    }

    private func performEmpty() {
        isEmptying = true
        Task.detached(priority: .userInitiated) {
            let errors = TrashService.shared.empty()
            await MainActor.run {
                isEmptying = false
                appState.refreshTrashSize()
                lastResultMessage = errors.isEmpty
                    ? "Trash emptied."
                    : "Emptied most of the Trash; \(errors.count) item(s) couldn't be removed (in use or permission-protected)."
            }
        }
    }
}
