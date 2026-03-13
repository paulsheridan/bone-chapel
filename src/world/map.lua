local WorldGen = require("src.world.world_gen")
local Population = require("src.world.world_population")
local WorldRender = require("src.world.world_render")
local TiledMap = require("src.world.tiled_map")
local Dungeon = require("src.world.dungeon")

local Map = {}

Map.tileSize = 32
Map.tiledMapPath = "assets/tiled/maps/world.lua"
Map.preferTiled = true
Map.enableProceduralCave = true
Map.dungeonTileset = {
  imagePath = "assets/dungeon_tilemap.png",
  firstgid = 20000,
  tileWidth = 16,
  tileHeight = 16,
  spacing = 1,
  margin = 0,
  columns = 12,
  tileCount = 132,
  maxLocalId = 72,
  palette = {
    walkableFloor = 49,
    unwalkableFloor = 1,
    walkableFloors = { 49, 43, 50 },
    unwalkableFloors = { 1, 25 },
    floorDetail = {
      edge = 51,
      edgeAlt = 52,
      topLeftCorner = 53,
      topLeftInset = 54,
    },
    walls = {
      outerTopLeft = 60,
      top = 41,
      outerTopRight = 58,
      outerTopCapLeft = 2,
      outerTopCapRight = 4,
      topCapLeft = 18,
      topCap = 3,
      topCapRight = 17,
      left = 14,
      right = 16,
      outerBottomLeft = 26,
      bottom = 27,
      outerBottomRight = 28,
      innerTopLeft = 5,
      innerTopRight = 6,
      innerBottomLeft = 6,
      innerBottomRight = 5,
    },
  },
}

local function objectProperty(obj, name, default)
  if type(obj.properties) == "table" then
    if obj.properties[name] ~= nil then
      return obj.properties[name]
    end
    for _, p in ipairs(obj.properties) do
      if p.name == name then
        return p.value
      end
    end
  end
  return default
end

local function mapProperty(rawMap, name, default)
  if type(rawMap.properties) == "table" then
    if rawMap.properties[name] ~= nil then
      return rawMap.properties[name]
    end
    for _, p in ipairs(rawMap.properties) do
      if p.name == name then
        return p.value
      end
    end
  end
  return default
end

local function objectPoint(obj, scale)
  local s = scale or 1
  return (obj.x or 0) * s, (obj.y or 0) * s
end

