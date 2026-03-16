local Map = require("src.world.map")
local Math2D = require("src.core.math2d")
local Movement = require("src.core.movement")
local Weapons = require("src.data.weapons")

local Combat = {}

local WEAPON_TILE_W = (Map.dungeonTileset and Map.dungeonTileset.tileWidth) or 16
local WEAPON_TILE_H = (Map.dungeonTileset and Map.dungeonTileset.tileHeight) or 16
local WEAPON_SPACING = (Map.dungeonTileset and Map.dungeonTileset.spacing) or 1
local WEAPON_MARGIN = (Map.dungeonTileset and Map.dungeonTileset.margin) or 0
local WEAPON_COLUMNS = (Map.dungeonTileset and Map.dungeonTileset.columns) or 12
local WEAPON_SCALE = 2
local SWING_STEPS = 7
local QUICK_STARTUP_MULT = 0.62
local QUICK_ACTIVE_MULT = 0.58
local QUICK_RECOVERY_MULT = 0.74
local QUICK_THRUST_MULT = 1.22
local STRONG_SWEEP_CURVE = 1

local function tunedTimings(attackMode, attackData)
  local startup = attackData.startup or 0
  local active = attackData.active or 0
  local recovery = attackData.recovery or 0

  if attackMode == "quick" then
    startup = startup * QUICK_STARTUP_MULT
    active = active * QUICK_ACTIVE_MULT
    recovery = recovery * QUICK_RECOVERY_MULT
  end

  startup = math.max(0.02, startup)
  active = math.max(0.03, active)
  recovery = math.max(0.03, recovery)
  return startup, active, recovery
end

local weaponSheet
local weaponQuads = {}

local function clamp01(v)
  return Math2D.clamp(v, 0, 1)
end

local function normalizeFacing(entity)
  local fx, fy = Math2D.normalize(entity.facingX or 1, entity.facingY or 0)
  if fx == 0 and fy == 0 then
    fx, fy = 1, 0
  end
  return fx, fy
end

local function distPointToSegment(px, py, ax, ay, bx, by)
  local abx = bx - ax
  local aby = by - ay
  local abLen2 = abx * abx + aby * aby
  if abLen2 <= 0.0001 then
    return math.sqrt(Math2D.distSq(px, py, ax, ay))
  end

  local apx = px - ax
  local apy = py - ay
  local t = Math2D.clamp((apx * abx + apy * aby) / abLen2, 0, 1)
  local cx = ax + abx * t
  local cy = ay + aby * t
  return math.sqrt(Math2D.distSq(px, py, cx, cy))
end

local function initWeaponSheet()
  if weaponSheet then
    return
  end

  local weaponImagePath = (Map.dungeonTileset and Map.dungeonTileset.imagePath) or "assets/dungeon_tilemap.png"
  weaponSheet = love.graphics.newImage(weaponImagePath)
  weaponSheet:setFilter("nearest", "nearest")
  weaponQuads = {}
end

local function getWeaponQuad(spriteId)
  initWeaponSheet()
  local quad = weaponQuads[spriteId]
  if quad then
    return quad
  end

  local index = math.max(1, math.floor(spriteId or 1))
  local col = (index - 1) % WEAPON_COLUMNS
  local row = math.floor((index - 1) / WEAPON_COLUMNS)
  local x = WEAPON_MARGIN + col * (WEAPON_TILE_W + WEAPON_SPACING)
  local y = WEAPON_MARGIN + row * (WEAPON_TILE_H + WEAPON_SPACING)
  quad = love.graphics.newQuad(x, y, WEAPON_TILE_W, WEAPON_TILE_H, weaponSheet:getWidth(), weaponSheet:getHeight())
  weaponQuads[spriteId] = quad
  return quad
end

local function getAttackMode(mode)
  if mode == "heavy" or mode == "strong" then
    return "strong"
  end
  return "quick"
end

local function isActiveAttack(attack)
  if not attack then
    return false
  end
  local start = attack.startup
  local finish = attack.startup + attack.active
  return attack.elapsed >= start and attack.elapsed <= finish
end

local function quantize(v, steps)
  if steps <= 1 then
    return v
  end
  return math.floor(v * steps + 0.5) / steps
end

