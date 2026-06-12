import Foundation
import Combine

/// Shared singleton that lets the AppDelegate route push notification taps
/// to the SwiftUI view hierarchy. FamilyView observes pendingMessageId and
/// presents IncomingMessageView as a sheet when it is set.
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var pendingMessageId: String? = nil
    private init() {}
}
