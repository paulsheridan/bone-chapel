# Character Sprite Integration Notes

This project now uses `assets/Characters.png` for animated character sprites for:

- player (necromancer)
- enemy variants (`brute`, `hunter`, `skirmisher`)
- friendly NPCs

## Sprite Sheet Layout

- Tile width: `16`
- Tile height: `16`
- Margin: `0`
- Spacing: `1`
- Each character set: `4 x 3` tiles
  - Columns: `left`, `down`, `up`, `right`
  - Rows: idle/top frame then 2 walk frames

Animation sequence used while moving is:

- `1, 2, 1, 3` (loop)

When not moving, frame `1` is used.

## Rendering System

Core sprite rendering and quad generation lives in:

- `src/systems/rendering.lua`

Key details:

- Characters are drawn from quads generated per set index.
- Shared draw scale is currently `2x`.
- Direction is read from `entity.spriteFacing`.
- Frame is read from `entity.spriteFrame`.

Current set mapping:

- Player (necromancer): set `6` (bottom set)
- Enemies:
  - `brute` -> set `1`
  - `hunter` -> set `2`
  - `skirmisher` -> set `3`
- Friendly NPC defaults: alternating set `4` and `5`

## Player Animation State

Player animation state is updated in:

- `src/systems/player.lua`

Fields maintained on the controlled entity:

- `spriteFacing`
- `spriteAnimStep`
- `spriteAnimTimer`
- `spriteMoving`
- `spriteFrame`

Diagonal movement behavior for facing:

- Horizontal input takes priority (left/right), per requested behavior.

## Enemy Animation State

Enemy animation state is updated in:

- `src/systems/enemies.lua`

Movement deltas are measured each update and used to drive:

- direction (`spriteFacing`)
- walk cycle (`spriteFrame` via `1,2,1,3`)
- idle reset (`frame 1`)

## Friendly NPC Foundation (Movement-Ready)

Friendly NPC updates are now centralized in:

- `src/systems/npcs.lua`

Called from:

- `src/game.lua` via `Npcs.updateAll(Game, dt)`

NPCs now have structure for future movement systems:

- `behavior` (default `"idle"`)
- `moveIntentX`, `moveIntentY`
- `moveTargetX`, `moveTargetY`
- `route`, `routeIndex`
- `velocityX`, `velocityY`

These are already wired so that adding route or random movement later only requires setting intent/targets/route data.

## NPC Data Fields (Map + Tiled)

NPC defaults are initialized in:

- `src/world/map.lua` (Tiled-loaded NPCs)
- `src/world/world_helpers.lua` (procedural/static placement)

Supported NPC sprite-related fields:

- `spriteSet` (character set index)
- `spriteFacing` (`left`, `down`, `up`, `right`)
- `radius`
- `speed`

### Tiled Usage

On an object in the `npcs` object layer, add optional properties:

- `spriteSet` (number, e.g. `4`)
- `spriteFacing` (string, e.g. `down`)
- `radius` (number)
- `speed` (number)

If omitted, defaults are applied automatically.

## Non-Tiled/Fallback Rendering Change

Legacy circle rendering for NPCs was removed from:

- `src/world/world_render.lua`

This prevents duplicate NPC drawing and keeps all character sprite rendering in one place (`src/systems/rendering.lua`).
