import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool

    init() {
        isLoggedIn = SessionStore.shared.isConnected
    }
}
