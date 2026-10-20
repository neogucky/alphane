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
    var onPreview: ((AlphaneColorTheme) -> Void)?
    var onConfirm: (() -> Void)?
    @State
    private var showsCustomPicker = false
    @State
    private var draftCustomColor: Color = .white
    @State
    private var isCustomFocused = false
    @State
    private var isCustomConfirmationPending = false

    private func confirmCustomWhenFocusReturns() {
        guard isCustomConfirmationPending, isCustomFocused else { return }

        isCustomConfirmationPending = false
        onConfirm?()
    }

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
                Button {
                    selection = theme
                    onConfirm?()
                } label: { row(theme) }
                    .focused(focus, equals: "theme-" + theme.rawValue)
                    .isSelected(selection == theme)
                    .accessibilityIdentifier("settings-theme-" + theme.rawValue)
            }
            Button {
                draftCustomColor = customColor
                isCustomFocused = false
                showsCustomPicker = true
            } label: {
                row(.custom)
                    .modifier(CustomChoiceFocusObserver { isFocused in
                        isCustomFocused = isFocused
                        confirmCustomWhenFocusReturns()
                    })
            }
            .focused(focus, equals: "accent")
            .isSelected(selection == .custom)
            .accessibilityIdentifier("settings-accent")
        }
        .buttonStyle(CapsuleButtonStyle(isSelectionActive: false, fillsAvailableWidth: true))
        .activeSelectionFocus(focus, selection: selection == .custom ? "accent" : "theme-" + selection.rawValue)
        .onChange(of: focus.wrappedValue) {
            if let theme = AlphaneColorTheme.allCases.first(where: {
                focus.wrappedValue == ($0 == .custom ? "accent" : "theme-" + $0.rawValue)
            }) {
                onPreview?(theme)
            }
        }
        .sheet(isPresented: $showsCustomPicker, onDismiss: {
            customColor = draftCustomColor
            selection = .custom
            // The sheet's dismissal callback can precede native focus restoration.
            // Hand off to Next only once the covered Custom button has focus again.
            isCustomConfirmationPending = onConfirm != nil
            confirmCustomWhenFocusReturns()
        }) {
            ColorPicker.Sheet(title: L10n.accentColor, value: $draftCustomColor, supportsOpacity: false)
        }
    }
}

private struct CustomChoiceFocusObserver: ViewModifier {
    @Environment(\.isFocused)
    private var isFocused
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: isFocused) { onChange(isFocused) }
    }
}
