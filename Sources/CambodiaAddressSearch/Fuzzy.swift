/// Bounded fuzzy string distance for typo-tolerant matching.
enum Fuzzy {

    /// Optimal String Alignment distance (Levenshtein + adjacent transposition), bounded.
    ///
    /// Returns `max + 1` as a sentinel as soon as the distance is known to exceed `max`,
    /// so callers can cheaply reject non-matches. Runs in O(n·m) worst case but exits
    /// early once an entire DP row exceeds the bound.
    static func distance(_ a: [Character], _ b: [Character], max: Int) -> Int {
        let n = a.count
        let m = b.count
        if abs(n - m) > max { return max + 1 }
        if n == 0 { return m }
        if m == 0 { return n }

        var prevPrev = [Int](repeating: 0, count: m + 1) // row i-2 (for transposition)
        var prev = Array(0...m)                          // row i-1
        var curr = [Int](repeating: 0, count: m + 1)     // row i

        for i in 1...n {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(prev[j] + 1,        // deletion
                                curr[j - 1] + 1,    // insertion
                                prev[j - 1] + cost) // substitution
                // Adjacent transposition.
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, prevPrev[j - 2] + 1)
                }
                curr[j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > max { return max + 1 } // no cell in this row can lead to a match
            swap(&prevPrev, &prev)
            swap(&prev, &curr)
        }
        return prev[m]
    }

    /// Convenience over `String`.
    static func distance(_ a: String, _ b: String, max: Int) -> Int {
        distance(Array(a), Array(b), max: max)
    }
}