local function resolveProfile(entity, mode)
  local weapon = Weapons.get(entity.weaponId)
  local attack = weapon[mode] or weapon.quick
  local quick = weapon.quick or attack
  local quickStartup, quickActive, quickRecovery = tunedTimings("quick", quick)
  local quickDuration = quickStartup + quickActive + quickRecovery
  local startup, active, recovery = tunedTimings(mode, attack)
  local baseArc = math.abs((quick.sweepEnd or 0) - (quick.sweepStart or 0))
  local arcScale = 1
  if (entity.baseAttackArc or 0) > 0 and entity.attackArc then
    arcScale = entity.attackArc / entity.baseAttackArc
  elseif baseArc > 0 and entity.attackArc then
    arcScale = entity.attackArc / baseArc
  end

  local configuredSweepStart = attack.sweepStart or math.rad(120)
  local configuredSweepEnd = attack.sweepEnd or math.rad(-20)
  if mode == "strong" then
    configuredSweepStart = math.rad(170)
    configuredSweepEnd = math.rad(-36)
  end

  local mid = (configuredSweepStart + configuredSweepEnd) * 0.5
  local sweepCurve = attack.sweepCurve
  if sweepCurve == nil then
    sweepCurve = (mode == "strong") and STRONG_SWEEP_CURVE or 1
  end

  local half = (configuredSweepEnd - configuredSweepStart) * 0.5 * arcScale * sweepCurve
  local sweepStart = mid - half
  local sweepEnd = mid + half
  local baseRange = entity.attackRange or weapon.reach
  local reach = baseRange * (attack.reachMult or 1)
  if mode == "strong" then
    reach = reach + 7
  end
  local total = startup + active + recovery
  local style = attack.style
  if not style then
    style = (mode == "quick") and "thrust" or "slash"
  end
  local thrustDistance = attack.thrustDistance
  if thrustDistance == nil then
    thrustDistance = math.max(10, reach * 0.5)
  end
  if style == "thrust" then
    thrustDistance = thrustDistance * QUICK_THRUST_MULT
  end

  return {
    weapon = weapon,
    mode = mode,
    startup = startup,
    active = active,
    recovery = recovery,
    duration = total,
    quickDuration = quickDuration,
    style = style,
    sweepStart = sweepStart,
    sweepEnd = sweepEnd,
    damageMult = attack.damageMult,
    damageFlat = attack.damageFlat,
    knockback = attack.knockback,
    poiseDamage = attack.poiseDamage,
    breakStun = attack.breakStun,
    hitstop = attack.hitstop,
    lunge = attack.lunge or 0,
    barricadeMult = attack.barricadeMult or 1,
    reach = reach,
    thrustDistance = thrustDistance,
    hitRadius = weapon.hitRadius or 6,
  }
end

local function getWeaponPose(entity, attack)
  local weapon = Weapons.get(entity.weaponId)
  local fx, fy = normalizeFacing(entity)
  local px, py = -fy, fx
  local rx, ry = -px, -py
  local facingAngle = math.atan2(fy, fx)

  local idle = weapon.idle or {}
  local side = idle.side or (entity.radius + 2)
  local forward = idle.forward or 0
  local handX = entity.x + px * side + fx * forward
  local handY = entity.y + py * side + fy * forward
  local angle = facingAngle + (idle.angle or math.rad(96))
  local reach = (entity.attackRange or weapon.reach)

  if attack then
    if attack.style == "thrust" then
      local rightSide = side + 1
      local rightHandX = entity.x + rx * rightSide + fx * (forward + 1)
      local rightHandY = entity.y + ry * rightSide + fy * (forward + 1)
      local activeEnd = attack.startup + attack.active
      local outTime = attack.startup + attack.active * 0.65
      local dart
      if attack.elapsed <= outTime then
        dart = clamp01(attack.elapsed / math.max(0.0001, outTime))
      elseif attack.elapsed <= activeEnd then
        dart = 1
      else
        dart = 1 - clamp01((attack.elapsed - activeEnd) / math.max(0.0001, attack.recovery))
      end
      dart = quantize(dart, SWING_STEPS)

      local thrust = (attack.thrustDistance or 0) * dart
      handX = rightHandX + fx * thrust
      handY = rightHandY + fy * thrust
      angle = facingAngle + math.rad(2)
      reach = attack.reach
    else
      local sweepWindow = attack.startup + attack.active
      local sweepT = 1
      if sweepWindow > 0 then
        sweepT = clamp01(attack.elapsed / sweepWindow)
      end
      sweepT = quantize(sweepT, SWING_STEPS)

      local sweep = attack.sweepStart + (attack.sweepEnd - attack.sweepStart) * sweepT
      local lunge = math.sin(clamp01(attack.elapsed / attack.duration) * math.pi) * (attack.lunge or 0)
      handX = handX + fx * lunge
      handY = handY + fy * lunge
      angle = facingAngle + sweep
      reach = attack.reach
    end
  end

  local tipX = handX + math.cos(angle) * reach
  local tipY = handY + math.sin(angle) * reach
  return {
    handX = handX,
    handY = handY,
    tipX = tipX,
    tipY = tipY,
    angle = angle,
    reach = reach,
  }
