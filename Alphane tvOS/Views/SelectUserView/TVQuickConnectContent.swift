//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct TVQuickConnectContent: View {

    private enum Action: Hashable {
        case retry
        case cancel
    }

    let code: String?
    let error: Error?
    let retry: () -> Void
    let dismiss: () -> Void

    @FocusState
    private var focusedAction: Action?

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            instruction(1, text: L10n.quickConnectStep1)
            instruction(2, text: L10n.quickConnectStep2)
        }
        .frame(width: 700)
    }

    private func instruction(_ number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(number.formatted())
                .font(.system(size: 18, weight: .medium))
                .frame(width: 28, height: 28)
                .background(AlphaneTheme.surface, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 22))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AlphaneTheme.secondaryText)
    }

    private var connectionCode: some View {
        VStack(spacing: 18) {
            Text(code ?? "000000")
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .tracking(10)
                .foregroundStyle(.white)
                .opacity(code == nil ? 0 : 1)
                .padding(.leading, 10)
                .frame(width: 430, height: 116)
                .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    if code == nil {
                        ProgressView().tint(.white)
                    }
                }
                .accessibilityLabel(L10n.quickConnectCode)
                .accessibilityValue(code ?? String(localized: "Loading"))
                .accessibilityIdentifier("quick-connect-code")

            HStack(spacing: 10) {
                if code != nil {
                    ProgressView()
                        .tint(AlphaneTheme.secondaryText)
                        .scaleEffect(0.6)
                        .frame(width: 20, height: 20)
                }
                Text(code == nil ? String(localized: "Getting your code…") : String(localized: "Waiting for approval"))
                    .font(.system(size: 18))
            }
            .foregroundStyle(AlphaneTheme.secondaryText)
            .frame(height: 24)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: error == nil ? "qrcode" : "exclamationmark.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .accessibilityHidden(true)
                    .padding(.bottom, 22)
                Text(L10n.quickConnect)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                if let error {
                    Text(ErrorView<ErrorMessage>.displayMessage(for: error))
                        .font(.system(size: 22))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 700)
                        .padding(.top, 34)
                        .accessibilityIdentifier("quick-connect-error")
                } else {
                    connectionCode.padding(.top, 34)
                    instructions.padding(.top, 42)
                }

                HStack(spacing: 24) {
                    if error != nil {
                        Button(L10n.retry, action: retry)
                            .focused($focusedAction, equals: .retry)
                            .accessibilityIdentifier("quick-connect-retry")
                    }
                    Button(L10n.cancel, action: dismiss)
                        .focused($focusedAction, equals: .cancel)
                        .accessibilityIdentifier("quick-connect-cancel")
                }
                .buttonStyle(TVSettingsButtonStyle())
                .padding(.top, 38)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 90)
        }
        .background(AlphaneTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(L10n.quickConnect)
        .defaultFocus($focusedAction, error == nil ? .cancel : .retry, priority: .userInitiated)
        .onChange(of: error != nil) { focusedAction = error == nil ? .cancel : .retry }
        .onExitCommand(perform: dismiss)
    }
}
