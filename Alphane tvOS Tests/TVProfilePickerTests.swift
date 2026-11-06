//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import FactoryKit
import JellyfinAPI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class TVProfilePickerTests: XCTestCase {

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
    var body: some View {
        NavigationInjectionView(coordinator: .init()) {
            SelectUserView.TVProfilePicker(
                userItems: users.map { (user: $0, server: server) }, servers: [server], serverSelection: .all,
                action: { _ in }, onDelete: { _ in }
            )
            .disabled(!model.isReady)
            .opacity(model.isReady ? 1 : 0)
            .allowsHitTesting(model.isReady)
            .onAppear { model.appearances += 1 }
        }
        .preferredColorScheme(.dark)
        .recoveringMissingFocus()
        .environment(\.scenePhase, model.phase)
    }
}
