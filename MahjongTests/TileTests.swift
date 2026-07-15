import Testing
@testable import Mahjong

struct TileTests {

    @Test("Same suit and value match")
    func sameSuitAndValueMatch() {
        let a = Tile(suit: .man, value: 5, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .man, value: 5, row: 0, col: 4, layer: 0)
        #expect(a.matches(b))
        #expect(b.matches(a))
    }

    @Test("Same suit different value does not match")
    func sameSuitDifferentValueDoesNotMatch() {
        let a = Tile(suit: .pin, value: 3, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .pin, value: 4, row: 0, col: 4, layer: 0)
        #expect(!a.matches(b))
    }

    @Test("Different suits never match")
    func differentSuitsDoNotMatch() {
        let a = Tile(suit: .man, value: 1, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .sou, value: 1, row: 0, col: 4, layer: 0)
        #expect(!a.matches(b))
    }

    @Test("A tile never matches itself")
    func tileDoesNotMatchItself() {
        let a = Tile(suit: .dragon, value: 1, row: 0, col: 0, layer: 0)
        #expect(!a.matches(a))
    }

    @Test("Any two flowers match regardless of value")
    func anyTwoFlowersMatch() {
        let a = Tile(suit: .flower, value: 1, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .flower, value: 3, row: 0, col: 4, layer: 0)
        #expect(a.matches(b))
    }

    @Test("Any two seasons match regardless of value")
    func anyTwoSeasonsMatch() {
        let a = Tile(suit: .season, value: 2, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .season, value: 4, row: 0, col: 4, layer: 0)
        #expect(a.matches(b))
    }

    @Test("A flower never matches a season")
    func flowerDoesNotMatchSeason() {
        let a = Tile(suit: .flower, value: 1, row: 0, col: 0, layer: 0)
        let b = Tile(suit: .season, value: 1, row: 0, col: 4, layer: 0)
        #expect(!a.matches(b))
    }
}
