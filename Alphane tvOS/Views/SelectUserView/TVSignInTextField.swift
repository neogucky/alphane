//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import UIKit

/// The visible field is an Alphane button. Its native editor sits behind that
/// button and opens the system TV keyboard when selected. This preserves secure
/// entry and phone input without inheriting UITextField's mandatory focus pill.
struct TVSignInKeyboard: UIViewRepresentable {

    @Binding
    var text: String
    @Binding
    var isPresented: Bool
    @Environment(\.isEnabled)
    private var isEnabled
    let title: String
    let secure: Bool
    let password: Bool
    let submit: () -> Void
    var contentType: UITextContentType? = .username
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType?

    func makeUIView(context: Context) -> TVSignInKeyboardField {
        let field = TVSignInKeyboardField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: TVSignInKeyboardField, context: Context) {
        context.coordinator.editor = self
        if field.isSecureTextEntry != secure {
            field.isSecureTextEntry = secure
        }
        if field.text != text {
            field.text = text
        }
        field.placeholder = title
        field.textContentType = password ? .password : contentType
        field.keyboardType = keyboardType
        field.returnKeyType = returnKeyType ?? (password ? .go : .next)
        field.isEnabled = isEnabled
        field.accessibilityElementsHidden = true
        if isPresented, isEnabled, !field.isFirstResponder {
            DispatchQueue.main.async { [weak field, weak coordinator = context.coordinator] in
                guard let field, field.window != nil, coordinator?.editor.isPresented == true else { return }

                field.becomeFirstResponder()
            }
        } else if !isPresented, field.isFirstResponder {
            context.coordinator.cancel(field)
        }
    }

    static func dismantleUIView(_ field: TVSignInKeyboardField, coordinator: Coordinator) {
        if field.isFirstResponder {
            coordinator.cancel(field)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(editor: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var editor: TVSignInKeyboard
        private var originalText = ""
        private var completed = false

        init(editor: TVSignInKeyboard) {
            self.editor = editor
        }

        @objc
        func changed(_ field: UITextField) {
            editor.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            originalText = editor.text
            completed = false
        }

        private func commit(_ field: UITextField) {
            guard !completed else { return }

            completed = true
            changed(field)
            editor.isPresented = false
            field.resignFirstResponder()
            editor.submit()
        }

        func cancel(_ field: UITextField) {
            guard !completed else { return }

            completed = true
            field.text = originalText
            editor.text = originalText
            editor.isPresented = false
            field.resignFirstResponder()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            commit(textField)
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
            if reason == .cancelled {
                cancel(textField)
            } else {
                commit(textField)
            }
        }
    }
}

final class TVSignInKeyboardField: UITextField {

    override var canBecomeFocused: Bool {
        false
    }

    init() {
        super.init(frame: .zero)
        font = .systemFont(ofSize: 24)
        borderStyle = .none
        backgroundColor = .clear
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        keyboardAppearance = .dark
        clearButtonMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
