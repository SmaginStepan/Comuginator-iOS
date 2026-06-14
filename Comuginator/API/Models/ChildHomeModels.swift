import Foundation

struct ChildHomeNodeItemDto: Decodable {
    let id: String
    let label: String
    let source: String?
    let sourceRef: String?
    let imageUrl: String?
    let isVisible: Bool

    private enum CodingKeys: String, CodingKey {
        case id, label, source, sourceRef, imageUrl, isVisible
    }

    // Tolerate a missing isVisible (Android defaults it to true via Gson).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        label     = try c.decode(String.self, forKey: .label)
        source    = try c.decodeIfPresent(String.self, forKey: .source)
        sourceRef = try c.decodeIfPresent(String.self, forKey: .sourceRef)
        imageUrl  = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
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

    private enum CodingKeys: String, CodingKey {
        case id, familyId, itemId, parentId, type, sortOrder, targetMode
        case blinkEnabled, blinkSeconds, labelOverride, isVisible, item, targets
    }

    // Swift's Codable is strict about missing keys; Android (Gson) fills them
    // with defaults. Mirror those defaults so a sparse node still decodes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        familyId      = try c.decodeIfPresent(String.self, forKey: .familyId) ?? ""
        itemId        = try c.decodeIfPresent(String.self, forKey: .itemId)
        parentId      = try c.decodeIfPresent(String.self, forKey: .parentId)
        type          = try c.decodeIfPresent(String.self, forKey: .type) ?? "ACTION"
        sortOrder     = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        targetMode    = try c.decodeIfPresent(String.self, forKey: .targetMode)
        blinkEnabled  = try c.decodeIfPresent(Bool.self, forKey: .blinkEnabled) ?? false
        blinkSeconds  = try c.decodeIfPresent(Int.self, forKey: .blinkSeconds)
        labelOverride = try c.decodeIfPresent(String.self, forKey: .labelOverride)
        isVisible     = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        item          = try c.decodeIfPresent(ChildHomeNodeItemDto.self, forKey: .item)
        targets       = try c.decodeIfPresent([ChildHomeTargetDto].self, forKey: .targets) ?? []
    }
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
