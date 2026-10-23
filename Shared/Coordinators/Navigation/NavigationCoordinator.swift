//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

@MainActor
final class NavigationCoordinator: ObservableObject {

    struct PresentedRoute: Identifiable {

        let route: NavigationRoute
        let coordinator: NavigationCoordinator

        var id: String {
            route.id
        }
    }

    @Published
    var path: [NavigationRoute] = [] {
        didSet {
            #if os(tvOS)
            if path.count < oldValue.count {
                focusStore.restore(path.last?.id ?? "root")
            } else if path.count > oldValue.count {
                focusStore.beginNavigation()
            }
            #endif
        }
    }

    #if os(tvOS)
    let focusStore = NavigationFocusStore()

    @Published
    private(set) var fullScreenDismissalRevision = 0

    func fullScreenDidDismiss() {
        fullScreenDismissalRevision += 1
    }
    #endif

    @Published
    var presentedSheet: PresentedRoute?
    @Published
    var presentedFullScreen: PresentedRoute?

    let usesNavigationStack: Bool

    init(usesNavigationStack: Bool = false) {
        self.usesNavigationStack = usesNavigationStack
    }

    func push(
        _ route: NavigationRoute
    ) {
        if let presentedCoordinator = presentedFullScreen?.coordinator ?? presentedSheet?.coordinator {
            presentedCoordinator.push(route)
            return
        }

        switch route.transitionStyle {
        case .push where usesNavigationStack:
            path.append(route)

        case .push, .sheet:
            presentedSheet = .init(
                route: route,
                coordinator: .init()
            )

        case .fullscreen:
            presentedFullScreen = .init(
                route: route,
                coordinator: .init()
            )
        }
    }

    /// Continue within the current detail destination without adding a Back step.
    func replaceLast(with route: NavigationRoute) {
        if let presentedCoordinator = presentedFullScreen?.coordinator ?? presentedSheet?.coordinator {
            presentedCoordinator.replaceLast(with: route)
            return
        }

        guard case .push = route.transitionStyle, usesNavigationStack, !path.isEmpty else {
            push(route)
            return
        }

        #if os(tvOS)
        focusStore.beginNavigation()
        #endif
        path[path.count - 1] = route
    }
}
