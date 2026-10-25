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
final class HomeFocusReturnTests: XCTestCase {

    func testBackRestoresANativeCardAfterContinueRefreshRecreatesTheRow() async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let factories = FactoryKit.Container.shared.manager
        factories.push()
        defer { factories.pop() }
        let userID = "home-focus-\(UUID().uuidString)"
        let url = try XCTUnwrap(URL(string: "https://focus.example"))
        let session = UserSession(
            server: ServerState(urls: [url], currentURL: url, name: "Test", id: userID, userIDs: [userID]),
            user: UserState(id: userID, serverID: userID, username: "Test")
        )
        FactoryKit.Container.shared.currentUserSession.register { session }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let navigation = NavigationCoordinator(usesNavigationStack: true)
        let fixture = HomeFocusFixture()
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: navigation) { HomeFocusFixtureView(model: fixture) }
                .preferredColorScheme(.dark))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        func waitForCard(_ id: String) async throws {
            for _ in 0 ..< 80 {
                if fixture.focusedID == AnyPoster(BaseItemDto(id: id)).id, let focused = UIFocusSystem(for: window)?.focusedItem {
                    let frame = focused.focusItemContainer?.coordinateSpace.convert(focused.frame, to: window) ?? focused.frame
                    if frame.minX < 500, frame.width > 100 {
                        return
                    }
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTFail("No native Home card focus for \(id); last callback: \(String(describing: fixture.focusedID))")
        }
        try await waitForCard("completed")
        navigation.focusStore.remember(.init(scope: "cinematic-selection", item: AnyHashable(fixture.items[0].id)), on: "root")
        navigation.push(NavigationRoute(id: "episode") { Button("Episode detail") {} })
        try await Task.sleep(for: .milliseconds(350))
        fixture.items.removeFirst()
        fixture.generation += 1
        fixture.focusedID = nil
        navigation.path.removeLast()
        try await waitForCard("next")
        XCTAssertNil(navigation.focusStore.request)
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = "Home after Back with refreshed Continue and down cue"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class HomeFocusFixture: ObservableObject {
    @Published
    var generation = 0
    @Published
    var items = [
        BaseItemDto(id: "completed", name: "Finished episode", type: .episode),
        BaseItemDto(id: "next", name: "Next episode", type: .episode),
        BaseItemDto(id: "another", name: "Another movie", type: .movie)
    ]
    var focusedID: AnyPoster.ID?
}

private struct HomeFocusFixtureView: View {
    @ObservedObject
    var model: HomeFocusFixture
    @FocusedValue(\.focusedPoster)
    private var focusedPoster

    var body: some View {
        ScrollView {
            CinematicItemSelector(items: model.items, showsDownCue: true) { _ in } topContent: { item in
                Text(item.displayTitle).font(.system(size: 54, weight: .bold)).padding(.horizontal, 60)
            }
            .environment(\.navigationFocusScopeID, "cinematic-selection")
            .id(model.generation)
        }
        .trackingFrame(for: .scrollView)
        .onChange(of: focusedPoster?.id, initial: true) { _, id in model.focusedID = id }
    }
}
