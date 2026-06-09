import SwiftUI

struct TileView: View {
    let tile: Tile
    let tileW: CGFloat
    let tileH: CGFloat
    let depth: CGFloat
    let isFree: Bool
    let hintRole: HintRole?
    let onTap: () -> Void

    @AppStorage("tileTheme") private var tileTheme: String = "Classic"
    @AppStorage("dimBlockedTiles") private var dimBlockedTiles = false
    @State private var isShakingLocal = false

    private var def: TileDefinition? {
        TileDefinition.lookup[tile.suit]?[tile.value]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 3D depth slab (only when free)
            if isFree {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(hex: "#C8B89A"))
                    .frame(width: tileW, height: tileH)
                    .offset(x: depth, y: depth)
            }

            // Tile face
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(faceColor)
                .frame(width: tileW, height: tileH)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: tile.isSelected ? 2.5 : (hintRole != nil ? 2 : 0.8))
                )
                .overlay(tileContent)
                .overlay(lockedOverlay)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 1)
        }
        .frame(width: tileW + depth, height: tileH + depth)
        .scaleEffect(tile.isSelected ? 1.07 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.5), value: tile.isSelected)
        .modifier(ShakeModifier(trigger: isShakingLocal))
        .modifier(HintPulse(role: hintRole))
        .opacity(tile.isRemoved ? 0 : (dimBlockedTiles && !isFree ? 0.6 : 1.0))
        .scaleEffect(tile.isRemoved ? 0.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: tile.isRemoved)
        .onTapGesture {
            guard !tile.isRemoved else { return }
            if isFree {
                onTap()
            } else {
                isShakingLocal = true
                HapticService.notification(.error)
                SoundService.shared.play("lock")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isShakingLocal = false
                }
            }
        }
        .accessibilityLabel(accessLabel)
        .accessibilityHint(isFree ? "Free tile, tap to collect" : "Blocked")
        .accessibilityAddTraits(isFree ? .isButton : [])
    }

    // MARK: - Derived

    private var cornerRadius: CGFloat { max(3, tileW * 0.1) }

    private var symbolFontSize: CGFloat { max(8, tileW * 0.38) }
    private var subtitleFontSize: CGFloat { max(6, tileW * 0.18) }

    private var faceColor: Color {
        switch tileTheme {
        case "Dark":    return Color(hex: "#2A2A2A")
        case "Minimal": return Color(hex: "#F0F0F0")
        default:        return Color(hex: "#FAF0E6")
        }
    }

    private var borderColor: Color {
        if tile.isSelected { return Color(hex: "#FFD700") }
        switch hintRole {
        case .matchA, .matchB: return Color(hex: "#FFD700").opacity(0.8)
        case .blocker:         return Color(hex: "#FF6B00").opacity(0.8)
        case nil:              return Color(hex: "#C8B89A").opacity(0.5)
        }
    }

    @ViewBuilder
    private var tileContent: some View {
        if let d = def {
            VStack(spacing: 0) {
                Text(d.displaySymbol)
                    .font(.system(size: symbolFontSize, weight: .semibold))
                    .foregroundColor(d.displayColor)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(d.groupLabel.prefix(3))
                    .font(.system(size: subtitleFontSize, weight: .regular))
                    .foregroundColor(d.displayColor.opacity(0.55))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            }
            .padding(max(2, tileW * 0.06))
        }
    }

    @ViewBuilder
    private var lockedOverlay: some View {
        if !isFree {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(dimBlockedTiles ? 0.55 : 0.28))
        }
    }

    private var accessLabel: String {
        guard let d = def else { return "Tile" }
        return "\(d.groupLabel) \(d.displaySymbol)"
    }
}

// MARK: - Shake

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content.offset(x: offset)
            .task(id: trigger) {
                guard trigger else { return }
                withAnimation(.linear(duration: 0.07).repeatCount(4, autoreverses: true)) { offset = 7 }
                try? await Task.sleep(nanoseconds: 350_000_000)
                offset = 0
            }
    }
}

// MARK: - Hint pulse

struct HintPulse: ViewModifier {
    let role: HintRole?
    @State private var glowing = false

    private var glowColor: Color {
        switch role {
        case .blocker:         return Color(hex: "#FF6B00")
        case .matchA, .matchB: return Color(hex: "#FFD700")
        case nil:              return .clear
        }
    }

    private var duration: Double {
        role == .blocker ? 0.4 : 0.55
    }

    func body(content: Content) -> some View {
        let active = role != nil
        return content
            .shadow(color: active ? glowColor.opacity(glowing ? 0.9 : 0.2) : .clear,
                    radius: active ? (glowing ? 8 : 3) : 0)
            .animation(active ? Animation.easeInOut(duration: duration).repeatForever(autoreverses: true) : .default, value: glowing)
            .onChange(of: role) { _, newRole in
                if newRole != nil {
                    glowing = true
                } else {
                    glowing = false
                }
            }
            .onAppear {
                if active {
                    glowing = true
                }
            }
    }
}

extension Color {
    func lighter(by percentage: CGFloat = 0.15) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Color(hue: Double(h), saturation: Double(max(0, s - percentage)), brightness: Double(min(1, b + percentage)), opacity: Double(a))
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(max(0, s - percentage)), brightness: Double(min(1, b + percentage)), opacity: Double(a))
        #endif
        return self
    }
}
