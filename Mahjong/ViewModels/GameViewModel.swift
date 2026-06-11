import SwiftUI
import Combine
import UIKit

// MARK: - Hint model

struct HintResult {
    enum Kind {
        case freePair       // two free board tiles match — send both to shelf
        case shelfMatch     // one free board tile matches a tile on the shelf
        case blockerPath    // send orange tile first to open up a future match
    }
    let kind: Kind
    let matchTileA: UUID
    let matchTileB: UUID
    var blockerTileID: UUID? = nil
    var shelfTileID: UUID? = nil    // shelf tile to highlight (shelfMatch only)

    func message(hasShelfContext: Bool) -> String {
        switch kind {
        case .freePair:    return "Send both glowing tiles to your shelf!"
        case .shelfMatch:  return "This tile completes a match on your shelf!"
        case .blockerPath: return hasShelfContext
            ? "Send the orange tile first to unlock a shelf match!"
            : "Send the orange tile first to open a match"
        }
    }
}

enum HintRole {
    case matchA
    case matchB
    case blocker
}

enum UndoAction {
    case boardMatch(Tile, Tile, scoreAdded: Int)
    case shelfSend(Tile)
    case shelfMatch(Tile, Tile, scoreAdded: Int)
}

// MARK: -

struct BoardBounds {
    let minCol: Int
    let minRow: Int
    let maxCol: Int
    let maxRow: Int
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var tiles: [Tile] = []
    @Published var score: Int = 0
    @Published var moves: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var hintsRemaining: Int = 3
    @Published var undosRemaining: Int = 5
    @Published var shufflesRemaining: Int = 5
    @Published var revivesRemaining: Int = 3
    enum GameOverReason { case shelfOverflow, noMoves }
    @Published var isGameOver: Bool = false
    @Published var gameOverReason: GameOverReason? = nil
    @Published var isVictory: Bool = false
    @Published var currentHint: HintResult? = nil
    @Published var isPaused: Bool = false
    @Published var currentLevel: Int
    @Published var showDeadlockAlert: Bool = false
    @Published var selectedTileID: UUID? = nil
    @Published var matchesAvailable: Int = 0
    @Published var comboCount: Int = 0
    @Published var isShelfModeEnabled: Bool = false
    @Published var shelfVM: ShelfViewModel? = nil
    @Published var boardBounds: BoardBounds? = nil

    private var timer: AnyCancellable?
    private var hintTask: Task<Void, Never>?
    private var streakCount: Int = 0
    private var undoHistory: [UndoAction] = []
    private var lastMatchDate: Date? = nil

    init(level: Int) {
        self.currentLevel = level
        HapticService.prepare()
        newGame(level: level)
    }

    // MARK: - New Game

    func newGame(level: Int) {
        currentLevel = level
        tiles = []
        boardBounds = nil
        score = 0
        moves = 0
        elapsedSeconds = 0
        hintsRemaining = 3
        undosRemaining = 5
        shufflesRemaining = 5
        revivesRemaining = 3
        isGameOver = false
        gameOverReason = nil
        isVictory = false
        streakCount = 0
        hintTask?.cancel()
        hintTask = nil
        currentHint = nil
        showDeadlockAlert = false
        selectedTileID = nil
        matchesAvailable = 0
        comboCount = 0
        undoHistory = []
        lastMatchDate = nil
        shelfVM?.reset()
        PersistenceService.shared.clearGame()
        PersistenceService.shared.lastPlayedLevel = level
        
        HapticService.prepare()

        // Capture the positions (value type) on the main actor, then generate off-thread.
        let positions = BoardLayout.classic.positions
        Task {
            let newTiles = await Task.detached(priority: .userInitiated) {
                LevelGenerator.generateFromPositions(positions)
            }.value
            self.tiles = newTiles
            
            let minCol = newTiles.map(\.col).min() ?? 0
            let minRow = newTiles.map(\.row).min() ?? 0
            let maxCol = newTiles.map(\.col).max() ?? 0
            let maxRow = newTiles.map(\.row).max() ?? 0
            self.boardBounds = BoardBounds(minCol: minCol, minRow: minRow, maxCol: maxCol, maxRow: maxRow)
            
            self.updateMatchesAvailable()
            self.checkForDeadlock()
            
            // Delay starting the timer and incrementing totalGamesPlayed until generation completes
            self.startTimer()
            PersistenceService.shared.totalGamesPlayed += 1
        }

        // Shelf is always enabled (Vita Mahjong rules)
        enableShelfMode()
    }

