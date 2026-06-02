#if canImport(UIKit)
import UIKit
import SwiftUI
import CambodiaAddressCore

/// UIKit entry point: hosts ``AddressPickerView`` and reports the chosen address via a callback.
///
/// ```swift
/// let vc = CambodiaAddressPickerViewController { selection in … }
/// present(vc, animated: true)
/// ```
public final class CambodiaAddressPickerViewController: UIHostingController<AnyView> {

    /// - Parameters:
    ///   - initialSelection: a pre-existing selection to resume from.
    ///   - language: language for names and chrome.
    ///   - repository: optional custom repository; defaults to bundled offline data + search.
    ///   - onComplete: called with the selected address when the user taps Done.
    public init(
        initialSelection: AddressSelection = .init(),
        language: AddressLanguage = .system,
        repository: (any AddressRepository)? = nil,
        onComplete: @escaping (AddressSelection) -> Void
    ) {
        let view = AddressPickerView(initialSelection: initialSelection, onComplete: onComplete)
            .addressLanguage(language)

        let rooted: AnyView = if let repository {
            AnyView(view.cambodiaAddress(repository))
        } else {
            AnyView(view)
        }
        super.init(rootView: rooted)
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
#endif
