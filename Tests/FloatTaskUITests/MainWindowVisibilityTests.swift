import AppKit
import XCTest
@testable import FloatTask

final class MainWindowVisibilityTests: XCTestCase {
    @MainActor
    func testMenuBarHideDoesNotRequestTerminationInApplicationEventLoop() {
        let app = NSApplication.shared
        let previousDelegate = app.delegate
        let previousPolicy = app.activationPolicy()
        let probe = TerminationProbe()
        app.delegate = probe
        app.setActivationPolicy(.regular)
        let main = makeMainWindow()
        let visibility = MainWindowVisibilityController(window: main)
        let menuBar = MenuBarController(toggleMain: { visibility.toggle() })
        menuBar.setVisible(true)
        main.makeKeyAndOrderFront(nil)
        defer {
            menuBar.setVisible(false)
            main.orderOut(nil)
            app.delegate = previousDelegate
            app.setActivationPolicy(previousPolicy)
        }

        // A synchronous isVisible assertion misses AppKit's deferred termination
        // check. Run the real application event loop between status-item actions.
        var step = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            MainActor.assumeIsolated {
                if step == 4 {
                    FloatTaskWindowMode.apply(to: main, floating: true)
                }
                if step < 8 {
                    menuBar.statusItem?.button?.performClick(nil)
                    XCTAssertEqual(main.isVisible, step % 2 == 1)
                    XCTAssertNotNil(menuBar.statusItem)
                    step += 1
                } else {
                    app.stop(nil)
                    // Wake nextEvent so run() can observe stop immediately.
                    let event = NSEvent.otherEvent(
                        with: .applicationDefined, location: .zero, modifierFlags: [],
                        timestamp: 0, windowNumber: 0, context: nil,
                        subtype: 0, data1: 0, data2: 0
                    )!
                    app.postEvent(event, atStart: true)
                }
            }
        }
        app.run()
        timer.invalidate()

        XCTAssertEqual(step, 8)
        XCTAssertGreaterThan(probe.lastWindowChecks, 0, "Exercise AppKit's automatic termination policy.")
        XCTAssertEqual(probe.terminationRequests, 0, "Hiding the last visible window must not quit the app.")
        XCTAssertTrue(main.isVisible)
    }

    @MainActor
    func testStatusButtonHidesAndRestoresWindowAndOpenPanel() {
        _ = NSApplication.shared
        for level: NSWindow.Level in [.normal, .floating] {
            let main = makeMainWindow()
            main.level = level
            let panel = KeyableSidePanel(
                contentRect: NSRect(x: 700, y: 100, width: 336, height: 500),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            let draft = NSTextField(string: "Unsent chat draft")
            panel.contentView = draft
            panel.level = level
            main.addChildWindow(panel, ordered: .below)
            main.orderFront(nil)
            panel.orderFront(nil)
            let mainContent = main.contentView
            let mainFrame = main.frame
            let panelFrame = panel.frame
            let visibility = MainWindowVisibilityController(window: main)
            let menuBar = MenuBarController(toggleMain: { visibility.toggle() })
            menuBar.setVisible(true)
            defer {
                menuBar.setVisible(false)
                main.removeChildWindow(panel)
                panel.orderOut(nil)
                main.orderOut(nil)
            }

            XCTAssertNil(menuBar.statusItem?.menu)
            for _ in 0..<2 {
                menuBar.statusItem?.button?.performClick(nil)
                XCTAssertFalse(main.isVisible)
                XCTAssertFalse(panel.isVisible)
                XCTAssertNil(panel.parent, "AppKit detaches child windows when they are ordered out.")
                XCTAssertTrue(main.contentView === mainContent)
                XCTAssertTrue(panel.contentView === draft)
                XCTAssertEqual(draft.stringValue, "Unsent chat draft")

                menuBar.statusItem?.button?.performClick(nil)
                XCTAssertTrue(main.isVisible)
                XCTAssertTrue(panel.isVisible)
                XCTAssertTrue(panel.parent === main)
                XCTAssertEqual(main.frame, mainFrame)
                XCTAssertEqual(panel.frame, panelFrame)
                XCTAssertEqual(main.level, level)
                XCTAssertEqual(panel.level, level)
                XCTAssertTrue(panel.contentView === draft)
                XCTAssertEqual(draft.stringValue, "Unsent chat draft")
            }
        }
    }

    @MainActor
    func testRepeatedHideKeepsOpenPanelSnapshotAndDoesNotReopenRemovedPanel() {
        _ = NSApplication.shared
        let main = makeMainWindow()
        let panel = KeyableSidePanel(
            contentRect: NSRect(x: 700, y: 100, width: 336, height: 500),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        main.addChildWindow(panel, ordered: .below)
        main.orderFront(nil)
        panel.orderFront(nil)
        let visibility = MainWindowVisibilityController(window: main)
        defer {
            main.removeChildWindow(panel)
            panel.orderOut(nil)
            main.orderOut(nil)
        }

        visibility.hide()
        visibility.hide()
        visibility.show()
        XCTAssertTrue(panel.isVisible)

        visibility.hide()
        panel.isClosing = true
        visibility.show()
        XCTAssertTrue(main.isVisible)
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor
    private func makeMainWindow() -> FloatTaskWindow {
        let window = FloatTaskWindow(
            contentRect: NSRect(x: 100, y: 100, width: 520, height: 560),
            styleMask: [.borderless, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
        return window
    }
}

@MainActor
private final class TerminationProbe: NSObject, NSApplicationDelegate {
    private let delegate = AppDelegate()
    private(set) var lastWindowChecks = 0
    private(set) var terminationRequests = 0

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        lastWindowChecks += 1
        return delegate.applicationShouldTerminateAfterLastWindowClosed(sender)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationRequests += 1
        // Capture a regression without allowing it to kill the XCTest process.
        return .terminateCancel
    }
}
