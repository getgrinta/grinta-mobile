import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false
    @State private var topColor = Color.neutral100
    @State private var bottomColor = Color.neutral100

    @Namespace private var namespace
    // When non‑nil, an image was selected and the web view appears.
    @State private var selectedImage: String? = nil

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(color: topColor, safeAreaInsets: proxy.safeAreaInsets)

                ZStack {
                    TabContainerView(namespace: namespace, selectedImage: selectedImage, onSelectedImage: {
                        selectedImage = $0
                    })
                    .background(topColor)

                    // --- Web View Overlay ---
                    if let selectedImage {
                        ZStack {
                            // Header area: the thumbnail animates into a large header.
                            // TODO: Fade out after 0.5s
//                            Image(selectedImage)
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(height: 300)
//                                .clipped()
//                                // Option: tap header to dismiss.
//                                .onTapGesture {
//                                    withAnimation(.spring()) {
//                                        self.selectedImage = nil
//                                    }
//                                }

                            WebView(url: store.currentURL)
                                .onBrandColorChange(region: .top(20)) { color in
                                    withAnimation {
                                        topColor = color
                                    }
                                }
                                .onBrandColorChange(region: .bottom(20)) { color in
                                    withAnimation {
                                        bottomColor = color
                                    }
                                }
                                .onWebsiteMetadata { metadata in
                                    store.send(.websiteMetadataFetched(metadata))
                                }
                        }
                        .matchedGeometryEffect(id: selectedImage, in: namespace)
                        .background(Color.white)
                        // Transition animation for the web view overlay.
                        .transition(.scale)
                        // Overlay a button in the web view to return to the grid.
                        .overlay(
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            self.selectedImage = nil
                                        }
                                    }) {
                                        Text("Back")
                                            .padding(8)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .padding()
                                }
                                Spacer()
                            }
                        )
                    }
                }

//                Group {
//                    WebView(url: store.currentURL)
//                        .onBrandColorChange(region: .top(20)) { color in
//                            withAnimation {
//                                topColor = color
//                            }
//                        }
//                        .onBrandColorChange(region: .bottom(20)) { color in
//                            withAnimation {
//                                bottomColor = color
//                            }
//                        }
//                        .onWebsiteMetadata { metadata in
//                            store.send(.websiteMetadataFetched(metadata))
//                        }
//                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                // which is reserved for the bottom bar
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }
                .animation(nil, value: store.currentURL)

                BottomBarBackgroundView(color: bottomColor)
            }
            .animation(nil, value: store.currentURL)
            .sheet(isPresented: $showSheet) {
                MagicSheetView(store: store.scope(state: \.magicSheet, action: \.magicSheet))
                    .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                        SettingsView(store: store)
                            .presentationDetents([.height(200)])
                    }
            }
            .ignoresSafeArea(.all)
        }
    }
}

private struct BottomBarBackgroundView: View {
    let color: Color

    var body: some View {
        color
    }
}

private struct StatusBarCoverView: View {
    let color: Color
    let safeAreaInsets: EdgeInsets

    var body: some View {
        color
            .frame(height: safeAreaInsets.top)
    }
}

#Preview {
    MainView(
        store: Store(initialState: Main.State()) {
            Main()
        }
    )
}

struct TabContainerView: View {
    let namespace: Namespace.ID

    // When non‑nil, an image was selected and the web view appears.
    var selectedImage: String? = nil
    var onSelectedImage: (String) -> Void
    // Example thumbnails: use names of images in your asset catalog.
    let thumbnails = ["image1", "thumb2", "thumb3", "thumb4", "thumb5"]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()),
                                GridItem(.flexible())],
                      spacing: 10)
            {
                ForEach(thumbnails, id: \.self) { imageName in
                    Image(imageName)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .border(Color.red)
                        // Both grid and header share this matched geometry.
                        .matchedGeometryEffect(id: imageName, in: namespace)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                onSelectedImage(imageName)
                            }
                        }
                }
            }
            .padding()
        }
        // Hide the grid when a thumbnail is selected.
        .opacity(selectedImage == nil ? 1 : 0)
    }
}
