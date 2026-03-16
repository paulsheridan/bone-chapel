local Apply = {}
local WallRules = require("src.world.dungeon.wall_rules")

local function findTileLayerByName(runtime, name)
  local lname = string.lower(name)
  for _, layer in ipairs(runtime.tilelayers or {}) do
    if string.lower(layer.name or "") == lname then
      return layer
    end
  end
  return nil
end

local function mostCommonKey(counts, allowZero)
  local bestKey
  local bestCount = -1
  for key, count in pairs(counts) do
    if (allowZero or key ~= 0) and count > bestCount then
      bestKey = key
      bestCount = count
    end
  end
  return bestKey
end

local function bump(counts, key)
  counts[key] = (counts[key] or 0) + 1
end

local function detectCaveWarp(map)
  local firstPortal
  for _, warp in ipairs(map.warps or {}) do
    if warp.kind == "portal" then
      if not firstPortal then
        firstPortal = warp
      end
      local label = string.lower(warp.label or "")
      if string.find(label, "cave", 1, true) then
        return warp
      end
    end
  end
  return firstPortal
end

local function inZone(context, x, y)
  local zx, zy = context.getZoneForWorld(context.map, x, y)
  if context.generatedZoneSet then
    return context.generatedZoneSet[zx .. ":" .. zy] == true
  end
  return zx == context.anchorZoneX and zy == context.anchorZoneY
end

local function isWalkable(layout, x, y)
  return x >= 1 and y >= 1 and x <= layout.width and y <= layout.height and not layout.blocked[y][x]
end

