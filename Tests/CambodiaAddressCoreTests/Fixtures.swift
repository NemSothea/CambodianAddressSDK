import CambodiaAddressCore

/// Small, real-looking fixtures (Phnom Penh → Doun Penh → Phsar Thmei 3 → a village)
/// shared across Core test suites.
enum Fixtures {
    static let phnomPenh = Province(
        code: "12",
        name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")
    )

    static let dounPenh = District(
        code: "1201",
        provinceCode: "12",
        name: LocalizedName(km: "ដូនពេញ", en: "Doun Penh"),
        type: .khan
    )

    static let phsarThmei3 = Commune(
        code: "120103",
        districtCode: "1201",
        name: LocalizedName(km: "ផ្សារថ្មីទី៣", en: "Phsar Thmei 3"),
        type: .sangkat
    )

    static let village = Village(
        code: "12010301",
        communeCode: "120103",
        name: LocalizedName(km: "ភូមិ១", en: "Village 1")
    )

    static var fullSelection: AddressSelection {
        AddressSelection(province: phnomPenh, district: dounPenh, commune: phsarThmei3, village: village)
    }
}
