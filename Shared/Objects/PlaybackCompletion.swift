//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

enum PlaybackCompletion {

    struct StopEvent {
        let report: PlaybackStopInfo
        let didReachEnd: Bool
    }

    /// Update only playback fields on the shared record. Metadata, artwork,
    /// source selections and the detail page's loaded groups stay in place.
    @MainActor
    static func applyStop(
        _ report: PlaybackStopInfo,
        didReachEnd: Bool = false,
        to entry: ItemEntry,
        in store: ItemStore?
    ) throws {
        guard report.itemID == entry.itemID,
              let item = entry.value, !item.isLiveStream,
              let position = report.positionTicks, position >= 0
        else { return }

        var data = item.userData ?? UserItemDataDto(key: entry.itemID)
        data.itemID = entry.itemID
        data.playbackPositionTicks = position
        var fields: Set<String> = ["PlaybackPositionTicks"]
        if let runtime = item.runTimeTicks, runtime > 0 {
            data.playedPercentage = min(100, Double(position) / Double(runtime) * 100)
            fields.insert("PlayedPercentage")
        }
        if didReachEnd || reachedEnd(of: item, at: position) {
            data.isPlayed = true
            data.playbackPositionTicks = 0
            data.playedPercentage = 100
            fields.formUnion(["Played", "PlayedPercentage"])
        }

        if let store {
            try store.mergeUserData(data, fields: fields, token: store.beginRequest())
        } else {
            // Presentation-only entries used without an authenticated session.
            let patch = ItemPatch(
                value: BaseItemDto(id: entry.itemID, userData: data),
                fields: ["UserData"],
                userDataFields: fields
            )
            try entry.item.merge(patch, revision: 0, program: nil)
        }
    }

    static func reachedEnd(of item: BaseItemDto, at positionTicks: Int?) -> Bool {
        guard let runtime = item.runTimeTicks, runtime > 0,
              let positionTicks, positionTicks > 0
        else { return false }

        return positionTicks >= runtime - 10_000_000
    }

    /// Prefer Next only after this viewing reached the end, never when opening
    /// an episode or stopping partway through a rewatch.
    static func shouldPreferNextEpisode(
        after item: BaseItemDto,
        stoppedAt positionTicks: Int?,
        didReachEnd: Bool = false,
        nextEpisode: BaseItemDto?
    ) -> Bool {
        item.type == .episode
            && (didReachEnd || reachedEnd(of: item, at: positionTicks))
            && item.userData?.isPlayed == true
            && (item.userData?.playbackPositionTicks ?? 0) == 0
            && nextEpisode?.type == .episode
            && nextEpisode?.isPlayable == true
    }

    @MainActor
    static func refreshedItem(
        stoppedAt positionTicks: Int?,
        didReachEnd: Bool = false,
        fetch: () async throws -> BaseItemDto,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(500)) }
    ) async throws -> BaseItemDto {
        var item = try await fetch()
        guard didReachEnd || reachedEnd(of: item, at: positionTicks) else { return item }

        for _ in 0 ..< 3 {
            if item.userData?.isPlayed == true {
                break
            }
            try await pause()
            item = try await fetch()
        }

        // A natural ending is known locally even if a read replica or cache
        // still has the older resume point. This affects display only.
        var data = item.userData ?? UserItemDataDto(key: item.id ?? "")
        data.isPlayed = true
        data.playbackPositionTicks = 0
        data.playedPercentage = 100
        item.userData = data
        return item
    }
}
