import SwiftUI
import AppKit

struct UpdatesView: View {
    @EnvironmentObject var appState: AppState
    @State private var isChecking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Software Updates").font(.title2).bold()
                Text("macOS handles hardware drivers itself — checking here covers the real update path: Apple's Software Update, plus Homebrew packages if you use it.")
                    .foregroundStyle(.secondary)

                Button(isChecking ? "Checking…" : "Check for Updates") {
                    checkUpdates()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isChecking)

                if appState.updates.isEmpty && !isChecking {
                    Text("No updates found, or none checked yet.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(appState.updates) { update in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.name).font(.system(size: 13, weight: .medium))
                                Text(update.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(update.source.rawValue)
                                .font(.caption2).bold()
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
                    }

                    if appState.updates.contains(where: { $0.source == .macOS }) {
                        Button("Open Software Update…") {
                            openSystemSoftwareUpdate()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(28)
        }
    }

    private func checkUpdates() {
        isChecking = true
        SoftwareUpdateService.shared.checkAll { items in
            appState.updates = items
            isChecking = false
        }
    }

    private func openSystemSoftwareUpdate() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.softwareupdate") {
            NSWorkspace.shared.open(url)
        }
    }
}
