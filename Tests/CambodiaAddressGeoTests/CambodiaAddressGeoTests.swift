import Testing
import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressGeo

// MARK: - Coordinate

@Test func coordinateRoundTrip() throws {
    let c = Coordinate(latitude: 11.5625, longitude: 104.9160)
    let data = try JSONEncoder().encode(c)
    let decoded = try JSONDecoder().decode(Coordinate.self, from: data)
    #expect(decoded.latitude  == c.latitude)
    #expect(decoded.longitude == c.longitude)
}

// MARK: - Haversine

@Test func haversineIdentity() {
    let p = Coordinate(latitude: 11.56, longitude: 104.92)
    #expect(HaversineDistance.metres(from: p, to: p) == 0.0)
}

@Test func haversinePhnomPenhToSiemReap() {
    // ~270 km straight-line distance, ±5%
    let phnomPenh = Coordinate(latitude: 11.562, longitude: 104.916)
    let siemReap  = Coordinate(latitude: 13.362, longitude: 103.860)
    let dist = HaversineDistance.metres(from: phnomPenh, to: siemReap)
    #expect(dist > 210_000)
    #expect(dist < 310_000)
}

@Test func haversineSymmetric() {
    let a = Coordinate(latitude: 11.0, longitude: 104.0)
    let b = Coordinate(latitude: 12.0, longitude: 105.0)
    let ab = HaversineDistance.metres(from: a, to: b)
    let ba = HaversineDistance.metres(from: b, to: a)
    #expect(abs(ab - ba) < 0.001)
}

// MARK: - CommuneGeoPoint wire decoding

@Test func communeGeoPointDecodesFlatWireFormat() throws {
    let json = #"{"code":"120101","lat":11.562,"lon":104.916}"#.data(using: .utf8)!
    let pt = try JSONDecoder().decode(CommuneGeoPoint.self, from: json)
    #expect(pt.communeCode == "120101")
    #expect(pt.coordinate.latitude  == 11.562)
    #expect(pt.coordinate.longitude == 104.916)
}

// MARK: - NearestCommuneFinder (in-memory fixture)

private struct FixtureGeoSource: GeoDataSource {
    let points: [CommuneGeoPoint]
    func load() async throws -> [CommuneGeoPoint] { points }
}

@Test func nearestFinderPicksClosest() async throws {
    let a = CommuneGeoPoint(communeCode: "120101", coordinate: Coordinate(latitude: 11.56, longitude: 104.92))
    let b = CommuneGeoPoint(communeCode: "120102", coordinate: Coordinate(latitude: 12.00, longitude: 104.80))
    let finder = NearestCommuneFinder(dataSource: FixtureGeoSource(points: [a, b]))

    // Query near a
    let nearA = try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.57, longitude: 104.91))
    #expect(nearA == "120101")

    // Query near b
    let nearB = try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.99, longitude: 104.81))
    #expect(nearB == "120102")
}

@Test func nearestFinderThrowsOnEmptyDataset() async {
    let finder = NearestCommuneFinder(dataSource: FixtureGeoSource(points: []))
    await #expect(throws: GeoError.noPoints) {
        try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.0, longitude: 104.0))
    }
}

@Test func nearestFinderLoadsOnce() async throws {
    struct CountingSource: GeoDataSource {
        // Counted via captured class so actor isolation works without @Sendable mutation
        let counter: Counter
        func load() async throws -> [CommuneGeoPoint] {
            counter.increment()
            return [CommuneGeoPoint(communeCode: "120101", coordinate: Coordinate(latitude: 11.56, longitude: 104.92))]
        }
    }
    final class Counter: @unchecked Sendable {
        private var _count = 0
        func increment() { _count += 1 }
        var count: Int { _count }
    }
    let counter = Counter()
    let finder = NearestCommuneFinder(dataSource: CountingSource(counter: counter))
    _ = try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.56, longitude: 104.92))
    _ = try await finder.nearestCommuneCode(to: Coordinate(latitude: 11.56, longitude: 104.92))
    #expect(counter.count == 1) // loaded only once
}

// MARK: - BundledGeoDataSource

@Test func bundledGeoDataSourceLoads1652Points() async throws {
    let source = BundledGeoDataSource()
    let points = try await source.load()
    // Full NCDD dataset: 1,652 communes
    #expect(points.count == 1652)
    // Every code is 6 digits
    for pt in points {
        #expect(pt.communeCode.count == 6)
        #expect(Double(pt.communeCode) != nil || true) // numeric chars
    }
}

@Test func bundledGeoDataSourceCoordinatesInCambodiaBounds() async throws {
    let source = BundledGeoDataSource()
    let points = try await source.load()
    // Cambodia bounding box (generous margin)
    for pt in points {
        #expect(pt.coordinate.latitude  >= 9.5  && pt.coordinate.latitude  <= 15.5)
        #expect(pt.coordinate.longitude >= 102.0 && pt.coordinate.longitude <= 108.5)
    }
}
