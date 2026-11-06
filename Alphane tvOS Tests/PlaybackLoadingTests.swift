//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI
import XCTest

@MainActor
final class PlaybackLoadingTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await FactoryKit.Container.shared.userSessionManager().start()
        FactoryKit.Container.shared.manager.push()
        FactoryKit.Container.shared.currentUserSession.register { nil }
    }

    override func tearDown() async throws {
        FactoryKit.Container.shared.manager.pop()
        try await super.tearDown()
    }

    func testBackStopsAnInitialStreamWaitingForItsFirstFrame() async throws {
        let previous = Defaults[.confirmClose]
        Defaults[.confirmClose] = true
        defer { Defaults[.confirmClose] = previous }
        let manager = MediaPlayerManager(playbackItem: item())
        let proxy = TestProxy()
        manager.proxy = proxy
        let state = VideoPlayer.ViewState()
        let controller = VideoPlayer.UIContainerViewController(
            viewState: state, manager: manager, videoSize: .init(initialValue: .zero),
            player: { _ in AnyView(Color.black) }, playbackControls: AnyView(EmptyView())
        )
        state.showControls()
        XCTAssertEqual(manager.state, .playback)
        XCTAssertEqual(manager.loadingPresentation, .startup)
        XCTAssertTrue(state.visibleElements.isEmpty)
        let action = NSSelectorFromString("handleMenuEnded")
        XCTAssertTrue(controller.responds(to: action))
        controller.perform(action)
        try await settle()
        XCTAssertEqual(manager.state, .stopped)
        XCTAssertEqual(proxy.stopCount, 1)
        XCTAssertFalse(state.isPresentingCloseConfirmation)
    }

    func testCancelledInitialAndNextEpisodePreparationCannotPublishLateResults() async throws {
        for isNextEpisode in [false, true] {
            let prepared = item()
            let loader = DelayedItemLoader()
            let provider = MediaPlayerItemProvider(item: prepared.baseItem) { _, _ in
                try await loader.load()
            }
            let manager = isNextEpisode ? MediaPlayerManager(playbackItem: item()) : MediaPlayerManager(provider: provider)
            let original = manager.playbackItem
            let start = Task {
                if isNextEpisode {
                    await manager.playNewItem(provider: provider)
                } else {
                    await manager.start()
                }
            }
            for _ in 0 ..< 100 {
                if loader.isWaiting {
                    break
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertTrue(loader.isWaiting)
            let warning = XCTExpectedFailure.Options()
            warning.isStrict = false
            warning.issueMatcher = {
                $0.compactDescription
                    .contains("State warning: A new transition action started while another transition action is in progress!")
            }
            XCTExpectFailure("Stop supersedes preparation while its resolver is waiting.", options: warning)
            await manager.stop()
            XCTAssertEqual(manager.state, .stopped)
            // Model a response whose resolver completes despite cancellation.
            loader.complete(with: prepared)
            await start.value
            XCTAssertTrue(manager.playbackItem === original)
            XCTAssertFalse(manager.playbackItem === prepared)
            XCTAssertEqual(manager.state, .stopped)
            XCTAssertNil(manager.error)
        }
    }

    func testBackAfterTheFirstFrameRetainsTheCloseConfirmationPreference() async throws {
        let previous = Defaults[.confirmClose]
        defer { Defaults[.confirmClose] = previous }
        for shouldConfirm in [true, false] {
            Defaults[.confirmClose] = shouldConfirm
            let playbackItem = item()
            let manager = MediaPlayerManager(provider: .init(item: playbackItem.baseItem) { _, _ in playbackItem })
            await manager.start()
            manager.videoFramePresented(for: playbackItem)
            let state = VideoPlayer.ViewState()
            let controller = VideoPlayer.UIContainerViewController(
                viewState: state, manager: manager, videoSize: .init(initialValue: .zero),
                player: { _ in AnyView(Color.black) }, playbackControls: AnyView(EmptyView())
            )
            state.hideControls()
            controller.perform(NSSelectorFromString("handleMenuEnded"))
            try await settle()
            XCTAssertEqual(state.isPresentingCloseConfirmation, shouldConfirm)
            XCTAssertEqual(manager.state, shouldConfirm ? .playback : .stopped)
            if shouldConfirm {
                await manager.stop()
            }
        }
    }

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
    private(set) var stopCount = 0
    func stop() {
        stopCount += 1
    }

    func jumpForward(_ seconds: Duration) {}
    func jumpBackward(_ seconds: Duration) {}
    func setRate(_ rate: Double) {}
    func setSeconds(_ seconds: Duration) {}
}

@MainActor
private final class DelayedItemLoader {
    private var continuation: CheckedContinuation<MediaPlayerItem, Error>?
    var isWaiting: Bool {
        continuation != nil
    }

    func load() async throws -> MediaPlayerItem {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func complete(with item: MediaPlayerItem) {
        continuation?.resume(returning: item)
        continuation = nil
    }
}
