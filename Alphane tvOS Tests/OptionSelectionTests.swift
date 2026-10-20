//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import JellyfinAPI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class OptionSelectionTests: XCTestCase {

    func testFilterPageInitiallyFocusesItsSelectedChoice() async throws {
        let trait = ItemTrait.supportedCases[1]
        let model = FilterViewModel(currentFilters: .init(traits: [trait]))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let controller = UIHostingController(rootView:
            NavigationInjectionView(coordinator: NavigationCoordinator(usesNavigationStack: true)) {
                FilterView(viewModel: model, type: .traits)
            }
            .preferredColorScheme(.dark)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(600))
        let focused = try XCTUnwrap(UIFocusSystem.focusSystem(for: window)?.focusedItem)
        let rect = focused.focusItemContainer?.coordinateSpace.convert(focused.frame, to: window) ?? focused.frame
        XCTAssertGreaterThan(rect.midX, 760, "The selected second-column option must receive focus, rather than the first cell")
        XCTAssertLessThan(rect.midX, 1160)
        XCTAssertEqual(model.currentFilters.traits, [trait], "Initial focus must not change the saved filter")
    }

    func testEnteringChoicesFocusesSelectionWithoutChangingIt() async throws {
        var selected = ["Drama"]
        var writes = 0
        var focused: String?
        let selector = TVOptionSelector(
            selection: Binding(get: { selected }, set: { selected = $0
                writes += 1
            }),
            sources: ["Action", "Comedy", "Drama"], type: .multi, onFocusChange: { focused = $0 }
        ) { Text($0) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let controller = UIHostingController(rootView: selector.padding(100).preferredColorScheme(.dark))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(focused, "Drama")
        XCTAssertEqual(selected, ["Drama"])
        XCTAssertEqual(writes, 0, "Focusing a choice must not apply it")
    }

    func testSortChoicesWriteThroughAndResetIsImmediatelyReflected() async {
        let model = FilterViewModel(currentFilters: .recent)
        let view = TVFilterContent(viewModel: model, type: .sortBy)
        let group = ItemFilterType.sortBy.group[1]
        let selector = TVOptionSelector(
            selection: view.selection(for: group), sources: model.allFilters[keyPath: group.keyPath], type: .single
        ) { Text($0.displayTitle) }
        let rating = AnyItemFilter(displayTitle: ItemSortBy.communityRating.displayTitle, value: ItemSortBy.communityRating.rawValue)

        selector.select(rating)
        XCTAssertEqual(model.currentFilters.sortBy, [.communityRating])
        XCTAssertEqual(model.currentFilters.sortOrder, [.descending])
        XCTAssertEqual(selector.preferredElement, rating)

        await model.reset(filterType: .sortBy)
        XCTAssertEqual(model.currentFilters.sortOrder, [.ascending])
        XCTAssertEqual(selector.selection.wrappedValue, ItemFilterCollection.default[keyPath: group.keyPath])
        XCTAssertEqual(selector.preferredElement?.value, ItemSortBy.sortName.rawValue)
    }

    func testMultiSelectTogglesWithoutChangingOtherFiltersAndHonorsExternalReset() async {
        let model = FilterViewModel(currentFilters: .favorites)
        let view = TVFilterContent(viewModel: model, type: .genres)
        let group = ItemFilterType.genres.group[0]
        let action = AnyItemFilter(displayTitle: "Action", value: "Action")
        let drama = AnyItemFilter(displayTitle: "Drama", value: "Drama")
        let selector = TVOptionSelector(selection: view.selection(for: group), sources: [action, drama], type: .multi) {
            Text($0.displayTitle)
        }

        selector.select(action)
        selector.select(drama)
        XCTAssertEqual(model.currentFilters.genres.map(\.value), ["Action", "Drama"])
        selector.select(action)
        XCTAssertEqual(model.currentFilters.genres.map(\.value), ["Drama"])
        XCTAssertEqual(model.currentFilters.traits, ItemFilterCollection.favorites.traits)

        await model.reset(filterType: .genres)
        XCTAssertTrue(selector.selection.wrappedValue.isEmpty)
        XCTAssertEqual(model.currentFilters.traits, ItemFilterCollection.favorites.traits)
    }

    func testFontBindingOnlyChangesWhenAChoiceIsApplied() {
        var font = "Helvetica Neue"
        let picker = TVFontPickerContent(selection: Binding(get: { font }, set: { font = $0 }))
        let selector = TVOptionSelector(selection: picker.fontSelection, sources: ["Arial", "Helvetica Neue"], type: .single) { Text($0) }
        XCTAssertEqual(selector.preferredElement, "Helvetica Neue")
        XCTAssertEqual(font, "Helvetica Neue")
        selector.select("Arial")
        XCTAssertEqual(font, "Arial")
        picker.fontSelection.wrappedValue = []
        XCTAssertEqual(font, "Arial", "An empty selection must not clear the subtitle font")
    }
}
