local Helpers = {}

function Helpers.zoneTile(map, zx, zy, lx, ly)
  local tx = (zx - 1) * map.zoneWidthTiles + lx
  local ty = (zy - 1) * map.zoneHeightTiles + ly
  return tx, ty
end

function Helpers.setWallRect(map, x1, y1, x2, y2)
  for ty = y1, y2 do
    for tx = x1, x2 do
      if tx >= 1 and ty >= 1 and tx <= map.width and ty <= map.height then
        map.tiles[ty][tx] = "wall"
      end
    end
  end
end

function Helpers.setWallRectZone(map, zx, zy, lx1, ly1, lx2, ly2)
  local x1, y1 = Helpers.zoneTile(map, zx, zy, lx1, ly1)
  local x2, y2 = Helpers.zoneTile(map, zx, zy, lx2, ly2)
  Helpers.setWallRect(map, math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2))
end

function Helpers.fillZone(map, zx, zy, tile)
  local x1 = (zx - 1) * map.zoneWidthTiles + 1
  local y1 = (zy - 1) * map.zoneHeightTiles + 1
  local x2 = x1 + map.zoneWidthTiles - 1
  local y2 = y1 + map.zoneHeightTiles - 1
  for ty = y1, y2 do
    for tx = x1, x2 do
      map.tiles[ty][tx] = tile
    end
  end
end

function Helpers.carveRoom(map, zx, zy)
  local x1 = (zx - 1) * map.zoneWidthTiles + 1
  local y1 = (zy - 1) * map.zoneHeightTiles + 1
  local x2 = x1 + map.zoneWidthTiles - 1
  local y2 = y1 + map.zoneHeightTiles - 1
  Helpers.setWallRect(map, x1, y1, x2, y1)
  Helpers.setWallRect(map, x1, y2, x2, y2)
  Helpers.setWallRect(map, x1, y1, x1, y2)
  Helpers.setWallRect(map, x2, y1, x2, y2)
end

function Helpers.openHorizontalDoor(map, zx, zy)
  local seamX = zx * map.zoneWidthTiles
  local centerY = (zy - 1) * map.zoneHeightTiles + math.floor(map.zoneHeightTiles * 0.5)
  for y = centerY - 2, centerY + 2 do
    map.tiles[y][seamX] = "floor"
    map.tiles[y][seamX + 1] = "floor"
  end
end

function Helpers.openHorizontalSeamWide(map, zx, zy)
  local seamX = zx * map.zoneWidthTiles
  local y1 = (zy - 1) * map.zoneHeightTiles + 2
  local y2 = zy * map.zoneHeightTiles - 1
  for y = y1, y2 do
    map.tiles[y][seamX] = "floor"
    map.tiles[y][seamX + 1] = "floor"
  end
end

function Helpers.openVerticalDoor(map, zx, zy)
  local seamY = zy * map.zoneHeightTiles
  local centerX = (zx - 1) * map.zoneWidthTiles + math.floor(map.zoneWidthTiles * 0.5)
  for x = centerX - 2, centerX + 2 do
    map.tiles[seamY][x] = "floor"
    map.tiles[seamY + 1][x] = "floor"
  end
end

function Helpers.carveZoneConnections(map)
  Helpers.openHorizontalDoor(map, 1, 1)
  Helpers.openHorizontalDoor(map, 2, 1)
  Helpers.openHorizontalDoor(map, 3, 1)
  Helpers.openHorizontalDoor(map, 2, 3)
  Helpers.openHorizontalDoor(map, 3, 3)

  Helpers.openHorizontalSeamWide(map, 1, 2)
  Helpers.openHorizontalSeamWide(map, 2, 2)
  Helpers.openHorizontalSeamWide(map, 3, 2)

  Helpers.openVerticalDoor(map, 1, 1)
  Helpers.openVerticalDoor(map, 1, 2)
  Helpers.openVerticalDoor(map, 2, 1)
end

function Helpers.addPathRect(map, tileSize, zx, zy, lx, ly, w, h)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local x = (tx - 1) * tileSize
  local y = (ty - 1) * tileSize
  table.insert(map.paths, {
    x = x,
    y = y,
    w = w * tileSize,
    h = h * tileSize,
  })
end

function Helpers.addNpc(map, tileToWorld, zx, zy, lx, ly, name, line)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local pos = tileToWorld(tx, ty)
  local npcIndex = #map.npcs + 1
  table.insert(map.npcs, {
    x = pos.x,
    y = pos.y,
    radius = 11,
    speed = 72,
    spriteSet = ((npcIndex - 1) % 2) + 4,
    spriteFacing = "down",
    name = name,
    line = line,
  })
end

function Helpers.addGrave(map, tileToWorld, zx, zy, lx, ly, slot)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local pos = tileToWorld(tx, ty)
  table.insert(map.graves, {
    x = pos.x,
    y = pos.y,
    slot = slot,
    dug = false,
  })
end

function Helpers.addWarp(map, tileToWorld, zx, zy, lx, ly, tzx, tzy, tlx, tly, label, kind)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local ttx, tty = Helpers.zoneTile(map, tzx, tzy, tlx, tly)
  local fromPos = tileToWorld(tx, ty)
  local toPos = tileToWorld(ttx, tty)
  table.insert(map.warps, {
    id = #map.warps + 1,
    fromX = fromPos.x,
    fromY = fromPos.y,
    toX = toPos.x,
    toY = toPos.y,
    label = label,
    kind = kind or "portal",
    radius = 12,
  })
end

function Helpers.placeEnemy(map, tileToWorld, zx, zy, lx, ly, kind)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local pos = tileToWorld(tx, ty)
  table.insert(map.enemies, {
    x = pos.x,
    y = pos.y,
    kind = kind,
  })
end

function Helpers.placePickup(map, tileToWorld, zx, zy, lx, ly, slot)
  local tx, ty = Helpers.zoneTile(map, zx, zy, lx, ly)
  local pos = tileToWorld(tx, ty)
  table.insert(map.pickups, {
    x = pos.x,
    y = pos.y,
    kind = "part",
    slot = slot,
    taken = false,
  })
end

function Helpers.buildInterior(map, zx, zy, roomW, roomH)
  Helpers.fillZone(map, zx, zy, "wall")
  local lx = math.floor((map.zoneWidthTiles - roomW) * 0.5) + 1
  local ly = math.floor((map.zoneHeightTiles - roomH) * 0.5) + 1
  local x1, y1 = Helpers.zoneTile(map, zx, zy, lx, ly)
  local x2, y2 = Helpers.zoneTile(map, zx, zy, lx + roomW - 1, ly + roomH - 1)
  for ty = y1, y2 do
    for tx = x1, x2 do
      map.tiles[ty][tx] = "floor"
    end
  end
  return lx, ly
end

return Helpers
