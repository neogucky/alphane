//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension Section where Parent == Text, Footer == Text, Content: View {

    init(
        _ header: String,
        footer: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(content: content) {
            Text(header)
        } footer: {
            Text(footer)
        }
    }
}

// MARK: - Section Overloads

func Section(
    _ title: String,
    @ViewBuilder content: @escaping () -> some View,
    @LabeledContentBuilder learnMore: @escaping () -> AnyView
) -> some View {
    Section(
        title,
        content: content,
        footer: { EmptyView() },
        learnMore: learnMore
    )
}

func Section(
    _ title: String,
    footer: String,
    @ViewBuilder content: @escaping () -> some View,
    @LabeledContentBuilder learnMore: @escaping () -> AnyView
) -> some View {
    Section(
        title,
        content: content,
        footer: { Text(footer) },
        learnMore: learnMore
    )
}

func Section(
    _ title: String,
    @ViewBuilder content: @escaping () -> some View,
    @ViewBuilder footer: @escaping () -> some View,
    @LabeledContentBuilder learnMore: @escaping () -> AnyView
) -> some View {
    Group {
        Section {
            content()
                .focusedValue(\.formLearnMore, learnMore())
        } header: {
            Text(title)
        } footer: {
            footer()
        }
    }
}
