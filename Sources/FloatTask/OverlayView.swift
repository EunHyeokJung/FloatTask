import AppKit
import FloatTaskCore
import SwiftUI

private struct TaskComposerRequest: Equatable {
    let projectID: UUID
    let afterTaskID: UUID?
}

struct OverlayView: View {
    @StateObject private var model = TaskViewModel()
    @StateObject private var chatSession = ChatSession()
    @StateObject private var completedTasks = CompletedTasksPanelController()
    @ObservedObject private var preferences = AppPreferences.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var composerRequest: TaskComposerRequest?
    @State private var projectTitleFocusRequest: UUID?
    @State private var isChatOpen = false

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea(.container, edges: .top)
            Color(nsColor: .windowBackgroundColor).opacity(0.82)
                .ignoresSafeArea(.container, edges: .top)

            VStack(spacing: 0) {
                toolbar
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .background(WindowDragSurface())

                if model.database.projects.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.projectSpacing) {
                            ForEach(model.database.projects) { project in
                                ProjectSection(
                                    project: project,
                                    model: model,
                                    showCompletedTasks: { showCompletedTasks(projectID: project.id) },
                                    projectTitleFocusRequest: $projectTitleFocusRequest,
                                    composerRequest: Binding(
                                        get: {
                                            composerRequest?.projectID == project.id ? composerRequest : nil
                                        },
                                        set: { request in
                                            if let request {
                                                composerRequest = request
                                            } else if composerRequest?.projectID == project.id {
                                                composerRequest = nil
                                            }
                                        }
                                    )
                                )
                                .transition(projectTransition)
                            }
                        }
                        .padding(.horizontal, DesignTokens.contentInset)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            if model.errorMessage != nil {
                errorIndicator
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(12)
            }
        }
        .frame(
            minWidth: DesignTokens.panelMinWidth, maxWidth: .infinity,
            minHeight: DesignTokens.panelMinHeight, maxHeight: .infinity
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.panelRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatTaskAddTask)) { _ in
            if let firstProject = model.database.projects.first {
                withTaskAnimation(DesignTokens.insertion) {
                    composerRequest = TaskComposerRequest(
                        projectID: firstProject.id,
                        afterTaskID: nil
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatTaskAddProject)) { _ in
            addProjectAndFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatTaskShowCompleted)) { _ in
            showCompletedTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            ChatPanelController.shared.close(animated: false)
            completedTasks.close(animated: false)
            SettingsPanelController.shared.close()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            toolbarButton(
                symbol: preferences.keepOnTop ? "pin.fill" : "pin",
                label: preferences.keepOnTop ? "Use Normal Window" : "Keep on Top",
                action: toggleFloating
            )

            Spacer()

            toolbarButton(
                symbol: isChatOpen ? "bubble.left.fill" : "bubble.left",
                label: isChatOpen ? "Close Chat" : "Open Chat"
            ) {
                toggleChat()
            }

            toolbarButton(symbol: "folder.badge.plus", label: "Add Project") {
                addProjectAndFocus()
            }

            toolbarButton(
                symbol: completedTasks.isVisible ? "checkmark.circle.fill" : "checkmark.circle",
                label: completedTasks.isVisible ? "Close Completed Tasks" : "Show Completed Tasks"
            ) {
                if completedTasks.isVisible {
                    completedTasks.close(animated: !reduceMotion)
                } else {
                    showCompletedTasks()
                }
            }

            toolbarButton(symbol: "gearshape", label: "Settings") {
                NotificationCenter.default.post(name: .floatTaskShowSettings, object: nil)
            }

            toolbarButton(symbol: "xmark", label: "Close") {
                NSApp.terminate(nil)
            }
        }
    }

    private var emptyState: some View {
        Button {
            addProjectAndFocus()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Add Project")
    }

    private var errorIndicator: some View {
        Button {
            model.clearError()
        } label: {
            Image(systemName: "exclamationmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
        }
        .buttonStyle(.plain)
        .help(model.errorMessage ?? "")
        .accessibilityLabel(model.errorMessage ?? "Error")
    }

    private func toolbarButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }

    private var projectTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    private func withTaskAnimation(_ animation: Animation, action: () -> Void) {
        withAnimation(.taskMotion(reduceMotion: reduceMotion, preferred: animation), action)
    }

    private func addProjectAndFocus() {
        withTaskAnimation(DesignTokens.insertion) {
            if let projectID = model.addProject() {
                projectTitleFocusRequest = projectID
            }
        }
    }

    private func toggleFloating() {
        preferences.keepOnTop.toggle()
    }

    private func showCompletedTasks(projectID: UUID? = nil) {
        guard let window = FloatTaskWindowMode.mainWindow else { return }
        completedTasks.show(relativeTo: window, model: model, projectID: projectID, animated: !reduceMotion)
    }

    private func toggleChat() {
        if isChatOpen {
            ChatPanelController.shared.close(animated: !reduceMotion)
            isChatOpen = false
            return
        }

        guard let window = FloatTaskWindowMode.mainWindow else { return }

        isChatOpen = true
        ChatPanelController.shared.show(
            relativeTo: window,
            session: chatSession,
            model: model,
            animated: !reduceMotion
        ) {
            isChatOpen = false
        }
    }
}

