import Foundation

enum LevelGenerator {
    /// Build a guaranteed-solvable tile set for the given layout.
    /// Prefer `generateFromPositions(_:)` when calling from a non-isolated context.
    static func generate(for layout: BoardLayout) -> [Tile] {
        generateFromPositions(layout.positions)
    }

    /// Nonisolated entry point — safe to call from `Task.detached`.
    /// Caller must capture `layout.positions` on the main actor first.
    /// Guaranteed solvable: uses reverse-construction to ensure a valid
    /// winning sequence exists before returning.
    nonisolated static func generateFromPositions(_ positions: [TilePosition]) -> [Tile] {
        precondition(positions.count == 72, "Layout must have exactly 72 positions")

        let maxAttempts = 20
        for _ in 0..<maxAttempts {
            if let assignment = buildSolvableAssignment(positions: positions) {
                return zip(positions, assignment).map { pos, def in
                    Tile(suit: def.0, value: def.1,
                         row: pos.row, col: pos.col, layer: pos.layer)
                }
            }
        }

        // Should never reach here for this layout. Emit an assertion in debug
        // so the issue is caught; in release return a best-effort board.
        assertionFailure("LevelGenerator: failed solvable generation after \(maxAttempts) attempts")
        var fallback: [(TileSuit, Int)] = []
        for pair in makeDeckPairs() { fallback.append(pair); fallback.append(pair) }
        return zip(positions, fallback).map { pos, def in
            Tile(suit: def.0, value: def.1, row: pos.row, col: pos.col, layer: pos.layer)
        }
    }

    // MARK: - Core solvable assignment

    /// Simulates removing 36 pairs from the layout, then assigns tile values in
    /// the order pairs were freed. Returns nil if the simulation gets stuck.
    nonisolated private static func buildSolvableAssignment(
        positions: [TilePosition]
    ) -> [(TileSuit, Int)]? {
        var active = Set(0..<positions.count)
        var removalOrder: [(Int, Int)] = []
        removalOrder.reserveCapacity(36)

        for _ in 0..<36 {
            let free = computeFreeTiles(positions: positions, active: active)
            guard free.count >= 2 else { return nil }

            // Pick the pair whose removal leaves the most free tiles, so the
            // player always has plenty of options and is never forced into a
            // single move. Among equally-scoring pairs prefer spatially close
            // ones so matching tiles are easy to spot on screen.
            let (a, b) = bestPair(free: free, positions: positions, active: active)
            removalOrder.append((a, b))
            active.remove(a)
            active.remove(b)
        }

        let pairs = makeDeckPairs().shuffled()
        var assignment = [(TileSuit, Int)](repeating: (.man, 0), count: positions.count)
        for (step, (posA, posB)) in removalOrder.enumerated() {
            assignment[posA] = pairs[step]
            assignment[posB] = pairs[step]
        }
        return assignment
    }

    // MARK: - Pair picker

    /// From the current free tiles, returns the pair whose removal maximises the
    /// number of free tiles remaining (easiest-play heuristic). Ties are broken
    /// by spatial proximity so matching tiles tend to be near each other.
    /// Evaluates at most kMaxCandidates random pairs to keep generation fast.
    nonisolated private static func bestPair(
        free: [Int],
        positions: [TilePosition],
        active: Set<Int>
    ) -> (Int, Int) {
        let kMaxCandidates = 40

        // Build a candidate list: all pairs when free is small, a random sample otherwise.
        var candidates: [(Int, Int)] = []
        if free.count <= 10 {
            for i in 0..<free.count {
                for j in (i + 1)..<free.count {
                    candidates.append((free[i], free[j]))
                }
            }
        } else {
            let shuffled = free.shuffled()
            let take = min(shuffled.count, kMaxCandidates)
            for i in 0..<(take - 1) {
                candidates.append((shuffled[i], shuffled[i + 1]))
            }
            candidates.append((shuffled[take - 1], shuffled[0]))
        }
        candidates.shuffle()

        var bestScore = Int.min
        var bestCandidates: [(Int, Int)] = []

        for (a, b) in candidates {
            var testActive = active
            testActive.remove(a)
            testActive.remove(b)
            let newFree = computeFreeTiles(positions: positions, active: testActive).count

            // Proximity bonus (0..10): closer tiles score higher.
            let pA = positions[a], pB = positions[b]
            let dist = abs(pA.col - pB.col) + abs(pA.row - pB.row)
            let proximity = max(0, 10 - dist)

            // Primary sort: free tiles after removal; secondary: proximity.
            let score = newFree * 100 + proximity
            if score > bestScore {
                bestScore = score
                bestCandidates = [(a, b)]
            } else if score == bestScore {
                bestCandidates.append((a, b))
            }
        }

        return bestCandidates.randomElement() ?? (free[0], free[1])
    }

