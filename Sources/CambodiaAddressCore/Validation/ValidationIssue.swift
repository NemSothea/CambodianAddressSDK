import Foundation

/// A single problem found during address validation.
public enum ValidationIssue: Error, Sendable, Hashable {

    // MARK: Completeness

    /// No province has been selected.
    case missingProvince
    /// No district has been selected (province is present).
    case missingDistrict
    /// No commune has been selected (district is present).
    case missingCommune
    /// No village has been selected (commune is present).
    case missingVillage

    // MARK: Code format

    /// The province code is not exactly 2 numeric digits.
    case invalidProvinceCode(String)
    /// The district code is not exactly 4 numeric digits.
    case invalidDistrictCode(String)
    /// The commune code is not exactly 6 numeric digits.
    case invalidCommuneCode(String)
    /// The village code is not exactly 8 numeric digits.
    case invalidVillageCode(String)

    // MARK: Parent-child consistency

    /// The district's province code does not match the selected province.
    case districtProvinceMismatch(districtProvinceCode: String, selectedProvinceCode: String)
    /// The commune's district code does not match the selected district.
    case communeDistrictMismatch(communeDistrictCode: String, selectedDistrictCode: String)
    /// The village's commune code does not match the selected commune.
    case villageCommuneMismatch(villageCommuneCode: String, selectedCommuneCode: String)
}

extension ValidationIssue: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingProvince:
            return "No province selected."
        case .missingDistrict:
            return "No district selected."
        case .missingCommune:
            return "No commune selected."
        case .missingVillage:
            return "No village selected."
        case .invalidProvinceCode(let code):
            return "Province code \"\(code)\" must be exactly 2 numeric digits."
        case .invalidDistrictCode(let code):
            return "District code \"\(code)\" must be exactly 4 numeric digits."
        case .invalidCommuneCode(let code):
            return "Commune code \"\(code)\" must be exactly 6 numeric digits."
        case .invalidVillageCode(let code):
            return "Village code \"\(code)\" must be exactly 8 numeric digits."
        case .districtProvinceMismatch(let dc, let pc):
            return "District province code \"\(dc)\" does not match selected province \"\(pc)\"."
        case .communeDistrictMismatch(let cc, let dc):
            return "Commune district code \"\(cc)\" does not match selected district \"\(dc)\"."
        case .villageCommuneMismatch(let vc, let cc):
            return "Village commune code \"\(vc)\" does not match selected commune \"\(cc)\"."
        }
    }
}
