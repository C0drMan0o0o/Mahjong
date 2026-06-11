import SwiftUI

struct MainMenuView: View {
    @State private var selectedLevelWrapper: LevelWrapper? = nil
    @State private var showSettings = false
    @State private var driftingTiles: [DriftTile] = []
    @State private var animateDrift = false

    private let totalLevels = 50
    @State private var highestUnlocked: Int = PersistenceService.shared.highestUnlockedLevel

    var body: some View {
        GeometryReader { geo in
        ZStack {
            LinearGradient(colors: [Color(hex: "#2C1810"), Color(hex: "#1A0F08")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Drifting background tiles
            ForEach(driftingTiles) { t in
                Text(t.symbol)
                    .font(.system(size: t.size))
                    .opacity(t.opacity)
                    .position(x: t.position.x, y: animateDrift ? t.targetY : t.position.y)
                    .rotationEffect(.degrees(animateDrift ? t.targetRotation : t.rotation))
            }

            VStack(spacing: 0) {
                // Title
                VStack(spacing: 6) {
                    Text("麻将")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#FFD700"))
                    Text("MAHJONG SOLITAIRE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(3)
                }
                .padding(.top, 50)
                .padding(.bottom, 24)

                // Continue button
                Button {
                    selectedLevelWrapper = LevelWrapper(level: PersistenceService.shared.lastPlayedLevel)
                } label: {
                    HStack {
                        Text("▶ Continue")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Text("Level \(PersistenceService.shared.lastPlayedLevel)")
                            .font(.system(size: 14))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 15)
                    .background(Color(hex: "#1B4332"))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Level grid
                Text("SELECT LEVEL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                              spacing: 10) {
                        if totalLevels > 0 {
                            ForEach(1...totalLevels, id: \.self) { level in
                                levelCell(level)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                Spacer()

                // Settings
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 30)
            }
        }
            .onAppear {
                spawnDriftingTiles(in: geo.size)
                DispatchQueue.main.async {
                    withAnimation(.linear(duration: 22).repeatForever(autoreverses: true)) {
                        animateDrift = true
                    }
                }
            }
            .onDisappear {
                animateDrift = false
            }
            .fullScreenCover(item: $selectedLevelWrapper) { wrapper in
                GameView(level: wrapper.level)
            }
            .onChange(of: selectedLevelWrapper) {
                // Refresh unlock state whenever the game screen is dismissed.
                highestUnlocked = PersistenceService.shared.highestUnlockedLevel
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        } // GeometryReader
    }

    // MARK: - Level cell

    private func levelCell(_ level: Int) -> some View {
        let unlocked = level <= highestUnlocked
        let best = PersistenceService.shared.bestRecord(forLevel: level)
        let completed = best != nil

        return Button {
            if unlocked { selectedLevelWrapper = LevelWrapper(level: level) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cellBackground(unlocked: unlocked, completed: completed))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(cellBorder(unlocked: unlocked, completed: completed), lineWidth: 1.5)
                    )

                VStack(spacing: 3) {
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        Text("\(level)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(completed ? Color(hex: "#FFD700") : .white)
                        if completed {
                            Text("⭐")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func cellBackground(unlocked: Bool, completed: Bool) -> Color {
        if !unlocked  { return Color.white.opacity(0.04) }
        if completed  { return Color(hex: "#1B4332").opacity(0.8) }
        return Color.white.opacity(0.09)
    }

    private func cellBorder(unlocked: Bool, completed: Bool) -> Color {
        if completed { return Color(hex: "#FFD700").opacity(0.6) }
        if unlocked  { return Color.white.opacity(0.15) }
        return Color.white.opacity(0.06)
    }

    // MARK: - Drifting tiles

    private func spawnDriftingTiles(in size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let symbols = ["🀇","🀈","🀉","🀊","🀋","🀌","🀍","🀎","🀏","🀙","🀚","🀛","🀜","🀝"]
        driftingTiles = (0..<16).map { _ in
            let startY = CGFloat.random(in: 0...size.height)
            let startRot = Double.random(in: -30...30)
            return DriftTile(
                symbol: symbols.randomElement()!,
                size: CGFloat.random(in: 18...40),
                opacity: Double.random(in: 0.04...0.1),
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: startY),
                rotation: startRot,
                targetY: startY - CGFloat.random(in: 60...180),
                targetRotation: startRot + Double.random(in: -20...20)
            )
        }
    }
}

// MARK: - Helpers

struct DriftTile: Identifiable {
    let id = UUID()
    let symbol: String
    let size: CGFloat
    let opacity: Double
    var position: CGPoint
    var rotation: Double
    let targetY: CGFloat
    let targetRotation: Double
}

// Wraps Int so it works with .fullScreenCover(item:)
struct LevelWrapper: Identifiable, Equatable {
    let id: Int
    let level: Int
    init(level: Int) { self.id = level; self.level = level }
}
