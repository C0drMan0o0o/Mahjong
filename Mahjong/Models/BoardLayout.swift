import Foundation

struct TilePosition: Codable {
    let row: Int
    let col: Int
    let layer: Int
}

// Single classic turtle layout used for all levels.
// Levels differ only in tile shuffle/seed.
struct BoardLayout: Codable {
    let positions: [TilePosition]

    static let classic: BoardLayout = buildClassic()

    // MARK: - Classic pyramid layout (144 tiles, 7 layers)
    // Diamond/pyramid shape: widest at base, narrowing toward the top.
    // Each tile occupies a 2×2 block in grid coordinates.
    // Layer N tiles are offset by N from the even-grid base so they sit
    // visually between and on top of the tiles below.
    //
    // Layer 0: 6 cols × 9 rows = 54  (cols 0,2,4,6,8,10  rows 0,2,...,16)
    // Layer 1: 5 cols × 8 rows = 40  (cols 1,3,5,7,9     rows 1,3,...,15)
    // Layer 2: 4 cols × 6 rows = 24  (cols 2,4,6,8        rows 2,4,...,12)
    // Layer 3: 3 cols × 4 rows = 12  (cols 3,5,7          rows 3,5,7,9)
    // Layer 4: 2 cols × 4 rows =  8  (cols 4,6            rows 4,6,8,10)
    // Layer 5: 2 cols × 2 rows =  4  (cols 4,6            rows 5,7)
    // Layer 6: 1 col  × 2 rows =  2  (col  5              rows 6,8)
    // Total: 54+40+24+12+8+4+2 = 144
    private static func buildClassic() -> BoardLayout {
        var pos: [TilePosition] = []

        // Layer 0 — 6 wide × 9 tall = 54 tiles
        for ri in 0..<9 {
            for ci in 0..<6 {
                pos.append(TilePosition(row: ri * 2, col: ci * 2, layer: 0))
            }
        }

        // Layer 1 — 5 wide × 8 tall = 40 tiles
        for ri in 0..<8 {
            for ci in 0..<5 {
                pos.append(TilePosition(row: 1 + ri * 2, col: 1 + ci * 2, layer: 1))
            }
        }

        // Layer 2 — 4 wide × 6 tall = 24 tiles
        for ri in 0..<6 {
            for ci in 0..<4 {
                pos.append(TilePosition(row: 2 + ri * 2, col: 2 + ci * 2, layer: 2))
            }
        }

        // Layer 3 — 3 wide × 4 tall = 12 tiles
        for ri in 0..<4 {
            for ci in 0..<3 {
                pos.append(TilePosition(row: 3 + ri * 2, col: 3 + ci * 2, layer: 3))
            }
        }

        // Layer 4 — 2 wide × 4 tall = 8 tiles
        for ri in 0..<4 {
            for ci in 0..<2 {
                pos.append(TilePosition(row: 4 + ri * 2, col: 4 + ci * 2, layer: 4))
            }
        }

        // Layer 5 — 2 wide × 2 tall = 4 tiles
        for ri in 0..<2 {
            for ci in 0..<2 {
                pos.append(TilePosition(row: 5 + ri * 2, col: 4 + ci * 2, layer: 5))
            }
        }

        // Layer 6 — 1 wide × 2 tall = 2 tiles
        for ri in 0..<2 {
            pos.append(TilePosition(row: 6 + ri * 2, col: 5, layer: 6))
        }

        precondition(pos.count == 144, "Classic layout must have exactly 144 positions, got \(pos.count)")
        return BoardLayout(positions: pos)
    }
}