local function pickVariant(variants, x, y, fallback)
  if type(variants) ~= "table" or #variants == 0 then
    return fallback
  end
  local idx = ((x * 73856093 + y * 19349663) % #variants) + 1
  return variants[idx]
end

local TILE_FLIP_VERTICAL = 1073741824
local TILE_FLIP_DIAGONAL = 536870912

local function rotateTile270(gid)
  if not gid or gid <= 0 then
    return gid
  end
  return gid + TILE_FLIP_VERTICAL + TILE_FLIP_DIAGONAL
end

local function pickSparseVariant(variants, x, y, fallback, secondaryPct, tertiaryPct)
  if type(variants) ~= "table" or #variants == 0 then
    return fallback
  end

  local base = variants[1] or fallback
  local second = variants[2]
  local third = variants[3]
  if not second then
    return base
  end

  local roll = (x * 12582917 + y * 4256249) % 100
  if third and roll < (tertiaryPct or 4) then
    return third
  end
  if roll < ((secondaryPct or 8) + (tertiaryPct or 4)) then
    return second
  end
  return base
end

local function pickWalkableTile(context, layout, x, y)
  local theme = context.tileTheme
  local floorDetail = theme and theme.floorDetail or nil
  local walkableFloors = theme and theme.walkableFloors or nil

  local walkN = isWalkable(layout, x, y - 1)
  local walkS = isWalkable(layout, x, y + 1)
  local walkW = isWalkable(layout, x - 1, y)
  local walkE = isWalkable(layout, x + 1, y)
  local walkNW = isWalkable(layout, x - 1, y - 1)

  local blockN = not walkN
  local blockS = not walkS
  local blockW = not walkW
  local blockE = not walkE

  if floorDetail then
    if blockN and blockW and not blockE and not blockS then
      return rotateTile270(floorDetail.topLeftCorner or floorDetail.edge or context.floorGid)
    end

    if not blockN and not blockS and not blockW and not blockE and not walkNW then
      return floorDetail.topLeftInset or context.floorGid
    end

    if blockN and not blockS and not blockE and not blockW then
      local roll = (x * 31337 + y * 7331) % 100
      if roll < 12 then
        return floorDetail.edgeAlt or floorDetail.edge or context.floorGid
      end
      return floorDetail.edge or context.floorGid
    end

    if blockW and not blockE and not blockN and not blockS then
      local roll = (x * 31337 + y * 7331) % 100
      local edgeTile = floorDetail.edge or context.floorGid
      if roll < 12 then
        edgeTile = floorDetail.edgeAlt or edgeTile
      end
      return rotateTile270(edgeTile)
    end
  end

  return pickSparseVariant(walkableFloors, x, y, context.floorGid, 2, 0)
end

local function pickWallTile(context, layout, x, y)
  local wallGid = WallRules.pick(context.tileTheme, function(wx, wy)
    return isWalkable(layout, wx, wy)
  end, x, y, context.wallGid)
  return wallGid
end

function Apply.resolveContext(map, helpers, tileTheme)
  if not map or not map.tiled then
    return nil
  end

  local runtime = map.tiled
  local groundLayer = findTileLayerByName(runtime, "ground") or runtime.tilelayers[1]
  local collisionLayer = runtime.collisionLayer or runtime.collisionByName["walls"] or runtime.collisionByName["blocked"]
  if not groundLayer or not collisionLayer then
    return nil
  end

  local clearLayers = {}
  for _, layer in ipairs(runtime.tilelayers or {}) do
    if layer ~= groundLayer and layer ~= collisionLayer then
      table.insert(clearLayers, layer)
    end
  end

  local caveWarp = detectCaveWarp(map)
  if not caveWarp then
    return nil
  end

  local zoneX, zoneY = helpers.getZoneForWorld(map, caveWarp.toX, caveWarp.toY)
  local tx1 = (zoneX - 1) * map.zoneWidthTiles + 1
  local ty1 = (zoneY - 1) * map.zoneHeightTiles + 1
  local tx2 = tx1 + map.zoneWidthTiles - 1
  local ty2 = ty1 + map.zoneHeightTiles - 1

  local entryTx, entryTy = helpers.worldToTile(caveWarp.toX, caveWarp.toY)
  local entryLocalX = entryTx - tx1 + 1
  local entryLocalY = entryTy - ty1 + 1
  if entryLocalX < 1 or entryLocalX > map.zoneWidthTiles or entryLocalY < 1 or entryLocalY > map.zoneHeightTiles then
    entryLocalX = math.max(2, math.floor(map.zoneWidthTiles * 0.5))
    entryLocalY = math.max(2, math.floor(map.zoneHeightTiles * 0.5))
  end

  local floorGroundCounts = {}
  local wallGroundCounts = {}
  local wallCollisionCounts = {}
  for ty = ty1, ty2 do
    for tx = tx1, tx2 do
      local idx = (ty - 1) * map.width + tx
      local groundGid = groundLayer.dataDecoded[idx] or 0
      local collisionGid = collisionLayer.dataDecoded[idx] or 0
      if collisionGid ~= 0 then
        bump(wallGroundCounts, groundGid)
        bump(wallCollisionCounts, collisionGid)
      else
        bump(floorGroundCounts, groundGid)
      end
    end
  end

  local floorGid = mostCommonKey(floorGroundCounts, false) or mostCommonKey(floorGroundCounts, true) or 1
  local wallGid = mostCommonKey(wallGroundCounts, false) or floorGid
  local collisionWallGid = mostCommonKey(wallCollisionCounts, false) or 1
  if tileTheme then
    if tileTheme.floorGid and tileTheme.floorGid > 0 then
      floorGid = tileTheme.floorGid
    end
    if tileTheme.wallGid and tileTheme.wallGid > 0 then
      wallGid = tileTheme.wallGid
    end
  end

  return {
    map = map,
    anchorZoneX = zoneX,
    anchorZoneY = zoneY,
    tx1 = tx1,
    ty1 = ty1,
    tx2 = tx2,
    ty2 = ty2,
    zoneWidth = map.zoneWidthTiles,
    zoneHeight = map.zoneHeightTiles,
    entryLocal = {
      x = entryLocalX,
      y = entryLocalY,
    },
    entryTile = {
      tx = entryTx,
      ty = entryTy,
    },
    floorGid = floorGid,
    wallGid = wallGid,
    collisionWallGid = collisionWallGid,
    tileTheme = tileTheme,
    groundLayer = groundLayer,
    collisionLayer = collisionLayer,
    clearLayers = clearLayers,
    tileToWorld = helpers.tileToWorld,
    getZoneForWorld = helpers.getZoneForWorld,
  }
end

function Apply.apply(context, layout, content)
  local map = context.map
  local groundData = context.groundLayer.dataDecoded
  local collisionData = context.collisionLayer.dataDecoded

  local function shouldPaintTile(tx, ty)
    if not context.generatedZoneSet then
      return tx >= context.tx1 and tx <= context.tx2 and ty >= context.ty1 and ty <= context.ty2
    end
    local zx = math.floor((tx - 1) / map.zoneWidthTiles) + 1
    local zy = math.floor((ty - 1) / map.zoneHeightTiles) + 1
    return context.generatedZoneSet[zx .. ":" .. zy] == true
  end

  for ty = 1, map.height do
    for tx = 1, map.width do
      if shouldPaintTile(tx, ty) then
        local idx = (ty - 1) * map.width + tx
        local lx = tx
        local ly = ty
        if not context.generatedZoneSet then
          lx = tx - context.tx1 + 1
          ly = ty - context.ty1 + 1
        end

        if layout.blocked[ly] and layout.blocked[ly][lx] then
          groundData[idx] = pickWallTile(context, layout, lx, ly)
          collisionData[idx] = context.collisionWallGid
        else
          groundData[idx] = pickWalkableTile(context, layout, lx, ly)
          collisionData[idx] = 0
        end
      end
    end
  end

  for _, layer in ipairs(context.clearLayers or {}) do
    local data = layer.dataDecoded
    if data then
      for ty = 1, map.height do
        for tx = 1, map.width do
          if shouldPaintTile(tx, ty) then
            local idx = (ty - 1) * map.width + tx
            data[idx] = 0
          end
        end
      end
    end
  end

  local remainingPickups = {}
  for _, pickup in ipairs(map.pickups) do
    if not inZone(context, pickup.x, pickup.y) then
      table.insert(remainingPickups, pickup)
    end
  end
  for _, pickup in ipairs(content.pickups) do
    table.insert(remainingPickups, {
      x = pickup.wx,
      y = pickup.wy,
      kind = "part",
      slot = pickup.slot,
      taken = false,
    })
  end
  map.pickups = remainingPickups

  local remainingEnemies = {}
  for _, enemy in ipairs(map.enemies) do
    if not inZone(context, enemy.x, enemy.y) then
      table.insert(remainingEnemies, enemy)
    end
  end
  for _, enemy in ipairs(content.enemies) do
    table.insert(remainingEnemies, {
      x = enemy.wx,
      y = enemy.wy,
      kind = enemy.kind,
    })
  end
  map.enemies = remainingEnemies

  local remainingBarricades = {}
  for _, barricade in ipairs(map.barricades or {}) do
    local pos = context.tileToWorld(barricade.tx, barricade.ty)
    if not inZone(context, pos.x, pos.y) then
      table.insert(remainingBarricades, barricade)
    end
  end
  map.barricades = remainingBarricades

  local remainingGraves = {}
  for _, grave in ipairs(map.graves or {}) do
    if not inZone(context, grave.x, grave.y) then
      table.insert(remainingGraves, grave)
    end
  end
  map.graves = remainingGraves

  local remainingNpcs = {}
  for _, npc in ipairs(map.npcs or {}) do
    if not inZone(context, npc.x, npc.y) then
      table.insert(remainingNpcs, npc)
    end
  end
  map.npcs = remainingNpcs

  local remainingPaths = {}
  for _, path in ipairs(map.paths or {}) do
    local cx = path.x + (path.w or 0) * 0.5
    local cy = path.y + (path.h or 0) * 0.5
    if not inZone(context, cx, cy) then
      table.insert(remainingPaths, path)
    end
  end
  map.paths = remainingPaths
end

return Apply
