# Documentation Hub

This folder contains contributor-facing documentation for architecture, workflows, and cave-generation tuning.

## Recommended Reading Order

1. `docs/code-layout.md`
2. `docs/tiled-workflow.md`
3. `docs/procedural-cave.md`

## Document Guide

- `docs/code-layout.md`
  - High-level map of core modules and responsibilities.
  - Best starting point for new contributors and agents.

- `docs/tiled-workflow.md`
  - How to edit/export maps from Tiled.
  - Tileset settings and object-layer loader conventions.

- `docs/procedural-cave.md`
  - Cave generation flow and retry/fallback behavior.
  - Wall-thickness and corner-spacing rules.
  - Cave autotile and flagged GID rotation notes.
  - Debug/testing and cave-entrance troubleshooting.

## Quick Notes

- Keep geometry logic (`src/world/dungeon/generator.lua`) separate from cave art logic (`src/world/dungeon/apply.lua`).
- If cave entrance behavior regresses, check cave procgen apply/fallback behavior before changing warp data.
