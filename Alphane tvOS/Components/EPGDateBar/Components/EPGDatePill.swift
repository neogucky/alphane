//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension EPGDateBar {
    struct DatePill: View {
        let date: Date
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(.system(size: 22, weight: .medium))
                    .lineLimit(1)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.capsule(isSelectionActive: false))
        }
    }
}
