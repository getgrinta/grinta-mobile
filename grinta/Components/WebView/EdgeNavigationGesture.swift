import SwiftUI

struct EdgeNavigationGesture: ViewModifier {
    private var dragCompletionClosure: ((CGFloat) -> Void)?
    let canGoBack: Bool
    let onBack: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @Binding var isDraggingBack: Bool

    private var dragCompletion: CGFloat {
        dragOffset / 100
    }

    init(
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        isDraggingBack: Binding<Bool>
    ) {
        self.canGoBack = canGoBack
        self.onBack = onBack
        _isDraggingBack = isDraggingBack
    }

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let horizontalTranslation = value.translation.width
                        let edgeWidth: CGFloat = 44 // Width of the edge detection area

                        if value.startLocation.x < edgeWidth, canGoBack {
                            // Left edge gesture (go back)
                            state = max(0, horizontalTranslation)
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDraggingBack = true
                            }
                        }

                        dragCompletionClosure?(dragCompletion)
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50 // Minimum drag distance to trigger navigation
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDraggingBack = false
                        }

                        if value.startLocation.x < 44, value.translation.width > threshold, canGoBack {
                            dragCompletionClosure?(1)
                            onBack()
                        } else {
                            dragCompletionClosure?(0)
                        }
                    }
            )
            .offset(x: dragOffset)
            .opacity(1 - dragCompletion)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: dragOffset)
    }

    func dragCompletionChanged(_ completion: @escaping (CGFloat) -> Void) -> Self {
        var copy = self
        copy.dragCompletionClosure = completion
        return copy
    }
}