    // MARK: - Free tile computation (mirrors GameViewModel.isTileFree exactly)

    nonisolated private static func computeFreeTiles(
        positions: [TilePosition],
        active: Set<Int>
    ) -> [Int] {
        active.filter { i in
            let p = positions[i]

            let blockedAbove = active.contains { j in
                j != i
                && positions[j].layer == p.layer + 1
                && colsOverlap(p, positions[j])
                && rowsOverlap(p, positions[j])
            }
            guard !blockedAbove else { return false }

            let leftBlocked = active.contains { j in
                j != i
                && positions[j].layer == p.layer
                && positions[j].col + 2 == p.col
                && rowsOverlap(p, positions[j])
            }
            let rightBlocked = active.contains { j in
                j != i
                && positions[j].layer == p.layer
                && positions[j].col == p.col + 2
                && rowsOverlap(p, positions[j])
            }
            return !leftBlocked || !rightBlocked
        }
    }

    nonisolated private static func colsOverlap(_ a: TilePosition, _ b: TilePosition) -> Bool {
        (a.col...a.col + 1).overlaps(b.col...b.col + 1)
    }

    nonisolated private static func rowsOverlap(_ a: TilePosition, _ b: TilePosition) -> Bool {
        (a.row...a.row + 1).overlaps(b.row...b.row + 1)
    }

    // MARK: - Deck building

    /// Returns 36 unique pair identifiers — one entry per pair.
    /// Each entry will be assigned to exactly two board positions.
    /// Flowers and seasons match any tile of the same suit; all others require exact suit+value.
    nonisolated private static func makeDeckPairs() -> [(TileSuit, Int)] {
        var pairs: [(TileSuit, Int)] = []

        // Man, Pin, Sou: 1-9 each = 27 pairs
        for suit in [TileSuit.man, .pin, .sou] {
            for v in 1...9 { pairs.append((suit, v)) }
        }
        // Winds 1-4: 4 pairs
        for v in 1...4 { pairs.append((.wind, v)) }
        // Dragons 1-3: 3 pairs
        for v in 1...3 { pairs.append((.dragon, v)) }
        // Flowers: 1 pair (any flower matches any flower)
        pairs.append((.flower, 1))
        // Seasons: 1 pair (any season matches any season)
        pairs.append((.season, 1))

        // Total: 27 + 4 + 3 + 1 + 1 = 36
        precondition(pairs.count == 36)
        return pairs
    }

    // MARK: - Shuffle repair (used by GameViewModel after a shuffle)

    /// Re-pair an already-active set of (suit, value) pairs to guarantee at least one match.
    static func repairPairs(_ values: [(suit: TileSuit, value: Int)]) -> [(suit: TileSuit, value: Int)] {
        var groups: [[(suit: TileSuit, value: Int)]] = []
        var singletons: [(suit: TileSuit, value: Int)] = []
        var used = [Bool](repeating: false, count: values.count)

        for i in 0..<values.count {
            guard !used[i] else { continue }
            var group = [values[i]]
            used[i] = true
            for j in (i + 1)..<values.count {
                guard !used[j] else { continue }
                let a = values[i], b = values[j]
                let matches = (a.suit == .flower && b.suit == .flower) ||
                              (a.suit == .season && b.suit == .season) ||
                              (a.suit == b.suit && a.value == b.value)
                if matches {
                    group.append(values[j])
                    used[j] = true
                }
            }
            if group.count >= 2 {
                groups.append(group)
            } else {
                singletons.append(contentsOf: group)
            }
        }

        var shuffledGroups = groups.map { $0.shuffled() }
        shuffledGroups.shuffle()
        var result: [(suit: TileSuit, value: Int)] = []
        var anyLeft = true
        while anyLeft {
            anyLeft = false
            for i in shuffledGroups.indices where !shuffledGroups[i].isEmpty {
                result.append(shuffledGroups[i].removeFirst())
                anyLeft = true
            }
        }
        result.append(contentsOf: singletons.shuffled())
        return result
    }
}
