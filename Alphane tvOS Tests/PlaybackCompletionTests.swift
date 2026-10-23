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

@MainActor
final class PlaybackCompletionTests: XCTestCase {

    func testNaturalEndUpdatesTheSharedRecordDespiteDifferentSourceRuntime() throws {
        let store = ItemStore()
        var episode = item(played: false)
        episode.runTimeTicks = Duration.seconds(43 * 60).ticks
        episode.name = "Behind the Red Curtain"
        episode.userData?.isFavorite = true
        let entry = try ItemEntry(item: store.record(for: episode))
        let staleRequest = try store.beginRequest()
        var report = PlaybackStopInfo()
        report.itemID = episode.id
        report.positionTicks = Duration.seconds(38 * 60).ticks

        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: store)
        // A request begun before Stop must not restore the old resume point.
        try store.merge(ItemPatch.snapshot(episode), token: staleRequest)

        XCTAssertTrue(entry.item === store["nine"])
        XCTAssertEqual(entry.snapshot.name, episode.name)
        XCTAssertEqual(entry.snapshot.userData?.isFavorite, true)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, 0)
        XCTAssertEqual(entry.snapshot.userData?.playedPercentage, 100)
        XCTAssertTrue(PlaybackCompletion.shouldPreferNextEpisode(
            after: entry.snapshot, stoppedAt: report.positionTicks, didReachEnd: true, nextEpisode: nextEpisode
        ))
    }

    func testManualStopPreservesResumeAndDoesNotCompleteAnUnwatchedEpisode() throws {
        let store = ItemStore()
        var episode = item(played: false)
        episode.runTimeTicks = Duration.seconds(43 * 60).ticks
        let entry = try ItemEntry(item: store.record(for: episode))
        var report = PlaybackStopInfo()
        report.itemID = "nine"
        report.positionTicks = Duration.seconds(38 * 60).ticks
        try PlaybackCompletion.applyStop(report, to: entry, in: store)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, false)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, report.positionTicks)
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: entry.snapshot, stoppedAt: report.positionTicks, nextEpisode: nextEpisode
        ))
    }

    func testInFlightCompletionKeepsLateSocketProgressOutOfTheVisibleTimeline() throws {
        let store = ItemStore()
        let episode = item(played: false)
        let entry = try ItemEntry(item: store.record(for: episode))
        let completionID = UUID()
        entry.item.beginPlaybackCompletion(id: completionID)
        var report = PlaybackStopInfo()
        report.itemID = episode.id
        report.positionTicks = episode.runTimeTicks
        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: store)
        // Socket messages acquire a new token when delivered, even if they
        // describe a progress request sent before Stop.
        try store.merge(ItemPatch.snapshot(episode), token: store.beginRequest())
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, 0)
        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: store)
        entry.item.endPlaybackCompletion(id: completionID)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, 0)
    }

    func testNaturalEndCreatesMissingUserDataAndIgnoresUnrelatedStops() throws {
        let store = ItemStore()
        let entry = try ItemEntry(item: store.record(for: BaseItemDto(id: "nine", type: .episode)))
        var report = PlaybackStopInfo()
        report.itemID = "other"
        report.positionTicks = 0
        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: store)
        XCTAssertNil(entry.snapshot.userData)
        report.itemID = "nine"
        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: store)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, 0)
    }

    func testNaturalEndingWaitsForStaleWatchedStateToSettle() async throws {
        var calls = 0
        let result = try await PlaybackCompletion.refreshedItem(stoppedAt: 3_102_100_000) {
            calls += 1
            return self.item(played: calls > 1)
        } pause: {}
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(result.userData?.isPlayed, true)
        XCTAssertEqual(result.userData?.playbackPositionTicks, 0)
    }

    func testNaturalEndingDoesNotKeepStaleResumePositionAfterBoundedRetries() async throws {
        var calls = 0
        let result = try await PlaybackCompletion.refreshedItem(stoppedAt: 3_102_100_000) {
            calls += 1
            return self.item(played: false)
        } pause: {}
        XCTAssertEqual(calls, 4)
        XCTAssertEqual(result.userData?.isPlayed, true)
        XCTAssertEqual(result.userData?.playbackPositionTicks, 0)
    }

    func testStoppingHalfwayDoesNotMarkEpisodeWatchedOrRetry() async throws {
        var calls = 0
        let result = try await PlaybackCompletion.refreshedItem(stoppedAt: 1_503_860_000) {
            calls += 1
            return self.item(played: false)
        } pause: {}
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(result.userData?.isPlayed, false)
        XCTAssertEqual(result.userData?.playbackPositionTicks, 1_503_860_000)
    }

    func testEndingARewatchClearsStaleResumePositionWithoutRetrying() async throws {
        var watched = item(played: true)
        watched.userData?.playbackPositionTicks = 1_503_860_000
        var calls = 0
        let result = try await PlaybackCompletion.refreshedItem(stoppedAt: 3_102_100_000) {
            calls += 1
            return watched
        } pause: { XCTFail("Already-watched state needs no retry") }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(result.userData?.playbackPositionTicks, 0)
        XCTAssertTrue(PlaybackCompletion.shouldPreferNextEpisode(
            after: result, stoppedAt: 3_102_100_000, nextEpisode: nextEpisode
        ))
    }

    func testNextFocusRequiresAPlaybackStopAndCompletedStateWithAnAvailableNextEpisode() {
        let watched = item(played: true)
        XCTAssertTrue(PlaybackCompletion.shouldPreferNextEpisode(
            after: watched, stoppedAt: watched.runTimeTicks, nextEpisode: nextEpisode
        ))
        // Simply opening an episode, even a watched one, keeps Play/Continue selected.
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: watched, stoppedAt: nil, nextEpisode: nextEpisode
        ))
        // Jellyfin can complete an episode during its credits, before EOF.
        XCTAssertTrue(PlaybackCompletion.shouldPreferNextEpisode(
            after: watched, stoppedAt: 1_503_860_000, nextEpisode: nextEpisode
        ))
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: watched, stoppedAt: 0, nextEpisode: nextEpisode
        ))
        var resumable = watched
        resumable.userData?.playbackPositionTicks = 1_503_860_000
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: resumable, stoppedAt: resumable.runTimeTicks, nextEpisode: nextEpisode
        ))
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: watched, stoppedAt: watched.runTimeTicks, nextEpisode: nil
        ))
        var movie = watched
        movie.type = .movie
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: movie, stoppedAt: movie.runTimeTicks, nextEpisode: nextEpisode
        ))
    }

    func testManualCreditsStopPrefersNextOnlyAfterJellyfinClearsTheResumePoint() throws {
        let store = ItemStore()
        let episode = item(played: false)
        let entry = try ItemEntry(item: store.record(for: episode))
        var report = PlaybackStopInfo()
        report.itemID = episode.id
        report.positionTicks = Duration.seconds(285).ticks
        XCTAssertFalse(PlaybackCompletion.reachedEnd(of: episode, at: report.positionTicks))

        try PlaybackCompletion.applyStop(report, to: entry, in: store)
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: entry.snapshot, stoppedAt: report.positionTicks, nextEpisode: nextEpisode
        ))

        var completed = UserItemDataDto(key: entry.itemID)
        completed.itemID = entry.itemID
        completed.isPlayed = true
        completed.playbackPositionTicks = 0
        completed.playedPercentage = 100
        try store.mergeUserData(completed, token: store.beginRequest())
        XCTAssertEqual(entry.snapshot.playButtonLabel, L10n.playAgain)
        XCTAssertTrue(PlaybackCompletion.shouldPreferNextEpisode(
            after: entry.snapshot, stoppedAt: report.positionTicks, nextEpisode: nextEpisode
        ))

        // A later partial rewatch must return to Resume even though Played stays true.
        report.positionTicks = Duration.seconds(60).ticks
        try PlaybackCompletion.applyStop(report, to: entry, in: store)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertNotNil(entry.snapshot.progressLabel)
        XCTAssertFalse(PlaybackCompletion.shouldPreferNextEpisode(
            after: entry.snapshot, stoppedAt: report.positionTicks, nextEpisode: nextEpisode
        ))
    }

    func testOnlyTheMatchingStopUpdatesDetailPlaybackFocusContext() {
        let provider = ItemContentGroupProvider(item: item(played: false))
        var report = PlaybackStopInfo()
        report.itemID = "nine"
        report.positionTicks = 1_503_860_000
        XCTAssertTrue(provider.prepareForPlaybackStop(report))
        XCTAssertEqual(provider.lastPlaybackStopPosition, report.positionTicks)
        report.itemID = "other-episode"
        report.positionTicks = 3_102_100_000
        XCTAssertFalse(provider.prepareForPlaybackStop(report))
        XCTAssertEqual(provider.lastPlaybackStopPosition, 1_503_860_000)
    }

    private var nextEpisode: BaseItemDto {
        BaseItemDto(id: "ten", type: .episode)
    }

    func testUnknownRuntimeAndUnrelatedStopCannotCompleteTheDetailPage() {
        var episode = item(played: false)
        episode.runTimeTicks = nil
        XCTAssertFalse(PlaybackCompletion.reachedEnd(of: episode, at: 3_102_100_000))
        let provider = ItemContentGroupProvider(item: episode)
        var report = PlaybackStopInfo()
        report.itemID = "different-episode"
        report.positionTicks = 3_102_100_000
        XCTAssertFalse(provider.prepareForPlaybackStop(report))
    }

    private func item(played: Bool) -> BaseItemDto {
        BaseItemDto(
            id: "nine", runTimeTicks: 3_102_100_000, type: .episode,
            userData: UserItemDataDto(isPlayed: played, key: "nine", playbackPositionTicks: played ? 0 : 1_503_860_000)
        )
    }
}
