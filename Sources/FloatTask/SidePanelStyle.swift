import AppKit
import SwiftUI

final class KeyableSidePanel: NSPanel {
    var onEscape: (() -> Void)?
    var isClosing = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if let onEscape {
            onEscape()
        } else {
            super.cancelOperation(sender)
        }
    }
}

enum SidePanelLayout {
    @MainActor
    static func repositionChildren(of parent: NSWindow) {
        let screen = parent.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? parent.frame
        // Keep the nearest panel first, preserving the existing order on each side.
        let children = (parent.childWindows ?? []).compactMap { $0 as? KeyableSidePanel }
            .filter(\.isVisible)
            .sorted { abs($0.frame.midX - parent.frame.midX) < abs($1.frame.midX - parent.frame.midX) }
        var occupied: [NSRect] = []
        for child in children {
            let target = frame(parent: parent.frame, screen: screen, occupied: occupied, size: child.frame.size)
            occupied.append(target)
            if child.frame.origin != target.origin { child.setFrameOrigin(target.origin) }
        }
    }

    @MainActor
    static func frame(relativeTo parent: NSWindow, size: NSSize? = nil) -> NSRect {
        let screen = parent.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? parent.frame
        let occupied = (parent.childWindows ?? []).filter(\.isVisible).map(\.frame)
        return frame(parent: parent.frame, screen: screen, occupied: occupied, size: size)
    }

    static func frame(parent: NSRect, screen: NSRect, occupied: [NSRect], size: NSSize? = nil) -> NSRect {
        let width = size?.width ?? DesignTokens.sidePanelWidth
        let gap = DesignTokens.panelGap
        let height = size?.height ?? DesignTokens.panelHeight
        let y = max(screen.minY, min(parent.maxY - height, screen.maxY - height))
        let obstacles = [parent] + occupied
        let leftEdges = [parent.minX] + occupied.map(\.minX).sorted(by: >)
        let rightEdges = [parent.maxX] + occupied.map(\.maxX).sorted()
        let candidates = leftEdges.map { NSRect(x: $0 - width - gap, y: y, width: width, height: height) }
            + rightEdges.map { NSRect(x: $0 + gap, y: y, width: width, height: height) }

        func fits(_ frame: NSRect) -> Bool {
            screen.contains(frame) && !obstacles.contains { $0.intersects(frame.insetBy(dx: -gap / 2, dy: 0)) }
        }
        if let frame = candidates.first(where: fits) { return frame }

        // Use vertical space when a narrow display cannot fit another horizontal panel.
        let x = max(screen.minX, min(parent.minX, screen.maxX - width))
        for edgeY in [parent.minY - height - gap, parent.maxY + gap] {
            let frame = NSRect(x: x, y: edgeY, width: width, height: height)
            if fits(frame) { return frame }
        }

        // When the display cannot contain all panels, keep every new panel on-screen
        // and minimize overlap rather than moving or closing an existing panel.
        let clamped = candidates.map {
            NSRect(x: max(screen.minX, min($0.minX, screen.maxX - width)), y: y, width: width, height: height)
        }
        func overlap(_ frame: NSRect) -> CGFloat {
            obstacles.reduce(0) { total, obstacle in
                let intersection = frame.intersection(obstacle)
                return total + (intersection.isNull ? 0 : intersection.width * intersection.height)
            }
        }
        return clamped.min { overlap($0) < overlap($1) } ?? NSRect(x: x, y: y, width: width, height: height)
    }
}

struct SidePanelSurface<Content: View>: View {
    var height: CGFloat = DesignTokens.panelHeight
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            SidePanelVisualEffectBackground().ignoresSafeArea()
            Color(nsColor: .windowBackgroundColor)
                .opacity(DesignTokens.sidePanelSurfaceOpacity)
                .ignoresSafeArea()
            content
        }
        .frame(width: DesignTokens.sidePanelWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.panelRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.panelRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }
}

struct SidePanelIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.completedRowRadius, style: .continuous)
                    .fill(Color(nsColor: .labelColor).opacity(configuration.isPressed ? 0.10 : 0))
            }
    }
}

private struct SidePanelVisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
