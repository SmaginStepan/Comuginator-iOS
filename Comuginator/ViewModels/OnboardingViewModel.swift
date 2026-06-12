import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class OnboardingViewModel: ObservableObject {

    enum Step { case nameEntry, choice }

    @Published var step: Step = .nameEntry

    @Published var userName: String = SessionStore.shared.userName ?? ""
    @Published var deviceName: String = {
        if let saved = SessionStore.shared.deviceName, !saved.isEmpty { return saved }
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Mac"
        #endif
    }()
    @Published var inviteCode: String = ""
    @Published var familyName: String = ""

    @Published var showJoinSection = false
    @Published var showQRScanner = false
    @Published var showCreateFamilySheet = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false

    func proceedFromNameEntry() {
        let name = userName.trimmed
        let device = deviceName.trimmed
        guard !name.isEmpty else { errorMessage = "User name is required"; return }
        guard !device.isEmpty else { errorMessage = "Device name is required"; return }
        errorMessage = nil
        step = .choice
    }

    func createFamily() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.createFamily(CreateFamilyRequest(
                userName: userName.trimmed,
                deviceName: deviceName.trimmed,
                deviceId: SessionStore.shared.deviceId,
                familyName: familyName.trimmed.isEmpty ? nil : familyName.trimmed,
                timezone: TimeZone.current.identifier
            ))
            save(token: r.token, familyId: r.familyId, userId: r.userId, role: r.role)
            isComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinFamily() async {
        let code = inviteCode.trimmed.uppercased()
        guard !code.isEmpty else { errorMessage = "Invite code is required"; return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.joinFamily(JoinFamilyRequest(
                code: code,
                userName: userName.trimmed,
                deviceName: deviceName.trimmed,
                deviceId: SessionStore.shared.deviceId,
                timezone: TimeZone.current.identifier
            ))
            save(token: r.token, familyId: r.familyId, userId: r.userId, role: r.role)
            isComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleQRCode(_ raw: String) {
        showQRScanner = false
        let content = raw.trimmed

        if content.hasPrefix("comuginator://join?code=") {
            let code = String(content.dropFirst("comuginator://join?code=".count))
                .components(separatedBy: "&")[0]
                .trimmed.uppercased()
            guard !code.isEmpty else { errorMessage = "Invalid QR code"; return }
            inviteCode = code
            showJoinSection = true
        } else {
            let code = content.uppercased()
            if code.range(of: "^[A-Z0-9]{4,20}$", options: .regularExpression) != nil {
                inviteCode = code
                showJoinSection = true
            } else {
                errorMessage = "Invalid QR code"
            }
        }
    }

    private func save(token: String, familyId: String, userId: String, role: String) {
        SessionStore.shared.token = token
        SessionStore.shared.familyId = familyId
        SessionStore.shared.userId = userId
        SessionStore.shared.userName = userName.trimmed
        SessionStore.shared.deviceName = deviceName.trimmed
        SessionStore.shared.role = role
        SessionStore.shared.addOrUpdateFamily(familyId: familyId, userId: userId, role: role)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
