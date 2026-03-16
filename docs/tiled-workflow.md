# Tiled Workflow

This project can run from a Tiled-exported Lua map.

## Files

- Source map (edit in Tiled): `assets/tiled/maps/world.tmj`
- Runtime export (load in game): `assets/tiled/maps/world.lua`
- Main tileset: `assets/tiled/tilesets/roguelike_sheet.tsx`

## Tileset Settings

For `roguelike_sheet.tsx`:

- image: `assets/roguelikeSheet_transparent.png`
- tile size: `16x16`
- spacing: `1`
- margin: `0`
- columns: `57` (derived from image dimensions)

## Export Workflow

1. Edit `assets/tiled/maps/world.tmj` in Tiled.
2. Export as Lua to `assets/tiled/maps/world.lua`.
3. Run game with `Map.preferTiled = true` in `src/world/map.lua`.

Notes:

- `world.lua` is a generated runtime export; do not edit it manually unless you are debugging export content.
- Keep object-layer names stable; loader logic depends on them.

## Loader Conventions

Handled in `src/world/map.lua` and `src/world/tiled_map.lua`.

- Collision tile layer name: `collision` (fallback: `walls`, `blocked`).
- Other tile layers render in layer order.
- Supported object layers:
  - `spawn`
  - `exit`
  - `npcs`
  - `graves`
  - `pickups`
  - `enemies`
  - `warps`
  - `houses`
  - `paths`
  - `barricades`
  - `build_spots`

## Cave-Specific Note

The cave portal warp is defined in the `warps` object layer (`kind = "portal"`).
Procedural cave replacement now targets a destination anchor zone and expands into a connected multi-zone footprint after map load.
