//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemView {

    struct RegularEnhancedHeaderContentGroup: ContentGroup {

        let id: String = ItemView.Component.header
        let provider: ItemContentGroupProvider

        func body(with viewModel: Empty) -> Body {
            Body(provider: provider)
        }

        struct Body: View {

            @ObservedObject
            var provider: ItemContentGroupProvider

            @StoredValue(.User.itemViewAttributes)
            private var attributes

            private let headerAspectRatio = 2.0

            private var logoHeight: CGFloat {
                UIDevice.isTV ? 100 : 70
            }

            @ViewBuilder
            private var logo: some View {
                ImageView(
                    provider.item.imageSource(
                        .logo,
                        itemID: provider.item.id,
                        environment: ImageSourceOptions(maxHeight: logoHeight)
                    )
                )
                .image { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: logoHeight)
                }
                .placeholder { _ in
                    EmptyView()
                }
                .failure {
                    Text(provider.item.displayTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel(provider.item.displayTitle)
                .accessibilityRemoveTraits(.isImage)
            }

            @ViewBuilder
            private var overlay: some View {
                HStack(alignment: .bottom, spacing: EdgeInsets.edgePadding) {
                    VStack(alignment: .center, spacing: UIDevice.isTV ? 30 : 5) {
                        VStack(alignment: .leading) {
                            if let parentID = provider.item.parentRootID, let parentTitle = provider.item.parentTitle {
                                ParentButton(title: parentTitle, id: parentID)
                            }

                            logo
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ItemView.ActionBar(provider: provider)
                    }
                    .frame(width: UIDevice.isTV ? 450 : 300)

                    VStack(alignment: .leading, spacing: 10) {
                        ItemView.Description(item: provider.item)

                        HStack(alignment: .top) {
                            ItemView.AttributesHStack(
                                attributes: attributes,
                                item: provider.item,
                                selectedMediaSource: provider.mediaPlayerItemProvider?.mediaSource,
                                alignment: .leading
                            )

                            MetadataHStack(item: provider.item)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .focusSection()
            }

            var body: some View {
                CinematicContentGroupContainer {
                    overlay
                        .edgePadding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .colorScheme(.dark)
                }
            }
        }
    }
}