    // MARK: - Shelf mode

    func enableShelfMode() {
        let shelf = ShelfViewModel()
        shelf.onMatchFound = { [weak self] existingTile, newTile in
            guard let self else { return }
            let now = Date()
            if let last = self.lastMatchDate, now.timeIntervalSince(last) < 3.0 {
                self.comboCount += 1
            } else {
                self.comboCount = 1
            }
            self.lastMatchDate = now
            let multiplier: Double = self.comboCount >= 5 ? 2.0 : self.comboCount >= 3 ? 1.5 : 1.0
            let addedScore = Int(100.0 * multiplier)
            self.score += addedScore
            self.moves += 1
            PersistenceService.shared.totalPairsMatched += 1
            
            // Track shelf match in undo history (existingTile first, newTile/recently picked second)
            self.undoHistory.append(.shelfMatch(existingTile, newTile, scoreAdded: addedScore))
            
            self.updateMatchesAvailable()
            self.checkVictory()
            self.checkForDeadlock()
        }
        shelf.onShelfOverflow = { [weak self] in
            self?.gameOverReason = .shelfOverflow
            self?.isGameOver = true
            self?.timer?.cancel()
        }
        self.shelfVM = shelf
        self.isShelfModeEnabled = true
    }

    func disableShelfMode() {
        shelfVM?.reset()
        shelfVM = nil
        isShelfModeEnabled = false
    }

    // MARK: - Tile selection (Vita Mahjong rules)

