import SwiftUI

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()

    @State private var showCardPicker = false
    @State private var newItemCard: AacCardDto?
    @State private var editTarget: ScheduleItemDto?
    @State private var deleteTarget: ScheduleItemDto?

    var body: some View {
        Group {
            if vm.items.isEmpty && !vm.isLoading {
                ContentUnavailableView("No Scheduled Items", systemImage: "calendar.badge.clock",
                    description: Text("Tap + to schedule a card."))
            } else {
                List {
                    ForEach(vm.items) { item in
                        ScheduleRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { editTarget = item }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteTarget = item } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCardPicker = true } label: { Image(systemName: "plus") }
            }
        }
        .overlay { if vm.isLoading { loadingOverlay } }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        // Pick a card → open the editor for a new item
        .sheet(isPresented: $showCardPicker) {
            ScheduleCardPickerSheet { card in
                showCardPicker = false
                newItemCard = card
            }
        }
        // New item editor
        .sheet(item: Binding(
            get: { newItemCard.map { ScheduleEditorContext(card: $0, item: nil) } },
            set: { if $0 == nil { newItemCard = nil } }
        )) { ctx in
            ScheduleItemEditorView(card: ctx.card, item: nil) {
                newItemCard = nil
                Task { await vm.load() }
            }
        }
        // Edit existing
        .sheet(item: $editTarget) { item in
            ScheduleItemEditorView(card: item.cards.first, item: item) {
                editTarget = nil
                Task { await vm.load() }
            }
        }
        // Delete confirmation
        .confirmationDialog(
            "Delete this schedule item?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = deleteTarget { Task { await vm.deleteItem(item) } }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// Wrapper so sheet(item:) can present a card + optional item pair
private struct ScheduleEditorContext: Identifiable {
    let card: AacCardDto
    let item: ScheduleItemDto?
    var id: String { card.id }
}

// MARK: - Row

private struct ScheduleRow: View {
    let item: ScheduleItemDto

    var body: some View {
        HStack(spacing: 12) {
            AuthImageView(urlString: item.cards.first?.imageUrl)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name?.isEmpty == false ? item.name! : (item.cards.first?.label ?? item.id))
                    .font(.subheadline)
                Text(ScheduleViewModel.scheduleText(item))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: item.mode == "DATE" ? "calendar" : "repeat")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Card picker (library items, single pick)

private struct ScheduleCardPickerSheet: View {
    let onSelect: (AacCardDto) -> Void

    @StateObject private var vm = LibraryItemPickerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                } else {
                    let items = vm.allItems.filter {
                        search.isEmpty || $0.label.localizedCaseInsensitiveContains(search)
                    }
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items, id: \.id) { item in
                                Button {
                                    onSelect(AacCardDto(
                                        id: item.id, label: item.label,
                                        imageUrl: item.imageUrl,
                                        source: item.source, sourceRef: item.sourceRef
                                    ))
                                } label: {
                                    VStack(spacing: 4) {
                                        AuthImageView(urlString: item.imageUrl)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Text(item.label)
                                            .font(.caption2).lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 72)
                                    }
                                    .padding(6)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $search, prompt: "Search")
                }
            }
            .navigationTitle("Choose Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await vm.load() }
    }
}