local function addTiledObjectsToMap(map)
  local tiled = map.tiled
  local s = map.tiledScale or 1

  local spawn = TiledMap.getObjects(tiled, "spawn")
  if #spawn > 0 then
    local sx, sy = objectPoint(spawn[1], s)
    map.start = { x = sx, y = sy }
  end

  local exits = TiledMap.getObjects(tiled, "exit")
  if #exits > 0 then
    local ex, ey = objectPoint(exits[1], s)
    local tx, ty = Map.worldToTile(ex, ey)
    map.exit = { tx = tx, ty = ty }
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "enemies")) do
    local x, y = objectPoint(obj, s)
    table.insert(map.enemies, {
      x = x,
      y = y,
      kind = objectProperty(obj, "kind", objectProperty(obj, "type", nil)),
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "pickups")) do
    local x, y = objectPoint(obj, s)
    local kind = objectProperty(obj, "kind", "part")
    table.insert(map.pickups, {
      x = x,
      y = y,
      kind = kind,
      slot = objectProperty(obj, "slot", "head"),
      category = objectProperty(obj, "category", nil),
      itemId = objectProperty(obj, "itemId", nil),
      taken = false,
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "npcs")) do
    local x, y = objectPoint(obj, s)
    table.insert(map.npcs, {
      x = x,
      y = y,
      name = objectProperty(obj, "name", obj.name or "Villager"),
      line = objectProperty(obj, "line", "Hello there."),
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "graves")) do
    local x, y = objectPoint(obj, s)
    table.insert(map.graves, {
      x = x,
      y = y,
      slot = objectProperty(obj, "slot", "head"),
      dug = objectProperty(obj, "dug", false),
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "warps")) do
    local x, y = objectPoint(obj, s)
    local kind = objectProperty(obj, "kind", "portal")
    table.insert(map.warps, {
      id = #map.warps + 1,
      fromX = x,
      fromY = y,
      toX = (objectProperty(obj, "toX", x / s) or 0) * s,
      toY = (objectProperty(obj, "toY", y / s) or 0) * s,
      label = objectProperty(obj, "label", "You travel onward."),
      kind = kind,
      radius = (objectProperty(obj, "radius", 12) or 12) * s,
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "houses")) do
    local x = (obj.x or 0) * s
    local y = (obj.y or 0) * s
    local w = (obj.width or (Map.tileSize * 4 / s)) * s
    local h = (obj.height or (Map.tileSize * 4 / s)) * s
    table.insert(map.houses, {
      id = #map.houses + 1,
      name = objectProperty(obj, "name", obj.name or "House"),
      x = x,
      y = y,
      w = w,
      h = h,
      roofHide = objectProperty(obj, "roofHide", true),
      roofHideInset = (objectProperty(obj, "roofHideInset", 0) or 0) * s,
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "build_spots")) do
    local x, y = objectPoint(obj, s)
    map.buildSpot = {
      x = x,
      y = y,
      name = objectProperty(obj, "name", obj.name or "Stitching Altar"),
      label = objectProperty(obj, "label", "The stitching altar hums with old power."),
      radius = (objectProperty(obj, "radius", 36) or 36) * s,
    }
    break
  end

  if not map.buildSpot then
    for _, warp in ipairs(map.warps) do
      if warp.kind == "door" then
        local label = string.lower(warp.label or "")
        if string.find(label, "hill chapel", 1, true) then
          map.buildSpot = {
            x = warp.toX,
            y = warp.toY - Map.tileSize,
            name = "Stitching Altar",
            label = "You return to the chapel's stitching altar.",
            radius = 40,
          }
          break
        end
      end
    end
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "paths")) do
    table.insert(map.paths, {
      x = (obj.x or 0) * s,
      y = (obj.y or 0) * s,
      w = (obj.width or 0) * s,
      h = (obj.height or 0) * s,
    })
  end

  for _, obj in ipairs(TiledMap.getObjects(tiled, "barricades")) do
    local x, y = objectPoint(obj, s)
    local tx, ty = Map.worldToTile(x, y)
    local maxHealth = objectProperty(obj, "maxHealth", 55)
    table.insert(map.barricades, {
      tx = tx,
      ty = ty,
      health = objectProperty(obj, "health", maxHealth),
      maxHealth = maxHealth,
      broken = objectProperty(obj, "broken", false),
      requiredStrength = objectProperty(obj, "requiredStrength", 28),
    })
  end
end

local function findCavePortalWarp(map)
  local fallback
  for _, warp in ipairs(map.warps or {}) do
    if warp.kind == "portal" then
      if not fallback then
        fallback = warp
      end
      local label = string.lower(warp.label or "")
      if string.find(label, "cave", 1, true) then
        return warp
      end
    end
  end
  return fallback
end

local function setStartNearCaveEntrance(map)
  local warp = findCavePortalWarp(map)
  if not warp then
    return
  end

  local radius = warp.radius or 12
  local clearance = math.max(8, radius + 4)
  local probeRadius = 11
  local directions = {
    { 1, 0 },
    { -1, 0 },
    { 0, 1 },
    { 0, -1 },
    { 0.7071, 0.7071 },
    { -0.7071, 0.7071 },
    { 0.7071, -0.7071 },
    { -0.7071, -0.7071 },
  }
  local distances = {
    radius + 16,
    radius + 26,
    radius + 38,
    radius + 52,
  }

  for _, dist in ipairs(distances) do
    for _, dir in ipairs(directions) do
      local sx = warp.fromX + dir[1] * dist
      local sy = warp.fromY + dir[2] * dist
      local dx = sx - warp.fromX
      local dy = sy - warp.fromY
      if dx * dx + dy * dy > clearance * clearance and not Map.entityCollides(map, sx, sy, probeRadius) then
        map.start = { x = sx, y = sy }
        return
      end
    end
  end
end

local function tileRectFromHouse(map, house)
  local tx1, ty1 = Map.worldToTile(house.x, house.y)
  local tx2, ty2 = Map.worldToTile(house.x + house.w - 1, house.y + house.h - 1)
  tx1 = math.max(1, math.min(map.width, tx1))
  ty1 = math.max(1, math.min(map.height, ty1))
  tx2 = math.max(1, math.min(map.width, tx2))
  ty2 = math.max(1, math.min(map.height, ty2))
  if tx2 < tx1 then
    tx1, tx2 = tx2, tx1
  end
  if ty2 < ty1 then
    ty1, ty2 = ty2, ty1
  end
  return tx1, ty1, tx2, ty2
