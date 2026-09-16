import AppKit
import FloatTaskCore
import XCTest
@testable import FloatTask

final class AppPreferencesTests: XCTestCase {
    @MainActor
    func testDefaultsAndPersistence() {
        let suite = "FloatTask.PreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.showInMenuBar)
        XCTAssertTrue(preferences.keepOnTop)
        XCTAssertEqual(preferences.replyLanguage, .korean)

        preferences.showInMenuBar = true
        preferences.keepOnTop = false
        preferences.replyLanguage = .english

        let restored = AppPreferences(defaults: defaults)
        XCTAssertTrue(restored.showInMenuBar)
        XCTAssertFalse(restored.keepOnTop)
        XCTAssertEqual(restored.replyLanguage, .english)
    }

    @MainActor
    func testExistingPreferenceKeysArePreserved() {
        let suite = "FloatTask.PreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "FloatTask.floats")
        defaults.set("en", forKey: "FloatTask.chatReplyLanguage")
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.keepOnTop)
        XCTAssertEqual(preferences.replyLanguage, .english)
        preferences.keepOnTop = true
        preferences.replyLanguage = .korean
        XCTAssertTrue(defaults.bool(forKey: "FloatTask.floats"))
        XCTAssertEqual(defaults.string(forKey: "FloatTask.chatReplyLanguage"), "ko")
    }

    @MainActor
    func testUnknownLanguageFallsBackToKorean() {
        let suite = "FloatTask.PreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unknown", forKey: "FloatTask.chatReplyLanguage")
        XCTAssertEqual(AppPreferences(defaults: defaults).replyLanguage, .korean)
    }

    @MainActor
    func testMenuBarItemLifecycleAndActions() {
        _ = NSApplication.shared
        var toggles = 0
        let controller = MenuBarController(toggleMain: { toggles += 1 })
        defer { controller.setVisible(false) }
        XCTAssertNil(controller.statusItem)
        controller.setVisible(true)
        let item = controller.statusItem
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.isVisible, true)
        XCTAssertEqual(item?.button?.image?.isTemplate, true)
        XCTAssertNil(item?.menu, "A menu bar click must not open a dropdown.")
        XCTAssertTrue(item?.button?.target === controller)
        XCTAssertNotNil(item?.button?.action)
        item?.button?.performClick(nil)
        item?.button?.performClick(nil)
        XCTAssertEqual(toggles, 2)
        controller.setVisible(true)
        XCTAssertTrue(controller.statusItem === item, "Repeated updates must not duplicate menu bar icons.")
        controller.setVisible(false)
        XCTAssertNil(controller.statusItem)
    }

    func testCompactSettingsAlignsWithTopAndAvoidsOpenPanels() {
        let screen = NSRect(x: 0, y: 0, width: 1800, height: 1100)
        let parent = NSRect(x: 1400, y: 500, width: 360, height: 500)
        let chat = NSRect(x: 1056, y: 500, width: 336, height: 500)
        let completed = NSRect(x: 712, y: 500, width: 336, height: 500)
        let size = NSSize(width: 336, height: 252)
        let settings = SidePanelLayout.frame(parent: parent, screen: screen, occupied: [chat, completed], size: size)
        XCTAssertEqual(settings.size, size)
        XCTAssertEqual(settings.maxY, parent.maxY)
        XCTAssertTrue(screen.contains(settings))
        XCTAssertFalse([parent, chat, completed].contains { $0.intersects(settings) })
    }

    func testExistingSidePanelSizeIsUnchanged() {
        let screen = NSRect(x: 0, y: 0, width: 1800, height: 1100)
        let parent = NSRect(x: 1400, y: 500, width: 360, height: 500)
        let frame = SidePanelLayout.frame(parent: parent, screen: screen, occupied: [])
        XCTAssertEqual(frame, NSRect(x: 1056, y: 500, width: 336, height: 500))
    }

    func testSidePanelDoesNotInheritResizedMainHeight() {
        let screen = NSRect(x: 0, y: 0, width: 2000, height: 1200)
        for height: CGFloat in [280, 700, 1000] {
            let parent = NSRect(x: 1200, y: 100, width: 640, height: height)
            let frame = SidePanelLayout.frame(parent: parent, screen: screen, occupied: [])
            XCTAssertEqual(frame.size, NSSize(width: 336, height: 500))
            XCTAssertTrue(screen.contains(frame))
            XCTAssertFalse(parent.intersects(frame))
        }
    }

    @MainActor
    func testNativeResizeCannotShrinkBelowMinimum() {
        XCTAssertEqual(FloatTaskWindow.constrainedSize(NSSize(width: 150, height: 140)), NSSize(width: 320, height: 280))
        XCTAssertEqual(FloatTaskWindow.constrainedSize(NSSize(width: 600, height: 620)), NSSize(width: 600, height: 620))
        let delegate = AppDelegate()
        let window = FloatTaskWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 500),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        XCTAssertEqual(delegate.windowWillResize(window, to: NSSize(width: 200, height: 200)), NSSize(width: 320, height: 280))
    }

    @MainActor
    func testMainResizeRepositionsChildrenWithoutChangingTheirSizes() {
        _ = NSApplication.shared
        let parent = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 560, height: 700),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        let child = KeyableSidePanel(
            contentRect: NSRect(x: 450, y: 200, width: 336, height: 500),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        parent.addChildWindow(child, ordered: .below)
        child.orderFront(nil)
        defer {
            parent.removeChildWindow(child)
            child.orderOut(nil)
            parent.orderOut(nil)
        }
        SidePanelLayout.repositionChildren(of: parent)
        XCTAssertEqual(child.frame.size, NSSize(width: 336, height: 500))
        if let screen = parent.screen?.visibleFrame, screen.width >= 904 {
            XCTAssertFalse(parent.frame.intersects(child.frame))
        }
    }
}
