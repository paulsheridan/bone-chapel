local Helpers = require("src.world.world_helpers")

local WorldGen = {}

WorldGen.config = {
  zoneWidthTiles = 34,
  zoneHeightTiles = 22,
  zonesX = 4,
  zonesY = 4,
}

function WorldGen.createEmptyMap()
  local map = {
    zoneWidthTiles = WorldGen.config.zoneWidthTiles,
    zoneHeightTiles = WorldGen.config.zoneHeightTiles,
    zonesX = WorldGen.config.zonesX,
    zonesY = WorldGen.config.zonesY,
    tiles = {},
    pickups = {},
    enemies = {},
    barricades = {},
    npcs = {},
    graves = {},
    warps = {},
    paths = {},
    start = { x = 64, y = 64 },
    exit = nil,
  }

  map.width = map.zoneWidthTiles * map.zonesX
  map.height = map.zoneHeightTiles * map.zonesY
  for y = 1, map.height do
    map.tiles[y] = {}
    for x = 1, map.width do
      map.tiles[y][x] = "floor"
    end
  end

  return map
end

function WorldGen.applyTerrain(map, tileSize, tileToWorld)
  for zy = 1, map.zonesY do
    for zx = 1, map.zonesX do
      Helpers.carveRoom(map, zx, zy)
    end
  end

  Helpers.carveZoneConnections(map)

  Helpers.setWallRectZone(map, 1, 1, 24, 14, 27, 16)
  Helpers.setWallRectZone(map, 1, 3, 23, 6, 25, 8)
  Helpers.setWallRectZone(map, 2, 2, 16, 5, 18, 7)
  Helpers.setWallRectZone(map, 3, 2, 8, 15, 13, 17)
  Helpers.setWallRectZone(map, 4, 2, 13, 6, 16, 9)
  Helpers.setWallRectZone(map, 4, 2, 22, 13, 26, 15)
  Helpers.setWallRectZone(map, 2, 3, 12, 7, 15, 9)
  Helpers.setWallRectZone(map, 3, 3, 17, 12, 20, 15)

  Helpers.fillZone(map, 1, 1, "floor")
  Helpers.fillZone(map, 1, 2, "floor")
  Helpers.fillZone(map, 1, 3, "floor")
  Helpers.fillZone(map, 2, 1, "floor")
  Helpers.fillZone(map, 2, 2, "floor")

  -- Town and hill-town are open, but primary structures are solid.
  Helpers.setWallRectZone(map, 1, 1, 7, 5, 12, 9)
  Helpers.setWallRectZone(map, 1, 2, 17, 7, 23, 12)
  Helpers.setWallRectZone(map, 1, 3, 9, 9, 15, 14)
  Helpers.setWallRectZone(map, 2, 1, 11, 8, 18, 13)

  Helpers.carveZoneConnections(map)

  local i1x, i1y = Helpers.buildInterior(map, 1, 4, 12, 8)
  local i2x, i2y = Helpers.buildInterior(map, 2, 4, 12, 8)
  local i3x, i3y = Helpers.buildInterior(map, 3, 4, 12, 8)
  local i4x, i4y = Helpers.buildInterior(map, 4, 4, 12, 8)

  Helpers.setWallRectZone(map, 1, 4, i1x + 1, i1y + 1, i1x + 2, i1y + 2)
  Helpers.setWallRectZone(map, 2, 4, i2x + 8, i2y + 2, i2x + 9, i2y + 3)
  Helpers.setWallRectZone(map, 3, 4, i3x + 2, i3y + 4, i3x + 3, i3y + 5)
  Helpers.setWallRectZone(map, 4, 4, i4x + 5, i4y + 1, i4x + 6, i4y + 2)

  local function doorWarp(hzx, hzy, dlx, dly, izx, izy, ilx, ily, inLabel, outLabel)
    Helpers.addWarp(map, tileToWorld, hzx, hzy, dlx, dly, izx, izy, ilx, ily, inLabel, "door")
    Helpers.addWarp(map, tileToWorld, izx, izy, ilx, ily, hzx, hzy, dlx, dly + 2, outLabel, "door")
  end

  doorWarp(1, 1, 10, 10, 1, 4, i1x + 6, i1y + 6, "You step inside the cottage.", "You step back outside.")
  doorWarp(1, 2, 20, 13, 2, 4, i2x + 6, i2y + 6, "You enter the lamplit home.", "You step back outside.")
  doorWarp(1, 3, 12, 15, 3, 4, i3x + 6, i3y + 6, "You duck into the tanner's house.", "You step back outside.")
  doorWarp(2, 1, 15, 14, 4, 4, i4x + 6, i4y + 6, "You enter the hill chapel.", "You step back outside.")

  Helpers.addPathRect(map, tileSize, 2, 2, 1, 10, 34, 4)
  Helpers.addPathRect(map, tileSize, 3, 2, 1, 10, 34, 4)
  Helpers.addPathRect(map, tileSize, 4, 2, 1, 10, 20, 4)

  local sTx, sTy = Helpers.zoneTile(map, 1, 2, 6, 11)
  map.start = tileToWorld(sTx, sTy)

  return {
    interiors = {
      { zx = 1, zy = 4, lx = i1x, ly = i1y },
      { zx = 2, zy = 4, lx = i2x, ly = i2y },
      { zx = 3, zy = 4, lx = i3x, ly = i3y },
      { zx = 4, zy = 4, lx = i4x, ly = i4y },
    },
  }
end

return WorldGen
