import Foundation

struct LibraryItemDto: Codable, Identifiable {
    let id: String
    let label: String
    let imageUrl: String?
    let source: String?
    let sourceRef: String?
}

struct LibraryItemsResponse: Decodable {
    let ok: Bool
    let items: [LibraryItemDto]
}

struct LibraryItemResponse: Decodable {
    let ok: Bool
    let item: LibraryItemDto
}

struct LibrarySetDto: Decodable {
    let id: String
    let name: String
    let cover: LibraryItemDto?
    let itemsCount: Int?
}

struct LibrarySetDetailsDto: Decodable {
    let id: String
    let name: String
    let cover: LibraryItemDto?
    let items: [LibraryItemDto]
}

struct LibrarySetsResponse: Decodable {
    let ok: Bool
    let sets: [LibrarySetDto]
}

struct LibrarySetResponse: Decodable {
    let ok: Bool
    let set: LibrarySetDetailsDto
}

struct CreateLibrarySetRequest: Encodable {
    let name: String
    let coverItemId: String?
    let itemIds: [String]
}

struct UpdateLibrarySetRequest: Encodable {
    let name: String?
    let coverItemId: String?
}

struct AddItemsToSetRequest: Encodable {
    let itemIds: [String]
}

struct MoveLibrarySetItemsRequest: Encodable {
    let itemIds: [String]
}

struct MoveLibrarySetsRequest: Encodable {
    let setIds: [String]
}

struct RenameLibraryItemRequest: Encodable {
    let label: String
}

struct CreateArasaacLibraryItemRequest: Encodable {
    let label: String
    let sourceRef: String
}

struct UploadFamilyPhotoResponse: Decodable {
    let ok: Bool
    let item: LibraryItemDto
}

struct FamilyPhotoListResponse: Decodable {
    let ok: Bool
    let items: [LibraryItemDto]
}
