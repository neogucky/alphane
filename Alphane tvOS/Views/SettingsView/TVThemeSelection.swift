//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct TVThemeSelection: View {
    @Default(.userColorTheme)
    private var storedTheme
    @Default(.userAccentColor)
    private var customColor
    let focus: FocusState<String?>.Binding

    private var selected: AlphaneColorTheme {
        .resolved(stored: storedTheme, custom: customColor)
    }

    var body: some View {
        TVThemeChoices(
            selection: Binding(get: { selected }, set: { storedTheme = $0 }),
            customColor: $customColor,
            focus: focus
        )
    }
}

/// Shared by Appearance and setup so saved/focused states stay identical.
struct TVThemeChoices: View {
    @Binding
    var selection: AlphaneColorTheme
    @Binding
    var customColor: Color
    let focus: FocusState<String?>.Binding
    @State
    private var showsCustomPicker = false

    private func row(_ theme: AlphaneColorTheme) -> some View {
        HStack(spacing: 14) {
            Text(theme.title).lineLimit(1)
            Spacer(minLength: 12)
            if theme == selection {
                Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold))
            }
            if theme == .custom {
                Image(systemName: "chevron.right").font(.system(size: 16))
            }
        }
        .font(.system(size: 22, weight: .medium))
        .frame(minHeight: 46)
    }

    var body: some View {
        VStack(spacing: 18) {
            ForEach(AlphaneColorTheme.presets, id: \.self) { theme in
                Button { selection = theme } label: { row(theme) }
                    .focused(focus, equals: "theme-" + theme.rawValue)
                    .isSelected(selection == theme)
                    .accessibilityIdentifier("settings-theme-" + theme.rawValue)
            }
            Button { showsCustomPicker = true } label: { row(.custom) }
                .focused(focus, equals: "accent")
                .isSelected(selection == .custom)
                .accessibilityIdentifier("settings-accent")
        }
        .buttonStyle(CapsuleButtonStyle(isSelectionActive: false, fillsAvailableWidth: true))
        .activeSelectionFocus(focus, selection: selection == .custom ? "accent" : "theme-" + selection.rawValue)
        .sheet(isPresented: $showsCustomPicker) {
            StateAdapter(initialValue: customColor) { draft in
                ColorPicker.Sheet(title: L10n.accentColor, value: draft, supportsOpacity: false)
                    .onDisappear {
                        customColor = draft.wrappedValue
                        selection = .custom
                    }
            }
        }
    }
}
