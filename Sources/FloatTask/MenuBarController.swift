import AppKit

@MainActor
final class MenuBarController: NSObject {
    private(set) var statusItem: NSStatusItem?
    private let toggleMain: () -> Void

    init(toggleMain: @escaping () -> Void) {
        self.toggleMain = toggleMain
    }

    func setVisible(_ visible: Bool) {
        guard visible else {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "FloatTask")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Show or hide FloatTask"
        item.button?.setAccessibilityLabel("Show or hide FloatTask")
        item.button?.target = self
        item.button?.action = #selector(toggleWindow)
        item.button?.sendAction(on: .leftMouseUp)
        statusItem = item
    }

    @objc private func toggleWindow() { toggleMain() }
}
