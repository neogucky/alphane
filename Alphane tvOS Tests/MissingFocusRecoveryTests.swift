//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import FactoryKit
import SwiftUI
import UIKit
import XCTest

@MainActor
final class MissingFocusRecoveryTests: XCTestCase {
    func testRecoverySurvivesWindowEligibilityArrivingAfterTheWakeNotification() async throws {
        try await withFixture { controller, window in
            let delayedWindow = try XCTUnwrap(window as? FocusRecoveryTestWindow)
            delayedWindow.reportsKeyWindowReady = false
            controller.allowsControlsToFocus = false
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(1200))
            XCTAssertNil(UIFocusSystem(for: window)?.focusedItem)

            // Model wake's late window/focus readiness without a second activation,
            // key-window notification, appearance or remote input.
            controller.allowsControlsToFocus = true
            delayedWindow.reportsKeyWindowReady = true
            try await waitForFocus(controller.first, in: window)
        }
    }

    func testDelayedFirstControlReceivesFocusWithoutRemoteInput() async throws {
        try await withFixture { controller, window in
            controller.first.isEnabled = false
            controller.second.isEnabled = false
            controller.third.isEnabled = false
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertNil(UIFocusSystem(for: window)?.focusedItem)
            // Readiness changes without another appearance or a focus request.
            controller.first.isEnabled = true
            try await waitForFocus(controller.first, in: window)
        }
    }

    func testMissingFocusAfterActivationIsRecoveredWithoutAnotherAppearance() async throws {
        try await withFixture { controller, window in
            controller.allowsControlsToFocus = false
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertNil(UIFocusSystem(for: window)?.focusedItem)
            let appearances = controller.appearances
            controller.allowsControlsToFocus = true
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: window.windowScene)
            try await waitForFocus(controller.first, in: window)
            XCTAssertEqual(controller.appearances, appearances)
        }
    }

    func testAnExistingSelectionIsNeverReplacedByTheDefault() async throws {
        try await withFixture { controller, window in
            window.makeKeyAndVisible()
            try await waitForFocus(controller.first, in: window)
            let system = try XCTUnwrap(UIFocusSystem(for: window))
            controller.recovery.isRecoveryEnabled = false
            controller.preferredControl = controller.second
            controller.setNeedsFocusUpdate()
            controller.updateFocusIfNeeded()
            try await waitForFocus(controller.second, in: window)
            controller.preferredControl = controller.first
            controller.recovery.isRecoveryEnabled = true
            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: window.windowScene)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(600))
            XCTAssertTrue(system.focusedItem === controller.second)
        }
    }

    func testRemovedFocusedControlFallsBackToAnAvailableControl() async throws {
        try await withFixture { controller, window in
            window.makeKeyAndVisible()
            try await waitForFocus(controller.first, in: window)
            controller.first.removeFromSuperview()
            try await waitForFocus(controller.second, in: window)
        }
    }

    func testRecoveryWaitsWhileInactiveAndDoesNotFocusAnotherWindow() async throws {
        try await withFixture { controller, window in
            controller.recovery.isRecoveryEnabled = false
            controller.allowsControlsToFocus = false
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(250))
            controller.allowsControlsToFocus = true
            try await Task.sleep(for: .milliseconds(450))
            XCTAssertNil(UIFocusSystem(for: window)?.focusedItem, "A background scene must not request focus")
            controller.recovery.isRecoveryEnabled = true
            try await waitForFocus(controller.first, in: window)

            let secondWindow = try UIWindow(windowScene: XCTUnwrap(window.windowScene))
            let overlay = FocusRecoveryFixtureController()
            secondWindow.rootViewController = overlay
            secondWindow.frame = window.bounds
            secondWindow.makeKeyAndVisible()
            defer { secondWindow.isHidden = true
                secondWindow.rootViewController = nil
            }
            try await waitForFocus(overlay.first, in: secondWindow)
            try await Task.sleep(for: .milliseconds(350))
            XCTAssertTrue(UIFocusSystem(for: secondWindow)?.focusedItem === overlay.first)
            XCTAssertFalse(window.isKeyWindow)
        }
    }

    func testPresentedDialogKeepsFocusInsteadOfTheCoveredPage() async throws {
        try await withFixture { controller, window in
            window.makeKeyAndVisible()
            try await waitForFocus(controller.first, in: window)
            let alert = UIAlertController(title: "Sample dialog", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default))
            controller.present(alert, animated: false)
            defer { controller.dismiss(animated: false) }
            var focusedView: UIView?
            for _ in 0 ..< 60 {
                focusedView = UIFocusSystem(for: window)?.focusedItem as? UIView
                if focusedView?.isDescendant(of: alert.view) == true {
                    break
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            try await Task.sleep(for: .milliseconds(350))
            focusedView = UIFocusSystem(for: window)?.focusedItem as? UIView
            XCTAssertTrue(focusedView?.isDescendant(of: alert.view) == true, "Do not focus controls underneath a dialog")
        }
    }

    private func withFixture(_ action: (FocusRecoveryFixtureController, UIWindow) async throws -> Void) async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let controller = FocusRecoveryFixtureController()
        let window = FocusRecoveryTestWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = controller
        controller.loadViewIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await action(controller, window)
    }

    private func waitForFocus(_ item: UIView, in window: UIWindow) async throws {
        for _ in 0 ..< 60 {
            if UIFocusSystem(for: window)?.focusedItem === item {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail(
            "The available control never received native focus; expected \(item), actual \(String(describing: UIFocusSystem(for: window)?.focusedItem)); key window \(window.isKeyWindow)"
        )
    }
}

@MainActor
private final class FocusRecoveryTestWindow: UIWindow {
    var reportsKeyWindowReady = true
    override var isKeyWindow: Bool {
        reportsKeyWindowReady && super.isKeyWindow
    }
}

@MainActor
private final class FocusRecoveryFixtureController: UIViewController {
    let first = FocusEligibilityButton(type: .system)
    let second = FocusEligibilityButton(type: .system)
    let third = FocusEligibilityButton(type: .system)
    let recovery = MissingFocusRecoveryObserver()
    var preferredControl: UIView?
    var allowsControlsToFocus: Bool {
        get { first.isFocusReady }
        set { for button in [first, second, third] {
            button.isFocusReady = newValue
        } }
    }

    private(set) var appearances = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        for (index, button) in [first, second, third].enumerated() {
            button.setTitle("Option \(index + 1)", for: .normal)
            button.frame = CGRect(x: 200 + index * 460, y: 440, width: 360, height: 100)
            view.addSubview(button)
        }
        recovery.isRecoveryEnabled = true
        view.addSubview(recovery)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearances += 1
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [preferredControl, first, second, third].compactMap(\.self).filter { $0.superview != nil && $0.canBecomeFocused }
    }
}

@MainActor
private final class FocusEligibilityButton: UIButton {
    var isFocusReady = true
    override var canBecomeFocused: Bool {
        isFocusReady && super.canBecomeFocused
    }
}
