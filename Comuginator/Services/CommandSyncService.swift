import Foundation
import Combine
#if canImport(UIKit)
import UIKit
import MediaPlayer
#endif

extension Notification.Name {
    /// Server applied a schedule's force-show/hide to child home nodes.
    static let childHomeScheduleApplied = Notification.Name("childHomeScheduleApplied")
}

/// iOS counterpart of Android's CommandSyncWorker + BaseActivity.checkPendingIncomingMessages.
///
/// Polls pending device commands while the app is in the foreground and
/// auto-opens the incoming-message screen when a message awaits this user's
/// reply (or a reply to this user's message arrived) — this is what delivers
/// messages when push notifications aren't available.
@MainActor
final class CommandSyncService {
    static let shared = CommandSyncService()
    private init() {}

    private var loopTask: Task<Void, Never>?
    /// Avoid re-opening the same message every poll after the user dismissed it.
    private var lastRoutedMessageId: String?

    // MARK: - Lifecycle

    func start() {
        stop()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncOnce()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    /// Allow the same message to reopen on the next app activation
    /// (mirrors Android re-checking on every activity resume).
    func resetRoutingMemory() {
        lastRoutedMessageId = nil
    }

    // MARK: - Sync

    func syncOnce() async {
        guard SessionStore.shared.isConnected else { return }

        // 1. Process queued device commands
        let pending = (try? await APIClient.shared.getPendingCommands())?.items ?? []
        var pendingMessageMap: [String: String] = [:]   // messageId → commandId
        var pendingReplyMap: [String: String] = [:]

        for command in pending where command.status == "queued" {
            switch command.type {
            case "set_volume":
                if let percent = command.payload?["volumePercent"]?.intValue {
                    Self.setSystemVolume(percent)
                }
                await ack(command.id)
            case "aac_message_available":
                if let id = command.payload?["messageId"]?.stringValue {
                    pendingMessageMap[id] = command.id
                }
            case "aac_reply_available":
                if let id = command.payload?["messageId"]?.stringValue {
                    pendingReplyMap[id] = command.id
                }
            case "invite_used":
                if let id = command.payload?["inviteId"]?.stringValue {
                    SessionStore.shared.lastUsedInviteId = id
                }
                await ack(command.id)
            case "child_home_schedule_applied":
                NotificationCenter.default.post(name: .childHomeScheduleApplied, object: nil)
                await ack(command.id)
            default:
                await ack(command.id)
            }
        }

        // 2. Find a message that should open
        guard let messages = try? await APIClient.shared.getMessages() else { return }
        let myUserId = SessionStore.shared.userId

        let incomingToAnswer = messages.items
            .filter { Self.shouldOpenIncoming($0, userId: myUserId) }
            .max { $0.createdAt < $1.createdAt }

        let repliedToMyMessage = messages.items
            .filter { $0.fromUserId == myUserId && $0.reply != nil && pendingReplyMap[$0.id] != nil }
            .max { $0.createdAt < $1.createdAt }

        let target = incomingToAnswer ?? repliedToMyMessage
        guard let target else { return }

        // Don't fight the user: skip if a message sheet is already open or
        // this exact message was already offered this session.
        guard NotificationRouter.shared.pendingMessageId == nil,
              target.id != lastRoutedMessageId else { return }

        lastRoutedMessageId = target.id
        NotificationRouter.shared.pendingMessageId = target.id

        // Ack the command that announced it (if any)
        if let commandId = pendingMessageMap[target.id] ?? pendingReplyMap[target.id] {
            await ack(commandId)
        }
    }

    private func ack(_ commandId: String) async {
        _ = try? await APIClient.shared.ackCommand(id: commandId)
    }

    // MARK: - Should-open logic (port of Android BaseActivity.shouldOpenIncoming)

    static func shouldOpenIncoming(_ msg: AacMessageListItemDto, userId: String?) -> Bool {
        guard msg.toUserId == userId else { return false }
        guard !msg.suggestedReplies.isEmpty else { return false }

        if msg.mode != "SEQUENCE" {
            return msg.reply == nil
        }

        guard let currentReplyId = msg.reply?.reply.last?.id else { return true }
        if currentReplyId == "SEQUENCE_COMPLETED" { return false }
        guard let currentIndex = msg.suggestedReplies.firstIndex(where: { $0.id == currentReplyId })
        else { return true }
        return currentIndex < msg.suggestedReplies.count - 1
    }

    // MARK: - System volume (best effort)

    /// iOS has no public API to set the system volume directly; nudging the
    /// hidden MPVolumeView slider is the long-standing workaround.
    static func setSystemVolume(_ percent: Int) {
        #if canImport(UIKit)
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.alpha = 0.01
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        window.addSubview(volumeView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = Float(max(0, min(100, percent))) / 100.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                volumeView.removeFromSuperview()
            }
        }
        #endif
    }
}
