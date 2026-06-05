import Foundation
import CambodiaAddressCore

/// Single decode path for raw dataset bytes, shared by every data source that reads the wire
/// format (bundle, remote). Treats input as untrusted and maps any failure to ``AddressError``.
enum DatasetDecoding {
    /// Decode wire-format JSON bytes into a domain ``AddressDataset``.
    static func decode(_ data: Data) throws -> AddressDataset {
        do {
            return try JSONDecoder().decode(WireDataset.self, from: data).toDomain()
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
    }

    /// Decode a domain-model cache snapshot (full property names, not wire short-keys).
    /// Used by ``DatasetCache/read()`` — the cache stores ``AddressDataset`` directly.
    static func decodeDataset(_ data: Data) throws -> AddressDataset {
        do {
            return try JSONDecoder().decode(AddressDataset.self, from: data)
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
    }

    /// Decode only the `version` field without allocating the full domain dataset.
    /// Used by ``BundledJSONDataSource/version`` to avoid a full re-decode just for sync checks.
    static func decodeVersion(_ data: Data) throws -> DatasetVersion {
        struct VersionOnly: Decodable { let version: String }
        do {
            return DatasetVersion(try JSONDecoder().decode(VersionOnly.self, from: data).version)
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
    }
}
