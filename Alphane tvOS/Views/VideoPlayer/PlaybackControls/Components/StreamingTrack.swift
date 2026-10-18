//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

enum CinemaTrackAppearance {
    static let height: CGFloat = 4
    static let playheadSize: CGFloat = 16
    static let animationHeight: CGFloat = 28

    static func unplayedOpacity(isFocused: Bool) -> Double {
        isFocused ? 0.4 : 0.16
    }
}

/// Only this small drawing ticks; the artwork, controls and focus geometry stay still.
struct StreamingTrack: View {
    enum Direction {
        case towardStart
        case towardEnd
    }

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.scenePhase)
    private var scenePhase

    let color: Color
    var isActive = true
    var direction: Direction = .towardEnd
    var startProgress: Double = 0

    var body: some View {
        Group {
            if isActive, !reduceMotion, scenePhase == .active {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                    Canvas { context, size in
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8
                        let shape = StreamingTrackShape(phase: phase, direction: direction, startProgress: startProgress)
                        context.fill(shape.path(in: CGRect(origin: .zero, size: size)), with: .color(color))
                    }
                }
            } else {
                Capsule()
                    .fill(color)
                    .frame(height: CinemaTrackAppearance.height)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(height: CinemaTrackAppearance.animationHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct StreamingTrackShape: Shape {
    let phase: Double
    let direction: StreamingTrack.Direction
    var startProgress: Double = 0

    private struct Pulse {
        let offset: Double
        let height: Double
        let width: Double
    }

    // Irregular spacing is fixed throughout a wait: no random jumps between frames.
    private static let outgoing: [Pulse] = [
        .init(offset: 0.12, height: 3.7, width: 15),
        .init(offset: 0.45, height: 2.6, width: 19),
        .init(offset: 0.85, height: 3.3, width: 12),
    ]
    private static let incoming: [Pulse] = [
        .init(offset: 0.08, height: 2.6, width: 13),
        .init(offset: 0.29, height: 3.8, width: 18),
        .init(offset: 0.46, height: 3.1, width: 12),
        .init(offset: 0.68, height: 2.7, width: 16),
        .init(offset: 0.93, height: 3.9, width: 14),
    ]

    func radius(at x: Double, width: Double) -> Double {
        guard width.isFinite, width > 0, x.isFinite, phase.isFinite else { return 0 }

        let baseRadius = Double(CinemaTrackAppearance.height / 2)
        let clampedX = min(width, max(0, x))
        let distanceToEdge = min(clampedX, width - clampedX)
        let cap = distanceToEdge < baseRadius
            ? sqrt(max(0, baseRadius * baseRadius - pow(baseRadius - distanceToEdge, 2)))
            : baseRadius
        let start = width * (startProgress.isFinite ? min(1, max(0, startProgress)) : 1)
        let streamWidth = width - start
        guard clampedX >= start, streamWidth > 24 else { return cap }

        let localX = clampedX - start
        let span = streamWidth + 160
        let sign: Double = direction == .towardEnd ? 1 : -1
        let pulses = direction == .towardEnd ? Self.outgoing : Self.incoming
        var swell = 0.0
        for pulse in pulses {
            let position = pulse.offset + sign * phase
            let center = (position - floor(position)) * span - 80
            swell += pulse.height * exp(-0.5 * pow((localX - center) / pulse.width, 2))
        }
        let edge = min(1, localX / 16) * min(1, (streamWidth - localX) / 16)
        let gate = edge * edge * (3 - 2 * edge)
        return cap + min(swell, 5) * gate
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, rect.height > 0 else { return Path() }

        let steps = max(1, Int(ceil(rect.width / 2)))
        var path = Path()
        for index in 0 ... steps {
            let x = rect.width * Double(index) / Double(steps)
            let y = rect.midY - radius(at: x, width: rect.width)
            let point = CGPoint(x: rect.minX + x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        for index in (0 ... steps).reversed() {
            let x = rect.width * Double(index) / Double(steps)
            path.addLine(to: CGPoint(x: rect.minX + x, y: rect.midY + radius(at: x, width: rect.width)))
        }
        path.closeSubpath()
        return path
    }
}
