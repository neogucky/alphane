//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import PulseUI
import SwiftUI

extension NavigationRoute {

    #if os(tvOS)
    static var tvAudioSubtitleSettings: NavigationRoute {
        NavigationRoute(id: "tvAudioSubtitleSettings") {
            VideoPlayerSettingsView(page: .audioAndSubtitles)
        }
    }

    static var tvPlaybackPreferences: NavigationRoute {
        NavigationRoute(id: "tvPlaybackPreferences") {
            VideoPlayerSettingsView(page: .playbackPreferences)
        }
    }

    static var tvDiagnostics: NavigationRoute {
        NavigationRoute(id: "tvDiagnostics") {
            TVDiagnosticsSettingsView()
        }
    }
    #endif

    static func actionBarButtonSelector(selectedButtonsBinding: Binding<[VideoPlayerActionButton]>) -> NavigationRoute {
        NavigationRoute(id: "actionBarButtonSelector") {
            OrderedSectionSelectorView(
                title: L10n.barButtons.localizedCapitalized,
                selection: selectedButtonsBinding,
                sources: VideoPlayerActionButton.allCases
            )
            .navigationTitle(L10n.barButtons.localizedCapitalized)
        }
    }

    static func actionMenuButtonSelector(selectedButtonsBinding: Binding<[VideoPlayerActionButton]>) -> NavigationRoute {
        NavigationRoute(id: "actionMenuButtonSelector") {
            OrderedSectionSelectorView(
                title: L10n.menuButtons.localizedCapitalized,
                selection: selectedButtonsBinding,
                sources: VideoPlayerActionButton.allCases
            )
            .navigationTitle(L10n.menuButtons.localizedCapitalized)
        }
    }

    static func itemActionBarButtonSelector(selectedButtonsBinding: Binding<[ItemActionButton]>) -> NavigationRoute {
        NavigationRoute(id: "itemActionBarButtonSelector") {
            OrderedSectionSelectorView(
                title: L10n.barButtons.localizedCapitalized,
                selection: selectedButtonsBinding,
                sources: ItemActionButton.allCases
            )
            .navigationTitle(L10n.barButtons.localizedCapitalized)
        }
    }

    static func itemActionMenuButtonSelector(selectedButtonsBinding: Binding<[ItemActionButton]>) -> NavigationRoute {
        NavigationRoute(id: "itemActionMenuButtonSelector") {
            OrderedSectionSelectorView(
                title: L10n.menuButtons.localizedCapitalized,
                selection: selectedButtonsBinding,
                sources: ItemActionButton.allCases
            )
            .navigationTitle(L10n.menuButtons.localizedCapitalized)
        }
    }

    static func supplementSelector(selectedSupplementsBinding: Binding<[VideoPlayerSupplement]>) -> NavigationRoute {
        NavigationRoute(id: "supplementSelector") {
            OrderedSectionSelectorView(
                title: L10n.supplements.localizedCapitalized,
                selection: selectedSupplementsBinding,
                sources: VideoPlayerSupplement.allCases,
                removable: VideoPlayerSupplement.allCases.subtracting(VideoPlayerSupplement.supportedCases)
            )
            .navigationTitle(L10n.supplements.localizedCapitalized)
        }
    }

    static var createDeviceProfile: NavigationRoute {
        NavigationRoute(
            id: "createDeviceProfile",
            style: .sheet
        ) {
            CustomDeviceProfilesView.EditDeviceProfileView(profile: nil)
                .navigationTitle(L10n.customProfile.localizedCapitalized)
        }
    }

    static var customDeviceProfilesSettings: NavigationRoute {
        NavigationRoute(
            id: "customDeviceProfilesSettings"
        ) {
            CustomDeviceProfilesView()
        }
    }

    static var customizeSettingsView: NavigationRoute {
        NavigationRoute(
            id: "customizeSettingsView"
        ) {
            CustomizeSettingsView()
        }
    }

    #if DEBUG
    static var debugSettings: NavigationRoute {
        NavigationRoute(
            id: "debugSettings"
        ) {
            DebugSettingsView()
        }
    }
    #endif

    static func editDeviceProfile(profile: Binding<CustomDeviceProfile>) -> NavigationRoute {
        NavigationRoute(
            id: "editDeviceProfile",
            style: .sheet
        ) {
            CustomDeviceProfilesView.EditDeviceProfileView(profile: profile)
                .navigationTitle(L10n.customProfile.localizedCapitalized)
        }
    }

    static func editDeviceProfileAudio(selection: Binding<[AudioCodec]>) -> NavigationRoute {
        NavigationRoute(id: "editDeviceProfileAudio") {
            OrderedSectionSelectorView(systemImage: "waveform", title: L10n.audio, selection: selection, sources: AudioCodec.allCases)
                .navigationTitle(L10n.audio)
        }
    }

