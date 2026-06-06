import Foundation

/// A geographic coordinate (WGS-84).
///
/// Defined here so ``CambodiaAddressGeo`` has no dependency on CoreLocation or MapKit.
/// Convert to `CLLocationCoordinate2D` when needed:
/// ```swift
/// CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
/// ```
public struct Coordinate: Codable, Sendable, Hashable {
    /// Latitude in decimal degrees, positive = north.
    public let latitude: Double
    /// Longitude in decimal degrees, positive = east.
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
    }
}

extension Coordinate: CustomStringConvertible {
    public var description: String {
        String(format: "(%.5f, %.5f)", latitude, longitude)
    }
}
