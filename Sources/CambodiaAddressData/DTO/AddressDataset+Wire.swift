import CambodiaAddressCore

/// On-disk / wire representation of the dataset.
///
/// Uses short keys (`p`, `d`, `c`, `t`) to keep the bundled JSON small. This shape is a
/// data-layer concern: it decodes into the domain ``AddressDataset`` via ``toDomain()``,
/// so the file format can change without touching Core.
struct WireDataset: Decodable {
    let version: String
    let provinces: [WireProvince]
    let districts: [WireDistrict]
    let communes: [WireCommune]
    let villages: [WireVillage]
}

struct WireProvince: Decodable {
    let code: String
    let km: String
    let en: String
}

struct WireDistrict: Decodable {
    let code: String
    /// Parent province code.
    let p: String
    let km: String
    let en: String
    /// District type raw value; defaults to `.district` when absent.
    let t: String?
}

struct WireCommune: Decodable {
    let code: String
    /// Parent district code.
    let d: String
    let km: String
    let en: String
    /// Commune type raw value; defaults to `.commune` when absent.
    let t: String?
}

struct WireVillage: Decodable {
    let code: String
    /// Parent commune code.
    let c: String
    let km: String
    let en: String
}

extension WireDataset {
    /// Map the wire format into domain models.
    func toDomain() -> AddressDataset {
        AddressDataset(
            version: DatasetVersion(version),
            provinces: provinces.map {
                Province(code: $0.code, name: LocalizedName(km: $0.km, en: $0.en))
            },
            districts: districts.map {
                District(
                    code: $0.code,
                    provinceCode: $0.p,
                    name: LocalizedName(km: $0.km, en: $0.en),
                    type: $0.t.flatMap(DistrictType.init(rawValue:)) ?? .district
                )
            },
            communes: communes.map {
                Commune(
                    code: $0.code,
                    districtCode: $0.d,
                    name: LocalizedName(km: $0.km, en: $0.en),
                    type: $0.t.flatMap(CommuneType.init(rawValue:)) ?? .commune
                )
            },
            villages: villages.map {
                Village(code: $0.code, communeCode: $0.c, name: LocalizedName(km: $0.km, en: $0.en))
            }
        )
    }
}
