//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

@testable import Alphane
import Foundation
import XCTest

@MainActor
final class ServerConnectionPresentationTests: XCTestCase {

    func testReorderingConnectionsPersistsPriorityWithoutSwitchingTheActiveEndpoint() throws {
        let id = UUID().uuidString
        defer { UserDefaults.standard.removePersistentDomain(forName: id) }
        let url = try XCTUnwrap(URL(string: "https://connections-tests.invalid"))
        let server = ServerState(urls: [url], currentURL: url, name: "Test", id: id, userIDs: [])
        server.serverConnections = (0 ..< 3).map { index in
            ServerConnection(
                id: "\(index)",
                name: "Connection \(index)",
                url: url.appending(path: "\(index)"),
                interface: .any,
                priority: index
            )
        }
        server.activeServerConnection = server.serverConnections[0]
        let model = ServerConnectionViewModel(server: server)

        // The explicit Down action uses SwiftUI's insertion offset (past the following row).
        model.moveConnections(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        XCTAssertEqual(model.connections.map(\.id), ["1", "0", "2"])
        XCTAssertEqual(server.serverConnections.map(\.id), ["1", "0", "2"])
        XCTAssertEqual(model.connections.map(\.priority), [0, 1, 2])
        XCTAssertEqual(model.activeConnection?.id, "0")
        XCTAssertEqual(server.activeServerConnection?.id, "0")

        model.moveConnections(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(model.connections.map(\.id), ["0", "1", "2"])
        XCTAssertEqual(ServerConnectionViewModel(server: server).connections.map(\.id), ["0", "1", "2"])
        XCTAssertEqual(server.activeServerConnection?.id, "0")
    }
}
