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

    private enum Field: Hashable {
        case username
        case password
    }

    @Environment(\.localUserAuthenticationAction)
    private var authenticationAction

    @Injected(\.userSessionManager)
    private var userSessionManager: UserSessionManager

    @FocusState
    private var focusedTextField: Field?

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
                    UIDevice.feedback(.success)
                    router.dismiss()
                } catch {
                    await viewModel.error(error)
                }
            }
        }
    }

    private func signIn() {
        focusedTextField = nil
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
    private func disclaimerText(_ disclaimer: String) -> some View {
        if let attributedString = try? AttributedString(
            markdown: disclaimer,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributedString)
        } else {
            Text(disclaimer)
        }
    }

    // MARK: - Sign In Section

    @ViewBuilder
    private var signInSection: some View {
        Section {
            if let profile = viewModel.profile {
                HStack(spacing: 16) {
                    UserProfileImage(userID: profile.id, source: profile.user.profileImageSource(client: viewModel.server.client))
                        .frame(width: 60, height: 60)
                    Text(profile.username)
                }
            } else {
                TextField(L10n.username, text: $username)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .focused($focusedTextField, equals: .username)
                    .onSubmit {
                        focusedTextField = .password
                    }
            }

            SecureField(
                L10n.password,
                text: $password,
                maskToggle: .enabled
            ) {
                signIn()
            }
            .autocorrectionDisabled()
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .focused($focusedTextField, equals: .password)
        } header: {
            Text(L10n.signInToServer(viewModel.server.name))
        } footer: {
            switch accessPolicy {
            case .requireDeviceAuthentication:
                Label(L10n.userDeviceAuthRequiredDescription, systemImage: "exclamationmark.circle.fill")
                    .labelStyle(.sectionFooterWithImage(imageStyle: .orange))

            case .requirePin:
                Label(L10n.userPinRequiredDescription, systemImage: "exclamationmark.circle.fill")
                    .labelStyle(.sectionFooterWithImage(imageStyle: .orange))

            case .none:
                EmptyView()
            }
        }

        if case .signingIn = viewModel.state {
            Button(role: .cancel) {
                viewModel.cancel()
            } label: {
                Text(L10n.cancel)
                    .frame(maxWidth: .infinity)
            }
            .listRowInsets(.zero)
            .listRowBackground(Color.clear)
            .fontWeight(.semibold)
            .backport
            .buttonStyle(.glassProminent.shadow(false))
            #if os(iOS)
            .controlSize(.large)
            #endif
            #if os(iOS)
            .listRowSeparator(.hidden)
            #endif
            .frame(maxHeight: 75)
        } else {
            Button(action: signIn) {
                Text(L10n.signIn)
                    .frame(maxWidth: .infinity)
            }
            .listRowInsets(.zero)
            .listRowBackground(Color.clear)
            .fontWeight(.semibold)
            .backport
            .buttonStyle(.glassProminent.shadow(false))
            .tint(.jellyfinPurple)
            #if os(iOS)
            .controlSize(.large)
            .listRowSeparator(.hidden)
            #endif
            .frame(maxHeight: 75)
            .disabled(username.isEmpty)
        }

        if viewModel.isQuickConnectEnabled {
            Section {
                Button(action: quickConnect) {
                    Text(L10n.quickConnect)
                        .frame(maxWidth: .infinity)
                }
                .listRowInsets(.zero)
                .listRowBackground(Color.clear)
                .fontWeight(.semibold)
                .backport
                .buttonStyle(.glassProminent.shadow(false))
                .tint(.jellyfinPurple)
                #if os(iOS)
                .controlSize(.large)
                #endif
                #if os(iOS)
                .listRowSeparator(.hidden)
                #endif
                .disabled(viewModel.state == .signingIn)
            }
        }

        if let disclaimer = viewModel.serverDisclaimer {
            Section(L10n.disclaimer) {
                disclaimerText(disclaimer)
                    .font(.callout)
            }
        }
    }

    // MARK: - Public Users Section

    @ViewBuilder
    private var publicUsersSection: some View {
        Section(L10n.publicUsers) {
            if viewModel.publicUsers.isEmpty {
                Text(L10n.noPublicUsers)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                #if os(iOS)
                ForEach(viewModel.publicUsers) { user in
                    ChevronButton {
                        username = user.name ?? ""
                        password = ""
                        focusedTextField = .password
                    } label: {
                        HStack {
                            UserProfileImage(
                                userID: user.id,
                                source: user.profileImageSource(
                                    client: viewModel.server.client,
                                    maxWidth: 50
                                )
                            )
                            .frame(width: 50, height: 50)

                            Text(user.name ?? .emptyDash)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                }
                #else
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: EdgeInsets.itemSpacing),
                        count: 4
                    ),
                    spacing: EdgeInsets.itemSpacing
                ) {
                    ForEach(viewModel.publicUsers) { user in
                        UserButton(
                            user: user,
                            client: viewModel.server.client
                        ) {
                            username = user.name ?? ""
                            password = ""
                            focusedTextField = .password
                        }
                        .withViewContext(.isOverComplexContent)
                    }
                }
                #endif
            }
        }
        .disabled(viewModel.state == .signingIn)
    }

    @ViewBuilder
    private var contentView: some View {
        #if os(iOS)
        List {
            signInSection
            if viewModel.profile == nil {
                publicUsersSection
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .navigationBarCloseButton(disabled: viewModel.state == .signingIn) {
            router.dismiss()
        }
        .topBarTrailing {
            if viewModel.state == .signingIn || viewModel.background.is(.gettingPublicData) {
                ProgressView()
            }

            Button(L10n.security, systemImage: "gearshape.fill") {
                router.route(
                    to: .userSecurity(
                        pinHint: $pinHint,
                        accessPolicy: $accessPolicy
                    )
                )
            }
        }
        #else
        TVSignInContent(
            username: $username,
            password: $password,
            viewModel: viewModel,
            signIn: signIn,
            quickConnect: quickConnect,
            dismiss: { router.dismiss() }
        )
        #endif
    }

    // MARK: - Body

    var body: some View {
        contentView
            .navigationTitle(L10n.signIn.localizedCapitalized)
            .interactiveDismissDisabled(viewModel.state == .signingIn)
            .onReceive(viewModel.events, perform: handleEvent)
            .onFirstAppear {
                #if os(iOS)
                focusedTextField = username.isEmpty ? .username : .password
                #endif
                viewModel.getPublicData()
            }
        #if os(tvOS)
            .toolbar(.hidden, for: .navigationBar)
        #else
            .errorMessage($viewModel.error)
        #endif
    }
}
