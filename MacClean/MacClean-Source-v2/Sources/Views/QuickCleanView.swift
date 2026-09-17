import SwiftUI

struct QuickCleanView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var showConfirm = false
    @State private var lastResultMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Quick Clean").font(.title2).bold()
                Text("Review what's safe to remove, then move it to the Trash. Nothing is deleted without your confirmation.")
                    .foregroundStyle(.secondary)

                if appState.cleanableCategories.isEmpty {
                    Text("Nothing found yet. Run a scan from the Overview tab.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                } else {
                    HStack {
                        Button("Select All") {
                            selectedCategoryIDs = Set(appState.cleanableCategories.map { $0.id })
                        }
                        .buttonStyle(.bordered)
                        Button("Deselect All") {
                            selectedCategoryIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }

                    ForEach(appState.cleanableCategories) { category in
                        categoryRow(category)
                    }

                    Button("Move Selected to Trash (\(ByteFormat.string(selectedSize)))") {
                        showConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCategoryIDs.isEmpty)
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
            "Move \(selectedCategoryIDs.count) categor\(selectedCategoryIDs.count == 1 ? "y" : "ies") to the Trash?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { performClean() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can restore these from the Trash afterward if you change your mind.")
        }
    }

    private var selectedSize: Int64 {
        appState.cleanableCategories
            .filter { selectedCategoryIDs.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    private func categoryRow(_ category: CleanableCategory) -> some View {
        let isSelected = selectedCategoryIDs.contains(category.id)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .font(.system(size: 18))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name).font(.headline)
                    Spacer()
                    Text(ByteFormat.string(category.size)).bold()
                }
                Text(category.description).font(.caption).foregroundStyle(.secondary)
                Text("\(category.urls.count) item(s)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor)))
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedCategoryIDs.remove(category.id)
            } else {
                selectedCategoryIDs.insert(category.id)
            }
        }
    }

    private func performClean() {
        let categories = appState.cleanableCategories.filter { selectedCategoryIDs.contains($0.id) }
        let urls = categories.flatMap { $0.urls }
        let errors = CacheCleanerService.shared.trash(urls)

        appState.cleanableCategories.removeAll { selectedCategoryIDs.contains($0.id) }
        selectedCategoryIDs.removeAll()
        appState.refreshTrashSize()

        lastResultMessage = errors.isEmpty
            ? "Moved the selected items to the Trash."
            : "Moved most items to the Trash; \(errors.count) couldn't be removed (in use or permission-protected)."
    }
}
