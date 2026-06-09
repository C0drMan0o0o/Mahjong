import SwiftUI

// MARK: - TileShelfView

/// The bottom shelf panel showing up to 4 collected tiles awaiting a match.
/// Observes `ShelfViewModel` for slot state and flash-match animations.
struct TileShelfView: View {

    @ObservedObject var shelfVM: ShelfViewModel

    /// True when the shelf is full AND contains no matching pair — signals the player is stuck.
    private var isBlocked: Bool {
        shelfVM.slots.allSatisfy { $0 != nil } && shelfVM.matchingTileIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            headerLabel
            slotsRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(shelfBackground)
        .overlay(shelfBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Header

    private var headerLabel: some View {
        HStack(spacing: 6) {
            Text("SHELF")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.7))

            Text("\(shelfVM.slots.compactMap { $0 }.count)/4")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Slots row

    private var slotsRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                let tile     = shelfVM.slots[index]
                let matching = tile.map { shelfVM.matchingTileIDs.contains($0.id) } ?? false

                SlotView(tile: tile, isMatching: matching)
            }
        }
    }

    // MARK: Background / border

    private var shelfBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                Color(hex: "#1A1A2E").opacity(isBlocked ? 0.95 : 0.9)
                    .shadow(.inner(color: .black.opacity(0.4), radius: 4, x: 0, y: 2))
            )
            .overlay(
                // Subtle red tint when blocked
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(isBlocked ? 0.10 : 0))
                    .animation(.easeInOut(duration: 0.4), value: isBlocked)
            )
    }

    private var shelfBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                Color.white.opacity(isBlocked ? 0.20 : 0.08),
                lineWidth: 1
            )
            .animation(.easeInOut(duration: 0.4), value: isBlocked)
    }
}

// MARK: - SlotView

/// A single slot in the shelf — either empty (dashed) or occupied by a `TileChipView`.
private struct SlotView: View {

    let tile: Tile?
    let isMatching: Bool

    var body: some View {
        ZStack {
            if let tile {
                TileChipView(tile: tile, isMatching: isMatching)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.6)
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.01)
                                .combined(with: .opacity)
                        )
                    )
            } else {
                emptySlot
            }
        }
        .frame(width: 62, height: 80)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.65),
            value: tile?.id
        )
    }

    // MARK: Empty state

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            )
    }
}

// MARK: - TileChipView

/// The visual tile chip placed inside a slot.  Shows a 3-D slab effect, symbol, and group label.
/// Pulses with a gold glow when `isMatching` is true.
private struct TileChipView: View {

    let tile: Tile
    let isMatching: Bool

    /// Drive the pulse animation locally.
    @State private var glowPulse = false

    private var definition: TileDefinition? {
        TileDefinition.lookup[tile.suit]?[tile.value]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 3-D depth slab (offset copy behind the face)
            slabShadow

            // Tile face
            tileFace
        }
        // Gold glow when matched
        .shadow(
            color: isMatching
                ? Color(hex: "#FFD700").opacity(glowPulse ? 0.9 : 0.35)
                : .clear,
            radius: isMatching ? 10 : 0
        )
        .scaleEffect(isMatching ? (glowPulse ? 1.10 : 1.05) : 1.0)
        .animation(
            isMatching
                ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
                : .spring(response: 0.3, dampingFraction: 0.65),
            value: glowPulse
        )
        .onChange(of: isMatching) { _, nowMatching in
            glowPulse = nowMatching
        }
        .onAppear {
            if isMatching { glowPulse = true }
        }
    }

    // MARK: Slab shadow (depth effect)

    private var slabShadow: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(hex: "#C8B89A"))
            .frame(width: 62, height: 80)
            .offset(x: 3, y: 3)
    }

    // MARK: Tile face

    private var tileFace: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#2D2D4E"), Color(hex: "#1A1A35")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(tileContent)
            .overlay(goldBorder)
            .frame(width: 62, height: 80)
    }

    @ViewBuilder
    private var tileContent: some View {
        if let def = definition {
            VStack(spacing: 4) {
                // Main symbol
                Text(def.displaySymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(def.displayColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Group abbreviation (up to 3 chars)
                Text(def.groupLabel.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 6)
        } else {
            // Fallback if lookup returns nil
            Text("?")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var goldBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [Color(hex: "#FFD700").opacity(0.8), Color(hex: "#C8A000").opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}
