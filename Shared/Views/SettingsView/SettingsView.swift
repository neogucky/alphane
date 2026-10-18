//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

struct SettingsView: View {

    @Default(.userAccentColor)
    private var accentColor

    @InjectedObject(\.userSessionManager)
    private var userSessionManager: UserSessionManager

    @Router
    private var router

    // MARK: - Body

    var body: some View {
        TVSettingsView()
    }

    // MARK: - Server Section

    @ViewBuilder
    private var serverSection: some View {
        if let userSession = userSessionManager.currentSession {
            Section {
                UserProfileRow(user: userSession.user.data) {
                    router.route(to: .localUserSettings(user: userSession.user.data))
                }

                ChevronButton(
                    L10n.server,
                    action: {
                        router.route(to: .editLocalServer(server: userSession.server))
                    }
                ) {
                    Label {
                        Text(userSession.server.name)
                    } icon: {
                        if !userSession.server.isVersionCompatible {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                    }
                    .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }
            }
        }

        Section {
            Button {
                Task { @MainActor in

                    await userSessionManager.signOut(reason: .explicit)
                    router.dismiss()
                }
            } label: {
                Text(L10n.switchUser)
                    .frame(maxWidth: .infinity)
                    // Otherwise non-Liquid Glass only uses text height
                    .if(!UIDevice.supportsLiquidGlass) { button in
                        button
                            .frame(maxHeight: .infinity)
                    }
            }
            .listRowInsets(.zero)
            .listRowBackground(Color.clear)
            .fontWeight(.semibold)
            .backport
            .buttonStyle(.glassProminent.shadow(false))
            .tint(accentColor)
        }
    }

    // MARK: - Customization Section

    @ViewBuilder
    private var customizeSection: some View {
        Section {

            ColorPicker(L10n.accentColor, selection: $accentColor, supportsOpacity: false)

            ChevronButton(L10n.advanced) {
                router.route(to: .customizeSettingsView)
            }
        } header: {
            Text(L10n.customize)
        } footer: {
            Text(L10n.viewsMayRequireRestart)
        }
    }

    // MARK: - Diagnostics Section

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section {

            if ExperimentalSettingsView.isEnabled {
                ChevronButton(L10n.experimental) {
                    router.route(to: .experimentalSettings)
                }
            }

            ChevronButton(L10n.logs) {
                router.route(to: .log)
            }

            #if DEBUG
            ChevronButton("Debug") {
                router.route(to: .debugSettings)
            }
            #endif
        }
    }
}
