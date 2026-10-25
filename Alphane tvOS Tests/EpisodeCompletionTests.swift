//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Combine
import Defaults
import FactoryKit
import Get
import JellyfinAPI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class EpisodeCompletionTests: XCTestCase {

    func testRepeatedTrackAndSourceSelectionsDoNotRepublishThePlaybackProvider() async {
        let session = makeStubSession(userID: "tracks-\(UUID().uuidString)")
        let provider = ItemContentGroupProvider(item: episode("episode"))
        provider.userSession = session
        let model = ContentGroupViewModel(provider: provider)
        await model.refresh()
        XCTAssertEqual(model.state, .content)
        var publications = 0
        let subscription = provider.$mediaPlayerItemProvider.dropFirst().sink { _ in publications += 1 }
        defer { subscription.cancel() }

        provider.select(.audioStreamIndex(2))
        provider.select(.audioStreamIndex(2))
        provider.select(.subtitleStreamIndex(3))
        provider.select(.subtitleStreamIndex(3))
        XCTAssertEqual(publications, 2)
        provider.select(.mediaSource(provider.mediaPlayerItemProvider?.mediaSource))
        XCTAssertEqual(provider.mediaPlayerItemProvider?.audioStreamIndex, 2)
        XCTAssertEqual(provider.mediaPlayerItemProvider?.subtitleStreamIndex, 3)
        XCTAssertEqual(publications, 2, "Picker writeback of the current source must not reset tracks")
        if let bitrate = provider.mediaPlayerItemProvider?.requestedBitrate {
            provider.select(.bitrate(bitrate))
        }
        XCTAssertEqual(publications, 2)
        provider.select(.subtitleStreamIndex(-1))
        provider.select(.subtitleStreamIndex(-1))
        XCTAssertEqual(publications, 3)
        XCTAssertEqual(provider.mediaPlayerItemProvider?.subtitleStreamIndex, -1)
    }

    func testRetainedDetailPageFocusesNextAfterCompletionAndResumeAfterPartialRewatch() async throws {
        // Finish the host app's session initialization before overriding its
        // factories; a later startup reset would otherwise discard this fixture.
        let sessionManager = FactoryKit.Container.shared.userSessionManager()
        await sessionManager.start()
        let factories = FactoryKit.Container.shared.manager
        factories.push()
        defer { factories.pop() }
        let session = makeStubSession(userID: "focus-\(UUID().uuidString)")
        let previousUserData = session.user.data
        session.user.data = UserDto(id: session.user.id, policy: UserPolicy(
            authenticationProviderID: "test", enableMediaPlayback: true, passwordResetProviderID: "test"
        ))
        defer { session.user.data = previousUserData }
        FactoryKit.Container.shared.currentUserSession.register { session }
        let provider = ItemContentGroupProvider(item: episode("episode"))
        provider.userSession = session
        // The host's concurrent launch/foreground transition can reset Factory
        // after start() returns. Keep this native fixture on its isolated session.
        let sessionSubscription = sessionManager.$state.dropFirst().sink { _ in
            FactoryKit.Container.shared.currentUserSession.register { session }
            provider.userSession = session
        }
        defer { sessionSubscription.cancel() }
        let coordinator = NavigationCoordinator(usesNavigationStack: true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        window.rootViewController = UIHostingController(rootView:
            NavigationInjectionView(coordinator: coordinator) { ItemView(provider: provider) }
                .preferredColorScheme(.dark))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
        }
        for _ in 0 ..< 60 {
            if provider.mediaPlayerItemProvider != nil, provider.nextEpisodeItemProvider != nil {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(provider.mediaPlayerItemProvider)
        XCTAssertNotNil(provider.nextEpisodeItemProvider)
        XCTAssertTrue(provider.item.presentPlayButton)
        XCTAssertTrue(provider.userSession === session, "The native fixture must retain its fake session")
        XCTAssertTrue(provider.$item.item === session.items["episode"], "Playback must update the displayed session record")
        let initialItemRecord = provider.$item.item

        let stops = [
            (name: "natural-end", naturalEnd: true, serverCompletes: false, delayed: false),
            (name: "partial-rewatch", naturalEnd: false, serverCompletes: false, delayed: false),
            (name: "credits-before-dismissal", naturalEnd: false, serverCompletes: true, delayed: false),
            (name: "partial-rewatch-again", naturalEnd: false, serverCompletes: false, delayed: false),
            (name: "credits-after-dismissal", naturalEnd: false, serverCompletes: true, delayed: true),
            (name: "natural-end-again", naturalEnd: true, serverCompletes: false, delayed: false),
        ]
        for stop in stops {
            // The real player uses this same full-screen route. No stream,
            // server progress report or real watch history is needed here.
            coordinator.push(NavigationRoute(id: "focus-test-player", style: .fullscreen) {
                Color.black.ignoresSafeArea().focusable()
            })
            try await Task.sleep(for: .milliseconds(700))
            var report = PlaybackStopInfo()
            report.itemID = "episode"
            report.positionTicks = Duration.seconds(stop.naturalEnd ? 120 : stop.serverCompletes ? 110 : 38).ticks
            XCTAssertTrue(provider.userSession === session, stop.name)
            XCTAssertTrue(session.items.isActive, stop.name)
            XCTAssertTrue(provider.$item.item === session.items["episode"], stop.name)
            XCTAssertTrue(provider.prepareForPlaybackStop(report, didReachEnd: stop.naturalEnd))
            XCTAssertEqual(provider.shouldFocusNextEpisode, stop.naturalEnd, stop.name)
            func serverCompletesEpisode() throws {
                var data = UserItemDataDto(key: "episode")
                data.itemID = "episode"
                data.isPlayed = true
                data.playbackPositionTicks = 0
                data.playedPercentage = 100
                try session.items.mergeUserData(data, token: session.items.beginRequest())
            }
            if stop.serverCompletes, !stop.delayed {
                try serverCompletesEpisode()
            }
            coordinator.presentedFullScreen = nil
            try await Task.sleep(for: .milliseconds(900))
            if stop.serverCompletes, stop.delayed {
                let focus = try XCTUnwrap(UIFocusSystem.focusSystem(for: window)?.focusedItem)
                let rect = focus.focusItemContainer?.coordinateSpace.convert(focus.frame, to: window) ?? focus.frame
                XCTAssertLessThan(rect.maxX, 1000, "Resume stays focused until Jellyfin confirms completion")
                try serverCompletesEpisode()
                try await Task.sleep(for: .milliseconds(300))
            }
            XCTAssertEqual(provider.shouldFocusNextEpisode, stop.naturalEnd || stop.serverCompletes, stop.name)
            let focus = try XCTUnwrap(UIFocusSystem.focusSystem(for: window)?.focusedItem)
            let rect = focus.focusItemContainer?.coordinateSpace.convert(focus.frame, to: window) ?? focus.frame
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let capture = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: capture)
            attachment.name = stop.name
            attachment.lifetime = .keepAlways
            add(attachment)
            if stop.naturalEnd || stop.serverCompletes {
                XCTAssertGreaterThan(
                    rect.minX,
                    1400,
                    "\(stop.name): the next-episode thumbnail must actually receive native focus after dismissal"
                )
                XCTAssertEqual(provider.mediaPlayerItemProvider?.item.playButtonLabel, L10n.playAgain)
            } else {
                XCTAssertLessThan(rect.maxX, 1000, "An unfinished rewatch must focus Resume instead of Next")
                XCTAssertGreaterThan(rect.width, 160, "Focus must be on Resume, not the watched/liked icons")
                XCTAssertNotNil(provider.mediaPlayerItemProvider?.item.progressLabel)
            }
            XCTAssertTrue(provider.$item.item === initialItemRecord, "Focus restoration must not reload the detail page")
        }
    }

    func testAutomaticEndingPreparesNextBeforeAcknowledgementWithoutReloadingThePage() async {
        // This can be the first test in a scoped run; host startup must not
        // reset the fixture's session injection while its requests are running.
        await FactoryKit.Container.shared.userSessionManager().start()
        let factories = FactoryKit.Container.shared.manager
        factories.push()
        defer { factories.pop() }
        let previous = Defaults[.sendProgressReports]
        Defaults[.sendProgressReports] = true
        defer { Defaults[.sendProgressReports] = previous }
        let session = makeStubSession()
        FactoryKit.Container.shared.currentUserSession.register { session }
        let provider = ItemContentGroupProvider(item: episode("episode"))
        provider.userSession = session
        let viewModel = ContentGroupViewModel(provider: provider)
        await viewModel.refresh()
        XCTAssertEqual(viewModel.state, .content, String(describing: viewModel.error))
        XCTAssertEqual(provider.nextEpisodeItemProvider?.item.id, "next")
        XCTAssertFalse(provider.shouldFocusNextEpisode)
        let groups = viewModel.groups.map(\.id)
        XCTAssertFalse(groups.isEmpty)
        var showedLoading = false
        let stateSubscription = viewModel.$state.sink { state in
            if state != .content {
                showedLoading = true
            }
        }
        defer { stateSubscription.cancel() }
        let sharedItem = provider.$item.item
        provider.select(.audioStreamIndex(2))

        let (manager, observer) = makePlaybackSession(sourceRuntime: .seconds(60))
        // The engine's last clock is behind both its file runtime and metadata.
        manager.seconds = .seconds(38)
        let started = expectation(description: "Stop awaiting acknowledgement")
        observer.onStopRequest = { started.fulfill() }
        await manager.ended()
        await fulfillment(of: [started], timeout: 2)

        XCTAssertEqual(observer.stopInfo?.positionTicks, Duration.seconds(60).ticks)
        XCTAssertEqual(provider.item.userData?.isPlayed, true)
        XCTAssertEqual(provider.item.userData?.playbackPositionTicks, 0)
        XCTAssertTrue(provider.shouldFocusNextEpisode)
        XCTAssertTrue(provider.$item.item === sharedItem)
        XCTAssertEqual(provider.mediaPlayerItemProvider?.audioStreamIndex, 2)

        let acknowledged = expectation(description: "Server acknowledged Stop")
        let subscription = Notifications[.didSendStopReport].publisher.sink { _ in acknowledged.fulfill() }
        defer { subscription.cancel() }
        observer.completeStopReport()
        await fulfillment(of: [acknowledged], timeout: 2)
        viewModel.refreshIfPendingChanges()
        await Task.yield()
        XCTAssertEqual(viewModel.state, .content)
        XCTAssertEqual(viewModel.groups.map(\.id), groups)
        XCTAssertFalse(showedLoading)
        XCTAssertEqual(provider.mediaPlayerItemProvider?.audioStreamIndex, 2)
        XCTAssertTrue(provider.shouldFocusNextEpisode)
    }

    func testStaleServerStateIsPersistedWithoutRestoringResumeOnTheSharedRecord() async throws {
        let session = makeStubSession()
        let entry = try await session.getFullItem(id: "episode")
        var report = PlaybackStopInfo()
        report.itemID = "episode"
        report.positionTicks = Duration.seconds(60).ticks
        try PlaybackCompletion.applyStop(report, didReachEnd: true, to: entry, in: session.items)

        let playbackItem = try MediaPlayerItem(
            baseItem: entry.snapshot,
            mediaSource: MediaSourceInfo(id: "source"),
            playSessionID: "session",
            url: XCTUnwrap(URL(string: "https://completion.example/video")),
            deviceProfile: DeviceProfile()
        )
        let observer = MediaProgressObserver(item: playbackItem)
        observer.userSession = session
        var restoredResume = false
        let subscription = session.items.changes.sink { _ in
            if entry.snapshot.userData?.isPlayed != true || entry.snapshot.userData?.playbackPositionTicks != 0 {
                restoredResume = true
            }
        }
        defer { subscription.cancel() }

        await observer.settlePlaybackState(for: entry.snapshot, stoppedAt: report.positionTicks, didReachEnd: true)
        XCTAssertFalse(restoredResume)
        XCTAssertEqual(entry.snapshot.userData?.isPlayed, true)
        XCTAssertEqual(entry.snapshot.userData?.playbackPositionTicks, 0)
        XCTAssertEqual(entry.snapshot.userData?.playCount, 1, "Jellyfin's mark-played endpoint must confirm completion")
    }

    func testStopWaitsForAnOlderInFlightProgressReport() async throws {
        let previous = Defaults[.sendProgressReports]
        Defaults[.sendProgressReports] = true
        defer { Defaults[.sendProgressReports] = previous }
        let progressStarted = expectation(description: "Older progress in flight")
        let stopStarted = expectation(description: "Final stop follows progress")
        let (manager, observer) = makePlaybackSession()
        observer.onProgressRequest = { progressStarted.fulfill() }
        observer.onStopRequest = { stopStarted.fulfill() }
        try observer.sendProgressReport(for: XCTUnwrap(manager.playbackItem), seconds: .seconds(90))
        await fulfillment(of: [progressStarted], timeout: 2)
        await manager.stop()
        await Task.yield()
        XCTAssertNil(observer.stopInfo, "Stop must not race an older progress request")
        observer.completeProgressReport()
        await fulfillment(of: [stopStarted], timeout: 2)
        XCTAssertEqual(observer.stopInfo?.positionTicks, Duration.seconds(120).ticks)
        observer.completeStopReport()
    }

    func testHomeRefreshWaitsForFinalWatchedStateAfterAcknowledgement() async {
        let previous = Defaults[.sendProgressReports]
        Defaults[.sendProgressReports] = true
        defer { Defaults[.sendProgressReports] = previous }
        let stopStarted = expectation(description: "Stop report in flight")
        let settling = expectation(description: "Waiting for watched state")
        let refreshed = expectation(description: "Home can now refresh")
        var refreshCount = 0
        let subscription = Notifications[.didSendStopReport].publisher.sink { _ in
            refreshCount += 1
            refreshed.fulfill()
        }
        defer { subscription.cancel() }
        let (manager, observer) = makePlaybackSession()
        observer.onStopRequest = { stopStarted.fulfill() }
        observer.onSettlementRequest = { settling.fulfill() }
        await manager.stop()
        await fulfillment(of: [stopStarted], timeout: 2)
        observer.completeStopReport()
        await fulfillment(of: [settling], timeout: 2)
        XCTAssertEqual(refreshCount, 0)
        observer.completeSettlement()
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertEqual(refreshCount, 1)
    }

    func testStopReportRefreshWaitsForServerAcknowledgement() async {
        let previousSendProgressReports = Defaults[.sendProgressReports]
        Defaults[.sendProgressReports] = true
        defer { Defaults[.sendProgressReports] = previousSendProgressReports }

        let reportStarted = expectation(description: "Stop report sent")
        let refreshReceived = expectation(description: "Playback refresh received")
        var refreshCount = 0
        let subscription = Notifications[.didSendStopReport].publisher.sink { _ in
            refreshCount += 1
            refreshReceived.fulfill()
        }
        defer { subscription.cancel() }

        let (manager, observer) = makePlaybackSession()
        observer.onStopRequest = { reportStarted.fulfill() }
        await manager.stop()
        await fulfillment(of: [reportStarted], timeout: 2)

        XCTAssertEqual(refreshCount, 0, "Fetching Next Up before acknowledgement would return stale progress")
        XCTAssertEqual(observer.stopInfo?.itemID, "episode")
        XCTAssertEqual(observer.stopInfo?.positionTicks, Duration.seconds(120).ticks)
        XCTAssertEqual(observer.stopInfo?.playSessionID, "session")

        observer.completeStopReport()
        await fulfillment(of: [refreshReceived], timeout: 2)
        XCTAssertEqual(refreshCount, 1)
    }

    func testFailedStopReportDoesNotAnnounceSavedProgress() async {
        let previousSendProgressReports = Defaults[.sendProgressReports]
        Defaults[.sendProgressReports] = true
        defer { Defaults[.sendProgressReports] = previousSendProgressReports }

        let reportStarted = expectation(description: "Stop report sent")
        let refreshReceived = expectation(description: "No refresh for unsaved progress")
        refreshReceived.isInverted = true
        let subscription = Notifications[.didSendStopReport].publisher.sink { _ in
            refreshReceived.fulfill()
        }
        defer { subscription.cancel() }

        let (manager, observer) = makePlaybackSession()
        observer.onStopRequest = { reportStarted.fulfill() }
        await manager.stop()
        await fulfillment(of: [reportStarted], timeout: 2)

        observer.completeStopReport(throwing: URLError(.cannotConnectToHost))
        await fulfillment(of: [refreshReceived], timeout: 0.2)
    }

    func testPlaybackReportRefreshesGroupsEvenAfterAnImmediateReturn() async {
        let groupViewModel = RecordingRefreshViewModel()
        let viewModel = ContentGroupViewModel(provider: RecordingProvider(viewModel: groupViewModel))
        await viewModel.refresh()
        XCTAssertEqual(groupViewModel.refreshCount, 1)

        viewModel.refreshIfNeeded(sinceLastDisappear: 0)
        await Task.yield()
        XCTAssertEqual(groupViewModel.refreshCount, 1)

        let refreshed = expectation(description: "Content refreshed after playback")
        groupViewModel.onRefresh = { refreshed.fulfill() }
        var report = PlaybackStopInfo()
        report.itemID = "episode"
        Notifications[.didSendStopReport].post(report)
        viewModel.refreshIfNeeded(sinceLastDisappear: 0)
        await fulfillment(of: [refreshed], timeout: 2)
        XCTAssertEqual(groupViewModel.refreshCount, 2)
    }

    func testNextEpisodeAtStartAndMiddleOfSeries() {
        let first = episode("first")
        let current = episode("current")
        let next = episode("next")

        XCTAssertEqual(ItemContentGroupProvider.nextEpisode(after: first, in: [first, current])?.id, current.id)
        XCTAssertEqual(ItemContentGroupProvider.nextEpisode(after: current, in: [first, current, next])?.id, next.id)
    }

    func testFinalEpisodeDoesNotReplayOrWrapAround() {
        let previous = episode("previous")
        let final = episode("final")

        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: final, in: [previous, final]))
        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: final, in: [final]))
        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: final, in: []))
        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: final, in: [previous]))
    }

    func testNextEpisodeCanCrossSeasonBoundary() {
        var finale = episode("season-one-finale")
        finale.parentIndexNumber = 1
        var premiere = episode("season-two-premiere")
        premiere.parentIndexNumber = 2

        XCTAssertEqual(ItemContentGroupProvider.nextEpisode(after: finale, in: [finale, premiere])?.id, premiere.id)
    }

    func testMissingEpisodeDoesNotOfferUnplayableNextAction() {
        let current = episode("current")
        var missing = episode("missing")
        missing.locationType = .virtual

        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: current, in: [current, missing]))
        XCTAssertNil(ItemContentGroupProvider.nextEpisode(after: current, in: [current, BaseItemDto(id: "series", type: .series)]))
    }

    private func episode(_ id: String) -> BaseItemDto {
        BaseItemDto(id: id, seriesID: "series", type: .episode)
    }

    private func makePlaybackSession(sourceRuntime: Duration? = nil) -> (MediaPlayerManager, RecordingProgressObserver) {
        var item = episode("episode")
        item.runTimeTicks = Duration.seconds(120).ticks
        let playbackItem = MediaPlayerItem(
            baseItem: item,
            mediaSource: MediaSourceInfo(id: "source", runTimeTicks: sourceRuntime?.ticks),
            playSessionID: "session",
            url: URL(string: "http://localhost/video")!,
            deviceProfile: DeviceProfile()
        )
        let observer = RecordingProgressObserver(item: playbackItem)
        playbackItem.observers = [observer]
        let manager = MediaPlayerManager(playbackItem: playbackItem)
        observer.manager = manager
        manager.seconds = .seconds(120)
        return (manager, observer)
    }

    private func makeStubSession(userID: String = "user") -> UserSession {
        let url = URL(string: "https://completion.example")!
        let session = UserSession(
            server: ServerState(urls: [url], currentURL: url, name: "Test", id: "server", userIDs: [userID]),
            user: UserState(id: userID, serverID: "server", username: "User")
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CompletionProtocol.self]
        session.client = JellyfinClient(
            configuration: .alphaneConfiguration(url: url, accessToken: "test-token"),
            sessionConfiguration: configuration
        )
        return session
    }
}

