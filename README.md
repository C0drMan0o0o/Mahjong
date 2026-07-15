# 麻将 Mahjong Solitaire

A polished Mahjong Solitaire game for iOS built with SwiftUI. Features a shelf-based twist on classic rules, guaranteed-solvable board generation, a multi-tier hint engine, and 50 progressively unlocked levels — all rendered with tactile animations and synthetic audio feedback.

---

## Screenshots

> _Screenshots coming soon. Run the app in Xcode Simulator targeting any iPhone to preview._

---

## Features

### Core Gameplay
- **Shelf-mode rules (Vita Mahjong style)** — instead of directly matching two free tiles, you tap tiles to send them to a 4-slot shelf. Pairs that land on the shelf together auto-clear with a flash animation. The shelf overflowing (5th tile with no match) triggers game over.
- **72-tile compact layout** (36 pairs) across 4 stacked layers. The pyramid-style board uses a half-unit grid coordinate system so tile boundaries are pixel-precise.
- **7 tile suits** with authentic symbols and colors:
  - Characters (万, red) — values 1–9
  - Circles (①–⑨, navy) — values 1–9
  - Bamboo (🎋, green) — values 1–9
  - Winds (東南西北, dark) — 4 tiles
  - Dragons (中發白, suit colors) — 3 tiles
  - Flowers (🌸🌺🌻🌹, purple) — 2 tiles per game; any flower matches any flower
  - Seasons (🌱☀️🍂❄️, purple) — 2 tiles per game; any season matches any season

### Level System
- **50 levels** with sequential unlock progression
- Levels share the same board layout but get a fresh guaranteed-solvable tile assignment each play
- Best score and best time tracked per level; completed levels show a ⭐ in the level grid
- Continue button always resumes the last played level

### Guaranteed-Solvable Generation
The `LevelGenerator` builds boards via **reverse construction**: it simulates removing all 36 pairs in a legal order (always picking the pair whose removal maximises the remaining free-tile count), then assigns tile values to positions in that order. Up to 20 attempts are made; the board is only returned when a full winning sequence exists.

The 36-pair deck is: 27 numbered suit pairs (Characters, Circles, Bamboo 1–9) + 4 Wind pairs + 3 Dragon pairs + 1 Flower pair + 1 Season pair. Flowers and seasons use group-match semantics — any two flower tiles match regardless of which specific flower emoji they show, and likewise for seasons.

Post-shuffle, adjacent free tiles that already match are separated by a targeted swap pass (up to 40 iterations) so the board never looks pre-solved after a shuffle.

### Tools
| Tool | Uses | Behavior |
|------|------|----------|
| Hint 💡 | 3 per game | Highlights the best move; costs 50 points. Auto-clears after 4 s |
| Undo ↩️ | 5 per game | Reverses the last board match, shelf send, or shelf match atomically |
| Shuffle 🔀 | 5 per game | Returns shelf tiles to the board and re-deals all active tiles; repairs pairs |
| Revive | 3 per game | On shelf overflow: returns the last 3 shelf tiles to the board. On no-moves: grants a free shuffle |

### Hint Engine (4 tiers)
1. **Shelf match** — a free board tile completes a pair with a tile already on the shelf
2. **Shelf blocker path** — a blocked tile matches a shelf tile; the free blocker in front is highlighted orange
3. **Free pair** — two free board tiles that match each other
4. **Board blocker path** — a blocked tile has a free match partner; the closest free blocker is highlighted

### Scoring
- Base 100 points per matched pair
- **Combo multiplier**: ×1.5 for 3–4 consecutive matches within 3 seconds, ×2.0 for 5+ consecutive
- Time penalty on victory: `score − (elapsedSeconds × 2)`, counted down step-by-step
- Hint usage deducts 50 points

### Animations & Feedback
- Spring-physics tile entrance, selection scale pop, and shrink-to-zero removal
- Hint pulse: gold glow for match tiles, orange glow for blockers
- Shelf tile chip flash and scale pulse on match
- Shake animation when tapping a blocked tile
- Haptic feedback at three intensity levels (light, medium, heavy) and notification patterns
- Synthetic audio generated entirely in-process via `AVAudioEngine` (no bundled audio files) — distinct tones for select, match, lock, victory, and deadlock

### Settings
- Sound effects toggle
- Background music toggle
- Haptic feedback toggle
- Tile theme: Classic (warm linen), Dark, Minimal
- Dim blocked tiles option
- Lifetime stats: games played, pairs matched

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI framework | SwiftUI |
| State management | `@MainActor` ObservableObject (`GameViewModel`, `ShelfViewModel`) |
| Concurrency | Swift async/await + `Task.detached` for off-thread board generation |
| Audio | AVFoundation — `AVAudioPlayer` with PCM WAV data generated at runtime |
| Persistence | `UserDefaults` via `PersistenceService` (scores, settings, stats) |
| Haptics | UIKit `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` |
| Minimum deployment | iOS 26.5 |

