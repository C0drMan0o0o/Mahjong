import SwiftUI

struct GameBoardView: View {
    @ObservedObject var vm: GameViewModel

    // Tile aspect ratio (height / width)
    private let tileAspect: CGFloat = 68.0 / 52.0
    private let depthRatio: CGFloat = 0.08  // depth as fraction of tile width
    private let layerShift: CGFloat = 2     // px per layer for 3D illusion
    private let zoomFactor: CGFloat = 1.25  // scale tiles up beyond pure fit

    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(in: geo.size)
            ZStack {
                ForEach(sortedActiveTiles) { tile in
                    let isFree = vm.isTileFree(tile)
                    let hintRole: HintRole? = {
                        guard let h = vm.currentHint else { return nil }
                        if tile.id == h.blockerTileID { return .blocker }
                        if tile.id == h.matchTileA    { return .matchA }
                        if tile.id == h.matchTileB    { return .matchB }
                        return nil
                    }()
                    TileView(tile: tile,
                             tileW: layout.tileW,
                             tileH: layout.tileH,
                             depth: layout.depth,
                             isFree: isFree,
                             hintRole: hintRole,
                             onTap: { vm.selectTile(tile) })
                        .position(position(for: tile, layout: layout))
                        .zIndex(Double(tile.layer * 100_000 + tile.row * 1000 + tile.col))
                }
            }
            // Board canvas sized to exactly fill available space
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Layout computation

    struct TileLayout {
        let unitW: CGFloat
        let unitH: CGFloat
        let tileW: CGFloat
        let tileH: CGFloat
        let depth: CGFloat
        let minCol: Int
        let minRow: Int
        let xOffset: CGFloat
        let yOffset: CGFloat
    }

    private func computeLayout(in size: CGSize) -> TileLayout {
        guard let bounds = vm.boardBounds else {
            let u: CGFloat = 20
            return TileLayout(unitW: u, unitH: u * tileAspect,
                               tileW: u * 2 - 2, tileH: u * 2 * tileAspect - 2,
                               depth: u * depthRatio * 2,
                               minCol: 0, minRow: 0,
                               xOffset: 0, yOffset: 0)
        }

        let minCol = bounds.minCol
        let minRow = bounds.minRow
        let maxCol = bounds.maxCol
        let maxRow = bounds.maxRow

        // Span in grid units (each tile = 2 units wide/tall, +3 margin each side)
        let colSpan = CGFloat(maxCol - minCol + 6)
        let rowSpan = CGFloat(maxRow - minRow + 6)

        // Fit to available size while keeping tile aspect ratio
        let unitByWidth  = size.width  / colSpan
        let unitByHeight = (size.height / rowSpan) / tileAspect
        let unitW = min(unitByWidth, unitByHeight) * zoomFactor
        let unitH = unitW * tileAspect

        let tileW = unitW * 2 - 1
        let tileH = unitH * 2 - 1
        let depth = max(2, tileW * depthRatio)

        // Center the actual tile content. A tile's frame is (tileW + depth) and
        // sits centered on its position point; the content spans from the leftmost
        // tile's left edge to the rightmost tile's right edge.
        let contentW = CGFloat(maxCol - minCol + 2) * unitW - 1 + depth
        let contentH = CGFloat(maxRow - minRow + 2) * unitH - 1 + depth
        let xOffset = (size.width  - contentW) / 2 - unitW
        let yOffset = (size.height - contentH) / 2 - unitH

        return TileLayout(unitW: unitW, unitH: unitH,
                          tileW: tileW, tileH: tileH, depth: depth,
                          minCol: minCol, minRow: minRow,
                          xOffset: xOffset, yOffset: yOffset)
    }

    private func position(for tile: Tile, layout: TileLayout) -> CGPoint {
        let x = CGFloat(tile.col - layout.minCol + 1) * layout.unitW
              + (layout.tileW + layout.depth) / 2
              - CGFloat(tile.layer) * layerShift
              + layout.xOffset
        let y = CGFloat(tile.row - layout.minRow + 1) * layout.unitH
              + (layout.tileH + layout.depth) / 2
              - CGFloat(tile.layer) * layerShift
              + layout.yOffset
        return CGPoint(x: x, y: y)
    }

    private var sortedActiveTiles: [Tile] {
        vm.tiles
            .filter { !$0.isRemoved }
            .sorted {
                if $0.layer != $1.layer { return $0.layer < $1.layer }
                if $0.row != $1.row { return $0.row < $1.row }
                return $0.col < $1.col
            }
    }
}
