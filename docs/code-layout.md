# Code Layout

This document maps major Lua modules to their responsibilities.

## Runtime Entry

- `main.lua`: Love2D callbacks and top-level bootstrapping.
- `src/game.lua`: game state orchestration, update loop, input routing, and high-level gameplay flow.

## Core Utilities

- `src/core/math2d.lua`: clamp, normalize, distance helpers.
- `src/core/movement.lua`: shared movement and collision-aware stepping.
- `src/core/display.lua`: logical resolution helpers.

## Systems

- `src/systems/camera.lua`: zone tracking and screen-pan transitions.
- `src/systems/combat.lua`: attacks, cooldowns, and combat interactions.
- `src/systems/enemies.lua`: enemy creation, AI, movement, and behaviors.
- `src/systems/interactions.lua`: interactions, digging, and warp touch handling.
- `src/systems/player.lua`: controlled-entity movement and attack input.
- `src/systems/rendering.lua`: world rendering, HUD, and debug overlay.
- `src/systems/monster_mods.lua`: monster stat projection from parts/gear.

## World and Map

- `src/world/map.lua`: map loading path selection and world/tile helper functions.
- `src/world/tiled_map.lua`: Tiled Lua loader, layer/object access, draw pipeline, and flagged GID flip/rotation support.
- `src/world/world_gen.lua`: non-Tiled world generation.
- `src/world/world_population.lua`: non-procgen population placement.
- `src/world/world_render.lua`: non-Tiled world drawing helpers.
- `src/world/world_helpers.lua`: world construction utilities.
- `src/world/pathfinding.lua`: grid pathfinding helpers.

## Procedural Cave Modules

- `src/world/dungeon.lua`: cave orchestration (generate -> populate -> validate -> apply) with retries.
- `src/world/dungeon/config.lua`: cave tuning knobs.
- `src/world/dungeon/generator.lua`: room/corridor geometry and wall-rule checks.
- `src/world/dungeon/populate.lua`: enemy/pickup placement for generated cave zone.
- `src/world/dungeon/validate.lua`: reachability and minimum-floor checks.
- `src/world/dungeon/apply.lua`: cave tile painting/autotile decisions and in-zone content replacement.
