import Foundation

/// Loads commune centroid data from `cambodia_communes_geo.json` bundled
/// inside the `CambodiaAddressGeo` module.
public struct BundledGeoDataSource: GeoDataSource, Sendable {
    private let bundle: Bundle

    public init() { self.bundle = .module }
    init(bundle: Bundle) { self.bundle = bundle }

    public func load() async throws -> [CommuneGeoPoint] {
        guard let url = bundle.url(forResource: "cambodia_communes_geo", withExtension: "json") else {
            throw GeoError.resourceNotFound("cambodia_communes_geo.json")
        }
        let data = try Data(contentsOf: url)
        let wrapper = try JSONDecoder().decode(GeoDatasetWrapper.self, from: data)
        return wrapper.points
    }

    // {"version":"…","points":[…]}
    private struct GeoDatasetWrapper: Decodable {
        let points: [CommuneGeoPoint]
    }
}
