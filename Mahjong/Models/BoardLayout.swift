import Foundation

struct TilePosition: Codable, BoardOccupant {
    let row: Int
    let col: Int
    let layer: Int

    var occupiedCols: ClosedRange<Int> { col...(col + 1) }
    var occupiedRows: ClosedRange<Int> { row...(row + 1) }
}

// Single classic turtle layout used for all levels.
// Levels differ only in tile shuffle/seed.
struct BoardLayout: Codable {
    let positions: [TilePosition]

    static let classic: BoardLayout = buildClassic()

    // MARK: - Compact layout (72 tiles, 4 layers)
    // Wide landscape shape: 7 columns across at base, 4 rows tall.
    // 72 tiles = 36 pairs — half the classic 144-tile set.
    //
    // Layer 0: 7 cols × 4 rows = 28  (cols 0,2,...,12  rows 0,2,4,6)
    // Layer 1: 5 cols × 4 rows = 20  (cols 1,3,5,7,9   rows 1,3,5,7)
    // Layer 2: 4 cols × 4 rows = 16  (cols 2,4,6,8     rows 2,4,6,8)
    // Layer 3: 4 cols × 2 rows =  8  (cols 3,5,7,9     rows 3,5)
    // Total: 28+20+16+8 = 72
    private static func buildClassic() -> BoardLayout {
        var pos: [TilePosition] = []

        // Layer 0 — 7 wide × 4 tall = 28 tiles
        for ri in 0..<4 {
            for ci in 0..<7 {
                pos.append(TilePosition(row: ri * 2, col: ci * 2, layer: 0))
            }
        }

        // Layer 1 — 5 wide × 4 tall = 20 tiles
        for ri in 0..<4 {
            for ci in 0..<5 {
                pos.append(TilePosition(row: 1 + ri * 2, col: 1 + ci * 2, layer: 1))
            }
        }

        // Layer 2 — 4 wide × 4 tall = 16 tiles
        for ri in 0..<4 {
            for ci in 0..<4 {
                pos.append(TilePosition(row: 2 + ri * 2, col: 2 + ci * 2, layer: 2))
            }
        }

        // Layer 3 — 4 wide × 2 tall = 8 tiles
        for ri in 0..<2 {
            for ci in 0..<4 {
                pos.append(TilePosition(row: 3 + ri * 2, col: 3 + ci * 2, layer: 3))
            }
        }

        precondition(pos.count == 72, "Layout must have exactly 72 positions, got \(pos.count)")
        return BoardLayout(positions: pos)
    }
}