### Architecture

```
Mahjong/
├── Models/
│   ├── Tile.swift          # Tile value type; occupiedCols/Rows overlap logic
│   ├── TileType.swift      # TileSuit enum + TileDefinition catalog (symbols, colors)
│   ├── BoardLayout.swift   # Classic 72-tile layout (4 layers, half-unit grid)
│   └── BoardOccupancy.swift# Shared free-tile rule used by GameViewModel and LevelGenerator
├── ViewModels/
│   ├── GameViewModel.swift # @MainActor orchestrator: selection, hints, undo, shuffle, scoring
│   └── ShelfViewModel.swift# 4-slot shelf: add, match detection, overflow, undo restore
├── Views/
│   ├── MainMenuView.swift  # Level grid, continue button, animated drifting tile background
│   ├── GameView.swift      # HUD, board, shelf, toolbar, pause/gameover/victory overlays
│   ├── GameBoardView.swift # Tile layout using GeometryReader + absolute positioning
│   ├── TileView.swift      # 3D slab tile, hint glow, shake modifier
│   ├── ShelfView.swift     # TileShelfView + SlotView + TileChipView
│   ├── LevelCompleteView.swift # Victory screen with score, time, next level
│   └── SettingsView.swift  # Audio, haptics, theme, stats
└── Services/
    ├── LevelGenerator.swift    # Reverse-construction guaranteed-solvable board
    ├── PersistenceService.swift# UserDefaults wrapper for progress and settings
    └── SoundService.swift      # Runtime PCM tone synthesis via AVAudioPlayer
```

The app follows a clean MVVM separation. `GameViewModel` owns the canonical `[Tile]` array and is the single source of truth. `ShelfViewModel` is a child owned by `GameViewModel`, communicating upward via callbacks (`onMatchFound`, `onShelfOverflow`). All state mutations happen on `@MainActor`; board generation is dispatched to a detached task and merged back on the main actor.

---

## Build & Run

### Requirements
- Xcode 26 or later
- iOS 26.5 SDK (see `IPHONEOS_DEPLOYMENT_TARGET` in `Mahjong.xcodeproj/project.pbxproj` for the exact minimum)
- A real device or iOS Simulator

### Steps

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd Mahjong
   ```

2. Open the project in Xcode:
   ```bash
   open Mahjong.xcodeproj
   ```

3. Select a simulator or connected device from the scheme picker at the top of Xcode.

4. Press **⌘R** (Product → Run) to build and launch.

No third-party dependencies or package manager setup is required — the project has zero external dependencies.

---

## Gameplay Instructions

### Objective
Clear all 72 tiles from the board by matching them in pairs through the shelf.

### How to play
1. Tap any **free tile** (one not covered by another tile and open on at least its left or right side) to send it to your shelf.
2. When two matching tiles land on the shelf, they flash gold and disappear — scoring you points.
3. Clear all tiles from both the board and the shelf to win the level.

### Free tile rules
A tile is **free** when:
- Nothing is stacked on top of it, **and**
- At least one horizontal side (left or right) is unobstructed by a same-layer neighbor.

Blocked tiles show a dark overlay. Tapping a blocked tile causes it to shake.

### Matching rules
| Suit | Match condition |
|------|----------------|
| Characters, Circles, Bamboo | Same suit **and** same number |
| Winds | Same direction (East matches East, etc.) |
| Dragons | Same dragon (中 matches 中, etc.) |
| Flowers | Any flower matches any flower |
| Seasons | Any season matches any season |

### Shelf strategy
- The shelf holds **4 tiles**. Filling it with no matching pair triggers game over.
- Plan ahead: avoid sending tiles to the shelf that have no partner visible on the board.
- Use the **hint** when stuck — it will point you to the most immediately actionable move.

### Tools
- **Hint 💡** — costs 50 points; shows glowing tiles for up to 4 seconds.
- **Undo ↩️** — reverses your last action (send to shelf, board match, or shelf match).
- **Shuffle 🔀** — re-deals all remaining tiles. Shelf is cleared first. Use when deadlocked.
- **Revive** — available on game over; returns shelf tiles to the board or grants a free shuffle.

---

## Project Structure Overview

```
Mahjong.xcodeproj/     Xcode project file
Mahjong/
├── MahjongApp.swift   App entry point (@main), launches MainMenuView directly
├── Assets.xcassets/   App icon (custom mahjong tile SVG) + accent color
├── Models/            Pure value types: Tile, TileType, BoardLayout, BoardOccupancy
├── ViewModels/        ObservableObjects: GameViewModel, ShelfViewModel
├── Views/             SwiftUI views for every screen and component
└── Services/          LevelGenerator, PersistenceService, SoundService
```
