//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVDeviceProfileSummary: View {
    let transcoding: Bool
    let audio: String
    let video: String
    let containers: String

    private func component(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 24) {
            Text(title).frame(width: 130, alignment: .leading)
            Text(value.isEmpty ? L10n.none : value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(transcoding ? String(localized: "Transcoding") : L10n.directPlay)
                .font(.system(size: 22, weight: .medium))
            component(L10n.audio, value: audio)
            component(L10n.video, value: video)
            component(L10n.containers, value: containers.isEmpty ? L10n.all : containers)
        }
        .padding(.vertical, 12)
    }
}

/// A scroll target for reading built-in capabilities, without a no-op button.
struct TVDeviceProfileReference: View {
    let transcoding: Bool
    let audio: String
    let video: String
    let containers: String
    @FocusState
    private var isFocused: Bool

    var body: some View {
        TVDeviceProfileSummary(transcoding: transcoding, audio: audio, video: video, containers: containers)
            .foregroundStyle(isFocused ? Color.white : AlphaneTheme.secondaryText)
            .padding(22)
            .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .tvFocusBorder(isFocused: isFocused, shape: RoundedRectangle(cornerRadius: 24), lineWidth: 2)
            .focusable()
            .focused($isFocused)
            .accessibilityElement(children: .combine)
    }
}
