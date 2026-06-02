import Testing
import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressSearch

// MARK: - Normalization

@Suite struct KhmerNormalizerTests {
    @Test func lowercasesAndTrimsLatin() {
        #expect(KhmerNormalizer.normalize("  Phnom   PENH  ") == "phnom penh")
    }

    @Test func foldsLatinDiacritics() {
        #expect(KhmerNormalizer.normalize("Krong Siĕmréab").contains("siemreab"))
    }

    @Test func stripsZeroWidthCharacters() {
        // Khmer text with an embedded zero-width space should normalize to a join.
        let withZWSP = "ភ្នំ\u{200B}ពេញ"
        #expect(KhmerNormalizer.normalize(withZWSP) == "ភ្នំពេញ")
    }

    @Test func preservesKhmerScript() {
        let khmer = "ភ្នំពេញ"
        // Khmer must survive normalization unchanged (no diacritic stripping).
        #expect(KhmerNormalizer.normalize(khmer) == khmer)
    }

    @Test func tokenizesEnglishWords() {
        #expect(KhmerNormalizer.tokens("Phnom Penh") == ["phnom", "penh"])
    }

    @Test func tokenizesOnPunctuation() {
        #expect(KhmerNormalizer.tokens("Phsar Thmei, Ti-Bei") == ["phsar", "thmei", "ti", "bei"])
    }
}

// MARK: - Fuzzy distance

@Suite struct FuzzyTests {
    @Test func zeroForIdentical() {
        #expect(Fuzzy.distance("phnom", "phnom", max: 2) == 0)
    }

    @Test func oneForSingleEdit() {
        #expect(Fuzzy.distance("phnum", "phnom", max: 2) == 1) // substitution
        #expect(Fuzzy.distance("phno", "phnom", max: 2) == 1)  // deletion
    }

    @Test func detectsTransposition() {
        #expect(Fuzzy.distance("pnhom", "phnom", max: 2) == 1) // adjacent swap
    }

    @Test func returnsSentinelBeyondBound() {
        // "abc" vs "xyz" is distance 3; with max 2 we expect the >max sentinel.
        #expect(Fuzzy.distance("abc", "xyz", max: 2) == 3)
    }

    @Test func lengthGapExceedingBoundShortCircuits() {
        #expect(Fuzzy.distance("a", "abcdef", max: 2) == 3)
    }
}

// MARK: - Engine: exact / prefix / fuzzy / khmer

@Suite struct AddressSearchEngineTests {
    let engine = SearchFixtures.engine
    let levels = SearchFixtures.allLevels

    @Test func exactEnglishMatch() async throws {
        let results = try await engine.search("Doun Penh", levels: levels, limit: 10)
        #expect(results.first?.id == "1201")
        #expect(results.first?.level == .district)
    }

    @Test func prefixMatch() async throws {
        let results = try await engine.search("doun", levels: levels, limit: 10)
        #expect(results.contains { $0.id == "1201" })
    }

    @Test func khmerQueryMatches() async throws {
        let results = try await engine.search("ដូនពេញ", levels: levels, limit: 10)
        #expect(results.first?.id == "1201")
    }

    @Test func fuzzyToleratesTypo() async throws {
        // "chamkat" -> "chamkar" (Chamkar Mon) within edit distance 1.
        let results = try await engine.search("chamkat", levels: levels, limit: 10)
        #expect(results.contains { $0.id == "1202" })
    }

    @Test func resultsCarryFullPath() async throws {
        let results = try await engine.search("Village One", levels: levels, limit: 5)
        let village = try #require(results.first { $0.id == "12010101" })
        #expect(village.path.province?.code == "12")
        #expect(village.path.district?.code == "1201")
        #expect(village.path.commune?.code == "120101")
        #expect(village.path.isComplete)
    }

    @Test func levelFilterExcludesOtherLevels() async throws {
        let results = try await engine.search("phnom", levels: [.province], limit: 10)
        #expect(results.allSatisfy { $0.level == .province })
        #expect(results.contains { $0.id == "12" })
    }

    @Test func limitIsRespected() async throws {
        let results = try await engine.search("village", levels: levels, limit: 1)
        #expect(results.count <= 1)
    }

    @Test func emptyQueryReturnsNothing() async throws {
        #expect(try await engine.search("   ", levels: levels, limit: 10).isEmpty)
        #expect(try await engine.search("doun", levels: levels, limit: 0).isEmpty)
    }

    @Test func exactOutranksFuzzy() async throws {
        // Exact "chamkar" should rank above any fuzzy-only neighbor.
        let results = try await engine.search("chamkar", levels: levels, limit: 10)
        #expect(results.first?.id == "1202")
    }
}

// MARK: - Performance (Milestone M2 budget)

@Suite struct SearchPerformanceTests {
    @Test func searchOver25kIsFast() async throws {
        let dataset = SearchFixtures.large(villages: 25_000)
        #expect(dataset.villages.count >= 25_000)

        let engine = AddressSearchEngine(dataset: dataset)
        let levels = SearchFixtures.allLevels
        let queries = ["phnom", "penh", "doun", "kandal", "basak", "ampov", "prey", "voat"]

        // Warm up (first call also exercises JIT/allocations).
        _ = try await engine.search("phnom", levels: levels, limit: 25)

        let clock = ContinuousClock()
        var worst = Duration.zero
        for query in queries {
            let elapsed = try await clock.measure {
                _ = try await engine.search(query, levels: levels, limit: 25)
            }
            worst = max(worst, elapsed)
        }

        let worstMillis = Double(worst.components.seconds) * 1000
            + Double(worst.components.attoseconds) / 1e15

        // The Milestone M2 budget (p95 < 16 ms) is a *release* target — that's what ships.
        // Debug builds run these tight loops ~5–8× slower, so there we only guard against
        // algorithmic regressions (e.g. an accidental O(n²)).
        #if DEBUG
        let budgetMillis = 120.0
        #else
        let budgetMillis = 16.0
        #endif
        #expect(worstMillis < budgetMillis, "Worst query took \(worstMillis) ms over 25k units (budget \(budgetMillis) ms)")
    }
}
