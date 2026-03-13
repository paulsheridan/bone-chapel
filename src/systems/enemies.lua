local Map = require("src.world.map")
local Pathfinding = require("src.world.pathfinding")
local LOS = require("src.ai.los")
local Math2D = require("src.core.math2d")
local Movement = require("src.core.movement")

local Enemies = {}

local archetypes = {
  brute = {
    speed = 76,
    health = 88,
    strength = 13,
    visionRange = 220,
    attackCooldown = 1.08,
    repathRate = 0.5,
    loseGrace = 2.2,
    searchDuration = 1.9,
    patrolMin = 1.8,
    patrolMax = 3.8,
    windupDuration = 0.36,
    maxPoise = 42,
    poiseRegen = 12,
  },
  hunter = {
    speed = 94,
    health = 62,
    strength = 9,
    visionRange = 290,
    attackCooldown = 0.82,
    repathRate = 0.32,
    loseGrace = 3.2,
    searchDuration = 2.8,
    patrolMin = 1.4,
    patrolMax = 3.4,
    windupDuration = 0.28,
    maxPoise = 30,
    poiseRegen = 16,
  },
  skirmisher = {
    speed = 108,
    health = 52,
    strength = 8,
    visionRange = 245,
    attackCooldown = 0.74,
    repathRate = 0.28,
    loseGrace = 2.3,
    searchDuration = 2.1,
    patrolMin = 1.2,
    patrolMax = 2.8,
    kiteInRange = 64,
    kiteOutRange = 98,
    windupDuration = 0.22,
    maxPoise = 24,
    poiseRegen = 18,
  },
}

local archetypeOrder = { "brute", "hunter", "skirmisher" }

