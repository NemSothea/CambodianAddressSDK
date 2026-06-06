import Foundation

/// Haversine great-circle distance between two WGS-84 coordinates.
///
/// Accurate to within ~0.3% for the distances involved (commune centroids
/// are at most a few tens of kilometres apart). No framework dependency.
enum HaversineDistance {
    /// Earth's mean radius in metres (WGS-84 approximation).
    private static let earthRadius: Double = 6_371_000

    /// Returns the distance in metres between `a` and `b`.
    static func metres(from a: Coordinate, to b: Coordinate) -> Double {
        let φ1 = a.latitude  * .pi / 180
        let φ2 = b.latitude  * .pi / 180
        let Δφ = (b.latitude  - a.latitude)  * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180

        let sinΔφ = sin(Δφ / 2)
        let sinΔλ = sin(Δλ / 2)
        let h = sinΔφ * sinΔφ + cos(φ1) * cos(φ2) * sinΔλ * sinΔλ
        return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
