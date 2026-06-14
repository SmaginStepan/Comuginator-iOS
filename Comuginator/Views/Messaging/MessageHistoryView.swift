import SwiftUI

struct MessageHistoryView: View {
    let targetUserId: String
    let targetUserName: String

    @StateObject private var vm = MessageHistoryViewModel()
    @State private var repeatMessage: AacMessageListItemDto?

    var body: some View {
        Group {
            if vm.isLoading && vm.messages.isEmpty {
                ProgressView("Loading…")
            } else if vm.messages.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "bubble.left.and.bubble.right")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.messages, id: \.id) { msg in
                                MessageBubble(msg: msg, isMine: vm.isSentByMe(msg))
                                    .id(msg.id)
                                    .onTapGesture {
                                        // Request-only messages can't be repeated
                                        if !msg.suggestedReplies.isEmpty { repeatMessage = msg }
                                    }
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .navigationTitle(targetUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load(targetUserId: targetUserId) } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await vm.load(targetUserId: targetUserId) }
        .sheet(item: $repeatMessage) { msg in
            ComposeMessageView(
                targetUserId: targetUserId,
                targetUserName: targetUserName,
                initialMode: msg.mode,
                initialMessageCards: msg.message,
                initialReplyCards: msg.suggestedReplies,
                initialRequiredReplyCount: msg.requiredReplyCount ?? 1
            )
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let msg: AacMessageListItemDto
    let isMine: Bool

    private var hasSuggestedReplies: Bool { !msg.suggestedReplies.isEmpty }

    /// Reply options as displayable cards (WAIT steps filtered out).
    private var suggestedCards: [(id: String, url: String?, label: String)] {
        msg.suggestedReplies
            .filter { !$0.isWaitStep }
            .map { ($0.id, $0.imageUrl, $0.label ?? $0.id) }
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                if hasSuggestedReplies {
                    // A question/exclamation with reply options — hide the system
                    // message card and show the options + the chosen answer.
                    Text(LocalizedStringKey(msg.mode == "SEQUENCE" ? "Sequence" : "Normal"))
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)

                    Text("Suggested Replies")
                        .font(.caption2).foregroundStyle(.secondary)
                    cardRow(suggestedCards)

                    if let reply = msg.reply, !reply.reply.isEmpty {
                        Text("Selected reply")
                            .font(.caption2).foregroundStyle(.secondary)
                        cardRow(reply.reply
                            .filter { $0.id != "SEQUENCE_COMPLETED" }
                            .map { ($0.id, $0.imageUrl, $0.label) })
                    } else {
                        Text("Awaiting reply")
                            .font(.caption2).foregroundStyle(.secondary).italic()
                    }
                } else {
                    // Request-only: show the message cards.
                    Text("Request")
                        .font(.caption2.weight(.medium)).foregroundStyle(.orange)
                    cardRow(msg.message.map { ($0.id, $0.imageUrl, $0.label) })
                }

                // Timestamp
                Text(TimeFormat.dateTime(msg.createdAt))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(isMine ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12))

            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private func cardRow(_ cards: [(id: String, url: String?, label: String)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(cards, id: \.id) { card in
                    VStack(spacing: 4) {
                        AuthImageView(urlString: card.url)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(card.label)
                            .font(.caption2)
                            .lineLimit(2)
                            .frame(width: 56)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}
