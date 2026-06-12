import WidgetKit
import SwiftUI

// MARK: - Widget bundle

@main
struct ComuginatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        ComuginatorWidget()
    }
}

// MARK: - Widget

struct ComuginatorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComuginatorWidget", provider: Provider()) { entry in
            ComuginatorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Comuginator")
        .description("Shows unread messages or the upcoming schedule.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Timeline entry

struct WidgetCard {
    let label: String
    let imageData: Data?
}

enum WidgetContent {
    case message(sender: String, messageId: String, cards: [WidgetCard])
    case schedule(items: [(title: String, timeText: String, imageData: Data?)])
    case empty
}

struct ComuginatorEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

// MARK: - Provider

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> ComuginatorEntry {
        ComuginatorEntry(date: .now, content: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComuginatorEntry) -> Void) {
        completion(ComuginatorEntry(date: .now, content: .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComuginatorEntry>) -> Void) {
        Task {
            let content = await WidgetDataLoader.load()
            let entry = ComuginatorEntry(date: .now, content: content)
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - Data loading (self-contained: the widget runs in its own process)

enum WidgetDataLoader {
    static let appGroupId = "group.com.comuginator.shared"
    static let baseURL = URL(string: "https://comuginator.com/")!

    struct CardDto: Decodable { let id: String; let label: String; let imageUrl: String? }
    struct ReplyShort: Decodable { let id: String; let reply: [CardDto] }
    // WAIT steps come without an id ({"type":"WAIT","seconds":300})
    struct SuggestedReply: Decodable { let id: String?; let type: String? }
    struct MessageItem: Decodable {
        let id: String
        let toUserId: String
        let fromUser: UserShort
        let mode: String
        let message: [CardDto]
        let suggestedReplies: [SuggestedReply]
        let reply: ReplyShort?
        let createdAt: String
    }
    struct UserShort: Decodable { let name: String }
    struct MessagesResponse: Decodable { let items: [MessageItem] }
    struct ScheduleItem: Decodable {
        let id: String
        let name: String?
        let mode: String
        let weekdays: [Int]
        let date: String?
        let time: String
        let cards: [CardDto]
    }
    struct ScheduleResponse: Decodable { let items: [ScheduleItem] }

    static func load() async -> WidgetContent {
        let shared = UserDefaults(suiteName: appGroupId)
        guard let token = shared?.string(forKey: "token"),
              let userId = shared?.string(forKey: "userId") else { return .empty }
        let familyId = shared?.string(forKey: "familyId")

        // 1. Unread message awaiting this user's reply?
        if let messages: MessagesResponse = try? await get("v1/messages/aac?scope=all", token: token, familyId: familyId) {
            let unread = messages.items
                .filter { isAwaitingReply($0, userId: userId) }
                .max { $0.createdAt < $1.createdAt }
            if let unread {
                let cards = await loadCards(Array(unread.message.prefix(6)), token: token, familyId: familyId)
                return .message(sender: unread.fromUser.name, messageId: unread.id, cards: cards)
            }
        }

        // 2. Otherwise: next schedule items
        if let schedule: ScheduleResponse = try? await get("v1/schedule/items", token: token, familyId: familyId) {
            let upcoming = schedule.items
                .compactMap { item -> (ScheduleItem, Date)? in
                    guard let next = nextOccurrence(item) else { return nil }
                    return (item, next)
                }
                .sorted { $0.1 < $1.1 }
                .prefix(6)

            if !upcoming.isEmpty {
                var rows: [(String, String, Data?)] = []
                for (item, next) in upcoming {
                    let title = item.name?.isEmpty == false ? item.name! : (item.cards.first?.label ?? "")
                    let timeText = next.formatted(date: .omitted, time: .shortened)
                    let imageData = await loadImage(item.cards.first?.imageUrl, token: token, familyId: familyId)
                    rows.append((title, timeText, imageData))
                }
                return .schedule(items: rows)
            }
        }

        return .empty
    }

    /// Mirrors the app's shouldOpenIncoming: a message still waiting for this
    /// user's (next) reply — including a partially completed SEQUENCE.
    private static func isAwaitingReply(_ msg: MessageItem, userId: String) -> Bool {
        guard msg.toUserId == userId, !msg.suggestedReplies.isEmpty else { return false }
        if msg.mode != "SEQUENCE" { return msg.reply == nil }
        guard let currentReplyId = msg.reply?.reply.last?.id else { return true }
        if currentReplyId == "SEQUENCE_COMPLETED" { return false }
        guard let index = msg.suggestedReplies.firstIndex(where: { $0.id == currentReplyId })
        else { return true }
        return index < msg.suggestedReplies.count - 1
    }

    private static func get<T: Decodable>(_ path: String, token: String, familyId: String?) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let familyId { req.setValue(familyId, forHTTPHeaderField: "X-Family-Id") }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func loadCards(_ cards: [CardDto], token: String, familyId: String?) async -> [WidgetCard] {
        var result: [WidgetCard] = []
        for card in cards {
            let data = await loadImage(card.imageUrl, token: token, familyId: familyId)
            result.append(WidgetCard(label: card.label, imageData: data))
        }
        return result
    }

    private static func loadImage(_ urlString: String?, token: String, familyId: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        if url.host?.hasSuffix("comuginator.com") == true {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let familyId { req.setValue(familyId, forHTTPHeaderField: "X-Family-Id") }
        }
        return try? await URLSession.shared.data(for: req).0
    }

    private static func nextOccurrence(_ item: ScheduleItem) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let parts = item.time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }

        if item.mode == "DATE", let dateStr = item.date {
            let d = dateStr.prefix(10).split(separator: "-").compactMap { Int($0) }
            guard d.count == 3 else { return nil }
            var comps = DateComponents()
            comps.year = d[0]; comps.month = d[1]; comps.day = d[2]
            comps.hour = parts[0]; comps.minute = parts[1]
            guard let date = calendar.date(from: comps), date > now else { return nil }
            return date
        }

        guard !item.weekdays.isEmpty else { return nil }
        return item.weekdays.compactMap { isoDay -> Date? in
            var comps = DateComponents()
            comps.weekday = isoDay == 7 ? 1 : isoDay + 1   // Mon=1…Sun=7 → Calendar Sun=1…Sat=7
            comps.hour = parts[0]; comps.minute = parts[1]
            return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
        }.min()
    }
}

// MARK: - View

struct ComuginatorWidgetView: View {
    let entry: ComuginatorEntry
    @Environment(\.widgetFamily) private var family

    // Sizing that scales with the widget family
    private var isLarge: Bool { family == .systemLarge || family == .systemExtraLarge }
    private var cardSize: CGFloat { isLarge ? 88 : 44 }
    private var rowImageSize: CGFloat { isLarge ? 44 : 28 }
    private var maxCards: Int { isLarge ? 6 : 4 }
    private var maxRows: Int { isLarge ? 6 : 3 }

    var body: some View {
        switch entry.content {
        case .message(let sender, let messageId, let cards):
            VStack(alignment: .leading, spacing: isLarge ? 12 : 8) {
                Label("Message from \(sender)", systemImage: "bubble.left.fill")
                    .font(isLarge ? .headline : .caption.bold())
                    .foregroundStyle(.blue)
                HStack(spacing: isLarge ? 12 : 8) {
                    ForEach(Array(cards.prefix(maxCards).enumerated()), id: \.offset) { _, card in
                        VStack(spacing: isLarge ? 4 : 2) {
                            cardImage(card.imageData)
                                .frame(width: cardSize, height: cardSize)
                                .clipShape(RoundedRectangle(cornerRadius: isLarge ? 14 : 8))
                            Text(card.label)
                                .font(isLarge ? .caption : .system(size: 9))
                                .lineLimit(1)
                                .frame(width: cardSize + 4)
                        }
                    }
                }
                Text("Tap to reply")
                    .font(isLarge ? .subheadline : .caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(URL(string: "comuginator://message?id=\(messageId)"))

        case .schedule(let items):
            VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
                Label("Upcoming", systemImage: "calendar.badge.clock")
                    .font(isLarge ? .headline : .caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(Array(items.prefix(maxRows).enumerated()), id: \.offset) { _, row in
                    HStack(spacing: isLarge ? 12 : 8) {
                        cardImage(row.imageData)
                            .frame(width: rowImageSize, height: rowImageSize)
                            .clipShape(RoundedRectangle(cornerRadius: isLarge ? 10 : 6))
                        Text(row.title)
                            .font(isLarge ? .body : .caption)
                            .lineLimit(1)
                        Spacer()
                        Text(row.timeText)
                            .font(isLarge ? .body.monospacedDigit() : .caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .empty:
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(isLarge ? .largeTitle : .title2)
                    .foregroundStyle(.green)
                Text("All caught up")
                    .font(isLarge ? .body : .caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func cardImage(_ data: Data?) -> some View {
        if let data, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Color.secondary.opacity(0.15)
        }
    }
}
