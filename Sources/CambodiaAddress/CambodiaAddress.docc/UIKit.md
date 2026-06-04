# Using the picker from UIKit

Present the address picker from a view controller and receive the selection in a callback.

## Overview

`CambodiaAddressPickerViewController` is the SDK's UIKit entry point: a
`UIHostingController` that wraps the standalone ``AddressPickerView`` and
reports the chosen address when the user taps **Done**.

### Present and receive

```swift
import CambodiaAddress

final class CheckoutViewController: UIViewController {

    @objc private func pickAddress() {
        let picker = CambodiaAddressPickerViewController(language: .khmer) { [weak self] selection in
            self?.addressLabel.text = AddressFormatter(language: .khmer).string(from: selection)
            self?.dismiss(animated: true)
        }
        present(picker, animated: true)
    }
}
```

### Resuming an existing selection

Pass the previously chosen address so the picker opens pre-filled:

```swift
let picker = CambodiaAddressPickerViewController(
    initialSelection: savedAddress,
    onComplete: { selection in … }
)
```

### Sharing a repository

By default the controller builds its own repository over the bundled offline
dataset. If your app already holds a ``CambodiaAddress`` facade (for example,
one configured with `.synced` data), hand its repository to the controller so
both use the same data source:

```swift
let picker = CambodiaAddressPickerViewController(
    repository: cambodia.repository,
    onComplete: { selection in … }
)
```

> Tip: The example app's **UIKit** tab shows the controller presented from
> SwiftUI via `UIViewControllerRepresentable` — the same pattern works for
> mixed UIKit/SwiftUI codebases.

## See Also

- ``AddressPickerView``
- ``AddressSelection``
- <doc:Configuration>
