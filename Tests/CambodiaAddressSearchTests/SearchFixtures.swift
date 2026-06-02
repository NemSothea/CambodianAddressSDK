import CambodiaAddressCore
@testable import CambodiaAddressSearch

enum SearchFixtures {
    static let dataset = AddressDataset(
        version: "search-test",
        provinces: [
            Province(code: "12", name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")),
            Province(code: "08", name: LocalizedName(km: "កណ្ដាល", en: "Kandal")),
        ],
        districts: [
            District(code: "1201", provinceCode: "12", name: LocalizedName(km: "ដូនពេញ", en: "Doun Penh"), type: .khan),
            District(code: "1202", provinceCode: "12", name: LocalizedName(km: "ចំការមន", en: "Chamkar Mon"), type: .khan),
        ],
        communes: [
            Commune(code: "120101", districtCode: "1201", name: LocalizedName(km: "វត្តភ្នំ", en: "Voat Phnum"), type: .sangkat),
            Commune(code: "120201", districtCode: "1202", name: LocalizedName(km: "ទន្លេបាសាក់", en: "Tonle Basak"), type: .sangkat),
        ],
        villages: [
            Village(code: "12010101", communeCode: "120101", name: LocalizedName(km: "ភូមិមួយ", en: "Village One")),
            Village(code: "12020101", communeCode: "120201", name: LocalizedName(km: "ភូមិពីរ", en: "Village Two")),
        ]
    )

    static let engine = AddressSearchEngine(dataset: dataset)

    static let allLevels = Set(AdministrativeLevel.allCases)

    /// A synthetic dataset of roughly `villages` villages for performance testing.
    static func large(villages targetVillages: Int) -> AddressDataset {
        var provinces: [Province] = []
        var districts: [District] = []
        var communes: [Commune] = []
        var villageList: [Village] = []

        // Word pools to produce varied, realistic-length tokens.
        let words = ["phnom", "penh", "doun", "chamkar", "tonle", "basak", "kandal",
                     "stueng", "ampov", "prey", "voat", "thmei", "boeng", "keng",
                     "sangkat", "phsar", "russey", "kaeo", "mean", "chey"]

        var made = 0
        var p = 0
        while made < targetVillages {
            let pCode = String(format: "%02d", (p % 89) + 10) // pseudo province codes 10..98
            provinces.append(Province(code: pCode + "\(p)", name: name(words, p)))
            for d in 0..<5 {
                let dCode = "\(pCode)\(p)d\(d)"
                districts.append(District(code: dCode, provinceCode: pCode + "\(p)", name: name(words, p + d), type: .district))
                for c in 0..<5 {
                    let cCode = "\(dCode)c\(c)"
                    communes.append(Commune(code: cCode, districtCode: dCode, name: name(words, p + d + c), type: .commune))
                    for v in 0..<8 where made < targetVillages {
                        villageList.append(Village(code: "\(cCode)v\(v)", communeCode: cCode, name: name(words, p + d + c + v)))
                        made += 1
                    }
                }
            }
            p += 1
        }
        return AddressDataset(version: "perf", provinces: provinces, districts: districts, communes: communes, villages: villageList)
    }

    private static func name(_ words: [String], _ seed: Int) -> LocalizedName {
        let a = words[seed % words.count]
        let b = words[(seed * 7 + 3) % words.count]
        return LocalizedName(km: "ភូមិ\(seed)", en: "\(a.capitalized) \(b.capitalized)")
    }
}
