import Foundation

struct CreateFamilyRequest: Encodable {
    let userName: String
    let deviceName: String
    let deviceId: String
    let familyName: String?
    let timezone: String?
}

struct CreateFamilyResponse: Decodable {
    let familyId: String
    let userId: String
    let deviceId: String
    let token: String
    let role: String
}

struct JoinFamilyRequest: Encodable {
    let code: String
    let userName: String
    let deviceName: String
    let deviceId: String
    let timezone: String?
}

struct JoinFamilyResponse: Decodable {
    let familyId: String
    let userId: String
    let deviceId: String
    let token: String
    let role: String
    let userCreated: Bool
}

struct CreateInviteRequest: Encodable {
    let role: String
    let expiresInMinutes: Int
}

struct CreateInviteResponse: Decodable {
    let inviteId: String
    let code: String
    let expiresAt: String
}
