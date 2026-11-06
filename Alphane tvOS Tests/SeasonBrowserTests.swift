//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Combine
import FactoryKit
import JellyfinAPI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class SeasonBrowserTests: XCTestCase {

    private var fixtureSession: UserSession?
    private var sessionSubscription: AnyCancellable?

    override func setUp() async throws {
        try await super.setUp()
        let manager = FactoryKit.Container.shared.userSessionManager()
        await manager.start()
        FactoryKit.Container.shared.manager.push()
        sessionSubscription = manager.$state.dropFirst().sink { [weak self] _ in
            guard let session = self?.fixtureSession else { return }

            FactoryKit.Container.shared.currentUserSession.register { session }
        }
    }

    override func tearDown() async throws {
        sessionSubscription?.cancel()
        sessionSubscription = nil
        fixtureSession = nil
        FactoryKit.Container.shared.manager.pop()
        try await super.tearDown()
    }

    func testSeasonProgressCountsAvailableEpisodesOnlyAndKeepsCrossSeasonNext() {
        let first = episode(1)
        let finale = episode(9)
        let premiere = episode(1, season: 2)
        var missing = episode(10)
        missing.locationType = .virtual
        XCTAssertEqual(EpisodeContinuation.remainingInSeason(after: first, in: [first, finale, missing, premiere]), 1)
        XCTAssertEqual(EpisodeContinuation.remainingInSeason(after: finale, in: [first, finale, premiere]), 0)
        XCTAssertEqual(EpisodeContinuation.nextEpisode(after: finale, in: [first, finale, premiere])?.id, premiere.id)
        XCTAssertNil(EpisodeContinuation.nextEpisode(after: finale, in: [first, finale]))
        XCTAssertNil(EpisodeContinuation.remainingInSeason(after: finale, in: [first]))
        XCTAssertNil(EpisodeContinuation.remainingInSeason(after: BaseItemDto(id: "unknown"), in: [first]))
    }

    func testSeasonCountUsesFilenameOrderAndFallsBackToSeasonNumber() {
        var ninth = episode(9)
        ninth.indexNumber = nil
        var tenth = episode(10)
        tenth.indexNumber = nil
        XCTAssertEqual(EpisodeContinuation.remainingInSeason(after: ninth, in: [tenth, ninth]), 1)
        ninth.seasonID = nil
        tenth.seasonID = nil
        XCTAssertEqual(EpisodeContinuation.remainingInSeason(after: ninth, in: [tenth, ninth, episode(1, season: 2)]), 1)
    }

    func testCompleteCatalogueReadsEveryPageBeforeClaimingASeasonEnd() async throws {
        let session = makeSession()
        SeasonProtocol.reset(mode: .paged)
        let current = episode(200)
        let episodes = try await EpisodeContinuation.allAvailableEpisodes(for: current, userID: session.user.id, client: session.client)
        XCTAssertEqual(episodes.count, 205)
        XCTAssertEqual(EpisodeContinuation.remainingInSeason(after: current, in: episodes), 5)
        XCTAssertEqual(EpisodeContinuation.nextEpisode(after: current, in: episodes)?.id, "s1e201")
        XCTAssertEqual(SeasonProtocol.paths.count(where: { $0.contains("startIndex=200") }), 1)
    }

    func testIncompleteCatalogueFailsInsteadOfReportingLastEpisode() async {
        let session = makeSession()
        SeasonProtocol.reset(mode: .incomplete)
        do {
            _ = try await EpisodeContinuation.allAvailableEpisodes(for: episode(1), userID: session.user.id, client: session.client)
            XCTFail("An incomplete server response cannot establish a season boundary")
        } catch {}
    }

    func testDetailShowsSeasonBoundaryAndNextSeasonWithoutInventingAnEpisodeTen() async throws {
        let session = makeSession()
        SeasonProtocol.reset()
        let provider = ItemContentGroupProvider(item: episode(9))
        provider.userSession = session
        _ = try await provider.makeGroups(environment: .default)
        XCTAssertEqual(provider.remainingSeasonEpisodes, 0)
        XCTAssertEqual(provider.nextEpisodeItemProvider?.item.id, "s2e1")
        XCTAssertEqual(provider.item.userData?.isPlayed, true)
        SeasonProtocol.reset(mode: .incomplete)
        let failed = ItemContentGroupProvider(item: episode(9))
        failed.userSession = session
        _ = try await failed.makeGroups(environment: .default)
        XCTAssertNil(failed.remainingSeasonEpisodes, "A failed catalogue must not claim a season finale")
    }

    func testSeasonListRefreshRetainsLoadedEpisodeModelsAndUsesSeriesEndpoint() async throws {
        let session = makeSession()
        SeasonProtocol.reset()
        let model = PagingLibraryViewModel(library: SeasonViewModelLibrary(parent: series), userSession: session)
        await model.refresh()
        let season = try XCTUnwrap(model.elements.first)
        await season.refresh()
        let entry = try XCTUnwrap(season.elements.first)
        XCTAssertEqual(season.state, .content)
        var lostContent = false
        let subscription = season.$state.sink { state in
            if state != .content {
                lostContent = true
            }
        }
        defer { subscription.cancel() }
        for _ in 0 ..< 3 {
            await model.background.refresh()
        }
        XCTAssertTrue(model.elements.first === season)
        XCTAssertEqual(season.elements.first?.id, entry.id)
        XCTAssertFalse(lostContent)
        XCTAssertEqual(SeasonProtocol.paths.count(where: { $0.contains("/Episodes") }), 1)
        XCTAssertTrue(SeasonProtocol.paths.contains { $0.contains("/Shows/series/Episodes") && $0.contains("seasonId=season1") })
    }

    func testDetailGroupRebuildRetainsLoadedSeasonInsteadOfReplacingCards() async throws {
        let session = makeSession()
        SeasonProtocol.reset()
        let provider = ItemContentGroupProvider(item: series)
        provider.userSession = session
        let model = ContentGroupViewModel(provider: provider)
        await model.refresh()
        let before = try XCTUnwrap(model.groups.compactMap { $0 as? SeriesEpisodeContentGroup }.first)
        let season = try XCTUnwrap(before.viewModel.elements.first)
        await season.refresh()
        var observedEmpty = false
        let subscription = before.viewModel.$elements.sink {
            if $0.isEmpty {
                observedEmpty = true
            }
        }
        defer { subscription.cancel() }
        await model.refresh()
        let after = try XCTUnwrap(model.groups.compactMap { $0 as? SeriesEpisodeContentGroup }.first)
        XCTAssertTrue(before.viewModel === after.viewModel)
        XCTAssertTrue(after.viewModel.elements.first === season)
        XCTAssertFalse(observedEmpty, "A retained visible row must not turn back into placeholders")
        XCTAssertEqual(season.state, .content)
    }

    func testSeasonCacheDoesNotCrossUserSessions() throws {
        let first = makeSession()
        let second = makeSession()
        let library = SeasonViewModelLibrary(parent: series)
        let patches = try [ItemPatch.snapshot(BaseItemDto(id: "season1", name: "Season 1", seriesID: "series", type: .season))]
        let one = try library.materialize(patches, pageState: .init(pageOffset: 0, pageSize: 50, userSession: first))
        let two = try library.materialize(patches, pageState: .init(pageOffset: 0, pageSize: 50, userSession: second))
        XCTAssertFalse(one[0] === two[0])
        XCTAssertTrue(two[0].userSession === second)
    }

    func testNativeBrowserOpensCurrentSeasonAndRetainsFocusThroughRefresh() async throws {
        let session = makeSession()
        SeasonProtocol.reset()
        let model = PagingLibraryViewModel(library: SeasonViewModelLibrary(parent: series), userSession: session)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let detail = ItemContentGroupProvider(item: episode(9))
        detail.userSession = session
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: coordinator) {
                ItemView(provider: detail)
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
        for _ in 0 ..< 100 {
            if detail.remainingSeasonEpisodes != nil {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(detail.remainingSeasonEpisodes, 0)
        capture(window, name: "Episode detail - last available episode this season")
        coordinator.push(NavigationRoute(id: "seasons-series") {
            SeriesSeasonsView(episode: self.episode(1, season: 2), viewModel: model)
        })
        for _ in 0 ..< 100 {
            if model.elements.first(where: { $0.id == "season2" })?.state == .content,
               UIFocusSystem(for: window)?.focusedItem != nil
            {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        try await Task.sleep(for: .milliseconds(700))
        let season = try XCTUnwrap(model.elements.first(where: { $0.id == "season2" }))
        XCTAssertEqual(season.state, .content)
        let focus = try XCTUnwrap(UIFocusSystem(for: window)?.focusedItem)
        let initialFrame = focus.focusItemContainer?.coordinateSpace.convert(focus.frame, to: window) ?? focus.frame
        let episodeRequest = try XCTUnwrap(SeasonProtocol.paths.last { $0.contains("/Episodes") && $0.contains("seasonId=") })
        XCTAssertTrue(episodeRequest.contains("seasonId=season2"), "Native entry must activate the current season")
        capture(window, name: "Seasons browser - current Season 2")

        let cardFrame = initialFrame
        await model.background.refresh()
        await season.background.refresh()
        try await Task.sleep(for: .milliseconds(450))
        let restored = try XCTUnwrap(UIFocusSystem(for: window)?.focusedItem)
        let frame = restored.focusItemContainer?.coordinateSpace.convert(restored.frame, to: window) ?? restored.frame
        XCTAssertEqual(frame.minX, cardFrame.minX, accuracy: 2)
        XCTAssertEqual(frame.minY, cardFrame.minY, accuracy: 2)
        XCTAssertTrue(model.elements.first(where: { $0.id == "season2" }) === season)
        capture(window, name: "Seasons browser - focus retained after background refresh")
        if !coordinator.path.isEmpty {
            coordinator.path.removeLast()
        }
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNotNil(UIFocusSystem(for: window)?.focusedItem, "Back must restore usable detail focus")
        capture(window, name: "Episode detail - returned from Seasons")
    }

    private var series: BaseItemDto {
        .init(id: "series", name: "Sample series", type: .series)
    }

    private func episode(_ number: Int, season: Int = 1) -> BaseItemDto {
        BaseItemDto(
            id: "s\(season)e\(number)",
            indexNumber: number,
            name: "Ep\(number)_Title",
            parentIndexNumber: season,
            seasonID: "season\(season)",
            seriesID: "series",
            seriesName: "Sample series",
            type: .episode
        )
    }

    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeSession() -> UserSession {
        let url = URL(string: "https://season-browser.example")!
        let id = UUID().uuidString
        let session = UserSession(
            server: ServerState(urls: [url], currentURL: url, name: "Test", id: id, userIDs: [id]),
            user: UserState(id: id, serverID: id, username: "Sample profile")
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SeasonProtocol.self]
        session.client = JellyfinClient(
            configuration: .alphaneConfiguration(url: url, accessToken: "fixture"),
            sessionConfiguration: configuration
        )
        fixtureSession = session
        FactoryKit.Container.shared.currentUserSession.register { session }
        return session
    }
}

private final class SeasonProtocol: URLProtocol, @unchecked Sendable {
    enum Mode { case normal, paged, incomplete }
    private static let lock = NSLock()
    private nonisolated(unsafe) static var mode = Mode.normal
    private nonisolated(unsafe) static var requests: [String] = []
    static var paths: [String] {
        lock.withLock { requests }
    }

    static func reset(mode: Mode = .normal) {
        lock.withLock { Self.mode = mode
            requests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        let mode = Self.lock.withLock { Self.requests.append(url.absoluteString)
            return Self.mode
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            query.first { $0.name.lowercased() == name.lowercased() }?.value
        }
        var object: Any = ["Items": [], "TotalRecordCount": 0]
        if url.path.hasSuffix("/Seasons") {
            object = ["Items": (1 ... 2).map { ["Id": "season\($0)", "Name": "Season \($0)", "Type": "Season", "SeriesId": "series"] }]
        } else if url.path.hasSuffix("/Episodes") {
            let offset = Int(value("startIndex") ?? "0") ?? 0
            let season = value("seasonId") == "season2" ? 2 : 1
            let count = mode == .paged ? 205 : mode == .incomplete ? 201 : 9
            let upper = min(offset + (Int(value("limit") ?? "200") ?? 200), count)
            let range = mode == .incomplete && offset > 0 ? 0 ..< 0 : offset ..< upper
            var items: [[String: Any]] = range.map { number in
                [
                    "Id": "s\(season)e\(number + 1)",
                    "Name": "Episode \(number + 1)",
                    "Type": "Episode",
                    "IndexNumber": number + 1,
                    "SeriesId": "series",
                    "SeriesName": "Sample series",
                    "SeasonId": "season\(season)",
                    "ParentIndexNumber": season,
                    "Overview": "A sample episode description. No playback or watch history is used."
                ] as [String: Any]
            }
            if mode == .normal, value("seasonId") == nil {
                items.append([
                    "Id": "s2e1",
                    "Name": "Season 2 premiere",
                    "Type": "Episode",
                    "IndexNumber": 1,
                    "SeriesId": "series",
                    "SeriesName": "Sample series",
                    "SeasonId": "season2",
                    "ParentIndexNumber": 2
                ])
            }
            object = ["Items": items, "TotalRecordCount": mode == .normal ? items.count : count]
        } else if url.path.hasSuffix("/Items/series") {
            object = ["Id": "series", "Name": "Sample series", "Type": "Series"]
        } else if url.path.hasSuffix("/Items/s1e9") {
            object = [
                "Id": "s1e9",
                "Name": "Season finale",
                "Type": "Episode",
                "IndexNumber": 9,
                "SeriesId": "series",
                "SeriesName": "Sample series",
                "SeasonId": "season1",
                "ParentIndexNumber": 1,
                "UserData": ["Played": true, "PlaybackPositionTicks": 0, "Key": "s1e9"]
            ] as [String: Any]
        } else if url.path.hasSuffix("/LocalTrailers") || url.path.hasSuffix("/SpecialFeatures") {
            object = [Any]()
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: object))
        client?.urlProtocolDidFinishLoading(self)
    }
}
