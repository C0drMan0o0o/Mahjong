import Foundation
import os

final class PersistenceService {
    static let shared = PersistenceService()
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.myplayground.MyPlayground", category: "PersistenceService")
    
    private init() {}

    // MARK: - Current Game

    func clearGame() {
        defaults.removeObject(forKey: "currentGame")
    }

    // MARK: - Level Progress

    var highestUnlockedLevel: Int {
        get { max(1, defaults.integer(forKey: "highestUnlockedLevel")) }
        set { defaults.set(newValue, forKey: "highestUnlockedLevel") }
    }

    var lastPlayedLevel: Int {
        get { max(1, defaults.integer(forKey: "lastPlayedLevel")) }
        set { defaults.set(newValue, forKey: "lastPlayedLevel") }
    }

    func completeLevel(_ level: Int, score: Int, time: Int) {
        if level + 1 > highestUnlockedLevel {
            highestUnlockedLevel = level + 1
        }
        lastPlayedLevel = level
        let key = "best_level_\(level)"
        let current = bestRecord(forLevel: level)
        let record = BestRecord(
            bestScore: max(score, current?.bestScore ?? 0),
            bestTime: current?.bestTime.map { min($0, time) } ?? time
        )
        do {
            let data = try JSONEncoder().encode(record)
            defaults.set(data, forKey: key)
        } catch {
            logger.error("Failed to encode BestRecord for level \(level): \(error.localizedDescription)")
        }
    }

    func bestRecord(forLevel level: Int) -> BestRecord? {
        guard let data = defaults.data(forKey: "best_level_\(level)") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(BestRecord.self, from: data)
        } catch {
            logger.error("Failed to decode BestRecord for level \(level): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Settings

    var soundEnabled: Bool {
        get { defaults.object(forKey: "soundEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "soundEnabled") }
    }

    var musicEnabled: Bool {
        get { defaults.object(forKey: "musicEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "musicEnabled") }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: "hapticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hapticsEnabled") }
    }

    var tileTheme: String {
        get { defaults.string(forKey: "tileTheme") ?? "Classic" }
        set { defaults.set(newValue, forKey: "tileTheme") }
    }

    var dimBlockedTiles: Bool {
        get { defaults.bool(forKey: "dimBlockedTiles") }
        set { defaults.set(newValue, forKey: "dimBlockedTiles") }
    }

    // MARK: - Stats

    var totalGamesPlayed: Int {
        get { defaults.integer(forKey: "totalGamesPlayed") }
        set { defaults.set(newValue, forKey: "totalGamesPlayed") }
    }

    var totalPairsMatched: Int {
        get { defaults.integer(forKey: "totalPairsMatched") }
        set { defaults.set(newValue, forKey: "totalPairsMatched") }
    }
}

extension Int {
    var formattedTime: String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
