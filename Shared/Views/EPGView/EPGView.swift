//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct EPGView: View {

    @Router
    private var router

    @StateObject
    private var viewModel = EPGViewModel()

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            #if os(tvOS)
            HStack(spacing: 24) {
                Text(L10n.guide)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                EPGDateBar(viewModel: viewModel)
                Spacer(minLength: 0)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
            #endif

            EPGContentView(
                viewModel: viewModel
            ) {
                router.route(to: .item(item: $0))
            }
        }
    }

    var body: some View {
        EPGLoadableView(viewModel: viewModel) {
            contentView
        }
        .onFirstAppear {
            viewModel.refresh(startDate: nil)
        }
        .refreshable {
            await viewModel.refresh(startDate: nil)
        }
        .onSceneWillEnterForeground {
            Task {
                await viewModel.refresh(startDate: nil)
            }
        }
        .padding(.horizontal, 60)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: [.horizontal])
    }
}
