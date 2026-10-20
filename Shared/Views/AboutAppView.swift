//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

struct AboutAppView: View {

    @Router
    private var router

    var body: some View {
        Form(image: .alphaneMark) {

            Section {
                #if DEBUG
                // swiftlint:disable:next hard_coded_display_string
                LabeledContent(
                    "Branch",
                    value: UIApplication.gitBranch ?? .emptyDash
                )
                #else
                LabeledContent(
                    L10n.version,
                    value: "\(UIApplication.appVersion ?? .emptyDash) (\(UIApplication.bundleVersion ?? .emptyDash))"
                )
                #endif

                ChevronButton(
                    L10n.settings,
                    systemName: "gearshape.fill",
                    external: true
                ) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }

                    UIApplication.shared.open(url)
                }
            }

            Section {

                // tvOS cannot open generic web links
            }
            Section {
                Text(L10n.upstreamAttribution)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.aboutApp)
    }
}
