//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVFontPickerContent: View {

    let selection: Binding<String>

    @State
    private var focusedFont: String?
    @Router
    private var router

    private var previewFont: String {
        focusedFont ?? selection.wrappedValue
    }

    var fontSelection: Binding<[String]> {
        Binding {
            [selection.wrappedValue]
        } set: { value in
            if let font = value.first {
                selection.wrappedValue = font
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 20) {
            Text(String(localized: "The story continues."))
                .font(.custom(previewFont, size: 32))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Text(previewFont)
                .font(.system(size: 18))
                .foregroundStyle(AlphaneTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityIdentifier("subtitle-font-preview")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(L10n.subtitleFont.localizedCapitalized)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .accessibilityAddTraits(.isHeader)
            preview
            ScrollViewReader { proxy in
                ScrollView {
                    TVOptionSelector(
                        selection: fontSelection,
                        sources: UIFont.familyNames,
                        type: .single,
                        onFocusChange: { focusedFont = $0 }
                    ) { Text($0) }
                        .padding(.vertical, 10)
                }
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                        Color.white
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                    }
                }
                .onAppear { proxy.scrollTo(selection.wrappedValue, anchor: .center) }
            }
        }
        .frame(maxWidth: 1280)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 90)
        .padding(.vertical, 60)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.subtitleFont.localizedCapitalized)
        .toolbar(.hidden, for: .navigationBar)
        .onExitCommand { router.dismiss() }
    }
}
