import Foundation

// MARK: - Family & Auth
extension APIClient {
    func createFamily(_ body: CreateFamilyRequest) async throws -> CreateFamilyResponse {
        try await request(path: "v1/families/create", method: "POST", body: body, requiresAuth: false)
    }

    func joinFamily(_ body: JoinFamilyRequest) async throws -> JoinFamilyResponse {
        try await request(path: "v1/families/join", method: "POST", body: body, requiresAuth: false)
    }

    func createInvite(_ body: CreateInviteRequest) async throws -> CreateInviteResponse {
        try await request(path: "v1/invites", method: "POST", body: body)
    }

    func getMyFamily() async throws -> FamilyMeResponse {
        try await request(path: "v1/families/me")
    }

    func getMyFamilies() async throws -> MyFamiliesResponse {
        try await request(path: "v1/me/families")
    }

    func updateMyFamily(_ body: UpdateFamilyRequest) async throws -> UpdateFamilyResponse {
        try await request(path: "v1/families/me", method: "PATCH", body: body)
    }

    func deleteFamily() async throws -> OkResponse {
        try await request(path: "v1/families/me", method: "DELETE")
    }
}

// MARK: - Devices
extension APIClient {
    func heartbeat(_ body: HeartbeatRequest) async throws -> HeartbeatResponse {
        try await request(path: "v1/devices/heartbeat", method: "POST", body: body)
    }

    func createCommand(deviceId: String, body: CreateCommandRequest) async throws -> CreateCommandResponse {
        try await request(path: "v1/devices/\(deviceId)/commands", method: "POST", body: body)
    }

    func updateDeviceName(deviceId: String, body: UpdateNameRequest) async throws -> UpdateDeviceResponse {
        try await request(path: "v1/devices/\(deviceId)/name", method: "PATCH", body: body)
    }

    func deleteDevice(deviceId: String) async throws -> OkResponse {
        try await request(path: "v1/devices/\(deviceId)", method: "DELETE")
    }

    func updateFcmToken(_ body: FcmTokenRequest) async throws -> OkResponse {
        try await request(path: "v1/devices/fcm-token", method: "POST", body: body)
    }
}

// MARK: - Commands
extension APIClient {
    func getPendingCommands() async throws -> PendingCommandsResponse {
        try await request(path: "v1/commands/pending")
    }

    func ackCommand(id: String) async throws -> AckCommandResponse {
        try await request(path: "v1/commands/\(id)/ack", method: "POST")
    }
}

// MARK: - Users
extension APIClient {
    func updateUserName(userId: String, body: UpdateNameRequest) async throws -> UpdateUserResponse {
        try await request(path: "v1/users/\(userId)", method: "PATCH", body: body)
    }

    func updateUserAvatar(userId: String, body: UpdateMyAvatarRequest) async throws -> UpdateMyAvatarResponse {
        try await request(path: "v1/users/\(userId)/avatar", method: "PATCH", body: body)
    }

    func updateMyAvatar(_ body: UpdateMyAvatarRequest) async throws -> UpdateMyAvatarResponse {
        try await request(path: "v1/users/me/avatar", method: "PATCH", body: body)
    }

    func deleteUser(userId: String) async throws -> OkResponse {
        try await request(path: "v1/users/\(userId)", method: "DELETE")
    }
}

// MARK: - ARASAAC
extension APIClient {
    func searchArasaac(query: String) async throws -> ArasaacSearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "v1/arasaac/search?q=\(encoded)")
    }
}

// MARK: - Messages
extension APIClient {
    func sendMessage(_ body: SendAacMessageRequest) async throws -> SendAacMessageResponse {
        try await request(path: "v1/messages/aac", method: "POST", body: body)
    }

    func getMessages(familyId: String? = nil) async throws -> AacMessagesResponse {
        try await request(path: "v1/messages/aac?scope=all", familyId: familyId)
    }

    func getMessageById(messageId: String, familyId: String? = nil) async throws -> AacMessageDetailsDto {
        try await request(path: "v1/messages/aac/\(messageId)", familyId: familyId)
    }

    func replyToMessage(messageId: String, body: SendAacReplyRequest, familyId: String? = nil) async throws -> SendAacReplyResponse {
        try await request(path: "v1/messages/aac/\(messageId)/reply", method: "POST", body: body, familyId: familyId)
    }
}

