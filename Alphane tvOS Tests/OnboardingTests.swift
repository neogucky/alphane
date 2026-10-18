//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Defaults
import SwiftUI
import XCTest

@MainActor
final class OnboardingTests: XCTestCase {
    private var preferences: UserDefaults!
    private var suiteName: String!
    private var previousTheme: AlphaneColorTheme!
    private var previousColor: Color!
    private var previousServer: SelectUserServerSelection!

    override func setUp() {
        super.setUp()
        suiteName = "onboarding-test-\(UUID())"
        preferences = UserDefaults(suiteName: suiteName)!
        previousTheme = Defaults[.colorTheme]
        previousColor = Defaults[.accentColor]
        previousServer = Defaults[.selectUserServerSelection]
    }

    override func tearDown() {
        preferences.removePersistentDomain(forName: suiteName)
        Defaults[.colorTheme] = previousTheme
        Defaults[.accentColor] = previousColor
        Defaults[.selectUserServerSelection] = previousServer
        super.tearDown()
    }

    func testNewInstallationStartsWithStyleAndCannotSkipAuthentication() {
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        XCTAssertEqual(model.step, .style)
        XCTAssertEqual(model.theme, .noAccent)
        model.selectServer(server())
        XCTAssertEqual(model.step, .style)
        XCTAssertFalse(model.finish(user: user()))
        model.back()
        XCTAssertEqual(model.step, .style)
    }

    func testUpgradeSkipsSetupAndDoesNotChangeTheCurrentTheme() {
        let model = TVOnboardingModel(preferences: preferences, servers: [server()])
        XCTAssertEqual(model.step, .complete)
        model.applyPreview()
        XCTAssertEqual(Defaults[.colorTheme], previousTheme)
        XCTAssertEqual(Defaults[.accentColor], previousColor)
        // Deleting the last server later must not turn an update into first launch.
        XCTAssertEqual(TVOnboardingModel(preferences: preferences, servers: []).step, .complete)
    }

    func testFocusPreviewsWithoutSavingOrAdvancing() {
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        model.preview(.warm)
        XCTAssertEqual(Defaults[.colorTheme], .warm)
        assertColor(Defaults[.accentColor], AlphaneColorTheme.warm.color(custom: .white))
        XCTAssertEqual(model.theme, .noAccent)
        XCTAssertEqual(model.step, .style)

        let restored = TVOnboardingModel(preferences: preferences, servers: [])
        XCTAssertEqual(restored.theme, .noAccent, "An unconfirmed focus preview must not become the saved choice")
        model.choose(.cold)
        model.continueFromStyle()
        model.preview(.warm)
        XCTAssertEqual(model.step, .server)
        XCTAssertEqual(model.theme, .cold)
        XCTAssertEqual(Defaults[.colorTheme], .cold, "Focus changes during dismissal must not replace the confirmed style")
        model.back()
        XCTAssertEqual(model.theme, .cold)
    }

    func testConnectedServerDoesNotMarkAnInterruptedSetupComplete() {
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        model.continueFromStyle()
        model.selectServer(server())
        let restored = TVOnboardingModel(preferences: preferences, servers: [server()])
        XCTAssertEqual(restored.step, .profile)
        XCTAssertEqual(restored.selectedServer?.id, server().id)
        restored.back()
        XCTAssertEqual(restored.step, .server)
        restored.back()
        XCTAssertEqual(restored.step, .style)
    }

    func testDraftCustomColourSurvivesBackNavigationAndRelaunch() {
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        let custom = Color(hex: "BE96E8")
        model.chooseCustomColor(custom)
        model.choose(.warm)
        model.continueFromStyle()
        model.back()
        let restored = TVOnboardingModel(preferences: preferences, servers: [])
        XCTAssertEqual(restored.theme, .warm)
        assertColor(restored.customColor, custom)
        restored.choose(.custom)
        assertColor(restored.color, custom)
    }

    func testMissingServerReturnsToConnectionStep() {
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        model.continueFromStyle()
        model.selectServer(server())
        XCTAssertEqual(TVOnboardingModel(preferences: preferences, servers: []).step, .server)
    }

    func testOnlyTheAuthenticatedProfileReceivesTheThemeOnce() {
        let target = user()
        let other = UserState(id: "other-\(UUID())", serverID: "elsewhere", username: "Other")
        let targetSuite = UserDefaults.userSuite(id: target.id)
        let otherSuite = UserDefaults.userSuite(id: other.id)
        let previousUser = Defaults[.lastSignedInUserID]
        defer {
            Defaults[.lastSignedInUserID] = previousUser
            targetSuite.removePersistentDomain(forName: target.id)
            otherSuite.removePersistentDomain(forName: other.id)
        }
        Defaults[.lastSignedInUserID] = .signedIn(userID: other.id)
        Defaults[.userColorTheme(in: otherSuite)] = .cold
        let model = TVOnboardingModel(preferences: preferences, servers: [])
        let custom = Color(hex: "BE96E8")
        model.chooseCustomColor(custom)
        model.continueFromStyle()
        model.selectServer(server())
        XCTAssertFalse(model.finish(user: other))
        XCTAssertEqual(model.step, .profile)
        XCTAssertTrue(model.finish(user: target))
        XCTAssertEqual(Defaults[.userColorTheme(in: targetSuite)], .custom)
        assertColor(Defaults[.userAccentColor(in: targetSuite)], custom)
        XCTAssertEqual(Defaults[.userColorTheme(in: otherSuite)], .cold)
        XCTAssertEqual(model.step, .complete)
        Defaults[.userColorTheme(in: targetSuite)] = .warm
        XCTAssertFalse(model.finish(user: target), "Later logins must not reapply the setup theme")
        XCTAssertEqual(Defaults[.userColorTheme(in: targetSuite)], .warm)
        XCTAssertEqual(TVOnboardingModel(preferences: preferences, servers: [server()]).step, .complete)
    }

    private func server() -> ServerState {
        let url = URL(string: "https://onboarding.invalid")!
        return ServerState(urls: [url], currentURL: url, name: "Cinema", id: "onboarding-server", userIDs: [])
    }

    private func user() -> UserState {
        UserState(id: "onboarding-\(UUID())", serverID: "onboarding-server", username: "Alex")
    }

    private func assertColor(_ actual: Color, _ expected: Color) {
        let actual = actual.rgbaComponents
        let expected = expected.rgbaComponents
        XCTAssertEqual(actual.red, expected.red, accuracy: 0.002)
        XCTAssertEqual(actual.green, expected.green, accuracy: 0.002)
        XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.002)
        XCTAssertEqual(actual.alpha, expected.alpha, accuracy: 0.002)
    }
}
