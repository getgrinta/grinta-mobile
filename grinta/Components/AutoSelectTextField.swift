import SwiftUI
import UIKit

/// A UITextField wrapper that supports auto-selection and custom keyboard behaviors
struct AutoSelectTextField: UIViewRepresentable {
    // MARK: - Properties

    let placeholder: String
    @Binding var text: String

    // MARK: - Configuration

    private var autoSelectTrigger: AnyHashable?
    private var keyboardType: UIKeyboardType = .default
    private var returnKeyType: UIReturnKeyType = .default
    private var autocorrectionType: UITextAutocorrectionType = .default
    private var autocapitalizationType: UITextAutocapitalizationType = .sentences
    private var enablesReturnKeyAutomatically: Bool = false
    private var focusedField: Binding<AnyHashable?>?
    private var focusedValue: AnyHashable?

    // MARK: - Callbacks

    private var onSubmit: (() -> Void)?
    private var onKeyPress: ((UIKey?) -> KeyPressResult)?

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    // MARK: - UIViewRepresentable

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

        configureTextField(textField)
        return textField
    }

    func updateUIView(_ uiView: CustomizableTextField, context: Context) {
        updateTextIfNeeded(uiView)
        updateCallbacks(uiView)
        updateFocusState(uiView)
        handleAutoSelection(uiView, context: context)
        configureTextField(uiView)
        context.coordinator.onSubmit = onSubmit
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView _: CustomizableTextField, context _: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: 24)
    }

    // MARK: - Private Helpers

    private func configureTextField(_ textField: CustomizableTextField) {
        textField.onKeyPress = onKeyPress
        textField.onSubmit = onSubmit
        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKeyType
        textField.autocorrectionType = autocorrectionType
        textField.autocapitalizationType = autocapitalizationType
        textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
    }

    private func updateTextIfNeeded(_ textField: CustomizableTextField) {
        if textField.text != text {
            textField.text = text
        }
    }

    private func updateCallbacks(_ textField: CustomizableTextField) {
        textField.onKeyPress = onKeyPress
        textField.onSubmit = onSubmit
    }

    private func updateFocusState(_ textField: CustomizableTextField) {
        guard let focusedField,
              let focusedValue else { return }

        let isFocused = focusedField.wrappedValue == focusedValue
        if isFocused, !textField.isFirstResponder {
            textField.becomeFirstResponder()
        } else if !isFocused, textField.isFirstResponder {
            _ = textField.resignFirstResponder()
        }
    }

    private func handleAutoSelection(_ textField: CustomizableTextField, context: Context) {
        if autoSelectTrigger != context.coordinator.lastAutoSelectTrigger {
            context.coordinator.lastAutoSelectTrigger = autoSelectTrigger
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}

// MARK: - Modifiers

extension AutoSelectTextField {
    func submitLabel(_ label: SubmitLabel) -> Self {
        var copy = self
        copy.returnKeyType = label.returnKeyType
        copy.enablesReturnKeyAutomatically = true
        return copy
    }

    func keyboardType(_ type: UIKeyboardType) -> Self {
        var copy = self
        copy.keyboardType = type
        return copy
    }

    func autocorrectionDisabled() -> Self {
        var copy = self
        copy.autocorrectionType = .no
        return copy
    }

    func focused<T: Hashable>(_ binding: FocusState<T>.Binding, equals value: T) -> Self {
        var copy = self
        copy.focusedField = Binding(
            get: { binding.wrappedValue == value ? AnyHashable(value) : nil },
            set: { _ in binding.wrappedValue = value }
        )
        return copy
    }

    func textInputAutocapitalization(_ style: TextInputAutocapitalization) -> Self {
        var copy = self
        copy.autocapitalizationType = style == .never ? .none : .sentences
        return copy
    }

    func onKeyPress(_ action: @escaping (UIKey?) -> KeyPressResult) -> Self {
        var copy = self
        copy.onKeyPress = action
        return copy
    }

    func onSubmit(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.onSubmit = action
        return copy
    }

    func autoselect(value: AnyHashable?) -> Self {
        var copy = self
        copy.autoSelectTrigger = value
        return copy
    }
}

// MARK: - Supporting Types

enum KeyPressResult {
    case ignored
    case handled
}

enum SubmitLabel {
    case go
    case `default`

    var returnKeyType: UIReturnKeyType {
        switch self {
        case .go:
            .go
        case .default:
            .default
        }
    }
}

enum TextInputAutocapitalization {
    case never
    case sentences
}

// MARK: - CustomizableTextField

final class CustomizableTextField: UITextField {
    var onKeyPress: ((UIKey?) -> KeyPressResult)?
    var onSubmit: (() -> Void)?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {
            super.pressesBegan(presses, with: event)
            return
        }

        if let result = onKeyPress?(key) {
            switch result {
            case .ignored:
                super.pressesBegan(presses, with: event)
            case .handled:
                break
            }
        } else {
            super.pressesBegan(presses, with: event)
        }
    }
}

// MARK: - Coordinator

extension AutoSelectTextField {
    class Coordinator: NSObject, UITextFieldDelegate {
        private var textField: AutoSelectTextField
        var lastAutoSelectTrigger: AnyHashable?
        var onSubmit: (() -> Void)?

        init(_ textField: AutoSelectTextField) {
            self.textField = textField
        }

        @objc func textChanged(_ textField: UITextField) {
            self.textField.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit?()
            textField.resignFirstResponder()
            return true
        }
    }
}
