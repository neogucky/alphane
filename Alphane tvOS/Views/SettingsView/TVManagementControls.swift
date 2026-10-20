//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVManagementPage<Actions: View, Content: View>: View {
    let title: String
    var width: CGFloat = 1280
    @ViewBuilder
    var actions: Actions
    @ViewBuilder
    var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                HStack(spacing: 24) {
                    Text(title)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 24)
                    actions
                }
                .padding(.horizontal, 22)
                content
            }
            .frame(maxWidth: width)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 90)
            .padding(.vertical, 60)
        }
        .buttonStyle(TVSettingsButtonStyle())
        .menuStyle(TVSettingsMenuStyle())
        .toggleStyle(TVPlaybackSettingsToggleStyle())
        .environment(\.usesPlaybackSettingsStyle, true)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TVManagementSection<Content: View>: View {
    let title: String
    @ViewBuilder
    var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title.localizedUppercase)
                .font(.system(size: 18, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(AlphaneTheme.secondaryText)
                .padding(.horizontal, 22)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TVManagementNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20))
            .foregroundStyle(AlphaneTheme.secondaryText)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
    }
}

struct TVManagementField: View {
    let title: String
    @Binding
    var text: String
    var isURL = false
    @State
    private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19))
                .foregroundStyle(AlphaneTheme.secondaryText)
                .padding(.horizontal, 22)
            Button { isEditing = true } label: {
                HStack(spacing: 20) {
                    Text(text.isEmpty ? title : text)
                        .font(.system(size: 24))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                }
            }
            .buttonStyle(TVSettingsButtonStyle())
            .accessibilityLabel(title)
            .accessibilityValue(text)
            .background {
                TVSignInKeyboard(
                    text: $text, isPresented: $isEditing, title: title, secure: false, password: false,
                    submit: {}, contentType: isURL ? .URL : nil, keyboardType: isURL ? .URL : .default,
                    returnKeyType: .done
                )
                .frame(width: 1, height: 1)
                .clipped()
                .opacity(0.01)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 12)
        .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
