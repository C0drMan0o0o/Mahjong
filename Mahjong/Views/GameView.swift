import SwiftUI

struct GameView: View {
    let level: Int
    @StateObject private var vm: GameViewModel
    @Environment(\.dismiss) private var dismiss

    init(level: Int) {
        self.level = level
        _vm = StateObject(wrappedValue: GameViewModel(level: level))
    }

    var body: some View {
        ZStack {
            // Background
            RadialGradient(colors: [Color(hex: "#2C1810"), Color(hex: "#1A0F08")],
                           center: .center, startRadius: 80, endRadius: 500)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top HUD ──────────────────────────────
                topBar

                // ── Combo banner ─────────────────────────
                Group {
                    if vm.comboCount >= 2 {
                        HStack(spacing: 6) {
                            Text("🔥")
                                .font(.system(size: 16))
                            Text("COMBO ×\(vm.comboCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#FFD700"))
                                .kerning(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: vm.comboCount)

                // ── Board (fills remaining space) ────────
                GameBoardView(vm: vm)
                    .padding(8)

                // ── Shelf (always visible) ────────────────────
                if let shelf = vm.shelfVM {
                    TileShelfView(shelfVM: shelf)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                // ── Toolbar ───────────────────────────────
                bottomToolbar
                    .padding(.bottom, 8)
            }

            // Pause overlay
            if vm.isPaused { pauseOverlay }

            // Game over overlay
            if vm.isGameOver { gameOverOverlay }

            // Deadlock prompt
            if vm.showDeadlockAlert && !vm.isGameOver && !vm.isVictory {
                deadlockPromptOverlay
            }

            // Victory
            if vm.isVictory {
                LevelCompleteView(
                    score: vm.score,
                    moves: vm.moves,
                    elapsedSeconds: vm.elapsedSeconds,
                    currentLevel: vm.currentLevel,
                    onPlayAgain: { vm.newGame(level: level) },
                    onNextLevel: { vm.newGame(level: level + 1) },
                    onMainMenu: { dismiss() }
                )
                .transition(.opacity)
                .animation(.easeInOut, value: vm.isVictory)
            }
        }
        .statusBarHidden(!vm.isPaused && !vm.isGameOver && !vm.isVictory)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(vm.score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#FFD700"))
                    .contentTransition(.numericText())
                    .animation(.spring(), value: vm.score)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("MOVES")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(vm.matchesAvailable)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(vm.matchesAvailable == 0 ? Color(hex: "#FF4444") : .white)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: vm.matchesAvailable)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("TIME")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text(vm.elapsedSeconds.formattedTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("LEVEL")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(vm.currentLevel)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button { vm.togglePause() } label: {
                Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 28) {
            toolButton(icon: "💡", label: "Hint \(vm.hintsRemaining)",
                       disabled: vm.hintsRemaining == 0) { vm.useHint() }

            toolButton(icon: "↩️", label: "Undo",
                       disabled: false) { vm.undoLastMove() }

            toolButton(icon: "🔀", label: "Shuffle", disabled: false) { vm.shuffle() }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }

    private func toolButton(icon: String, label: String,
                             disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 26))
                    .opacity(disabled ? 0.3 : 1)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(disabled ? 0.3 : 0.75))
                    .accessibilityHidden(true)
            }
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Overlays

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("⏸ Paused")
                    .font(.system(size: 30, weight: .bold)).foregroundColor(.white)
                actionBtn("Resume", color: Color(hex: "#1B4332")) { vm.togglePause() }
                Button("Main Menu") { dismiss() }
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("😔 Game Over")
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text("No more moves available")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    actionBtn("Shuffle 🔀", color: Color(hex: "#1B4332")) {
                        vm.shuffle()
                    }
                    actionBtn("Restart", color: Color(hex: "#2C3E50")) {
                        vm.newGame(level: level)
                    }
                }
                Button("Main Menu") { dismiss() }
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 4)
            }
            .padding(28)
            .background(Color(hex: "#2C1810").opacity(0.97))
            .cornerRadius(22)
            .padding(32)
        }
    }

    private var deadlockPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🤔 No Moves Available")
                    .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                Text("Shuffle the tiles to continue?")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.65))
                HStack(spacing: 14) {
                    actionBtn("Shuffle 🔀", color: Color(hex: "#1B4332")) {
                        vm.showDeadlockAlert = false
                        vm.shuffle()
                    }
                    actionBtn("Keep Trying", color: Color(hex: "#2C3E50")) {
                        vm.showDeadlockAlert = false
                    }
                }
            }
            .padding(28)
            .background(Color(hex: "#2C1810").opacity(0.97))
            .cornerRadius(20)
            .padding(40)
        }
    }

    private func actionBtn(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 13)
                .background(color)
                .cornerRadius(11)
        }
    }

    private var formattedTime: String {
        vm.elapsedSeconds.formattedTime
    }
}
