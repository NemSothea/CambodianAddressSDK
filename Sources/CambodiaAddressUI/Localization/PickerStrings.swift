import CambodiaAddressCore

/// UI chrome strings (labels, placeholders, buttons) in Khmer and English.
///
/// Keyed off the SDK's own ``AddressLanguage`` rather than a String Catalog / device locale,
/// so the picker's chrome follows the *same* language as the place names it displays — if a
/// caller forces `.khmer`, the whole component is Khmer regardless of device settings. This is
/// deterministic and fully unit-testable. (A `.xcstrings` catalog could back this later without
/// changing the call sites.)
struct PickerStrings: Sendable {
    let language: AddressLanguage

    private func t(_ km: String, _ en: String) -> String {
        language.resolved == .khmer ? km : en
    }

    var provinceLabel: String { t("ខេត្ត / ក្រុង", "Province") }
    var districtLabel: String { t("ស្រុក / ខណ្ឌ", "District") }
    var communeLabel: String { t("ឃុំ / សង្កាត់", "Commune") }
    var villageLabel: String { t("ភូមិ", "Village") }

    var searchPlaceholder: String { t("ស្វែងរកអាសយដ្ឋាន", "Search address") }
    var selectPlaceholder: String { t("ជ្រើសរើស", "Select") }
    var doneButton: String { t("រួចរាល់", "Done") }
    var clearButton: String { t("សម្អាត", "Clear") }
    var noResults: String { t("រកមិនឃើញ", "No results") }
    var screenTitle: String { t("អាសយដ្ឋាន", "Address") }

    func label(for level: AdministrativeLevel) -> String {
        switch level {
        case .province: provinceLabel
        case .district: districtLabel
        case .commune:  communeLabel
        case .village:  villageLabel
        }
    }
}

/// A lightweight, display-ready item used by the selection lists.
struct PickerRowItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: LocalizedName
}