    func selectTile(_ tile: Tile) {
        // Shelf mode: send tile to shelf instead of direct match
        if isShelfModeEnabled, let shelf = shelfVM {
            guard !tile.isRemoved, isTileFree(tile), !isPaused, !isGameOver, !isVictory else { return }
            cancelHint()
            
            // Set removed ONLY if shelf accepted the tile
            let accepted = shelf.addTile(tile)
            if accepted {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: tile.id) { $0.isRemoved = true }
                }
                undoHistory.append(.shelfSend(tile))
            }
            return
        }

        guard !tile.isRemoved, isTileFree(tile), !isPaused, !isGameOver, !isVictory else { return }

        cancelHint()

        // Tap already-selected tile → deselect
        if selectedTileID == tile.id {
            updateTile(id: tile.id) { $0.isSelected = false }
            selectedTileID = nil
            return
        }

        // A different tile is already selected
        if let selID = selectedTileID,
           let selTile = tiles.first(where: { $0.id == selID && !$0.isRemoved }) {

            if tile.matches(selTile) {
                // ✅ Match — clear both
                let now = Date()
                if let last = lastMatchDate, now.timeIntervalSince(last) < 3.0 {
                    comboCount += 1
                } else {
                    comboCount = 1
                }
                lastMatchDate = now

                let multiplier: Double = comboCount >= 5 ? 2.0 : comboCount >= 3 ? 1.5 : 1.0
                let addedScore = Int(100.0 * multiplier)

                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: selID)  { $0.isRemoved = true; $0.isSelected = false }
                    updateTile(id: tile.id) { $0.isRemoved = true }
                }
                selectedTileID = nil
                undoHistory.append(.boardMatch(selTile, tile, scoreAdded: addedScore))

                score += addedScore
                moves += 1

                SoundService.shared.play("tile_match")
                HapticService.impact(.medium)
                PersistenceService.shared.totalPairsMatched += 1

                updateMatchesAvailable()
                checkVictory()
                checkForDeadlock()
            } else {
                // ❌ No match — swap selection
                updateTile(id: selID) { $0.isSelected = false }
                updateTile(id: tile.id) { $0.isSelected = true }
                selectedTileID = tile.id
                SoundService.shared.play("tile_select")
                HapticService.impact(.light)
            }
        } else {
            // Nothing selected yet — select this tile
            updateTile(id: tile.id) { $0.isSelected = true }
            selectedTileID = tile.id
            SoundService.shared.play("tile_select")
            HapticService.impact(.light)
        }
    }

    // MARK: - Free tile detection

    func isTileFree(_ tile: Tile) -> Bool {
        guard !tile.isRemoved else { return false }
        let active = tiles.filter { !$0.isRemoved }

        let blockedAbove = active.contains {
            $0.id != tile.id && $0.layer == tile.layer + 1 && $0.overlapsHorizontally(tile)
        }
        if blockedAbove { return false }

        let leftBlocked = active.contains {
            $0.id != tile.id && $0.layer == tile.layer &&
            $0.col + 2 == tile.col && $0.occupiedRows.overlaps(tile.occupiedRows)
        }
        let rightBlocked = active.contains {
            $0.id != tile.id && $0.layer == tile.layer &&
            $0.col == tile.col + 2 && $0.occupiedRows.overlaps(tile.occupiedRows)
        }
        return !leftBlocked || !rightBlocked
    }

    // MARK: - Hint

    func useHint() {
        guard hintsRemaining > 0, !isPaused else { return }
        guard let result = findHint() else { return }
        hintsRemaining -= 1
        score = max(0, score - 50)
        streakCount = 0
        currentHint = result
        HapticService.impact(.light)
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            currentHint = nil
        }
    }

    private func cancelHint() {
        hintTask?.cancel()
        hintTask = nil
        currentHint = nil
    }

    private func findHint() -> HintResult? {
        let active = tiles.filter { !$0.isRemoved }
        let free = active.filter { isTileFree($0) }

        // Tier 1 (shelf mode): free board tile matches a tile already on the shelf.
        // Most immediately useful — player sends one tile to get an instant clear.
        // Exclude tiles currently mid-animation (matchingTileIDs) so we don't hint at
        // a shelf tile that is about to vanish.
        if isShelfModeEnabled, let shelf = shelfVM {
            let animatingIDs = shelf.matchingTileIDs
            let shelfTiles = shelf.slots.compactMap { $0 }.filter { !animatingIDs.contains($0.id) }
            for boardTile in free {
                if let shelfMatch = shelfTiles.first(where: { boardTile.matches($0) }) {
                    return HintResult(kind: .shelfMatch,
                                      matchTileA: boardTile.id,
                                      matchTileB: boardTile.id,
                                      shelfTileID: shelfMatch.id)
                }
            }
        }

        // Tier 1.5 (shelf mode): a blocked board tile matches a shelf tile.
        // Show the player which free blocker to tap first. Pick the most accessible
        // candidate (fewest direct blockers).
        if isShelfModeEnabled, let shelf = shelfVM {
            let animatingIDs = shelf.matchingTileIDs
            let shelfTiles = shelf.slots.compactMap { $0 }.filter { !animatingIDs.contains($0.id) }
            var bestCandidate: (blockedTile: Tile, shelfTile: Tile, blocker: Tile, blockerCount: Int)?
            for boardTile in active where !isTileFree(boardTile) {
                guard let shelfTile = shelfTiles.first(where: { boardTile.matches($0) }) else { continue }
                let blockers = directBlockers(of: boardTile, in: active)
                guard let freeBlocker = blockers.first(where: { isTileFree($0) }) else { continue }
                let count = blockers.count
                if bestCandidate == nil || count < bestCandidate!.blockerCount {
                    bestCandidate = (boardTile, shelfTile, freeBlocker, count)
                }
            }
            if let c = bestCandidate {
                return HintResult(kind: .blockerPath,
                                  matchTileA: c.blockedTile.id,
                                  matchTileB: c.blockedTile.id,
                                  blockerTileID: c.blocker.id,
                                  shelfTileID: c.shelfTile.id)
            }
        }

        // Tier 2: two free board tiles that match each other.
        for i in 0..<free.count {
            for j in (i + 1)..<free.count {
                if free[i].matches(free[j]) {
                    return HintResult(kind: .freePair, matchTileA: free[i].id, matchTileB: free[j].id)
                }
            }
        }

        // Tier 3: a free blocker (orange) whose removal exposes a blocked tile that has a
        // free match partner (gold). Pick the most accessible candidate (fewest blockers).
        var tier3Best: (match: Tile, tile: Tile, blocker: Tile, count: Int)?
        for tile in active where !isTileFree(tile) {
            guard let match = free.first(where: { $0.id != tile.id && $0.matches(tile) }) else { continue }
            let blockers = directBlockers(of: tile, in: active)
            guard let freeBlocker = blockers.first(where: { isTileFree($0) && $0.id != match.id }) else { continue }
            let count = blockers.count
            if tier3Best == nil || count < tier3Best!.count {
                tier3Best = (match, tile, freeBlocker, count)
            }
        }
        if let b = tier3Best {
            return HintResult(kind: .blockerPath,
                              matchTileA: b.match.id,
                              matchTileB: b.tile.id,
                              blockerTileID: b.blocker.id)
        }

        // Tier 4: two-level blocker — the immediate blocker is itself blocked, but its
        // blocker is free. Pick the candidate with the fewest second-level blockers.
        var tier4Best: (match: Tile, tile: Tile, freeB2: Tile, count: Int)?
        for tile in active where !isTileFree(tile) {
            guard let match = free.first(where: { $0.id != tile.id && $0.matches(tile) }) else { continue }
            let blockers1 = directBlockers(of: tile, in: active)
            for b1 in blockers1 where !isTileFree(b1) {
                let blockers2 = directBlockers(of: b1, in: active).filter { $0.id != tile.id }
                guard let freeB2 = blockers2.first(where: { isTileFree($0) && $0.id != match.id }) else { continue }
                let count = blockers2.count
                if tier4Best == nil || count < tier4Best!.count {
                    tier4Best = (match, tile, freeB2, count)
                }
            }
        }
        if let b = tier4Best {
            return HintResult(kind: .blockerPath,
                              matchTileA: b.match.id,
                              matchTileB: b.tile.id,
                              blockerTileID: b.freeB2.id)
        }

        return nil
    }

    private func directBlockers(of tile: Tile, in active: [Tile]) -> [Tile] {
        active.filter { b in
            b.id != tile.id && (
                (b.layer == tile.layer &&
                 (b.col + 2 == tile.col || b.col == tile.col + 2) &&
                 b.occupiedRows.overlaps(tile.occupiedRows)) ||
                (b.layer == tile.layer + 1 && b.overlapsHorizontally(tile))
            )
        }
    }

    // MARK: - Deadlock detection

    private func checkForDeadlock() {
        guard !tiles.filter({ !$0.isRemoved }).isEmpty else { return }
        guard !isVictory, !isGameOver else { return }
        
        // In shelf-mode, check if shelf has matches or if board has free tiles matching shelf tiles
        if isShelfModeEnabled {
            if let shelf = shelfVM, shelf.hasMatchOnShelf() {
                return
            }
            if let shelf = shelfVM {
                let shelfTiles = shelf.slots.compactMap { $0 }
                let freeBoardTiles = tiles.filter { !$0.isRemoved && isTileFree($0) }
                let hasMatchWithShelf = freeBoardTiles.contains { boardTile in
                    shelfTiles.contains { shelfTile in
                        boardTile.matches(shelfTile)
                    }
                }
                if hasMatchWithShelf {
                    return
                }
            }
        }

        if findHint() == nil {
            gameOverReason = .noMoves
            showDeadlockAlert = true
        }
    }

    // MARK: - Undo

    func undoLastMove() {
        // Fix guard order: check isPaused first before popping/discarding undo history
        guard !isPaused else { return }
        guard undosRemaining > 0 else { return }
        guard let last = undoHistory.popLast() else { return }

        undosRemaining -= 1

        if isShelfModeEnabled {
            switch last {
            case .shelfSend(let tile):
                if let shelf = shelfVM {
                    shelf.removeTile(id: tile.id)
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: tile.id) { $0.isRemoved = false }
                }
                updateMatchesAvailable()
                HapticService.impact(.light)

            case .shelfMatch(let tile1, let tile2, let scoreAdded):
                // tile1 is existing tile, tile2 is the newly matched tile
                if let shelf = shelfVM {
                    shelf.restoreTileToShelf(tile1)
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: tile2.id) { $0.isRemoved = false }
                }
                // Remove the corresponding .shelfSend(tile2) from the undo history
                if let idx = undoHistory.lastIndex(where: {
                    if case .shelfSend(let t) = $0, t.id == tile2.id { return true }
                    return false
                }) {
                    undoHistory.remove(at: idx)
                }
                score = max(0, score - scoreAdded)
                moves = max(0, moves - 1)
                comboCount = 0
                lastMatchDate = nil
                updateMatchesAvailable()
                HapticService.impact(.light)

            case .boardMatch(let tile1, let tile2, let scoreAdded):
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: tile1.id) { $0.isRemoved = false; $0.isSelected = false }
                    updateTile(id: tile2.id) { $0.isRemoved = false; $0.isSelected = false }
                }
                score = max(0, score - scoreAdded)
                moves = max(0, moves - 1)
                updateMatchesAvailable()
                HapticService.impact(.light)
            }
        } else {
            switch last {
            case .boardMatch(let tile1, let tile2, let scoreAdded):
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    updateTile(id: tile1.id) { $0.isRemoved = false; $0.isSelected = false }
                    updateTile(id: tile2.id) { $0.isRemoved = false; $0.isSelected = false }
                }
                if let selID = selectedTileID {
                    updateTile(id: selID) { $0.isSelected = false }
                    selectedTileID = nil
                }
                score = max(0, score - scoreAdded)
                moves = max(0, moves - 1)
                comboCount = 0
                lastMatchDate = nil
                updateMatchesAvailable()
                HapticService.impact(.light)
            default:
                break
            }
        }
        checkVictory()
        checkForDeadlock()
    }

    // MARK: - Revive

    func revive() {
        guard revivesRemaining > 0 else { return }
        revivesRemaining -= 1

        switch gameOverReason {
        case .shelfOverflow:
            // Return the last 3 tiles from the shelf to the board (multi-undo).
            // The board state is otherwise preserved exactly as-is.
            if isShelfModeEnabled, let shelf = shelfVM {
                let tilesToReturn = shelf.slots.compactMap { $0 }.suffix(3)
                for tile in tilesToReturn {
                    shelf.removeTile(id: tile.id)
                    updateTile(id: tile.id) { $0.isRemoved = false }
                }
            }

        case .noMoves, .none:
            // Free shuffle — doesn't consume the player's shuffle allowance.
            shufflesRemaining += 1
            shuffle()
        }

        gameOverReason = nil
        isGameOver = false
        updateMatchesAvailable()
        startTimer()
    }

    // MARK: - Shuffle

    func shuffle() {
        guard !isPaused else { return }
        if let selID = selectedTileID {
            updateTile(id: selID) { $0.isSelected = false }
            selectedTileID = nil
        }
        guard shufflesRemaining > 0 else { return }
        comboCount = 0
        showDeadlockAlert = false
        shufflesRemaining -= 1
        
        // Reset or handle the shelf correctly when shuffle occurs (return shelf tiles to board)
        if isShelfModeEnabled, let shelf = shelfVM {
            let shelfTiles = shelf.slots.compactMap { $0 }
            for tile in shelfTiles {
                updateTile(id: tile.id) { $0.isRemoved = false }
            }
            shelf.reset()
        }

        let active = tiles.filter { !$0.isRemoved }
        var values = active.map { (suit: $0.suit, value: $0.value) }.shuffled()
        values = LevelGenerator.repairPairs(values)
        var idx = 0
        for i in tiles.indices where !tiles[i].isRemoved {
            let old = tiles[i]
            tiles[i] = Tile(id: old.id, suit: values[idx].suit, value: values[idx].value,
                            row: old.row, col: old.col, layer: old.layer)
            idx += 1
        }
        separateAdjacentFreeMatches()
        HapticService.impact(.heavy)
        updateMatchesAvailable()
    }

    // After a shuffle, swap values to break up adjacent free tiles that already match.
    private func separateAdjacentFreeMatches() {
        let maxPasses = 40
        for _ in 0..<maxPasses {
            // Recompute free indices each pass so we work with current state.
            let freeIndices = tiles.indices.filter { !tiles[$0].isRemoved && isTileFree(tiles[$0]) }
            var swapped = false
            outer: for i in freeIndices {
                for j in freeIndices where j != i {
                    let a = tiles[i], b = tiles[j]
                    guard areAdjacentFree(a, b), a.matches(b) else { continue }
                    // Find a free tile c whose value won't match a after the swap,
                    // and that won't introduce a new adjacent free match at its own position.
                    for k in freeIndices where k != i && k != j {
                        let c = tiles[k]
                        // c's current value must not match a (so b's new value is safe next to a)
                        guard !c.matches(a) else { continue }
                        // c must not be adjacent to a (avoid creating a new problem there)
                        guard !areAdjacentFree(a, c) else { continue }
                        // Any new adjacencies introduced at c's position are resolved in the next pass.
                        // Swap values of b (index j) and c (index k)
                        let bSuit = tiles[j].suit; let bVal = tiles[j].value
                        tiles[j] = Tile(id: tiles[j].id, suit: tiles[k].suit, value: tiles[k].value,
                                        row: tiles[j].row, col: tiles[j].col, layer: tiles[j].layer)
                        tiles[k] = Tile(id: tiles[k].id, suit: bSuit, value: bVal,
                                        row: tiles[k].row, col: tiles[k].col, layer: tiles[k].layer)
                        swapped = true
                        break outer
                    }
                }
            }
            if !swapped { break }
        }
    }

    private func areAdjacentFree(_ a: Tile, _ b: Tile) -> Bool {
        guard a.layer == b.layer else { return false }
        let colDiff = abs(a.col - b.col)
        let rowDiff = abs(a.row - b.row)
        let rowsOverlap = a.occupiedRows.overlaps(b.occupiedRows)
        let colsOverlap = a.occupiedCols.overlaps(b.occupiedCols)
        // Horizontal neighbors: columns 2 apart, same row band
        // Vertical neighbors: rows 2 apart, same column band
        return (colDiff == 2 && rowsOverlap) || (rowDiff == 2 && colsOverlap)
    }

    // MARK: - Matches Available

    private func updateMatchesAvailable() {
        let free = tiles.filter { !$0.isRemoved && isTileFree($0) }
        var count = 0
        for i in 0..<free.count {
            for j in (i + 1)..<free.count {
                if free[i].matches(free[j]) { count += 1 }
            }
        }
        matchesAvailable = count
    }

    // MARK: - Timer

    func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.isPaused, !self.isVictory, !self.isGameOver else { return }
                self.elapsedSeconds += 1
            }
    }

    func togglePause() { isPaused.toggle() }
    func resumeTimer() { isPaused = false }

    // MARK: - Victory

    private func checkVictory() {
        guard tiles.filter({ !$0.isRemoved }).isEmpty else { return }
        // In shelf mode, shelf must also be fully cleared
        if let shelf = shelfVM, shelf.slots.compactMap({ $0 }).count > 0 { return }
        isVictory = true
        timer?.cancel()
        SoundService.shared.play("victory")
        HapticService.notification(.success)
        
        let finalScore = max(0, score - elapsedSeconds * 2)
        PersistenceService.shared.completeLevel(currentLevel, score: finalScore, time: elapsedSeconds)
        PersistenceService.shared.clearGame()

        // Animate/publish victory score time penalties step-wise
        let difference = score - finalScore
        if difference > 0 {
            Task {
                let steps = min(20, difference)
                let decrementPerStep = difference / steps
                for _ in 0..<steps {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    self.score = max(finalScore, self.score - decrementPerStep)
                }
                self.score = finalScore
            }
        } else {
            score = finalScore
        }
    }

    // MARK: - Helpers

    private func updateTile(id: UUID, mutation: (inout Tile) -> Void) {
        if let idx = tiles.firstIndex(where: { $0.id == id }) {
            mutation(&tiles[idx])
        }
    }
}

// MARK: - Haptics

enum HapticService {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        guard PersistenceService.shared.hapticsEnabled else { return }
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard PersistenceService.shared.hapticsEnabled else { return }
        switch style {
        case .light:
            lightGenerator.prepare()
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.prepare()
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.prepare()
            heavyGenerator.impactOccurred()
        default:
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.prepare()
            gen.impactOccurred()
        }
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard PersistenceService.shared.hapticsEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }
}
