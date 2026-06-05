import CambodiaAddressCore

/// Immutable, value-typed search index built once from an ``AddressDataset``.
///
/// Holds three structures, all `Sendable` value types (no reference juggling under Swift 6):
/// 1. `documents` — one entry per administrative unit, with its full breadcrumb path.
/// 2. `postings` — inverted index: normalized token → document indices (exact match).
/// 3. `sortedTokens` — `(token, document)` pairs sorted by token, for binary-search prefix
///    queries in O(log n + k).
///
/// > Note: We use a sorted-array prefix index rather than a node-based trie. It has the same
/// > O(p + k) prefix-query complexity, better cache locality, and is a plain value type — so
/// > the enclosing engine is trivially `Sendable`.
struct SearchIndex: Sendable {

    struct Document: Sendable {
        let id: String
        let level: AdministrativeLevel
        let name: LocalizedName
        let path: AddressSelection
    }

    struct TokenEntry: Sendable {
        let token: String
        let document: Int
    }

    let documents: [Document]
    let postings: [String: [Int]]
    let sortedTokens: [TokenEntry]
    /// Distinct tokens, used as the candidate pool for fuzzy matching.
    let uniqueTokens: [String]
    /// Character arrays parallel to `uniqueTokens`, precomputed so fuzzy matching never
    /// re-allocates per query.
    let uniqueTokenChars: [[Character]]
    /// Indices into `uniqueTokens` grouped by character count, so fuzzy matching only visits
    /// candidates within the edit-distance length window instead of scanning everything.
    let tokenIndicesByLength: [Int: [Int]]

    init(dataset: AddressDataset) {
        // Parent lookups so each document can carry a full province→unit path.
        let provincesByCode = Dictionary(dataset.provinces.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        let districtsByCode = Dictionary(dataset.districts.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        let communesByCode = Dictionary(dataset.communes.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })

        var documents: [Document] = []
        documents.reserveCapacity(dataset.count)

        for province in dataset.provinces {
            documents.append(Document(
                id: province.code, level: .province, name: province.name,
                path: AddressSelection(province: province)
            ))
        }
        for district in dataset.districts {
            // Skip districts whose province is missing — the path would be unresolvable.
            guard let province = provincesByCode[district.provinceCode] else { continue }
            documents.append(Document(
                id: district.code, level: .district, name: district.name,
                path: AddressSelection(province: province, district: district)
            ))
        }
        for commune in dataset.communes {
            guard let district = districtsByCode[commune.districtCode],
                  let province = provincesByCode[district.provinceCode] else { continue }
            documents.append(Document(
                id: commune.code, level: .commune, name: commune.name,
                path: AddressSelection(province: province, district: district, commune: commune)
            ))
        }
        for village in dataset.villages {
            // Mirror AddressStore.selection: only index villages with an intact parent chain.
            // A broken-chain village would appear in search results but throw when the UI
            // calls selection(forVillageCode:) to resolve it — producing an unresolvable result.
            guard let commune = communesByCode[village.communeCode],
                  let district = districtsByCode[commune.districtCode],
                  let province = provincesByCode[district.provinceCode] else { continue }
            documents.append(Document(
                id: village.code, level: .village, name: village.name,
                path: AddressSelection(province: province, district: district, commune: commune, village: village)
            ))
        }
        self.documents = documents

        // Build inverted index + token entries from both Khmer and English names.
        var postings: [String: [Int]] = [:]
        var entries: [TokenEntry] = []
        for (index, document) in documents.enumerated() {
            let tokens = Set(KhmerNormalizer.tokens(document.name.km) + KhmerNormalizer.tokens(document.name.en))
            for token in tokens {
                postings[token, default: []].append(index)
                entries.append(TokenEntry(token: token, document: index))
            }
        }
        self.postings = postings
        self.sortedTokens = entries.sorted { $0.token < $1.token }

        let uniqueTokens = Array(postings.keys)
        self.uniqueTokens = uniqueTokens
        self.uniqueTokenChars = uniqueTokens.map(Array.init)
        self.tokenIndicesByLength = Dictionary(grouping: uniqueTokens.indices, by: { uniqueTokens[$0].count })
    }

    /// Token entries whose token begins with `prefix`, found by binary search.
    func prefixMatches(_ prefix: String) -> ArraySlice<TokenEntry> {
        guard !prefix.isEmpty else { return [] }
        let start = lowerBound(prefix)
        var end = start
        while end < sortedTokens.count, sortedTokens[end].token.hasPrefix(prefix) {
            end += 1
        }
        return sortedTokens[start..<end]
    }

    /// First index in `sortedTokens` whose token is >= `key`.
    private func lowerBound(_ key: String) -> Int {
        var low = 0
        var high = sortedTokens.count
        while low < high {
            let mid = (low + high) / 2
            if sortedTokens[mid].token < key {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
