import Foundation

struct GameState: Codable {
    var tiles: [Tile]
    var score: Int
    var moves: Int
    var elapsedSeconds: Int
    var hintsRemaining: Int
    var layoutID: String   // kept for Codable compatibility; unused at runtime

    var isVictory: Bool {
        tiles.allSatisfy { $0.isRemoved }
    }

    func isTileFree(_ tile: Tile) -> Bool {
        guard !tile.isRemoved else { return false }
        let active = tiles.filter { !$0.isRemoved }

        let blockedAbove = active.contains {
            $0.id != tile.id && $0.layer == tile.layer + 1 && $0.overlapsHorizontally(tile)
        }
        if blockedAbove { return false }

        let leftBlocked = active.contains {
            $0.id != tile.id && $0.layer == tile.layer &&
            $0.col + 2 == tile.col && $0.occupiedRows.overlaps(tile.occupiedRows)
        }
        let rightBlocked = active.contains {
            $0.id != tile.id && $0.layer == tile.layer &&
            $0.col == tile.col + 2 && $0.occupiedRows.overlaps(tile.occupiedRows)
        }
        return !leftBlocked || !rightBlocked
    }

    var isDeadlocked: Bool {
        let active = tiles.filter { !$0.isRemoved }
        guard !active.isEmpty else { return false }
        
        let freeTiles = active.filter { isTileFree($0) }
        for i in 0..<freeTiles.count {
            for j in (i + 1)..<freeTiles.count {
                if freeTiles[i].matches(freeTiles[j]) {
                    return false
                }
            }
        }
        return true
    }

    var isGameOver: Bool {
        isDeadlocked && !isVictory
    }
}

struct BestRecord: Codable {
    var bestScore: Int
    var bestTime: Int?
}
