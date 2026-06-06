import SwiftUI
import CambodiaAddressCore
import CambodiaAddressSearch

/// A searchable list of options for one administrative level, shown in a sheet.
///
/// Filtering uses ``KhmerNormalizer`` so Khmer and English queries both match (zero-width,
/// case, and diacritic tolerant). Built from system components, so Dynamic Type, Dark Mode,
/// and VoiceOver work without extra code.
struct LevelSelectionList: View {
    let title: String
    let items: [PickerRowItem]
    let language: AddressLanguage
    let selectedID: String?
    let searchPrompt: String
    let onSelect: (String) -> Void

    @State private var filter = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredItems: [PickerRowItem] {
        let query = KhmerNormalizer.normalize(filter)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            KhmerNormalizer.normalize(item.name.km).contains(query)
                || KhmerNormalizer.normalize(item.name.en).contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                Button {
                    onSelect(item.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(item.name.resolved(for: language))
                            .foregroundStyle(.primary)
                        Spacer()
                        if item.id == selectedID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Selected")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $filter, prompt: searchPrompt)
            .navigationTitle(title)
            .navigationBarTitleDisplayModeInlineIfAvailable()
        }
    }
}

extension View {
    /// Inline title on platforms that support it; no-op elsewhere (keeps macOS host builds happy).
    func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
}