private final class CompletionProtocol: URLProtocol, @unchecked Sendable {

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func stopLoading() {}

    override func startLoading() {
        let path = request.url!.path
        let json: String = if path.contains("/UserPlayedItems/") {
            #"{"ItemId":"episode","Key":"episode","Played":true,"PlaybackPositionTicks":0,"PlayedPercentage":100,"PlayCount":1}"#
        } else if path.hasSuffix("/Items/episode") {
            #"{"Id":"episode","Name":"Current episode","Type":"Episode","SeriesId":"series","IndexNumber":1,"Genres":["Drama"],"RunTimeTicks":1200000000,"UserData":{"Key":"episode","Played":false,"PlaybackPositionTicks":380000000}}"#
        } else if path.hasSuffix("/Episodes") {
            #"{"Items":[{"Id":"episode","Type":"Episode","SeriesId":"series","IndexNumber":1},{"Id":"next","Name":"Next episode","Type":"Episode","SeriesId":"series","IndexNumber":2}]}"#
        } else if path.hasSuffix("/LocalTrailers") || path.hasSuffix("/SpecialFeatures") {
            "[]"
        } else {
            #"{"Items":[],"TotalRecordCount":0}"#
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@MainActor
private final class RecordingProgressObserver: MediaProgressObserver {

    var stopInfo: PlaybackStopInfo?
    var onStopRequest: (() -> Void)?
    var onProgressRequest: (() -> Void)?
    var onSettlementRequest: (() -> Void)?
    private var settlementContinuation: CheckedContinuation<Void, Never>?
    private var progressContinuation: CheckedContinuation<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?

    override func send(_ request: Request<Void>) async throws {
        if request.body is PlaybackStateInfo, let onProgressRequest {
            try await withCheckedThrowingContinuation {
                progressContinuation = $0
                onProgressRequest()
            }
            return
        }
        guard let info = request.body as? PlaybackStopInfo else { return }

        stopInfo = info
        try await withCheckedThrowingContinuation {
            continuation = $0
            onStopRequest?()
        }
    }

    override func settlePlaybackState(for item: BaseItemDto, stoppedAt positionTicks: Int?, didReachEnd: Bool = false) async {
        guard let onSettlementRequest else { return }

        await withCheckedContinuation {
            settlementContinuation = $0
            onSettlementRequest()
        }
    }

    func completeSettlement() {
        settlementContinuation?.resume()
        settlementContinuation = nil
    }

    func completeProgressReport() {
        progressContinuation?.resume()
        progressContinuation = nil
        onProgressRequest = nil
    }

    func completeStopReport(throwing error: Error? = nil) {
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
        continuation = nil
    }
}

@MainActor
private final class RecordingRefreshViewModel: WithRefresh {

    var refreshCount = 0
    var onRefresh: (() -> Void)?

    var background: RecordingRefreshViewModel {
        get { self }
        set {}
    }

    func refresh() {
        recordRefresh()
    }

    func refresh() async {
        recordRefresh()
    }

    private func recordRefresh() {
        refreshCount += 1
        onRefresh?()
    }
}

private struct RecordingGroup: ContentGroup {
    let id = "test"
    let viewModel: RecordingRefreshViewModel

    func body(with viewModel: RecordingRefreshViewModel) -> some View {
        EmptyView()
    }
}

private struct RecordingProvider: ContentGroupProvider {
    let id = "test"
    let displayTitle = "Test"
    let viewModel: RecordingRefreshViewModel

    func makeGroups(environment: Alphane.Empty) async throws -> [any ContentGroup] {
        [RecordingGroup(viewModel: viewModel)]
    }
}
