import SwiftUI

enum TileSuit: String, CaseIterable, Codable, Hashable, Sendable {
    case man, pin, sou, wind, dragon, flower, season
}

struct TileDefinition {
    let suit: TileSuit
    let value: Int
    let displaySymbol: String
    let displayColor: Color
    let groupLabel: String

    static let all: [TileDefinition] = buildAll()

    /// Precomputed O(1) lookup: [suit: [value: definition]]
    static let lookup: [TileSuit: [Int: TileDefinition]] = {
        var map: [TileSuit: [Int: TileDefinition]] = [:]
        for def in all {
            map[def.suit, default: [:]][def.value] = def
        }
        return map
    }()

    private static func buildAll() -> [TileDefinition] {
        var defs: [TileDefinition] = []

        // Characters (Man) 1-9, 4 copies each
        for v in 1...9 {
            defs.append(TileDefinition(suit: .man, value: v,
                displaySymbol: "\(v)萬",
                displayColor: Color(hex: "#DC143C"),
                groupLabel: "Characters"))
        }

        // Circles (Pin) 1-9
        for v in 1...9 {
            defs.append(TileDefinition(suit: .pin, value: v,
                displaySymbol: circleSymbol(v),
                displayColor: Color(hex: "#1A5276"),
                groupLabel: "Circles"))
        }

        // Bamboo (Sou) 1-9
        for v in 1...9 {
            defs.append(TileDefinition(suit: .sou, value: v,
                displaySymbol: bambooSymbol(v),
                displayColor: Color(hex: "#1B5E20"),
                groupLabel: "Bamboo"))
        }

        // Winds 1-4 (East/South/West/North)
        let windSymbols = ["東", "南", "西", "北"]
        let windLabels  = ["East", "South", "West", "North"]
        for v in 1...4 {
            defs.append(TileDefinition(suit: .wind, value: v,
                displaySymbol: windSymbols[v - 1],
                displayColor: Color(hex: "#2C3E50"),
                groupLabel: windLabels[v - 1]))
        }

        // Dragons 1-3 (Red/Green/White)
        let dragonInfo: [(String, Color, String)] = [
            ("中", Color(hex: "#DC143C"), "Red"),
            ("發", Color(hex: "#1B5E20"), "Green"),
            ("白", Color(hex: "#95A5A6"), "White")
        ]
        for v in 1...3 {
            let info = dragonInfo[v - 1]
            defs.append(TileDefinition(suit: .dragon, value: v,
                displaySymbol: info.0,
                displayColor: info.1,
                groupLabel: info.2))
        }

        // Flowers 1-4 (unique, match any flower)
        let flowerSymbols = ["🌸", "🌺", "🌻", "🌹"]
        for v in 1...4 {
            defs.append(TileDefinition(suit: .flower, value: v,
                displaySymbol: flowerSymbols[v - 1],
                displayColor: Color(hex: "#8B008B"),
                groupLabel: "Flowers"))
        }

        // Seasons 1-4 (unique, match any season)
        let seasonSymbols = ["🌱", "☀️", "🍂", "❄️"]
        for v in 1...4 {
            defs.append(TileDefinition(suit: .season, value: v,
                displaySymbol: seasonSymbols[v - 1],
                displayColor: Color(hex: "#8B008B"),
                groupLabel: "Seasons"))
        }

        return defs
    }

    private static func circleSymbol(_ v: Int) -> String {
        let symbols = ["①","②","③","④","⑤","⑥","⑦","⑧","⑨"]
        return symbols[v - 1]
    }

    private static func bambooSymbol(_ v: Int) -> String {
        let symbols = ["1🎋","2🎋","3🎋","4🎋","5🎋","6🎋","7🎋","8🎋","9🎋"]
        return symbols[v - 1]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
