//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import SwiftUI
import XCTest

@MainActor
final class StreamingTrackTests: XCTestCase {
    func testIncomingMotionLeavesPlayedTrackAndPlayheadUntouched() {
        for phase in [0.0, 0.1, 0.4, 0.8] {
            let shape = StreamingTrackShape(phase: phase, direction: .towardStart, startProgress: 0.6)
            for x in stride(from: 2.0, through: 600, by: 2) {
                XCTAssertEqual(shape.radius(at: x, width: 1000), 2, accuracy: 0.00001)
            }
        }
        let animated = StreamingTrackShape(phase: 0, direction: .towardStart, startProgress: 0.6)
        XCTAssertGreaterThan(animated.radius(at: 682.4, width: 1000), 4)
        XCTAssertEqual(animated.radius(at: 1000, width: 1000), 0)
    }

    func testBulgesTravelInTheRequestedDirectionWithoutChangingTheBaseline() {
        let outgoing = StreamingTrackShape(phase: 0, direction: .towardEnd)
        let laterOutgoing = StreamingTrackShape(phase: 0.05, direction: .towardEnd)
        let center = 0.45 * (264 + 160) - 80
        XCTAssertGreaterThan(outgoing.radius(at: center, width: 264), 4)
        XCTAssertEqual(outgoing.radius(at: center, width: 264), laterOutgoing.radius(at: center + 21.2, width: 264), accuracy: 0.02)

        let incoming = StreamingTrackShape(phase: 0, direction: .towardStart, startProgress: 0.6)
        let laterIncoming = StreamingTrackShape(phase: 0.02, direction: .towardStart, startProgress: 0.6)
        let incomingCenter = 600 + 0.68 * 560 - 80
        XCTAssertEqual(
            incoming.radius(at: incomingCenter, width: 1000),
            laterIncoming.radius(at: incomingCenter - 11.2, width: 1000),
            accuracy: 0.02
        )
    }

    func testZeroRemainingTimeAndInvalidGeometryRemainSafe() {
        for progress in [1.0, .nan, .infinity] {
            let shape = StreamingTrackShape(phase: 0.1, direction: .towardStart, startProgress: progress)
            XCTAssertEqual(shape.radius(at: 500, width: 1000), 2)
            XCTAssertTrue(shape.path(in: CGRect(x: 0, y: 0, width: 1000, height: 28)).boundingRect.width.isFinite)
        }
        XCTAssertTrue(StreamingTrackShape(phase: 0, direction: .towardEnd).path(in: .zero).isEmpty)
    }
}
