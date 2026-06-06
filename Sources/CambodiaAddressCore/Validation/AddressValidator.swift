import Foundation

/// Validates an ``AddressSelection`` for completeness, code format, and
/// parent-child consistency.
///
/// All checks run in one pass and every issue is collected — callers receive
/// the full list, not just the first failure.
///
/// ```swift
/// let issues = AddressValidator.validate(selection)
/// if issues.isEmpty { /* save */ }
/// ```
public enum AddressValidator {

    // MARK: - Public API

    /// Validate a selection, returning every issue found.
    ///
    /// - Parameter selection: The selection to check.
    /// - Parameter requiresVillage: When `true` (the default) a missing village
    ///   is reported as ``ValidationIssue/missingVillage``. Pass `false` for
    ///   flows that only require commune-level precision (e.g., delivery zones).
    /// - Returns: An array of ``ValidationIssue`` values. Empty means valid.
    public static func validate(
        _ selection: AddressSelection,
        requiresVillage: Bool = true
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // ── Completeness ────────────────────────────────────────────────────
        guard let province = selection.province else {
            issues.append(.missingProvince)
            return issues  // no further checks possible without a province
        }
        guard let district = selection.district else {
            issues.append(.missingDistrict)
            return issues
        }
        guard let commune = selection.commune else {
            issues.append(.missingCommune)
            return issues
        }
        if requiresVillage, selection.village == nil {
            issues.append(.missingVillage)
        }

        // ── Code format ─────────────────────────────────────────────────────
        if !isNumeric(province.code, length: 2) {
            issues.append(.invalidProvinceCode(province.code))
        }
        if !isNumeric(district.code, length: 4) {
            issues.append(.invalidDistrictCode(district.code))
        }
        if !isNumeric(commune.code, length: 6) {
            issues.append(.invalidCommuneCode(commune.code))
        }
        if let village = selection.village, !isNumeric(village.code, length: 8) {
            issues.append(.invalidVillageCode(village.code))
        }

        // ── Parent-child consistency ─────────────────────────────────────────
        if district.provinceCode != province.code {
            issues.append(.districtProvinceMismatch(
                districtProvinceCode: district.provinceCode,
                selectedProvinceCode: province.code
            ))
        }
        if commune.districtCode != district.code {
            issues.append(.communeDistrictMismatch(
                communeDistrictCode: commune.districtCode,
                selectedDistrictCode: district.code
            ))
        }
        if let village = selection.village, village.communeCode != commune.code {
            issues.append(.villageCommuneMismatch(
                villageCommuneCode: village.communeCode,
                selectedCommuneCode: commune.code
            ))
        }

        return issues
    }

    /// Returns `true` only when `validate` reports no issues.
    public static func isValid(
        _ selection: AddressSelection,
        requiresVillage: Bool = true
    ) -> Bool {
        validate(selection, requiresVillage: requiresVillage).isEmpty
    }

    // MARK: - Helpers

    private static func isNumeric(_ code: String, length: Int) -> Bool {
        code.count == length && code.allSatisfy(\.isNumber)
    }
}
