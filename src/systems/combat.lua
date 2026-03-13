local Map = require("src.world.map")
local Math2D = require("src.core.math2d")
local Movement = require("src.core.movement")

local Combat = {}

local function attackProfile(attacker, mode)
  local isMonster = attacker.weapon == "claws"
  local heavy = mode == "heavy"

  if heavy then
    return {
      damageMult = isMonster and 1.5 or 1.45,
      damageFlat = isMonster and 2 or 0,
      cooldownMult = isMonster and 2.2 or 2.0,
      rangeFlat = isMonster and 10 or 8,
      arcMult = isMonster and 1.2 or 1.18,
      knockback = isMonster and 300 or 250,
      poiseDamage = isMonster and 28 or 24,
      breakStun = 0.28,
      hitstop = 0.058,
      anim = 0.19,
      comboStep = 0,
      comboTimer = 0,
      barricadeMult = 1.25,
    }
  end

  local comboStep = ((attacker.comboTimer or 0) > 0 and (attacker.comboStep or 0) == 1) and 2 or 1
  if comboStep == 1 then
    return {
      damageMult = isMonster and 0.9 or 0.88,
      damageFlat = 0,
      cooldownMult = 0.88,
      rangeFlat = 0,
      arcMult = isMonster and 0.95 or 0.92,
      knockback = isMonster and 190 or 155,
      poiseDamage = isMonster and 11 or 9,
      breakStun = 0.2,
      hitstop = 0.034,
      anim = 0.11,
      comboStep = 1,
      comboTimer = 0.55,
      barricadeMult = 0.95,
    }
  end

  return {
    damageMult = isMonster and 1.12 or 1.08,
    damageFlat = isMonster and 1 or 0,
    cooldownMult = 1.08,
    rangeFlat = isMonster and 4 or 5,
    arcMult = isMonster and 1.08 or 1.05,
    knockback = isMonster and 230 or 180,
    poiseDamage = isMonster and 16 or 13,
    breakStun = 0.22,
    hitstop = 0.04,
    anim = 0.13,
    comboStep = 2,
    comboTimer = 0.55,
    barricadeMult = 1.05,
  }
end

local function applyPoise(game, target, amount, breakStun)
  if game.applyPoiseHit then
    return game:applyPoiseHit(target, amount, breakStun)
  end
  return false
end

function Combat.performAttack(game, attacker, mode)
  if not attacker or not attacker.alive or attacker.attackCooldown > 0 or (attacker.hitStun or 0) > 0 then
    return
  end

  local profile = attackProfile(attacker, mode)
  local baseCooldown = attacker.attackCooldownBase or 0.35
  attacker.attackCooldown = baseCooldown * profile.cooldownMult
  attacker.attackAnim = profile.anim
  attacker.comboStep = profile.comboStep
  attacker.comboTimer = profile.comboTimer

  local arc = attacker.attackArc * profile.arcMult
  local attackRange = attacker.attackRange + profile.rangeFlat
  local maxRangeSq = attackRange * attackRange
  local fx, fy = Math2D.normalize(attacker.facingX or 1, attacker.facingY or 0)
  if fx == 0 and fy == 0 then
    fx, fy = 1, 0
  end

  for _, enemy in ipairs(game.enemies) do
    if enemy.alive then
      local vx = enemy.x - attacker.x
      local vy = enemy.y - attacker.y
      local d2 = vx * vx + vy * vy
      if d2 <= maxRangeSq then
        local nx, ny = Math2D.normalize(vx, vy)
        local dot = fx * nx + fy * ny
        local angle = math.acos(Math2D.clamp(dot, -1, 1))
        if angle <= arc * 0.5 then
          local rawDamage = (attacker.attackDamage or 1) * profile.damageMult + profile.damageFlat
          local dealt = math.max(1, math.floor(rawDamage + 0.5))
          enemy.health = enemy.health - dealt
          Movement.applyKnockback(enemy, nx, ny, profile.knockback)
          local poiseBreak = applyPoise(game, enemy, profile.poiseDamage, profile.breakStun)
          if game.impact then
            local force = (attacker == game.monster and 0.95 or 0.75) + (poiseBreak and 0.45 or 0)
            game:impact(force, enemy.health <= 0 and 0.055 or profile.hitstop)
          end
          if attacker.lifeSteal and attacker.lifeSteal > 0 then
            attacker.health = math.min(attacker.maxHealth, attacker.health + math.max(1, math.floor(dealt * attacker.lifeSteal + 0.5)))
          end

          if attacker.bleedChance and attacker.bleedChance > 0 and love.math.random() < attacker.bleedChance then
            enemy.bleed = enemy.bleed or { timer = 0, tick = 0.5, nextTick = 0.5, damage = 0 }
            enemy.bleed.timer = math.max(enemy.bleed.timer, 2.5)
            enemy.bleed.tick = 0.5
            enemy.bleed.nextTick = 0.5
            enemy.bleed.damage = math.max(enemy.bleed.damage, math.max(1, math.floor(attacker.bleedDamage or 1)))
          end

          if enemy.health <= 0 then
            enemy.health = 0
            enemy.alive = false
            if game.handleEnemyDefeat then
              game:handleEnemyDefeat(enemy)
            end
          else
            enemy.state = "chase"
          end
        end
      end
    end
  end

  if attacker == game.monster then
    for _, barricade in ipairs(game.map.barricades) do
      if not barricade.broken then
        local pos = Map.tileToWorld(barricade.tx, barricade.ty)
        local vx = pos.x - attacker.x
        local vy = pos.y - attacker.y
        if (vx * vx + vy * vy) <= maxRangeSq then
          if attacker.strength >= barricade.requiredStrength then
            local barricadeDamage = (attacker.attackDamage or 1) * (attacker.barricadeDamageMult or 1) * profile.barricadeMult
            barricade.health = barricade.health - barricadeDamage
            if game.impact then
              game:impact(mode == "heavy" and 1.0 or 0.7, mode == "heavy" and 0.04 or 0.03)
            end
            if barricade.health <= 0 then
              barricade.broken = true
              game.ui.message = "Barricade shattered. The exit path is open."
              game.ui.msgTimer = 6
            end
          else
            game.ui.message = "Monster lacks strength to break this barricade."
            game.ui.msgTimer = 2
          end
        end
      end
    end
  end
