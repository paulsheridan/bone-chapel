local Apply = {}

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
  return zx == context.zoneX and zy == context.zoneY
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

  return pickSparseVariant(walkableFloors, x, y, context.floorGid, 7, 3)
end

local function pickWallTile(context, layout, x, y)
  local theme = context.tileTheme
  local walls = theme and theme.walls or nil
  local innerOverrides = theme and theme.innerCornerOverrides or nil
  local useInnerTopLeft = innerOverrides and innerOverrides.topLeft
  local useInnerTopRight = innerOverrides and innerOverrides.topRight
  local useInnerBottomLeft = innerOverrides and innerOverrides.bottomLeft
  local useInnerBottomRight = innerOverrides and innerOverrides.bottomRight
  local outerTopLeft = walls and (walls.outerTopLeft or walls.topLeft) or nil
  local outerTopRight = walls and (walls.outerTopRight or walls.topRight) or nil
  local outerBottomLeft = walls and (walls.outerBottomLeft or walls.bottomLeft) or nil
  local outerBottomRight = walls and (walls.outerBottomRight or walls.bottomRight) or nil
  local floorN = isWalkable(layout, x, y - 1)
  local floorS = isWalkable(layout, x, y + 1)
  local floorW = isWalkable(layout, x - 1, y)
  local floorE = isWalkable(layout, x + 1, y)
  local floorNN = isWalkable(layout, x, y - 2)
  local floorSS = isWalkable(layout, x, y + 2)
  local floorSSW = isWalkable(layout, x - 1, y + 2)
  local floorSSE = isWalkable(layout, x + 1, y + 2)
  local floorNW = isWalkable(layout, x - 1, y - 1)
  local floorNE = isWalkable(layout, x + 1, y - 1)
  local floorSW = isWalkable(layout, x - 1, y + 1)
  local floorSE = isWalkable(layout, x + 1, y + 1)

  if not floorS and floorSS then
    if floorW and not floorE then
      return walls and (walls.topCapRight or walls.topCap) or context.wallGid
    elseif floorE and not floorW then
      return walls and (walls.topCapLeft or walls.topCap) or context.wallGid
    end
    return walls and (walls.topCap or walls.top) or context.wallGid
  end

  if not floorN and not floorS and not floorW and not floorE then
    if not floorSS then
      if floorSSE and not floorSSW and not floorSE then
        return walls and (walls.outerTopCapLeft or walls.topCapLeft or walls.topCap or context.wallGid) or context.wallGid
      elseif floorSSW and not floorSSE and not floorSW then
        return walls and (walls.outerTopCapRight or walls.topCapRight or walls.topCap or context.wallGid) or context.wallGid
      end
    end

    if floorSW and not floorSE then
      return walls and (walls.right or context.wallGid) or context.wallGid
    elseif floorSE and not floorSW then
      return walls and (walls.left or context.wallGid) or context.wallGid
    elseif floorNW and not floorNE then
      return outerBottomRight or (walls and (walls.bottom or context.wallGid)) or context.wallGid
    elseif floorNE and not floorNW then
      return outerBottomLeft or (walls and (walls.bottom or context.wallGid)) or context.wallGid
    elseif floorNN and not floorSS then
      if floorSSE and not floorSSW then
        if useInnerTopLeft then
          return walls and (walls.innerTopLeft or walls.outerTopCapLeft or outerTopLeft or walls.top or context.wallGid)
            or context.wallGid
        end
        return walls and (walls.outerTopCapLeft or outerTopLeft or walls.top or context.wallGid) or context.wallGid
      elseif floorSSW and not floorSSE then
        if useInnerTopRight then
          return walls and (walls.innerTopRight or walls.outerTopCapRight or outerTopRight or walls.top or context.wallGid)
            or context.wallGid
        end
        return walls and (walls.outerTopCapRight or outerTopRight or walls.top or context.wallGid) or context.wallGid
      end
    end
    return pickSparseVariant(theme and theme.unwalkableFloors, x, y, context.wallGid, 6, 0)
  end

  if not walls then
    return context.wallGid
  end

  if floorS and floorE and not floorN and not floorW then
    return outerTopLeft or walls.top or context.wallGid
  elseif floorS and floorW and not floorN and not floorE then
    return outerTopRight or walls.top or context.wallGid
  elseif floorN and floorE and not floorS and not floorW then
    if useInnerBottomLeft then
      return walls.innerBottomLeft or outerBottomLeft or walls.bottom or context.wallGid
    end
    return outerBottomLeft or walls.bottom or context.wallGid
  elseif floorN and floorW and not floorS and not floorE then
    if useInnerBottomRight then
      return walls.innerBottomRight or outerBottomRight or walls.bottom or context.wallGid
    end
    return outerBottomRight or walls.bottom or context.wallGid
  end

  if floorS and floorE and floorW and not floorN and not floorSE then
    return walls.innerTopLeft or walls.top or context.wallGid
  elseif floorS and floorE and floorW and not floorN and not floorSW then
    return walls.innerTopRight or walls.top or context.wallGid
  elseif floorN and floorE and floorW and not floorS and not floorNE then
    return walls.innerBottomLeft or walls.bottom or context.wallGid
  elseif floorN and floorE and floorW and not floorS and not floorNW then
    return walls.innerBottomRight or walls.bottom or context.wallGid
  end

  if floorS and not floorN then
    return walls.top or context.wallGid
  elseif floorN and not floorS then
    return walls.bottom or context.wallGid
  elseif floorE and not floorW then
    return walls.left or context.wallGid
  elseif floorW and not floorE then
    return walls.right or context.wallGid
  elseif floorE or floorW then
    return walls.left or context.wallGid
  end

  return walls.top or context.wallGid
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
    zoneX = zoneX,
    zoneY = zoneY,
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

  for y = 1, layout.height do
    for x = 1, layout.width do
      local tx = context.tx1 + x - 1
      local ty = context.ty1 + y - 1
      local idx = (ty - 1) * map.width + tx
      if layout.blocked[y][x] then
        groundData[idx] = pickWallTile(context, layout, x, y)
        collisionData[idx] = context.collisionWallGid
      else
        groundData[idx] = pickWalkableTile(context, layout, x, y)
        collisionData[idx] = 0
      end
    end
  end

  for _, layer in ipairs(context.clearLayers or {}) do
    local data = layer.dataDecoded
    if data then
      for y = 1, layout.height do
        for x = 1, layout.width do
          local tx = context.tx1 + x - 1
          local ty = context.ty1 + y - 1
          local idx = (ty - 1) * map.width + tx
          data[idx] = 0
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
