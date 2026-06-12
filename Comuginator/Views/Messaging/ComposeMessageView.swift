import SwiftUI

struct ComposeMessageView: View {
    let targetUserId: String
    let targetUserName: String
    var initialMode: String = "NORMAL"
    var initialReplyCards: [AacSuggestedReplyDto] = []
    var initialRequiredReplyCount: Int = 1

    @StateObject private var vm = ComposeMessageViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showMessageCardPicker = false
    @State private var showReplyCardPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Message cards ──────────────────────────────────────────
                Section {
                    if vm.messageCards.isEmpty {
                        Text("No cards yet — tap Add Card")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(vm.messageCards, id: \.id) { card in
                            CardRow(card: card)
                        }
                        .onDelete { vm.removeMessageCard(at: $0) }
                        .onMove  { vm.moveMessageCard(from: $0, to: $1) }
                    }
                    Button { showMessageCardPicker = true } label: {
                        Label("Add Card", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Message Cards")
                } footer: {
                    Text("What you are saying. Long-press to reorder, swipe to delete.")
                        .font(.caption)
                }

                // ── Mode ───────────────────────────────────────────────────
                Section("Mode") {
                    Picker("Mode", selection: $vm.mode) {
                        Text("Normal").tag("NORMAL")
                        Text("Sequence").tag("SEQUENCE")
                    }
                    .pickerStyle(.segmented)
                }

                // ── Reply cards ────────────────────────────────────────────
                Section {
                    if vm.replyCards.isEmpty {
                        Text("No reply cards — tap Add Reply Card")
                            .foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(vm.replyCards, id: \.id) { card in
                            HStack {
                                AuthImageView(urlString: card.imageUrl)
                                    .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(card.label ?? card.id).font(.subheadline)
                            }
                        }
                        .onDelete { vm.removeReplyCard(at: $0) }
                    }
                    Button { showReplyCardPicker = true } label: {
                        Label("Add Reply Card", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Suggested Replies")
                } footer: {
                    Text("Cards the recipient can choose from as a reply.")
                        .font(.caption)
                }

                // ── Multiple replies (NORMAL only) ─────────────────────────
                if vm.mode == "NORMAL" {
                    Section("Reply Options") {
                        Toggle("Allow Multiple Replies", isOn: $vm.allowMultipleReplies)
                        if vm.allowMultipleReplies {
                            Stepper("Required: \(vm.requiredReplyCount)",
                                    value: $vm.requiredReplyCount, in: 2...4)
                        }
                    }
                }

                // ── Status ─────────────────────────────────────────────────
                if !vm.statusText.isEmpty {
                    Section {
                        Text(vm.statusText)
                            .font(.footnote)
                            .foregroundStyle(vm.isSent ? .green : .red)
                    }
                }
            }
            .navigationTitle("To: \(targetUserName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") {
                        Task { await vm.sendMessage(targetUserId: targetUserId) }
                    }
                    .bold()
                    .disabled(vm.isLoading || vm.messageCards.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .overlay { if vm.isLoading { loadingOverlay } }
            .onChange(of: vm.isSent) { _, sent in if sent { dismiss() } }
        }
        .task {
            vm.populate(mode: initialMode, replyCards: initialReplyCards,
                        requiredReplyCount: initialRequiredReplyCount)
            await vm.loadLibrary()
        }
        .sheet(isPresented: $showMessageCardPicker) {
            LibraryItemPickerSheet(items: vm.libraryItems, isLoading: vm.isLoadingLibrary) {
                vm.addMessageCard($0)
                showMessageCardPicker = false
            }
        }
        .sheet(isPresented: $showReplyCardPicker) {
            LibraryItemPickerSheet(items: vm.libraryItems, isLoading: vm.isLoadingLibrary) {
                vm.addReplyCard($0)
                showReplyCardPicker = false
            }
        }
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Card row

private struct CardRow: View {
    let card: AacCardDto
    var body: some View {
        HStack(spacing: 10) {
            AuthImageView(urlString: card.imageUrl)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(card.label).font(.subheadline)
        }
    }
}

// MARK: - Inline library picker sheet

struct LibraryItemPickerSheet: View {
    let items: [LibraryItemDto]
    let isLoading: Bool
    let onSelect: (LibraryItemDto) -> Void

    @State private var search = ""

    private var filtered: [LibraryItemDto] {
        search.isEmpty ? items : items.filter { $0.label.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading library…")
                } else if items.isEmpty {
                    ContentUnavailableView("No Items", systemImage: "photo.on.rectangle")
                } else {
                    List(filtered, id: \.id) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: 12) {
                                AuthImageView(urlString: item.imageUrl)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(item.label).foregroundStyle(.primary)
                            }
                        }
                    }
                    .searchable(text: $search, prompt: "Search cards")
                }
            }
            .navigationTitle("Choose Card")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
