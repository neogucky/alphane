//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct PlaybackStartupView: View {
    let item: BaseItemDto

    var body: some View {
        PlaybackStartupContent(item: item) {
            ImageView(item.imageSources(for: .landscape, environment: .init(maxWidth: 1920, viewContext: .isBackdrop)))
                .failure { AlphaneTheme.background }
                .aspectRatio(contentMode: .fill)
        }
    }
}

struct PlaybackStartupContent<Artwork: View>: View {
    @Default(.accentColor)
    private var accentColor

    let item: BaseItemDto
    @ViewBuilder
    var artwork: () -> Artwork

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AlphaneTheme.background
                artwork()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 12)
                    .opacity(0.26)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.28)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 58, weight: .regular))
                        .frame(width: 58, height: 58)

                    StreamingTrack(color: accentColor.opacity(CinemaTrackAppearance.unplayedOpacity(isFocused: true)))
                        .frame(width: 264)

                    Image(systemName: "tv")
                        .font(.system(size: 54, weight: .regular))
                        .frame(width: 66, height: 58)
                }
                .foregroundStyle(.white.opacity(0.6))
                .accessibilityHidden(true)

                HStack(alignment: .bottom, spacing: 80) {
                    VStack(alignment: .leading, spacing: 12) {
                        if item.type == .episode {
                            Text([item.parentTitle, item.seasonEpisodeLabel].compactMap(\.self).joined(separator: "  ·  "))
                                .font(.system(size: 21))
                                .foregroundStyle(AlphaneTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Text(item.displayTitle)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Label(L10n.closePlayer, systemImage: "chevron.left")
                        .font(.system(size: 20))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                }
                .padding(.horizontal, 96)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
