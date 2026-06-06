import Foundation

/// Finds the commune whose centroid is closest to a given GPS coordinate.
///
/// Geo data loads lazily on the first query, exactly once, and is then held
/// in memory. Concurrent callers share the same in-flight load (actor
/// guarantees mutual exclusion without explicit locking in call sites).
///
/// ```swift
/// let finder = NearestCommuneFinder()
/// let code = try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.56, longitude: 104.92))
/// // → "120101" (Voat Phnum sangkat, Phnom Penh)
/// ```
public actor NearestCommuneFinder {

    private let dataSource: any GeoDataSource
    private var points: [CommuneGeoPoint]?
    private var loadTask: Task<[CommuneGeoPoint], Error>?

    /// - Parameter dataSource: Source of commune centroid data.
    ///   Defaults to the bundled `cambodia_communes_geo.json`.
    public init(dataSource: any GeoDataSource = BundledGeoDataSource()) {
        self.dataSource = dataSource
    }

    /// Returns the NCDD commune code of the commune whose centroid is
    /// geographically closest to `coordinate`.
    ///
    /// - Throws: ``GeoError/notLoaded`` if the centroid data cannot be read,
    ///   or ``GeoError/noPoints`` if the dataset contains zero entries.
    public func nearestCommuneCode(to coordinate: Coordinate) async throws -> String {
        let pts = try await ensureLoaded()
        guard !pts.isEmpty else { throw GeoError.noPoints }

        var best: (code: String, dist: Double) = ("", .infinity)
        for pt in pts {
            let d = HaversineDistance.metres(from: coordinate, to: pt.coordinate)
            if d < best.dist { best = (pt.communeCode, d) }
        }
        return best.code
    }

    /// Returns the full list of loaded centroid points (useful for debugging /
    /// building a spatial index on top).
    public func allPoints() async throws -> [CommuneGeoPoint] {
        try await ensureLoaded()
    }

    // MARK: - Loading

    private func ensureLoaded() async throws -> [CommuneGeoPoint] {
        if let points { return points }
        if let task = loadTask { return try await task.value }

        let source = dataSource
        let task = Task<[CommuneGeoPoint], Error> { try await source.load() }
        loadTask = task
        do {
            let pts = try await task.value
            points = pts
            loadTask = nil
            return pts
        } catch {
            loadTask = nil
            throw error
        }
    }
}
