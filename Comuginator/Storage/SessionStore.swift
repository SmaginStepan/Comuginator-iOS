import Foundation

struct FamilyEntry: Codable, Identifiable {
    let familyId: String
    let userId: String
    let role: String
    var name: String?

    var id: String { familyId }
}

final class SessionStore {
    static let shared = SessionStore()
    /// Must match the App Group enabled on both the app and widget targets.
    static let appGroupId = "group.com.comuginator.shared"

    private let defaults = UserDefaults.standard
    /// Shared with the widget extension; nil when the App Group isn't configured.
    private let sharedDefaults = UserDefaults(suiteName: SessionStore.appGroupId)
    private let tokenKey = "comuginator_token"

    private init() {}

    var token: String? {
        get { KeychainHelper.shared.read(key: tokenKey) }
        set {
            if let value = newValue {
                KeychainHelper.shared.save(value, key: tokenKey)
            } else {
                KeychainHelper.shared.delete(key: tokenKey)
            }
            // Mirror for the widget extension (separate process, no shared keychain)
            sharedDefaults?.set(newValue, forKey: "token")
        }
    }

    var userId: String? {
        get { defaults.string(forKey: "userId") }
        set {
            defaults.set(newValue, forKey: "userId")
            sharedDefaults?.set(newValue, forKey: "userId")
        }
    }

    var userName: String? {
        get { defaults.string(forKey: "userName") }
        set { defaults.set(newValue, forKey: "userName") }
    }

    // Stable device ID — generated once and persisted
    var deviceId: String {
        if let id = defaults.string(forKey: "deviceId") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "deviceId")
        return id
    }

    var deviceName: String? {
        get { defaults.string(forKey: "deviceName") }
        set { defaults.set(newValue, forKey: "deviceName") }
    }

    var familyId: String? {
        get { defaults.string(forKey: "familyId") }
        set {
            defaults.set(newValue, forKey: "familyId")
            sharedDefaults?.set(newValue, forKey: "familyId")
        }
    }

    var role: String? {
        get { defaults.string(forKey: "role") }
        set { defaults.set(newValue, forKey: "role") }
    }

    var appLanguage: String? {
        get { defaults.string(forKey: "appLanguage") }
        set { defaults.set(newValue, forKey: "appLanguage") }
    }

    var lastUsedInviteId: String? {
        get { defaults.string(forKey: "lastUsedInviteId") }
        set { defaults.set(newValue, forKey: "lastUsedInviteId") }
    }

    var isConnected: Bool {
        token != nil && familyId != nil
    }

    /// Mirror the session into the App Group so the widget can read it.
    /// Called at launch — users logged in before the widget existed never
    /// re-set token/familyId, so the write-through mirrors alone don't fire.
    func syncToSharedDefaults() {
        sharedDefaults?.set(token, forKey: "token")
        sharedDefaults?.set(userId, forKey: "userId")
        sharedDefaults?.set(familyId, forKey: "familyId")
    }

    // MARK: - Multi-family

    func getFamilies() -> [FamilyEntry] {
        if let data = defaults.data(forKey: "families_v2"),
           let list = try? JSONDecoder().decode([FamilyEntry].self, from: data) {
            return list
        }
        // Migrate from single-family storage
        guard let id = familyId, let uid = userId, let r = role else { return [] }
        let entry = FamilyEntry(familyId: id, userId: uid, role: r, name: nil)
        saveFamilies([entry])
        return [entry]
    }

    private func saveFamilies(_ list: [FamilyEntry]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: "families_v2")
        }
    }

    /// Replace the local family list with the server's truth (GET /v1/me/families).
    func syncFamilies(_ entries: [FamilyEntry]) {
        saveFamilies(entries)
    }

    func addOrUpdateFamily(familyId: String, userId: String, role: String, name: String? = nil) {
        var list = getFamilies()
        let existing = list.first { $0.familyId == familyId }
        list.removeAll { $0.familyId == familyId }
        list.append(FamilyEntry(familyId: familyId, userId: userId, role: role,
                                name: name ?? existing?.name))
        saveFamilies(list)
    }

    func removeFamily(familyId: String) {
        var list = getFamilies()
        list.removeAll { $0.familyId == familyId }
        saveFamilies(list)
    }

    func setActiveFamily(familyId: String) {
        guard let entry = getFamilies().first(where: { $0.familyId == familyId }) else { return }
        self.familyId = entry.familyId
        self.userId = entry.userId
        self.role = entry.role
    }

    /// The timezone this device last reported to the server for the family.
    func timezoneSynced(familyId: String) -> String? {
        defaults.string(forKey: "tz_synced_\(familyId)")
    }

    func setTimezoneSynced(familyId: String, timezone: String) {
        defaults.set(timezone, forKey: "tz_synced_\(familyId)")
    }

    func clear() {
        token = nil
        [
            "userId", "userName", "deviceName",
            "familyId", "role", "appLanguage", "lastUsedInviteId", "families_v2"
        ].forEach { defaults.removeObject(forKey: $0) }
        ["token", "userId", "familyId"].forEach { sharedDefaults?.removeObject(forKey: $0) }
    }
}
