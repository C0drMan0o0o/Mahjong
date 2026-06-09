import Foundation

enum LevelGenerator {
    /// Build a shuffled, solvable tile set for the given layout.
    /// Prefer `generateFromPositions(_:)` when calling from a non-isolated context.
    static func generate(for layout: BoardLayout) -> [Tile] {
        generateFromPositions(layout.positions)
    }

    /// Nonisolated entry point — safe to call from `Task.detached`.
    /// Caller must capture `layout.positions` on the main actor first.
    nonisolated static func generateFromPositions(_ positions: [TilePosition]) -> [Tile] {
        precondition(positions.count == 144, "Layout must have exactly 144 positions")

        let deck = makeDeck()
        precondition(deck.count == 144)

        // 1. Fully random shuffle of the deck.
        let shuffledDeck = pairShuffle(deck)

        // 2. Map shuffled deck onto positions.
        var tiles = zip(positions, shuffledDeck).map { pos, def in
            Tile(suit: def.0, value: def.1,
                 row: pos.row, col: pos.col, layer: pos.layer)
        }

        // 3. Spread pass: run 3 times to push matching pairs apart.
        for _ in 0..<3 {
            tiles = spreadPass(tiles)
        }

        return tiles
    }

    // MARK: - Spread shuffle helpers

    nonisolated private static func tilesMatch(_ a: Tile, _ b: Tile) -> Bool {
        if a.suit == .flower && b.suit == .flower { return true }
        if a.suit == .season && b.suit == .season { return true }
        return a.suit == b.suit && a.value == b.value
    }

    nonisolated private static func areSpatiallyClose(_ a: Tile, _ b: Tile) -> Bool {
        let sameLayer = a.layer == b.layer
        let colDist = abs(a.col - b.col)
        let rowDist = abs(a.row - b.row)
        return sameLayer && (colDist + rowDist) < 6
    }

    /// One pass over all tiles: for each matching pair that is spatially close,
    /// try to swap one tile with a farther-away non-close tile.
    nonisolated private static func spreadPass(_ input: [Tile]) -> [Tile] {
        var tiles = input

        for i in 0..<tiles.count {
            while true {
                // Find j: the matching partner of i that is spatially close.
                guard let j = (0..<tiles.count).first(where: { k in
                    k != i && tilesMatch(tiles[i], tiles[k]) && areSpatiallyClose(tiles[i], tiles[k])
                }) else { break }

                // Try up to 10 random candidates for the swap target k.
                var indices = Array(0..<tiles.count)
                indices.shuffle()
                var bestK: Int? = nil
                var bestDist = -1
                var checkedCount = 0

                for k in indices where k != i && k != j {
                    // After swap, tiles[i] gets tiles[k]'s suit/value, tiles[k] gets tiles[i]'s.
                    // Check: would the new tiles[i] (now with k's suit/value) still be close to j?
                    let kSuit = tiles[k].suit
                    let kValue = tiles[k].value
                    let fakeTileAtI = Tile(suit: kSuit, value: kValue,
                                          row: tiles[i].row, col: tiles[i].col, layer: tiles[i].layer)
                    // We want fakeTileAtI to NOT match tiles[j], or if it does match, not be close.
                    let wouldBeClose = tilesMatch(fakeTileAtI, tiles[j]) && areSpatiallyClose(fakeTileAtI, tiles[j])
                    if wouldBeClose { continue }

                    // Track the best k by distance from j (maximise Manhattan distance).
                    let dist = abs(tiles[k].col - tiles[j].col) + abs(tiles[k].row - tiles[j].row)
                    if dist > bestDist {
                        bestDist = dist
                        bestK = k
                    }

                    // Accept best candidate found after checking 10 valid options.
                    checkedCount += 1
                    if bestK != nil && checkedCount >= 10 { break }
                }

                guard let k = bestK else { break }

                // Swap the suit/value of tiles[i] and tiles[k], keeping positions fixed.
                let (iSuit, iValue) = (tiles[i].suit, tiles[i].value)
                let (kSuit, kValue) = (tiles[k].suit, tiles[k].value)
                tiles[i] = Tile(suit: kSuit, value: kValue,
                                row: tiles[i].row, col: tiles[i].col, layer: tiles[i].layer)
                tiles[k] = Tile(suit: iSuit, value: iValue,
                                row: tiles[k].row, col: tiles[k].col, layer: tiles[k].layer)
            }
        }

        return tiles
    }

    // MARK: - Deck building

    nonisolated private static func makeDeck() -> [(suit: TileSuit, value: Int)] {
        var deck: [(TileSuit, Int)] = []

        // Man, Pin, Sou: 4 copies of 1-9
        for suit in [TileSuit.man, .pin, .sou] {
            for v in 1...9 {
                for _ in 0..<4 { deck.append((suit, v)) }
            }
        }
        // Winds 1-4: 4 copies each
        for v in 1...4 {
            for _ in 0..<4 { deck.append((.wind, v)) }
        }
        // Dragons 1-3: 4 copies each
        for v in 1...3 {
            for _ in 0..<4 { deck.append((.dragon, v)) }
        }
        // Flowers 1-4: 1 copy each
        for v in 1...4 { deck.append((.flower, v)) }
        // Seasons 1-4: 1 copy each
        for v in 1...4 { deck.append((.season, v)) }

        precondition(deck.count == 144)
        return deck
    }

    /// Shuffle while keeping pairs together so board is always solvable at start.
    nonisolated private static func pairShuffle(_ deck: [(TileSuit, Int)]) -> [(TileSuit, Int)] {
        // Group identical (or group-matching) tiles
        var groups: [[(TileSuit, Int)]] = []

        // Flowers all match each other — treat as one group of 4
        let flowers = deck.filter { $0.0 == .flower }
        if !flowers.isEmpty { groups.append(flowers) }

        let seasons = deck.filter { $0.0 == .season }
        if !seasons.isEmpty { groups.append(seasons) }

        // All other tiles: group by (suit, value)
        let remaining = deck.filter { $0.0 != .flower && $0.0 != .season }
        struct TileKey: Hashable {
            let suit: TileSuit
            let value: Int
        }
        var seen = Set<TileKey>()
        for tile in remaining {
            let key = TileKey(suit: tile.0, value: tile.1)
            if !seen.contains(key) {
                seen.insert(key)
                groups.append(remaining.filter { $0.0 == tile.0 && $0.1 == tile.1 })
            }
        }

        // Shuffle groups, then emit pairs (take 2 from each group, shuffle pair order)
        groups.shuffle()

        var result: [(TileSuit, Int)] = []
        for group in groups {
            var g = group.shuffled()
            // Emit in pairs
            while g.count >= 2 {
                result.append(g.removeFirst())
                result.append(g.removeFirst())
            }
            result.append(contentsOf: g)
        }

        return result
    }

    /// Re-pair an already-active set of (suit, value) pairs to guarantee at least one match.
    /// Builds a fresh output array so singletons (flowers/seasons with no partner remaining)
    /// are preserved and never overwritten by another group.
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

        var result: [(suit: TileSuit, value: Int)] = []
        for group in groups.shuffled() {
            result.append(contentsOf: group.shuffled())
        }
        result.append(contentsOf: singletons.shuffled())
        return result
    }
}