    static func editDeviceProfileContainer(selection: Binding<[MediaContainer]>) -> NavigationRoute {
        NavigationRoute(id: "editDeviceProfileContainer") {
            OrderedSectionSelectorView(
                systemImage: "archivebox",
                title: L10n.containers,
                selection: selection,
                sources: MediaContainer.allCases
            )
            .navigationTitle(L10n.containers)
        }
    }

    static func editDeviceProfileVideo(selection: Binding<[VideoCodec]>) -> NavigationRoute {
        NavigationRoute(id: "editDeviceProfileVideo") {
            OrderedSectionSelectorView(systemImage: "play.rectangle", title: L10n.video, selection: selection, sources: VideoCodec.allCases)
                .navigationTitle(L10n.video)
        }
    }

    static func editLocalServer(server: ServerState, isEditing: Bool = false) -> NavigationRoute {
        NavigationRoute(id: "editServer") {
            EditLocalServerView(
                server: server,
                isDeletePresented: isEditing
            )
        }
    }

    @MainActor
    static func serverConnections(viewModel: ServerConnectionViewModel) -> NavigationRoute {
        NavigationRoute(
            id: "serverConnections-\(viewModel.server.id)"
        ) {
            ServerConnectionView(viewModel: viewModel)
        }
    }

    @MainActor
    static func editServerConnection(
        viewModel: ServerConnectionViewModel,
        connection: ServerConnection
    ) -> NavigationRoute {
        NavigationRoute(
            id: "serverConnection-\(viewModel.server.id)-\(connection.id)",
            style: .sheet
        ) {
            EditServerConnectionView(
                viewModel: viewModel,
                connection: connection
            )
        }
    }

    static var experimentalSettings: NavigationRoute {
        NavigationRoute(
            id: "experimentalSettings"
        ) {
            ExperimentalSettingsView()
        }
    }

    static func fontPicker(selection: Binding<String>) -> NavigationRoute {
        NavigationRoute(id: "fontPicker") {
            FontPickerView(selection: selection)
        }
    }

    static var itemSettings: NavigationRoute {
        NavigationRoute(
            id: "itemSettings"
        ) {
            CustomizeSettingsView.ItemSection()
        }
    }

    static var librarySettings: NavigationRoute {
        NavigationRoute(
            id: "librarySettings"
        ) {
            CustomizeSettingsView.LibrarySection()
        }
    }

    static var posterSettings: NavigationRoute {
        NavigationRoute(
            id: "posterSettings"
        ) {
            CustomizeSettingsView.PosterSection()
        }
    }

    static var indicatorSettings: NavigationRoute {
        NavigationRoute(
            id: "indicatorSettings"
        ) {
            IndicatorSettingsView()
        }
    }

    static func itemFilterDrawerSelector(selection: Binding<[ItemFilterType]>) -> NavigationRoute {
        NavigationRoute(id: "itemFilterDrawerSelector") {
            OrderedSectionSelectorView(
                systemImage: "line.3.horizontal.decrease",
                title: L10n.filters,
                selection: selection,
                sources: ItemFilterType.allCases
            )
            .navigationTitle(L10n.filters)
        }
    }

    static func itemViewAttributes(selection: Binding<[ItemViewAttribute]>) -> NavigationRoute {
        NavigationRoute(id: "itemViewAttributes") {
            OrderedSectionSelectorView(
                systemImage: "tag",
                title: L10n.mediaAttributes.localizedCapitalized,
                selection: selection,
                sources: ItemViewAttribute.allCases
            )
            .navigationTitle(L10n.mediaAttributes.localizedCapitalized)
        }
    }

    static var localUserSecurity: NavigationRoute {
        NavigationRoute(
            id: "localUserSecurity"
        ) {
            WithLocalUserAuthentication {
                LocalUserSecurityView()
            }
        }
    }

    static func localUserSettings(user: UserDto) -> NavigationRoute {
        NavigationRoute(id: "localUserSettings") {
            LocalUserSettingsView(user: user)
        }
    }

    static var log: NavigationRoute {
        NavigationRoute(
            id: "log"
        ) {
            ConsoleView()
        }
    }

    static var playbackQualitySettings: NavigationRoute {
        NavigationRoute(
            id: "playbackQualitySettings"
        ) {
            PlaybackQualitySettingsView()
        }
    }

    static var settings: NavigationRoute {
        NavigationRoute(
            id: "settings",
            style: .sheet
        ) {
            SettingsView()
        }
    }

    static var videoPlayerSettings: NavigationRoute {
        NavigationRoute(
            id: "videoPlayerSettings"
        ) {
            VideoPlayerSettingsView()
        }
    }
}
