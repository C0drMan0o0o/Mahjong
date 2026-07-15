import Testing
@testable import Mahjong

struct LevelGeneratorTests {

    @Test("Generated board has 72 tiles forming exactly 36 matching pairs")
    func generatesCorrectTileCount() {
        let tiles = LevelGenerator.generateFromPositions(BoardLayout.classic.positions)
        #expect(tiles.count == 72)

        var remaining = tiles
        var pairCount = 0
        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            guard let matchIndex = remaining.firstIndex(where: { first.matches($0) }) else {
                Issue.record("Tile \(first.suit) \(first.value) has no partner in the deck")
                break
            }
            remaining.remove(at: matchIndex)
            pairCount += 1
        }
        #expect(pairCount == 36)
    }

    @Test("Generated board is always fully solvable by repeatedly matching free tiles")
    func generatedBoardIsSolvable() {
        for _ in 0..<10 {
            let tiles = LevelGenerator.generateFromPositions(BoardLayout.classic.positions)
            #expect(Self.solve(tiles), "Board should be fully clearable via free-tile matches alone")
        }
    }

    /// Repeatedly removes any pair of free, matching tiles using the same
    /// BoardOccupancy rule the live game uses. Returns true only if every
    /// tile is eventually removed, matching LevelGenerator's solvability guarantee.
    private static func solve(_ tiles: [Tile]) -> Bool {
        var active = tiles

        while !active.isEmpty {
            let free = active.filter { tile in
                BoardOccupancy.isFree(tile, isSame: { $0.id == tile.id }, among: active)
            }

            var madeMove = false
            outer: for i in 0..<free.count {
                for j in (i + 1)..<free.count {
                    if free[i].matches(free[j]) {
                        active.removeAll { $0.id == free[i].id || $0.id == free[j].id }
                        madeMove = true
                        break outer
                    }
                }
            }

            guard madeMove else { return false }
        }
        return true
    }
}
