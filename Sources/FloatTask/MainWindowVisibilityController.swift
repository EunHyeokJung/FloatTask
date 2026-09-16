import AppKit

@MainActor
final class MainWindowVisibilityController {
    private struct HiddenPanel {
        let window: KeyableSidePanel
        let order: NSWindow.OrderingMode
    }

    private weak var window: NSWindow?
    private var hiddenPanels: [HiddenPanel] = []
    private weak var previouslyKeyWindow: NSWindow?

    init(window: NSWindow) {
        self.window = window
    }

    func toggle() {
        guard let window else { return }
        if window.isVisible && !window.isMiniaturized && !NSApp.isHidden {
            hide()
        } else {
            show()
        }
    }

    func hide() {
        guard let window, window.isVisible else { return }
        previouslyKeyWindow = NSApp.keyWindow
        hiddenPanels = (window.childWindows ?? []).compactMap { $0 as? KeyableSidePanel }
            .filter(\.isVisible)
            .map { HiddenPanel(window: $0, order: $0.orderedIndex < window.orderedIndex ? .above : .below) }
        // Keep controllers and hosting views alive: orderOut is not a panel close.
        // AppKit detaches child windows during orderOut, so retain their attachment order too.
        for panel in hiddenPanels { panel.window.orderOut(nil) }
        window.orderOut(nil)
    }

    func show() {
        guard let window else { return }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        for snapshot in hiddenPanels {
            let panel = snapshot.window
            guard !panel.isClosing, panel.parent == nil || panel.parent === window else { continue }
            window.addChildWindow(panel, ordered: snapshot.order)
            panel.orderFront(nil)
        }
        if let previouslyKeyWindow, previouslyKeyWindow.isVisible,
           previouslyKeyWindow === window || previouslyKeyWindow.parent === window {
            previouslyKeyWindow.makeKey()
        } else {
            window.makeFirstResponder(nil)
        }
        hiddenPanels.removeAll()
        previouslyKeyWindow = nil
    }
}