private struct ProjectSection: View {
    let project: TaskProject
    @ObservedObject var model: TaskViewModel
    let showCompletedTasks: () -> Void
    @Binding var projectTitleFocusRequest: UUID?
    @Binding var composerRequest: TaskComposerRequest?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var projectTitle: String
    @State private var confirmingDelete = false
    @FocusState private var projectTitleFocused: Bool

    init(
        project: TaskProject,
        model: TaskViewModel,
        showCompletedTasks: @escaping () -> Void,
        projectTitleFocusRequest: Binding<UUID?>,
        composerRequest: Binding<TaskComposerRequest?>
    ) {
        self.project = project
        self.model = model
        self.showCompletedTasks = showCompletedTasks
        self._projectTitleFocusRequest = projectTitleFocusRequest
        self._composerRequest = composerRequest
        self._projectTitle = State(initialValue: project.title)
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                TextField("Project", text: $projectTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 4)
                    .frame(height: 28)
                    .overlay(alignment: .bottom) {
                        inlineEditorFocusLine(isFocused: projectTitleFocused)
                    }
                    .focused($projectTitleFocused)
                    .onSubmit(commitProjectTitle)
                    .onExitCommand {
                        projectTitle = project.title
                        projectTitleFocused = false
                    }
                    .onTapGesture { beginProjectTitleEditing(selectAll: false) }
                    .accessibilityLabel("Project Name")
                    .onChange(of: projectTitleFocused) { wasFocused, isFocused in
                        if wasFocused && !isFocused { saveProjectTitle() }
                    }

                Spacer(minLength: 4)

                if completedCount > 0 {
                    Button(action: showCompletedTasks) {
                        HStack(spacing: DesignTokens.compactSpacing) {
                            Image(systemName: "checkmark.circle")
                                .accessibilityHidden(true)
                            Text("\(completedCount)")
                        }
                            .font(.system(size: DesignTokens.metadataFontSize))
                            .monospacedDigit()
                            .fixedSize()
                            .frame(minWidth: DesignTokens.controlSize, minHeight: DesignTokens.controlSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help("Show Completed Tasks")
                    .accessibilityLabel("\(project.title), \(completedCount) Completed Tasks")
                }

                Button {
                    presentComposer(afterTaskID: nil)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                }
                .buttonStyle(QuietButtonStyle())
                .help("Add Task")
                .accessibilityLabel("Add Task to \(project.title)")

                Menu {
                    Button("Rename") {
                        beginProjectTitleEditing(selectAll: true)
                    }
                    Divider()
                    Button("Delete Project", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Project Menu")
                .accessibilityLabel("\(project.title) Project Menu")
            }
            .frame(height: 36)

            VStack(spacing: 0) {
                ForEach(project.tasks) { task in
                    if !task.isCompleted {
                        TaskRow(task: task, model: model) {
                            presentComposer(afterTaskID: task.id)
                        }
                        .transition(taskTransition)
                    }

                    if composerRequest?.afterTaskID == task.id {
                        composer(afterTaskID: task.id)
                            .transition(taskTransition)
                    }
                }

                if composerRequest != nil, composerRequest?.afterTaskID == nil {
                    composer(afterTaskID: nil)
                        .transition(taskTransition)
                }
            }
            .animation(
                .taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.completion),
                value: project.tasks
            )
        }
        .onChange(of: project.title) { _, title in
            if !projectTitleFocused { projectTitle = title }
        }
        .onAppear {
            focusProjectTitleIfRequested(projectTitleFocusRequest)
        }
        .onChange(of: projectTitleFocusRequest) { _, projectID in
            focusProjectTitleIfRequested(projectID)
        }
        .confirmationDialog("Delete Project", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation(.taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.removal)) {
                    model.deleteProject(project.id)
                }
            }
        } message: {
            Text("This permanently deletes “\(project.title)” and all of its tasks.")
        }
    }

    private var taskTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .offset(y: -8).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    private var completedCount: Int {
        project.tasks.filter(\.isCompleted).count
    }

    private func presentComposer(afterTaskID: UUID?) {
        withAnimation(.taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.insertion)) {
            composerRequest = TaskComposerRequest(
                projectID: project.id,
                afterTaskID: afterTaskID
            )
        }
    }

    private func composer(afterTaskID: UUID?) -> some View {
        TaskComposer(
            projectID: project.id,
            afterTaskID: afterTaskID,
            model: model,
            isPresented: Binding(
                get: { composerRequest != nil },
                set: { if !$0 { composerRequest = nil } }
            ),
            onTaskCreated: { createdTaskID in
                composerRequest = TaskComposerRequest(
                    projectID: project.id,
                    afterTaskID: createdTaskID
                )
            }
        )
        .id(afterTaskID)
    }

    private func commitProjectTitle() {
        projectTitleFocused = false
    }

    private func focusProjectTitleIfRequested(_ projectID: UUID?) {
        guard projectID == project.id else { return }
        projectTitleFocusRequest = nil
        beginProjectTitleEditing(selectAll: true)
    }

    private func beginProjectTitleEditing(selectAll: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        FloatTaskWindowMode.mainWindow?.makeKey()
        DispatchQueue.main.async {
            projectTitleFocused = true
            guard selectAll else { return }
            DispatchQueue.main.async {
                guard projectTitleFocused else { return }
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        }
    }

    private func saveProjectTitle() {
        let clean = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            projectTitle = project.title
        } else if clean != project.title {
            model.renameProject(project.id, title: clean)
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    @ObservedObject var model: TaskViewModel
    let createNextTask: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftTitle: String
    @State private var hovering = false
    @State private var skipSaveOnBlur = false
    @FocusState private var titleFocused: Bool

    init(task: TaskItem, model: TaskViewModel, createNextTask: @escaping () -> Void) {
        self.task = task
        self.model = model
        self.createNextTask = createNextTask
        self._draftTitle = State(initialValue: task.title)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button {
                withAnimation(.taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.completion)) {
                    model.setTaskCompletion(task.id, completed: !task.isCompleted)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: DesignTokens.checkSize, height: DesignTokens.checkSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel(task.isCompleted ? "Reopen Task" : "Complete Task")

            ZStack(alignment: .topLeading) {
                TextField("Task", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(
                        titleFocused
                            ? (task.isCompleted ? Color.secondary : Color.primary)
                            : Color.clear
                    )
                    .strikethrough(titleFocused && task.isCompleted, color: .secondary)
                    .focused($titleFocused)
                    .onSubmit(commitTitle)
                    .onExitCommand {
                        skipSaveOnBlur = true
                        draftTitle = task.title
                        titleFocused = false
                    }
                    .onTapGesture { beginTitleEditing() }
                    .onChange(of: titleFocused) { wasFocused, isFocused in
                        if wasFocused && !isFocused {
                            if skipSaveOnBlur {
                                skipSaveOnBlur = false
                            } else {
                                _ = saveTitle()
                            }
                        }
                    }
                    .accessibilityLabel("Task Name")

                TaskTitleLabel(
                    title: draftTitle,
                    isExpanded: expandsTitle,
                    isCompleted: task.isCompleted
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5.5)
                    .opacity(titleFocused ? 0 : 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 28, alignment: .top)
            .overlay(alignment: .bottom) {
                inlineEditorFocusLine(isFocused: titleFocused)
            }
            .padding(.vertical, 6)

            Button {
                withAnimation(.taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.removal)) {
                    model.deleteTask(task.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
            }
            .buttonStyle(QuietButtonStyle(destructive: true))
            .padding(.top, 4)
            .help("Delete Task")
            .accessibilityLabel("Delete \(task.title)")
            .accessibilityHidden(!showsDeleteButton)
            .disabled(!showsDeleteButton)
            .opacity(showsDeleteButton ? 1 : 0)
            .animation(
                .taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.hover),
                value: showsDeleteButton
            )
        }
        .padding(.horizontal, 2)
        .frame(minHeight: DesignTokens.rowHeight, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .labelColor).opacity(hovering ? 0.055 : 0))
        }
        .contentShape(Rectangle())
        .onHover { value in
            hovering = value
        }
        .animation(
            .taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.taskExpansion),
            value: expandsTitle
        )
        .onChange(of: task.title) { _, title in
            if !titleFocused { draftTitle = title }
        }
        .contextMenu {
            Button("Rename") { beginTitleEditing() }
            Divider()
            Button(task.isCompleted ? "Reopen" : "Complete") {
                model.setTaskCompletion(task.id, completed: !task.isCompleted)
            }
            Divider()
            Button("Delete Task", role: .destructive) { model.deleteTask(task.id) }
        }
    }

    private var showsDeleteButton: Bool {
        hovering || titleFocused
    }

    private var expandsTitle: Bool {
        hovering && !titleFocused
    }

    private func commitTitle() {
        let shouldCreateNextTask = saveTitle()
        skipSaveOnBlur = true
        titleFocused = false
        if shouldCreateNextTask {
            DispatchQueue.main.async { createNextTask() }
        }
    }

    private func beginTitleEditing() {
        skipSaveOnBlur = false
        NSApp.activate(ignoringOtherApps: true)
        FloatTaskWindowMode.mainWindow?.makeKey()
        DispatchQueue.main.async { titleFocused = true }
    }

    @discardableResult
    private func saveTitle() -> Bool {
        let clean = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            draftTitle = task.title
            return false
        } else if clean != task.title {
            model.renameTask(task.id, title: clean)
        }
        return true
    }
}

