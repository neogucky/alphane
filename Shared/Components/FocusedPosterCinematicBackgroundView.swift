//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(tvOS)
import Defaults
import SwiftUI

struct FocusedPosterCinematicBackgroundView: View {

    @Default(.Customization.Library.cinematicBackground)
    private var isCinematicBackgroundEnabled

    @FocusedValue(\.focusedPoster)
    private var focusedPoster

    var body: some View {
        ZStack {
            AlphaneTheme.background

            if isCinematicBackgroundEnabled {
                SettledBackdrop(request: .init(
                    posterID: focusedPoster?.id,
                    sources: focusedPoster?.imageSources(for: .landscape, environment: .init(viewContext: .isBackdrop)) ?? []
                ))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    struct BackdropRequest: Hashable {
        let posterID: AnyPoster.ID?
        let sources: [ImageSource]
    }

    struct SettledBackdrop: View {
        let request: BackdropRequest

        @State
        private var settledSources: [ImageSource] = []

        var body: some View {
            Artwork(sources: settledSources)
                .equatable()
                .task(id: request) {
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }

                    settledSources = request.sources
                }
        }
    }

    private struct Artwork: View, Equatable {
        let sources: [ImageSource]

        var body: some View {
            // Focus and scroll updates do not replace the hosted image while
            // its settled sources are unchanged. The previous artwork remains
            // visible until the latest focus has been quiet for 100 ms.
            FadeContentTransitionView(item: sources) { sources in
                ImageView(sources)
                    .failure {
                        EmptyView()
                    }
                    .aspectRatio(contentMode: .fill)
            }
            .blurred()
        }
    }
}
#endif
