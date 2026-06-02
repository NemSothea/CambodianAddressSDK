import SwiftUI
import CambodiaAddress

@main
struct CambodiaAddressExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the live SDK (bundled offline data + search engine).
                .cambodiaAddress(.live())
        }
    }
}
