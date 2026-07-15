import Testing
@testable import Mahjong

struct BoardOccupancyTests {

    @Test("A lone tile is free")
    func loneTileIsFree() {
        let a = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        #expect(BoardOccupancy.isFree(a, isSame: { $0.id == a.id }, among: [a]))
    }

    @Test("A tile fully covered on the layer above is blocked")
    func tileCoveredAboveIsBlocked() {
        let base = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        let above = Tile(suit: .pin, value: 1, row: 0, col: 0, layer: 1)
        let active = [base, above]
        #expect(!BoardOccupancy.isFree(base, isSame: { $0.id == base.id }, among: active))
    }

    @Test("A tile sandwiched on both horizontal sides is blocked")
    func tileSandwichedHorizontallyIsBlocked() {
        let left = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        let middle = Tile(suit: .man, value: 2, row: 0, col: 2, layer: 0)
        let right = Tile(suit: .man, value: 3, row: 0, col: 4, layer: 0)
        let active = [left, middle, right]
        #expect(!BoardOccupancy.isFree(middle, isSame: { $0.id == middle.id }, among: active))
        // Tiles at the ends only have one neighbor, so they remain free.
        #expect(BoardOccupancy.isFree(left, isSame: { $0.id == left.id }, among: active))
        #expect(BoardOccupancy.isFree(right, isSame: { $0.id == right.id }, among: active))
    }

    @Test("A tile blocked on only one side is still free")
    func tileBlockedOnOneSideIsFree() {
        let a = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .man, value: 2, row: 0, col: 2, layer: 0)
        let active = [a, b]
        #expect(BoardOccupancy.isFree(a, isSame: { $0.id == a.id }, among: active))
        #expect(BoardOccupancy.isFree(b, isSame: { $0.id == b.id }, among: active))
    }

    @Test("Vertical stacking does not block horizontal neighbors on the same layer")
    func differentLayersDoNotBlockHorizontally() {
        let a = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .man, value: 2, row: 0, col: 2, layer: 1)
        let active = [a, b]
        #expect(BoardOccupancy.isFree(a, isSame: { $0.id == a.id }, among: active))
    }

    @Test("TilePosition and Tile agree on free-tile results for the same layout")
    func tilePositionAndTileAgree() {
        let positions = [
            TilePosition(row: 0, col: 0, layer: 0),
            TilePosition(row: 0, col: 2, layer: 0),
            TilePosition(row: 0, col: 4, layer: 0),
            TilePosition(row: 0, col: 2, layer: 1),
        ]
        let tiles = positions.map { Tile(suit: .man, value: 1, row: $0.row, col: $0.col, layer: $0.layer) }

        for (p, t) in zip(positions, tiles) {
            let freeAsPosition = BoardOccupancy.isFree(
                p, isSame: { $0.row == p.row && $0.col == p.col && $0.layer == p.layer }, among: positions
            )
            let freeAsTile = BoardOccupancy.isFree(t, isSame: { $0.id == t.id }, among: tiles)
            #expect(freeAsPosition == freeAsTile)
        }
    }
}
