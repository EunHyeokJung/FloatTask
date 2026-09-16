import AppKit
import FloatTaskCore
import SwiftUI

enum CompletedTaskSort: String, CaseIterable, Identifiable {
    case recentlyCompleted
    case added

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyCompleted: return "Recently completed"
        case .added: return "Date added"
        }
    }

    func precedes(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        switch self {
        case .recentlyCompleted:
            let leftDate = lhs.completedAt ?? .distantPast
            let rightDate = rhs.completedAt ?? .distantPast
            if leftDate != rightDate { return leftDate > rightDate }
        case .added:
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

@MainActor
final class CompletedTasksPanelController: ObservableObject {
    @Published private(set) var isVisible = false
    @Published var projectID: UUID?
    @Published var sort: CompletedTaskSort = .recentlyCompleted

    private var panel: KeyableSidePanel?
    private weak var parentWindow: NSWindow?

    func show(relativeTo parent: NSWindow, model: TaskViewModel, projectID: UUID?, animated: Bool) {
        self.projectID = projectID
        if let panel {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let targetFrame = SidePanelLayout.frame(relativeTo: parent)
        let startFrame = targetFrame.offsetBy(dx: DesignTokens.sidePanelOpenOffset, dy: 0)
        let panel = KeyableSidePanel(
            contentRect: animated ? startFrame : targetFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Completed Tasks"
        panel.identifier = NSUserInterfaceItemIdentifier("FloatTask.CompletedTasksPanel")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.level = parent.level
        panel.collectionBehavior = parent.collectionBehavior
        panel.alphaValue = animated ? 0 : 1
        panel.onEscape = { [weak self] in self?.close(animated: animated) }
        panel.contentViewController = NSHostingController(
            rootView: CompletedTasksView(model: model, controller: self) { [weak self] in
                self?.close(animated: animated)
            }
        )

        self.panel = panel
        parentWindow = parent
        parent.addChildWindow(panel, ordered: .below)
        isVisible = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

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
        isVisible = false
        let finish = {
            parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.onEscape = nil
            panel.contentViewController = nil
            // Do not steal focus if another side panel opened during the close animation.
            if NSApp.keyWindow == nil || NSApp.keyWindow === panel { parent?.makeKey() }
        }
        guard animated else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.sidePanelCloseDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(
                panel.frame.offsetBy(dx: DesignTokens.sidePanelCloseOffset, dy: 0), display: true
            )
            panel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }
}

private struct CompletedTaskEntry: Identifiable {
    let task: TaskItem
    let projectTitle: String
    var id: UUID { task.id }
}

private struct CompletedTasksView: View {
    @ObservedObject var model: TaskViewModel
    @ObservedObject var controller: CompletedTasksPanelController
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var entries: [CompletedTaskEntry] {
        model.database.projects
            .filter { controller.projectID == nil || $0.id == controller.projectID }
            .flatMap { project in
                project.tasks.filter(\.isCompleted).map {
                    CompletedTaskEntry(task: $0, projectTitle: project.title)
                }
            }
            .sorted { controller.sort.precedes($0.task, $1.task) }
    }

    var body: some View {
        SidePanelSurface {
            VStack(spacing: 0) {
                header
                Divider().opacity(0.55)

                if entries.isEmpty {
                    Text("No completed tasks")
                        .font(.system(size: DesignTokens.taskFontSize))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignTokens.compactSpacing) {
                            ForEach(entries) { entry in
                                CompletedTaskRow(entry: entry, sort: controller.sort) {
                                    withAnimation(
                                        .taskMotion(reduceMotion: reduceMotion, preferred: DesignTokens.completion)
                                    ) {
                                        model.setTaskCompletion(entry.task.id, completed: false)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                        .padding(DesignTokens.contentInset)
                    }
                    .scrollIndicators(.hidden)
                }

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: DesignTokens.metadataFontSize))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .padding(DesignTokens.contentInset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onExitCommand(perform: onClose)
        .onChange(of: model.database.projects.map(\.id)) { _, ids in
            if let selected = controller.projectID, !ids.contains(selected) {
                controller.projectID = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.itemSpacing) {
            HStack(spacing: DesignTokens.compactSpacing) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: DesignTokens.taskFontSize))
                Text("\(entries.count)")
                    .monospacedDigit()
            }
            .font(.system(size: DesignTokens.metadataFontSize))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entries.count) Completed Tasks")
            .help("\(entries.count) Completed Tasks")

            PanelChoiceMenu(
                choices: [PanelChoice<UUID?>(value: nil, title: "All projects")]
                    + model.database.projects.map {
                        PanelChoice(value: Optional($0.id), title: $0.title)
                    },
                selection: $controller.projectID,
                accessibilityLabel: "Filter Projects"
            ) {
                HStack(spacing: DesignTokens.compactSpacing) {
                    Text(selectedProjectTitle)
                        .font(.system(size: DesignTokens.metadataFontSize, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .padding(.horizontal, DesignTokens.compactSpacing)
                .frame(height: DesignTokens.controlSize)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PanelChoiceMenu(
                choices: CompletedTaskSort.allCases.map { PanelChoice(value: $0, title: $0.title) },
                selection: $controller.sort,
                accessibilityLabel: "Sort: \(controller.sort.title)"
            ) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: DesignTokens.compactIconSize, weight: .medium))
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SidePanelIconButtonStyle())
            .help("Close Completed Tasks")
            .accessibilityLabel("Close Completed Tasks")
        }
        .padding(.horizontal, DesignTokens.sidePanelHeaderInset)
        .frame(height: DesignTokens.sidePanelHeaderHeight)
    }

    private var selectedProjectTitle: String {
        model.database.projects.first { $0.id == controller.projectID }?.title ?? "All projects"
    }
}

private struct CompletedTaskRow: View {
    let entry: CompletedTaskEntry
    let sort: CompletedTaskSort
    let reopen: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.itemSpacing) {
            Button(action: reopen) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: DesignTokens.checkSize, height: DesignTokens.checkSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Reopen Task")
            .accessibilityLabel("Reopen \(entry.task.title)")

            VStack(alignment: .leading, spacing: DesignTokens.compactSpacing) {
                Text(entry.task.title)
                    .font(.system(size: DesignTokens.taskFontSize))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                HStack(spacing: DesignTokens.itemSpacing) {
                    Text(entry.projectTitle)
                        .lineLimit(1)
                        .help(entry.projectTitle)
                    Spacer(minLength: 0)
                    Text(compactDate)
                        .fixedSize()
                        .help(dateDescription)
                        .accessibilityLabel(dateDescription)
                }
                .font(.system(size: DesignTokens.metadataFontSize))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.compactSpacing)
        }
        .padding(DesignTokens.completedRowInset)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.completedRowRadius)
                .fill(hovering ? DesignTokens.hoverSurface : .clear)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var displayDate: Date? {
        sort == .added ? entry.task.createdAt : entry.task.completedAt
    }

    private var compactDate: String {
        guard let date = displayDate else { return "—" }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US"))
        let isCurrentYear = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        return date.formatted(isCurrentYear ? style : style.year())
    }

    private var dateDescription: String {
        guard let date = displayDate else { return "Completion date unavailable" }
        let prefix = sort == .added ? "Added" : "Completed"
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "en_US"))
        return "\(prefix) \(date.formatted(style))"
    }
}
