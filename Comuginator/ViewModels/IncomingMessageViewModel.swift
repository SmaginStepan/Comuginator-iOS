import Foundation
import Combine

@MainActor
final class IncomingMessageViewModel: ObservableObject {
    @Published var message: AacMessageDetailsDto?
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var selectedReplies: [AacSuggestedReplyDto] = []
    @Published var sequenceStepIndex = 0
    @Published var isWaitTimerRunning = false
    @Published var waitSecondsRemaining = 0
    @Published var isSendingReply = false
    @Published var replySuccess = false
    @Published var cardOpacities: [String: Double] = [:]

    var requiredCount: Int  { max(message?.requiredReplyCount ?? 1, 1) }
    var mode: String        { message?.mode ?? "NORMAL" }
    var replies: [AacSuggestedReplyDto] { message?.suggestedReplies ?? [] }
    var isAlreadyAnswered: Bool { message?.reply != nil }
    var canSend: Bool { selectedReplies.count >= requiredCount && !isSendingReply && !replySuccess }

    /// A "request" (e.g. child home action) has no suggested replies — there is
    /// nothing to answer, so the whole reply UI is hidden.
    var isRequestOnly: Bool { replies.isEmpty }

    /// NORMAL mode: cards still selectable (already-picked ones are hidden).
    var visibleNormalReplies: [AacSuggestedReplyDto] {
        let selectedIds = Set(selectedReplies.map(\.id))
        return replies.filter { !selectedIds.contains($0.id) }
    }

    // MARK: - Load

    /// Family the message was resolved in (may differ from the active family
    /// when the push belongs to another membership). Used for the reply too.
    private var resolvedFamilyId: String?

    func loadMessage(id: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let msg = try await APIClient.shared.getMessageById(messageId: id)
            resolvedFamilyId = nil
            setup(message: msg)
        } catch {
            // The message may belong to another family this device is in —
            // probe them without switching the active family.
            let others = SessionStore.shared.getFamilies()
                .filter { $0.familyId != SessionStore.shared.familyId }
            for family in others {
                if let msg = try? await APIClient.shared.getMessageById(
                    messageId: id, familyId: family.familyId
                ) {
                    resolvedFamilyId = family.familyId
                    setup(message: msg)
                    return
                }
            }
            statusText = error.localizedDescription
        }
    }

    func setup(message: AacMessageDetailsDto) {
        self.message = message
        cardOpacities = Dictionary(uniqueKeysWithValues: message.suggestedReplies.map { ($0.id, 1.0) })
        if message.mode == "SEQUENCE", let first = message.suggestedReplies.first {
            Task { await handleSequenceStep(first) }
        }
    }

    // MARK: - Normal mode

    func toggleNormalReply(_ reply: AacSuggestedReplyDto) {
        guard !isAlreadyAnswered, !replySuccess, !isSendingReply else { return }

        // Single reply → tap sends immediately
        if requiredCount <= 1 {
            selectedReplies = [reply]
            Task {
                await blink(cardId: reply.id)
                await sendReply(messageId: message?.id ?? "")
            }
            return
        }

        if selectedReplies.contains(where: { $0.id == reply.id }) {
            selectedReplies.removeAll { $0.id == reply.id }
        } else if selectedReplies.count < requiredCount {
            selectedReplies.append(reply)
            // Auto-send once the required number of cards is selected
            if selectedReplies.count == requiredCount {
                Task {
                    await blink(cardId: reply.id)
                    await sendReply(messageId: message?.id ?? "")
                }
            } else {
                Task { await blink(cardId: reply.id) }
            }
        }
    }

    /// Deselect a card from the "your reply" row (multi-select mode).
    func removeSelectedReply(_ reply: AacSuggestedReplyDto) {
        guard !isAlreadyAnswered, !replySuccess, !isSendingReply else { return }
        selectedReplies.removeAll { $0.id == reply.id }
    }

    // MARK: - Sequence mode

    func tapSequenceCard(_ reply: AacSuggestedReplyDto) {
        guard !isAlreadyAnswered, !replySuccess else { return }
        guard sequenceStepIndex < replies.count else { return }
        let current = replies[sequenceStepIndex]
        guard reply.id == current.id else {
            statusText = "Only the current step can be selected"
            return
        }
        Task { await handleSequenceStep(current) }
    }

    private func handleSequenceStep(_ step: AacSuggestedReplyDto) async {
        if step.isWaitStep, let secs = step.seconds {
            await runWaitTimer(seconds: secs)
        } else {
            await blink(cardId: step.id)
            selectedReplies.append(step)
            sequenceStepIndex += 1
            if sequenceStepIndex >= replies.count {
                await sendReply(messageId: message?.id ?? "")
            }
        }
    }

    private func runWaitTimer(seconds: Int) async {
        isWaitTimerRunning = true
        waitSecondsRemaining = seconds
        while waitSecondsRemaining > 0 && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            waitSecondsRemaining -= 1
        }
        isWaitTimerRunning = false
        sequenceStepIndex += 1
        if sequenceStepIndex < replies.count {
            await handleSequenceStep(replies[sequenceStepIndex])
        } else {
            await sendReply(messageId: message?.id ?? "")
        }
    }

    // MARK: - Blink animation (6 × 500 ms)

    func blink(cardId: String) async {
        for _ in 0..<6 {
            cardOpacities[cardId] = (cardOpacities[cardId] ?? 1.0) < 0.5 ? 1.0 : 0.15
            try? await Task.sleep(for: .milliseconds(500))
        }
        cardOpacities[cardId] = 1.0
    }

    // MARK: - Send reply

    func sendReply(messageId: String) async {
        guard !isSendingReply else { return }
        isSendingReply = true
        defer { isSendingReply = false }
        do {
            var cards = selectedReplies.map {
                AacCardDto(id: $0.id, label: $0.label ?? "", imageUrl: $0.imageUrl,
                           source: $0.source, sourceRef: $0.sourceRef)
            }
            // Mark finished sequences so other devices stop reopening them
            if mode == "SEQUENCE" {
                cards.append(AacCardDto(id: "SEQUENCE_COMPLETED", label: "Completed",
                                        imageUrl: "", source: "SYSTEM",
                                        sourceRef: "SEQUENCE_COMPLETED"))
            }
            _ = try await APIClient.shared.replyToMessage(messageId: messageId,
                                                          body: SendAacReplyRequest(reply: cards),
                                                          familyId: resolvedFamilyId)
            replySuccess = true
            statusText = "Reply sent!"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}
