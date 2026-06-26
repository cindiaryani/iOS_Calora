import SwiftUI

/// Full-screen fitness chatbot. Restricted to workout / fitness topics by the
/// system prompt in `FitnessCoachChatService`.
struct CoachChatView: View {
    @StateObject private var chat = FitnessCoachChatService()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    private let accent = Color.appPrimary

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .background(Color.appBackground)
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        chat.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .disabled(chat.isResponding)
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    disclaimer

                    ForEach(chat.messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }

                    if chat.isResponding {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: chat.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: chat.isResponding) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var disclaimer: some View {
        Label("I only answer fitness & workout questions.", systemImage: "shield.lefthalf.filled")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(accent.opacity(0.12), in: Capsule())
    }

    private func bubble(for message: CoachChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 36) }

            if !isUser {
                Image(systemName: "figure.run.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
            }

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(bubbleTextColor(isUser: isUser, isError: message.isError))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground(isUser: isUser, isError: message.isError), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if isUser {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appTextSecondary)
            }

            if !isUser { Spacer(minLength: 36) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func bubbleBackground(isUser: Bool, isError: Bool) -> Color {
        if isError { return Color.appIntensityHigh.opacity(0.14) }
        return isUser ? accent : Color.appSurface
    }

    private func bubbleTextColor(isUser: Bool, isError: Bool) -> Color {
        if isError { return Color.appTextPrimary }
        return isUser ? Color.appOnPrimary : Color.appTextPrimary
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title3)
                .foregroundStyle(accent)
            ProgressView()
            Text("Coach is thinking…")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputBar: some View {
        VStack(spacing: 10) {
            if chat.messages.count <= 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chat.suggestions, id: \.self) { suggestion in
                            Button {
                                chat.draft = suggestion
                                inputFocused = false
                                Task { await chat.send() }
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 34)
                                    .background(Color.appSurfaceMuted, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            HStack(spacing: 10) {
                TextField("Ask about your workout…", text: $chat.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    inputFocused = false
                    Task { await chat.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.appOnPrimary)
                        .frame(width: 40, height: 40)
                        .background(canSend ? accent : Color.appTextHint, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .padding(.top, 2)
        }
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var canSend: Bool {
        !chat.isResponding && !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chat.isResponding {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = chat.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

struct CoachChatView_Previews: PreviewProvider {
    static var previews: some View {
        CoachChatView()
    }
}
