import Foundation
import Combine
import SwiftUI

@MainActor
final class ComposeMessageViewModel: ObservableObject {

    // MARK: - Compose state
    /// The message is preset (e.g. when repeating a message) and shown read-only.
    @Published var messageCards: [AacCardDto] = []
    @Published var replyCards: [AacSuggestedReplyDto] = []
    @Published var mode: String = "NORMAL"
    @Published var allowMultipleReplies = false
    @Published var requiredReplyCount: Int = 2

    // MARK: - Library (used to resolve picked item ids into reply cards)
    @Published var libraryItems: [LibraryItemDto] = []
    @Published var isLoadingLibrary = false

    // MARK: - Send state
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var isSent = false

    // MARK: - Initialise from a preset / repeated message
    func populate(mode: String,
                  messageCards: [AacCardDto],
                  replyCards: [AacSuggestedReplyDto],
                  requiredReplyCount: Int = 1) {
        self.mode = mode
        self.messageCards = messageCards
        self.replyCards = replyCards
        if requiredReplyCount > 1 {
            self.allowMultipleReplies = true
            self.requiredReplyCount = min(max(requiredReplyCount, 2), 4)
        } else {
            self.allowMultipleReplies = false
        }
    }

    // MARK: - Library

    func loadLibrary() async {
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        do {
            libraryItems = try await APIClient.shared.getLibraryItems().items
        } catch {
            statusText = "Library load failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Suggested-reply management

    /// The shared picker returns a library item id. Resolve it into a reply card,
    /// reloading the library if the item was just created (ARASAAC / photo upload).
    func addReplyCard(byId id: String) async {
        guard !replyCards.contains(where: { $0.id == id }) else { return }
        if let item = libraryItems.first(where: { $0.id == id }) {
            appendReply(item)
            return
        }
        await loadLibrary()
        if let item = libraryItems.first(where: { $0.id == id }) {
            appendReply(item)
        } else {
            statusText = "Couldn't load the selected card"
        }
    }

    private func appendReply(_ item: LibraryItemDto) {
        replyCards.append(AacSuggestedReplyDto(
            type: "card", id: item.id, label: item.label,
            imageUrl: item.imageUrl, source: item.source, sourceRef: item.sourceRef,
            storageKey: nil, seconds: nil
        ))
    }

    func removeReplyCard(at offsets: IndexSet) { replyCards.remove(atOffsets: offsets) }
    func moveReplyCard(from source: IndexSet, to dest: Int) { replyCards.move(fromOffsets: source, toOffset: dest) }

    // MARK: - Send

    func sendMessage(targetUserId: String) async {
        guard !replyCards.isEmpty else { statusText = "Add at least one suggested response"; return }
        isLoading = true
        statusText = "Sending…"
        defer { isLoading = false }
        do {
            let count = allowMultipleReplies ? requiredReplyCount : 1
            let req = SendAacMessageRequest(
                targetUserId: targetUserId,
                mode: mode,
                cards: messageCards,
                suggestedReplies: replyCards,
                requiredReplyCount: count
            )
            _ = try await APIClient.shared.sendMessage(req)
            isSent = true
            statusText = "Sent!"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}
