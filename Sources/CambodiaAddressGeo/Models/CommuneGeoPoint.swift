import Foundation

/// The centroid coordinate of a single commune/sangkat.
///
/// Used by ``NearestCommuneFinder`` to locate the commune whose centre is
/// closest to a device GPS fix.
public struct CommuneGeoPoint: Codable, Sendable, Hashable {
    /// NCDD commune code (6 digits, e.g. `"120101"`).
    public let communeCode: String
    /// Approximate geographic centre of the commune.
    public let coordinate: Coordinate

    public init(communeCode: String, coordinate: Coordinate) {
        self.communeCode = communeCode
        self.coordinate = coordinate
    }

    // Wire format: {"code":"120101","lat":11.56,"lon":104.92}
    enum CodingKeys: String, CodingKey {
        case communeCode = "code"
        case coordinate  // flattened below
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: WireKeys.self)
        communeCode = try c.decode(String.self, forKey: .code)
        let lat = try c.decode(Double.self, forKey: .lat)
        let lon = try c.decode(Double.self, forKey: .lon)
        coordinate = Coordinate(latitude: lat, longitude: lon)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: WireKeys.self)
        try c.encode(communeCode, forKey: .code)
        try c.encode(coordinate.latitude,  forKey: .lat)
        try c.encode(coordinate.longitude, forKey: .lon)
    }

    private enum WireKeys: String, CodingKey {
        case code, lat, lon
    }
}
