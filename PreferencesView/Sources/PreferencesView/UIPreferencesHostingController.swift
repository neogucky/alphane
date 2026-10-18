//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// TODO: Button recognizers for tvOS?
//       - .menu, .select

public class UIPreferencesHostingController: UIHostingController<AnyView> {

    public init(@ViewBuilder content: @escaping () -> some View) {

        let box = Box()
        let rootView = AnyView(
            content()
                .onPreferenceChange(PressCommandsPreferenceKey.self) {
                    box.value?._pressCommandActions = $0
                }
        )

        super.init(rootView: rootView)

        box.value = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(tvOS)

    override public func viewDidLoad() {
        super.viewDidLoad()

        let gesture = UITapGestureRecognizer(target: self, action: #selector(ignorePress))
        gesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(gesture)
    }

    @objc
    func ignorePress() {}

    private var _pressCommandActions: [PressCommandAction] = []

    override public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let buttonPress = presses.first?.type else { return }
        guard let action = _pressCommandActions
            .first(where: { $0.press == buttonPress }) else { return }

        action.action()
    }
    #endif
}
