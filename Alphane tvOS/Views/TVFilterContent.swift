//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVFilterContent: View {

    @ObservedObject
    var viewModel: FilterViewModel
    let type: ItemFilterType

    @Router
    private var router

    func selection(for group: ItemFilterType.Group) -> Binding<[AnyItemFilter]> {
        Binding {
            viewModel.currentFilters[keyPath: group.keyPath]
        } set: {
            group.setter($0, viewModel)
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Text(type.displayTitle)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(L10n.reset) { viewModel.reset(filterType: type) }
                .disabled(!viewModel.isFilterSelected(type: type))
            Button(L10n.done) { router.dismiss() }
        }
        .buttonStyle(TVSettingsButtonStyle())
        .padding(.horizontal, 22)
    }

    private func options(_ group: ItemFilterType.Group) -> some View {
        let source = viewModel.allFilters[keyPath: group.keyPath]
        return VStack(alignment: .leading, spacing: 20) {
            if type.group.count > 1 {
                Text(group.displayTitle.localizedUppercase)
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .padding(.horizontal, 22)
                    .accessibilityAddTraits(.isHeader)
            }
            if source.isEmpty {
                Text(L10n.none)
                    .font(.system(size: 22))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .padding(22)
            } else {
                TVOptionSelector(
                    selection: selection(for: group), sources: source, type: group.selectorType,
                    columnCount: type == .letter ? 7 : 3
                ) { Text($0.displayTitle) }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                header
                ForEach(Array(type.group.enumerated()), id: \.offset) { _, group in
                    options(group)
                }
            }
            .frame(maxWidth: 1280)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 90)
            .padding(.vertical, 60)
        }
        .background(AlphaneTheme.background.ignoresSafeArea())
        .navigationTitle(type.displayTitle)
        .toolbar(.hidden, for: .navigationBar)
        .onExitCommand { router.dismiss() }
    }
}
