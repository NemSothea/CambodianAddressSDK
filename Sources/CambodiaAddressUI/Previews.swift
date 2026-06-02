#if DEBUG
import SwiftUI
import CambodiaAddressCore
import CambodiaAddressData
import CambodiaAddressSearch

/// Sample data + repository used only by SwiftUI previews.
enum AddressPreviewData {
    static let dataset = AddressDataset(
        version: "preview",
        provinces: [
            Province(code: "12", name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")),
            Province(code: "08", name: LocalizedName(km: "កណ្ដាល", en: "Kandal")),
        ],
        districts: [
            District(code: "1201", provinceCode: "12", name: LocalizedName(km: "ដូនពេញ", en: "Doun Penh"), type: .khan),
            District(code: "1202", provinceCode: "12", name: LocalizedName(km: "ចំការមន", en: "Chamkar Mon"), type: .khan),
            District(code: "0801", provinceCode: "08", name: LocalizedName(km: "កណ្ដាលស្ទឹង", en: "Kandal Stueng"), type: .district),
        ],
        communes: [
            Commune(code: "120101", districtCode: "1201", name: LocalizedName(km: "វត្តភ្នំ", en: "Voat Phnum"), type: .sangkat),
            Commune(code: "120103", districtCode: "1201", name: LocalizedName(km: "ផ្សារថ្មីទី៣", en: "Phsar Thmei Ti Bei"), type: .sangkat),
            Commune(code: "120201", districtCode: "1202", name: LocalizedName(km: "ទន្លេបាសាក់", en: "Tonle Basak"), type: .sangkat),
        ],
        villages: [
            Village(code: "12010101", communeCode: "120101", name: LocalizedName(km: "ភូមិ១", en: "Phum 1")),
            Village(code: "12010301", communeCode: "120103", name: LocalizedName(km: "ភូមិ១", en: "Phum 1")),
            Village(code: "12020101", communeCode: "120201", name: LocalizedName(km: "ភូមិ១", en: "Phum 1")),
        ]
    )

    static func repository() -> any AddressRepository {
        DefaultAddressRepository(
            dataSource: InMemoryDataSource(dataset),
            searchProvider: { AddressSearchEngine(dataset: $0) }
        )
    }
}

#Preview("Picker — English") {
    @Previewable @State var selection = AddressSelection()
    ScrollView {
        CambodiaAddressPicker(selection: $selection)
            .padding()
    }
    .cambodiaAddress(AddressPreviewData.repository())
    .addressLanguage(.english)
}

#Preview("Picker — Khmer") {
    @Previewable @State var selection = AddressSelection()
    ScrollView {
        CambodiaAddressPicker(selection: $selection)
            .padding()
    }
    .cambodiaAddress(AddressPreviewData.repository())
    .addressLanguage(.khmer)
}

#Preview("Standalone screen") {
    AddressPickerView { _ in }
        .cambodiaAddress(AddressPreviewData.repository())
        .addressLanguage(.english)
}
#endif
