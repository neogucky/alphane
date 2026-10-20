//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

struct ConnectToServerView: View {

    var isOnboarding = false
    var onConnected: ((ServerState) -> Void)?

    @Default(.accentColor)
    private var accentColor

    @FocusState
    private var isURLFocused: Bool

    @Router
    private var router

    @State
    private var duplicateServer: ServerState? = nil

    @State
    private var url: String = ""

    @StateObject
    private var viewModel = ConnectToServerViewModel()

    private let timer = Timer.publish(every: 12, on: .main, in: .common).autoconnect()

    private func onEvent(_ event: ConnectToServerViewModel._Event) {
        switch event {
        case let .connected(server):

            Notifications[.didConnectToServer].post(server)
            if let onConnected {
                onConnected(server)
            } else {
                router.dismiss()
            }

        case let .duplicateServer(server):

            duplicateServer = server
        }
    }

    @ViewBuilder
    private var connectSection: some View {
        Section {
            TextField(L10n.serverAddress, text: $url)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .focused($isURLFocused)
        } header: {
            Text(L10n.connectToServer)
        } footer: {
            Text(L10n.serverAddressHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if viewModel.state == .connecting {
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
            .frame(maxHeight: 75)
        } else {
            Button {
                isURLFocused = false
                viewModel.connect(url: url)
            } label: {
                Text(L10n.connect)
                    .frame(maxWidth: .infinity)
            }
            .listRowInsets(.zero)
            .listRowBackground(Color.clear)
            .fontWeight(.semibold)
            .backport
            .buttonStyle(.glassProminent.shadow(false))
            .tint(accentColor)
            .frame(maxHeight: 75)
            .disabled(url.isEmpty)
        }
    }

    // MARK: - Local Servers Section

    @ViewBuilder
    private var localServersSection: some View {
        Section(L10n.localServers) {
            if viewModel.localServers.isEmpty {
                Text(L10n.noLocalServersFound)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.localServers) { server in
                    LocalServerButton(server: server) {
                        url = server.currentURL.absoluteString
                        viewModel.connect(url: server.currentURL.absoluteString)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        TVSetupContent(
            url: $url,
            isURLFocused: $isURLFocused,
            viewModel: viewModel,
            isOnboarding: isOnboarding
        )
    }

    // MARK: - Body

    var body: some View {
        contentView
            .navigationTitle(L10n.connect)
            .interactiveDismissDisabled(viewModel.state == .connecting)
            .onFirstAppear {
                isURLFocused = true
                viewModel.searchForServers()
            }
            .onReceive(timer) { _ in
                guard viewModel.state != .connecting else { return }

                viewModel.searchForServers()
            }
            .onReceive(viewModel.events, perform: onEvent)
            .onDisappear {
                if isOnboarding {
                    viewModel.cancel()
                }
            }
            .onReceive(viewModel.$error) { error in
                guard error != nil else { return }

                isURLFocused = true
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sheet(item: $duplicateServer) { server in
                DuplicateServerConnectionView(server: server) {
                    viewModel.addConnection(serverState: server)
                    duplicateServer = nil
                    if let onConnected {
                        onConnected(server)
                    } else {
                        router.dismiss()
                    }
                }
            }
            .errorMessage($viewModel.error)
    }
}
