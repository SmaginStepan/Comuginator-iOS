import Foundation
import Combine
import SwiftUI

@MainActor
final class ComposeMessageViewModel: ObservableObject {

    // MARK: - Compose state
    @Published var messageCards: [AacCardDto] = []
    @Published var replyCards: [AacSuggestedReplyDto] = []
    @Published var mode: String = "NORMAL"
    @Published var allowMultipleReplies = false
    @Published var requiredReplyCount: Int = 2

    // MARK: - Library picker state
    @Published var libraryItems: [LibraryItemDto] = []
    @Published var librarySets: [LibrarySetDto] = []
    @Published var isLoadingLibrary = false

    // MARK: - Send state
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var isSent = false

    // MARK: - Initialise from a repeated message
    func populate(mode: String, replyCards: [AacSuggestedReplyDto], requiredReplyCount: Int = 1) {
        self.mode = mode
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
            async let itemsResponse = APIClient.shared.getLibraryItems()
            async let setsResponse  = APIClient.shared.getLibrarySets()
            libraryItems = try await itemsResponse.items
            librarySets  = try await setsResponse.sets
        } catch {
            statusText = "Library load failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Card management

    func addMessageCard(_ item: LibraryItemDto) {
        let card = AacCardDto(id: item.id, label: item.label,
                              imageUrl: item.imageUrl, source: item.source, sourceRef: item.sourceRef)
        messageCards.append(card)
    }

    func removeMessageCard(at offsets: IndexSet) { messageCards.remove(atOffsets: offsets) }
    func moveMessageCard(from source: IndexSet, to dest: Int) { messageCards.move(fromOffsets: source, toOffset: dest) }

    func addReplyCard(_ item: LibraryItemDto) {
        guard !replyCards.contains(where: { $0.id == item.id }) else { return }
        replyCards.append(AacSuggestedReplyDto(
            type: "card", id: item.id, label: item.label,
            imageUrl: item.imageUrl, source: item.source, sourceRef: item.sourceRef,
            storageKey: nil, seconds: nil
        ))
    }

    func removeReplyCard(at offsets: IndexSet) { replyCards.remove(atOffsets: offsets) }

    // MARK: - Send

    func sendMessage(targetUserId: String) async {
        guard !messageCards.isEmpty else { statusText = "Add at least one card"; return }
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
