local Math2D = require("src.core.math2d")
local Movement = require("src.core.movement")

local Npcs = {}

local WALK_SEQUENCE = { 1, 2, 1, 3 }
local WALK_FRAME_TIME = 0.14

local function facingFromVector(x, y, fallback)
  if math.abs(x) < 0.0001 and math.abs(y) < 0.0001 then
    return fallback or "down"
  end
  if math.abs(x) >= math.abs(y) then
    if x < 0 then
      return "left"
    end
    return "right"
  end
  if y < 0 then
    return "up"
  end
  return "down"
end

local function initNpc(npc, index)
  npc.radius = npc.radius or 11
  if npc.alive == nil then
    npc.alive = true
  end
  npc.speed = npc.speed or 72
  npc.spriteSet = npc.spriteSet or (((index - 1) % 2) + 4)

  npc.spriteFacing = npc.spriteFacing or "down"
  npc.spriteAnimStep = npc.spriteAnimStep or 1
  npc.spriteAnimTimer = npc.spriteAnimTimer or 0
  npc.spriteFrame = npc.spriteFrame or 1
  npc.spriteMoving = npc.spriteMoving or false

  npc.behavior = npc.behavior or "idle"
  npc.moveIntentX = npc.moveIntentX or 0
  npc.moveIntentY = npc.moveIntentY or 0
  npc.velocityX = npc.velocityX or 0
  npc.velocityY = npc.velocityY or 0
  npc.route = npc.route or nil
  npc.routeIndex = npc.routeIndex or 1
  npc.moveTargetX = npc.moveTargetX or nil
  npc.moveTargetY = npc.moveTargetY or nil
end

local function computeDesiredMove(npc)
  local ix, iy = npc.moveIntentX or 0, npc.moveIntentY or 0
  if math.abs(ix) > 0.01 or math.abs(iy) > 0.01 then
    local nx, ny = Math2D.normalize(ix, iy)
    return nx, ny
  end

  if npc.moveTargetX and npc.moveTargetY then
    local dx = npc.moveTargetX - npc.x
    local dy = npc.moveTargetY - npc.y
    local d2 = dx * dx + dy * dy
    if d2 > 4 then
      local nx, ny = Math2D.normalize(dx, dy)
      return nx, ny
    end
  end

  return 0, 0
end

local function updateNpcSprite(npc, dt, moveX, moveY)
  local moving = math.abs(moveX) > 0.01 or math.abs(moveY) > 0.01
  if moving then
    npc.spriteFacing = facingFromVector(moveX, moveY, npc.spriteFacing)
    npc.spriteAnimTimer = npc.spriteAnimTimer + dt
    while npc.spriteAnimTimer >= WALK_FRAME_TIME do
      npc.spriteAnimTimer = npc.spriteAnimTimer - WALK_FRAME_TIME
      npc.spriteAnimStep = (npc.spriteAnimStep % #WALK_SEQUENCE) + 1
    end
  else
    npc.spriteAnimStep = 1
    npc.spriteAnimTimer = 0
  end

  npc.spriteMoving = moving
  npc.spriteFrame = WALK_SEQUENCE[npc.spriteAnimStep]
end

function Npcs.updateAll(game, dt)
  local list = (game.map and game.map.npcs) or {}
  for i, npc in ipairs(list) do
    initNpc(npc, i)
    if npc.alive then
      local prevX, prevY = npc.x, npc.y
      local nx, ny = computeDesiredMove(npc)
      if nx ~= 0 or ny ~= 0 then
        Movement.moveWithCollisions(game, npc, nx * npc.speed * dt, ny * npc.speed * dt)
      end

      local dx = npc.x - prevX
      local dy = npc.y - prevY
      npc.velocityX = (dt > 0) and (dx / dt) or 0
      npc.velocityY = (dt > 0) and (dy / dt) or 0
      if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then
        npc.spriteFacing = facingFromVector(dx, dy, npc.spriteFacing)
      end
      updateNpcSprite(npc, dt, dx, dy)
    end
  end
end

return Npcs
