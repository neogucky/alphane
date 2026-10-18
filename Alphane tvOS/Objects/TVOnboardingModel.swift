//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

@MainActor
final class TVOnboardingModel: ObservableObject {
    enum Step: String, Defaults.Serializable {
        case style
        case server
        case profile
        case complete
    }

    @Published
    private(set) var step: Step
    @Published
    private(set) var theme: AlphaneColorTheme
    @Published
    private(set) var customColor: Color
    @Published
    private(set) var servers: [ServerState]
    @Published
    private(set) var serverID: String?

    private let stepKey: Defaults.Key<Step?>
    private let themeKey: Defaults.Key<AlphaneColorTheme>
    private let customKey: Defaults.Key<Color>
    private let serverKey: Defaults.Key<String?>

    init(preferences: UserDefaults = .appSuite, servers: [ServerState] = StoredValues[.Server.servers]) {
        stepKey = .init("setupStep", default: nil, suite: preferences)
        themeKey = .init("setupTheme", default: .noAccent, suite: preferences)
        customKey = .init("setupCustomColor", default: AlphaneTheme.accent, suite: preferences)
        serverKey = .init("setupServerID", default: nil, suite: preferences)
        self.servers = servers
        theme = Defaults[themeKey]
        customColor = Defaults[customKey]
        serverID = Defaults[serverKey]
        // A nil marker with saved servers identifies an existing installation.
        // Once setup starts, its explicit marker survives connecting a server.
        let stored = Defaults[stepKey]
        step = stored ?? (servers.isEmpty ? .style : .complete)
        if step == .profile, !servers.contains(where: { $0.id == serverID }) {
            step = .server
        }
        Defaults[stepKey] = step
    }

    var selectedServer: ServerState? {
        servers.first { $0.id == serverID }
    }

    var color: Color {
        theme.color(custom: customColor)
    }

    func choose(_ theme: AlphaneColorTheme) {
        self.theme = theme
        Defaults[themeKey] = theme
        applyPreview()
    }

    func chooseCustomColor(_ color: Color) {
        customColor = color
        Defaults[customKey] = color
        choose(.custom)
    }

    func applyPreview() {
        guard step != .complete else { return }

        Defaults[.colorTheme] = theme
        Defaults[.accentColor] = color
    }

    func continueFromStyle() {
        guard step == .style else { return }

        move(to: .server)
    }

    func selectServer(_ server: ServerState) {
        guard step == .server else { return }

        if !servers.contains(where: { $0.id == server.id }) {
            servers.append(server)
        }
        serverID = server.id
        Defaults[serverKey] = server.id
        Defaults[.selectUserServerSelection] = .server(id: server.id)
        move(to: .profile)
    }

    func back() {
        switch step {
        case .server: move(to: .style)
        case .profile: move(to: .server)
        case .style, .complete: break
        }
    }

    /// Write to the authenticated profile explicitly; session publication and
    /// lastSignedInUserID observation need not happen in the same render pass.
    @discardableResult
    func finish(user: UserState) -> Bool {
        guard step == .profile, user.serverID == serverID else { return false }

        let suite = UserDefaults.userSuite(id: user.id)
        Defaults[.userAccentColor(in: suite)] = customColor
        Defaults[.userColorTheme(in: suite)] = theme
        applyPreview()
        move(to: .complete)
        return true
    }

    private func move(to step: Step) {
        self.step = step
        Defaults[stepKey] = step
    }
}
