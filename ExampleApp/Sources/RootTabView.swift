import SwiftUI
import CambodiaAddress

/// Hosts the three demo tabs. Language is owned here so the toggle in the
/// Picker tab restyles badges and breadcrumbs everywhere.
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
        }
        .addressLanguage(language)
    }
}

#Preview {
    let cambodia = CambodiaAddress.live()
    RootTabView(cambodia: cambodia)
        .cambodiaAddress(cambodia)
}
