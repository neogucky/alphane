//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension UserSignInView {

    struct TVSignInContent: View {

        enum Element: Hashable {
            case username
            case password
            case visibility
            case signIn
            case quickConnect
            case back
        }

        @Binding
        var username: String
        @Binding
        var password: String
        @ObservedObject
        var viewModel: UserSignInViewModel
        let signIn: () -> Void
        let quickConnect: () -> Void
        let dismiss: () -> Void

        @FocusState
        private var focusedElement: Element?
        @State
        private var isPasswordVisible = false
        @State
        private var editingElement: Element?

        private var isSigningIn: Bool {
            viewModel.state == .signingIn
        }

        private var initialFocus: Element {
            viewModel.profile == nil ? .username : .password
        }

        private var canSignIn: Bool {
            !(viewModel.profile?.username ?? username).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        static func displayError(_ error: Error?, selectedProfile: Bool) -> String? {
            guard let error, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return nil }

            if AuthenticationFailure.isUnauthorized(error) {
                return selectedProfile
                    ? String(localized: "Check your password and try again.")
                    : String(localized: "Check your username and password and try again.")
            }
            return ErrorView<ErrorMessage>.displayMessage(for: error)
        }

        private var errorMessage: String? {
            Self.displayError(viewModel.error, selectedProfile: viewModel.profile != nil)
        }

        private func submit() {
            guard !isSigningIn, canSignIn else { return }

            focusedElement = .signIn
            signIn()
        }

        private func cancel() {
            viewModel.cancel()
            focusedElement = initialFocus
        }

        private func avatar(_ profile: UserSignInProfile) -> some View {
            let fallback = Text(profile.username.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased())
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(AlphaneTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AlphaneTheme.surface)

            return ImageView(profile.user.profileImageSource(client: viewModel.server.client, maxWidth: 240))
                .pipeline(.Alphane.local)
                .image { image in image.aspectRatio(contentMode: .fill) }
                .placeholder { _ in fallback }
                .failure { fallback }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }

        private var identity: some View {
            VStack(spacing: 20) {
                if let profile = viewModel.profile {
                    avatar(profile)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 38))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                        .frame(width: 96, height: 96)
                        .background(AlphaneTheme.surface, in: Circle())
                        .accessibilityHidden(true)
                }

                VStack(spacing: 9) {
                    Text(viewModel.profile?.username ?? L10n.signIn)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("sign-in-profile-name")
                    Text(viewModel.server.name)
                        .font(.system(size: 20))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }

        private func field(_ title: String, focused: Bool, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 19))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .padding(.leading, 4)
                    .accessibilityHidden(true)
                content()
                    .textFieldStyle(.plain)
                    .font(.system(size: 24))
                    .foregroundStyle(focused ? .white : AlphaneTheme.secondaryText)
                    .tint(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 72)
                    .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .tvFocusBorder(isFocused: focused && !isSigningIn, shape: RoundedRectangle(cornerRadius: 16), lineWidth: 4)
                    .disabled(isSigningIn)
            }
        }

        private func credentialInput(
            _ title: String, text: Binding<String>, secure: Bool, element: Element, submit: @escaping () -> Void
        ) -> some View {
            let value = text.wrappedValue
            return Button { editingElement = element } label: {
                Text(value.isEmpty ? title : (secure ? String(repeating: "•", count: value.count) : value))
                    .font(.system(size: 24))
                    .tracking(secure && !value.isEmpty ? 4 : 0)
                    .foregroundStyle(value.isEmpty || focusedElement != element ? AlphaneTheme.secondaryText : .white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background(AlphaneTheme.surface)
            }
            .buttonStyle(ArtworkButtonStyle())
            .focused($focusedElement, equals: element)
            .accessibilityLabel(title)
            .accessibilityValue(secure && !value.isEmpty ? String(localized: "\(value.count) characters") : value)
            .accessibilityIdentifier(element == .username ? "sign-in-username" : "sign-in-password")
            .background {
                TVSignInKeyboard(
                    text: text,
                    isPresented: Binding(
                        get: { editingElement == element },
                        set: { presented in
                            if presented {
                                editingElement = element
                            } else if editingElement == element {
                                editingElement = nil
                            }
                        }
                    ),
                    title: title, secure: secure, password: element == .password, submit: submit
                )
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        }

        private var credentials: some View {
            VStack(spacing: 26) {
                if viewModel.profile == nil {
                    field(L10n.username, focused: focusedElement == .username) {
                        credentialInput(
                            L10n.username, text: $username, secure: false, element: .username,
                            submit: { focusedElement = .password }
                        )
                    }
                }

                field(L10n.password, focused: focusedElement == .password) {
                    HStack(spacing: 18) {
                        Image(systemName: "lock")
                            .font(.system(size: 21))
                            .accessibilityHidden(true)
                        credentialInput(
                            L10n.password, text: $password, secure: !isPasswordVisible,
                            element: .password, submit: submit
                        )

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .frame(width: 24)
                        }
                        .buttonStyle(TVSettingsButtonStyle())
                        .focused($focusedElement, equals: .visibility)
                        .accessibilityLabel(isPasswordVisible ? String(localized: "Hide password") : String(localized: "Show password"))
                        .accessibilityIdentifier("sign-in-password-visibility")
                    }
                }
            }
        }

        private var actions: some View {
            HStack(spacing: 24) {
                Button {
                    if isSigningIn {
                        cancel()
                    } else {
                        submit()
                    }
                } label: {
                    HStack(spacing: 12) {
                        if isSigningIn {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(focusedElement == .signIn ? .black : .white)
                                .frame(width: 24, height: 24)
                        }
                        Text(isSigningIn ? L10n.cancel : L10n.signIn)
                    }
                    .frame(width: 180)
                }
                .focused($focusedElement, equals: .signIn)
                .disabled(!isSigningIn && !canSignIn)
                .accessibilityIdentifier("sign-in-submit")

                if viewModel.isQuickConnectEnabled {
                    Button(action: quickConnect) {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 21))
                            Text(L10n.quickConnect)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: 180)
                    }
                    .focused($focusedElement, equals: .quickConnect)
                    .disabled(isSigningIn)
                    .accessibilityIdentifier("sign-in-quick-connect")
                }
            }
            .buttonStyle(TVSettingsButtonStyle())
            .focusSection()
        }

        private var cornerControls: some View {
            HStack {
                Button(L10n.profiles, systemImage: "chevron.left", action: dismiss)
                    .buttonStyle(TVSettingsButtonStyle())
                    .focused($focusedElement, equals: .back)
                    .disabled(isSigningIn)
                    .accessibilityIdentifier("sign-in-back")
                Spacer()
                Text(verbatim: "ALPHANE")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
        }

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    AlphaneTheme.background.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 0) {
                            identity
                                .padding(.bottom, viewModel.profile == nil ? 38 : 46)
                            credentials
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 18))
                                    .foregroundStyle(AlphaneTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 16)
                                    .accessibilityIdentifier("sign-in-error")
                            }
                            actions.padding(.top, errorMessage == nil ? 40 : 20)
                            if let disclaimer = viewModel.serverDisclaimer {
                                Text((try? AttributedString(
                                    markdown: disclaimer,
                                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                                )) ?? AttributedString(disclaimer))
                                    .font(.system(size: 18))
                                    .foregroundStyle(AlphaneTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .focusable()
                                    .padding(.top, 28)
                            }
                        }
                        .frame(width: 600)
                        .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 144, 0))
                        .padding(.vertical, 72)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    cornerControls
                }
            }
            .ignoresSafeArea()
            .defaultFocus($focusedElement, initialFocus, priority: .userInitiated)
            .onFirstAppear { focusedElement = initialFocus }
            .onChange(of: viewModel.error?.localizedDescription) {
                if errorMessage != nil {
                    focusedElement = canSignIn ? .password : .username
                }
            }
            .onChange(of: username) { viewModel.error = nil }
            .onChange(of: password) { viewModel.error = nil }
            .onExitCommand {
                if editingElement != nil {
                    editingElement = nil
                } else if isSigningIn {
                    cancel()
                } else {
                    dismiss()
                }
            }
        }
    }
}
