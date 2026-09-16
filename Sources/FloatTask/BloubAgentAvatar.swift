import AppKit
import FloatTaskCore
import SwiftUI

struct BloubAgentAvatar: View {
    let activity: CodexTaskAgentActivity?
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            avatarLayer
                .id(activityID)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.86)),
                        removal: .opacity.combined(with: .scale(scale: 1.06))
                    )
                )
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: activity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var avatarLayer: some View {
        let mode = AvatarMode(activity: activity)
        if reduceMotion {
            BloubCanvas(mode: mode, time: 0.7)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                BloubCanvas(
                    mode: mode,
                    time: timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 120)
                )
            }
        }
    }

    private var activityID: String {
        switch activity {
        case nil: "idle"
        case .thinking: "thinking"
        case .working: "working"
        case .looking: "looking"
        }
    }

    private var accessibilityLabel: String {
        switch activity {
        case nil: "Luna idle"
        case .thinking: "Luna thinking"
        case .working: "Luna working"
        case .looking: "Luna looking up information"
        }
    }
}

private enum AvatarMode {
    case idle
    case thinking
    case comet
    case wideEyes

    init(activity: CodexTaskAgentActivity?) {
        switch activity {
        case nil: self = .idle
        case .thinking: self = .thinking
        case .working: self = .comet
        case .looking: self = .wideEyes
        }
    }
}

private struct BloubCanvas: View {
    let mode: AvatarMode
    let time: TimeInterval

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            switch mode {
            case .idle:
                drawIdle(in: &context, center: center, side: side)
            case .thinking:
                drawThinking(in: &context, center: center, side: side)
            case .comet:
                drawComet(in: &context, center: center, side: side)
            case .wideEyes:
                drawWideEyes(in: &context, center: center, side: side)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawIdle(in context: inout GraphicsContext, center: CGPoint, side: CGFloat) {
        let radius = side * 0.39
        fillCircle(in: &context, center: center, radius: radius, color: .primary)

        let blinkPhase = time.truncatingRemainder(dividingBy: 4.6)
        let blink = blinkPhase < 0.18 ? max(0.1, abs(blinkPhase - 0.09) / 0.09) : 1
        let gazeX = CGFloat(sin(time * 0.72)) * side * 0.025
        let gazeY = CGFloat(cos(time * 0.51)) * side * 0.018
        let eyeSize = CGSize(width: side * 0.10, height: side * 0.22 * blink)
        let eyeColor = Color(nsColor: .windowBackgroundColor)
        fillCapsule(
            in: &context,
            center: CGPoint(x: center.x - side * 0.13 + gazeX, y: center.y + gazeY),
            size: eyeSize,
            color: eyeColor
        )
        fillCapsule(
            in: &context,
            center: CGPoint(x: center.x + side * 0.13 + gazeX, y: center.y + gazeY),
            size: eyeSize,
            color: eyeColor
        )
    }

    private func drawThinking(in context: inout GraphicsContext, center: CGPoint, side: CGFloat) {
        let positions: [CGFloat] = [-0.27, 0, 0.27]
        for (index, position) in positions.enumerated() {
            let wave = sin(time * .pi * 2 / 1.5 - Double(index) * 0.85)
            let pulse = 1 + CGFloat(pow(max(0, wave), 3)) * 0.25
            fillCircle(
                in: &context,
                center: CGPoint(x: center.x + position * side, y: center.y),
                radius: side * 0.082 * pulse,
                color: .primary
            )
        }
    }

    private func drawComet(in context: inout GraphicsContext, center: CGPoint, side: CGFloat) {
        let colors: [Color] = [
            Color(red: 0.98, green: 0.36, blue: 0.48),
            Color(red: 1.00, green: 0.70, blue: 0.22),
            Color(red: 0.24, green: 0.76, blue: 0.68),
            Color(red: 0.34, green: 0.55, blue: 0.98)
        ]
        let ellipseAngle = 34.0 * Double.pi / 180
        let head = time * 210.0 * Double.pi / 180
        let sweep = Double.pi * 0.68

        for ribbon in 0..<4 {
            let ribbonHead = head - Double(ribbon) * 0.1
            for segment in 0..<14 {
                let startFraction = Double(segment) / 14
                let endFraction = Double(segment + 1) / 14
                let start = cometPoint(
                    angle: ribbonHead - sweep + sweep * startFraction,
                    center: center,
                    side: side,
                    ellipseAngle: ellipseAngle,
                    phase: Double(ribbon) * 0.08
                )
                let end = cometPoint(
                    angle: ribbonHead - sweep + sweep * endFraction,
                    center: center,
                    side: side,
                    ellipseAngle: ellipseAngle,
                    phase: Double(ribbon) * 0.08
                )
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .color(colors[ribbon].opacity(0.12 + 0.76 * endFraction)),
                    lineWidth: side * 0.052
                )
            }
        }

        fillCircle(in: &context, center: center, radius: side * 0.065, color: .primary)
    }

    private func cometPoint(
        angle: Double,
        center: CGPoint,
        side: CGFloat,
        ellipseAngle: Double,
        phase: Double
    ) -> CGPoint {
        let localX = cos(angle + phase) * Double(side * 0.41)
        let localY = sin(angle + phase) * Double(side * 0.075)
        let rotatedX = localX * cos(ellipseAngle) - localY * sin(ellipseAngle)
        let rotatedY = localX * sin(ellipseAngle) + localY * cos(ellipseAngle)
        return CGPoint(x: center.x + CGFloat(rotatedX), y: center.y + CGFloat(rotatedY))
    }

    private func drawWideEyes(in context: inout GraphicsContext, center: CGPoint, side: CGFloat) {
        let radius = side * 0.42
        fillCircle(in: &context, center: center, radius: radius, color: .primary)

        let gazeX = CGFloat(sin(time * 1.75)) * side * 0.045
        let gazeY = CGFloat(sin(time * 1.07 + 1.2)) * side * 0.035
        let eyeSize = CGSize(width: side * 0.15, height: side * 0.37)
        let eyeColor = Color(nsColor: .windowBackgroundColor)
        fillCapsule(
            in: &context,
            center: CGPoint(x: center.x - side * 0.15 + gazeX, y: center.y + gazeY),
            size: eyeSize,
            color: eyeColor
        )
        fillCapsule(
            in: &context,
            center: CGPoint(x: center.x + side * 0.15 + gazeX, y: center.y + gazeY),
            size: eyeSize,
            color: eyeColor
        )
    }

    private func fillCircle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func fillCapsule(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        context.fill(
            Path(roundedRect: rect, cornerRadius: min(size.width, size.height) / 2),
            with: .color(color)
        )
    }
}
