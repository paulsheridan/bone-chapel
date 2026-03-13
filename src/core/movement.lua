local Map = require("src.world.map")

local Movement = {}

local function entityRadius(entity)
  return entity.radius or 10
end

local function blockersFor(game, entity)
  local blockers = {}

  local function pushIfBlocker(other)
    if not other or other == entity then
      return
    end
    if other.alive == false then
      return
    end
    table.insert(blockers, other)
  end

  pushIfBlocker(game.necromancer)
  pushIfBlocker(game.monster)

  for _, enemy in ipairs(game.enemies or {}) do
    pushIfBlocker(enemy)
  end

  for _, npc in ipairs((game.map and game.map.npcs) or {}) do
    pushIfBlocker(npc)
  end

  return blockers
end

local function circleBlocked(game, entity, x, y)
  local r = entityRadius(entity)
  for _, blocker in ipairs(blockersFor(game, entity)) do
    local br = entityRadius(blocker)
    local minDist = r + br
    local dxNow = entity.x - blocker.x
    local dyNow = entity.y - blocker.y
    local dxNext = x - blocker.x
    local dyNext = y - blocker.y
    local nowD2 = dxNow * dxNow + dyNow * dyNow
    local nextD2 = dxNext * dxNext + dyNext * dyNext
    local minD2 = minDist * minDist

    if nextD2 < minD2 then
      local escapingOverlap = nowD2 < minD2 and nextD2 > nowD2
      if not escapingOverlap then
        return true
      end
    end
  end
  return false
end

local function canOccupy(game, entity, x, y)
  if Map.entityCollides(game.map, x, y, entityRadius(entity)) then
    return false
  end
  if circleBlocked(game, entity, x, y) then
    return false
  end
  return true
end

function Movement.applyKnockback(entity, nx, ny, force)
  if not entity then
    return
  end
  entity.kbX = (entity.kbX or 0) + nx * force
  entity.kbY = (entity.kbY or 0) + ny * force
  entity.hitStun = math.max(entity.hitStun or 0, 0.07)
end

function Movement.updateKnockback(game, entity, dt)
  if not entity or entity.alive == false then
    return
  end

  entity.slamCooldown = math.max(0, (entity.slamCooldown or 0) - dt)
  entity.hitStun = math.max(0, (entity.hitStun or 0) - dt)

  local vx = entity.kbX or 0
  local vy = entity.kbY or 0
  if math.abs(vx) < 2 and math.abs(vy) < 2 then
    entity.kbX = 0
    entity.kbY = 0
    return
  end

  local oldX, oldY = entity.x, entity.y
  local intendedDX = vx * dt
  local intendedDY = vy * dt
  Movement.moveWithCollisions(game, entity, intendedDX, intendedDY)

  local movedDX = entity.x - oldX
  local movedDY = entity.y - oldY
  local intendedDist = math.sqrt(intendedDX * intendedDX + intendedDY * intendedDY)
  local movedDist = math.sqrt(movedDX * movedDX + movedDY * movedDY)
  local speed = math.sqrt(vx * vx + vy * vy)

  if game and game.handleWallSlam and (entity.slamCooldown or 0) <= 0 and speed > 140 and intendedDist > 0.1 and movedDist < intendedDist * 0.3 then
    local nx = vx / speed
    local ny = vy / speed
    local probeX = entity.x + nx * (entity.radius + 2)
    local probeY = entity.y + ny * (entity.radius + 2)
    if Map.entityCollides(game.map, probeX, probeY, math.max(3, entity.radius * 0.7)) then
      game:handleWallSlam(entity, speed)
    end
  end

  local damping = math.exp(-12 * dt)
  entity.kbX = vx * damping
  entity.kbY = vy * damping
end

function Movement.moveWithCollisions(game, entity, dx, dy)
  local nextX = entity.x + dx
  if canOccupy(game, entity, nextX, entity.y) then
    entity.x = nextX
  end

  local nextY = entity.y + dy
  if canOccupy(game, entity, entity.x, nextY) then
    entity.y = nextY
  end
end

return Movement
