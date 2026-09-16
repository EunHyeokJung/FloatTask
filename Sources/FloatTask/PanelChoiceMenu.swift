import AppKit
import SwiftUI

struct PanelChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct PanelChoiceMenu<Value: Hashable, Label: View>: View {
    let choices: [PanelChoice<Value>]
    @Binding var selection: Value
    let accessibilityLabel: String
    var menuTitle: String? = nil
    @ViewBuilder let label: Label
    @State private var isPresented = false
    @State private var restoreTriggerFocus = false
    @State private var anchor = PanelMenuWindowAnchor()

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            label.contentShape(Rectangle())
        }
        .buttonStyle(SidePanelIconButtonStyle())
        .background(PanelMenuAnchorReader(anchor: anchor).allowsHitTesting(false))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(choices.first { $0.value == selection }?.title ?? "")
        .help(accessibilityLabel)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            PanelChoiceList(choices: choices, selection: selection, title: menuTitle) { value in
                selection = value
                restoreTriggerFocus = true
                isPresented = false
            } onDismiss: {
                restoreTriggerFocus = true
                isPresented = false
            }
            .onDisappear {
                // Restore keyboard access after choosing or cancelling, but not after clicking another window.
                guard restoreTriggerFocus else { return }
                restoreTriggerFocus = false
                guard NSApp.isActive, let window = anchor.window, window.isVisible else { return }
                window.makeKey()
                window.makeFirstResponder(nil)
            }
        }
    }
}

private final class PanelMenuWindowAnchor {
    weak var window: NSWindow?
}

private struct PanelMenuAnchorReader: NSViewRepresentable {
    let anchor: PanelMenuWindowAnchor

    func makeNSView(context: Context) -> AnchorView { AnchorView(anchor: anchor) }
    func updateNSView(_ nsView: AnchorView, context: Context) {}

    final class AnchorView: NSView {
        let anchor: PanelMenuWindowAnchor

        init(anchor: PanelMenuWindowAnchor) {
            self.anchor = anchor
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            anchor.window = window
        }
    }
}

private struct PanelChoiceList<Value: Hashable>: View {
    let choices: [PanelChoice<Value>]
    let selection: Value
    let title: String?
    let onSelect: (Value) -> Void
    let onDismiss: () -> Void
    @State private var highlightedIndex = 0
    @State private var hoveredIndex: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let title {
                        Text(title)
                            .font(.system(size: DesignTokens.taskFontSize, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignTokens.itemSpacing)
                            .frame(height: DesignTokens.selectionMenuRowHeight)
                    }
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        Button {
                            onSelect(choice.value)
                        } label: {
                            HStack(spacing: DesignTokens.itemSpacing) {
                                Text(choice.title)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .opacity(choice.value == selection ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .font(.system(size: DesignTokens.metadataFontSize))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, DesignTokens.itemSpacing)
                            .frame(height: DesignTokens.selectionMenuRowHeight)
                            .background {
                                RoundedRectangle(cornerRadius: DesignTokens.selectionMenuRadius)
                                    .fill(index == (hoveredIndex ?? highlightedIndex) ? DesignTokens.hoverSurface : .clear)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityAddTraits(choice.value == selection ? .isSelected : [])
                        .help(choice.title)
                        .onHover { hovering in
                            if hovering { hoveredIndex = index }
                            else if hoveredIndex == index { hoveredIndex = nil }
                        }
                        .id(index)
                    }
                }
                .padding(DesignTokens.selectionMenuInset)
            }
            .scrollIndicators(.hidden)
            .frame(
                width: DesignTokens.selectionMenuWidth,
                height: min(
                    CGFloat(choices.count + (title == nil ? 0 : 1)) * DesignTokens.selectionMenuRowHeight + DesignTokens.selectionMenuInset * 2,
                    DesignTokens.selectionMenuMaxHeight
                )
            )
            .background {
                PanelMenuKeyboardCapture { keyCode in
                    hoveredIndex = nil
                    switch keyCode {
                    case 125:
                        highlightedIndex = min(highlightedIndex + 1, max(choices.count - 1, 0))
                    case 126:
                        highlightedIndex = max(highlightedIndex - 1, 0)
                    case 36, 76:
                        if choices.indices.contains(highlightedIndex) { onSelect(choices[highlightedIndex].value) }
                    case 53:
                        onDismiss()
                    default:
                        return false
                    }
                    return true
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                highlightedIndex = choices.firstIndex { $0.value == selection } ?? 0
                proxy.scrollTo(highlightedIndex)
            }
            .onChange(of: highlightedIndex) { _, index in proxy.scrollTo(index) }
            .onExitCommand(perform: onDismiss)
        }
    }
}

private struct PanelMenuKeyboardCapture: NSViewRepresentable {
    let onKey: (UInt16) -> Bool

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) { nsView.onKey = onKey }

    final class KeyView: NSView {
        var onKey: ((UInt16) -> Bool)?
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The popover attaches its window after SwiftUI's onAppear callback.
            DispatchQueue.main.async { [weak self] in
                guard let self, let window, NSApp.isActive else { return }
                window.makeKey()
                window.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            if onKey?(event.keyCode) != true { super.keyDown(with: event) }
        }
    }
}
