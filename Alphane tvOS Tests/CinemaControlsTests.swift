//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import JellyfinAPI
import SwiftUI
import XCTest

@MainActor
final class CinemaControlsTests: XCTestCase {

    func testClickpadSelectRestoresAllControlsWhenTogglingFromProgressOnly() async throws {
        let item = MediaPlayerItem(
            baseItem: BaseItemDto(id: UUID().uuidString, runTimeTicks: 1_200_000_000, type: .episode),
            mediaSource: .init(), playSessionID: "remote-test",
            url: URL(fileURLWithPath: "/remote-fixture.mp4"), deviceProfile: .init()
        )
        let manager = MediaPlayerManager(playbackItem: item)
        manager.videoFramePresented(for: item)
        let state = VideoPlayer.ViewState()
        state.connect(manager: manager)
        let controller = VideoPlayer.UIContainerViewController(
            viewState: state, manager: manager, videoSize: .init(initialValue: .zero),
            player: { _ in AnyView(Color.black) }, playbackControls: AnyView(EmptyView())
        )
        for status in [MediaPlayerManager.PlaybackRequestStatus.playing, .paused] {
            await manager.setPlaybackRequestStatus(status: status)
            state.hideControls()
            state.showProgress() // A clickpad touch precedes its Select release.
            XCTAssertTrue(controller.handlePlaybackSelection(isProgressFocused: true))
            try await Task.sleep(for: .milliseconds(60))
            XCTAssertEqual(manager.playbackRequestStatus, status == .playing ? .paused : .playing)
            XCTAssertEqual(state.presentation, .controls)
            XCTAssertTrue(state.visibleElements.contains(.playbackButtons))
            XCTAssertTrue(state.visibleElements.contains(.toolbar))

            state.hideControls()
            state.showProgress()
            controller.handlePlayPauseEnded()
            XCTAssertEqual(state.presentation, .controls, "The dedicated remote button must also upgrade progress-only UI")
            try await Task.sleep(for: .milliseconds(60))
        }
        state.hideControls()
        XCTAssertTrue(controller.handlePlaybackSelection(isProgressFocused: false))
        XCTAssertEqual(state.presentation, .controls)
        XCTAssertFalse(controller.handlePlaybackSelection(isProgressFocused: false), "Toolbar/menu buttons retain their own Select action")
        state.showProgress(keepingControls: false)
        state.isScrubbing = true
        XCTAssertTrue(controller.handlePlaybackSelection(isProgressFocused: true))
        XCTAssertFalse(state.isScrubbing)
        XCTAssertEqual(state.presentation, .progress, "Committing a seek keeps the lightweight presentation")
    }

    func testControlsShowActionsAndProgressWithoutTheOldSupplementTabRow() {
        let state = VideoPlayer.ViewState()
        state.presentGuestSupplement(TestSupplement())
        state.selectedSupplementID = nil
        state.showControls()

        XCTAssertEqual(state.presentation, .controls)
        XCTAssertTrue(state.visibleElements.contains(.toolbar))
        XCTAssertTrue(state.visibleElements.contains(.playbackButtons))
        XCTAssertTrue(state.visibleElements.contains(.progress))
        XCTAssertFalse(state.visibleElements.contains(.supplements))
    }

    func testOpeningEpisodesReplacesControlsAndBackRestoresThem() {
        let state = VideoPlayer.ViewState()
        state.showControls()
        state.presentGuestSupplement(TestSupplement())

        XCTAssertEqual(state.selectedSupplementID, "episodes")
        XCTAssertEqual(state.visibleElements, [.supplements, .dimming])

        state.selectedSupplementID = nil
        XCTAssertNil(state.selectedSupplementID)
        XCTAssertTrue(state.visibleElements.contains(.playbackButtons))
        XCTAssertFalse(state.visibleElements.contains(.supplements))
    }

    func testScrubbingShowsOnlyProgressAndRestoresTheActionsAfterward() {
        let state = VideoPlayer.ViewState()
        state.showControls()
        state.isScrubbing = true
        XCTAssertEqual(state.visibleElements, [.progress])

        state.cancelScrub()
        XCTAssertFalse(state.isScrubbing)
        XCTAssertTrue(state.visibleElements.contains(.playbackButtons))
    }

    func testProgressOnlySeekingDoesNotRevealTheCinemaButtonRow() {
        let state = VideoPlayer.ViewState()
        state.showProgress()
        XCTAssertEqual(state.presentation, .progress)
        XCTAssertEqual(state.visibleElements, [.progress])

        state.hideControls()
        XCTAssertTrue(state.visibleElements.isEmpty)
    }

    private struct TestSupplement: MediaPlayerSupplement {
        let id = "episodes"
        let displayTitle = "Episodes"
        var videoPlayerBody: some View {
            EmptyView()
        }
    }
}
