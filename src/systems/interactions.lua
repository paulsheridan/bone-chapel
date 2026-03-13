local BodyParts = require("src.data.body_parts")
local Map = require("src.world.map")
local Camera = require("src.systems.camera")
local Math2D = require("src.core.math2d")

local Interactions = {}

local TUNING = {
  interactionRange = 36,
  graveCancelRange = 48,
  digDuration = 1.4,
  warpCooldown = 0.55,
}

local function findNearestInRange(items, x, y, rangeSq)
  local nearest
  local nearestDistSq
  for _, item in ipairs(items) do
    local d2 = Math2D.distSq(x, y, item.x, item.y)
    if d2 <= rangeSq and (not nearestDistSq or d2 < nearestDistSq) then
      nearest = item
      nearestDistSq = d2
    end
  end
  return nearest
end

local function showDialog(game, name, text)
  game.ui.dialog = {
    name = name,
    text = text,
  }
end

local function startDig(game, actor, grave)
  game.ui.dig = {
    actor = actor,
    grave = grave,
    duration = TUNING.digDuration,
    timer = TUNING.digDuration,
  }
  game.ui.message = "Digging..."
  game.ui.msgTimer = 1.2
end

local function transferThroughWarp(game, warp, actor)
  actor = actor or game.necromancer
  actor.x = warp.toX
  actor.y = warp.toY
  local zx, zy = Map.getZoneForWorld(game.map, actor.x, actor.y)
  Camera.snapToZone(game, zx, zy)
  game.ui.message = warp.label
  game.ui.msgTimer = 2.4
  game.warpCooldown = TUNING.warpCooldown
end

function Interactions.interact(game)
  if game.ui.dialog then
    game.ui.dialog = nil
    return
  end

  if game.ui.dig then
    game.ui.dig = nil
    game.ui.message = "Digging stopped."
    game.ui.msgTimer = 1.5
    return
  end

  local actor = (game.getControlledEntity and game:getControlledEntity()) or game.necromancer
  if not actor.alive then
    return
  end

  local useRangeSq = TUNING.interactionRange * TUNING.interactionRange

  local buildSpot = game.map and game.map.buildSpot
  if buildSpot and Math2D.distSq(actor.x, actor.y, buildSpot.x, buildSpot.y) <= (buildSpot.radius or TUNING.interactionRange) ^ 2 then
    game.ui.menu.open = true
    game.ui.message = buildSpot.label or "You step up to the stitching altar."
    game.ui.msgTimer = 1.8
    return
  end

  local npc = findNearestInRange(game.map.npcs, actor.x, actor.y, useRangeSq)
  if npc then
    showDialog(game, npc.name, npc.line)
    return
  end

  local grave = findNearestInRange(game.map.graves, actor.x, actor.y, useRangeSq)
  if grave then
    if grave.dug then
      game.ui.message = "This grave is already disturbed."
      game.ui.msgTimer = 2
    else
      startDig(game, actor, grave)
    end
    return
  end

  game.ui.message = "Nothing to interact with here."
  game.ui.msgTimer = 1.5
end

function Interactions.handleDialogKey(game, key)
  if not game.ui.dialog then
    return false
  end
  if key == "e" or key == "return" or key == "space" or key == "escape" then
    game.ui.dialog = nil
  end
  return true
end

function Interactions.updateDigging(game, dt)
  if not game.ui.dig then
    return
  end

  local dig = game.ui.dig
  local actor = dig.actor or game.necromancer
  local grave = dig.grave

  if not actor.alive or not grave or grave.dug then
    game.ui.dig = nil
    return
  end

  if Math2D.distSq(actor.x, actor.y, grave.x, grave.y) > TUNING.graveCancelRange * TUNING.graveCancelRange then
    game.ui.dig = nil
    game.ui.message = "You moved too far from the grave."
    game.ui.msgTimer = 1.8
    return
  end

  dig.timer = math.max(0, dig.timer - dt)
  if dig.timer <= 0 then
    grave.dug = true
    game:addPart(grave.slot)
    game.ui.message = "You dig up a " .. BodyParts.slotNames[grave.slot] .. "."
    game.ui.msgTimer = 3
    game.ui.dig = nil
  end
end

function Interactions.updateWarpTouch(game, dt)
  game.warpCooldown = math.max(0, (game.warpCooldown or 0) - dt)
  if game.warpCooldown > 0 then
    return
  end
  if game.ui.menu.open or game.ui.dialog or game.ui.dig then
    return
  end
  local actor = (game.getControlledEntity and game:getControlledEntity()) or game.necromancer
  if not actor or not actor.alive then
    return
  end

  for _, warp in ipairs(game.map.warps) do
    local radius = warp.radius or 12
    if Math2D.distSq(actor.x, actor.y, warp.fromX, warp.fromY) <= radius * radius then
      transferThroughWarp(game, warp, actor)
      return
    end
  end
end

return Interactions