end

local function applyPoise(game, target, amount, breakStun)
  if game.applyPoiseHit then
    return game:applyPoiseHit(target, amount, breakStun)
  end
  return false
end

local function applyTargetHit(game, attacker, target, attack)
  if not target or not target.alive then
    return
  end

  local rawDamage = (attacker.attackDamage or 1) * (attack.damageMult or 1) + (attack.damageFlat or 0)
  local dealt = math.max(1, math.floor(rawDamage + 0.5))
  target.health = target.health - dealt

  local nx, ny = Math2D.normalize(target.x - attacker.x, target.y - attacker.y)
  Movement.applyKnockback(target, nx, ny, attack.knockback or 140)
  local poiseBreak = applyPoise(game, target, attack.poiseDamage or 10, attack.breakStun or 0.2)

  if game.impact then
    local force = (attacker == game.monster and 0.95 or 0.75) + (poiseBreak and 0.45 or 0)
    game:impact(force, target.health <= 0 and 0.055 or (attack.hitstop or 0.03))
  end

  if attacker.lifeSteal and attacker.lifeSteal > 0 then
    attacker.health = math.min(attacker.maxHealth, attacker.health + math.max(1, math.floor(dealt * attacker.lifeSteal + 0.5)))
  end

  if attacker.bleedChance and attacker.bleedChance > 0 and love.math.random() < attacker.bleedChance then
    target.bleed = target.bleed or { timer = 0, tick = 0.5, nextTick = 0.5, damage = 0 }
    target.bleed.timer = math.max(target.bleed.timer, 2.5)
    target.bleed.tick = 0.5
    target.bleed.nextTick = 0.5
    target.bleed.damage = math.max(target.bleed.damage, math.max(1, math.floor(attacker.bleedDamage or 1)))
  end

  if target.health <= 0 then
    target.health = 0
    target.alive = false
    if game.handleEnemyDefeat then
      game:handleEnemyDefeat(target)
    end
  else
    target.state = "chase"
  end
end

local function attackHitsTarget(prevPose, pose, target, hitRadius)
  local sampleCount = 4
  for i = 0, sampleCount do
    local t = i / sampleCount
    local handX = prevPose.handX + (pose.handX - prevPose.handX) * t
    local handY = prevPose.handY + (pose.handY - prevPose.handY) * t
    local tipX = prevPose.tipX + (pose.tipX - prevPose.tipX) * t
    local tipY = prevPose.tipY + (pose.tipY - prevPose.tipY) * t
    local dist = distPointToSegment(target.x, target.y, handX, handY, tipX, tipY)
    if dist <= (target.radius or 10) + hitRadius then
      return true
    end
  end
  return false
end

local function hitEnemies(game, attacker, attack, prevPose, pose)
  for _, enemy in ipairs(game.enemies or {}) do
    if enemy.alive and not attack.hitTargets[enemy] then
      if attackHitsTarget(prevPose, pose, enemy, attack.hitRadius) then
        attack.hitTargets[enemy] = true
        applyTargetHit(game, attacker, enemy, attack)
      end
    end
  end
end

