//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Combine
import Foundation
import Get
import JellyfinAPI
import os
import SwiftUI
import UIKit
import XCTest

@MainActor
final class UserSignInTests: XCTestCase {

    func testIncompletePublicProfilesFallBackToManualSignIn() {
        for user in [UserDto(), UserDto(id: "root"), UserDto(id: "", name: "root"), UserDto(id: "root", name: "  ")] {
            XCTAssertNil(UserSignInProfile(user: user))
        }
        XCTAssertEqual(UserSignInProfile(user: UserDto(id: "root", name: "root"))?.username, "root")
    }

    func testRetainedProfileUsesItsCurrentIdentityAndKeepsAvatarMetadata() throws {
        let saved = UserState(id: UUID().uuidString, serverID: "server", username: "root")
        defer { UserDefaults.userSuite(id: saved.id).removeAll() }
        saved.data = UserDto(id: "old-id", name: "old-name", primaryImageTag: "avatar-tag")
        let profile = try XCTUnwrap(UserSignInProfile(savedUser: saved))
        XCTAssertEqual(profile.id, saved.id)
        XCTAssertEqual(profile.username, "root")
        XCTAssertEqual(profile.user.primaryImageTag, "avatar-tag")
    }

    func testSelectedProfileLocksTheUsernameAndAcceptsOnlyItsOwnAuthentication() async throws {
        try await withServer { server in
            let model = UserSignInViewModel(server: server, profile: profile())
            var connected: UserState?
            let observation = model.events.sink { event in
                if case let .connected(user) = event {
                    connected = user.state.state
                }
            }
            defer { observation.cancel() }
            await model.signIn(username: "someone-else", password: "test-password")
            XCTAssertNil(model.error)
            XCTAssertEqual(connected?.id, "root-id")
            XCTAssertEqual(connected?.serverID, server.id)
            let request = try XCTUnwrap(SignInProtocol.stub.withLock { $0.bodies.first })
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request) as? [String: Any])
            XCTAssertEqual(body["Username"] as? String, "root")
        }
    }

    func testQuickConnectCannotSignASelectedProfileInAsSomebodyElse() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.user = UserDto(id: "other-id", name: "Other") }
            let model = UserSignInViewModel(server: server, profile: profile())
            var authenticated = false
            let observation = model.events.sink { _ in authenticated = true }
            defer { observation.cancel() }
            await model.signInQuickConnect(secret: "test-secret")
            XCTAssertNotNil(model.error)
            XCTAssertFalse(authenticated)
            XCTAssertTrue(model.error?.localizedDescription.contains("root") == true)
            XCTAssertTrue(StoredValues[.User.users].isEmpty)
        }
    }

    func testPasswordAuthenticationCannotReturnADifferentSelectedProfile() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.user = UserDto(id: "other-id", name: "Other") }
            let model = UserSignInViewModel(server: server, profile: profile())
            var authenticated = false
            let observation = model.events.sink { _ in authenticated = true }
            defer { observation.cancel() }
            await model.signIn(username: "root", password: "test-password")
            XCTAssertNotNil(model.error)
            XCTAssertFalse(authenticated)
        }
    }

    func testQuickConnectStillWorksForTheSelectedProfile() async throws {
        try await withServer { server in
            let model = UserSignInViewModel(server: server, profile: profile())
            var authenticatedID: String?
            let observation = model.events.sink { event in
                if case let .connected(user) = event {
                    authenticatedID = user.state.state.id
                }
            }
            defer { observation.cancel() }
            await model.signInQuickConnect(secret: "test-secret")
            XCTAssertNil(model.error)
            XCTAssertEqual(authenticatedID, "root-id")
        }
    }

    func testAdditionalUserCanAuthorizeAnyAccountWithQuickConnect() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.user = UserDto(id: "hidden-id", name: "Hidden account") }
            let model = UserSignInViewModel(server: server)
            var authenticatedID: String?
            let observation = model.events.sink { event in
                if case let .connected(user) = event {
                    authenticatedID = user.state.state.id
                }
            }
            defer { observation.cancel() }
            await model.signInQuickConnect(secret: "test-secret")
            XCTAssertNil(model.error)
            XCTAssertEqual(authenticatedID, "hidden-id")
        }
    }

    func testSavedProfileAuthenticationReturnsItsFreshTokenAndRetainedSettingsIdentity() async throws {
        try await withServer { server in
            let saved = UserState(id: "root-id", serverID: server.id, username: "root")
            StoredValues[.User.users] = [saved]
            let model = UserSignInViewModel(server: server, profile: profile())
            var existing: UserSignInViewModel.UserStateDataPair?
            let observation = model.events.sink { event in
                if case let .existingUser(user) = event {
                    existing = user
                }
            }
            defer { observation.cancel() }
            await model.signIn(username: "root", password: "test-password")
            XCTAssertNil(model.error)
            XCTAssertEqual(existing?.state.state, saved)
            XCTAssertEqual(existing?.state.accessToken, "fresh-test-token")
        }
    }

    func testOptionalMetadataFailuresDoNotBlockQuickConnectOrReloadTheUserPicker() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.brandingUnavailable = true }
            let model = UserSignInViewModel(server: server, profile: profile())
            await model.getPublicData()
            XCTAssertTrue(model.isQuickConnectEnabled)
            XCTAssertNil(model.error)
            XCTAssertNil(model.serverDisclaimer)
            XCTAssertFalse(SignInProtocol.stub.withLock { $0.paths.contains { $0.lowercased().contains("users/public") } })
        }
    }

    func testUnavailableOptionalFeaturesStillAllowPasswordSignIn() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.metadataUnavailable = true }
            let model = UserSignInViewModel(server: server)
            await model.getPublicData()
            XCTAssertFalse(model.isQuickConnectEnabled)
            XCTAssertNil(model.error)
            await model.signIn(username: "root", password: "")
            XCTAssertNil(model.error, "Accounts without a password must still be accepted by the server")
        }
    }

    func testCancelledSignInCannotPublishALateAuthenticatedProfile() async throws {
        try await withServer { server in
            SignInProtocol.stub.withLock { $0.loginDelay = 0.2 }
            let model = UserSignInViewModel(server: server, profile: profile())
            var authenticated = false
            let observation = model.events.sink { _ in authenticated = true }
            defer { observation.cancel() }
            let request = Task { await model.signIn(username: "root", password: "test-password") }
            for _ in 0 ..< 100 where SignInProtocol.stub.withLock({ $0.bodies.isEmpty }) {
                try await Task.sleep(for: .milliseconds(5))
            }
            await model.cancel()
            await request.value
            XCTAssertFalse(authenticated)
            XCTAssertEqual(model.state, .initial)
            XCTAssertNil(UserSignInView.TVSignInContent.displayError(model.error, selectedProfile: true))
        }
    }

    func testAuthenticationErrorsUseInlineExplanationsAndCancellationStaysQuiet() {
        let selected = UserSignInView.TVSignInContent.displayError(APIError.unacceptableStatusCode(401), selectedProfile: true)
        XCTAssertEqual(selected, "Check your password and try again.")
        let manual = UserSignInView.TVSignInContent.displayError(APIError.unacceptableStatusCode(401), selectedProfile: false)
        XCTAssertEqual(manual, "Check your username and password and try again.")
        XCTAssertNil(UserSignInView.TVSignInContent.displayError(CancellationError(), selectedProfile: true))
        XCTAssertNil(UserSignInView.TVSignInContent.displayError(URLError(.cancelled), selectedProfile: true))
    }

    func testKeyboardCancelRestoresTheOriginalValueWithoutSubmitting() {
        var value = "original"
        var presented = true
        var submissions = 0
        let keyboard = TVSignInKeyboard(
            text: Binding(get: { value }, set: { value = $0 }),
            isPresented: Binding(get: { presented }, set: { presented = $0 }),
            title: "Password", secure: true, password: true, submit: { submissions += 1 }
        )
        let coordinator = keyboard.makeCoordinator()
        let field = TVSignInKeyboardField()
        coordinator.textFieldDidBeginEditing(field)
        field.text = "replacement"
        coordinator.changed(field)
        XCTAssertEqual(value, "replacement")
        coordinator.textFieldDidEndEditing(field, reason: .cancelled)
        XCTAssertEqual(value, "original")
        XCTAssertFalse(presented)
        XCTAssertEqual(submissions, 0)
    }

    func testKeyboardDoneSubmitsTheEditedValueExactlyOnce() {
        var value = "original"
        var presented = true
        var submissions = 0
        let keyboard = TVSignInKeyboard(
            text: Binding(get: { value }, set: { value = $0 }),
            isPresented: Binding(get: { presented }, set: { presented = $0 }),
            title: "Password", secure: true, password: true, submit: { submissions += 1 }
        )
        let coordinator = keyboard.makeCoordinator()
        let field = TVSignInKeyboardField()
        coordinator.textFieldDidBeginEditing(field)
        field.text = "replacement"
        XCTAssertTrue(coordinator.textFieldShouldReturn(field))
        coordinator.textFieldDidEndEditing(field, reason: .committed)
        XCTAssertEqual(value, "replacement")
        XCTAssertFalse(presented)
        XCTAssertEqual(submissions, 1)
    }

    func testSelectedProfileShowsOnlyPasswordAndFocusesIt() async throws {
        try await withServer { server in
            try await checkForm(server: server, profile: profile(), screenshot: "selected-profile")
        }
    }

    func testAdditionalUserShowsUsernameAndPasswordAndFocusesUsername() async throws {
        try await withServer { server in
            try await checkForm(server: server, profile: nil, screenshot: "additional-user")
        }
    }

    private func profile() -> UserSignInProfile {
        UserSignInProfile(user: UserDto(id: "root-id", name: "root"))!
    }

    private func withServer(_ body: (ServerState) async throws -> Void) async throws {
        let users = StoredValues[.User.users]
        let protocols = URLSessionConfiguration.alphane.protocolClasses
        SignInProtocol.stub.withLock { $0 = .init() }
        StoredValues[.User.users] = []
        URLSessionConfiguration.alphane.protocolClasses = [SignInProtocol.self]
        defer {
            StoredValues[.User.users] = users
            URLSessionConfiguration.alphane.protocolClasses = protocols
        }
        let url = try XCTUnwrap(URL(string: "https://sign-in-tests.invalid"))
        let server = ServerState(urls: [url], currentURL: url, name: "Media server", id: UUID().uuidString, userIDs: [])
        try await body(server)
    }

    private func checkForm(server: ServerState, profile: UserSignInProfile?, screenshot: String) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let controller = UIHostingController(rootView:
            NavigationInjectionView(coordinator: NavigationCoordinator(usesNavigationStack: true)) {
                WithLocalUserAuthentication { UserSignInView(server: server, profile: profile) }
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
        window.layoutIfNeeded()
        window.setNeedsFocusUpdate()
        window.updateFocusIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sign-in-redesign", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(screenshot + ".png"))
        let fields = descendants(controller.view).compactMap { $0 as? UITextField }.filter { !$0.isHidden }
        XCTAssertEqual(fields.count, profile == nil ? 2 : 1)
        XCTAssertEqual(fields.filter(\.isSecureTextEntry).count, 1)
        XCTAssertTrue(fields.allSatisfy { $0.borderStyle == .none }, "Native input backgrounds must not overlap Alphane's focus border")
        let first = try XCTUnwrap(fields.first { profile == nil ? !$0.isSecureTextEntry : $0.isSecureTextEntry })
        let focused = try XCTUnwrap(UIFocusSystem.focusSystem(for: window)?.focusedItem)
        let focusRect = focused.focusItemContainer?.coordinateSpace.convert(focused.frame, to: window) ?? focused.frame
        let editorRect = first.convert(first.bounds, to: window)
        XCTAssertTrue(focusRect.contains(CGPoint(x: editorRect.midX, y: editorRect.midY)), "The first credential field must receive focus")
        XCTAssertGreaterThan(focusRect.width, 100, "Focus belongs to the visible field, not its native editor")
        let keyboard = try XCTUnwrap(first.delegate as? TVSignInKeyboard.Coordinator)
        keyboard.editor.isPresented = true
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(first.isFirstResponder, "Selecting the field must open the native TV keyboard")
        keyboard.cancel(first)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(first.isFirstResponder)
        XCTAssertTrue(SignInProtocol.stub.withLock { $0.bodies.isEmpty }, "Cancelling the keyboard must not start sign-in")
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }
}

