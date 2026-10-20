//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

struct TVServerConnectionContent: View {

    private enum Element: Hashable {
        case connection(String)
        case moveUp(String)
        case moveDown(String)
        case add
        case edit
    }

    @Default(.Experimental.serverConnectionAutoSwitch)
    private var isAutoSwitchFeatureEnabled
    @ObservedObject
    var viewModel: ServerConnectionViewModel
    @Router
    private var router
    @Binding
    var editMode: EditMode
    @FocusState
    private var focusedElement: Element?

    private var isEditing: Bool {
        editMode.isEditing
    }

    private var initialFocus: Element {
        if isEditing {
            .edit
        } else if let connection = viewModel.activeConnection ?? viewModel.connections.first {
            .connection(connection.id)
        } else {
            .add
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.connections)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.server.name)
                    .font(.system(size: 20))
                    .foregroundStyle(AlphaneTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 24)
            Button(L10n.add, systemImage: "plus") {
                router.route(to: .editServerConnection(viewModel: viewModel, connection: viewModel.newConnection()))
            }
            .focused($focusedElement, equals: .add)
            .disabled(isEditing)
            .accessibilityIdentifier("connections-add")
            if viewModel.connections.count > 1 {
                Button(isEditing ? L10n.done : L10n.edit) { editMode = isEditing ? .inactive : .active }
                    .focused($focusedElement, equals: .edit)
                    .accessibilityIdentifier("connections-edit")
            }
        }
        .padding(.horizontal, 22)
    }

    private func connectionLabel(_ connection: ServerConnection) -> some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 9) {
                Text(connection.displayTitle)
                    .font(.system(size: 24, weight: .medium))
                    .lineLimit(2)
                Text(connection.url.absoluteString)
                    .font(.system(size: 20))
                    .lineLimit(2)
                    .truncationMode(.middle)
                if connection.interface == .wifi {
                    Label(connection.wifiSSIDs.first ?? L10n.anyWifiNetwork, systemImage: "wifi")
                        .font(.system(size: 18))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.activeConnection?.id == connection.id {
                Label(L10n.active, systemImage: "checkmark.circle")
                    .font(.system(size: 18))
            }
            if !isEditing {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func connectionRow(_ connection: ServerConnection, index: Int) -> some View {
        if isEditing {
            HStack(spacing: 18) {
                connectionLabel(connection)
                    .padding(.horizontal, 22)
                    .foregroundStyle(AlphaneTheme.secondaryText)
                Button {
                    viewModel.moveConnections(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .focused($focusedElement, equals: .moveUp(connection.id))
                .accessibilityLabel(String(localized: "Move \(connection.displayTitle) up"))
                .accessibilityIdentifier("connection-move-up-\(connection.id)")
                Button {
                    viewModel.moveConnections(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == viewModel.connections.count - 1)
                .focused($focusedElement, equals: .moveDown(connection.id))
                .accessibilityLabel(String(localized: "Move \(connection.displayTitle) down"))
                .accessibilityIdentifier("connection-move-down-\(connection.id)")
            }
            .padding(.trailing, 18)
            .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        } else {
            Button {
                router.route(to: .editServerConnection(viewModel: viewModel, connection: connection))
            } label: {
                connectionLabel(connection)
            }
            .focused($focusedElement, equals: .connection(connection.id))
            .accessibilityIdentifier("connection-\(connection.id)")
        }
    }

    private var automaticSwitching: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(L10n.autoSwitch, isOn: $viewModel.isAutoSwitchEnabled)
                .toggleStyle(TVPlaybackSettingsToggleStyle())
                .accessibilityIdentifier("connections-auto-switch")
            if viewModel.isAutoSwitchEnabled {
                Button {
                    Task { await viewModel.evaluateAutoSwitchConnection() }
                } label: {
                    HStack {
                        Text(L10n.evaluate)
                        Spacer()
                        if viewModel.isEvaluatingAutoSwitchConnection {
                            ProgressView().scaleEffect(0.65).frame(width: 24, height: 24)
                        }
                    }
                }
                .disabled(viewModel.isEvaluatingAutoSwitchConnection)
            }
            Text(String(localized: "Automatically chooses a connection using your network and the priority order above."))
                .font(.system(size: 20))
                .foregroundStyle(AlphaneTheme.secondaryText)
                .lineSpacing(5)
                .padding(.horizontal, 22)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(AlphaneTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .disabled(isEditing)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                VStack(spacing: 18) {
                    ForEach(Array(viewModel.connections.enumerated()), id: \.element.id) { index, connection in
                        connectionRow(connection, index: index)
                    }
                }
                .focusSection()
                if isAutoSwitchFeatureEnabled {
                    automaticSwitching
                }
            }
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 90)
            .padding(.vertical, 60)
        }
        .scrollClipDisabled()
        .buttonStyle(TVSettingsButtonStyle())
        .background(AlphaneTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(L10n.connections)
        .defaultFocus($focusedElement, initialFocus, priority: .userInitiated)
        .onChange(of: isEditing) { focusedElement = .edit }
        .onExitCommand {
            if isEditing {
                editMode = .inactive
            } else {
                router.dismiss()
            }
        }
    }
}
