import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var myUser: UserDto?
    @Published var familyName = ""
    @Published var deviceName = ""
    @Published var role = ""
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var shouldLogout = false

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    var isParent: Bool { role == "PARENT" }

    // MARK: - Load

    func load() async {
        // Show cached values immediately while the network call runs
        deviceName = SessionStore.shared.deviceName ?? ""
        role       = SessionStore.shared.role ?? ""

        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.getMyFamily()
            familyName = r.family.name
            role       = r.me.role
            SessionStore.shared.role = r.me.role

            let myId = SessionStore.shared.userId ?? r.me.userId
            myUser = r.users.first { $0.id == myId }
            if let name = myUser?.name {
                SessionStore.shared.userName = name
            }
            statusText = ""
        } catch {
            statusText = error.localizedDescription
        }
    }

    // MARK: - Updates

    func updateUserName(_ name: String) async {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let userId = SessionStore.shared.userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.updateUserName(
                userId: userId, body: UpdateNameRequest(name: name)
            )
            myUser = result.user
            SessionStore.shared.userName = name
            statusText = "Name updated"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateDeviceName(_ name: String) async {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let deviceId = SessionStore.shared.deviceId
            _ = try await APIClient.shared.updateDeviceName(
                deviceId: deviceId, body: UpdateNameRequest(name: name)
            )
            deviceName = name
            SessionStore.shared.deviceName = name
            statusText = "Device name updated"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateAvatar(itemId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.updateMyAvatar(
                UpdateMyAvatarRequest(avatarItemId: itemId)
            )
            myUser = result.user
            statusText = "Avatar updated"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Account

    func logout() {
        SessionStore.shared.clear()
        shouldLogout = true
    }

    func deleteAccount() async {
        guard let userId = SessionStore.shared.userId else { logout(); return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteUser(userId: userId)
            SessionStore.shared.clear()
            shouldLogout = true
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}
