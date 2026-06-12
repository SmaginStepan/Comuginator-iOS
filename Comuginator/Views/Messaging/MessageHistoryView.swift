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

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                let isRequestOnly = msg.suggestedReplies.isEmpty

                if isRequestOnly {
                    Text("Request")
                        .font(.caption2.weight(.medium)).foregroundStyle(.orange)
                } else {
                    Text(LocalizedStringKey(msg.mode == "SEQUENCE" ? "Sequence" : "Normal"))
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                }

                // Cards row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(msg.message, id: \.id) { card in
                            VStack(spacing: 4) {
                                AuthImageView(urlString: card.imageUrl)
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

                // Reply preview (only for messages that expect a reply)
                if !isRequestOnly {
                    if let reply = msg.reply {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption2).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(reply.reply, id: \.id) { card in
                                        Text(card.label)
                                            .font(.caption)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(.green.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Awaiting reply")
                            .font(.caption2).foregroundStyle(.secondary).italic()
                    }
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
}
