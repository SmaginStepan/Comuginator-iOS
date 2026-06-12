import SwiftUI

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()

    @State private var showCreateSet = false
    @State private var newSetName = ""
    @State private var deleteTarget: LibrarySetDto?

    let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        Group {
            if vm.sets.isEmpty && !vm.isLoading {
                ContentUnavailableView("No Sets", systemImage: "folder",
                    description: Text("Tap + to create your first library set."))
            } else {
                List {
                    ForEach(vm.sets, id: \.id) { set in
                        NavigationLink(value: set) {
                            SetRow(set: set)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteTarget = set } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        vm.sets.move(fromOffsets: from, toOffset: to)
                        Task { await vm.persistSetOrder() }
                    }
                }
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreateSet = true } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .navigationDestination(for: LibrarySetDto.self) { set in
            LibrarySetView(setId: set.id, initialName: set.name)
        }
        .overlay { if vm.isLoading { loadingOverlay } }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        // Create set alert
        .alert("New Set", isPresented: $showCreateSet) {
            TextField("Set name", text: $newSetName)
            Button("Create") {
                Task { await vm.createSet(name: newSetName); newSetName = "" }
            }
            Button("Cancel", role: .cancel) { newSetName = "" }
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete \"\(deleteTarget?.name ?? "")\"?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let s = deleteTarget { Task { await vm.deleteSet(id: s.id) } }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: { Text("This will delete the set and remove all items from it.") }
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// Make LibrarySetDto navigable
extension LibrarySetDto: Hashable {
    public static func == (lhs: LibrarySetDto, rhs: LibrarySetDto) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct SetRow: View {
    let set: LibrarySetDto
    var body: some View {
        HStack(spacing: 12) {
            AuthImageView(urlString: set.cover?.imageUrl)
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(set.name).font(.headline)
                if let count = set.itemsCount {
                    Text("\(count) items")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
