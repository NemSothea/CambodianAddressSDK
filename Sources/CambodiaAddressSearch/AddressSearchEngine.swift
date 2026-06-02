import CambodiaAddressCore

/// Offline search over the full address hierarchy (Province → Village).
///
/// Built once from an ``AddressDataset`` (the expensive indexing happens in `init`, off the
/// main actor at load time). Queries combine exact, prefix, and bounded-fuzzy token matches,
/// then rank: exact > prefix > fuzzy, with a small bias toward shallower levels on ties.
///
/// A value type wrapping an immutable ``SearchIndex``, so it is `Sendable` for free.
public struct AddressSearchEngine: AddressSearching {

    /// Tunable scoring/behavior.
    public struct Configuration: Sendable {
        public var exactWeight: Double
        public var prefixWeight: Double
        public var fuzzyWeight: Double
        /// Queries shorter than this skip fuzzy matching (too noisy).
        public var minFuzzyLength: Int
        /// Maximum edit distance considered a fuzzy match.
        public var maxEditDistance: Int

        public init(
            exactWeight: Double = 1.0,
            prefixWeight: Double = 0.6,
            fuzzyWeight: Double = 0.4,
            minFuzzyLength: Int = 3,
            maxEditDistance: Int = 2
        ) {
            self.exactWeight = exactWeight
            self.prefixWeight = prefixWeight
            self.fuzzyWeight = fuzzyWeight
            self.minFuzzyLength = minFuzzyLength
            self.maxEditDistance = maxEditDistance
        }

        /// Multiplier biasing results toward shallower levels on otherwise-equal scores.
        func levelWeight(_ level: AdministrativeLevel) -> Double {
            switch level {
            case .province: 1.00
            case .district: 0.97
            case .commune:  0.94
            case .village:  0.91
            }
        }
    }

    private let index: SearchIndex
    private let configuration: Configuration

    public init(dataset: AddressDataset, configuration: Configuration = .init()) {
        self.index = SearchIndex(dataset: dataset)
        self.configuration = configuration
    }

    public func search(
        _ query: String,
        levels: Set<AdministrativeLevel>,
        limit: Int
    ) async throws -> [AddressSearchResult] {
        guard limit > 0 else { return [] }
        let queryTokens = KhmerNormalizer.tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        // Accumulate per-document scores across all query tokens.
        var scores: [Int: Double] = [:]
        for token in queryTokens {
            scoreExact(token, into: &scores)
            scorePrefix(token, into: &scores)
            scoreFuzzy(token, into: &scores)
        }

        var results: [AddressSearchResult] = []
        results.reserveCapacity(scores.count)
        for (documentIndex, rawScore) in scores {
            let document = index.documents[documentIndex]
            guard levels.contains(document.level) else { continue }
            results.append(AddressSearchResult(
                id: document.id,
                level: document.level,
                name: document.name,
                path: document.path,
                score: rawScore * configuration.levelWeight(document.level)
            ))
        }

        results.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.level != rhs.level { return lhs.level < rhs.level } // shallower first
            return lhs.id < rhs.id
        }
        return Array(results.prefix(limit))
    }

    // MARK: - Scoring passes

    private func scoreExact(_ token: String, into scores: inout [Int: Double]) {
        guard let documents = index.postings[token] else { return }
        for document in documents {
            scores[document, default: 0] += configuration.exactWeight
        }
    }

    private func scorePrefix(_ token: String, into scores: inout [Int: Double]) {
        for entry in index.prefixMatches(token) where entry.token.count > token.count {
            // Closer-length prefixes score higher.
            let ratio = Double(token.count) / Double(entry.token.count)
            scores[entry.document, default: 0] += configuration.prefixWeight * ratio
        }
    }

    private func scoreFuzzy(_ token: String, into scores: inout [Int: Double]) {
        let length = token.count
        guard length >= configuration.minFuzzyLength else { return }
        let queryChars = Array(token)
        let maxDistance = configuration.maxEditDistance

        // Only candidates whose length is within the edit window can match — visit just those
        // buckets, using precomputed candidate char-arrays (no per-query allocation).
        for candidateLength in (length - maxDistance)...(length + maxDistance) where candidateLength > 0 {
            guard let indices = index.tokenIndicesByLength[candidateLength] else { continue }
            for tokenIndex in indices {
                let candidate = index.uniqueTokens[tokenIndex]
                if candidate == token || candidate.hasPrefix(token) { continue } // already scored
                let distance = Fuzzy.distance(queryChars, index.uniqueTokenChars[tokenIndex], max: maxDistance)
                guard distance <= maxDistance else { continue }
                let increment = configuration.fuzzyWeight / Double(1 + distance)
                for document in index.postings[candidate] ?? [] {
                    scores[document, default: 0] += increment
                }
            }
        }
    }
}
