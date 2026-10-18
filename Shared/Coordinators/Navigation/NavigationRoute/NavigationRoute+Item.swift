//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension NavigationRoute {

    // MARK: - Item Editing

    @MainActor
    static func castAndCrew(people: [BaseItemPerson], itemID: String?) -> NavigationRoute {
        let id = itemID == nil ? "castAndCrew" : "castAndCrew-\(itemID!)"
        let library = StaticLibrary(
            title: L10n.castAndCrew.localizedCapitalized,
            id: id,
            elements: people
        )

        return NavigationRoute(id: "castAndCrew") {
            PagingLibraryView(library: library)
        }
    }

    static func searchSubtitle(viewModel: ItemSubtitlesViewModel) -> NavigationRoute {
        NavigationRoute(
            id: "searchSubtitle",
            style: .sheet
        ) {
            ItemSubtitleSearchView(viewModel: viewModel)
        }
    }

    @MainActor
    static func item(item: BaseItemDto, startPlayback: Bool = false) -> NavigationRoute {
        let provider = ItemContentGroupProvider(item: item)

        return NavigationRoute(
            id: "item-\(item.id ?? "Unknown")",
            withNamespace: { .push(.zoom(sourceID: "item", namespace: $0)) }
        ) {
            ItemView(provider: provider, startPlayback: startPlayback)
        }
    }

    @MainActor
    static func item(id: String) -> NavigationRoute {
        let provider = ItemContentGroupProvider(id: id)

        return NavigationRoute(
            id: "item-\(id)",
            withNamespace: { .push(.zoom(sourceID: "item", namespace: $0)) }
        ) {
            ItemView(provider: provider)
        }
    }

    static func itemMetadataRefresh(viewModel: ItemEditorViewModel) -> NavigationRoute {
        NavigationRoute(
            id: "itemMetadataRefresh",
            style: .sheet
        ) {
            ItemRefreshView(viewModel: viewModel)
        }
    }

    static func itemOverview(item: BaseItemDto) -> NavigationRoute {
        NavigationRoute(
            id: "itemOverview",
            style: .sheet
        ) {
            ItemOverviewView(item: item)
        }
    }

    @MainActor
    static func editRecordingTimer(
        viewModel: RecordingTimerViewModel,
        isSeries: Bool
    ) -> NavigationRoute {
        NavigationRoute(
            id: "editRecordingTimer",
            style: .sheet
        ) {
            EditRecordingView(
                viewModel: viewModel,
                isSeries: isSeries
            )
        }
    }
}
