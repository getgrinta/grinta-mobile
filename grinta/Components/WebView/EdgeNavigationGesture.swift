import SwiftUI

struct EdgeNavigationGesture: ViewModifier {
    private var dragCompletionClosure: ((CGFloat) -> Void)?
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @Binding var isDraggingBack: Bool

    private var dragCompletion: CGFloat {
        dragOffset / 100
    }

    init(
        canGoBack: Bool,
        canGoForward: Bool,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void,
        isDraggingBack: Binding<Bool>
    ) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.onBack = onBack
        self.onForward = onForward
        _isDraggingBack = isDraggingBack
    }

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let horizontalTranslation = value.translation.width

                        // Only allow gestures from edges
                        let screenWidth = UIScreen.main.bounds.width
                        let edgeWidth: CGFloat = 44 // Width of the edge detection area

                        if value.startLocation.x < edgeWidth, canGoBack {
                            // Left edge gesture (go back)
                            state = max(0, horizontalTranslation)
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDraggingBack = true
                            }
                        } else if value.startLocation.x > screenWidth - edgeWidth, canGoForward {
                            // Right edge gesture (go forward)
                            state = min(0, horizontalTranslation)
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDraggingBack = false
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
                        } else if value.startLocation.x > UIScreen.main.bounds.width - 44,
                                  value.translation.width < -threshold, canGoForward
                        {
                            onForward()
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
