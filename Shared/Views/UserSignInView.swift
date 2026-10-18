//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI

struct UserSignInView: View {

    @Environment(\.localUserAuthenticationAction)
    private var authenticationAction

    @Injected(\.userSessionManager)
    private var userSessionManager: UserSessionManager

    @Router
    private var router

    @State
    private var accessPolicy: LocalUserAccessPolicy = .none
    @State
    private var password: String = ""
    @State
    private var pinHint: String = ""
    @State
    private var username: String = ""

    @StateObject
    private var viewModel: UserSignInViewModel

    init(server: ServerState, profile: UserSignInProfile? = nil) {
        self._username = State(initialValue: profile?.username ?? "")
        self._viewModel = StateObject(wrappedValue: UserSignInViewModel(server: server, profile: profile))
    }

    private func handleEvent(_ event: UserSignInViewModel._Event) {
        switch event {
        case let .connected(user):
            guard let authenticationAction else { return }

            viewModel.save(
                user: user,
                authenticationAction: (
                    authenticationAction,
                    accessPolicy,
                    accessPolicy.createReason(
                        user: user.state.state
                    )
                ),
                evaluatedPolicyMap: .init(action: processEvaluatedPolicy)
            )

        case let .existingUser(existingUser):
            guard let authenticationAction else { return }

            let user = existingUser.state.state
            viewModel.saveExisting(
                user: existingUser,
                replaceForAccessToken: true,
                authenticationAction: (authenticationAction, user.accessPolicy, user.accessPolicy.authenticateReason(user: user)),
                evaluatedPolicyMap: .init(action: processEvaluatedPolicy)
            )

        case let .saved(user):
            Task { @MainActor in
                do {
                    try await userSessionManager.signIn(userID: user.id)

                    router.dismiss()
                } catch {
                    await viewModel.error(error)
                }
            }
        }
    }

    private func signIn() {
        viewModel.signIn(username: username, password: password)
    }

    private func quickConnect() {
        router.route(to: .quickConnect(client: viewModel.server.client) { secret in
            await viewModel.signInQuickConnect(secret: secret)
        })
    }

    private func processEvaluatedPolicy(
        _ evaluatedPolicy: any EvaluatedLocalUserAccessPolicy
    ) -> any EvaluatedLocalUserAccessPolicy {
        if let pinPolicy = evaluatedPolicy as? PinEvaluatedUserAccessPolicy {
            return PinEvaluatedUserAccessPolicy(
                pin: pinPolicy.pin,
                pinHint: pinHint
            )
        }

        return evaluatedPolicy
    }

    @ViewBuilder
    private var contentView: some View {
        TVSignInContent(
            username: $username,
            password: $password,
            viewModel: viewModel,
            signIn: signIn,
            quickConnect: quickConnect,
            dismiss: { router.dismiss() }
        )
    }

    // MARK: - Body

    var body: some View {
        contentView
            .navigationTitle(L10n.signIn.localizedCapitalized)
            .interactiveDismissDisabled(viewModel.state == .signingIn)
            .onReceive(viewModel.events, perform: handleEvent)
            .onFirstAppear {
                viewModel.getPublicData()
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}
