import SwiftUI
import CambodiaAddressUI

public extension View {
    /// Inject a configured ``CambodiaAddress`` facade — sets both the repository and the
    /// language for the address picker subtree in one call.
    ///
    /// ```swift
    /// ContentView()
    ///     .cambodiaAddress(.live(.init(language: .khmer)))
    /// ```
    func cambodiaAddress(_ address: CambodiaAddress) -> some View {
        self
            .cambodiaAddress(address.repository)
            .addressLanguage(address.configuration.language)
    }
}
