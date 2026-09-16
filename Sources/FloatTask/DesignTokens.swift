import SwiftUI

enum DesignTokens {
    static let panelWidth: CGFloat = 360
    static let panelHeight: CGFloat = 500
    static let panelMinWidth: CGFloat = 320
    static let panelMinHeight: CGFloat = 280
    static let sidePanelWidth: CGFloat = 336
    static let sidePanelHeaderHeight: CGFloat = 48
    static let sidePanelHeaderInset: CGFloat = 12
    static let sidePanelSurfaceOpacity = 0.84
    static let sidePanelScreenInset: CGFloat = 8
    static let sidePanelOpenOffset: CGFloat = 24
    static let sidePanelCloseOffset: CGFloat = 18
    static let panelGap: CGFloat = 8
    static let panelRadius: CGFloat = 18
    static let contentInset: CGFloat = 16
    static let rowHeight: CGFloat = 40
    static let controlSize: CGFloat = 32
    static let checkSize: CGFloat = 36
    static let projectSpacing: CGFloat = 20
    static let metadataFontSize: CGFloat = 12
    static let taskFontSize: CGFloat = 14
    static let compactSpacing: CGFloat = 4
    static let itemSpacing: CGFloat = 8
    static let completedRowInset: CGFloat = 8
    static let completedRowRadius: CGFloat = 8
    static let selectionMenuWidth: CGFloat = 224
    static let selectionMenuMaxHeight: CGFloat = 288
    static let selectionMenuRowHeight: CGFloat = 36
    static let selectionMenuInset: CGFloat = 6
    static let selectionMenuRadius: CGFloat = 7
    static let compactIconSize: CGFloat = 13
    static let settingsPanelHeight: CGFloat = 252
    static let settingsRowHeight: CGFloat = 56
    static let settingsIconWidth: CGFloat = 20
    static let hoverSurface = Color(nsColor: .labelColor).opacity(0.055)

    static let insertion = Animation.spring(response: 0.26, dampingFraction: 0.84)
    static let completion = Animation.spring(response: 0.24, dampingFraction: 0.80)
    static let hover = Animation.easeOut(duration: 0.14)
    static let taskExpansion = Animation.spring(response: 0.16, dampingFraction: 0.92)
    static let removal = Animation.easeIn(duration: 0.16)
    static let sidePanelOpenDuration: TimeInterval = 0.28
    static let sidePanelCloseDuration: TimeInterval = 0.17
}

extension Animation {
    static func taskMotion(reduceMotion: Bool, preferred: Animation) -> Animation {
        reduceMotion ? .linear(duration: 0.01) : preferred
    }
}
