//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// The account explicitly chosen on the profile picker. A missing or incomplete
/// identity falls back to manual sign-in rather than locking an empty username.
struct UserSignInProfile: Equatable {

    let user: UserDto
    let id: String
    let username: String

    init?(user: UserDto) {
        guard let id = user.id, !id.isEmpty,
              let name = user.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        self.user = user
        self.id = id
        self.username = name
    }

    init?(savedUser: UserState) {
        var user = savedUser.data
        user.id = savedUser.id
        user.name = savedUser.username
        self.init(user: user)
    }
}
