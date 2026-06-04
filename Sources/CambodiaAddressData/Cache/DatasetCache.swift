import Foundation
import CambodiaAddressCore

/// Persists a downloaded ``AddressDataset`` to disk so a synced snapshot survives across launches.
///
/// Stores the domain dataset as JSON. Reads are best-effort: a missing or corrupt cache returns
/// `nil` rather than throwing, so a damaged file can never break the offline-first load path.
public struct DatasetCache: Sendable {
    /// Where the cached snapshot is written.
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Default location: `<Caches>/CambodiaAddressSDK/dataset.json`, falling back to the temporary
    /// directory if no caches directory is available.
    public static var `default`: DatasetCache {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = base
            .appendingPathComponent("CambodiaAddressSDK", isDirectory: true)
            .appendingPathComponent("dataset.json", isDirectory: false)
        return DatasetCache(fileURL: url)
    }

    /// The cached snapshot, or `nil` if absent/unreadable/corrupt.
    public func read() -> AddressDataset? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AddressDataset.self, from: data)
    }

    /// Atomically write a snapshot, creating the enclosing directory if needed.
    public func write(_ dataset: AddressDataset) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(dataset)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Remove the cached snapshot (no-op if it doesn't exist).
    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
