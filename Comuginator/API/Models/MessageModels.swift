import Foundation

struct AacCardDto: Codable {
    let id: String
    let label: String
    let imageUrl: String?
    let source: String?
    let sourceRef: String?
}

struct AacSuggestedReplyDto: Codable {
    let type: String
    let id: String
    let label: String?
    let imageUrl: String?
    let source: String?
    let sourceRef: String?
    let storageKey: String?
    let seconds: Int?

    var isWaitStep: Bool { type.uppercased() == "WAIT" }

    init(type: String, id: String, label: String?, imageUrl: String?,
         source: String?, sourceRef: String?, storageKey: String?, seconds: Int?) {
        self.type = type; self.id = id; self.label = label; self.imageUrl = imageUrl
        self.source = source; self.sourceRef = sourceRef
        self.storageKey = storageKey; self.seconds = seconds
    }

    // The server omits `type` for plain cards and omits `id` for WAIT steps
    // ({"type":"WAIT","seconds":300}) — default both so decoding never fails.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seconds    = try c.decodeIfPresent(Int.self, forKey: .seconds)
        type       = try c.decodeIfPresent(String.self, forKey: .type) ?? "CARD"
        id         = try c.decodeIfPresent(String.self, forKey: .id) ?? "WAIT_\(UUID().uuidString)"
        label      = try c.decodeIfPresent(String.self, forKey: .label)
        imageUrl   = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        source     = try c.decodeIfPresent(String.self, forKey: .source)
        sourceRef  = try c.decodeIfPresent(String.self, forKey: .sourceRef)
        storageKey = try c.decodeIfPresent(String.self, forKey: .storageKey)
    }
}

struct AacUserDto: Decodable {
    let id: String
    let name: String
    let role: String
    let avatarItemId: String?
    let avatarImageUrl: String?
}

struct AacReplyShortDto: Decodable {
    let id: String
    let reply: [AacCardDto]   // multiple cards — changed from String in "multiple answers" update
    let createdAt: String
}

struct AacMessageDetailsDto: Decodable {
    let id: String
    let fromUser: AacUserDto
    let toUser: AacUserDto
    let message: [AacCardDto]
    let suggestedReplies: [AacSuggestedReplyDto]
    let mode: String
    let reply: AacReplyShortDto?
    let requiredReplyCount: Int?  // how many cards the user must select
    let createdAt: String
    let answeredAt: String?
}

struct AacMessageListItemDto: Decodable, Identifiable {
    let id: String
    let familyId: String
    let fromUserId: String
    let toUserId: String
    let fromUser: AacUserDto
    let toUser: AacUserDto
    let message: [AacCardDto]
    let suggestedReplies: [AacSuggestedReplyDto]
    let reply: AacReplyShortDto?
    let requiredReplyCount: Int?  // how many cards the user must select
    let createdAt: String
    let mode: String
    let answeredAt: String?
}

struct AacMessagesResponse: Decodable {
    let ok: Bool
    let items: [AacMessageListItemDto]
}

struct SendAacMessageRequest: Encodable {
    let targetUserId: String
    let mode: String
    let cards: [AacCardDto]
    let suggestedReplies: [AacSuggestedReplyDto]
    let requiredReplyCount: Int?
}

struct SendAacMessageResponse: Decodable {
    let ok: Bool
    let messageId: String
}

struct SendAacReplyRequest: Encodable {
    let reply: [AacCardDto]   // multiple selected cards
}

struct SendAacReplyResponse: Decodable {
    let ok: Bool
    let replyId: String
}

struct ArasaacItemDto: Decodable {
    let id: String
    let label: String?
    let imageUrl: String?
}

struct ArasaacSearchResponse: Decodable {
    let items: [ArasaacItemDto]
}

struct WaitStepDto: Codable {
    let type: String
    let seconds: Int
}
