//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import JellyfinAPI
import XCTest

final class PlayButtonLabelTests: XCTestCase {
    func testWatchedEpisodesAndMoviesUseTheExistingSharedLabelHelper() {
        for type in [BaseItemKind.episode, .movie] {
            var item = BaseItemDto(
                runTimeTicks: 1_200_000_000,
                type: type,
                userData: .init(isPlayed: false, key: "item", playbackPositionTicks: 0)
            )
            XCTAssertEqual(item.playButtonLabel, L10n.play)
            item.userData?.isPlayed = true
            XCTAssertEqual(item.playButtonLabel, L10n.playAgain)
        }
    }

    func testAnUnfinishedRewatchKeepsResumePriority() {
        let item = BaseItemDto(
            runTimeTicks: 1_200_000_000, type: .episode,
            userData: .init(isPlayed: true, key: "item", playbackPositionTicks: 380_000_000)
        )
        XCTAssertNotNil(item.progressLabel)
        XCTAssertEqual(item.playButtonLabel, item.progressLabel)
        XCTAssertNotEqual(item.playButtonLabel, L10n.playAgain)
    }

    func testLiveChannelsDoNotOfferReplayForWatchedUserData() {
        let channel = BaseItemDto(
            channelType: .tv,
            type: .tvChannel,
            userData: .init(isPlayed: true, key: "item", playbackPositionTicks: 0)
        )
        XCTAssertEqual(channel.playButtonLabel, L10n.play)
    }
}
