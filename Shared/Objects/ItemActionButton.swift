//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

enum ItemActionButton: String, CaseIterable, Displayable, Equatable, Identifiable, Storable, SystemImageable {

    case played
    case favorited
    case trailers
    case playback
    case record
    case subtitles
    case refresh
    case delete

    var displayTitle: String {
        switch self {
        case .played:
            L10n.played
        case .favorited:
            L10n.favorited
        case .trailers:
            L10n.trailers
        case .playback:
            L10n.sourceAndTracks
        case .record:
            L10n.record
        case .refresh:
            L10n.refreshMetadata
        case .subtitles:
            L10n.subtitles
        case .delete:
            L10n.delete
        }
    }

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .played:
            "checkmark"
        case .favorited:
            "heart.fill"
        case .trailers:
            "movieclapper"
        case .playback:
            "slider.horizontal.3"
        case .record:
            "record.circle.fill"
        case .refresh:
            "arrow.clockwise"
        case .subtitles:
            "captions.bubble"
        case .delete:
            "trash"
        }
    }

    var secondarySystemImage: String {
        switch self {
        case .favorited:
            "heart"
        case .record:
            "record.circle"
        default:
            systemImage
        }
    }

    var activeColor: Color? {
        switch self {
        case .played:
            Defaults[.accentColor]

        case .favorited:
            .pink

        case .record:
            .red

        default:
            nil
        }
    }

    static let defaultBarActionButtons: [ItemActionButton] = [
        .played,
        .favorited,
        .record,
        .trailers,
        .playback
    ]

    static let defaultMenuActionButtons: [ItemActionButton] = [
        .refresh,
        .subtitles,
        .delete
    ]
}
