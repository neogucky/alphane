//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVOrderedOptions<Element: Displayable & Hashable>: View {
    let title: String
    @Binding
    var selection: [Element]
    let sources: [Element]
    let removable: [Element]
    @Router
    private var router

    private var available: [Element] {
        sources.filter { !selection.contains($0) && removable.contains($0) }
    }

    func toggle(_ element: Element) {
        guard removable.contains(element), sources.contains(element) else { return }

        selection.toggle(element)
    }

    func move(_ element: Element, by distance: Int) {
        guard let index = selection.firstIndex(of: element),
              selection.indices.contains(index + distance) else { return }

        selection.move(fromOffsets: IndexSet(integer: index), toOffset: distance < 0 ? index + distance : index + distance + 1)
    }

    private func label(_ element: Element) -> some View {
        HStack(spacing: 16) {
            if let imageable = element as? SystemImageable {
                Image(systemName: imageable.systemImage)
                    .frame(width: 28)
            }
            Text(element.displayTitle)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 22, weight: .medium))
        .frame(minHeight: 38)
    }

    private func enabledRow(_ element: Element, index: Int) -> some View {
        HStack(spacing: 4) {
            if removable.contains(element) {
                Button { toggle(element) } label: {
                    HStack(spacing: 12) {
                        label(element)
                        Image(systemName: "minus").font(.system(size: 18))
                    }
                }
                .accessibilityHint(String(localized: "Remove from enabled options"))
            } else {
                label(element)
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .accessibilityValue(String(localized: "Required"))
            }
            Button { move(element, by: -1) } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(index == 0)
            .accessibilityLabel(String(localized: "Move \(element.displayTitle) up"))
            Button { move(element, by: 1) } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(index == selection.count - 1)
            .accessibilityLabel(String(localized: "Move \(element.displayTitle) down"))
        }
        .padding(8)
        .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    var body: some View {
        TVManagementPage(title: title, width: 1500) {
            Button(L10n.done) { router.dismiss() }
        } content: {
            HStack(alignment: .top, spacing: 64) {
                TVManagementSection(title: L10n.enabled) {
                    if selection.isEmpty {
                        TVManagementNote(text: L10n.none)
                    }
                    ForEach(Array(selection.enumerated()), id: \.element) { index, element in
                        enabledRow(element, index: index)
                    }
                }
                .frame(maxWidth: .infinity)
                .focusSection()
                TVManagementSection(title: L10n.disabled) {
                    if available.isEmpty {
                        TVManagementNote(text: L10n.none)
                    }
                    ForEach(available, id: \.self) { element in
                        Button { toggle(element) } label: {
                            HStack(spacing: 12) {
                                label(element)
                                Image(systemName: "plus").font(.system(size: 18))
                            }
                        }
                        .accessibilityHint(String(localized: "Add to enabled options"))
                    }
                }
                .frame(maxWidth: .infinity)
                .focusSection()
            }
        }
        .onExitCommand { router.dismiss() }
    }
}
