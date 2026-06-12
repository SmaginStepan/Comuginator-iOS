import Foundation

struct ChildHomeNodeItemDto: Decodable {
    let id: String
    let label: String
    let source: String?
    let sourceRef: String?
    let imageUrl: String?
    let isVisible: Bool
}

struct ChildHomeTargetDto: Decodable {
    let id: String
    let nodeId: String
    let userId: String
}

struct ChildHomeNodeDto: Decodable, Identifiable {
    let id: String
    let familyId: String
    let itemId: String?
    let parentId: String?
    let type: String
    let sortOrder: Int
    let targetMode: String?
    let blinkEnabled: Bool
    let blinkSeconds: Int?
    let labelOverride: String?
    let isVisible: Bool
    let item: ChildHomeNodeItemDto?
    let targets: [ChildHomeTargetDto]
}

struct ChildHomeNodesResponse: Decodable {
    let ok: Bool
    let items: [ChildHomeNodeDto]
}

struct ChildHomeNodeResponse: Decodable {
    let ok: Bool
    let item: ChildHomeNodeDto
}

struct ChildHomeActionRequestResponse: Decodable {
    let ok: Bool
    let sentCount: Int
    let blinkEnabled: Bool
    let blinkSeconds: Int?
}

struct CreateChildHomeNodeRequest: Encodable {
    let itemId: String?
    let parentId: String?
    let type: String
    let sortOrder: Int
    let targetMode: String?
    let targetUserIds: [String]
    let blinkEnabled: Bool
    let blinkSeconds: Int?
}

struct UpdateChildHomeNodeRequest: Encodable {
    let itemId: String?
    let parentId: String?
    let type: String?
    let sortOrder: Int?
    let targetMode: String?
    let targetUserIds: [String]?
    let blinkEnabled: Bool?
    let blinkSeconds: Int?
    let labelOverride: String?
    let isVisible: Bool?
}
