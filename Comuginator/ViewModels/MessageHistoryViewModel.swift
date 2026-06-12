import Foundation
import Combine

@MainActor
final class MessageHistoryViewModel: ObservableObject {
    @Published var messages: [AacMessageListItemDto] = []
    @Published var isLoading = false
    @Published var statusText = ""

    private let myUserId: String = SessionStore.shared.userId ?? ""

    func load(targetUserId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.getMessages()
            messages = response.items
                .filter { msg in
                    (msg.fromUserId == myUserId && msg.toUserId == targetUserId) ||
                    (msg.fromUserId == targetUserId && msg.toUserId == myUserId)
                }
                .sorted { $0.createdAt < $1.createdAt }
            statusText = "\(messages.count) message(s)"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func isSentByMe(_ msg: AacMessageListItemDto) -> Bool {
        msg.fromUserId == myUserId
    }
}
