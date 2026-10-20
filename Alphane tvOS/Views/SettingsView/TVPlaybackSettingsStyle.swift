//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVPlaybackSettingsToggleStyle: ToggleStyle {

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(configuration.isOn ? TVSettingsText.on : TVSettingsText.off)
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(TVSettingsButtonStyle())
        .listRowInsets(.zero)
        .listRowBackground(Color.clear)
        .accessibilityValue(configuration.isOn ? TVSettingsText.on : TVSettingsText.off)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

struct TVPlaybackSettingsDescription: View {

    let content: AnyView

    var body: some View {
        Marquee(axis: .vertical, resetType: .bounce, speed: 30, fade: 20) {
            VStack(alignment: .leading, spacing: 24) {
                content
                    .labeledContentStyle(TVPlaybackSettingsDescriptionStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(30)
        }
        .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}

private struct TVPlaybackSettingsDescriptionStyle: LabeledContentStyle {

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            configuration.label
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
            configuration.content
                .font(.system(size: 20))
                .foregroundStyle(AlphaneTheme.secondaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {

    func playbackSettingsStyle() -> some View {
        environment(\.usesPlaybackSettingsStyle, true)
    }
}
