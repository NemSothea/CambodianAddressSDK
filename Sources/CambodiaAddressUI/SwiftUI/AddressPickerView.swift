import SwiftUI
import CambodiaAddressCore

/// A standalone address-picking screen with a title and a Done action.
///
/// ```swift
/// AddressPickerView { selection in
///     save(selection)
/// }
/// ```
public struct AddressPickerView: View {
    @State private var selection: AddressSelection
    @Environment(\.addressLanguage) private var language

    private let onComplete: (AddressSelection) -> Void

    public init(
        initialSelection: AddressSelection = .init(),
        onComplete: @escaping (AddressSelection) -> Void
    ) {
        _selection = State(initialValue: initialSelection)
        self.onComplete = onComplete
    }

    public var body: some View {
        let strings = PickerStrings(language: language)
        NavigationStack {
            ScrollView {
                CambodiaAddressPicker(selection: $selection)
                    .padding()
            }
            .navigationTitle(strings.screenTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(strings.doneButton) {
                        onComplete(selection)
                    }
                    .disabled(!selection.isComplete)
                }
            }
        }
    }
}
