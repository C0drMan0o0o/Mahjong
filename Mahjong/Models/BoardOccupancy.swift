import Foundation

/// Anything positioned on the half-unit board grid that can block or be blocked.
/// Conformed to by both `Tile` (live gameplay) and `TilePosition` (level generation)
/// so the free-tile rule below has exactly one implementation.
protocol BoardOccupant {
    var layer: Int { get }
    var col: Int { get }
    var occupiedCols: ClosedRange<Int> { get }
    var occupiedRows: ClosedRange<Int> { get }
}

enum BoardOccupancy {
    /// A tile is free when nothing sits on the layer directly above it, and at
    /// least one horizontal side (left or right) is unobstructed by a same-layer
    /// neighbor.
    static func isFree<T: BoardOccupant>(_ tile: T, isSame: (T) -> Bool, among active: [T]) -> Bool {
        let blockedAbove = active.contains { other in
            !isSame(other) && other.layer == tile.layer + 1 &&
            other.occupiedCols.overlaps(tile.occupiedCols) &&
            other.occupiedRows.overlaps(tile.occupiedRows)
        }
        if blockedAbove { return false }

        let leftBlocked = active.contains { other in
            !isSame(other) && other.layer == tile.layer &&
            other.col + 2 == tile.col && other.occupiedRows.overlaps(tile.occupiedRows)
        }
        let rightBlocked = active.contains { other in
            !isSame(other) && other.layer == tile.layer &&
            other.col == tile.col + 2 && other.occupiedRows.overlaps(tile.occupiedRows)
        }
        return !leftBlocked || !rightBlocked
    }
}
