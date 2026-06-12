import SwiftUI

struct IncomingMessageView: View {
    let messageId: String

    @StateObject private var vm = IncomingMessageViewModel()
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Message cards ──────────────────────────────────────
                    if let msg = vm.message {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("From \(msg.fromUser.name)", systemImage: "person.fill")
                                .font(.subheadline).foregroundStyle(.secondary)

                            if !msg.message.isEmpty {
                                if vm.isRequestOnly {
                                    Text("Request")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(msg.message, id: \.id) { card in
                                            CardTile(card: card, opacity: 1)
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // ── Reply section (hidden for request-only messages) ─
                        if !vm.isRequestOnly {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                replyHeader(msg: msg)

                                LazyVGrid(columns: columns, spacing: 12) {
                                    let shown = (msg.mode == "NORMAL")
                                        ? vm.visibleNormalReplies : vm.replies
                                    ForEach(shown, id: \.id) { reply in
                                        replyCard(reply, msg: msg)
                                    }
                                }

                                // Selected cards (multi-select) — tap to remove
                                if msg.mode == "NORMAL" && !vm.selectedReplies.isEmpty {
                                    Text("Your reply (\(vm.selectedReplies.count) of \(vm.requiredCount)):")
                                        .font(.caption).foregroundStyle(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(vm.selectedReplies, id: \.id) { reply in
                                                Button {
                                                    vm.removeSelectedReply(reply)
                                                } label: {
                                                    selectedReplyTile(reply)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // ── Status ─────────────────────────────────────────
                        if !vm.statusText.isEmpty {
                            Text(vm.statusText)
                                .font(.footnote)
                                .foregroundStyle(vm.replySuccess ? .green : .orange)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Incoming Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.replySuccess || vm.isAlreadyAnswered || vm.isRequestOnly {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .overlay { if vm.isLoading { loadingOverlay } }
        }
        .task { await vm.loadMessage(id: messageId) }
    }

    // MARK: - Reply header

    @ViewBuilder
    private func replyHeader(msg: AacMessageDetailsDto) -> some View {
        if vm.isAlreadyAnswered || vm.replySuccess {
            VStack(alignment: .leading, spacing: 8) {
                Label("Already answered", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.subheadline)
                // Show the received reply cards
                if let replyCards = msg.reply?.reply, !replyCards.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(replyCards.filter { $0.id != "SEQUENCE_COMPLETED" }, id: \.id) { card in
                                CardTile(card: card, opacity: 1)
                            }
                        }
                    }
                }
            }
        } else if msg.mode == "SEQUENCE" {
            if vm.isWaitTimerRunning {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("Wait: \(vm.waitSecondsRemaining)s")
                        .monospacedDigit()
                }
                .font(.subheadline).foregroundStyle(.orange)
            } else {
                Text("Step \(vm.sequenceStepIndex + 1) of \(vm.replies.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        } else {
            Text("Select \(vm.requiredCount) reply cards")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Reply card

    @ViewBuilder
    private func replyCard(_ reply: AacSuggestedReplyDto, msg: AacMessageDetailsDto) -> some View {
        let isSelected = vm.selectedReplies.contains { $0.id == reply.id }
        let isCurrentStep = msg.mode == "SEQUENCE" && vm.sequenceStepIndex < vm.replies.count
            && vm.replies[vm.sequenceStepIndex].id == reply.id
        let stepIndex = vm.replies.firstIndex { $0.id == reply.id } ?? -1
        let isDone = msg.mode == "SEQUENCE" && stepIndex < vm.sequenceStepIndex

        Button {
            if msg.mode == "SEQUENCE" {
                vm.tapSequenceCard(reply)
            } else {
                vm.toggleNormalReply(reply)
            }
        } label: {
            VStack(spacing: 6) {
                AuthImageView(urlString: reply.imageUrl)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected || isCurrentStep ? Color.blue : .clear, lineWidth: 3)
                )

                Text(reply.isWaitStep ? "⏳ \(reply.seconds ?? 0)s" : (reply.label ?? reply.id))
                    .font(.caption).lineLimit(2).multilineTextAlignment(.center)
            }
            .padding(8)
            .background(
                isSelected ? Color.blue.opacity(0.12) :
                isDone     ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .opacity(vm.cardOpacities[reply.id] ?? 1.0)
            .opacity(isDone ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(vm.isAlreadyAnswered || vm.replySuccess || vm.isWaitTimerRunning)
    }

    // MARK: - Selected reply tile

    private func selectedReplyTile(_ reply: AacSuggestedReplyDto) -> some View {
        VStack(spacing: 4) {
            AuthImageView(urlString: reply.imageUrl)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(reply.label ?? reply.id)
                .font(.caption2).lineLimit(1).frame(width: 56)
        }
        .padding(6)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .offset(x: 4, y: -4)
        }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Shared card tile

struct CardTile: View {
    let card: AacCardDto
    let opacity: Double

    var body: some View {
        VStack(spacing: 4) {
            AuthImageView(urlString: card.imageUrl)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(card.label)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .opacity(opacity)
    }
}