end

function Combat.updateCooldowns(game, dt)
  local entities = { game.necromancer, game.monster }
  for _, entity in ipairs(entities) do
    if entity and entity.alive then
      entity.attackCooldown = math.max(0, entity.attackCooldown - dt)
      entity.attackAnim = math.max(0, (entity.attackAnim or 0) - dt)
    end
  end
end

function Combat.drawWeapon(entity, isDigging)
  local fx, fy = Math2D.normalize(entity.facingX or 1, entity.facingY or 0)
  if fx == 0 and fy == 0 then
    fx, fy = 1, 0
  end

  local swing = (entity.attackAnim and entity.attackAnim > 0) and 1 or 0

  if isDigging and entity.weapon == "staff" then
    local digPhase = math.sin((entity.attackAnim or 0) * math.pi * 16)
    local px = -fy
    local py = fx
    local reach = entity.radius + 16 + digPhase * 6
    local sx = entity.x + px * 3
    local sy = entity.y + py * 3
    local ex = entity.x + fx * reach
    local ey = entity.y + fy * reach
    love.graphics.setColor(0.78, 0.68, 0.46)
    love.graphics.setLineWidth(3)
    love.graphics.line(sx, sy, ex, ey)
    love.graphics.setColor(0.62, 0.62, 0.65)
    love.graphics.polygon("fill", ex, ey, ex - px * 6 - fx * 3, ey - py * 6 - fy * 3, ex + px * 6 - fx * 3, ey + py * 6 - fy * 3)
    love.graphics.setLineWidth(1)
    return
  end

  if entity.weapon == "staff" then
    local reach = entity.radius + 18 + swing * 10
    local sx = entity.x + fx * (entity.radius - 2)
    local sy = entity.y + fy * (entity.radius - 2)
    local ex = entity.x + fx * reach
    local ey = entity.y + fy * reach
    love.graphics.setColor(0.82, 0.74, 0.52)
    love.graphics.setLineWidth(3)
    love.graphics.line(sx, sy, ex, ey)
    love.graphics.setColor(0.72, 0.9, 0.86)
    love.graphics.circle("fill", ex, ey, 3)
  elseif entity.weapon == "claws" then
    local px = -fy
    local py = fx
    local clawReach = entity.radius + 9 + swing * 10
    love.graphics.setColor(0.9, 0.85, 0.78)
    love.graphics.setLineWidth(2)
    for i = -1, 1 do
      local ox = px * i * 4
      local oy = py * i * 4
      local sx = entity.x + fx * (entity.radius - 3) + ox
      local sy = entity.y + fy * (entity.radius - 3) + oy
      local ex = entity.x + fx * clawReach + ox
      local ey = entity.y + fy * clawReach + oy
      love.graphics.line(sx, sy, ex, ey)
    end
  end

  love.graphics.setLineWidth(1)
end

return Combat
