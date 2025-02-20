import SwiftUI

struct EdgeNavigationGesture: ViewModifier {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    
    @GestureState private var dragOffset: CGFloat = 0
    @State private var previousOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let horizontalTranslation = value.translation.width
                        
                        // Only allow gestures from edges
                        let screenWidth = UIScreen.main.bounds.width
                        let edgeWidth: CGFloat = 44 // Width of the edge detection area
                        
                        if value.startLocation.x < edgeWidth && canGoBack {
                            // Left edge gesture (go back)
                            state = max(0, horizontalTranslation)
                        } else if value.startLocation.x > screenWidth - edgeWidth && canGoForward {
                            // Right edge gesture (go forward)
                            state = min(0, horizontalTranslation)
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50 // Minimum drag distance to trigger navigation
                        
                        if value.startLocation.x < 44 && value.translation.width > threshold && canGoBack {
                            onBack()
                        } else if value.startLocation.x > UIScreen.main.bounds.width - 44 && 
                                  value.translation.width < -threshold && canGoForward {
                            onForward()
                        }
                    }
            )
            .offset(x: dragOffset)
            .animation(.interactiveSpring(), value: dragOffset)
    }
}
