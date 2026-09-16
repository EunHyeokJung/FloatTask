import AppKit
import FloatTaskCore
import SwiftUI

enum ChatMessageRole: String {
    case user
    case assistant
    case status
    case error
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatMessageRole
    let content: String
}

@MainActor
final class ChatSession: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isWorking = false
    @Published private(set) var activity: CodexTaskAgentActivity?

    private let agent = CodexTaskAgent()
    private var requestTask: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var activeReplyLanguage: ChatReplyLanguage = .korean

    func send(_ rawText: String, model: TaskViewModel, replyLanguage: ChatReplyLanguage) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }

        let history = messages.suffix(16).compactMap { item -> AgentChatMessage? in
            switch item.role {
            case .user:
                return AgentChatMessage(role: "user", content: item.content)
            case .assistant:
                return AgentChatMessage(role: "assistant", content: item.content)
            case .status, .error:
                return nil
            }
        }
        let database = model.database
        messages.append(ChatMessage(role: .user, content: text))
        let requestID = UUID()
        activeRequestID = requestID
        activeReplyLanguage = replyLanguage
        isWorking = true
        activity = .thinking

        requestTask = Task { [weak self, weak model] in
            guard let self, let model else { return }
            do {
                let response = try await agent.respond(
                    to: text,
                    history: Array(history),
                    database: database,
                    replyLanguage: replyLanguage
                ) { [weak self] nextActivity in
                    Task { @MainActor [weak self] in
                        guard let self, self.activeRequestID == requestID else { return }
                        self.activity = nextActivity
                    }
                }
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }
                if !response.actions.isEmpty { activity = .working }
                let changes = try model.applyCodexActions(response.actions, originalRequest: text, replyLanguage: replyLanguage)
                let reply = CodexTaskReplyFormatter.format(response.reply, appliedChanges: changes, replyLanguage: replyLanguage)
                messages.append(ChatMessage(role: .assistant, content: reply))
            } catch is CancellationError {
                return
            } catch {
                guard activeRequestID == requestID else { return }
                messages.append(ChatMessage(role: .error, content: error.localizedDescription))
            }
            if activeRequestID == requestID {
                activeRequestID = nil
                requestTask = nil
                isWorking = false
                activity = nil
            }
        }
    }

    func cancel() {
        guard isWorking else { return }
        stopRequest()
        messages.append(ChatMessage(role: .status, content: activeReplyLanguage.stoppedReply))
    }

    func reset() {
        if isWorking { stopRequest() }
        messages.removeAll()
    }

    private func stopRequest() {
        activeRequestID = nil
        requestTask?.cancel()
        requestTask = nil
        isWorking = false
        activity = nil
    }

}

private struct ChatPanelView: View {
    @ObservedObject var session: ChatSession
    @ObservedObject var model: TaskViewModel
    let onClose: () -> Void

    @State private var draft = ""
    @ObservedObject private var preferences = AppPreferences.shared
    @FocusState private var inputFocused: Bool

    var body: some View {
        SidePanelSurface {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.55)
                transcript
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                Divider().opacity(0.55)
                composer
            }
        }
        .onAppear { inputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            BloubAgentAvatar(activity: session.activity, size: 28)

            Text("Luna")
                .font(.system(size: 14, weight: .semibold))

            Text("xhigh")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()

            Button(action: session.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SidePanelIconButtonStyle())
            .disabled(session.messages.isEmpty && !session.isWorking)
            .help("Clear Chat")
            .accessibilityLabel("Clear Chat")

            Button {
                NotificationCenter.default.post(name: .floatTaskShowSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: DesignTokens.compactIconSize))
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SidePanelIconButtonStyle())
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityValue(preferences.replyLanguage.title)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SidePanelIconButtonStyle())
            .help("Close Chat")
            .accessibilityLabel("Close Chat")
        }
        .padding(.horizontal, DesignTokens.sidePanelHeaderInset)
        .frame(height: DesignTokens.sidePanelHeaderHeight)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if session.messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                            Text("Manage projects and tasks")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                    } else {
                        ForEach(session.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)
            .onChange(of: session.messages.count) { _, _ in
                scrollToLatest(proxy)
            }
            .onChange(of: session.isWorking) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }

            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(message.role == .error ? Color.red : Color.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(message.role == .user ? Color.accentColor.opacity(0.14) : Color(nsColor: .labelColor).opacity(0.055))
                }

            if message.role != .user { Spacer(minLength: 42) }
        }
    }

    private var composer: some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Enter a command", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .focused($inputFocused)
                .onSubmit(submit)
                .accessibilityLabel("Codex Command")

            Button(action: primaryAction) {
                Image(systemName: session.isWorking ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(actionColor)
            .disabled(!session.isWorking && !canSubmit)
            .help(session.isWorking ? "Stop Response" : "Send")
            .accessibilityLabel(session.isWorking ? "Stop Response" : "Send")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isWorking
    }

    private func submit() {
        guard canSubmit else { return }
        let message = draft
        draft = ""
        session.send(message, model: model, replyLanguage: preferences.replyLanguage)
        inputFocused = true
    }

    private func primaryAction() {
        if session.isWorking {
            session.cancel()
        } else {
            submit()
        }
    }

    private var actionColor: Color {
        if session.isWorking { return .red }
        return canSubmit ? .accentColor : .secondary.opacity(0.45)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = session.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

@MainActor
final class ChatPanelController {
    static let shared = ChatPanelController()

    private var panel: KeyableSidePanel?
    private weak var parentWindow: NSWindow?

    private init() {}

    func show(
        relativeTo parent: NSWindow,
        session: ChatSession,
        model: TaskViewModel,
        animated: Bool,
        onClose: @escaping () -> Void
    ) {
        close(animated: false)

        let targetFrame = SidePanelLayout.frame(relativeTo: parent)
        let startFrame = targetFrame.offsetBy(dx: DesignTokens.sidePanelOpenOffset, dy: 0)
        let panel = KeyableSidePanel(
            contentRect: animated ? startFrame : targetFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.level = parent.level
        panel.collectionBehavior = parent.collectionBehavior
        panel.alphaValue = animated ? 0 : 1
        panel.contentViewController = NSHostingController(
            rootView: ChatPanelView(session: session, model: model) {
                self.close(animated: animated)
                onClose()
            }
        )

        parent.addChildWindow(panel, ordered: .below)
        panel.orderFront(nil)
        panel.makeKey()
        self.panel = panel
        parentWindow = parent

        guard animated else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.sidePanelOpenDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func close(animated: Bool) {
        guard let panel else { return }
        panel.isClosing = true
        let parent = parentWindow
        self.panel = nil
        parentWindow = nil
        let finish = {
            parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.contentViewController = nil
            if NSApp.keyWindow == nil || NSApp.keyWindow === panel { parent?.makeKey() }
        }

        guard animated else {
            finish()
            return
        }

        let endFrame = panel.frame.offsetBy(dx: DesignTokens.sidePanelCloseOffset, dy: 0)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.sidePanelCloseDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(endFrame, display: true)
            panel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }
}
