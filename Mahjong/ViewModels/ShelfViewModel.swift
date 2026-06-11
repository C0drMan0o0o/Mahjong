import SwiftUI
import Combine

/// Manages the 4-slot tile shelf/tray for Mahjong Solitaire shelf-mode levels.
/// Tiles are added from the board; matching pairs auto-clear with animation.
/// Designed to be owned by GameViewModel and swapped in/out per level mode.
@MainActor
final class ShelfViewModel: ObservableObject {

    // MARK: - Published State

    /// The 4 shelf slots. nil = empty, non-nil = tile occupying that slot.
    @Published var slots: [Tile?] = Array(repeating: nil, count: 4)

    /// IDs of tiles currently in a flash-match animation (will be cleared shortly).
    @Published var matchingTileIDs: Set<UUID> = []

    // MARK: - Internal State

    /// Track the order in which tiles were inserted (for LIFO undo).
    private(set) var insertionLog: [Tile] = []

    /// active tasks tracker to prevent stale callbacks and writes
    private var activeTasks: [Task<Void, Never>] = []

    /// Current generation count to prevent stale async writes after reset
    private var generation: Int = 0

    // MARK: - Callbacks (set by GameViewModel)

    /// Called after a match pair is removed. Passes the two matching tiles.
    var onMatchFound: ((_ tile1: Tile, _ tile2: Tile) -> Void)?

    /// Called when a 5th tile tries to enter a full shelf (game over trigger).
    var onShelfOverflow: (() -> Void)?

    // MARK: - Computed

    /// Number of tiles currently on the shelf.
    var count: Int { slots.compactMap { $0 }.count }

    /// True if all 4 slots are occupied.
    var isFull: Bool { count == 4 }

    // MARK: - Public API

    /// Add a tile to the shelf. Triggers match detection, overflow, or standard slot fill.
    /// Returns true if accepted, false if overflow/rejected.
    @discardableResult
    func addTile(_ tile: Tile) -> Bool {
        // Overflow guard — all 4 slots occupied and no match animation is clearing space
        let effectiveCount = slots.compactMap { $0 }.filter { !matchingTileIDs.contains($0.id) }.count
        if effectiveCount >= 4 {
            triggerOverflow()
            return false
        }

        // Place tile in first available slot, or into a slot being cleared by a match animation
        let emptyIndex: Int
        if let nilIndex = slots.firstIndex(where: { $0 == nil }) {
            emptyIndex = nilIndex
        } else if let animatingIndex = slots.firstIndex(where: { $0 != nil && matchingTileIDs.contains($0!.id) }) {
            emptyIndex = animatingIndex
        } else {
            triggerOverflow()
            return false
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            slots[emptyIndex] = tile
        }
        insertionLog.append(tile)
        SoundService.shared.play("tile_select")
        HapticService.impact(.light)

        // Check for a match with any existing shelf tile
        checkForMatch(newTile: tile, atIndex: emptyIndex)
        return true
    }

    /// Remove the tile at a specific slot index (e.g. for undo).
    func removeTile(at index: Int) {
        guard index < 4 else { return }
        if let tile = slots[index] {
            insertionLog.removeAll(where: { $0.id == tile.id })
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            slots[index] = nil
        }
    }

    /// Remove a tile by its ID (e.g. when undoing from GameViewModel).
    @discardableResult
    func removeTile(id: UUID) -> Tile? {
        guard let index = slots.firstIndex(where: { $0?.id == id }) else { return nil }
        let tile = slots[index]
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            slots[index] = nil
        }
        insertionLog.removeAll(where: { $0.id == id })
        matchingTileIDs.remove(id)
        return tile
    }

    /// Restore two matched tiles back to the shelf after an undo.
    func restoreMatchedTiles(_ tile1: Tile, _ tile2: Tile) {
        var tilesToRestore = [tile1, tile2]
        for i in 0..<slots.count {
            if slots[i] == nil, let nextTile = tilesToRestore.popLast() {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    slots[i] = nextTile
                }
                insertionLog.append(nextTile)
            }
        }
    }

    /// Restore a single tile back to the shelf.
    func restoreTileToShelf(_ tile: Tile) {
        for i in 0..<slots.count {
            if slots[i] == nil {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    slots[i] = tile
                }
                insertionLog.append(tile)
                break
             }
         }
    }

    /// Clear all slots (new game / revive).
    func reset() {
        generation += 1
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            slots = Array(repeating: nil, count: 4)
        }
        matchingTileIDs = []
        insertionLog = []
    }

    // MARK: - Private

    private func triggerOverflow() {
        onShelfOverflow?()
        HapticService.notification(.error)
        SoundService.shared.play("deadlock")
    }

    private func checkForMatch(newTile: Tile, atIndex newIndex: Int) {
        // Scan ALL shelf pairs (not just new tile vs existing) so that any two matching
        // tiles — regardless of when or in what order they arrived — are always resolved.
        let occupiedSlots: [(index: Int, tile: Tile)] = slots.enumerated().compactMap { i, t in
            guard let t, !matchingTileIDs.contains(t.id) else { return nil }
            return (i, t)
        }

        for i in 0..<occupiedSlots.count {
            for j in (i + 1)..<occupiedSlots.count {
                let a = occupiedSlots[i]
                let b = occupiedSlots[j]
                guard tilesMatch(a.tile, b.tile) else { continue }

                // Found a matching pair — flash both then remove
                matchingTileIDs.insert(a.tile.id)
                matchingTileIDs.insert(b.tile.id)

                let idxA = a.index
                let idxB = b.index

                let currentGen = self.generation
                let task = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled, self.generation == currentGen else { return }
                    
                    // Verify both tiles are still present in their expected slots
                    guard self.slots[idxA]?.id == a.tile.id && self.slots[idxB]?.id == b.tile.id else {
                        self.matchingTileIDs.remove(a.tile.id)
                        self.matchingTileIDs.remove(b.tile.id)
                        return
                    }

                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        slots[idxA] = nil
                        slots[idxB] = nil
                    }
                    matchingTileIDs.remove(a.tile.id)
                    matchingTileIDs.remove(b.tile.id)
                    insertionLog.removeAll(where: { $0.id == a.tile.id || $0.id == b.tile.id })
                    SoundService.shared.play("tile_match")
                    HapticService.impact(.medium)
                    
                    let existing = (a.tile.id == newTile.id) ? b.tile : a.tile
                    onMatchFound?(existing, newTile)
                }
                activeTasks.append(task)
                return  // Only resolve one pair per placement; re-check on next add
            }
        }

        // No match found anywhere on the shelf.
        // Only trigger overflow if shelf is truly full with no animation in flight.
        if isFull {
            let currentGen = self.generation
            let task = Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled, self.generation == currentGen else { return }
                guard self.isFull else { return }
                guard matchingTileIDs.isEmpty else { return }
                if !hasMatchOnShelf() {
                    triggerOverflow()
                }
            }
            activeTasks.append(task)
        }
    }

    /// Returns true if any two tiles currently on the shelf form a match.
    func hasMatchOnShelf() -> Bool {
        let occupied = slots.compactMap { $0 }
        for i in 0..<occupied.count {
            for j in (i + 1)..<occupied.count {
                if tilesMatch(occupied[i], occupied[j]) { return true }
            }
        }
        return false
    }

    private func tilesMatch(_ a: Tile, _ b: Tile) -> Bool {
        guard a.id != b.id else { return false }
        if a.suit == .flower && b.suit == .flower { return true }
        if a.suit == .season && b.suit == .season { return true }
        return a.suit == b.suit && a.value == b.value
    }
}
