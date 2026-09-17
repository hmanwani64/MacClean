import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(DashboardSection.allCases) { section in
                    Button {
                        appState.selectedSection = section
                    } label: {
                        HStack {
                            Label(section.rawValue, systemImage: icon(for: section))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        appState.selectedSection == section
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .listStyle(.sidebar)
        } detail: {
            content
                .navigationTitle(appState.selectedSection?.rawValue ?? "Overview")
        }
        .onAppear {
            if appState.diskSpace == nil {
                appState.scanAll()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.selectedSection ?? .overview {
        case .overview: OverviewView()
        case .quickClean: QuickCleanView()
        case .duplicates: DuplicatesView()
        case .largeOldFiles: LargeOldFilesView()
        case .leftoverApps: LeftoverAppsView()
        case .updates: UpdatesView()
        case .trash: TrashView()
        }
    }

    private func icon(for section: DashboardSection) -> String {
        switch section {
        case .overview: return "gauge"
        case .quickClean: return "sparkles"
        case .duplicates: return "doc.on.doc"
        case .largeOldFiles: return "archivebox"
        case .leftoverApps: return "app.badge.checkmark"
        case .updates: return "arrow.triangle.2.circlepath"
        case .trash: return "trash"
        }
    }
}
