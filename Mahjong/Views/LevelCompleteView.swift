import SwiftUI

struct LevelCompleteView: View {
    let score: Int
    let moves: Int
    let elapsedSeconds: Int
    let currentLevel: Int
    let onPlayAgain: () -> Void
    let onNextLevel: () -> Void
    let onMainMenu: () -> Void

    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea()

                // Confetti layer
                ForEach(confettiParticles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(p.position)
                        .opacity(p.opacity)
                }

            // Card
            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 60))
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1), value: appeared)

                Text("Congratulations!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#FFD700"))

                starsView

                VStack(spacing: 6) {
                    statRow(label: "Time", value: elapsedSeconds.formattedTime)
                    statRow(label: "Score", value: "\(score)")
                    statRow(label: "Moves", value: "\(moves)")
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

                VStack(spacing: 12) {
                    actionButton("Play Again", color: Color(hex: "#1B4332")) { onPlayAgain() }
                    if currentLevel < 50 {
                        actionButton("Next Level", color: Color(hex: "#2C3E50")) { onNextLevel() }
                    }
                    actionButton("Main Menu", color: Color.gray.opacity(0.4)) { onMainMenu() }
                }
            }
            .padding(32)
            .background(Color(hex: "#2C1810").opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .padding(40)
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: appeared)
        }
            .onAppear {
                appeared = true
                spawnConfetti(in: geo.size)
            }
        }
    }

    private var starsView: some View {
        let stars = starsEarned
        return HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Text(i < stars ? "⭐️" : "☆")
                    .font(.system(size: 32))
                    .scaleEffect(appeared && i < stars ? 1 : 0.5)
                    .animation(.spring().delay(0.3 + Double(i) * 0.15), value: appeared)
            }
        }
    }

    private var starsEarned: Int {
        if elapsedSeconds < 120 { return 3 }
        if elapsedSeconds < 300 { return 2 }
        return 1
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .cornerRadius(12)
        }
    }

    // MARK: - Confetti

    private func spawnConfetti(in size: CGSize) {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, Color(hex: "#FFD700")]
        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...14),
                position: CGPoint(x: CGFloat.random(in: 0...size.width),
                                  y: CGFloat.random(in: -50...size.height)),
                opacity: Double.random(in: 0.6...1.0)
            )
        }
        // Animate them falling
        withAnimation(.easeIn(duration: 2.5)) {
            confettiParticles = confettiParticles.map { p in
                var q = p
                q.position.y += CGFloat.random(in: 200...500)
                q.opacity = 0
                return q
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}
