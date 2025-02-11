import ComposableArchitecture
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>
    @State var textFieldLabel = "Ask an agent or search the web"

    init(store: StoreOf<Main>) {
        self.store = store
        UIPageControl.appearance().currentPageIndicatorTintColor = .primary
        UIPageControl.appearance().pageIndicatorTintColor = .neutral300
        UIPageControl.appearance().tintColor = .red
    }

    var body: some View {
        VStack {
            TabView {
                ScrollView {
                    HStack(alignment: .top) {
                        Text(store.output)
                            .frame(maxWidth: .infinity)
                    }
                }
                Text("Notes")
                Text("Settings")
            }
            .tabViewStyle(.page)
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    TextField(textFieldLabel, text: $store.search.sending(\.searchTextChanged))
                        .foregroundColor(.neutral400)
                        .font(.title3)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(.neutral200.opacity(0.5))
                        .mask(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.neutral200, lineWidth: 2)
                        )

                    Button {
                        store.send(.search)
                    } label: {
                        Image(systemSymbol: .magnifyingglass)
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .sensoryFeedback(trigger: store.output) { oldValue, newValue in
                        return .impact(flexibility: .solid, intensity: 0.3)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 32)
                .background(.neutral100)

                Color.clear
                    .ignoresSafeArea(.all)
                    .frame(maxWidth: .infinity)
                    .background(.neutral100)
            }
        }
        .background(Color.neutral50)
    }
}

#Preview {
    MainView(
        store: Store(initialState: Main.State()) {
            Main()
        }
    )
}
