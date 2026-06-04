import SwiftUI
import CambodiaAddress

@main
struct CambodiaAddressExampleApp: App {
    // One live facade (bundled offline data + search engine) shared by all tabs.
    @State private var cambodia = CambodiaAddress.live()

    var body: some Scene {
        WindowGroup {
            RootTabView(cambodia: cambodia)
                // Injects the repository + language for every picker subtree.
                .cambodiaAddress(cambodia)
        }
    }
}
