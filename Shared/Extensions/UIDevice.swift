//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import UIKit

extension UIDevice {

    static var vendorUUIDString: String {
        current.identifierForVendor!.uuidString
    }

    static var isTV: Bool {
        current.userInterfaceIdiom == .tv
    }

    static let supportsLiquidGlass: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafeBytes(of: systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        /// Apple TV HD and Apple TV 4K (1st gen) run tvOS 26 without Liquid Glass
        /// - https://support.apple.com/en-us/106336
        /// - See tvOS 26, footnote 2
        return !["AppleTV5,3", "AppleTV6,2"].contains(model)
    }()

    static var platform: String {
        L10n.tvOS
    }
}
