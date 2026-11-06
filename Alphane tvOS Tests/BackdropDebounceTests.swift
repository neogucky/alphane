//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import FactoryKit
import Nuke
import SwiftUI
import UIKit
import XCTest

@MainActor
final class BackdropDebounceTests: XCTestCase {
    func testRapidFocusChangesOnlyLoadTheSettledBackdrop() async throws {
        try await withFixture { model, _ in
            try await self.waitForImage("initial")
            model.request = self.request("skipped-first")
            try await Task.sleep(for: .milliseconds(20))
            model.request = self.request("skipped-second")
            try await Task.sleep(for: .milliseconds(20))
            let settledAt = Date()
            model.request = self.request("settled")
            try await self.waitForImage("settled")

            let requests = BackdropImageProtocol.requests
            XCTAssertEqual(requests.map(\.path), ["/initial", "/settled"])
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(requests.last).date.timeIntervalSince(settledAt), 0.09)
        }
    }

    func testChangingArtworkForTheSamePosterStillUpdatesIt() async throws {
        try await withFixture { model, _ in
            try await self.waitForImage("initial")
            let refreshed = self.request("refreshed")
            model.request = .init(posterID: model.request.posterID, sources: refreshed.sources)
            try await self.waitForImage("refreshed")
            XCTAssertEqual(BackdropImageProtocol.requests.map(\.path), ["/initial", "/refreshed"])
        }
    }

    func testLeavingTheViewCancelsItsPendingBackdrop() async throws {
        try await withFixture { model, window in
            try await self.waitForImage("initial")
            model.request = self.request("cancelled")
            try await Task.sleep(for: .milliseconds(20))
            window.rootViewController = nil
            try await Task.sleep(for: .milliseconds(200))
            XCTAssertEqual(BackdropImageProtocol.requests.map(\.path), ["/initial"])
        }
    }

    private func request(_ id: String) -> FocusedPosterCinematicBackgroundView.BackdropRequest {
        .init(
            posterID: .init(posterType: ObjectIdentifier(Self.self), value: AnyHashable(id)),
            sources: [ImageSource(url: URL(string: "https://backdrop.example/" + id))]
        )
    }

    private func waitForImage(_ path: String) async throws {
        for _ in 0 ..< 100 {
            if BackdropImageProtocol.requests.contains(where: { $0.path == "/" + path }) {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("No backdrop request for \(path)")
    }

    private func withFixture(_ action: (BackdropFixtureModel, UIWindow) async throws -> Void) async throws {
        await FactoryKit.Container.shared.userSessionManager().start()
        BackdropImageProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackdropImageProtocol.self]
        let previousPipeline = ImagePipeline.shared
        ImagePipeline.shared = ImagePipeline {
            $0.dataLoader = DataLoader(configuration: configuration)
            $0.imageCache = ImageCache()
        }
        defer { ImagePipeline.shared = previousPipeline }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let model = BackdropFixtureModel(request: request("initial"))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView: BackdropFixture(model: model))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        try await action(model, window)
    }
}

@MainActor
private final class BackdropFixtureModel: ObservableObject {
    @Published
    var request: FocusedPosterCinematicBackgroundView.BackdropRequest

    init(request: FocusedPosterCinematicBackgroundView.BackdropRequest) {
        self.request = request
    }
}

private struct BackdropFixture: View {
    @ObservedObject
    var model: BackdropFixtureModel

    var body: some View {
        FocusedPosterCinematicBackgroundView.SettledBackdrop(request: model.request)
    }
}

private final class BackdropImageProtocol: URLProtocol, @unchecked Sendable {
    struct Request {
        let path: String
        let date: Date
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var recorded: [Request] = []

    static var requests: [Request] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        recorded = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "backdrop.example"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        Self.lock.lock()
        Self.recorded.append(.init(path: url.path, date: .now))
        Self.lock.unlock()
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
