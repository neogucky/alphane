//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class PlaybackEntryTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await FactoryKit.Container.shared.userSessionManager().start()
        FactoryKit.Container.shared.manager.push()
        // These local providers need no login. Presentation-only item records
        // must not belong to a real session that the host can invalidate.
        FactoryKit.Container.shared.currentUserSession.register { nil }
    }

    override func tearDown() async throws {
        FactoryKit.Container.shared.manager.pop()
        try await super.tearDown()
    }

    func testBackCancelsPreparationAndReturnsToThePreviousPage() async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        let factories = FactoryKit.Container.shared.manager
        factories.push()
        let playerType = Defaults[.VideoPlayer.videoPlayerType]
        let confirmClose = Defaults[.confirmClose]
        Defaults[.VideoPlayer.videoPlayerType] = .avPlayer
        Defaults[.confirmClose] = true
        defer {
            factories.pop()
            Defaults[.VideoPlayer.videoPlayerType] = playerType
            Defaults[.confirmClose] = confirmClose
        }
        var preparationWasCancelled = false
        let manager = MediaPlayerManager(provider: .init(
            item: BaseItemDto(id: UUID().uuidString, name: "Stalled sample video", type: .movie)
        ) { _, _ in
            do {
                try await Task.sleep(for: .seconds(300))
            } catch {
                preparationWasCancelled = true
                throw error
            }
            throw CancellationError()
        })
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: coordinator) {
                Button("Returned from loading") {}
                    .buttonStyle(.capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AlphaneTheme.background)
            }
            .preferredColorScheme(.dark)
            .recoveringMissingFocus()
            .environment(\.scenePhase, .active))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(200))
        coordinator.push(.videoPlayer(manager: manager))
        for _ in 0 ..< 100 {
            if let container = findContainer(window.rootViewController), container.children.count > 3 {
                break
            }
            try await Task.sleep(for: .milliseconds(30))
        }
        let container = try XCTUnwrap(findContainer(window.rootViewController))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(manager.state, .loadingItem)
        XCTAssertEqual(container.viewState.presentation, .controls)
        XCTAssertTrue(container.viewState.visibleElements.isEmpty)
        let warning = XCTExpectedFailure.Options()
        warning.isStrict = false
        warning.issueMatcher = {
            $0.compactDescription.contains("State warning: A new transition action started while another transition action is in progress!")
        }
        XCTExpectFailure("Back intentionally supersedes pending preparation.", options: warning)

        // Invoke the same selector installed on the player's native Back recognizer.
        let action = NSSelectorFromString("handleMenuEnded")
        XCTAssertTrue(container.responds(to: action))
        container.perform(action)
        for _ in 0 ..< 80 {
            if manager.state == .stopped, coordinator.presentedFullScreen == nil {
                break
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(manager.state, .stopped, "One Back press must cancel startup, without waiting for controls or confirmation")
        XCTAssertTrue(preparationWasCancelled)
        XCTAssertNil(coordinator.presentedFullScreen)
        XCTAssertNotNil(UIFocusSystem(for: window)?.focusedItem, "The previous page must regain usable native focus")
        XCTAssertFalse(container.viewState.isPresentingCloseConfirmation)
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = "Back during stalled playback preparation"
        attachment.lifetime = .keepAlways
        add(attachment)
        if manager.state != .stopped {
            await manager.stop()
        }
    }

    func testLoadingIsVisibleDuringPresentationBeforeTheVideoSurfaceAppears() async throws {
        let factories = FactoryKit.Container.shared.manager
        factories.push()
        let playerType = Defaults[.VideoPlayer.videoPlayerType]
        Defaults[.VideoPlayer.videoPlayerType] = .avPlayer
        defer {
            factories.pop()
            Defaults[.VideoPlayer.videoPlayerType] = playerType
        }

        // No artwork, stream or server: startup must cover even this worst case.
        let manager = MediaPlayerManager(provider: .init(
            item: BaseItemDto(id: UUID().uuidString, name: "Local loading test", type: .movie)
        ) { _, _ in
            try await Task.sleep(for: .seconds(30))
            throw CancellationError()
        })
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: coordinator) { Color.black.ignoresSafeArea() }
                .preferredColorScheme(.dark))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(150))
        coordinator.push(.videoPlayer(manager: manager))

        var brightestOpeningFrame = 0
        for _ in 0 ..< 30 {
            try await Task.sleep(for: .milliseconds(25))
            guard let container = findContainer(window.rootViewController) else { continue }

            // The three control/supplement hosts exist during opening; the
            // fourth child (video) is deliberately added only in viewDidAppear.
            if container.children.count > 3 {
                break
            }

            brightestOpeningFrame = try max(brightestOpeningFrame, loadingSymbolPixels(in: window))
        }

        // Stop intentionally interrupts the sleeping provider. Expect only the
        // dependency's known overlapping-transition diagnostic, as in PlaybackLoadingTests.
        let warning = XCTExpectedFailure.Options()
        warning.issueMatcher = {
            $0.compactDescription.contains("State warning: A new transition action started while another transition action is in progress!")
        }
        XCTExpectFailure("Stop intentionally supersedes pending preparation.", options: warning)
        await manager.stop()

        XCTAssertGreaterThan(
            brightestOpeningFrame,
            25,
            "Loading symbols must be rendered before the video host appears, not a blank black screen"
        )
        XCTAssertFalse(manager.hasPresentedVideoFrame)
        XCTAssertEqual(manager.state, .stopped)
    }

    private func findContainer(_ controller: UIViewController?) -> VideoPlayer.UIContainerViewController? {
        guard let controller else { return nil }

        if let container = controller as? VideoPlayer.UIContainerViewController {
            return container
        }
        if let presented = findContainer(controller.presentedViewController) {
            return presented
        }
        return controller.children.compactMap { findContainer($0) }.first
    }

    private func loadingSymbolPixels(in window: UIWindow) throws -> Int {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 0.25
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        // Only the central loading symbols, excluding titles, controls and OS chrome.
        let symbols = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: 175, y: 117, width: 125, height: 35)))
        var luminance = [UInt8](repeating: 0, count: symbols.width * symbols.height)
        try luminance.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress, width: symbols.width, height: symbols.height,
                bitsPerComponent: 8, bytesPerRow: symbols.width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ))
            context.draw(symbols, in: CGRect(x: 0, y: 0, width: symbols.width, height: symbols.height))
        }
        return luminance.count { $0 > 70 }
    }
}
