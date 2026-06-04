import Foundation

/// Errors surfaced by the SDK's data and repository layers.
public enum AddressError: Error, Sendable, Equatable {
    /// A query ran before the dataset finished loading.
    case notLoaded
    /// The bundled/remote payload could not be decoded. Associated value is a diagnostic message.
    case decodingFailed(String)
    /// A required resource (e.g. the bundled JSON) was missing. Associated value is the resource name.
    case resourceNotFound(String)
    /// No administrative unit exists for the given code.
    case notFound(code: String)
    /// A feature stub that is reserved for a future version (e.g. remote sync).
    case notImplemented
    /// A remote endpoint used a non-HTTPS scheme (rejected before any request is made).
    /// Associated value is the offending URL string.
    case insecureEndpoint(String)
    /// A remote sync request failed at the transport layer. Associated value is a diagnostic message.
    case network(String)
    /// A remote response had a non-success HTTP status. Associated value is the status code.
    case invalidResponse(statusCode: Int)
    /// A remote payload exceeded the configured maximum size and was rejected (DoS guard).
    case payloadTooLarge
}

extension AddressError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notLoaded:
            "The address dataset has not been loaded yet."
        case .decodingFailed(let message):
            "Failed to decode the address dataset: \(message)"
        case .resourceNotFound(let name):
            "Required resource not found: \(name)"
        case .notFound(let code):
            "No administrative unit found for code \"\(code)\"."
        case .notImplemented:
            "This feature is not implemented in the current version."
        case .insecureEndpoint(let url):
            "Remote address endpoint must use HTTPS: \"\(url)\"."
        case .network(let message):
            "Network error while syncing the address dataset: \(message)"
        case .invalidResponse(let statusCode):
            "Remote address endpoint returned HTTP status \(statusCode)."
        case .payloadTooLarge:
            "The remote address dataset exceeded the maximum allowed size."
        }
    }
}
