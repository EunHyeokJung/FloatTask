import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let floatTaskAddTask = Notification.Name("FloatTask.AddTask")
    static let floatTaskAddProject = Notification.Name("FloatTask.AddProject")
    static let floatTaskShowCompleted = Notification.Name("FloatTask.ShowCompleted")
    static let floatTaskShowSettings = Notification.Name("FloatTask.ShowSettings")
}

@main
struct FloatTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .floatTaskShowSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Tasks") {
                Button("New Task") {
                    NotificationCenter.default.post(name: .floatTaskAddTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Project") {
                    NotificationCenter.default.post(name: .floatTaskAddProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()
                Button("Completed Tasks") {
                    NotificationCenter.default.post(name: .floatTaskShowCompleted, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindow: FloatTaskWindow?
    private var menuBar: MenuBarController?
    private var windowVisibility: MainWindowVisibilityController?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let floating = FloatTaskWindowMode.isFloating
        NSApp.setActivationPolicy(floating ? .accessory : .regular)

        let size = NSSize(width: DesignTokens.panelWidth, height: DesignTokens.panelHeight)
        let window = FloatTaskWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("FloatTask.MainWindow")
        window.title = "FloatTask"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        let hostingView = FloatTaskHostingView(rootView: OverlayView())
        // AppKit owns the user's window size; SwiftUI only lays out its contents.
        hostingView.sizingOptions = []
        window.contentView = hostingView
        // Hosting-view attachment can reset the native size constraints.
        window.minSize = FloatTaskWindow.minimumSize
        window.contentMinSize = FloatTaskWindow.minimumSize

        let autosaveName = "FloatTask.MainWindow"
        let restoredFrame = window.setFrameUsingName(autosaveName)
        window.setFrameAutosaveName(autosaveName)
        if !restoredFrame, let visibleFrame = NSScreen.main?.visibleFrame {
            window.setFrameOrigin(
                NSPoint(
                    x: visibleFrame.maxX - size.width - 20,
                    y: visibleFrame.maxY - size.height - 20
                )
            )
        }
        let restoredSize = FloatTaskWindow.constrainedSize(window.frame.size)
        if restoredSize != window.frame.size {
            window.setFrame(
                NSRect(x: window.frame.minX, y: window.frame.maxY - restoredSize.height,
                       width: restoredSize.width, height: restoredSize.height),
                display: false
            )
        }

        mainWindow = window
        windowVisibility = MainWindowVisibilityController(window: window)
        window.delegate = self
        FloatTaskWindowMode.apply(to: window, floating: floating)
        window.orderFrontRegardless()
        if !floating {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }

        menuBar = MenuBarController(
            toggleMain: { [weak self] in self?.windowVisibility?.toggle() }
        )
        AppPreferences.shared.$showInMenuBar
            .removeDuplicates()
            .sink { [weak self] visible in
                self?.menuBar?.setVisible(visible)
                if !visible, self?.mainWindow?.isVisible == false { self?.showMainWindow() }
            }
            .store(in: &subscriptions)
        AppPreferences.shared.$keepOnTop
            .removeDuplicates()
            .sink { [weak self] floating in
                guard let window = self?.mainWindow else { return }
                let wasActive = NSApp.isActive
                let keyWindow = NSApp.keyWindow
                FloatTaskWindowMode.apply(to: window, floating: floating)
                if wasActive {
                    NSApp.activate(ignoringOtherApps: true)
                    keyWindow?.makeKey()
                }
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .floatTaskShowSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.showSettings() }
            .store(in: &subscriptions)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // AppKit also checks this after orderOut hides the last visible window.
        // Stay alive for the menu bar; the main X and Quit still call terminate.
        false
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else { return }
        SidePanelLayout.repositionChildren(of: window)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        FloatTaskWindow.constrainedSize(frameSize)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        windowVisibility?.show()
    }

    private func showSettings() {
        guard let mainWindow else { return }
        if !mainWindow.isVisible { showMainWindow() }
        SettingsPanelController.shared.show(relativeTo: mainWindow)
    }
}

final class FloatTaskWindow: NSWindow {
    static var minimumSize: NSSize {
        NSSize(width: DesignTokens.panelMinWidth, height: DesignTokens.panelMinHeight)
    }

    static func constrainedSize(_ size: NSSize) -> NSSize {
        NSSize(width: max(size.width, minimumSize.width), height: max(size.height, minimumSize.height))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        resignActiveFieldEditor()
        super.resignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            if !isKeyWindow { makeKey() }
            resignFieldEditorWhenClickingOutside(event)
        }
        super.sendEvent(event)
    }

    private func resignFieldEditorWhenClickingOutside(_ event: NSEvent) {
        guard
            let fieldEditor = firstResponder as? NSTextView,
            fieldEditor.isFieldEditor,
            let editedField = fieldEditor.delegate as? NSView
        else { return }

        let pointInField = editedField.convert(event.locationInWindow, from: nil)
        if !editedField.bounds.contains(pointInField) {
            makeFirstResponder(nil)
        }
    }

    private func resignActiveFieldEditor() {
        guard
            let fieldEditor = firstResponder as? NSTextView,
            fieldEditor.isFieldEditor
        else { return }

        makeFirstResponder(nil)
    }
}

private final class FloatTaskHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
enum FloatTaskWindowMode {
    static var mainWindow: NSWindow? {
        NSApp.windows.first(where: { $0.identifier?.rawValue == "FloatTask.MainWindow" })
    }

    static var isFloating: Bool {
        AppPreferences.shared.keepOnTop
    }

    static func apply(to window: NSWindow, floating: Bool) {
        window.level = floating ? .floating : .normal
        window.hidesOnDeactivate = false

        if floating {
            NSApp.setActivationPolicy(.accessory)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        } else {
            NSApp.setActivationPolicy(.regular)
            window.collectionBehavior = [.managed, .participatesInCycle]
        }

        for childWindow in window.childWindows ?? [] {
            childWindow.level = window.level
            childWindow.collectionBehavior = window.collectionBehavior
            childWindow.hidesOnDeactivate = false
        }
    }
}

struct WindowDragSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
