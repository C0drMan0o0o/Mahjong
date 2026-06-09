import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("musicEnabled") private var musicEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("tileTheme") private var tileTheme = "Classic"
    @AppStorage("dimBlockedTiles") private var dimBlockedTiles = false

    @AppStorage("totalGamesPlayed") private var totalGamesPlayed = 0
    @AppStorage("totalPairsMatched") private var totalPairsMatched = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#2C1810").ignoresSafeArea()

                List {
                    Section("Audio") {
                        toggle("Sound Effects", systemImage: "speaker.wave.2", value: $soundEnabled)
                        toggle("Background Music", systemImage: "music.note", value: $musicEnabled)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Feel") {
                        toggle("Haptic Feedback", systemImage: "hand.tap", value: $hapticsEnabled)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Appearance") {
                        Picker("Tile Theme", selection: $tileTheme) {
                            Text("Classic").tag("Classic")
                            Text("Dark").tag("Dark")
                            Text("Minimal").tag("Minimal")
                        }
                        .pickerStyle(.segmented)
                        toggle("Dim Blocked Tiles", systemImage: "circle.slash", value: $dimBlockedTiles)
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section("Stats") {
                        labelRow("Games Played", value: "\(totalGamesPlayed)")
                        labelRow("Pairs Matched", value: "\(totalPairsMatched)")
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }
        }
    }

    private func toggle(_ label: String, systemImage: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Label(label, systemImage: systemImage)
        }
        .tint(Color(hex: "#FFD700"))
    }

    private func labelRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value).foregroundColor(Color(hex: "#FFD700")).fontWeight(.semibold)
        }
    }
}
