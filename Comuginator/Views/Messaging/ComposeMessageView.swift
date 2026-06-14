import SwiftUI

struct ComposeMessageView: View {
    let targetUserId: String
    let targetUserName: String
    var initialMode: String = "NORMAL"
    var initialMessageCards: [AacCardDto] = []
    var initialReplyCards: [AacSuggestedReplyDto] = []
    var initialRequiredReplyCount: Int = 1

    @StateObject private var vm = ComposeMessageViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showReplyCardPicker = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Message (read-only / preset) ───────────────────────────
                Section {
                    if vm.messageCards.isEmpty {
                        Text("No message — responses only")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(vm.messageCards, id: \.id) { card in
                                    CardTile(card: card, opacity: 1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Message")
                } footer: {
                    Text("What you are saying. Set when the message was created — not editable here.")
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

                // ── Suggested responses (editable) ─────────────────────────
                Section {
                    if vm.replyCards.isEmpty {
                        Text("No responses yet — tap Add Response")
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
                        .onMove   { vm.moveReplyCard(from: $0, to: $1) }
                    }
                    Button { showReplyCardPicker = true } label: {
                        Label("Add Response", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Suggested Responses")
                } footer: {
                    Text("Cards the recipient can choose from as a reply. Add from your library, ARASAAC, or your photos.")
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
                    .disabled(vm.isLoading || vm.replyCards.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .overlay { if vm.isLoading { loadingOverlay } }
            .onChange(of: vm.isSent) { _, sent in if sent { dismiss() } }
        }
        .task {
            vm.populate(mode: initialMode,
                        messageCards: initialMessageCards,
                        replyCards: initialReplyCards,
                        requiredReplyCount: initialRequiredReplyCount)
            await vm.loadLibrary()
        }
        .sheet(isPresented: $showReplyCardPicker) {
            LibraryItemPickerView { itemId in
                Task { await vm.addReplyCard(byId: itemId) }
            }
        }
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}
