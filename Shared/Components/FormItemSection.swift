//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct FormItemSection<Item: Poster>: View {

    @SharedPoster
    var item: Item

    var body: some View {
        Section(L10n.media) {
            if let baseItem = item as? BaseItemDto,
               let parentLabel = baseItem.parentLabel,
               let parentValue = baseItem.parentTitle
            {
                LabeledContent(
                    parentLabel,
                    value: parentValue
                )
            }

            LabeledContent(
                L10n.title,
                value: item.displayTitle
            )

            if let baseItem = item as? BaseItemDto,
               let subtitleLabel = baseItem.type?.displayTitle,
               let subtitleValue = baseItem.subtitle
            {
                LabeledContent(
                    subtitleLabel,
                    value: subtitleValue
                )
            } else if let baseItem = item as? BaseItemDto,
                      let year = baseItem.productionYear
            {
                LabeledContent(
                    L10n.year,
                    value: year.description
                )
            }
        }
        .labeledContentStyle(.focusable)
    }
}
