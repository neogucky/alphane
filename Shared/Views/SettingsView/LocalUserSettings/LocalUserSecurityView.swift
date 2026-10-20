//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// TODO: present toast when authentication successfully changed

struct LocalUserSecurityView: View {

    @Environment(\.localUserAuthenticationAction)
    private var authenticationAction

    @Router
    private var router

    @State
    private var error: Error? = nil

    @State
    private var pinHint: String = ""

    @State
    private var signInPolicy: LocalUserAccessPolicy = .none

    @StateObject
    private var viewModel = LocalUserSecurityViewModel()

    @MainActor
    private func performSaveSecurityPolicy() async {
        guard let authenticationAction else {
            return
        }

        do {
            let user = try viewModel.requireUserSession().user
            let oldPolicy = user.accessPolicy

            let oldEvaluatedPolicy = try await authenticationAction(
                policy: oldPolicy,
                reason: oldPolicy.authenticateReason(user: user)
            )

            if let oldPinPolicy = oldEvaluatedPolicy as? PinEvaluatedUserAccessPolicy {
                try viewModel.check(oldPin: oldPinPolicy.pin)
            }

            let newEvaluatedPolicy = try await authenticationAction(
                policy: signInPolicy,
                reason: signInPolicy.createReason(user: user)
            )

            try viewModel.set(
                newPolicy: signInPolicy,
                newPin: (newEvaluatedPolicy as? PinEvaluatedUserAccessPolicy)?.pin ?? "",
                newPinHint: signInPolicy == .requirePin ? pinHint : ""
            )
            router.dismiss()
        } catch is CancellationError {
            return
        } catch {

            self.error = error
        }
    }

    var body: some View {
        TVSettingsPage(title: "Profile PIN") {
            VStack(alignment: .leading, spacing: 22) {
                Button {
                    signInPolicy = signInPolicy == .requirePin ? .none : .requirePin
                } label: {
                    TVSettingsRow(
                        title: "Require PIN",
                        value: signInPolicy == .requirePin ? TVSettingsText.on : TVSettingsText.off,
                        symbol: nil
                    )
                }

                if signInPolicy == .requirePin {
                    hintControl
                }

                Text(L10n.additionalSecurityAccessDescription)
                    .font(.system(size: 20))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)

                HStack(spacing: 22) {
                    Button(L10n.cancel) { router.dismiss() }
                    if let user = viewModel.userSession?.user {
                        let isChangingPIN = signInPolicy == .requirePin && signInPolicy == user.accessPolicy
                        Button(isChangingPIN ? L10n.changePin : L10n.save) {
                            Task { @MainActor in
                                await performSaveSecurityPolicy()
                            }
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: 700)
        }
        .animation(.linear, value: signInPolicy)
        .navigationTitle(L10n.security)
        .onFirstAppear {
            guard let user = viewModel.userSession?.user else { return }

            signInPolicy = user.accessPolicy
            pinHint = user.pinHint
        }
        .errorMessage($error)
    }

    @ViewBuilder
    private var hintControl: some View {
        StateAdapter(initialValue: (isPresented: false, hint: pinHint)) { alert in
            ChevronButton(L10n.hint, content: pinHint) {
                alert.isPresented.wrappedValue = true
            }
            .alert(L10n.hint, isPresented: alert.isPresented) {
                TextField(L10n.hint, text: alert.hint)

                Button(L10n.save) {
                    pinHint = alert.hint.wrappedValue
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.setPinHintDescription)
            }
        }
    }
}
