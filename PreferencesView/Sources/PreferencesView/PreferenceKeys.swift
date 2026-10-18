//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

#if os(tvOS)
struct PressCommandsPreferenceKey: PreferenceKey {

    static var defaultValue: [PressCommandAction] = []

    static func reduce(value: inout [PressCommandAction], nextValue: () -> [PressCommandAction]) {
        value.append(contentsOf: nextValue())
    }
}
#endif