// MARK: - Library
extension APIClient {
    func uploadPhoto(imageData: Data, fileName: String) async throws -> UploadFamilyPhotoResponse {
        try await upload(path: "v1/library/items/upload", imageData: imageData, fileName: fileName)
    }

    func getLibraryItems() async throws -> LibraryItemsResponse {
        try await request(path: "v1/library/items")
    }

    func deleteLibraryItem(itemId: String) async throws -> OkResponse {
        try await request(path: "v1/library/items/\(itemId)", method: "DELETE")
    }

    func renameLibraryItem(itemId: String, body: RenameLibraryItemRequest) async throws -> LibraryItemResponse {
        try await request(path: "v1/library/items/\(itemId)", method: "PATCH", body: body)
    }

    func createArasaacLibraryItem(_ body: CreateArasaacLibraryItemRequest) async throws -> LibraryItemResponse {
        try await request(path: "v1/library/items/arasaac", method: "POST", body: body)
    }

    func getLibrarySets() async throws -> LibrarySetsResponse {
        try await request(path: "v1/library/sets")
    }

    func createLibrarySet(_ body: CreateLibrarySetRequest) async throws -> LibrarySetResponse {
        try await request(path: "v1/library/sets", method: "POST", body: body)
    }

    func getLibrarySet(setId: String) async throws -> LibrarySetResponse {
        try await request(path: "v1/library/sets/\(setId)")
    }

    func updateLibrarySet(setId: String, body: UpdateLibrarySetRequest) async throws -> LibrarySetResponse {
        try await request(path: "v1/library/sets/\(setId)", method: "PATCH", body: body)
    }

    func deleteLibrarySet(setId: String) async throws -> OkResponse {
        try await request(path: "v1/library/sets/\(setId)", method: "DELETE")
    }

    func addItemsToSet(setId: String, body: AddItemsToSetRequest) async throws -> LibrarySetResponse {
        try await request(path: "v1/library/sets/\(setId)/items", method: "POST", body: body)
    }

    func removeItemFromSet(setId: String, itemId: String) async throws -> LibrarySetResponse {
        try await request(path: "v1/library/sets/\(setId)/items/\(itemId)", method: "DELETE")
    }

    func moveItemsInSet(setId: String, body: MoveLibrarySetItemsRequest) async throws -> OkResponse {
        try await request(path: "v1/library/sets/\(setId)/move-items", method: "POST", body: body)
    }
}

// MARK: - Child Home
extension APIClient {
    func getChildHomeNodes(parentId: String? = nil) async throws -> ChildHomeNodesResponse {
        var path = "v1/child-home/nodes"
        if let parentId { path += "?parentId=\(parentId)" }
        return try await request(path: path)
    }

    func createChildHomeNode(_ body: CreateChildHomeNodeRequest) async throws -> ChildHomeNodeResponse {
        try await request(path: "v1/child-home/nodes", method: "POST", body: body)
    }

    func updateChildHomeNode(nodeId: String, body: UpdateChildHomeNodeRequest) async throws -> ChildHomeNodeResponse {
        try await request(path: "v1/child-home/nodes/\(nodeId)", method: "PATCH", body: body)
    }

    func deleteChildHomeNode(nodeId: String) async throws -> OkResponse {
        try await request(path: "v1/child-home/nodes/\(nodeId)", method: "DELETE")
    }

    func requestChildHomeAction(nodeId: String) async throws -> ChildHomeActionRequestResponse {
        try await request(path: "v1/child-home/actions/\(nodeId)/request", method: "POST")
    }
}

// MARK: - Schedule
extension APIClient {
    func getScheduleItems() async throws -> ScheduleItemsResponse {
        try await request(path: "v1/schedule/items")
    }

    func createScheduleItem(_ body: CreateScheduleItemRequest) async throws -> ScheduleItemResponse {
        try await request(path: "v1/schedule/items", method: "POST", body: body)
    }

    func updateScheduleItem(id: String, body: UpdateScheduleItemRequest) async throws -> ScheduleItemResponse {
        try await request(path: "v1/schedule/items/\(id)", method: "PATCH", body: body)
    }

    func deleteScheduleItem(id: String) async throws -> OkResponse {
        try await request(path: "v1/schedule/items/\(id)", method: "DELETE")
    }
}
