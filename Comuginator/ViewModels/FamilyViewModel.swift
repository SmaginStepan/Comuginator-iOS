import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct InviteDisplay {
    let code: String
    let role: String
    let expiresAt: String
}

@MainActor
final class FamilyViewModel: ObservableObject {
    @Published var familyResponse: FamilyMeResponse?
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var inviteDisplay: InviteDisplay?
    @Published var optimisticVolumes: [String: Int] = [:]
    @Published var shouldLogout = false

    private var shownInviteId: String?
    private var refreshTask: Task<Void, Never>?

    var isParent: Bool { familyResponse?.me.role == "PARENT" }
    var myDeviceId: String { familyResponse?.me.deviceId ?? SessionStore.shared.deviceId }
    var users: [UserDto] { familyResponse?.users ?? [] }
    var familyName: String { familyResponse?.family.name ?? "" }

    // MARK: - Refresh loop

    func startRefreshLoop() {
        stopRefreshLoop()
        refreshTask = Task { [weak self] in
            var cycle = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.loadFamily()
                cycle += 1
                // Send heartbeat every 10 cycles ≈ 5 minutes
                if cycle % 10 == 0 {
                    await self?.sendHeartbeat()
                }
            }
        }
    }

    func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Load

    func loadFamily() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.getMyFamily()
            familyResponse = response
            SessionStore.shared.role = response.me.role
            await syncFamilyList(response)
            syncFamilyTimezone(familyId: response.family.id, role: response.me.role)
            for user in response.users {
                for device in user.devices ?? [] {
                    if optimisticVolumes[device.deviceId] == device.state?.volumePercent {
                        optimisticVolumes.removeValue(forKey: device.deviceId)
                    }
                }
            }
            statusText = "Updated at \(formatTime())"
        } catch {
            if await handleUnauthorizedWithFamilySwitch(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Multi-family

    var families: [FamilyEntry] { SessionStore.shared.getFamilies() }

    /// Refresh the local family list from the server so the switch menu never
    /// shows memberships the user has lost. Best-effort: falls back to updating
    /// just the active family if the endpoint fails.
    private func syncFamilyList(_ response: FamilyMeResponse) async {
        do {
            let result = try await APIClient.shared.getMyFamilies()
            SessionStore.shared.syncFamilies(result.families.map {
                FamilyEntry(familyId: $0.familyId, userId: $0.userId,
                            role: $0.role, name: $0.familyName)
            })
        } catch {
            SessionStore.shared.addOrUpdateFamily(
                familyId: response.family.id,
                userId: response.me.userId,
                role: response.me.role,
                name: response.family.name
            )
        }
    }

    func setActiveFamily(_ familyId: String) {
        SessionStore.shared.setActiveFamily(familyId: familyId)
        familyResponse = nil
        inviteDisplay = nil
        optimisticVolumes = [:]
        Task { await loadFamily() }
    }

    func joinAnotherFamily(code: String) async {
        let code = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty,
              let userName = SessionStore.shared.userName,
              let deviceName = SessionStore.shared.deviceName else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.joinFamily(JoinFamilyRequest(
                code: code,
                userName: userName,
                deviceName: deviceName,
                deviceId: SessionStore.shared.deviceId,
                timezone: TimeZone.current.identifier
            ))
            SessionStore.shared.token = r.token
            SessionStore.shared.addOrUpdateFamily(familyId: r.familyId, userId: r.userId, role: r.role)
            if r.role == "CHILD" {
                // Don't auto-activate a CHILD membership: switching would lock
                // this device into child mode without warning.
                statusText = "Joined as child — switch manually when ready"
            } else {
                setActiveFamily(r.familyId)
                statusText = "Switched to new family"
            }
        } catch {
            if await handleUnauthorizedWithFamilySwitch(error) { return }
            statusText = "Join failed: \(error.localizedDescription)"
        }
    }

    /// Keep the family's timezone matching this device so the server's schedule
    /// worker fires items at the family's wall-clock time. Sent only when the
    /// device timezone differs from what this device last reported.
    private func syncFamilyTimezone(familyId: String, role: String) {
        guard role == "PARENT" else { return }
        let deviceTz = TimeZone.current.identifier
        guard SessionStore.shared.timezoneSynced(familyId: familyId) != deviceTz else { return }
        Task {
            do {
                _ = try await APIClient.shared.updateMyFamily(
                    UpdateFamilyRequest(name: nil, timezone: deviceTz)
                )
                SessionStore.shared.setTimezoneSynced(familyId: familyId, timezone: deviceTz)
            } catch { /* retried on the next loadFamily */ }
        }
    }

    // MARK: - Invite

    func createInvite(role: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await APIClient.shared.createInvite(
                CreateInviteRequest(role: role, expiresInMinutes: 60)
            )
            shownInviteId = r.inviteId
            inviteDisplay = InviteDisplay(code: r.code, role: role, expiresAt: r.expiresAt)
            statusText = "Invite created"
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func clearInvite() { shownInviteId = nil; inviteDisplay = nil }

    func onInviteUsed(_ inviteId: String?) {
        guard let id = inviteId, id == shownInviteId else { return }
        clearInvite()
    }

    // MARK: - Volume

    func sendSetVolumeCommand(deviceId: String, volume: Int) async {
        optimisticVolumes[deviceId] = volume
        do {
            _ = try await APIClient.shared.createCommand(
                deviceId: deviceId,
                body: CreateCommandRequest(type: "set_volume",
                                           payload: ["volumePercent": .number(Double(volume))])
            )
            statusText = "Volume command sent"
        } catch {
            optimisticVolumes.removeValue(forKey: deviceId)
            statusText = "Volume command failed: \(error.localizedDescription)"
        }
    }

    func effectiveVolume(for device: DeviceDto) -> Int? {
        optimisticVolumes[device.deviceId] ?? device.state?.volumePercent
    }

    // MARK: - Rename

    func updateFamilyName(_ name: String) async {
        guard !name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.updateMyFamily(UpdateFamilyRequest(name: name, timezone: nil))
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateUserName(userId: String, name: String) async {
        guard !name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.updateUserName(userId: userId, body: UpdateNameRequest(name: name))
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateDeviceName(deviceId: String, name: String) async {
        guard !name.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.updateDeviceName(deviceId: deviceId, body: UpdateNameRequest(name: name))
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateUserAvatar(userId: String, avatarItemId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.updateUserAvatar(userId: userId, body: UpdateMyAvatarRequest(avatarItemId: avatarItemId))
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete

    func deleteUser(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteUser(userId: userId)
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func deleteDevice(deviceId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteDevice(deviceId: deviceId)
            await loadFamily()
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func deleteFamily() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteFamily()
            SessionStore.shared.clear()
            shouldLogout = true
        } catch {
            if handleUnauthorized(error) { return }
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Heartbeat

    func sendHeartbeat() async {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let batteryPercent = level >= 0 ? Int(level * 100) : nil
        let isCharging = [.charging, .full].contains(UIDevice.current.batteryState)
        let model = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        #else
        let batteryPercent: Int? = nil
        let isCharging = false
        let model = "Mac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let request = HeartbeatRequest(
            batteryPercent: batteryPercent,
            volumePercent: nil,
            isCharging: isCharging,
            reportedAt: ISO8601DateFormatter().string(from: Date()),
            platform: "ios",
            model: model,
            osVersion: osVersion,
            appVersion: appVersion
        )
        do {
            _ = try await APIClient.shared.heartbeat(request)
            statusText = "Heartbeat sent at \(formatTime())"
        } catch {
            statusText = "Heartbeat failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func handleUnauthorized(_ error: Error) -> Bool {
        if case APIError.httpError(401, _) = error {
            SessionStore.shared.clear()
            shouldLogout = true
            return true
        }
        return false
    }

    /// On 401: drop the dead family membership and switch to a remaining one
    /// instead of logging out, if possible.
    private func handleUnauthorizedWithFamilySwitch(_ error: Error) async -> Bool {
        guard case APIError.httpError(401, _) = error else { return false }

        if let currentFamilyId = SessionStore.shared.familyId {
            SessionStore.shared.removeFamily(familyId: currentFamilyId)
            let remaining = SessionStore.shared.getFamilies()
            if let next = remaining.first {
                SessionStore.shared.setActiveFamily(familyId: next.familyId)
                familyResponse = nil
                inviteDisplay = nil
                statusText = "Removed from family — switched to \(next.name ?? "another family")"
                await loadFamily()
                return true
            }
        }
        SessionStore.shared.clear()
        shouldLogout = true
        return true
    }

    private func formatTime() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: Date())
    }
}
