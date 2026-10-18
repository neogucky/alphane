//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemSubtitleSearchView {

    struct SearchResultRow: View {

        @Environment(\.isSelected)
        private var isSelected

        let subtitle: RemoteSubtitleInfo
        let action: () -> Void

        var body: some View {
            tvOSContent
        }

        #if os(tvOS)
        private var tvOSContent: some View {
            Button(action: action) {
                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(subtitle.name ?? L10n.unknown)
                            .font(.system(size: 22, weight: .medium))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 22) {
                            Text(subtitle.threeLetterISOLanguageName?.localizedUppercase ?? L10n.unknown)
                            if let format = subtitle.format {
                                Text(format.localizedUppercase)
                            }
                            if let count = subtitle.downloadCount {
                                Label(count.formatted(), systemImage: "arrow.down")
                                    .accessibilityLabel("\(L10n.downloads): \(count)")
                            }
                            if let rating = subtitle.communityRating {
                                Label(String(format: "%.1f", rating), systemImage: "star")
                                    .accessibilityLabel("\(L10n.communityRating): \(rating)")
                            }
                            if let author = subtitle.author {
                                Text(author).lineLimit(1)
                            }
                        }
                        .font(.system(size: 18))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .opacity(isSelected ? 1 : 0)
                        .frame(width: 28)
                }
                .padding(.vertical, 18)
            }
            .buttonStyle(CapsuleButtonStyle(isSelectionActive: false, fillsAvailableWidth: true))
        }
        #endif

        private var legacyContent: some View {
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subtitle.name ?? L10n.unknown)
                            .font(.headline)
                            .fontWeight(.semibold)

                        LabeledContent(L10n.language, value: subtitle.threeLetterISOLanguageName ?? L10n.unknown)

                        if let downloadCount = subtitle.downloadCount {
                            LabeledContent(L10n.downloads, value: downloadCount.description)
                        }

                        if let rating = subtitle.communityRating {
                            LabeledContent(L10n.communityRating, value: String(format: "%.1f", rating))
                        }

                        if let author = subtitle.author {
                            LabeledContent(L10n.author, value: author)
                        }

                        if let format = subtitle.format {
                            LabeledContent(L10n.format, value: format)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ListRowCheckbox()
                }
                .if(UIDevice.isTV) { row in
                    row
                        .padding(.vertical)
                }
            }
            .foregroundStyle(isSelected ? .primary : .secondary, .secondary)
            .font(.caption)
            .isEditing(true)
        }
    }
}