private struct TaskTitleLabel: NSViewRepresentable {
    let title: String
    let isExpanded: Bool
    let isCompleted: Bool

    func makeNSView(context: Context) -> TaskTitleTextView {
        let textView = TaskTitleTextView()
        textView.layerContentsRedrawPolicy = .duringViewResize
        configure(textView)
        return textView
    }

    func updateNSView(_ textView: TaskTitleTextView, context: Context) {
        configure(textView)
        textView.displayIfNeeded()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView textView: TaskTitleTextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(
            width: width,
            height: textView.fittingHeight(for: width, expanded: isExpanded)
        )
    }

    private func configure(_ textView: TaskTitleTextView) {
        textView.title = title
        textView.isExpanded = isExpanded
        textView.isCompleted = isCompleted
    }
}

final class TaskTitleTextView: NSView {
    var title = "" {
        didSet { if title != oldValue { needsDisplay = true } }
    }
    var isExpanded = false {
        didSet { if isExpanded != oldValue { needsDisplay = true } }
    }
    var isCompleted = false {
        didSet { if isCompleted != oldValue { needsDisplay = true } }
    }

    override var isFlipped: Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        let sizeChanged = frame.size != newSize
        super.setFrameSize(newSize)
        if sizeChanged {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0 else { return }
        let renderedTitle = isExpanded ? title : wordTruncatedTitle(for: bounds.width)
        // Text layout drops an entire line when it does not fit in the supplied height.
        // Keep the full layout stable and clip its pixels to the animating viewport instead.
        let layoutHeight = max(bounds.height, fittingHeight(for: bounds.width, expanded: isExpanded))
        let layoutRect = NSRect(x: 0, y: 0, width: bounds.width, height: layoutHeight)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        NSAttributedString(string: renderedTitle, attributes: titleAttributes).draw(
            with: layoutRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }

    func fittingHeight(for width: CGFloat, expanded: Bool) -> CGFloat {
        guard expanded else { return lineHeight }
        let measuredBounds = NSAttributedString(
            string: title,
            attributes: titleAttributes
        ).boundingRect(
            with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(measuredBounds.height)
    }

    private var lineHeight: CGFloat {
        ceil(NSFont.systemFont(ofSize: 14).boundingRectForFont.height)
    }

    private func wordTruncatedTitle(for width: CGFloat) -> String {
        guard width > 0, measuredWidth(of: title) > width else { return title }

        let ellipsis = "…"
        var longestPrefix: String?
        title.enumerateSubstrings(
            in: title.startIndex..<title.endIndex,
            options: [.byWords]
        ) { _, wordRange, _, stop in
            let prefix = self.title[..<wordRange.upperBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = prefix + ellipsis
            if self.measuredWidth(of: candidate) <= width {
                longestPrefix = candidate
            } else {
                stop = true
            }
        }
        if let longestPrefix { return longestPrefix }

        var characterPrefix = ""
        for character in title {
            let candidate = characterPrefix + String(character) + ellipsis
            guard measuredWidth(of: candidate) <= width else { break }
            characterPrefix.append(character)
        }
        return characterPrefix + ellipsis
    }

    private func measuredWidth(of value: String) -> CGFloat {
        ceil((value as NSString).size(withAttributes: titleAttributes).width)
    }

    private var titleAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineBreakStrategy = .hangulWordPriority
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: isCompleted ? NSColor.secondaryLabelColor : NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        if isCompleted {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = NSColor.secondaryLabelColor
        }
        return attributes
    }
}

private struct TaskComposer: View {
    let projectID: UUID
    let afterTaskID: UUID?
    @ObservedObject var model: TaskViewModel
    @Binding var isPresented: Bool
    let onTaskCreated: (UUID) -> Void
    @State private var title = ""
    @State private var isSubmitting = false
    @State private var isDiscarding = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.tertiary)
                .frame(width: DesignTokens.checkSize, height: DesignTokens.checkSize)
                .accessibilityHidden(true)

            TextField("New task", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .frame(height: 28)
                .overlay(alignment: .bottom) {
                    inlineEditorFocusLine(isFocused: focused)
                }
                .focused($focused)
                .onSubmit(submit)
                .onExitCommand {
                    isDiscarding = true
                    isPresented = false
                }
                .onChange(of: focused) { wasFocused, isFocused in
                    if wasFocused && !isFocused, !isSubmitting, !isDiscarding {
                        finishEditing()
                    }
                }
                .accessibilityLabel("New Task Name")
        }
        .padding(.horizontal, 2)
        .frame(height: DesignTokens.rowHeight)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            FloatTaskWindowMode.mainWindow?.makeKey()
            DispatchQueue.main.async { focused = true }
        }
    }

    private func submit() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            isPresented = false
            return
        }
        isSubmitting = true
        guard let createdTaskID = model.addTask(
            projectID: projectID,
            title: clean,
            afterTaskID: afterTaskID
        ) else {
            isSubmitting = false
            return
        }
        title = ""
        onTaskCreated(createdTaskID)
    }

    private func finishEditing() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            isPresented = false
            return
        }
        if model.addTask(
            projectID: projectID,
            title: clean,
            afterTaskID: afterTaskID
        ) != nil {
            isPresented = false
        } else {
            DispatchQueue.main.async { focused = true }
        }
    }
}

@ViewBuilder
private func inlineEditorFocusLine(isFocused: Bool) -> some View {
    Rectangle()
        .fill(Color.accentColor.opacity(isFocused ? 0.55 : 0))
        .frame(height: 1)
        .allowsHitTesting(false)
}

private struct QuietButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(destructive ? Color.red : Color.secondary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .labelColor).opacity(configuration.isPressed ? 0.10 : 0))
            }
            .contentShape(Rectangle())
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