end

function Map.tileToWorld(tx, ty)
  local size = Map.tileSize
  return {
    x = (tx - 0.5) * size,
    y = (ty - 0.5) * size,
  }
end

function Map.worldToTile(x, y)
  local size = Map.tileSize
  local tx = math.floor(x / size) + 1
  local ty = math.floor(y / size) + 1
  return tx, ty
end

function Map.inBounds(map, tx, ty)
  return tx >= 1 and ty >= 1 and tx <= map.width and ty <= map.height
end

function Map.isBlocked(map, tx, ty)
  if map.tiled then
    return TiledMap.isBlocked(map.tiled, tx, ty)
  end

  if not Map.inBounds(map, tx, ty) then
    return true
  end
  if map.tiles[ty][tx] == "wall" then
    return true
  end
  for _, barricade in ipairs(map.barricades) do
    if not barricade.broken and barricade.tx == tx and barricade.ty == ty then
      return true
    end
  end
  return false
end

function Map.entityCollides(map, x, y, radius)
  local size = Map.tileSize
  local minX = math.floor((x - radius) / size) + 1
  local maxX = math.floor((x + radius) / size) + 1
  local minY = math.floor((y - radius) / size) + 1
  local maxY = math.floor((y + radius) / size) + 1

  for ty = minY, maxY do
    for tx = minX, maxX do
      if Map.isBlocked(map, tx, ty) then
        return true
      end
    end
  end
  return false
end

function Map.getZoneForWorld(map, x, y)
  local zoneWidthPx = map.zoneWidthTiles * Map.tileSize
  local zoneHeightPx = map.zoneHeightTiles * Map.tileSize
  local zx = math.floor(x / zoneWidthPx) + 1
  local zy = math.floor(y / zoneHeightPx) + 1
  zx = math.max(1, math.min(map.zonesX, zx))
  zy = math.max(1, math.min(map.zonesY, zy))
  return zx, zy
end

function Map.getZoneBoundsPixels(map, zx, zy)
  local zoneWidthPx = map.zoneWidthTiles * Map.tileSize
  local zoneHeightPx = map.zoneHeightTiles * Map.tileSize
  local left = (zx - 1) * zoneWidthPx
  local top = (zy - 1) * zoneHeightPx
  return {
    left = left,
    top = top,
    right = left + zoneWidthPx,
    bottom = top + zoneHeightPx,
  }
end

function Map.zoneToCamera(map, zx, zy, viewW, viewH)
  local bounds = Map.getZoneBoundsPixels(map, zx, zy)
  local cx = bounds.left + (bounds.right - bounds.left) * 0.5 - viewW * 0.5
  local cy = bounds.top + (bounds.bottom - bounds.top) * 0.5 - viewH * 0.5
  return cx, cy
end

