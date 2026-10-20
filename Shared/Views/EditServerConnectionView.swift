//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct EditServerConnectionView: View {

    @FocusState
    private var isNameFocused: Bool

    @ObservedObject
    var viewModel: ServerConnectionViewModel

    @Router
    private var router

    @State
    private var draft: ServerConnectionDraft
    @State
    private var saveError: String?

    private let initialConnection: ServerConnection
    private let initialDraft: ServerConnectionDraft

    private var existingConnection: ServerConnection? {
        viewModel.connections.first { $0.id == initialConnection.id }
    }

    private var connection: ServerConnection {
        existingConnection ?? initialConnection
    }

    private var isExistingConnection: Bool {
        existingConnection != nil
    }

    private var testState: ServerConnection.TestState {
        viewModel.testStates[initialConnection.id] ?? .idle
    }

    private var isTesting: Bool {
        if case .testing = testState {
            true
        } else {
            false
        }
    }

    private var isCurrentConnection: Bool {
        viewModel.activeConnection?.id == initialConnection.id
    }

    private var hasChanges: Bool {
        draft != initialDraft
    }

    private var isNameEmpty: Bool {
        draft.name.nilIfBlank == nil
    }

    private var isDuplicateConnection: Bool {
        guard let connection = try? draft.connection() else { return false }

        return ServerConnection.isDuplicate(connection, in: viewModel.connections)
    }

    private var isSaveDisabled: Bool {
        isTesting || !hasChanges || isNameEmpty || isDuplicateConnection
    }

    private var firstWifiSSID: Binding<String> {
        $draft.map(
            getter: { $0.wifiSSIDs.first ?? .empty },
            setter: { wifiSSID in
                var updatedDraft = draft

                if updatedDraft.wifiSSIDs.isEmpty {
                    updatedDraft.wifiSSIDs = [wifiSSID]
                } else {
                    updatedDraft.wifiSSIDs[0] = wifiSSID
                }

                return updatedDraft
            }
        )
    }

    init(
        viewModel: ServerConnectionViewModel,
        connection: ServerConnection
    ) {
        self.viewModel = viewModel
        self.initialConnection = connection
        self.initialDraft = ServerConnectionDraft(connection: connection)

        self._draft = State(initialValue: ServerConnectionDraft(connection: connection))
    }

    private func save() async throws {
        guard !isNameEmpty else {
            throw ErrorMessage(L10n.invalidName)
        }

        let connection = try draft.connection()

        guard !isDuplicateConnection else {
            throw ErrorMessage(L10n.connectionAlreadyExists)
        }

        let state = await viewModel.saveConnection(connection)
        guard case .success = state else { return }

        router.dismiss()
    }

    private func testDraft() {
        guard let draftConnection = try? draft.connection() else { return }

        test(draftConnection)
    }

    private func populateCurrentWifiSSID(keepSpecificOnFailure: Bool) {}

    private func test(_ connection: ServerConnection) {
        Task {
            _ = await viewModel.testConnection(connection)
        }
    }

    var body: some View {
        tvOSContent
    }

    #if os(tvOS)
    private var tvOSContent: some View {
        TVManagementPage(title: L10n.connection, width: 1080) {
            Button(L10n.cancel) { router.dismiss() }
            Button(L10n.save) {
                Task {
                    do { try await save() }
                    catch { saveError = error.localizedDescription }
                }
            }
            .disabled(isSaveDisabled || (try? draft.connection()) == nil)
        } content: {
            VStack(spacing: 24) {
                TVManagementField(title: L10n.name, text: $draft.name)
                    .focused($isNameFocused)
                TVManagementField(title: L10n.url, text: $draft.urlString, isURL: true)
            }
            .disabled(isTesting)
            if isNameEmpty {
                TVManagementNote(text: L10n.required)
            }
            if isDuplicateConnection {
                TVManagementNote(text: L10n.connectionAlreadyExists)
            }
            if (try? draft.connection()) == nil, !isNameEmpty {
                TVManagementNote(text: L10n.invalidURL)
            }
            HStack(spacing: 28) {
                Button(action: testDraft) {
                    HStack(spacing: 12) {
                        Text(L10n.test)
                        if isTesting {
                            ProgressView().scaleEffect(0.65).frame(width: 24, height: 24)
                        }
                    }
                }
                .disabled(isTesting || (try? draft.connection()) == nil)
                if isCurrentConnection {
                    Label(L10n.active, systemImage: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AlphaneTheme.secondaryText)
                } else if isExistingConnection {
                    Button(L10n.use) {
                        Task { await viewModel.setActiveConnectionIfValid(connection) }
                    }
                    .disabled(isTesting || hasChanges)
                }
                Spacer()
                if isExistingConnection {
                    Button(L10n.delete, role: .destructive) {
                        viewModel.deleteConnection(connection)
                        router.dismiss()
                    }
                    .disabled(isTesting || viewModel.connections.count <= 1 || isCurrentConnection)
                }
            }
            if case .success = testState {
                TVManagementNote(text: L10n.success)
            }
            if case let .failure(message) = testState {
                TVManagementNote(text: message.nilIfBlank ?? L10n.connectionFailed)
            }
            if let saveError {
                TVManagementNote(text: saveError)
            }
        }
        .defaultFocus($isNameFocused, true, priority: .userInitiated)
        .onExitCommand { router.dismiss() }
    }
    #endif

    private var legacyContent: some View {
        Form(systemImage: "network") {
            Section {
                TextField(L10n.name, text: $draft.name)
                    .focused($isNameFocused)
            } header: {
                Text(L10n.name)
            } footer: {
                if isNameEmpty {
                    Label(L10n.required, systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }
            }

            Section {
                TextField(L10n.url, text: $draft.urlString)
            } header: {
                Text(L10n.url)
            } footer: {
                if isDuplicateConnection {
                    Label(L10n.connectionAlreadyExists, systemImage: "exclamationmark.circle.fill")
                        .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }
            }

            Section(L10n.status) {
                if isCurrentConnection {
                    Label(L10n.active, systemImage: "circle.fill")
                        .foregroundStyle(.green)
                } else if isExistingConnection {
                    Button(L10n.use) {
                        Task {
                            await viewModel.setActiveConnectionIfValid(connection)
                        }
                    }
                    .disabled(isTesting || hasChanges)
                }

                Button(action: testDraft) {
                    LabeledContent {
                        switch testState {
                        case .idle, .failure:
                            EmptyView()
                        case .testing:
                            ProgressView()
                        case .success:
                            Image(systemName: "circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } label: {
                        Text(L10n.test)
                    }
                }
                .disabled(isTesting)

                if case let .failure(message) = testState {
                    Text(message.nilIfBlank ?? L10n.connectionFailed)
                        .foregroundStyle(.red)
                }
            }

            if isExistingConnection {
                Button(L10n.delete, role: .destructive) {
                    viewModel.deleteConnection(connection)
                    router.dismiss()
                }
                .disabled(viewModel.connections.count <= 1 || isCurrentConnection)
            }
        }
        .navigationTitle(L10n.connection)
        .navigationBarCloseButton {
            router.dismiss()
        }
        .topBarTrailing {
            let saveAction: () -> Void = {
                Task { try? await save() }
            }

            Group {
                Button(L10n.save, action: saveAction)
            }
            .disabled(isSaveDisabled)
        }
        .animation(.linear(duration: 0.1), value: draft.interface)
        .animation(.linear(duration: 0.1), value: draft.useWifiName)
        .onFirstAppear {
            isNameFocused = true
        }
    }
}

private struct ServerConnectionDraft: Equatable {
    let id: String
    var name: String
    var urlString: String
    var interface: ServerConnection.Interface
    var wifiSSIDs: [String]
    var priority: Int
    var useWifiName: Bool

    init(connection: ServerConnection) {
        self.id = connection.id
        self.name = connection.name
        self.urlString = connection.url.absoluteString
        self.interface = connection.interface
        self.wifiSSIDs = connection.wifiSSIDs
        self.priority = connection.priority
        self.useWifiName = connection.interface == .wifi && connection.wifiSSIDs.isNotEmpty
    }

    var url: URL? {
        let resolvedURLString = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prepending("http://", if: !urlString.contains("://"))

        return URL(string: resolvedURLString)?.normalizedServerConnectionURL
    }

    func connection() throws -> ServerConnection {
        guard let url, url.host != nil else {
            throw ErrorMessage(L10n.invalidURL)
        }

        let normalizedSSIDs = Self.normalizeSSIDs(wifiSSIDs)

        if interface == .wifi,
           useWifiName,
           normalizedSSIDs.isEmpty
        {
            throw ErrorMessage(L10n.invalidWifiName)
        }

        return ServerConnection(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            interface: interface,
            wifiSSIDs: interface == .wifi && useWifiName ? normalizedSSIDs : [],
            priority: priority
        )
    }

    private static func normalizeSSIDs(_ wifiSSIDs: [String]) -> [String] {
        wifiSSIDs
            .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank }
            .sorted()
    }
}
