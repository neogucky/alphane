//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension ConnectToServerView {

    struct DuplicateServerConnectionView: View {

        @Environment(\.dismiss)
        private var dismiss

        @Namespace
        private var namespace

        let server: ServerState
        let action: () -> Void

        var body: some View {
            VStack(spacing: 8) {
                Text(L10n.connection)
                    .font(.title3)
                    .edgePadding(.bottom)

                Text(L10n.duplicateServerConnectionMessage(server.name))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .edgePadding(.bottom)

                VStack {
                    LabeledContent(
                        L10n.server,
                        value: server.name
                    )

                    LabeledContent(
                        L10n.url,
                        value: server.currentURL.absoluteString
                    )
                }

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        AlternateLayoutView {
                            Color.clear
                                .aspectRatio(3.5, contentMode: .fit)
                                .frame(height: 40)
                        } content: {
                            Text(L10n.close)
                        }
                    }

                    Button(action: action) {
                        AlternateLayoutView {
                            Color.clear
                                .aspectRatio(3.5, contentMode: .fit)
                                .frame(height: 40)
                        } content: {
                            Text(L10n.add)
                        }
                    }
                }
                .focusSection()
                .edgePadding(.top)
            }
            .frame(width: 500)
            .edgePadding()
        }
    }
}
