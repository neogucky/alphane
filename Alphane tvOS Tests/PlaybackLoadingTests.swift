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
final class PlaybackLoadingTests: XCTestCase {
    func testPreparationAndAResumePositionStillWaitForAnActualFrame() {
        let item = item()
        let manager = MediaPlayerManager(playbackItem: item)
        manager.seconds = .seconds(25 * 60)
        XCTAssertEqual(manager.loadingPresentation, .startup)
        manager.videoFramePresented(for: item)
        XCTAssertEqual(manager.loadingPresentation, .none)

        XCTAssertEqual(PlaybackLoadingPresentation(
            state: .loadingItem, hasPresentedVideoFrame: true, isBuffering: false, playbackRequestStatus: .playing
        ), .startup)
        XCTAssertEqual(PlaybackLoadingPresentation(
            state: .initial, hasPresentedVideoFrame: false, isBuffering: false, playbackRequestStatus: .playing
        ), .startup)
    }

    func testPauseAndResumeBufferingNeverRestoreTheArtworkScreen() async {
        let item = item()
        let manager = MediaPlayerManager(playbackItem: item)
        let proxy = TestProxy()
        manager.proxy = proxy
        manager.videoFramePresented(for: item)

        await manager.setPlaybackRequestStatus(status: .paused)
        proxy.isBuffering.value = true
        XCTAssertEqual(manager.loadingPresentation, .none, "Intentional pause must not look like buffering")
        await manager.setPlaybackRequestStatus(status: .playing)
        XCTAssertEqual(manager.loadingPresentation, .buffering)
        proxy.isBuffering.value = false
        XCTAssertEqual(manager.loadingPresentation, .none)
        XCTAssertTrue(manager.hasPresentedVideoFrame)
    }

    func testAReplacementStreamWaitsForItsOwnFrameAndIgnoresLateCallbacks() throws {
        let first = item()
        let manager = MediaPlayerManager(playbackItem: first)
        manager.videoFramePresented(for: first)
        let replacement = try item(id: XCTUnwrap(first.baseItem.id))
        manager.playbackItem = replacement
        XCTAssertEqual(manager.loadingPresentation, .startup)
        manager.videoFramePresented(for: first)
        XCTAssertFalse(manager.hasPresentedVideoFrame)
        manager.videoFramePresented(for: replacement)
        XCTAssertEqual(manager.loadingPresentation, .none)
    }

    func testProxyReplacementDetachesThePreviousBufferSignal() {
        let item = item()
        let manager = MediaPlayerManager(playbackItem: item)
        let first = TestProxy()
        let second = TestProxy()
        manager.proxy = first
        manager.videoFramePresented(for: item)
        first.isBuffering.value = true
        XCTAssertEqual(manager.loadingPresentation, .buffering)
        manager.proxy = second
        XCTAssertEqual(manager.loadingPresentation, .none)
        first.isBuffering.value = false
        first.isBuffering.value = true
        XCTAssertFalse(manager.isBuffering)
        second.isBuffering.value = true
        XCTAssertEqual(manager.loadingPresentation, .buffering)
    }

    func testStartupHidesControlsButAStallRevealsOnlyTheProgressBar() async throws {
        let item = item()
        let manager = MediaPlayerManager(playbackItem: item)
        let proxy = TestProxy()
        manager.proxy = proxy
        let state = VideoPlayer.ViewState()
        state.connect(manager: manager)
        state.showControls()
        XCTAssertTrue(state.visibleElements.isEmpty)
        manager.videoFramePresented(for: item)
        try await settle()
        XCTAssertTrue(state.visibleElements.contains(.toolbar))
        state.hideControls()

        proxy.isBuffering.value = true
        try await settle()
        XCTAssertEqual(state.loadingPresentation, .buffering)
        XCTAssertEqual(state.presentation, .progress)
        XCTAssertEqual(state.visibleElements, [.progress], "Do not cover the movie with artwork or a new dimming overlay")
        // Progress normally auto-hides after two seconds. Keep it visible while waiting.
        try await Task.sleep(for: .milliseconds(2200))
        XCTAssertEqual(state.presentation, .progress)

        proxy.isBuffering.value = false
        try await settle()
        XCTAssertEqual(state.loadingPresentation, .none)
        XCTAssertEqual(state.presentation, .progress)
    }

    func testBufferingDoesNotReplaceAnOpenSupplement() async throws {
        let item = item()
        let manager = MediaPlayerManager(playbackItem: item)
        let proxy = TestProxy()
        manager.proxy = proxy
        manager.videoFramePresented(for: item)
        let state = VideoPlayer.ViewState()
        state.connect(manager: manager)
        state.presentGuestSupplement(TestSupplement())
        proxy.isBuffering.value = true
        try await settle()
        XCTAssertEqual(state.selectedSupplementID, "episodes")
        XCTAssertEqual(state.visibleElements, [.supplements, .dimming])
    }

    func testTerminalStatesCannotKeepLoadingAnimationsAlive() {
        for state in [MediaPlayerManager._State.error, .stopped] {
            for hasFrame in [true, false] {
                XCTAssertEqual(PlaybackLoadingPresentation(
                    state: state, hasPresentedVideoFrame: hasFrame, isBuffering: true, playbackRequestStatus: .playing
                ), .none)
            }
        }
    }

    func testStopCancelsPendingPreparationAndRemovesTheStartupScreen() async throws {
        let item = item()
        let manager = MediaPlayerManager(provider: .init(item: item.baseItem) { _, _ in
            try await Task.sleep(for: .seconds(30))
            return item
        })
        let state = VideoPlayer.ViewState()
        state.connect(manager: manager)
        let start = Task { await manager.start() }
        defer { start.cancel() }
        try await settle()
        XCTAssertEqual(state.loadingPresentation, .startup)

        // Back uses this same stop action while the controls are hidden.
        // StatefulMacro diagnoses the overlapping transition before stop cancels it.
        // Match only that dependency diagnostic; all lifecycle assertions remain enforced.
        let warning = XCTExpectedFailure.Options()
        warning.issueMatcher = {
            $0.compactDescription.contains("State warning: A new transition action started while another transition action is in progress!")
        }
        XCTExpectFailure("Stop intentionally supersedes the pending load transition.", options: warning)
        await manager.stop()
        try await settle()
        XCTAssertEqual(manager.state, .stopped)
        XCTAssertEqual(state.loadingPresentation, .none)
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(60))
    }

    private func item(id: String = UUID().uuidString) -> MediaPlayerItem {
        MediaPlayerItem(
            baseItem: BaseItemDto(id: id, name: "Loading fixture", runTimeTicks: 25_200_000_000, type: .episode),
            mediaSource: .init(), playSessionID: "loading-test",
            url: URL(fileURLWithPath: "/loading-fixture.mp4"), deviceProfile: .init()
        )
    }

    private struct TestSupplement: MediaPlayerSupplement {
        let id = "episodes"
        let displayTitle = "Episodes"
        var videoPlayerBody: some View {
            EmptyView()
        }
    }
}

@MainActor
private final class TestProxy: MediaPlayerProxy {
    weak var manager: MediaPlayerManager?
    let isBuffering = PublishedBox(initialValue: false)
    func play() {}
    func pause() {}
    func stop() {}
    func jumpForward(_ seconds: Duration) {}
    func jumpBackward(_ seconds: Duration) {}
    func setRate(_ rate: Double) {}
    func setSeconds(_ seconds: Duration) {}
}
