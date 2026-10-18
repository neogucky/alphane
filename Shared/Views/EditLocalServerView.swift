//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct EditLocalServerView: View {

    @Router
    private var router

    @State
    private var isPresentingConfirmDeletion: Bool = false

    @StateObject
    private var viewModel: ServerConnectionViewModel

    private let isDeletePresented: Bool

    init(server: ServerState, isDeletePresented: Bool = false) {
        self._viewModel = StateObject(wrappedValue: ServerConnectionViewModel(server: server))
        self.isDeletePresented = isDeletePresented
    }

    var body: some View {
        content
            .alert(L10n.deleteServer, isPresented: $isPresentingConfirmDeletion) {
                Button(L10n.delete, role: .destructive) {
                    viewModel.delete()
                    router.dismiss()
                }
            } message: {
                Text(L10n.confirmDeleteServerAndUsers(viewModel.server.name))
            }
    }

    @ViewBuilder
    private var content: some View {
        #if os(tvOS)
        TVManagementPage(title: viewModel.server.name, width: 1080) {
            EmptyView()
        } content: {
            if let version = StoredValues[.Server.publicInfo(id: viewModel.server.id)].version {
                TVManagementNote(text: "\(L10n.version) \(version)")
            }
            Button {
                router.route(to: .serverConnections(viewModel: viewModel))
            } label: {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.connections).font(.system(size: 24, weight: .medium))
                        Text((viewModel.activeConnection?.url ?? viewModel.server.effectiveServerURL).absoluteString)
                            .font(.system(size: 20))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 16))
                }
                .padding(.vertical, 12)
            }
            if !viewModel.server.isVersionCompatible {
                TVManagementNote(text: L10n.serverVersionWarning(viewModel.server.client.version.majorMinor.description))
            }
            if isDeletePresented {
                HStack {
                    Spacer()
                    Button(L10n.deleteServer, role: .destructive) { isPresentingConfirmDeletion = true }
                }
                .padding(.top, 12)
            }
        }
        .onExitCommand { router.dismiss() }
        #else
        legacyContent
        #endif
    }

    private var legacyContent: some View {
        Form(systemImage: "server.rack") {

            Section(L10n.server) {

                LabeledContent(
                    L10n.name,
                    value: viewModel.server.name
                )
                #if os(tvOS)
                .focusable(false)
                #endif

                if let serverVersion = StoredValues[.Server.publicInfo(id: viewModel.server.id)].version {
                    LabeledContent(
                        L10n.version,
                        value: serverVersion
                    )
                    #if os(tvOS)
                    .focusable(false)
                    #endif
                }
            }

            Section {
                ChevronButton {
                    router.route(to: .serverConnections(viewModel: viewModel))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.connection)

                        Text((viewModel.activeConnection?.url ?? viewModel.server.effectiveServerURL).absoluteString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if !viewModel.server.isVersionCompatible {
                    Label(
                        L10n.serverVersionWarning(viewModel.server.client.version.majorMinor.description),
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }
            }

            if isDeletePresented {
                Section {
                    Button(L10n.delete, role: .destructive) {
                        isPresentingConfirmDeletion = true
                    }
                }
            }
        }
        .navigationTitle(L10n.server)
    }
}
