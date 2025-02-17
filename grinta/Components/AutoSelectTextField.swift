import SwiftUI
import UIKit

struct AutoSelectTextField: UIViewRepresentable {
    var placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    private var autoSelectTrigger: AnyHashable? = nil

    private var keyboardType: UIKeyboardType = .default
    private var returnKeyType: UIReturnKeyType = .default
    private var autocorrectionType: UITextAutocorrectionType = .default
    private var autocapitalizationType: UITextAutocapitalizationType = .sentences
    private var enablesReturnKeyAutomatically: Bool = false

    private var onSubmit: (() -> Void)? = nil
    private var onKeyPress: ((UIKey?) -> KeyPressResult)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CustomizableTextField {
        let textField = CustomizableTextField(frame: .zero)
        textField.placeholder = placeholder
        textField.delegate = context.coordinator

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )

        textField.onKeyPress = onKeyPress

        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKeyType
        textField.autocorrectionType = autocorrectionType
        textField.autocapitalizationType = autocapitalizationType
        textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically

        return textField
    }

    func updateUIView(_ uiView: CustomizableTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        // Auto-select on trigger change
        if autoSelectTrigger != context.coordinator.lastAutoSelectTrigger {
            context.coordinator.lastAutoSelectTrigger = autoSelectTrigger
            DispatchQueue.main.async {
                uiView.selectAll(nil)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView _: CustomizableTextField, context _: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: 24)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoSelectTextField
        var lastAutoSelectTrigger: AnyHashable?

        init(_ parent: AutoSelectTextField) {
            self.parent = parent
            lastAutoSelectTrigger = parent.autoSelectTrigger
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_: UITextField) -> Bool {
            parent.onSubmit?()
            return true
        }

        func textFieldDidBeginEditing(_: UITextField) {}
    }
}

extension AutoSelectTextField {
    func placeholder(_ placeholder: String) -> AutoSelectTextField {
        var copy = self
        copy.placeholder = placeholder
        return copy
    }

    func keyboardType(_ type: UIKeyboardType) -> AutoSelectTextField {
        var copy = self
        copy.keyboardType = type
        return copy
    }

    func returnKeyType(_ type: UIReturnKeyType) -> AutoSelectTextField {
        var copy = self
        copy.returnKeyType = type
        return copy
    }

    func autocorrectionDisabled(_ disabled: Bool) -> AutoSelectTextField {
        var copy = self
        copy.autocorrectionType = disabled ? .no : .yes
        return copy
    }

    func textInputAutocapitalization(_ type: UITextAutocapitalizationType) -> AutoSelectTextField {
        var copy = self
        copy.autocapitalizationType = type
        return copy
    }

    /// Sets whether the return key is enabled automatically.
    func enablesReturnKeyAutomatically(_ enabled: Bool) -> AutoSelectTextField {
        var copy = self
        copy.enablesReturnKeyAutomatically = enabled
        return copy
    }

    /// Sets the onSubmit callback.
    func onSubmit(_ action: @escaping () -> Void) -> AutoSelectTextField {
        var copy = self
        copy.onSubmit = action
        return copy
    }

    /// Sets the onKeyPress callback.
    func onKeyPress(_ action: @escaping (UIKey?) -> KeyPressResult) -> AutoSelectTextField {
        var copy = self
        copy.onKeyPress = action
        return copy
    }

    /// Sets the auto‑select trigger.
    func autoselect(value: some Hashable) -> AutoSelectTextField {
        var copy = self
        copy.autoSelectTrigger = AnyHashable(value)
        return copy
    }
}

enum KeyPressResult {
    case ignored
    case handled
}

final class CustomizableTextField: UITextField {
    /// A closure called for key press events.
    var onKeyPress: ((UIKey?) -> KeyPressResult)?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let key = presses.first?.key, let result = onKeyPress?(key), result == .handled {
            // If handled, do not propagate further.
            return
        }
        super.pressesBegan(presses, with: event)
    }
}