function Map.load()
  if Map.preferTiled and love.filesystem.getInfo(Map.tiledMapPath) then
    local tiled, err = TiledMap.loadFromLua(Map.tiledMapPath)
    if not tiled then
      error("Failed to load Tiled map: " .. tostring(err))
    end

    local raw = tiled.map
    local sourceTileSize = raw.tilewidth or 16
    Map.tileSize = 32
    local tiledScale = Map.tileSize / sourceTileSize
    tiled.drawTileWidth = Map.tileSize
    tiled.drawTileHeight = Map.tileSize
    local zoneWidthTiles = mapProperty(raw, "zoneWidthTiles", 34)
    local zoneHeightTiles = mapProperty(raw, "zoneHeightTiles", 22)
    local zonesX = math.max(1, math.floor((raw.width + zoneWidthTiles - 1) / zoneWidthTiles))
    local zonesY = math.max(1, math.floor((raw.height + zoneHeightTiles - 1) / zoneHeightTiles))

    local map = {
      tiled = tiled,
      tiledScale = tiledScale,
      zoneWidthTiles = zoneWidthTiles,
      zoneHeightTiles = zoneHeightTiles,
      zonesX = zonesX,
      zonesY = zonesY,
      width = raw.width,
      height = raw.height,
      pickups = {},
      enemies = {},
      barricades = {},
      npcs = {},
      graves = {},
      warps = {},
      paths = {},
      houses = {},
      buildSpot = nil,
      start = Map.tileToWorld(2, 2),
      exit = nil,
    }
    addTiledObjectsToMap(map)
    setStartNearCaveEntrance(map)

    local caveTileTheme
    if Map.dungeonTileset and love.filesystem.getInfo(Map.dungeonTileset.imagePath) then
      local palette = Map.dungeonTileset.palette or {}

      local runtimeTileset = TiledMap.addImageTileset(tiled, {
        imagePath = Map.dungeonTileset.imagePath,
        firstgid = Map.dungeonTileset.firstgid,
        tileWidth = Map.dungeonTileset.tileWidth,
        tileHeight = Map.dungeonTileset.tileHeight,
        spacing = Map.dungeonTileset.spacing,
        margin = Map.dungeonTileset.margin,
        columns = Map.dungeonTileset.columns,
        tileCount = Map.dungeonTileset.tileCount,
      })
      if runtimeTileset then
        local maxLocalId = #runtimeTileset.quads
        local maxDungeonLocalId = math.min(maxLocalId, Map.dungeonTileset.maxLocalId or maxLocalId)

        local function localToGid(localId, fallback)
          local id = math.floor(tonumber(localId) or 0)
          if id < 1 then
            return fallback
          end
          id = math.min(maxDungeonLocalId, id)
          if id < 1 then
            return fallback
          end
          return runtimeTileset.firstgid + id - 1
        end

        local walkableFloorGid = localToGid(palette.walkableFloor, runtimeTileset.firstgid)
        local unwalkableFloorGid = localToGid(palette.unwalkableFloor, walkableFloorGid)

        local function mapVariantList(localList, fallbackGid)
          local out = {}
          if type(localList) == "table" then
            for _, localId in ipairs(localList) do
              local gid = localToGid(localId)
              if gid then
                table.insert(out, gid)
              end
            end
          end
          if #out == 0 and fallbackGid then
            out[1] = fallbackGid
          end
          return out
        end

        local function firstWallId(...)
          for i = 1, select("#", ...) do
            local candidate = select(i, ...)
            local id = math.floor(tonumber(candidate) or 0)
            if id > 0 then
              return id
            end
          end
          return nil
        end

        local function isExplicitInnerCornerOverride(localId, baseline)
          local id = math.floor(tonumber(localId) or 0)
          return id > 0 and id ~= baseline
        end

        local wallPalette = palette.walls or {}
        local floorDetailPalette = palette.floorDetail or {}
        caveTileTheme = {
          floorGid = walkableFloorGid,
          wallGid = unwalkableFloorGid,
          source = "configured",
          floorDetail = {
            edge = localToGid(floorDetailPalette.edge or 51, walkableFloorGid),
            edgeAlt = localToGid(floorDetailPalette.edgeAlt or 52, walkableFloorGid),
            topLeftCorner = localToGid(floorDetailPalette.topLeftCorner or 53, walkableFloorGid),
            topLeftInset = localToGid(floorDetailPalette.topLeftInset or 54, walkableFloorGid),
          },
          innerCornerOverrides = {
            topLeft = isExplicitInnerCornerOverride(wallPalette.innerTopLeft, 5),
            topRight = isExplicitInnerCornerOverride(wallPalette.innerTopRight, 6),
            bottomLeft = isExplicitInnerCornerOverride(wallPalette.innerBottomLeft, 17),
            bottomRight = isExplicitInnerCornerOverride(wallPalette.innerBottomRight, 18),
          },
          walkableFloors = mapVariantList(palette.walkableFloors, walkableFloorGid),
          unwalkableFloors = mapVariantList(palette.unwalkableFloors, unwalkableFloorGid),
          walls = {
            outerTopLeft = localToGid(firstWallId(wallPalette.outerTopLeft, wallPalette.topLeft), unwalkableFloorGid),
            top = localToGid(firstWallId(wallPalette.top), unwalkableFloorGid),
            outerTopRight = localToGid(firstWallId(wallPalette.outerTopRight, wallPalette.topRight), unwalkableFloorGid),
            outerTopCapLeft = localToGid(
              firstWallId(
                wallPalette.outerTopCapLeft,
                wallPalette.outerTopLeft,
                wallPalette.topLeft,
                wallPalette.innerTopLeft,
                wallPalette.top
              ),
              unwalkableFloorGid
            ),
            outerTopCapRight = localToGid(
              firstWallId(
                wallPalette.outerTopCapRight,
                wallPalette.outerTopRight,
                wallPalette.topRight,
                wallPalette.innerTopRight,
                wallPalette.top
              ),
              unwalkableFloorGid
            ),
            topCapLeft = localToGid(firstWallId(wallPalette.topCapLeft, wallPalette.topCap, wallPalette.top), unwalkableFloorGid),
            topCap = localToGid(firstWallId(wallPalette.topCap, wallPalette.top), unwalkableFloorGid),
            topCapRight = localToGid(firstWallId(wallPalette.topCapRight, wallPalette.topCap, wallPalette.top), unwalkableFloorGid),
            left = localToGid(firstWallId(wallPalette.left), unwalkableFloorGid),
            right = localToGid(firstWallId(wallPalette.right), unwalkableFloorGid),
            outerBottomLeft = localToGid(firstWallId(wallPalette.outerBottomLeft, wallPalette.bottomLeft), unwalkableFloorGid),
            bottom = localToGid(firstWallId(wallPalette.bottom), unwalkableFloorGid),
            outerBottomRight = localToGid(firstWallId(wallPalette.outerBottomRight, wallPalette.bottomRight), unwalkableFloorGid),
            innerTopLeft = localToGid(
              firstWallId(wallPalette.innerTopLeft, wallPalette.outerTopLeft, wallPalette.topLeft),
              unwalkableFloorGid
            ),
            innerTopRight = localToGid(
              firstWallId(wallPalette.innerTopRight, wallPalette.outerTopRight, wallPalette.topRight),
              unwalkableFloorGid
            ),
            innerBottomLeft = localToGid(
              firstWallId(wallPalette.innerBottomLeft, wallPalette.outerBottomLeft, wallPalette.bottomLeft),
              unwalkableFloorGid
            ),
            innerBottomRight = localToGid(
              firstWallId(wallPalette.innerBottomRight, wallPalette.outerBottomRight, wallPalette.bottomRight),
              unwalkableFloorGid
            ),
          },
        }
      end
    end

    if Map.enableProceduralCave then
      Dungeon.applyProceduralCave(map, {
        worldToTile = Map.worldToTile,
        tileToWorld = Map.tileToWorld,
        getZoneForWorld = Map.getZoneForWorld,
      }, caveTileTheme)
    end
    return map
  end

  Map.tileSize = 32
  local map = WorldGen.createEmptyMap()
  local terrainMeta = WorldGen.applyTerrain(map, Map.tileSize, Map.tileToWorld)
  Population.apply(map, Map.tileToWorld, terrainMeta)
  return map