private final class SignInProtocol: URLProtocol, @unchecked Sendable {

    struct Stub {
        var user = UserDto(id: "root-id", name: "root")
        var brandingUnavailable = false
        var metadataUnavailable = false
        var loginDelay: TimeInterval = 0
        var bodies: [Data] = []
        var paths: [String] = []
    }

    static let stub = OSAllocatedUnfairLock(initialState: Stub())
    private var work: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sign-in-tests.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url!.path.lowercased()
        let authentication = path.contains("authenticate")
        let body = authentication ? requestBody() : nil
        let state = Self.stub.withLock { state in
            state.paths.append(path)
            if let body {
                state.bodies.append(body)
            }
            return state
        }
        let status = !authentication && (state.metadataUnavailable || (state.brandingUnavailable && path.contains("branding"))) ? 503 : 200
        let data: Data = if authentication {
            try! JSONEncoder().encode(AuthenticationResult(accessToken: "fresh-test-token", user: state.user))
        } else if path.contains("quickconnect") {
            Data("true".utf8)
        } else {
            Data("{}".utf8)
        }
        let respond = DispatchWorkItem { [self] in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        work = respond
        DispatchQueue.global().asyncAfter(deadline: .now() + (authentication ? state.loginDelay : 0), execute: respond)
    }

    override func stopLoading() {
        work?.cancel()
    }

    private func requestBody() -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }

            result.append(buffer, count: count)
        }
        return result
    }
}
