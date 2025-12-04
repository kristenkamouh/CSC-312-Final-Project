# Shooter Game Enhancement Plan

## Current State (f16.asm)
- Background copied to framebuffer at startup, then redrawn each frame to clear artifacts.
- Player position stored in `$s0`/`$s1`; moves via `WASD` handling in the keyboard MMIO loop and stays within 128x128 bounds.
- Player fires a single yellow bullet to the right when inactive flag `$s2` is clear; bullet advances each frame and deactivates off-screen.
- Three vertically oscillating green enemies with fixed x-positions; each tracks its own bullet activation/counters and periodically fires a single blue bullet to the left.
- Rendering performed via `draw_block` helper for player, bullets, and enemies; frame pacing achieved with a short sleep syscall in the main loop.

## Goals
Add audiovisual feedback and basic game progression while preserving the existing 128x128 framebuffer architecture.

## Planned Features and Steps

### 1) Sprite Improvements
- Increase player/enemy sprite sizes (e.g., 4x4 or 5x5) and adjust draw calls so hitboxes match visuals.
- Consider multi-color sprites by layering several `draw_block` calls or by adding per-pixel data tables.
- Keep movement bounds in sync with new sprite dimensions to prevent off-screen drawing.

### 2) Collision Detection
- Implement bullet vs. enemy intersection: compare player bullet coordinates (and size) against each enemy area before bullet update/deactivation.
- Implement enemy bullet vs. player intersection: check each active enemy bullet against the player’s bounds.
- Centralize collision checks in the main loop after position updates but before rendering to avoid flicker.

### 3) Scoring and Lives
- Add `.word` storage for score and remaining lives; initialize during game state setup.
- Increment score when an enemy is hit; deactivate the enemy bullet or mark the enemy as destroyed if desired.
- Decrement lives when the player is hit; clamp at zero and trigger game-over flow when exhausted.
- Consider on-screen HUD: draw small numeric or bar indicators using colored blocks or a simple bitmap font.

### 4) Audio Feedback (Syscalls)
- Use SPIM/MARS audio syscalls for distinct events: player hit, enemy hit, firing, and game over.
- Store sound IDs/constants near the data section and call the audio syscall at the collision or firing points.

### 5) Game States and Screens
- Add state variables for `welcome`, `playing`, and `game_over`.
- In `welcome`, render a static title screen, wait for a key (e.g., `ENTER`) to start, and reset score/lives.
- In `game_over`, display results and wait for restart/quit input.
- Only run movement/shooting logic while in `playing` state.

### 6) Reset and Cleanup Utilities
- Provide a routine to reset player position, bullets, enemy positions/counters, score, and lives when starting a new game.
- Optionally add a timer or difficulty ramp (faster bullets/enemies) using the existing counters.

### 7) Testing Notes
- Verify collisions at sprite corners (edge cases) after resizing sprites.
- Confirm bullets deactivate correctly on hits and when leaving the screen.
- Exercise audio syscalls in the simulator environment to ensure availability and volume levels.
