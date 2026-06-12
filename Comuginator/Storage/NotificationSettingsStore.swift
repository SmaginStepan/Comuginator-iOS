import Foundation

struct NotificationRule: Codable, Identifiable {
    let id: String
    var enable: Bool          // true = turn notifications on, false = off
    var weekdays: [Int]       // Mon=1 … Sun=7 (empty when date is set)
    var date: String?         // yyyy-MM-dd (one-shot rule)
    var time: String          // HH:mm
}

/// Local notification preferences ("do not disturb" rules) for this device.
final class NotificationSettingsStore {
    static let shared = NotificationSettingsStore()
    private let defaults = UserDefaults.standard
    private init() {}

    var notificationsEnabledManually: Bool {
        get { defaults.object(forKey: "notif_enabled_manual") as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: "notif_enabled_manual")
            defaults.set(Date().timeIntervalSince1970, forKey: "notif_toggled_at")
        }
    }

    var notificationsToggledAt: TimeInterval {
        defaults.double(forKey: "notif_toggled_at")
    }

    func getRules() -> [NotificationRule] {
        guard let data = defaults.data(forKey: "notif_rules"),
              let rules = try? JSONDecoder().decode([NotificationRule].self, from: data)
        else { return [] }
        return rules
    }

    func saveRules(_ rules: [NotificationRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: "notif_rules")
        }
    }

    func addRule(_ rule: NotificationRule) {
        var rules = getRules()
        rules.append(rule)
        saveRules(rules)
    }

    func removeRule(id: String) {
        var rules = getRules()
        rules.removeAll { $0.id == id }
        saveRules(rules)
    }
}

/// Decides whether notifications are currently enabled on this device.
///
/// Evaluated lazily ("last event wins") instead of flipping a flag with
/// timers: the most recent of the manual toggle and every rule's latest
/// firing time determines the state. A transition can never be missed.
enum NotificationPolicy {

    static func isEnabled() -> Bool {
        let store = NotificationSettingsStore.shared
        let now = Date()

        var winnerAt = store.notificationsToggledAt
        var winnerEnabled = store.notificationsEnabledManually

        for rule in store.getRules() {
            guard let firedAt = lastFiredAt(rule, now: now) else { continue }
            if firedAt > winnerAt {
                winnerAt = firedAt
                winnerEnabled = rule.enable
            }
        }
        return winnerEnabled
    }

    /// The most recent moment this rule fired, or nil if it never has.
    private static func lastFiredAt(_ rule: NotificationRule, now: Date) -> TimeInterval? {
        let parts = rule.time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        let hour = parts[0], minute = parts[1]
        let calendar = Calendar.current

        // One-shot date rule
        if let dateStr = rule.date {
            let dateParts = dateStr.prefix(10).split(separator: "-").compactMap { Int($0) }
            guard dateParts.count == 3 else { return nil }
            var comps = DateComponents()
            comps.year = dateParts[0]; comps.month = dateParts[1]; comps.day = dateParts[2]
            comps.hour = hour; comps.minute = minute
            guard let fireDate = calendar.date(from: comps), fireDate <= now else { return nil }
            return fireDate.timeIntervalSince1970
        }

        guard !rule.weekdays.isEmpty else { return nil }

        // Weekly rule: walk back up to a week to find the latest firing.
        for daysBack in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: -daysBack, to: now) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour; comps.minute = minute
            guard let fireDate = calendar.date(from: comps), fireDate <= now else { continue }
            // Calendar: Sun=1…Sat=7 → app convention: Mon=1…Sun=7
            let calWeekday = calendar.component(.weekday, from: fireDate)
            let isoWeekday = calWeekday == 1 ? 7 : calWeekday - 1
            if rule.weekdays.contains(isoWeekday) {
                return fireDate.timeIntervalSince1970
            }
        }
        return nil
    }
}
