//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

extension ConnectToServerView {

    struct LocalServerButton: View {

        let server: ServerState
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Text(server.name).font(.system(size: 24, weight: .semibold))
                    Text(server.currentURL.absoluteString)
                        .font(.system(size: 18))
                        .opacity(0.8)
                }
                .frame(minWidth: 440)
            }
            .foregroundStyle(.primary, .secondary)
            .buttonStyle(.capsule)
            .controlSize(.large)
        }
    }
}
