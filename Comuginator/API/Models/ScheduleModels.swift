import Foundation

struct ScheduleItemDto: Decodable, Identifiable {
    let id: String
    let familyId: String
    let name: String?
    let mode: String          // WEEKDAY | DATE
    let weekdays: [Int]       // Mon=1 … Sun=7
    let date: String?         // yyyy-MM-dd (DATE mode)
    let time: String          // HH:mm
    let sortOrder: Int
    let cards: [AacCardDto]
    let forceShowChildHomeNodeIds: [String]
    let forceHideChildHomeNodeIds: [String]
}

struct ScheduleItemsResponse: Decodable {
    let ok: Bool
    let items: [ScheduleItemDto]
}

struct ScheduleItemResponse: Decodable {
    let ok: Bool
    let item: ScheduleItemDto
}

struct CreateScheduleItemRequest: Encodable {
    let mode: String
    let name: String?
    let weekdays: [Int]
    let date: String?
    let time: String
    let cards: [AacCardDto]
    let sortOrder: Int?
    let isEnabled: Bool
    let forceShowChildHomeNodeIds: [String]
    let forceHideChildHomeNodeIds: [String]
}

struct UpdateScheduleItemRequest: Encodable {
    let mode: String?
    let name: String?
    let weekdays: [Int]?
    let date: String?
    let time: String?
    let cards: [AacCardDto]?
    let isEnabled: Bool?
    let forceShowChildHomeNodeIds: [String]?
    let forceHideChildHomeNodeIds: [String]?
}
