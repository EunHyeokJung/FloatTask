import AppKit
import FloatTaskCore
import SwiftUI

private struct SettingsPanelView: View {
    @ObservedObject var preferences: AppPreferences
    let onClose: () -> Void

    var body: some View {
        SidePanelSurface(height: DesignTokens.settingsPanelHeight) {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.system(size: DesignTokens.taskFontSize, weight: .semibold))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: DesignTokens.controlSize, height: DesignTokens.controlSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SidePanelIconButtonStyle())
                    .help("Close Settings")
                    .accessibilityLabel("Close Settings")
                }
                .padding(.leading, DesignTokens.contentInset)
                .padding(.trailing, DesignTokens.sidePanelHeaderInset)
                .frame(height: DesignTokens.sidePanelHeaderHeight)
                .background(WindowDragSurface())

                Divider().opacity(0.55)

                VStack(spacing: 0) {
                    settingRow("Show in menu bar", symbol: "menubar.rectangle") {
                        Toggle("Show in menu bar", isOn: $preferences.showInMenuBar)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .accessibilityLabel("Show in menu bar")
                    }
                    rowDivider
                    settingRow("Keep on top", symbol: "pin") {
                        Toggle("Keep on top", isOn: $preferences.keepOnTop)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .accessibilityLabel("Keep on top")
                    }
                    rowDivider
                    settingRow("Reply language", symbol: "bubble.left") {
                        PanelChoiceMenu(
                            choices: ChatReplyLanguage.allCases.map { PanelChoice(value: $0, title: $0.title) },
                            selection: $preferences.replyLanguage,
                            accessibilityLabel: "Reply language"
                        ) {
                            HStack(spacing: DesignTokens.compactSpacing) {
                                Text(preferences.replyLanguage.title)
                                Image(systemName: "chevron.down")
                                    .imageScale(.small)
                                    .accessibilityHidden(true)
                            }
                            .font(.system(size: DesignTokens.metadataFontSize))
                            .padding(.horizontal, DesignTokens.compactSpacing)
                            .frame(minHeight: DesignTokens.controlSize)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.contentInset)
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .opacity(0.4)
            .padding(.leading, DesignTokens.settingsIconWidth + DesignTokens.sidePanelHeaderInset)
    }

    private func settingRow<Control: View>(
        _ title: String, symbol: String, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: DesignTokens.sidePanelHeaderInset) {
            Image(systemName: symbol)
                .font(.system(size: DesignTokens.compactIconSize))
                .foregroundStyle(.secondary)
                .frame(width: DesignTokens.settingsIconWidth)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: DesignTokens.taskFontSize))
                .fixedSize()
            Spacer(minLength: DesignTokens.compactSpacing)
            control()
        }
        .frame(height: DesignTokens.settingsRowHeight)
    }
}

@MainActor
final class SettingsPanelController {
    static let shared = SettingsPanelController()

    private var panel: KeyableSidePanel?
    private weak var parentWindow: NSWindow?

    func show(relativeTo parent: NSWindow) {
        if let panel, panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let size = NSSize(width: DesignTokens.sidePanelWidth, height: DesignTokens.settingsPanelHeight)
        let panel = KeyableSidePanel(
            contentRect: SidePanelLayout.frame(relativeTo: parent, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("FloatTask.Settings")
        panel.title = "Settings"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.level = parent.level
        panel.collectionBehavior = parent.collectionBehavior
        panel.onEscape = { [weak self] in self?.close() }
        panel.contentViewController = NSHostingController(
            rootView: SettingsPanelView(preferences: .shared) { [weak self] in self?.close() }
        )
        self.panel = panel
        parentWindow = parent
        parent.addChildWindow(panel, ordered: .above)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard let panel else { return }
        panel.isClosing = true
        let restoreFocus = panel.isKeyWindow
        parentWindow?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.contentViewController = nil
        if restoreFocus {
            parentWindow?.makeKey()
            parentWindow?.makeFirstResponder(nil)
        }
        self.panel = nil
        parentWindow = nil
    }
}
