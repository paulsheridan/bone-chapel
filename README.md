# Bonewright: Necromancer's Burden

A small top-down 2D ARPG prototype built with Love2D.

You play a necromancer exploring a dungeon to recover body parts, stitch together a monster, and designate control of that monster to break through obstacles she cannot clear alone.

This build uses a classic 90s handheld-inspired multi-zone layout with screen-panning transitions between areas.

The game now renders at a fixed logical resolution and scales with the window size, so resizing enlarges the same view instead of revealing more world area.

## Requirements

- Love2D 11.x

## Run

```bash
love .
```

## Controls

- `WASD`: Move controlled character
- `J` or `Space`: Attack in facing direction
- `E`: Interact (town NPCs, graves)
- `Tab`: Open/close Stitching Table (build menu)
- `1-6`: Select body slot in menu
- `Up/Down`: Select part in menu list
- `Enter`: Equip selected part to selected slot
- `A`: Assemble monster (in menu)
- `Q`: Designate/swap control between necromancer and monster
- `F3`: Toggle debug overlay
- `F4`: Toggle NPC pathfinding path lines
- `F5`: Toggle NPC line-of-sight debug rays
- `R`: Restart after win/lose

## Core Mechanics Included

- Body-part scavenging with six slots:
  - Head, Torso, Left Arm, Right Arm, Left Leg, Right Leg
- Slot-based stat assembly for monster:
  - Speed, Strength, Health
- Part traits now apply real combat modifiers (bleed, cooldown, barricade damage, mitigation, range)
- Set bonuses activate for specific body-part combinations
- Enemies now spawn as archetypes (brute, hunter, skirmisher) with distinct stats and behavior
- Enemy kills drop relic gear (armor, tools, weapons) that auto-equip and further alter monster behavior
- Ritual tether stability drains while controlling distant monster bodies and recovers while grounded
- Monster control designation with necromancer left static and vulnerable
- NPC line-of-sight checks using grid ray casting
- NPC pathfinding with A* over the dungeon tile grid
- Enemy state behavior (patrol, chase, search, attack)
- Dungeon gate via breakable barricade requiring monster strength
- Zone-based camera with side/top/bottom screen pan transitions
- Outdoor overworld with town, graveyard digging, and hostile woods
- Touch-triggered cave portal circles and house doors
- Portrait dialogue boxes for town NPC interactions
- Timed grave-digging action with shovel animation
- Expanded multi-zone town (north/center/south) plus hill-town above the graveyard
- Wide-open overworld transitions between town, graveyard, field, and forest
- Ground trail decals guiding travel toward the woods and cave

## Code Layout

- `src/game.lua`: high-level game orchestration and state flow
- `src/core/math2d.lua`: shared clamp/distance/normalization helpers
- `src/core/movement.lua`: shared collision-aware movement helper
- `src/systems/camera.lua`: zone camera tracking and screen-pan transitions
- `src/systems/combat.lua`: attacks, weapon visuals, and cooldown handling
- `src/systems/enemies.lua`: enemy spawning, AI states, pathing, and contact damage
- `src/systems/interactions.lua`: NPC dialogue, digging, and touch warps
- `src/systems/player.lua`: player movement/facing/attack input handling
- `src/systems/rendering.lua`: world/entity/HUD rendering
- `src/world/world_gen.lua`: terrain/layout generation and interior construction
- `src/world/world_population.lua`: NPC/loot/enemy/warp placement
- `src/world/world_render.lua`: map-layer rendering helpers
- `src/world/world_helpers.lua`: shared world-construction primitives

## Tiled Setup

- Tileset configured at `assets/tiled/tilesets/roguelike_sheet.tsx` using:
  - image: `assets/roguelikeSheet_transparent.png`
  - tile size: `16x16`
  - spacing: `1`
  - margin: `0`
  - columns: `57` (auto-derived from image dimensions)
- Edit map source in Tiled using `assets/tiled/maps/world.tmj`.
- Export maps from Tiled as **Lua** to `assets/tiled/maps/world.lua`.
- Note: `world.lua` is a runtime export and is not meant to be opened directly in Tiled.
- To run the game from a Tiled map, set in `src/world/map.lua`:
  - `Map.preferTiled = true`
- A generated starter map exists at `assets/tiled/maps/world.lua` that recreates a simple version of the current world layout.
- Tiled loader conventions:
  - Tile layer named `collision` (or `walls` / `blocked`) marks solid tiles
  - Other tile layers are rendered in order
  - Object layers supported: `spawn`, `exit`, `npcs`, `graves`, `pickups`, `enemies`, `warps`, `houses`, `paths`, `barricades`
