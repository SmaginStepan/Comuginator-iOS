import Foundation

struct FamilyDto: Codable {
    let id: String
    let name: String
}

struct MeDto: Decodable {
    let userId: String
    let deviceId: String
    let role: String
}

struct UserDto: Decodable, Identifiable {
    let id: String
    let familyId: String
    let role: String
    let name: String
    let avatarItemId: String?
    let avatarImageUrl: String?
    let devices: [DeviceDto]?
}

struct FamilyMeResponse: Decodable {
    let family: FamilyDto
    let me: MeDto
    let users: [UserDto]
}

struct UpdateNameRequest: Encodable {
    let name: String
}

struct UpdateFamilyRequest: Encodable {
    let name: String?
    let timezone: String?
}

struct MyFamilyDto: Decodable {
    let familyId: String
    let familyName: String?
    let userId: String
    let userName: String?
    let role: String
}

struct MyFamiliesResponse: Decodable {
    let ok: Bool
    let families: [MyFamilyDto]
}

struct UpdateFamilyResponse: Decodable {
    let ok: Bool
    let family: FamilyDto
}

struct UpdateUserResponse: Decodable {
    let ok: Bool
    let user: UserDto
}

struct UpdateMyAvatarRequest: Encodable {
    let avatarItemId: String
}

struct UpdateMyAvatarResponse: Decodable {
    let ok: Bool
    let user: UserDto
}
