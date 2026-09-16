import AppKit
import XCTest
@testable import FloatTask

final class TaskTitleTextViewTests: XCTestCase {
    @MainActor
    func testExpandedTextAppearsBeforeTheWholeSecondLineFits() {
        let view = TaskTitleTextView()
        view.title = "터치할 때마다 좌측 슬라이드 리스트가 움직이는 현상"
        view.isExpanded = true
        let width: CGFloat = 232
        let collapsed = Int(view.fittingHeight(for: width, expanded: false))
        let expanded = Int(view.fittingHeight(for: width, expanded: true))
        XCTAssertGreaterThan(expanded, collapsed)

        let firstLine = ink(in: view, width: Int(width), height: collapsed)
        let partialLine = ink(in: view, width: Int(width), height: (collapsed + expanded) / 2)
        let fullText = ink(in: view, width: Int(width), height: expanded)
        XCTAssertGreaterThan(partialLine, firstLine, "The next line must reveal pixels before the row reaches its final height.")
        XCTAssertGreaterThanOrEqual(fullText, partialLine)
    }

    @MainActor
    func testShortTitleDoesNotNeedAnotherLine() {
        let view = TaskTitleTextView()
        view.title = "Write brief"
        XCTAssertLessThanOrEqual(view.fittingHeight(for: 232, expanded: true), view.fittingHeight(for: 232, expanded: false))
    }

    @MainActor
    private func ink(in view: TaskTitleTextView, width: Int, height: Int) -> Int {
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        context.cgContext.translateBy(x: 0, y: CGFloat(height))
        context.cgContext.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context.cgContext, flipped: true)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()

        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                if bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.1 { count += 1 }
            }
        }
        return count
    }
}
