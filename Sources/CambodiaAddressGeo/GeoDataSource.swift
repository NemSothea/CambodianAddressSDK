import Foundation

/// Provides commune centroid data to ``NearestCommuneFinder``.
///
/// Conformers may load from the bundle (``BundledGeoDataSource``), from a
/// remote endpoint, from an in-memory fixture for tests, etc.
public protocol GeoDataSource: Sendable {
    func load() async throws -> [CommuneGeoPoint]
}
