//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import SwiftUI
import UIKit
import XCTest

@MainActor
final class PersistentNavigationTests: XCTestCase {

    func testBrowsingPushesRemainInStackAndBackReturnsToPreviousPage() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        coordinator.push(route("series"))
        coordinator.push(route("episode"))

        XCTAssertEqual(coordinator.path.map(\.id), ["series", "episode"])
        XCTAssertNil(coordinator.presentedSheet)
        coordinator.path.removeLast()
        XCTAssertEqual(coordinator.path.map(\.id), ["series"])
    }

    func testFullscreenPlaybackPreservesBrowsingStack() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        coordinator.push(route("episode"))
        coordinator.push(route("player", style: .fullscreen))

        XCTAssertEqual(coordinator.path.map(\.id), ["episode"])
        XCTAssertEqual(coordinator.presentedFullScreen?.route.id, "player")
        XCTAssertNil(coordinator.presentedSheet)
    }

    func testContinuingEpisodesReturnsBackToHomeWithoutRevisitingFinishedEpisodes() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let router = NavigationCoordinator.Router(navigationCoordinator: coordinator, isRootOfPath: false)
        let homeTarget = NavigationFocusStore.Target(scope: "continue", item: "episode-1")
        coordinator.focusStore.remember(homeTarget, on: "root")
        router.route(to: route("episode-1"))

        for episode in ["episode-2", "episode-3"] {
            router.replace(with: route(episode))
            router.route(to: route("player", style: .fullscreen))
            XCTAssertEqual(coordinator.path.map(\.id), [episode])
            XCTAssertEqual(coordinator.presentedFullScreen?.route.id, "player")
            coordinator.presentedFullScreen = nil
            coordinator.fullScreenDidDismiss()
            XCTAssertEqual(coordinator.path.map(\.id), [episode])
        }

        coordinator.path.removeLast()
        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertEqual(coordinator.focusStore.request?.pageID, "root")
        XCTAssertEqual(coordinator.focusStore.request?.target, homeTarget)
    }

    func testContinuingEpisodesPreservesTheOriginatingSeriesPageAndItsSelection() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        coordinator.push(route("series"))
        let seriesTarget = NavigationFocusStore.Target(scope: "episodes", item: "episode-1")
        coordinator.focusStore.remember(seriesTarget, on: "series")
        coordinator.push(route("episode-1"))
        coordinator.focusStore.restore("series")

        coordinator.replaceLast(with: route("episode-2"))
        XCTAssertEqual(coordinator.path.map(\.id), ["series", "episode-2"])
        XCTAssertNil(coordinator.focusStore.request, "Replacement must clear a stale focus-restoration request")
        coordinator.replaceLast(with: route("episode-3"))
        coordinator.path.removeLast()

        XCTAssertEqual(coordinator.path.map(\.id), ["series"])
        XCTAssertEqual(coordinator.focusStore.request?.pageID, "series")
        XCTAssertEqual(coordinator.focusStore.request?.target, seriesTarget)
    }

    func testReplacementWithoutAStackEntryFallsBackToNormalRouting() {
        let stack = NavigationCoordinator(usesNavigationStack: true)
        stack.replaceLast(with: route("episode"))
        XCTAssertEqual(stack.path.map(\.id), ["episode"])

        let modal = NavigationCoordinator()
        modal.replaceLast(with: route("episode"))
        XCTAssertTrue(modal.path.isEmpty)
        XCTAssertEqual(modal.presentedSheet?.route.id, "episode")
    }

    func testReplacementPreservesModalPresentationStylesAndRoutesInsideTheActivePresentation() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        coordinator.push(route("episode"))
        coordinator.replaceLast(with: route("player", style: .fullscreen))
        XCTAssertEqual(coordinator.path.map(\.id), ["episode"])
        XCTAssertEqual(coordinator.presentedFullScreen?.route.id, "player")

        coordinator.replaceLast(with: route("tracks", style: .sheet))
        XCTAssertEqual(coordinator.path.map(\.id), ["episode"])
        XCTAssertEqual(coordinator.presentedFullScreen?.route.id, "player")
        XCTAssertEqual(coordinator.presentedFullScreen?.coordinator.presentedSheet?.route.id, "tracks")
    }

    func testNativeStackShowsTheReplacementAndBackReturnsToTheOriginalView() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let window = UIWindow(windowScene: scene)
        func detail(_ id: String) -> NavigationRoute {
            NavigationRoute(id: id) { NavigationReplacementPage(id: id) }
        }
        func navigationController(in controller: UIViewController) -> UINavigationController? {
            (controller as? UINavigationController) ?? controller.children.lazy.compactMap { navigationController(in: $0) }.first
        }
        func visiblePageID(in view: UIView) -> String? {
            guard !view.isHidden, view.alpha > 0 else { return nil }

            if let id = view.accessibilityIdentifier, id.hasPrefix("navigation-probe-") {
                return id
            }
            return view.subviews.lazy.compactMap { visiblePageID(in: $0) }.first
        }
        func waitForPage(_ id: String, phase: String) async throws {
            var visibleID: String?
            for _ in 0 ..< 60 {
                let navigation = window.rootViewController.flatMap { navigationController(in: $0) }
                visibleID = navigation?.visibleViewController?.view.flatMap { visiblePageID(in: $0) }
                if visibleID == "navigation-probe-\(id)", navigation?.transitionCoordinator == nil {
                    return
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTFail("\(phase): expected visible page \(id), got \(visibleID ?? "none"); path: \(coordinator.path.map(\.id))")
        }
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: coordinator) { NavigationReplacementPage(id: "home") })
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await waitForPage("home", phase: "Initial presentation")

        for origin in ["home", "series"] {
            if origin == "series" {
                coordinator.push(detail(origin))
                try await waitForPage(origin, phase: "Opening the series")
            }
            coordinator.push(detail("episode-1"))
            try await waitForPage("episode-1", phase: "Opening the first episode from \(origin)")
            for episode in ["episode-2", "episode-3"] {
                coordinator.replaceLast(with: detail(episode))
                try await waitForPage(episode, phase: "Continuing from \(origin)")
            }
            coordinator.path.removeLast()
            try await waitForPage(origin, phase: "Back to \(origin)")
            XCTAssertEqual(coordinator.path.map(\.id), origin == "home" ? [] : ["series"])
        }
    }

    func testExplicitModalStillPresentsAboveBrowsingStack() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        coordinator.push(route("episode"))
        coordinator.push(route("filters", style: .sheet))

        XCTAssertEqual(coordinator.path.map(\.id), ["episode"])
        XCTAssertEqual(coordinator.presentedSheet?.route.id, "filters")
    }

    func testNonTabNavigationRetainsExistingPresentationBehavior() {
        let coordinator = NavigationCoordinator()
        coordinator.push(route("connect"))

        XCTAssertTrue(coordinator.path.isEmpty)
        XCTAssertEqual(coordinator.presentedSheet?.route.id, "connect")
    }

    func testSwitchingTabsPreservesIndependentBrowsingHistory() async {
        let coordinator = TabCoordinator {
            TabItem(id: "home", title: "Home", systemImage: "house") { EmptyView() }
            TabItem(id: "movies", title: "Movies", systemImage: "film") { EmptyView() }
        }
        await coordinator.route(to: route("episode"))
        coordinator.selectedTabID = "movies"
        await coordinator.route(to: route("movie"))
        coordinator.selectedTabID = "home"

        XCTAssertEqual(coordinator.tabs[0].coordinator.path.map(\.id), ["episode"])
        XCTAssertEqual(coordinator.tabs[1].coordinator.path.map(\.id), ["movie"])
        XCTAssertNil(coordinator.tabs[0].coordinator.presentedSheet)
        XCTAssertNil(coordinator.tabs[1].coordinator.presentedSheet)
    }

    func testHeaderObservationDoesNotMutateScrollViewOrPublishPageUpdates() {
        let controller = MainNavigationScrollController()
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        scrollView.contentInset.top = 80
        let viewport = scrollView.bounds.size
        var layoutUpdates = 0
        let subscription = controller.objectWillChange.sink { layoutUpdates += 1 }
        controller.register(scrollView, tabID: "home")
        controller.activate("home")

        for offset in stride(from: -80, through: 400, by: 1) {
            scrollView.contentOffset.y = CGFloat(offset)
            controller.didScroll(tabID: "home")
        }

        XCTAssertEqual(scrollView.bounds.size, viewport)
        XCTAssertEqual(controller.headerState.hiddenHeight, 80)
        XCTAssertEqual(layoutUpdates, 0)
        withExtendedLifetime(subscription) {}
    }

    func testHeaderUsesRememberedOffsetForActiveTabOnly() {
        let controller = MainNavigationScrollController()
        let home = UIScrollView()
        let movies = UIScrollView()
        home.contentOffset.y = 40
        movies.contentOffset.y = 200
        controller.register(home, tabID: "home")
        controller.register(movies, tabID: "movies")
        controller.activate("home")
        XCTAssertEqual(controller.headerState.hiddenHeight, 40)

        controller.didScroll(tabID: "movies")
        XCTAssertEqual(controller.headerState.hiddenHeight, 40)
        controller.activate("movies")
        XCTAssertEqual(controller.headerState.hiddenHeight, 80)
        controller.activate("home")
        XCTAssertEqual(controller.headerState.hiddenHeight, 40)
    }

    func testHeaderStopsPublishingOnceItHasScrolledAway() {
        let controller = MainNavigationScrollController()
        let scrollView = UIScrollView()
        controller.register(scrollView, tabID: "home")
        controller.activate("home")
        var headerUpdates = 0
        let subscription = controller.headerState.objectWillChange.sink { headerUpdates += 1 }

        for offset in stride(from: 0, through: 400, by: 1) {
            scrollView.contentOffset.y = CGFloat(offset)
            controller.didScroll(tabID: "home")
        }

        XCTAssertEqual(headerUpdates, 80)
        XCTAssertEqual(controller.headerState.hiddenHeight, 80)
        withExtendedLifetime(subscription) {}
    }

    func testBackRequestsTheActivatedCardOnItsOriginatingPage() {
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let homeTarget = NavigationFocusStore.Target(scope: "continue", item: "episode-12")
        let seriesTarget = NavigationFocusStore.Target(scope: "episodes", item: "episode-13")
        coordinator.focusStore.remember(homeTarget, on: "root")
        coordinator.push(route("series"))
        XCTAssertNil(coordinator.focusStore.request)
        coordinator.focusStore.remember(seriesTarget, on: "series")
        coordinator.push(route("episode"))

        coordinator.path.removeLast()
        XCTAssertEqual(coordinator.focusStore.request?.pageID, "series")
        XCTAssertEqual(coordinator.focusStore.request?.target, seriesTarget)
        coordinator.path.removeLast()
        XCTAssertEqual(coordinator.focusStore.request?.pageID, "root")
        XCTAssertEqual(coordinator.focusStore.request?.target, homeTarget)
    }

    func testRestorationIsConsumedOnceSoMovingFocusDoesNotJumpBack() {
        let store = NavigationFocusStore()
        let target = NavigationFocusStore.Target(scope: "continue", item: "episode-12")
        store.remember(target, on: "root")
        store.restore("root")
        store.didRestore(target, on: "series")
        XCTAssertNotNil(store.request)
        store.didRestore(target, on: "root")
        XCTAssertNil(store.request)
        // Remembered activation remains available for another visit to the same detail page.
        store.restore("root")
        XCTAssertEqual(store.request?.target, target)
    }

    func testDetailDefaultFocusRemainsAvailableDuringNavigationTransition() {
        let coordinator = FocusCoordinator(initial: "play")
        XCTAssertNil(coordinator.request)
        XCTAssertTrue(coordinator.prefersInitialFocus("play"))
        XCTAssertFalse(coordinator.prefersInitialFocus("seasons"))

        // Native default preferences remain available if tvOS evaluates them again
        // after the transition; they do not issue another imperative focus request.
        coordinator.focus("seasons")
        XCTAssertTrue(coordinator.prefersInitialFocus("play"))
        XCTAssertEqual(coordinator.request?.id, "seasons")
    }

    private func route(
        _ id: String,
        style: NavigationRoute.TransitionStyle = .push(.automatic)
    ) -> NavigationRoute {
        NavigationRoute(id: id, style: style) { EmptyView() }
    }
}

/// State mirrors a detail page's retained provider: replacement must create a new identity.
private struct NavigationReplacementPage: View {

    @State
    private var itemID: String

    init(id: String) {
        _itemID = State(initialValue: id)
    }

    var body: some View {
        Button(itemID) {}
            .buttonStyle(.capsule)
            .background { NavigationReplacementProbe(id: itemID) }
            .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

private struct NavigationReplacementProbe: UIViewRepresentable {

    let id: String

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.accessibilityIdentifier = "navigation-probe-\(id)"
    }
}
