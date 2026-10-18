//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct SliderContainer<Value: BinaryFloatingPoint>: View {

    struct SliderContainerState: Equatable {

        var isEditing = false
        var isFocused = false
    }

    @State
    private var containerState = SliderContainerState()

    @Binding
    private var value: Value
    private let total: Value
    private let isScrollingEnabled: Bool
    private let originProgress: Value?
    private var onEditingChanged: (Bool) -> Void

    init(
        value: Binding<Value>,
        total: Value = 1,
        isScrollingEnabled: Bool = true,
        originProgress: Value? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._value = value
        self.total = total.isFinite && total > 0 ? total : 1
        self.isScrollingEnabled = isScrollingEnabled
        self.originProgress = originProgress
        self.onEditingChanged = onEditingChanged
    }

    private var interaction: SliderInteractionModifier<Value> {
        SliderInteractionModifier(
            value: $value,
            total: total,
            isScrollingEnabled: isScrollingEnabled,
            onEditingChanged: setEditing,
            onFocusChanged: { containerState.isFocused = $0 }
        )
    }

    var body: some View {
        SliderContainerBody(configuration: .init(
            isEditing: containerState.isEditing,
            isFocused: containerState.isFocused,
            isScrollingEnabled: isScrollingEnabled,
            value: Double(value),
            originValue: originProgress.map { Double($0) },
            total: Double(total)
        ))
        .modifier(interaction)
        .onChange(of: isScrollingEnabled) {
            if !isScrollingEnabled {
                setEditing(false)
            }
        }
    }

    private func setEditing(_ isEditing: Bool) {
        guard containerState.isEditing != isEditing else { return }

        containerState.isEditing = isEditing
        onEditingChanged(isEditing)
    }
}

extension SliderContainer {

    func onEditingChanged(_ action: @escaping (Bool) -> Void) -> Self {
        copy(modifying: \.onEditingChanged, with: action)
    }
}
