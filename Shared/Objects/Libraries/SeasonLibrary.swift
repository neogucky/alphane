//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI

struct SeasonViewModelLibrary: PagingLibrary {

    // The library belongs to one paging model/session. Keep each season's loaded
    // episodes when a refreshed season list contains the same IDs.
    private let models = EpisodeModels()

    @MainActor
    private final class EpisodeModels {
        weak var session: UserSession?
        var bySeason: [String: Element] = [:]
    }

    let hasNextPage = false
    @SharedBaseItem
    var parent: BaseItemDto

    typealias Element = PagingLibraryViewModel<EpisodeLibrary>

    func retrievePage(
        environment: Empty,
        pageState: LibraryPageState
    ) async throws -> [ItemPatch] {
        if parent.type == .season {
            return try [ItemPatch.snapshot(parent)]
        }
        return try await SeasonLibrary(parent: parent).retrievePage(environment: environment, pageState: pageState)
    }

    func materialize(_ page: [ItemPatch], pageState: LibraryPageState) throws -> [Element] {
        if models.session !== pageState.userSession {
            models.bySeason.removeAll()
            models.session = pageState.userSession
        }
        let seasons = try SeasonLibrary(parent: parent).materialize(page, pageState: pageState)
        let result = seasons.map { season in
            if let model = models.bySeason[season.itemID] {
                return model
            }
            let model = Element(library: EpisodeLibrary(season: season.snapshot), userSession: pageState.userSession)
            models.bySeason[season.itemID] = model
            return model
        }
        let available = Set(seasons.map(\.itemID))
        models.bySeason = models.bySeason.filter { available.contains($0.key) }
        return result
    }
}

struct SeasonLibrary: BaseItemKindLibrary {

    let hasNextPage = false

    let libraryItemTypes: [BaseItemKind] = [.season]
    @SharedBaseItem
    var parent: BaseItemDto

    func retrievePage(
        environment: Empty,
        pageState: LibraryPageState
    ) async throws -> [ItemPatch] {
        guard let seriesID = parent.id else {
            throw ErrorMessage(L10n.unknownError)
        }

        var parameters = Paths.GetSeasonsParameters()
        parameters.fields = PosterSubtitleField.itemFields
        parameters.isMissing = Defaults[.Customization.shouldShowMissingSeasons] ? nil : false
        parameters.userID = pageState.userSession.user.id

        let request = Paths.getSeasons(seriesID: seriesID, parameters: parameters)
        let response = try await pageState.userSession.client.send(request)

        return try pageState.items(from: response)
    }
}
