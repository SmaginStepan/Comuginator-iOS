import Foundation
import Combine

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var items: [ScheduleItemDto] = []
    @Published var isLoading = false
    @Published var statusText = ""

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.getScheduleItems()
            items = response.items.sorted { nextSortKey($0) < nextSortKey($1) }
            statusText = ""
        } catch {
            statusText = "Failed to load schedule: \(error.localizedDescription)"
        }
    }

    func deleteItem(_ item: ScheduleItemDto) async {
        do {
            _ = try await APIClient.shared.deleteScheduleItem(id: item.id)
            await load()
        } catch {
            statusText = "Failed to delete: \(error.localizedDescription)"
        }
    }

    /// Next occurrence of the item, used to sort the list "soonest first".
    private func nextSortKey(_ item: ScheduleItemDto) -> Date {
        let calendar = Calendar.current
        let now = Date()

        let parts = item.time.split(separator: ":")
        let hour = Int(parts.first ?? "0") ?? 0
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        if item.mode == "DATE", let dateStr = item.date, !dateStr.isEmpty {
            let dateParts = dateStr.prefix(10).split(separator: "-").compactMap { Int($0) }
            if dateParts.count == 3 {
                var comps = DateComponents()
                comps.year = dateParts[0]; comps.month = dateParts[1]; comps.day = dateParts[2]
                comps.hour = hour; comps.minute = minute
                return calendar.date(from: comps) ?? now
            }
        }

        if item.mode == "WEEKDAY", !item.weekdays.isEmpty {
            // App convention: Mon=1…Sun=7 → Calendar: Sun=1…Sat=7
            let next = item.weekdays.compactMap { isoDay -> Date? in
                let calWeekday = isoDay == 7 ? 1 : isoDay + 1
                var comps = DateComponents()
                comps.weekday = calWeekday
                comps.hour = hour; comps.minute = minute
                return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
            }.min()
            if let next { return next }
        }

        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps) ?? now
    }

    // MARK: - Display helpers

    static func scheduleText(_ item: ScheduleItemDto) -> String {
        switch item.mode {
        case "WEEKDAY":
            let names = item.weekdays.map { weekdayName($0) }.joined(separator: ", ")
            return "\(names) \(item.time)"
        case "DATE":
            let d = TimeFormat.date(item.date)
            return "\(d.isEmpty ? "-" : d) \(item.time)"
        default:
            return item.time
        }
    }

    static func weekdayName(_ day: Int) -> String {
        // Mon=1 … Sun=7 (short names from the current locale)
        let symbols = Calendar.current.shortWeekdaySymbols  // [Sun, Mon, …]
        guard (1...7).contains(day) else { return "?" }
        return symbols[day % 7]
    }
}
