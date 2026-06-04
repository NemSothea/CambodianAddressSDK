import Testing
import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressData

// MARK: - URLProtocol stub (deterministic, no real network)

/// Intercepts requests and replays a canned response keyed by URL, so remote-sync tests are
/// hermetic. Each test uses a distinct URL to avoid cross-test interference.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response { let status: Int; let headers: [String: String]; let body: Data }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Response] = [:]

    static func set(_ response: Response, for url: URL) {
        lock.withLock { responses[url.absoluteString] = response }
    }
    private static func response(for url: URL) -> Response? {
        lock.withLock { responses[url.absoluteString] }
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let resp = Self.response(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let http = HTTPURLResponse(
            url: url, statusCode: resp.status, httpVersion: "HTTP/1.1", headerFields: resp.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - Fixtures

private let validWireJSON = #"""
{"version":"2030.01",
 "provinces":[{"code":"12","km":"ភ្នំពេញ","en":"Phnom Penh"}],
 "districts":[{"code":"1201","p":"12","km":"ដូនពេញ","en":"Doun Penh","t":"khan"}],
 "communes":[{"code":"120101","d":"1201","km":"វត្តភ្នំ","en":"Voat Phnum","t":"sangkat"}],
 "villages":[{"code":"12010101","c":"120101","km":"ភូមិ","en":"Phum 1"}]}
"""#

private func dataset(_ version: String) -> AddressDataset {
    AddressDataset(
        version: DatasetVersion(version),
        provinces: [Province(code: "12", name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh"))],
        districts: [], communes: [], villages: []
    )
}

private func tempCache() -> DatasetCache {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CambodiaAddressTests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("dataset.json")
    return DatasetCache(fileURL: url)
}

/// A source that always throws, to prove offline-first paths never depend on it.
private struct FailingDataSource: AddressDataSource {
    func load() async throws -> AddressDataset { throw AddressError.network("offline") }
    var version: DatasetVersion { get async throws { throw AddressError.network("offline") } }
}

// MARK: - RemoteAddressDataSource

@Suite struct RemoteAddressDataSourceTests {

    private func remote(_ url: URL, config: RemoteAddressDataSource.Configuration = .init()) -> RemoteAddressDataSource {
        RemoteAddressDataSource(endpoint: url, configuration: config, session: StubURLProtocol.makeSession())
    }

    @Test func decodesValidResponse() async throws {
        let url = URL(string: "https://example.test/decode")!
        StubURLProtocol.set(.init(status: 200, headers: ["Content-Type": "application/json"],
                                  body: Data(validWireJSON.utf8)), for: url)
        let dataset = try await remote(url).load()
        #expect(dataset.version == DatasetVersion("2030.01"))
        #expect(dataset.provinces.map(\.code) == ["12"])
        #expect(dataset.districts.first?.type == .khan)
    }

    @Test func rejectsNonHTTPSEndpointBeforeAnyRequest() async {
        let url = URL(string: "http://insecure.test/x")!   // no stub registered → would fail if hit
        await #expect(throws: AddressError.insecureEndpoint("http://insecure.test/x")) {
            try await remote(url).load()
        }
    }

    @Test func allowsHTTPWhenExplicitlyOptedIn() async throws {
        let url = URL(string: "http://local.test/ok")!
        StubURLProtocol.set(.init(status: 200, headers: [:], body: Data(validWireJSON.utf8)), for: url)
        let dataset = try await remote(url, config: .init(allowsInsecureHTTP: true)).load()
        #expect(dataset.provinces.count == 1)
    }

    @Test func rejectsDeclaredOversizePayload() async {
        let url = URL(string: "https://example.test/big-declared")!
        StubURLProtocol.set(.init(status: 200, headers: ["Content-Length": "100000000"],
                                  body: Data(validWireJSON.utf8)), for: url)
        await #expect(throws: AddressError.payloadTooLarge) {
            try await remote(url, config: .init(maximumResponseBytes: 16)).load()
        }
    }

    @Test func rejectsStreamedOversizePayloadWithoutContentLength() async {
        let url = URL(string: "https://example.test/big-streamed")!
        let big = Data(repeating: 0x41, count: 200)        // no Content-Length header → unknown length
        StubURLProtocol.set(.init(status: 200, headers: [:], body: big), for: url)
        await #expect(throws: AddressError.payloadTooLarge) {
            try await remote(url, config: .init(maximumResponseBytes: 16)).load()
        }
    }

    @Test func mapsNon200ToInvalidResponse() async {
        let url = URL(string: "https://example.test/down")!
        StubURLProtocol.set(.init(status: 503, headers: [:], body: Data()), for: url)
        await #expect(throws: AddressError.invalidResponse(statusCode: 503)) {
            try await remote(url).load()
        }
    }

    @Test func mapsMalformedJSONToDecodingFailed() async {
        let url = URL(string: "https://example.test/garbage")!
        StubURLProtocol.set(.init(status: 200, headers: [:], body: Data("not json".utf8)), for: url)
        await #expect(throws: (any Error).self) { try await remote(url).load() }
        // And specifically a decodingFailed:
        do { _ = try await remote(url).load(); Issue.record("expected throw") }
        catch let error as AddressError {
            guard case .decodingFailed = error else { Issue.record("wrong case: \(error)"); return }
        } catch { Issue.record("non-AddressError: \(error)") }
    }
}

// MARK: - CachingDataSource (offline-first decorator)

@Suite struct CachingDataSourceTests {

    @Test func loadReturnsBundleWhenNoCache() async throws {
        let cache = tempCache(); cache.clear()
        let source = CachingDataSource(
            remote: FailingDataSource(), fallback: InMemoryDataSource(dataset("2026.01")),
            cache: cache, refreshesInBackground: false
        )
        let loaded = try await source.load()
        #expect(loaded.version == DatasetVersion("2026.01"))
    }

    @Test func loadSurvivesRemoteFailureOffline() async throws {
        // Even with a remote that always throws, load() must succeed from the bundle.
        let cache = tempCache(); cache.clear()
        let source = CachingDataSource(
            remote: FailingDataSource(), fallback: InMemoryDataSource(dataset("2026.01")),
            cache: cache, refreshesInBackground: false
        )
        let loaded = try await source.load()
        #expect(loaded.version == DatasetVersion("2026.01"))
    }

    @Test func refreshWritesCacheWhenRemoteIsNewer() async throws {
        let cache = tempCache(); cache.clear()
        let source = CachingDataSource(
            remote: InMemoryDataSource(dataset("2030.01")), fallback: InMemoryDataSource(dataset("2026.01")),
            cache: cache, refreshesInBackground: false
        )
        let updated = try await source.refresh()
        #expect(updated)
        #expect(cache.read()?.version == DatasetVersion("2030.01"))
    }

    @Test func refreshSkipsWhenRemoteNotNewer() async throws {
        let cache = tempCache()
        try cache.write(dataset("2030.01"))                       // already have the newest
        let source = CachingDataSource(
            remote: InMemoryDataSource(dataset("2026.01")),       // older remote
            fallback: InMemoryDataSource(dataset("2025.01")),
            cache: cache, refreshesInBackground: false
        )
        let updated = try await source.refresh()
        #expect(!updated)
        #expect(cache.read()?.version == DatasetVersion("2030.01"))   // untouched
    }

    @Test func loadPrefersCacheOverOlderBundle() async throws {
        let cache = tempCache()
        try cache.write(dataset("2030.01"))
        let source = CachingDataSource(
            remote: FailingDataSource(), fallback: InMemoryDataSource(dataset("2026.01")),
            cache: cache, refreshesInBackground: false
        )
        #expect(try await source.load().version == DatasetVersion("2030.01"))
    }

    @Test func loadPrefersBundleOverStaleCache() async throws {
        let cache = tempCache()
        try cache.write(dataset("2024.01"))                       // stale cached download
        let source = CachingDataSource(
            remote: FailingDataSource(), fallback: InMemoryDataSource(dataset("2026.06")),   // newer bundle
            cache: cache, refreshesInBackground: false
        )
        #expect(try await source.load().version == DatasetVersion("2026.06"))
    }
}

// MARK: - DatasetCache

@Suite struct DatasetCacheTests {

    @Test func roundTripsDataset() throws {
        let cache = tempCache()
        try cache.write(dataset("2030.01"))
        #expect(cache.read()?.version == DatasetVersion("2030.01"))
    }

    @Test func readReturnsNilWhenMissing() {
        let cache = tempCache(); cache.clear()
        #expect(cache.read() == nil)
    }

    @Test func clearRemovesCache() throws {
        let cache = tempCache()
        try cache.write(dataset("2030.01"))
        cache.clear()
        #expect(cache.read() == nil)
    }
}
