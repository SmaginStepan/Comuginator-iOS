import Foundation

struct DeviceStateDto: Decodable {
    let deviceId: String
    let volumePercent: Int?
    let batteryPercent: Int?
    let isCharging: Bool?
    let reportedAt: String?
}

struct DeviceDto: Decodable, Identifiable {
    let id: String
    let deviceId: String
    let name: String
    let createdAt: String
    let lastSeenAt: String?
    let platform: String?
    let model: String?
    let osVersion: String?
    let appVersion: String?
    let state: DeviceStateDto?
}

struct DeviceNameDto: Decodable {
    let deviceId: String
    let name: String
}

struct HeartbeatRequest: Encodable {
    let batteryPercent: Int?
    let volumePercent: Int?
    let isCharging: Bool
    let reportedAt: String
    let platform: String
    let model: String
    let osVersion: String
    let appVersion: String
}

struct HeartbeatResponse: Decodable {
    let ok: Bool
    let now: String
}

struct CreateCommandRequest: Encodable {
    let type: String
    let payload: [String: JSONValue]
}

struct CreateCommandResponse: Decodable {
    let ok: Bool
    let commandId: String
}

struct CommandDto: Decodable {
    let id: String
    let deviceId: String
    let type: String
    let payload: [String: JSONValue]?
    let status: String
    let createdAt: String
}

struct PendingCommandsResponse: Decodable {
    let items: [CommandDto]
}

struct AckCommandResponse: Decodable {
    let ok: Bool
}

struct UpdateDeviceResponse: Decodable {
    let ok: Bool
    let device: DeviceDto
}

struct FcmTokenRequest: Encodable {
    let fcmToken: String
}