end

function Map.draw(map, opts)
  if map.tiled then
    local drawOpts = {}
    if opts then
      for k, v in pairs(opts) do
        drawOpts[k] = v
      end
    end
    local skipLayerNames = {}
    if opts and opts.skipLayerNames then
      for name, shouldSkip in pairs(opts.skipLayerNames) do
        skipLayerNames[name] = shouldSkip
      end
    end
    skipLayerNames.collision = true
    skipLayerNames.walls = true
    skipLayerNames.blocked = true
    drawOpts.skipLayerNames = skipLayerNames
    TiledMap.draw(map.tiled, map, drawOpts)
    return
  end
  WorldRender.draw(map, Map.tileSize, Map.tileToWorld, Map.getZoneBoundsPixels)
end

function Map.drawLayerByName(map, layerName, opts)
  if not map.tiled then
    return
  end
  TiledMap.drawLayerByName(map.tiled, layerName, opts)
end

function Map.getRoofHideRects(map, entities)
  if not map.houses or not entities then
    return {}
  end

  local rects = {}
  local seen = {}
  for _, entity in ipairs(entities) do
    if entity and entity.alive then
      for _, house in ipairs(map.houses) do
        if house.roofHide ~= false then
          local inset = math.max(0, house.roofHideInset or 0)
          local left = house.x + inset
          local top = house.y + inset
          local right = house.x + house.w - inset
          local bottom = house.y + house.h - inset
          if right < left then
            left = house.x
            right = house.x + house.w
          end
          if bottom < top then
            top = house.y
            bottom = house.y + house.h
          end
          if entity.x >= left and entity.x <= right and entity.y >= top and entity.y <= bottom then
            if not seen[house.id] then
              local tx1, ty1, tx2, ty2 = tileRectFromHouse(map, house)
              seen[house.id] = true
              table.insert(rects, {
                tx1 = tx1,
                ty1 = ty1,
                tx2 = tx2,
                ty2 = ty2,
              })
            end
          end
        end
      end
    end
  end
  return rects
end

return Map
