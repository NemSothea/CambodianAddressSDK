import SwiftUI
import CambodiaAddress

/// Root tab container. Language is owned here so the toggle in the Picker tab
/// restyles badges and breadcrumbs across all tabs.
struct RootTabView: View {
    let cambodia: CambodiaAddress
    @State private var language: AddressLanguage = .english

    var body: some View {
        TabView {
            PickerDemoView(language: $language)
                .tabItem { Label("Picker", systemImage: "list.bullet.indent") }

            SearchDemoView(cambodia: cambodia, language: language)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            UIKitDemoView(cambodia: cambodia, language: language)
                .tabItem { Label("UIKit", systemImage: "uiwindow.split.2x1") }

            GeoMapDemoView(cambodia: cambodia)
                .tabItem { Label("Map", systemImage: "map") }

            ValidationDemoView()
                .tabItem { Label("Validate", systemImage: "checkmark.shield") }
        }
        .addressLanguage(language)
    }
}

#Preview {
    let cambodia = CambodiaAddress.live()
    RootTabView(cambodia: cambodia)
        .cambodiaAddress(cambodia)
}
