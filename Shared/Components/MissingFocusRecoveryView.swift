//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import UIKit

/// Repairs an empty focus environment after wake or asynchronous page loading.
/// It never changes an existing selection or provides a hidden focus stop.
struct MissingFocusRecoveryView: UIViewRepresentable {
    func makeUIView(context: Context) -> MissingFocusRecoveryObserver {
        MissingFocusRecoveryObserver()
    }

    func updateUIView(_ uiView: MissingFocusRecoveryObserver, context: Context) {
        uiView.isRecoveryEnabled = context.environment.scenePhase == .active
    }

    static func dismantleUIView(_ uiView: MissingFocusRecoveryObserver, coordinator: ()) {
        uiView.stopObserving()
    }
}

final class MissingFocusRecoveryObserver: UIView {
    var isRecoveryEnabled = false {
        didSet { scheduleCheck() }
    }

    private var retryTimer: Timer?
    private var checkScheduled = false

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }

    deinit {
        retryTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        stopObserving()
        guard window != nil else { return }

        for name in [
            UIFocusSystem.didUpdateNotification,
            UIWindow.didBecomeKeyNotification,
            UIWindow.didResignKeyNotification,
            UIScene.didActivateNotification,
            UIScene.willDeactivateNotification
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(focusEnvironmentChanged), name: name, object: nil)
        }
        scheduleCheck()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleCheck()
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
        retryTimer?.invalidate()
        retryTimer = nil
    }

    @objc
    private func focusEnvironmentChanged() {
        // Focus notifications can arrive before UIKit has committed the new item.
        scheduleCheck()
    }

    private func scheduleCheck() {
        guard !checkScheduled else { return }

        checkScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.checkScheduled = false
            self.updateWaitingState()
        }
    }

    private var focusSystemNeedingRecovery: UIFocusSystem? {
        guard isRecoveryEnabled, let window, window.isKeyWindow, !window.isHidden,
              window.windowScene?.activationState == .foregroundActive,
              let system = UIFocusSystem(for: window) else { return nil }

        if let focused = system.focusedItem, focused.canBecomeFocused {
            // Keyboards and other system UI can own focus in a separate visible
            // window. Only repair empty/detached focus; never pull it out of them.
            let windows = window.windowScene?.windows ?? [window]
            if windows.contains(where: { !$0.isHidden && $0.contains(focused) }) {
                return nil
            }
        }
        return system
    }

    private func updateWaitingState() {
        // Wake notifications can precede key-window/scene readiness, and focus
        // can disappear later without another notification. Keep checking while
        // this active SwiftUI surface is attached, even if a check is premature
        // or currently finds a valid selection.
        guard isRecoveryEnabled, window != nil else {
            retryTimer?.invalidate()
            retryTimer = nil
            return
        }
        guard retryTimer == nil else { return }

        // Only recoverIfNeeded requests focus. Healthy focus, inactive scenes,
        // non-key windows and native dialogs cause no focus/layout updates.
        // The check stays alive to catch silent loss and late readiness.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.recoverIfNeeded()
        }
        retryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func recoverIfNeeded() {
        guard let system = focusSystemNeedingRecovery, let window else {
            updateWaitingState()
            return
        }

        // Request the window's current visible destination, respecting its
        // preferred/default focus and any presented keyboard, menu or dialog.
        system.requestFocusUpdate(to: window)
        system.updateFocusIfNeeded()
        updateWaitingState()
    }
}

extension View {
    func recoveringMissingFocus() -> some View {
        background {
            MissingFocusRecoveryView()
                .allowsHitTesting(false)
        }
    }
}
