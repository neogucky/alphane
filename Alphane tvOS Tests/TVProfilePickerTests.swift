//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import FactoryKit
import Foundation
import JellyfinAPI
import os
import SwiftUI
import UIKit
import XCTest

@MainActor
final class TVProfilePickerTests: XCTestCase {
    func testDelayedPublicProfilesAcquireFocusDuringSetup() async throws {
        let protocols = URLSessionConfiguration.alphane.protocolClasses
        URLSessionConfiguration.alphane.protocolClasses = [ProfileDirectoryProtocol.self] + (protocols ?? [])
        defer { URLSessionConfiguration.alphane.protocolClasses = protocols }
        let url = try XCTUnwrap(URL(string: "https://profile-focus.invalid"))
        let server = ServerState(urls: [url], currentURL: url, name: "Sample directory", id: "public-\(UUID())", userIDs: [])
        try await withProfilePage(server: server, users: [], showsChrome: false) { window, model in
            let expected = SelectUserView.TVProfilePicker.profileID(userID: "public-one", serverID: server.id)
            var received = false
            for _ in 0 ..< 160 {
                if model.confirmedIDs.contains(expected), let focused = UIFocusSystem(for: window)?.focusedItem,
                   window.contains(focused), focused.canBecomeFocused
                {
                    received = true
                    break
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            XCTAssertTrue(received, "Setup must focus the first public profile when its delayed directory response arrives")
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertTrue(model.confirmedIDs.contains(expected))
            capture(window, name: "First public profile after delayed setup directory response")
        }
    }

    func testSavedProfilesArrivingAfterThePickerAppearsReceiveDefaultFocus() async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1"))
        let server = ServerState(urls: [url], currentURL: url, name: "Offline sample", id: "delayed-\(UUID())", userIDs: [])
        let users = [
            UserState(id: "saved-\(UUID())", serverID: server.id, username: "First saved profile"),
            UserState(id: "second-\(UUID())", serverID: server.id, username: "Second saved profile")
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let model = ProfileReadinessModel()
        model.isReady = true
        model.phase = .active
        model.loadedUsers = []
        window.rootViewController = UIHostingController(rootView: ProfileReadinessView(users: users, server: server, model: model))
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(1200))
        let appearances = model.appearances
        model.loadedUsers = users
        try await waitForSavedProfile(in: window)
        XCTAssertEqual(model.appearances, appearances)
        try await Task.sleep(for: .milliseconds(300))
        try await waitForSavedProfile(in: window)
        capture(window, name: "Saved profile after delayed account arrival")

        for delay in [30, 280, 1200] {
            model.loadedUsers = []
            try await Task.sleep(for: .milliseconds(delay))
            model.loadedUsers = users
            try await waitForSavedProfile(in: window)
        }
        XCTAssertEqual(model.appearances, appearances, "Data refresh must not recreate the picker")
    }

    func testLoadingFinishesAfterActivationAndFocusLeavesThePreviousPage() async throws {
        try await withProfilePage { window, model in
            model.showsPreviousPage = true
            try await Task.sleep(for: .milliseconds(400))
            XCTAssertNotNil(UIFocusSystem(for: window)?.focusedItem)
            model.phase = .inactive
            try await Task.sleep(for: .milliseconds(150))
            model.showsLoading = true
            model.showsPreviousPage = false
            model.phase = .active
            try await Task.sleep(for: .milliseconds(700))
            model.showsLoading = false
            try await waitForSavedProfile(in: window)
            try await Task.sleep(for: .milliseconds(300))
            try await waitForSavedProfile(in: window)
            capture(window, name: "Profile focused after animated loading transition")
        }
    }

    func testWakeBehindANativeDialogDoesNotTakeItsFocusAndRestoresProfilesAfterDismissal() async throws {
        try await withProfilePage { window, model in
            try await waitForSavedProfile(in: window)
            let controller = try XCTUnwrap(window.rootViewController)
            let dialog = UIAlertController(title: "Sample PIN dialog", message: nil, preferredStyle: .alert)
            dialog.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            controller.present(dialog, animated: false)
            defer { controller.dismiss(animated: false) }
            for _ in 0 ..< 80 {
                if let focused = UIFocusSystem(for: window)?.focusedItem as? UIView, focused.isDescendant(of: dialog.view) {
                    break
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            model.phase = .inactive
            try await Task.sleep(for: .milliseconds(150))
            model.phase = .active
            try await Task.sleep(for: .milliseconds(700))
            let focused = UIFocusSystem(for: window)?.focusedItem as? UIView
            XCTAssertTrue(focused?.isDescendant(of: dialog.view) == true, "Wake must not focus the profile page underneath a native dialog")
            controller.dismiss(animated: false)
            try await waitForSavedProfile(in: window)
        }
    }

    private func withProfilePage(
        server suppliedServer: ServerState? = nil,
        users suppliedUsers: [UserState]? = nil,
        showsChrome: Bool = true,
        _ body: (UIWindow, ProfileReadinessModel) async throws -> Void
    ) async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1"))
        let server = suppliedServer ?? ServerState(urls: [url], currentURL: url, name: "Offline sample", id: "page-\(UUID())", userIDs: [])
        let users = suppliedUsers ?? [UserState(id: "saved-\(UUID())", serverID: server.id, username: "Saved profile")]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let model = ProfileReadinessModel()
        model.isReady = true
        model.phase = .active
        window.rootViewController = UIHostingController(rootView: ProfileReadinessView(
            users: users,
            server: server,
            model: model,
            showsChrome: showsChrome
        ))
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await body(window, model)
    }

    private func waitForSavedProfile(in window: UIWindow) async throws {
        for _ in 0 ..< 120 {
            if let focus = UIFocusSystem(for: window)?.focusedItem, window.contains(focus), focus.canBecomeFocused,
               focus.frame.width > 200, focus.frame.height > 230, focus.frame.midX < window.bounds.midX
            {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("The mounted saved profile must receive usable native focus without a remote press")
    }

    private func capture(_ window: UIWindow, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWakeRestoresTheSavedProfileWhenReadinessArrivesWithoutAnotherEvent() async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1"))
        let serverID = "wake-profile-\(UUID())"
        let server = ServerState(urls: [url], currentURL: url, name: "Offline sample server", id: serverID, userIDs: [])
        let users = [
            UserState(id: "first-\(UUID())", serverID: server.id, username: "First saved profile"),
            UserState(id: "second-\(UUID())", serverID: server.id, username: "Second saved profile")
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = ProfileWakeWindow(windowScene: scene)
        let readiness = ProfileReadinessModel()
        let controller = ProfileWakeHostingController(rootView: ProfileReadinessView(users: users, server: server, model: readiness))
        controller.acceptsFocus = false
        window.reportsKeyWindowReady = false
        window.rootViewController = controller
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        readiness.isReady = true
        readiness.phase = .active
        try await Task.sleep(for: .milliseconds(1200))
        controller.acceptsFocus = true
        window.reportsKeyWindowReady = true

        func waitForFirstSavedProfile() async throws {
            for _ in 0 ..< 100 {
                if let focus = UIFocusSystem(for: window)?.focusedItem, window.contains(focus), focus.canBecomeFocused,
                   focus.frame.width > 200, focus.frame.height > 230, focus.frame.midX < window.bounds.midX
                {
                    return
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            XCTFail("Late wake readiness must focus the first saved profile without a remote press")
        }
        try await waitForFirstSavedProfile()
        let appearances = readiness.appearances
        for _ in 0 ..< 3 {
            controller.acceptsFocus = false
            window.reportsKeyWindowReady = false
            readiness.phase = .inactive
            readiness.isReady = false
            try await Task.sleep(for: .milliseconds(150))
            readiness.isReady = true
            readiness.phase = .active
            try await Task.sleep(for: .milliseconds(1200))
            // No SwiftUI update, activation notification or input accompanies this.
            controller.acceptsFocus = true
            window.reportsKeyWindowReady = true
            try await waitForFirstSavedProfile()
        }
        XCTAssertEqual(readiness.appearances, appearances, "Wake must recover the retained page, not recreate it")
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = "Saved profiles after repeated late wake readiness"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSavedProfilesAreExcludedFromOtherUsersWithoutHidingUsersOnAnotherServer() {
        let server = makeServer("one")
        let saved = [
            UserState(id: "saved", serverID: "one", username: "Saved"),
            UserState(id: "same-id", serverID: "two", username: "Elsewhere")
        ]
        let publicUsers = [UserDto(id: "saved", name: "Saved"), UserDto(id: "same-id", name: "Other"), UserDto(id: "new", name: "New")]
        let profiles = SelectUserView.TVProfilePicker.unsavedProfiles(users: publicUsers, server: server, savedUsers: saved)
        XCTAssertEqual(profiles.map(\.user.id), ["new", "same-id"])
    }

    func testInvalidAndDuplicatePublicUsersDoNotCreateUnselectableOrDuplicateCards() {
        let users = [
            UserDto(name: "Missing"),
            UserDto(id: "", name: "Empty"),
            UserDto(id: "valid", name: "Valid"),
            UserDto(id: "valid", name: "Duplicate")
        ]
        let profiles = SelectUserView.TVProfilePicker.unsavedProfiles(users: users, server: makeServer("one"), savedUsers: [])
        XCTAssertEqual(profiles.map(\.id), ["one:valid"])
    }

    func testFocusIdentityDistinguishesTheSameUserIDOnDifferentServers() {
        XCTAssertNotEqual(
            SelectUserView.TVProfilePicker.profileID(userID: "user", serverID: "one"),
            SelectUserView.TVProfilePicker.profileID(userID: "user", serverID: "two")
        )
    }

    func testSavedProfileDefaultReturnsAfterControlsBecomeAvailableAgain() async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let server = makeServer("native-profile-focus-\(UUID())")
        let users = [
            UserState(id: "first-focus-\(UUID())", serverID: server.id, username: "First saved profile"),
            UserState(id: "second-focus-\(UUID())", serverID: server.id, username: "Second saved profile")
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let readiness = ProfileReadinessModel()
        window.rootViewController = UIHostingController(rootView: ProfileReadinessView(users: users, server: server, model: readiness))
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        func waitForSavedProfile() async throws {
            for _ in 0 ..< 80 {
                if let item = UIFocusSystem(for: window)?.focusedItem, window.contains(item), item.canBecomeFocused {
                    // Virtual focus items use row-content coordinates. The two
                    // centered saved cards are 220×258; the left one is first.
                    // Lower-row cards and corner controls have smaller bounds.
                    let frame = item.frame
                    if frame.width > 200, frame.height > 230, frame.midX < window.bounds.midX {
                        return
                    }
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            let item = UIFocusSystem(for: window)?.focusedItem
            let frame = item.map { $0.focusItemContainer?.coordinateSpace.convert($0.frame, to: window) ?? $0.frame }
            XCTFail(
                "The first saved profile did not receive usable focus; item \(String(describing: item)), frame \(String(describing: frame)), local \(item.map { window.contains($0) } ?? false), eligible \(item?.canBecomeFocused ?? false), scene \(String(describing: window.windowScene?.activationState.rawValue))"
            )
        }
        try await Task.sleep(for: .milliseconds(300))
        readiness.isReady = true
        readiness.phase = .active
        try await waitForSavedProfile()
        let appearances = readiness.appearances
        for _ in 0 ..< 2 {
            readiness.phase = .inactive
            readiness.isReady = false
            try await Task.sleep(for: .milliseconds(250))
            readiness.isReady = true
            readiness.phase = .active
            try await waitForSavedProfile()
        }
        XCTAssertEqual(readiness.appearances, appearances, "Recovery must work on the retained profile page")
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = "First saved profile restored after controls become available"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeServer(_ id: String) -> ServerState {
        let url = URL(string: "https://example.com")!
        return ServerState(urls: [url], currentURL: url, name: id, id: id, userIDs: [])
    }
}

@MainActor
private final class ProfileReadinessModel: ObservableObject {
    @Published
    var showsPreviousPage = false
    @Published
    var showsLoading = false
    var selectedUserID: String?
    var confirmedIDs: Set<String> = []
    @Published
    var loadedUsers: [UserState]?
    @Published
    var isReady = false
    @Published
    var phase: ScenePhase = .inactive
    var appearances = 0
}

private struct ProfileReadinessView: View {
    let users: [UserState]
    let server: ServerState
    @ObservedObject
    var model: ProfileReadinessModel
    var showsChrome = true
    var body: some View {
        NavigationInjectionView(coordinator: .init()) {
            Group {
                if model.showsPreviousPage {
                    Button("Previous page") {}
                } else if model.showsLoading {
                    ProgressView()
                } else {
                    SelectUserView.TVProfilePicker(
                        userItems: (model.loadedUsers ?? users).map { (user: $0, server: server) }, servers: [server],
                        serverSelection: .all,
                        action: { model.selectedUserID = $0.id }, onDelete: { _ in }, showsChrome: showsChrome
                    )
                    .disabled(!model.isReady)
                    .opacity(model.isReady ? 1 : 0)
                    .allowsHitTesting(model.isReady)
                    .onAppear { model.appearances += 1 }
                }
            }
            .animation(.linear(duration: 0.1), value: model.showsLoading)
            .animation(.linear(duration: 0.1), value: model.showsPreviousPage)
        }
        .preferredColorScheme(.dark)
        .background(AlphaneTheme.background.ignoresSafeArea())
        .onPreferenceChange(ProfileFocusPreference.self) { model.confirmedIDs = $0 }
        .recoveringMissingFocus()
        .environment(\.scenePhase, model.phase)
    }
}

private final class ProfileDirectoryProtocol: URLProtocol, @unchecked Sendable {
    private let stopped = OSAllocatedUnfairLock(initialState: false)

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "profile-focus.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let isDirectory = request.url?.path.lowercased().hasSuffix("/users/public") == true
        DispatchQueue.global().asyncAfter(deadline: .now() + (isDirectory ? 0.7 : 0)) { [weak self] in
            guard let self, !stopped.withLock({ $0 }), let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: isDirectory ? 200 : 404,
                      httpVersion: nil,
                      headerFields: ["Content-Type": "application/json"]
                  ) else { return }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if isDirectory, let data = try? JSONEncoder().encode([
                UserDto(id: "public-one", name: "First public profile"), UserDto(id: "public-two", name: "Second public profile")
            ]) {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        stopped.withLock { $0 = true }
    }
}

@MainActor
private final class ProfileWakeWindow: UIWindow {
    var reportsKeyWindowReady = true
    override var isKeyWindow: Bool {
        reportsKeyWindowReady && super.isKeyWindow
    }
}

@MainActor
private final class ProfileWakeHostingController: UIHostingController<ProfileReadinessView> {
    var acceptsFocus = true
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        acceptsFocus && super.shouldUpdateFocus(in: context)
    }
}
