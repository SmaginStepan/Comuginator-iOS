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
