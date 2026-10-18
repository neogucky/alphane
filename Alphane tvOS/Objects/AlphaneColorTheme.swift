//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

/// Neutral is a semantic mode, independent of a custom colour that happens to be white.
enum AlphaneColorTheme: String, CaseIterable, Defaults.Serializable {
    case noAccent
    case cold
    case warm
    case custom

    static let presets: [Self] = [.noAccent, .cold, .warm]

    var title: String {
        switch self {
        case .noAccent: String(localized: "No accent")
        case .cold: String(localized: "Cold")
        case .warm: String(localized: "Warm")
        case .custom: String(localized: "Custom colour")
        }
    }

    func color(custom: Color) -> Color {
        switch self {
        case .noAccent: .white
        case .cold: AlphaneTheme.accent
        case .warm: Color(hex: "E1B471")
        case .custom: custom
        }
    }

    /// Existing preferences keep their colour. In particular, legacy white
    /// remains Custom until the user explicitly opts into the neutral treatment.
    static func resolved(stored: Self?, custom: Color) -> Self {
        if let stored {
            return stored
        }
        // UIKit stores floating-point components; quantize by rounding so a
        // one-bit representation error does not misidentify an existing preset.
        let rgba = custom.rgbaComponents
        let bytes = (
            Int((rgba.red * 255).rounded()),
            Int((rgba.green * 255).rounded()),
            Int((rgba.blue * 255).rounded()),
            Int((rgba.alpha * 255).rounded())
        )
        switch bytes {
        case (106, 214, 202, 255): return .cold
        case (225, 180, 113, 255): return .warm
        default: return .custom
        }
    }
}

extension Defaults.Keys {
    static let colorTheme = Key<AlphaneColorTheme>("currentColorTheme", default: .cold, suite: .appSuite)
    static var userColorTheme: Key<AlphaneColorTheme?> {
        Key("userColorTheme", default: nil, suite: .currentUserSuite)
    }
}
