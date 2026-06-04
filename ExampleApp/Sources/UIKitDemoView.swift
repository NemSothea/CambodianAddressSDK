import SwiftUI
import CambodiaAddress

/// Tab 3 — the UIKit entry point. Presents `CambodiaAddressPickerViewController`
/// (a `UIHostingController`) from SwiftUI via `UIViewControllerRepresentable`,
/// exactly as a UIKit app would present it from a view controller.
struct UIKitDemoView: View {
    let cambodia: CambodiaAddress
    let language: AddressLanguage

    @State private var result = AddressSelection()
    @State private var presenting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Result from UIKit controller") {
                    if result.isEmpty {
                        Text("Nothing selected yet").foregroundStyle(.secondary)
                    } else {
                        Text(AddressFormatter(language: language).string(from: result))
                    }
                }

                Section {
                    Button("Present CambodiaAddressPickerViewController") {
                        presenting = true
                    }
                } footer: {
                    Text("""
                    In a UIKit app:

                    let vc = CambodiaAddressPickerViewController { selection in … }
                    present(vc, animated: true)
                    """)
                    .font(.caption.monospaced())
                }
            }
            .navigationTitle("UIKit")
            .sheet(isPresented: $presenting) {
                AddressPickerControllerRepresentable(
                    initialSelection: result,
                    language: language,
                    repository: cambodia.repository
                ) { selected in
                    result = selected
                    presenting = false
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// Thin bridge so the demo can host the UIKit controller inside SwiftUI.
private struct AddressPickerControllerRepresentable: UIViewControllerRepresentable {
    let initialSelection: AddressSelection
    let language: AddressLanguage
    let repository: any AddressRepository
    let onComplete: (AddressSelection) -> Void

    func makeUIViewController(context: Context) -> CambodiaAddressPickerViewController {
        CambodiaAddressPickerViewController(
            initialSelection: initialSelection,
            language: language,
            repository: repository,
            onComplete: onComplete
        )
    }

    func updateUIViewController(_ controller: CambodiaAddressPickerViewController, context: Context) {}
}

#Preview {
    UIKitDemoView(cambodia: .live(), language: .english)
}