local function hitBarricades(game, attacker, attack, pose)
  if attacker ~= game.monster then
    return
  end

  for _, barricade in ipairs(game.map.barricades or {}) do
    if not barricade.broken and not attack.hitBarricades[barricade] then
      local pos = Map.tileToWorld(barricade.tx, barricade.ty)
      local reach = attack.reach + 10
      if Math2D.distSq(pose.tipX, pose.tipY, pos.x, pos.y) <= reach * reach then
        attack.hitBarricades[barricade] = true
        if attacker.strength >= barricade.requiredStrength then
          local damage = (attacker.attackDamage or 1) * (attacker.barricadeDamageMult or 1) * (attack.barricadeMult or 1)
          barricade.health = barricade.health - damage
          if game.impact then
            game:impact(attack.mode == "strong" and 1.0 or 0.7, attack.mode == "strong" and 0.04 or 0.03)
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

local function updateAttack(game, entity, dt)
  local attack = entity.attackState
  if not attack then
    return
  end

  attack.elapsed = math.min(attack.duration, attack.elapsed + dt)
  local pose = getWeaponPose(entity, attack)

  if isActiveAttack(attack) then
    local prevPose = attack.prevPose or pose
    hitEnemies(game, entity, attack, prevPose, pose)
    hitBarricades(game, entity, attack, pose)
    attack.prevPose = pose
  else
    attack.prevPose = nil
  end

  if attack.elapsed >= attack.duration then
    entity.attackState = nil
  end
end

function Combat.equipWeapon(entity, weaponId)
  if not entity then
    return nil
  end

  local weapon = Weapons.get(weaponId)
  entity.weaponId = weapon.id

  entity.baseAttackRange = weapon.reach
  entity.baseAttackArc = math.abs((weapon.quick and weapon.quick.sweepEnd or 0) - (weapon.quick and weapon.quick.sweepStart or 0))
  entity.baseAttackCooldown = (weapon.quick and (weapon.quick.startup + weapon.quick.active + weapon.quick.recovery)) or 0.3

  entity.attackRange = entity.baseAttackRange
  entity.attackArc = entity.baseAttackArc
  entity.attackCooldownBase = entity.baseAttackCooldown
  return weapon
end

function Combat.performAttack(game, attacker, mode)
  if not attacker or not attacker.alive or attacker.attackCooldown > 0 or (attacker.hitStun or 0) > 0 or attacker.attackState then
    return
  end

  local attackMode = getAttackMode(mode)
  local profile = resolveProfile(attacker, attackMode)

  local cooldownBase = attacker.attackCooldownBase or profile.quickDuration
  local cooldownScale = profile.quickDuration > 0 and (profile.duration / profile.quickDuration) or 1
  local cooldown = cooldownBase * cooldownScale

  attacker.attackCooldown = cooldown
  attacker.attackState = {
    mode = attackMode,
    elapsed = 0,
    startup = profile.startup,
    active = profile.active,
    recovery = profile.recovery,
    duration = profile.duration,
    sweepStart = profile.sweepStart,
    sweepEnd = profile.sweepEnd,
    damageMult = profile.damageMult,
    damageFlat = profile.damageFlat,
    knockback = profile.knockback,
    poiseDamage = profile.poiseDamage,
    breakStun = profile.breakStun,
    hitstop = profile.hitstop,
    lunge = profile.lunge,
    barricadeMult = profile.barricadeMult,
    reach = profile.reach,
    hitRadius = profile.hitRadius,
    hitTargets = {},
    hitBarricades = {},
    prevPose = nil,
  }
end

function Combat.updateCooldowns(game, dt)
  local entities = { game.necromancer, game.monster }
  for _, entity in ipairs(entities) do
    if entity and entity.alive then
      entity.attackCooldown = math.max(0, (entity.attackCooldown or 0) - dt)
      updateAttack(game, entity, dt)
    end
  end
end

function Combat.drawWeapon(entity)
  if not entity or not entity.alive then
    return
  end

  local weapon = Weapons.get(entity.weaponId)
  local pose = getWeaponPose(entity, entity.attackState)
  Combat.drawWeaponSprite(weapon.spriteId, pose.handX, pose.handY, pose.angle, WEAPON_SCALE, 5, 11)
end

function Combat.drawWeaponSprite(spriteId, x, y, angle, scale, ox, oy)
  initWeaponSheet()
  local quad = getWeaponQuad(spriteId)
  local drawScale = scale or WEAPON_SCALE

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    weaponSheet,
    quad,
    x,
    y,
    angle or 0,
    drawScale,
    drawScale,
    ox or 5,
    oy or 11
  )
end

return Combat