local function pickArchetype(kind)
  if type(kind) == "string" then
    kind = string.lower(kind)
  end
  if kind and archetypes[kind] then
    return kind, archetypes[kind]
  end
  local rolled = archetypeOrder[love.math.random(1, #archetypeOrder)]
  return rolled, archetypes[rolled]
end

local function chooseTarget(game, enemy)
  local candidates = {}
  if game.necromancer.alive then
    table.insert(candidates, game.necromancer)
  end
  if game.monster and game.monster.alive then
    table.insert(candidates, game.monster)
  end

  local best
  local bestD2 = math.huge
  for _, target in ipairs(candidates) do
    local d2 = Math2D.distSq(enemy.x, enemy.y, target.x, target.y)
    if d2 <= enemy.visionRange * enemy.visionRange and LOS.canSee(game.map, enemy.x, enemy.y, target.x, target.y) then
      if d2 < bestD2 then
        best = target
        bestD2 = d2
      end
    end
  end
  return best
end

local function recalcPath(game, enemy, tx, ty)
  local sTx, sTy = Map.worldToTile(enemy.x, enemy.y)
  local gTx, gTy = Map.worldToTile(tx, ty)
  local path = Pathfinding.findPath(game.map, sTx, sTy, gTx, gTy, function(px, py)
    return Map.isBlocked(game.map, px, py)
  end)
  enemy.path = path
  enemy.pathIndex = 2
end

local function moveAlongPath(game, enemy, dt)
  if not enemy.path or enemy.pathIndex > #enemy.path then
    return
  end

  local node = enemy.path[enemy.pathIndex]
  local targetPos = Map.tileToWorld(node.tx, node.ty)
  local vx, vy = targetPos.x - enemy.x, targetPos.y - enemy.y
  local nx, ny = Math2D.normalize(vx, vy)
  enemy.lookX = nx
  enemy.lookY = ny
  Movement.moveWithCollisions(game, enemy, nx * enemy.speed * dt, ny * enemy.speed * dt)
  if Math2D.distSq(enemy.x, enemy.y, targetPos.x, targetPos.y) < 100 then
    enemy.pathIndex = enemy.pathIndex + 1
  end
end

local function damageTarget(game, attacker, target, amount)
  local reduction = target.damageReduction or 0
  local dealt = math.max(1, math.floor(amount * (1 - reduction) + 0.5))
  target.health = target.health - dealt
  local nx, ny = Math2D.normalize(target.x - attacker.x, target.y - attacker.y)
  Movement.applyKnockback(target, nx, ny, 150)
  if game.applyPoiseHit then
    game:applyPoiseHit(target, 10, 0.2)
  end
  if target.health <= 0 then
    target.health = 0
    target.alive = false
  end
  return dealt
end

local function chooseMeleeTarget(game, enemy)
  local best
  local bestD2 = math.huge
  local targets = { game.necromancer, game.monster }
  for _, target in ipairs(targets) do
    if target and target.alive then
      local reach = enemy.radius + target.radius + 12
      local d2 = Math2D.distSq(enemy.x, enemy.y, target.x, target.y)
      if d2 < (reach * reach) and d2 < bestD2 then
        best = target
        bestD2 = d2
      end
    end
  end
  return best
end

function Enemies.create(pos)
  local kind, data = pickArchetype(pos.kind)
  return {
    x = pos.x,
    y = pos.y,
    radius = 12,
    speed = data.speed,
    health = data.health,
    maxHealth = data.health,
    strength = data.strength,
    state = "patrol",
    kind = kind,
    homeX = pos.x,
    homeY = pos.y,
    path = nil,
    pathIndex = 1,
    repathTimer = 0,
    repathRate = data.repathRate,
    attackCooldown = 0,
    attackCooldownBase = data.attackCooldown,
    visionRange = data.visionRange,
    loseGrace = data.loseGrace,
    searchDuration = data.searchDuration or 2.2,
    patrolMin = data.patrolMin or 1.4,
    patrolMax = data.patrolMax or 3.8,
    kiteInRange = data.kiteInRange or 0,
    kiteOutRange = data.kiteOutRange or 0,
    kiting = false,
    windupDuration = data.windupDuration or 0.3,
    attackWindup = 0,
    attackTarget = nil,
    maxPoise = data.maxPoise or 28,
    poise = data.maxPoise or 28,
    poiseRegen = data.poiseRegen or 14,
    poiseRegenDelay = 0,
    poiseRegenDelayMax = 0.72,
    poiseBreakFlash = 0,
    loseTimer = 0,
    searchTimer = 0,
    patrolTimer = 0,
    targetX = pos.x,
    targetY = pos.y,
    lookX = 1,
    lookY = 0,
    alive = true,
    bleed = nil,
    dropHandled = false,
  }
end

function Enemies.updateAll(game, dt)
  for _, enemy in ipairs(game.enemies) do
    if enemy.alive then
      enemy.attackCooldown = math.max(0, enemy.attackCooldown - dt)
      enemy.repathTimer = math.max(0, enemy.repathTimer - dt)

      if enemy.bleed and enemy.bleed.timer > 0 then
        enemy.bleed.timer = enemy.bleed.timer - dt
        enemy.bleed.nextTick = enemy.bleed.nextTick - dt
        while enemy.bleed.nextTick <= 0 and enemy.bleed.timer > 0 and enemy.alive do
          enemy.health = enemy.health - enemy.bleed.damage
          enemy.bleed.nextTick = enemy.bleed.nextTick + enemy.bleed.tick
          if enemy.health <= 0 then
            enemy.health = 0
            enemy.alive = false
            if game.handleEnemyDefeat then
              game:handleEnemyDefeat(enemy)
            end
          end
        end
        if enemy.bleed.timer <= 0 then
          enemy.bleed = nil
        end
      end

      if not enemy.alive then
        enemy.state = "dead"
      else
        if (enemy.hitStun or 0) > 0 then
          enemy.state = "stagger"
          enemy.path = nil
          enemy.attackWindup = 0
          enemy.attackTarget = nil
        else
          local seenTarget = chooseTarget(game, enemy)
          if enemy.attackWindup <= 0 and seenTarget then
            enemy.state = "chase"
            enemy.targetX = seenTarget.x
            enemy.targetY = seenTarget.y
            local lx, ly = Math2D.normalize(seenTarget.x - enemy.x, seenTarget.y - enemy.y)
            enemy.lookX = lx
            enemy.lookY = ly
            enemy.loseTimer = 0
          elseif enemy.attackWindup <= 0 and enemy.state == "chase" then
            enemy.loseTimer = enemy.loseTimer + dt
            if enemy.loseTimer > (enemy.loseGrace or 2.0) then
              enemy.state = "search"
              enemy.searchTimer = enemy.searchDuration
            end
          end

          if enemy.attackWindup > 0 then
            enemy.state = "windup"
            local target = enemy.attackTarget
            if target and target.alive then
              local lx, ly = Math2D.normalize(target.x - enemy.x, target.y - enemy.y)
              enemy.lookX = lx
              enemy.lookY = ly
            end
          elseif enemy.state == "chase" then
            if enemy.repathTimer <= 0 then
              recalcPath(game, enemy, enemy.targetX, enemy.targetY)
              enemy.repathTimer = enemy.repathRate
            end

            if enemy.kind == "skirmisher" and seenTarget then
              local d2 = Math2D.distSq(enemy.x, enemy.y, seenTarget.x, seenTarget.y)
              if enemy.kiting then
                if d2 > (enemy.kiteOutRange * enemy.kiteOutRange) then
                  enemy.kiting = false
                end
              elseif d2 < (enemy.kiteInRange * enemy.kiteInRange) then
                enemy.kiting = true
              end

              if enemy.kiting then
                local rx, ry = Math2D.normalize(enemy.x - seenTarget.x, enemy.y - seenTarget.y)
                Movement.moveWithCollisions(game, enemy, rx * enemy.speed * dt, ry * enemy.speed * dt)
              else
                moveAlongPath(game, enemy, dt)
              end
            else
              moveAlongPath(game, enemy, dt)
            end
          elseif enemy.state == "search" then
            enemy.searchTimer = enemy.searchTimer - dt
            if enemy.repathTimer <= 0 then
              recalcPath(game, enemy, enemy.targetX, enemy.targetY)
              enemy.repathTimer = enemy.repathRate + 0.12
            end
            moveAlongPath(game, enemy, dt)
            if enemy.searchTimer <= 0 then
              enemy.state = "patrol"
              enemy.targetX = enemy.homeX
              enemy.targetY = enemy.homeY
              enemy.path = nil
              enemy.kiting = false
            end
          else
            enemy.patrolTimer = enemy.patrolTimer - dt
            if enemy.patrolTimer <= 0 then
              local wanderX = enemy.homeX + love.math.random(-95, 95)
              local wanderY = enemy.homeY + love.math.random(-95, 95)
              recalcPath(game, enemy, wanderX, wanderY)
              enemy.patrolTimer = love.math.random() * (enemy.patrolMax - enemy.patrolMin) + enemy.patrolMin
            end
            moveAlongPath(game, enemy, dt)
          end

          if enemy.attackWindup > 0 then
            enemy.attackWindup = math.max(0, enemy.attackWindup - dt)
            if enemy.attackWindup <= 0 then
              local target = enemy.attackTarget
              if target and target.alive then
                local reach = enemy.radius + target.radius + 12
                local d2 = Math2D.distSq(enemy.x, enemy.y, target.x, target.y)
                if d2 < (reach * reach) then
                  damageTarget(game, enemy, target, enemy.strength)
                  if game.impact then
                    game:impact(0.7, 0.03)
                  end
                  game.flash = 0.16
                end
              end
              enemy.attackCooldown = enemy.attackCooldownBase or 0.8
              enemy.attackTarget = nil
              if enemy.state == "windup" then
                enemy.state = "chase"
              end
            end
          elseif enemy.attackCooldown <= 0 then
            local target = chooseMeleeTarget(game, enemy)
            if target then
              enemy.attackWindup = enemy.windupDuration
              enemy.attackTarget = target
              enemy.state = "windup"
              enemy.path = nil
            end
          end
        end
      end
    end
  end
end

return Enemies
