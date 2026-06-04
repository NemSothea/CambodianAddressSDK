import Foundation
import CambodiaAddressCore

/// Fetches a dataset snapshot from a remote endpoint (v3 API sync).
///
/// Offline-first design means the SDK never *depends* on this — it is meant to sit behind a
/// ``CachingDataSource`` that falls back to the bundled dataset. The fetch enforces a security
/// contract on untrusted input:
///
/// - **HTTPS only.** A non-HTTPS endpoint is rejected before any request (override with
///   ``Configuration/allowsInsecureHTTP`` for local testing).
/// - **Size cap.** The body is streamed and aborted once it exceeds
///   ``Configuration/maximumResponseBytes`` (and rejected up front if the declared
///   `Content-Length` already exceeds it) — a memory-exhaustion guard against a hostile server.
/// - **Status + decode validation.** Non-2xx is an error; the payload is decoded through the
///   same untrusted wire path as every other source.
///
/// TLS validation is the `URLSession` default; inject a session with a pinning delegate for
/// certificate pinning.
public struct RemoteAddressDataSource: AddressDataSource {

    /// Tunables for the remote fetch.
    public struct Configuration: Sendable {
        /// Hard upper bound on the response body, in bytes. Default 32 MB.
        public var maximumResponseBytes: Int
        /// Per-request timeout, in seconds. Default 30.
        public var timeout: TimeInterval
        /// Allow a plain-HTTP endpoint. Default `false` (HTTPS required).
        public var allowsInsecureHTTP: Bool

        public init(
            maximumResponseBytes: Int = 32 * 1024 * 1024,
            timeout: TimeInterval = 30,
            allowsInsecureHTTP: Bool = false
        ) {
            self.maximumResponseBytes = maximumResponseBytes
            self.timeout = timeout
            self.allowsInsecureHTTP = allowsInsecureHTTP
        }
    }

    public let endpoint: URL
    private let configuration: Configuration
    private let session: URLSession

    public init(
        endpoint: URL,
        configuration: Configuration = .init(),
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.configuration = configuration
        self.session = session
    }

    public func load() async throws -> AddressDataset {
        let data = try await fetch()
        return try DatasetDecoding.decode(data)
    }

    /// Note: with a single full-dataset endpoint this downloads the whole snapshot. A future
    /// lightweight version endpoint can override this to avoid the transfer.
    public var version: DatasetVersion {
        get async throws { try await load().version }
    }

    // MARK: - Networking

    private func fetch() async throws -> Data {
        guard configuration.allowsInsecureHTTP || endpoint.scheme?.lowercased() == "https" else {
            throw AddressError.insecureEndpoint(endpoint.absoluteString)
        }

        var request = URLRequest(url: endpoint, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"

        do {
            let (bytes, response) = try await session.bytes(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AddressError.invalidResponse(statusCode: 0)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw AddressError.invalidResponse(statusCode: http.statusCode)
            }

            let cap = configuration.maximumResponseBytes
            // Cheap rejection: trust nothing, but if the server *declares* an oversized body, bail
            // before streaming it.
            if http.expectedContentLength > 0, http.expectedContentLength > Int64(cap) {
                throw AddressError.payloadTooLarge
            }

            var data = Data()
            if http.expectedContentLength > 0 {
                data.reserveCapacity(min(cap, Int(http.expectedContentLength)))
            }
            // Streaming backstop: enforce the cap even when Content-Length is absent (chunked).
            for try await byte in bytes {
                data.append(byte)
                if data.count > cap { throw AddressError.payloadTooLarge }
            }
            return data
        } catch let error as AddressError {
            throw error
        } catch {
            throw AddressError.network(String(describing: error))
        }
    }
}
