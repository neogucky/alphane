//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import SwiftUI

struct UserSessionRootView: View {

    @Environment(\.localUserAuthenticationAction)
    private var authenticationAction

    @InjectedObject(\.userSessionManager)
    private var userSessionManager

    #if os(tvOS)
    @StateObject
    private var onboarding = TVOnboardingModel()
    #endif

    @ViewBuilder
    private var sessionContent: some View {
        switch userSessionManager.state {
        case .initial:
            ProgressView()

        case .signedOut:
            NavigationInjectionView(coordinator: .init()) {
                SelectUserView()
            }

        case .signedIn:
            PosterPreferencesEnvironment {
                MainTabView()
            }
            // A real session replacement resets retained collections, even for the same user ID.
            .id(userSessionManager.currentSession.map { ObjectIdentifier($0) })
        }
    }

    var body: some View {
        ZStack {
            #if os(tvOS)
            if userSessionManager.state != .initial, onboarding.step != .complete {
                NavigationInjectionView(coordinator: .init()) {
                    TVOnboardingView(model: onboarding)
                }
            } else {
                sessionContent
            }
            #else
            sessionContent
            #endif
        }
        .animation(.linear(duration: 0.1), value: userSessionManager.state)
        .task {
            await userSessionManager.start()
            #if os(tvOS)
            finishSetupIfSignedIn()
            #endif
        }
        #if os(tvOS)
        .onChange(of: userSessionManager.currentSession.map { ObjectIdentifier($0) }) {
            finishSetupIfSignedIn()
        }
        .onChange(of: onboarding.step) { finishSetupIfSignedIn() }
        #endif
        .onOpenURL { url in
            guard let authenticationAction else { return }

            Task {
                await userSessionManager.handleOpenURL(
                    url,
                    authenticationAction: authenticationAction
                )
            }
        }
    }

    #if os(tvOS)
    private func finishSetupIfSignedIn() {
        if let user = userSessionManager.currentSession?.user {
            onboarding.finish(user: user)
        }
    }
    #endif
}

private struct PosterPreferencesEnvironment<Content: View>: View {

    @Default(.Customization.Poster.configuration)
    private var posterConfiguration

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.posterConfiguration, posterConfiguration)
    }
}
