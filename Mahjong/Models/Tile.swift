import Foundation

struct Tile: Identifiable, Codable, Equatable, Sendable, BoardOccupant {
    let id: UUID
    var suit: TileSuit
    var value: Int
    var row: Int
    var col: Int
    var layer: Int
    var isRemoved: Bool = false
    var isSelected: Bool = false

    nonisolated init(id: UUID = UUID(), suit: TileSuit, value: Int, row: Int, col: Int, layer: Int) {
        self.id = id
        self.suit = suit
        self.value = value
        self.row = row
        self.col = col
        self.layer = layer
    }

    func matches(_ other: Tile) -> Bool {
        guard id != other.id else { return false }
        if suit == .flower && other.suit == .flower { return true }
        if suit == .season && other.suit == .season { return true }
        return suit == other.suit && value == other.value
    }

    // Each tile occupies a 2×2 block in half-unit grid coordinates.
    // col/row here are in half-units so two adjacent tiles share no space.
    var occupiedCols: ClosedRange<Int> { col...(col + 1) }
    var occupiedRows: ClosedRange<Int> { row...(row + 1) }

    func overlapsHorizontally(_ other: Tile) -> Bool {
        occupiedCols.overlaps(other.occupiedCols) && occupiedRows.overlaps(other.occupiedRows)
    }
}

