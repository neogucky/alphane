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
final class OrderedOptionsTests: XCTestCase {
    func testReorderingWritesThroughAndHonorsExternalChanges() {
        var selection: [AudioCodec] = [.aac, .ac3, .flac]
        let view = TVOrderedOptions(
            title: "Audio",
            selection: Binding(get: { selection }, set: { selection = $0 }),
            sources: AudioCodec.allCases,
            removable: AudioCodec.allCases
        )
        view.move(.aac, by: 1)
        XCTAssertEqual(selection, [.ac3, .aac, .flac])
        view.move(.flac, by: -1)
        XCTAssertEqual(selection, [.ac3, .flac, .aac])
        view.move(.ac3, by: -1)
        view.move(.aac, by: 1)
        XCTAssertEqual(selection, [.ac3, .flac, .aac], "Moving beyond either edge must be ignored")
        selection = [.flac, .aac]
        view.move(.aac, by: -1)
        XCTAssertEqual(selection, [.aac, .flac], "Actions use the current binding, not a cached list")
    }

    func testRequiredPanelsCannotBeRemovedButCanBeReordered() {
        let required = VideoPlayerSupplement.supportedCases
        XCTAssertFalse(required.isEmpty)
        let optional = VideoPlayerSupplement.allCases.subtracting(required)
        var selection = required
        let view = TVOrderedOptions(
            title: "Panels",
            selection: Binding(get: { selection }, set: { selection = $0 }),
            sources: VideoPlayerSupplement.allCases,
            removable: optional
        )
        for panel in required {
            view.toggle(panel)
        }
        XCTAssertEqual(selection, required)
        if let panel = optional.first {
            view.toggle(panel)
            XCTAssertEqual(selection, required + [panel])
            view.move(panel, by: -1)
            XCTAssertEqual(Set(selection), Set(required + [panel]))
            view.toggle(panel)
            XCTAssertEqual(selection, required)
        }
    }

    func testAddingAndRemovingAnOptionPreservesTheOtherChoicesOrder() throws {
        var selection: [VideoCodec] = [.h264]
        let view = TVOrderedOptions(
            title: "Video",
            selection: Binding(get: { selection }, set: { selection = $0 }),
            sources: VideoCodec.allCases,
            removable: VideoCodec.allCases
        )
        let other = try XCTUnwrap(VideoCodec.allCases.first { $0 != .h264 })
        view.toggle(other)
        XCTAssertEqual(selection, [.h264, other])
        view.toggle(.h264)
        XCTAssertEqual(selection, [other])
        view.toggle(other)
        XCTAssertTrue(selection.isEmpty)
    }
}
