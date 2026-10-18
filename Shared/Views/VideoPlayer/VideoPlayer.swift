//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import SwiftUI
import Transmission

struct VideoPlayer: View {

    @Environment(\.presentationCoordinator)
    private var presentationCoordinator

    #if os(tvOS)
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    #endif

    @InjectedObject(\.mediaPlayerManager)
    private var manager: MediaPlayerManager

    @LazyState
    private var proxy: any VideoMediaPlayerLayoutConfigurable

    @Router
    private var router

    @State
    private var isBeingDismissedByTransition = false
    @State
    private var safeAreaInsets: EdgeInsets = .init()

    @State
    private var viewState: ViewState = .init()

    init() {
        switch Defaults[.VideoPlayer.videoPlayerType] {
        case .avPlayer:
            self._proxy = .init(wrappedValue: AVMediaPlayerProxy())
        case .mpv:
            self._proxy = .init(wrappedValue: MPVMediaPlayerProxy())
        case .vlc:
            self._proxy = .init(wrappedValue: VLCMediaPlayerProxy())
        }
    }

    var body: some View {
        Container(
            viewState: viewState,
            manager: manager,
            videoSize: proxy.videoSize
        ) { videoLayout in
            proxy.videoPlayerBody(layout: videoLayout)
                .eraseToAnyView()
        } playbackControls: {
            PlaybackControls()
        }
        #if os(tvOS)
        .overlay {
            // The video surface is mounted after presentation. Keep startup at the
            // presentation root so it also covers the opening animation.
            ZStack {
                if manager.loadingPresentation == .startup {
                    PlaybackStartupView(item: manager.item)
                        .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.35),
                value: manager.loadingPresentation == .startup
            )
        }
        #endif
        .onAppear {
                manager.proxy = proxy
                manager.start()
            }
            .prefersStatusBarHidden(!viewState.isPresentingControls)
            .preference(
                key: PresentationControllerShouldDismissPreferenceKey.self,
                value: viewState.presentationControllerShouldDismiss
            )
            .onChange(of: presentationCoordinator.isPresented) {
                guard !presentationCoordinator.isPresented else { return }

                isBeingDismissedByTransition = true
                manager.stop()
            }
            .onReceive(manager.$playbackItem) { newItem in
                // TODO: move to container view
                viewState.scrubbedSeconds.value = newItem?.baseItem.startSeconds ?? .zero
            }
            .onReceive(manager.$state) { newState in
                if newState == .stopped, !isBeingDismissedByTransition {
                    router.dismiss()
                }
            }

            .alert(
                L10n.error,
                isPresented: .constant(manager.error != nil)
            ) {
                Button(L10n.close, role: .cancel) {
                    FactoryKit.Container.shared.mediaPlayerManager.reset()
                    router.dismiss()
                }
            } message: {
                Text(L10n.unableToLoadThisItem)
            }
            .environment(\.safeAreaInsets, safeAreaInsets)
            .colorScheme(.dark) // use over `preferredColorScheme(.dark)` to not have destination change
            .supportedOrientations(.allButUpsideDown)
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .onSceneDidEnterBackground {
                let isPictureInPictureActive = (proxy as? MediaPlayerPictureInPictureCapable)?.isPiPActive.value == true
                if Defaults[.VideoPlayer.Transition.pauseOnBackground], !isPictureInPictureActive {
                    manager.setPlaybackRequestStatus(status: .paused)
                }
            }
            .onSizeChanged { _, safeArea in
                self.safeAreaInsets = safeArea.max(EdgeInsets.edgePadding)
            }
    }
}
