//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

/// Initial preparation covers the empty renderer; later stalls retain its frame.
enum PlaybackLoadingPresentation: Equatable {
    case none
    case startup
    case buffering

    init(
        state: MediaPlayerManager._State,
        hasPresentedVideoFrame: Bool,
        isBuffering: Bool,
        playbackRequestStatus: MediaPlayerManager.PlaybackRequestStatus
    ) {
        switch state {
        case .error, .stopped:
            self = .none
        case .loadingItem:
            self = .startup
        case .initial, .playback:
            if !hasPresentedVideoFrame {
                self = .startup
            } else if isBuffering, playbackRequestStatus == .playing {
                self = .buffering
            } else {
                self = .none
            }
        }
    }
}
