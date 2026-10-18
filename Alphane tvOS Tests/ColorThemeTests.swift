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
final class ColorThemeTests: XCTestCase {
    func testLegacyColoursKeepTheirAppearanceWithoutOptingIntoNeutral() {
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: nil, custom: AlphaneTheme.accent), .cold)
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: nil, custom: Color(hex: "E1B471")), .warm)
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: nil, custom: .white), .custom)
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: nil, custom: .jellyfinPurple), .custom)
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: nil, custom: AlphaneTheme.accent.opacity(0.5)), .custom)
    }

    func testExplicitNeutralAndCustomWhiteRemainDifferentModes() {
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: .noAccent, custom: .jellyfinPurple), .noAccent)
        XCTAssertEqual(AlphaneColorTheme.resolved(stored: .custom, custom: .white), .custom)
        assertColor(AlphaneColorTheme.noAccent.color(custom: .pink), red: 1, green: 1, blue: 1)
        assertColor(AlphaneColorTheme.custom.color(custom: .white), red: 1, green: 1, blue: 1)
    }

    func testPresetColoursAreIndependentOfTheSavedCustomColour() {
        assertColor(AlphaneColorTheme.cold.color(custom: .red), red: 106.0 / 255, green: 214.0 / 255, blue: 202.0 / 255)
        assertColor(AlphaneColorTheme.warm.color(custom: .blue), red: 225.0 / 255, green: 180.0 / 255, blue: 113.0 / 255)
    }

    func testProfilesAndPresetSwitchesPreserveTheirCustomColour() {
        let previous = Defaults[.lastSignedInUserID]
        let first = "theme-test-\(UUID())"
        let second = "theme-test-\(UUID())"
        defer {
            Defaults[.lastSignedInUserID] = previous
            UserDefaults.userSuite(id: first).removePersistentDomain(forName: first)
            UserDefaults.userSuite(id: second).removePersistentDomain(forName: second)
        }
        Defaults[.lastSignedInUserID] = .signedIn(userID: first)
        Defaults[.userAccentColor] = Color(hex: "BE96E8")
        for preset in AlphaneColorTheme.presets {
            Defaults[.userColorTheme] = preset
            XCTAssertEqual(Defaults[.userAccentColor].hexString, Color(hex: "BE96E8").hexString)
        }
        Defaults[.userColorTheme] = .custom

        Defaults[.lastSignedInUserID] = .signedIn(userID: second)
        XCTAssertNil(Defaults[.userColorTheme])
        Defaults[.userColorTheme] = .noAccent
        Defaults[.lastSignedInUserID] = .signedIn(userID: first)
        XCTAssertEqual(Defaults[.userColorTheme], .custom)
        XCTAssertEqual(Defaults[.userAccentColor].hexString, Color(hex: "BE96E8").hexString)
    }

    private func assertColor(_ color: Color, red: CGFloat, green: CGFloat, blue: CGFloat) {
        let rgb = color.rgbaComponents
        XCTAssertEqual(rgb.red, red, accuracy: 0.002)
        XCTAssertEqual(rgb.green, green, accuracy: 0.002)
        XCTAssertEqual(rgb.blue, blue, accuracy: 0.002)
    }
}
