//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension SeriesEpisodeContentGroup {

    struct SeasonSelector: View {

        let seasons: [PagingLibraryViewModel<EpisodeLibrary>]

        @Binding
        var selection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        let preferredSelection: PagingLibraryViewModel<EpisodeLibrary>.ID?

        @FocusState
        private var focusedSeason: PagingLibraryViewModel<EpisodeLibrary>.ID?

        private var selectedSeason: PagingLibraryViewModel<EpisodeLibrary>? {
            seasons.first { $0.id == selection }
        }

        @ViewBuilder
        private func title(_ value: String) -> some View {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .edgePadding(.horizontal)
        }

        var body: some View {
            if seasons.isEmpty {
                title(L10n.episodes)
            } else {
                ScrollView(.horizontal) {
                    SelectionTrack(
                        seasons,
                        selection: focusedSeason ?? selection,
                        focus: $focusedSeason
                    ) { season in
                        selection = season.id
                    }
                    .controlSize(.large)
                    .edgePadding(.horizontal)
                    .transaction { transaction in
                        // Switch the pill in one frame instead of crossfading two seasons.
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .activeSelectionFocus($focusedSeason, selection: selection ?? preferredSelection)
                .onChange(of: focusedSeason) { _, seasonID in
                    guard let seasonID,
                          seasonID != selection,
                          seasons.contains(where: { $0.id == seasonID })
                    else { return }

                    // Episode retrieval can finish later; selection follows focus immediately.
                    selection = seasonID
                }
            }
        }
    }
}
