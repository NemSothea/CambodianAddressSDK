import Foundation
import CambodiaAddressCore

/// Offline-first decorator that layers a disk cache and a remote source over a guaranteed local
/// fallback (the bundled dataset).
///
/// `load()` never blocks on the network: it returns the freshest snapshot already on the device —
/// the cached download if present and at least as new as the bundle, otherwise the bundle — and
/// (optionally) kicks off a background refresh whose result is used on the *next* launch. This is
/// the v3 sync model: the app is always usable offline, and remote updates land opportunistically.
public struct CachingDataSource: AddressDataSource {
    private let remote: any AddressDataSource
    private let fallback: any AddressDataSource
    private let cache: DatasetCache
    private let refreshesInBackground: Bool

    /// - Parameters:
    ///   - remote: upstream source for newer snapshots (typically ``RemoteAddressDataSource``).
    ///   - fallback: always-available local source. Defaults to the bundled dataset.
    ///   - cache: disk persistence for downloaded snapshots. Defaults to ``DatasetCache/default``.
    ///   - refreshesInBackground: if `true`, `load()` triggers a detached refresh. Set `false`
    ///     for deterministic tests / manual control via ``refresh()``.
    public init(
        remote: any AddressDataSource,
        fallback: any AddressDataSource = BundledJSONDataSource(),
        cache: DatasetCache = .default,
        refreshesInBackground: Bool = true
    ) {
        self.remote = remote
        self.fallback = fallback
        self.cache = cache
        self.refreshesInBackground = refreshesInBackground
    }

    public func load() async throws -> AddressDataset {
        let chosen = try await bestAvailable()
        if refreshesInBackground {
            Task.detached(priority: .utility) { try? await self.refresh() }
        }
        return chosen
    }

    /// The version we would serve right now, without contacting the network.
    ///
    /// Uses ``AddressDataSource/version`` on the fallback (a lightweight decode) rather than
    /// calling ``bestAvailable()`` (a full dataset decode) — keeps version checks cheap.
    public var version: DatasetVersion {
        get async throws {
            let bundledVersion = try await fallback.version
            if let cachedVersion = (await cache.readAsync())?.version, cachedVersion >= bundledVersion {
                return cachedVersion
            }
            return bundledVersion
        }
    }

    /// Fetch the remote snapshot and persist it **only if strictly newer** than the cache.
    /// Returns whether the cache was updated. Remote/transport errors propagate to the caller;
    /// the background trigger in `load()` swallows them so a failed sync never breaks startup.
    @discardableResult
    public func refresh() async throws -> Bool {
        let remoteDataset = try await remote.load()
        if let cachedVersion = (await cache.readAsync())?.version, remoteDataset.version <= cachedVersion {
            return false
        }
        try cache.write(remoteDataset)
        return true
    }

    // MARK: - Selection

    /// The freshest snapshot already on the device: cache if it's at least as new as the bundle,
    /// otherwise the bundle (an app update can ship a bundle newer than a stale cached download).
    private func bestAvailable() async throws -> AddressDataset {
        let cached = await cache.readAsync()
        let bundled = try? await fallback.load()
        switch (cached, bundled) {
        case let (cached?, bundled?): return cached.version >= bundled.version ? cached : bundled
        case let (cached?, nil):      return cached
        case let (nil, bundled?):     return bundled
        case (nil, nil):              throw AddressError.notLoaded
        }
    }
}
