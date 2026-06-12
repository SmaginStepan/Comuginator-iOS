import SwiftUI

struct LibrarySetView: View {
    let setId: String
    let initialName: String

    @StateObject private var vm = LibrarySetViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showAddPicker = false
    @State private var showCoverPicker = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteSet = false
    @State private var deleteItemTarget: LibraryItemDto?
    @State private var renameItemTarget: LibraryItemDto?
    @State private var renameItemText = ""

    var body: some View {
        Group {
            if vm.details == nil && vm.isLoading {
                ProgressView("Loading…")
            } else {
                List {
                    // ── Cover & info header ────────────────────────────────
                    Section {
                        HStack(spacing: 16) {
                            AuthImageView(urlString: vm.details?.cover?.imageUrl)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(vm.details?.name ?? initialName).font(.title3.bold())
                                Text("\(vm.items.count) item\(vm.items.count == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Change Cover") { showCoverPicker = true }
                                .font(.caption).buttonStyle(.bordered)
                        }
                    }

                    // ── Items ──────────────────────────────────────────────
                    Section("Items") {
                        if vm.items.isEmpty {
                            Text("No items — tap Add")
                                .foregroundStyle(.secondary).font(.subheadline)
                        } else {
                            ForEach(vm.items, id: \.id) { item in
                                ItemRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteItemTarget = item
                                        } label: { Label("Remove", systemImage: "trash") }
                                        Button {
                                            renameItemTarget = item
                                            renameItemText = item.label
                                        } label: { Label("Rename", systemImage: "pencil") }
                                        .tint(.blue)
                                    }
                            }
                            .onMove { from, to in
                                var items = vm.items
                                items.move(fromOffsets: from, toOffset: to)
                                Task { await vm.persistItemOrder(setId: setId) }
                            }
                        }

                        Button { showAddPicker = true } label: {
                            Label("Add Item", systemImage: "plus.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle(vm.details?.name ?? initialName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename Set") {
                        renameText = vm.details?.name ?? initialName
                        showRename = true
                    }
                    EditButton()
                    Divider()
                    Button("Delete Set", role: .destructive) { showDeleteSet = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .refreshable { await vm.load(setId: setId) }
        .task { await vm.load(setId: setId) }
        .overlay { if vm.isLoading { loadingOverlay } }
        .onChange(of: vm.shouldDismiss) { _, should in if should { dismiss() } }
        // Add item picker
        .sheet(isPresented: $showAddPicker) {
            LibraryItemPickerView { itemId in
                showAddPicker = false
                Task { await vm.addItem(itemId, setId: setId) }
            }
        }
        // Cover picker
        .sheet(isPresented: $showCoverPicker) {
            LibraryItemPickerView { itemId in
                showCoverPicker = false
                Task { await vm.updateCover(itemId, setId: setId) }
            }
        }
        // Rename item alert
        .alert("Rename Item", isPresented: Binding(
            get: { renameItemTarget != nil },
            set: { if !$0 { renameItemTarget = nil } }
        )) {
            TextField("Label", text: $renameItemText)
            Button("Save") {
                if let item = renameItemTarget {
                    Task { await vm.renameItem(item.id, label: renameItemText, setId: setId) }
                }
                renameItemTarget = nil
            }
            Button("Cancel", role: .cancel) { renameItemTarget = nil }
        }
        // Rename alert
        .alert("Rename Set", isPresented: $showRename) {
            TextField("Set name", text: $renameText)
            Button("Save") { Task { await vm.updateName(renameText, setId: setId) } }
            Button("Cancel", role: .cancel) {}
        }
        // Delete set
        .confirmationDialog("Delete this set?", isPresented: $showDeleteSet, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await vm.deleteSet(setId: setId) } }
            Button("Cancel", role: .cancel) {}
        }
        // Delete item
        .confirmationDialog(
            "Remove \"\(deleteItemTarget?.label ?? "")\"?",
            isPresented: Binding(get: { deleteItemTarget != nil }, set: { if !$0 { deleteItemTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let item = deleteItemTarget { Task { await vm.deleteItem(item.id, setId: setId) } }
                deleteItemTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteItemTarget = nil }
        }
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

private struct ItemRow: View {
    let item: LibraryItemDto
    var body: some View {
        HStack(spacing: 12) {
            AuthImageView(urlString: item.imageUrl)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(item.label).font(.subheadline)
        }
    }
}
