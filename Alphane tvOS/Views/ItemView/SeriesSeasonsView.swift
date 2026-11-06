//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

/// A stable browser, separate from the detail provider's metadata refreshes.
struct SeriesSeasonsView: View {

    let episode: BaseItemDto

    @StateObject
    private var viewModel: PagingLibraryViewModel<SeasonViewModelLibrary>
    @State
    private var isPrepared = false

    init(episode: BaseItemDto, viewModel: PagingLibraryViewModel<SeasonViewModelLibrary>? = nil) {
        self.episode = episode
        let series = BaseItemDto(id: episode.seriesID, name: episode.seriesName, type: .series)
        _viewModel = StateObject(wrappedValue: viewModel ?? .init(library: SeasonViewModelLibrary(parent: series)))
    }

    private func prepare() async -> Error? {
        await viewModel.refresh()
        guard viewModel.state == .content else { return viewModel.error ?? ErrorMessage(L10n.unknownError) }

        let preferred = viewModel.elements.first { $0.id == episode.seasonID } ?? viewModel.elements.first
        if let preferred, preferred.state == .initial {
            await preferred.refresh()
        }
        isPrepared = true
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            Text(episode.seriesName ?? L10n.seasons)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
                .edgePadding(.horizontal)

            RetryableContentView(
                error: viewModel.state == .error ? viewModel.error : nil,
                retry: { await prepare() }
            ) {
                if !isPrepared {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.elements.isEmpty {
                    Text(L10n.noEpisodesAvailable)
                        .foregroundStyle(AlphaneTheme.secondaryText)
                        .edgePadding(.horizontal)
                } else {
                    SeriesEpisodeContentGroup.Body(
                        viewModel: viewModel,
                        playButtonItem: episode,
                        focusesCurrentSeasonOnEntry: true
                    )
                }
            }
        }
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .task {
            guard !isPrepared else { return }

            _ = await prepare()
        }
    }
}
