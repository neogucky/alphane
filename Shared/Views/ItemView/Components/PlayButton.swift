//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import Logging
import SwiftUI

struct PlayButton: View {

    @Default(.accentColor)
    private var accentColor

    @ObservedObject
    var provider: ItemContentGroupProvider

    @Router
    private var router

    private var actionTint: Color {
        AlphaneTheme.surface
    }

    private var itemProvider: MediaPlayerItemProvider? {
        provider.mediaPlayerItemProvider
    }

    private var mediaSource: String? {
        guard itemProvider?.item.mediaSources?.count ?? 0 > 1 else { return nil }

        return itemProvider?.mediaSource?.displayTitle
    }

    private func play(fromBeginning: Bool = false) {
        let mediaPlayerItemProvider = if fromBeginning {
            itemProvider?.modifyingItem {
                $0.userData?.playbackPositionTicks = 0
            }
        } else {
            itemProvider
        }

        guard let mediaPlayerItemProvider else {
            provider.logger.error("Play selected with no playback item provider")
            return
        }

        let queue: (any MediaPlayerQueue)? = mediaPlayerItemProvider.item.type == .episode ?
            EpisodeMediaPlayerQueue(episode: mediaPlayerItemProvider.item) : nil

        router.route(
            to: .videoPlayer(
                provider: mediaPlayerItemProvider,
                queue: queue
            )
        )
    }

    var body: some View {
        Button {
            play()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                Text(itemProvider?.item.progressLabel == nil ? (itemProvider?.item.playButtonLabel ?? L10n.play) : L10n.resume)
                if let progressLabel = itemProvider?.item.progressLabel {
                    Text(progressLabel)
                        .font(.system(size: 22))
                }
            }
            .frame(minWidth: 160)
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(.capsule)
        .controlSize(.extraLarge)
        .contextMenu {
            if itemProvider?.item.userData?.playbackPositionTicks != 0 {
                Button(L10n.playFromBeginning, systemImage: "gobackward") {
                    play(fromBeginning: true)
                }
            }
        }
        .disabled(itemProvider == nil)
        #if os(tvOS)
            .accessibilityIdentifier("item-play")
        #endif
    }
}
