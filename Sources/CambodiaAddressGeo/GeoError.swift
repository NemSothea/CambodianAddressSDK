import Foundation

/// Errors thrown by the geo layer.
public enum GeoError: Error, Sendable, Equatable {
    /// The bundled geodata resource could not be found in the module bundle.
    case resourceNotFound(String)
    /// The geodata could not be decoded. Associated value is a diagnostic string.
    case decodingFailed(String)
    /// The centroid dataset contains no points; nearest-commune lookup is impossible.
    case noPoints
    /// Geo lookup was attempted before data finished loading.
    case notLoaded
}

extension GeoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name): "Geo resource not found: \(name)"
        case .decodingFailed(let msg):    "Geo data decoding failed: \(msg)"
        case .noPoints:                   "Commune geodata contains no points."
        case .notLoaded:                  "Geo data has not been loaded yet."
        }
    }
}
