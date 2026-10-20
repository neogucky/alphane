//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Direct bindings keep external changes, such as Reset, reflected in the selected pills.
struct TVOptionSelector<Element: Hashable, Label: View>: View {

    let selection: Binding<[Element]>
    let sources: [Element]
    let type: SelectorType
    var columnCount = 3
    var onFocusChange: (Element?) -> Void = { _ in }
    @ViewBuilder
    let label: (Element) -> Label

    @FocusState
    private var focusedElement: Element?
    @Namespace
    private var focusScope
    @State
    private var hasEnteredGroup = false

    var preferredElement: Element? {
        sources.first { selection.wrappedValue.contains($0) } ?? sources.first
    }

    func select(_ element: Element) {
        switch type {
        case .single:
            selection.wrappedValue = [element]
        case .multi:
            if selection.wrappedValue.contains(element) {
                selection.wrappedValue.removeAll { $0 == element }
            } else {
                selection.wrappedValue.append(element)
            }
        }
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .leading), count: columnCount),
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(sources, id: \.self) { element in
                let isSelected = selection.wrappedValue.contains(element)
                Button { select(element) } label: {
                    HStack(spacing: 14) {
                        label(element)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 20)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 46)
                }
                .isSelected(isSelected)
                .focused($focusedElement, equals: element)
                .prefersDefaultFocus(element == preferredElement, in: focusScope)
                .id(element)
            }
        }
        .font(.system(size: 22))
        .buttonStyle(CapsuleButtonStyle(isSelectionActive: false, fillsAvailableWidth: true))
        .focusScope(focusScope)
        .activeSelectionFocus($focusedElement, selection: preferredElement)
        .onChange(of: focusedElement) {
            // A surrounding scroll view can give its first visible cell focus before
            // honoring the group's preference. Reconcile that first entry once, after
            // the controls are focusable; subsequent arrow movement stays native.
            if let focusedElement, !hasEnteredGroup {
                hasEnteredGroup = true
                if let preferredElement, focusedElement != preferredElement {
                    self.focusedElement = preferredElement
                    return
                }
            }
            onFocusChange(focusedElement)
        }
    }
}
