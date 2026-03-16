local BodyParts = require("src.data.body_parts")

local Populate = {}

local enemyKinds = { "brute", "hunter", "skirmisher" }

local function tileKey(x, y)
  return x .. ":" .. y
end

local function gatherFloorTiles(layout)
  local tiles = {}
  for y = 1, layout.height do
    for x = 1, layout.width do
      if not layout.blocked[y][x] then
        table.insert(tiles, { x = x, y = y })
      end
    end
  end
  return tiles
end

local function manhattan(a, b)
  return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

local function pickTile(candidates, rng, occupied, minDistFrom, minDistValue)
  if #candidates == 0 then
    return nil
  end

  local start = rng:random(1, #candidates)
  for i = 0, #candidates - 1 do
    local idx = ((start + i - 1) % #candidates) + 1
    local tile = candidates[idx]
    if not occupied[tileKey(tile.x, tile.y)] then
      local okay = true
      if minDistFrom and minDistValue then
        for _, other in ipairs(minDistFrom) do
          if manhattan(tile, other) < minDistValue then
            okay = false
            break
          end
        end
      end
      if okay then
        return tile
      end
    end
  end
  return nil
end

local function localToSpawn(context, tile)
  local tx
  local ty
  if context.globalLayout then
    tx = tile.x
    ty = tile.y
  else
    tx = context.tx1 + tile.x - 1
    ty = context.ty1 + tile.y - 1
  end
  local pos = context.tileToWorld(tx, ty)
  return {
    x = tile.x,
    y = tile.y,
    tx = tx,
    ty = ty,
    wx = pos.x,
    wy = pos.y,
  }
end

function Populate.generate(context, layout, rng, config)
  local content = {
    pickups = {},
    enemies = {},
  }

  local allFloor = gatherFloorTiles(layout)
  local farForPickups = {}
  local farForEnemies = {}
  for _, tile in ipairs(allFloor) do
    local dist = manhattan(tile, layout.entry)
    if dist >= config.pickups.minEntryDistance then
      table.insert(farForPickups, tile)
    end
    if dist >= config.enemies.minEntryDistance then
      table.insert(farForEnemies, tile)
    end
  end

  local occupied = {}
  local pickupTiles = {}

  local pickupSlots = {}
  for _, slot in ipairs(BodyParts.slotOrder) do
    table.insert(pickupSlots, slot)
  end

  local extras = rng:random(config.pickups.extraMin, config.pickups.extraMax)
  for _ = 1, extras do
    local slotIdx = rng:random(1, #BodyParts.slotOrder)
    table.insert(pickupSlots, BodyParts.slotOrder[slotIdx])
  end

  for _, slot in ipairs(pickupSlots) do
    local tile = pickTile(farForPickups, rng, occupied)
    if not tile then
      tile = pickTile(allFloor, rng, occupied)
    end
    if tile then
      occupied[tileKey(tile.x, tile.y)] = true
      table.insert(pickupTiles, { x = tile.x, y = tile.y })
      local spawn = localToSpawn(context, tile)
      table.insert(content.pickups, {
        slot = slot,
        x = spawn.x,
        y = spawn.y,
        tx = spawn.tx,
        ty = spawn.ty,
        wx = spawn.wx,
        wy = spawn.wy,
      })
    end
  end

  local roomCount = #layout.rooms
  local areaCount = math.max(1, math.floor(layout.areaCount or 1))
  local perAreaBonus = ((config.enemies and config.enemies.scalePerArea) or 0)
  local baseEnemyCount = math.floor(roomCount * (config.enemies.scalePerRoom or 0.55) + areaCount * perAreaBonus + 0.5)
  local variance = config.enemies.variance or 1
  local enemyCount = baseEnemyCount + rng:random(-variance, variance)
  enemyCount = math.max(config.enemies.min, math.min(config.enemies.max, enemyCount))
  for _ = 1, enemyCount do
    local tile = pickTile(farForEnemies, rng, occupied, pickupTiles, config.enemies.minPickupDistance)
    if not tile then
      tile = pickTile(allFloor, rng, occupied, pickupTiles, config.enemies.minPickupDistance)
    end
      if tile then
        occupied[tileKey(tile.x, tile.y)] = true
        local spawn = localToSpawn(context, tile)
        local kind = enemyKinds[rng:random(1, #enemyKinds)]
        table.insert(content.enemies, {
          x = spawn.x,
          y = spawn.y,
          tx = spawn.tx,
          ty = spawn.ty,
          wx = spawn.wx,
          wy = spawn.wy,
          kind = kind,
        })
      end
    end

  return content
end

return Populate
