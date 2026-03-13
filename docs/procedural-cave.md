# Procedural Cave Generation

This doc is for future contributors and coding agents working on cave generation and cave tile behavior.

## Entry Point and Flow

- Cave generation starts from `src/world/map.lua`.
- `Map.load()` calls `Dungeon.applyProceduralCave(...)` when procedural cave support is enabled.
- Core flow in `src/world/dungeon.lua`:
  - `Generator.generate(...)`
  - `Populate.generate(...)`
  - `Validate.check(...)`
  - `Apply.apply(...)`

## Retry and Fallback Behavior

- `Config.maxAttempts` controls candidate attempts.
- Strictly valid cave candidates are preferred.
- If no strict corner-spacing candidate passes after all attempts, the best validated fallback candidate is applied.
- This preserves cave entrance usability and avoids total procgen failure during tuning.

## Separation of Concerns

- Geometry decisions are in `src/world/dungeon/generator.lua` and `src/world/dungeon/validate.lua`.
- Art/autotile decisions are in `src/world/dungeon/apply.lua` with palette values configured in `src/world/map.lua`.
- Keep these concerns separate when making changes.

## Wall Rules and Current Defaults

Two different rule sets are active and should not be conflated:

- Wall thickness (`config.wallThickness` in `src/world/dungeon/config.lua`):
  - `minVertical = 3`
  - `minHorizontal = 2`
  - `passes = 1`

- Corner spacing (`config.cornerSpacing` in `src/world/dungeon/config.lua`):
  - `minStraightBetweenCorners = 2`
  - Enforced by counting short edge runs in `enforceMinStraightWalls(...)`
  - No carve-based mutation for spacing (count/score only)

## Corner-Spacing Enforcement Notes

- Logic lives in `src/world/dungeon/generator.lua`.
- The check scans top/bottom/left/right wall-edge runs and counts violations.
- It records metadata on each layout:
  - `cornerSpacingViolations`
  - `cornerSpacingAllowedViolations`
  - `cornerSpacingPassed`
- The orchestration layer uses this metadata to pick strict-first, then best fallback.

## Cave Tile and Rotation Notes

- Cave floor/wall tile selection (including walkable detail behavior) is in `src/world/dungeon/apply.lua`.
- Some cave detail orientation uses Tiled flip flags on GIDs (rotation via flags, not separate tile IDs).
- `src/world/tiled_map.lua` must preserve and render flagged GIDs correctly.

## Debug and Testing

- `F3`: debug overlay (shows cave procgen seed/attempts).
- `F6`: enemy suppression toggle for calmer cave testing.
- Standard smoke check:

```bash
love .
```

## Troubleshooting Cave Entrance Issues

If cave entrance behavior regresses:

1. Confirm cave procgen is still applying in `src/world/dungeon.lua`.
2. Confirm fallback selection still applies a validated layout when strict spacing fails.
3. Only then inspect warp object definitions in the Tiled map export.
