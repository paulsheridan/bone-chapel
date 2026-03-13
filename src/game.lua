local Map = require("src.world.map")
local BodyParts = require("src.data.body_parts")
local GearLoot = require("src.data.gear_loot")
local BuildMenu = require("src.ui.build_menu")
local Math2D = require("src.core.math2d")
local Display = require("src.core.display")
local Movement = require("src.core.movement")
local MonsterMods = require("src.systems.monster_mods")

local Camera = require("src.systems.camera")
local Combat = require("src.systems.combat")
local Enemies = require("src.systems.enemies")
local Interactions = require("src.systems.interactions")
local Player = require("src.systems.player")
local Rendering = require("src.systems.rendering")

local Game = {
  state = "playing",
}

local BALANCE = {
  drops = {
    baseChance = 0.52,
    pityBonusPerMiss = 0.1,
    maxPityBonus = 0.32,
    kindBonus = {
      brute = 0.12,
      hunter = 0.07,
      skirmisher = 0.03,
    },
    missingCategoryWeight = 2.3,
    ownedCategoryWeight = 1.0,
    duplicateItemWeightScale = 0.45,
  },
  tether = {
    nearDistance = 110,
    farDistance = 430,
    baseRegen = 5.2,
    controlledRegenScale = 0.45,
    controlledBaseDrain = 2.1,
    controlledDistanceDrain = 5.4,
    idleDistanceDrain = 0.9,
    snapHealthPenalty = 6,
  },
  combat = {
    poiseBreakStun = 0.2,
    poiseBreakFlash = 0.35,
    poiseRegenDelay = 0.72,
    wallSlamSpeed = 140,
    wallSlamMaxDamage = 7,
  },
}

local function newNecromancer(start)
  return {
    x = start.x,
    y = start.y,
    radius = 11,
    speed = 230,
    strength = 12,
    health = 100,
    maxHealth = 100,
    attackCooldown = 0,
    attackRange = 58,
    attackArc = math.rad(55),
    attackDamage = 24,
    weapon = "staff",
    facingX = 0,
    facingY = 1,
    attackAnim = 0,
    comboStep = 0,
    comboTimer = 0,
    maxPoise = 34,
    poise = 34,
    poiseRegen = 12,
    poiseRegenDelay = 0,
    poiseRegenDelayMax = BALANCE.combat.poiseRegenDelay,
    poiseBreakFlash = 0,
    alive = true,
  }
end

local function pickPartForSlot(slot)
  local list = BodyParts[slot]
  local idx = love.math.random(1, #list)
  return list[idx]
end

local function cloneEquippedParts(equipped)
  local copy = {}
  for _, slot in ipairs(BodyParts.slotOrder) do
    copy[slot] = equipped[slot]
  end
  return copy
end

local function weightedChoice(list, weightFn)
  if #list == 0 then
    return nil
  end

  local total = 0
  for i, entry in ipairs(list) do
    local w = weightFn(entry, i) or 0
    if w > 0 then
      total = total + w
    end
  end

  if total <= 0 then
    return list[love.math.random(1, #list)]
  end

  local roll = love.math.random() * total
  local acc = 0
  for i, entry in ipairs(list) do
    local w = weightFn(entry, i) or 0
    if w > 0 then
      acc = acc + w
      if roll <= acc then
        return entry
      end
    end
  end

  return list[#list]
end

local function pickGearDrop(game, enemy)
  local drop = game.drop or { sinceGear = 0 }
  local missCount = drop.sinceGear or 0
  local pity = math.min(BALANCE.drops.maxPityBonus, missCount * BALANCE.drops.pityBonusPerMiss)
  local chance = BALANCE.drops.baseChance + pity + (BALANCE.drops.kindBonus[enemy.kind or ""] or 0)
  if love.math.random() > chance then
    return nil, nil
  end

  local category = weightedChoice(GearLoot.categoryOrder, function(cat)
    if game.gear and game.gear.equipped and game.gear.equipped[cat] then
      return BALANCE.drops.ownedCategoryWeight
    end
    return BALANCE.drops.missingCategoryWeight
  end)

  local pool = GearLoot[category] or {}
  local item = weightedChoice(pool, function(entry)
    local baseWeight = entry.weight or 1
    if game.gear and game.gear.owned and game.gear.owned[category] and game.gear.owned[category][entry.id] then
      return baseWeight * BALANCE.drops.duplicateItemWeightScale
    end
    return baseWeight
  end)
  return category, item
end

local function findGearItem(category, itemId)
  local pool = GearLoot[category]
  if not pool or not itemId then
    return nil
  end
  for _, item in ipairs(pool) do
    if item.id == itemId then
      return item
    end
  end
  return nil
end

local function choosePreferredController()
  local joysticks = love.joystick.getJoysticks()
  local fallback
  for _, joystick in ipairs(joysticks) do
    if joystick:isConnected() then
      if joystick:isGamepad() then
        return joystick
      end
      if not fallback then
        fallback = joystick
      end
    end
  end
  return fallback
end

local function mapGamepadButtonToKey(game, button)
  if button == "a" then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "return"
    end
    return "space"
  elseif button == "x" then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "a"
    end
    return "k"
  elseif button == "b" then
    return "e"
  elseif button == "y" or button == "back" then
    return "tab"
  elseif button == "start" then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "a"
    end
    return "tab"
  elseif button == "leftshoulder" or button == "rightshoulder" then
    return "q"
  elseif button == "dpup" then
    return "up"
  elseif button == "dpdown" then
    return "down"
  elseif button == "dpleft" then
    return "left"
  elseif button == "dpright" then
    return "right"
  end
  return nil
end

local function mapJoystickButtonToKey(game, button)
  if button == 1 then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "return"
    end
    return "space"
  elseif button == 2 then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "a"
    end
    return "k"
  elseif button == 3 then
    return "e"
  elseif button == 4 or button == 7 then
    return "tab"
  elseif button == 5 or button == 6 then
    return "q"
  elseif button == 8 then
    if game.ui and game.ui.menu and game.ui.menu.open then
      return "a"
    end
    return "tab"
  end
  return nil
end

function Game:setActiveController(joystick)
  self.activePad = joystick
  self.controllerName = joystick and joystick:getName() or nil
end

function Game.load()
  Game.map = Map.load()
  Game.necromancer = newNecromancer(Game.map.start)
  Game.monster = nil
  Game.controlled = "necromancer"

  Game.inventory = {}
  for _, slot in ipairs(BodyParts.slotOrder) do
    Game.inventory[slot] = {}
  end

  Game.build = {
    equipped = {
      head = nil,
      torso = nil,
      left_arm = nil,
      right_arm = nil,
      left_leg = nil,
      right_leg = nil,
    },
  }

  Game.ui = {
    menu = BuildMenu.new(),
    message = "Home is now the Hill Chapel. Recover parts and use the chapel stitching altar to build your monster.",
    msgTimer = 9,
    dialog = nil,
    dig = nil,
  }

  local startZoneX, startZoneY = Map.getZoneForWorld(Game.map, Game.necromancer.x, Game.necromancer.y)
  Game.camera = { x = 0, y = 0 }
  Game.zone = {
    x = startZoneX,
    y = startZoneY,
    transitioning = false,
    t = 0,
    duration = 0.38,
    fromX = 0,
    fromY = 0,
    toX = 0,
    toY = 0,
  }

  Game.enemies = {}
  for _, pos in ipairs(Game.map.enemies) do
    table.insert(Game.enemies, Enemies.create(pos))
  end

  Game.win = false
  Game.lose = false
  Game.hitstop = 0
  Game.flash = 0
  Game.warpCooldown = 0
  Game.gear = {
    equipped = { armor = nil, tools = nil, weapons = nil },
    owned = { armor = {}, tools = {}, weapons = {} },
  }
  Game.drop = {
    sinceGear = 0,
  }
  Game.tether = {
    max = 100,
    value = 100,
  }
  Game.debug = {
    enabled = false,
    showPaths = false,
    showLOS = false,
    suppressEnemies = false,
    storedEnemies = nil,
  }
  Game:setActiveController(choosePreferredController())

  Camera.initAtStart(Game, startZoneX, startZoneY, Game.necromancer.x, Game.necromancer.y)
end

function Game:impact(power, hitstop)
  local p = power or 1
  local stop = hitstop or (0.02 + 0.02 * p)
  self.hitstop = math.max(self.hitstop or 0, stop)
  Camera.kick(self, 1.6 + 2.2 * p, 0.12)
end

function Game:applyPoiseHit(target, amount, breakStun)
  if not target or not target.alive or not target.maxPoise then
    return false
  end

  target.poise = (target.poise or target.maxPoise) - (amount or 0)
  target.poiseRegenDelay = target.poiseRegenDelayMax or BALANCE.combat.poiseRegenDelay
  if target.poise <= 0 then
    target.poise = target.maxPoise
    target.hitStun = math.max(target.hitStun or 0, breakStun or BALANCE.combat.poiseBreakStun)
    target.poiseBreakFlash = BALANCE.combat.poiseBreakFlash
    return true
  end
  return false
end

function Game:refreshMonsterStats()
  if not self.monster or not self.monster.alive then
    return
  end

  local stability = 1
  if self.tether and self.tether.max > 0 then
    stability = Math2D.clamp(self.tether.value / self.tether.max, 0, 1)
  end

  local projected = MonsterMods.projectStats(self.monster.baseStats, self.monster.parts or self.build.equipped, self.gear.equipped, stability)
  local profile = projected.profile
  local mods = profile.mods

  local oldMax = self.monster.maxHealth or projected.health
  local oldHealth = self.monster.health or oldMax
  local ratio = oldMax > 0 and Math2D.clamp(oldHealth / oldMax, 0, 1) or 1

  self.monster.maxHealth = projected.health
  self.monster.health = math.max(1, math.floor(self.monster.maxHealth * ratio + 0.5))
  self.monster.speed = Math2D.clamp(projected.speed, 70, 240)
  self.monster.strength = projected.strength

  local powerPenalty = 1 + (1 - stability) * 0.35
  local baseDamage = (projected.strength + (mods.attackDamageFlat or 0)) * (mods.attackDamageMult or 1)
  self.monster.attackDamage = math.max(1, math.floor(baseDamage + 0.5))
  self.monster.attackRange = self.monster.baseAttackRange + (mods.attackRangeFlat or 0)
  self.monster.attackArc = self.monster.baseAttackArc * (mods.attackArcMult or 1)
  self.monster.attackCooldownBase = self.monster.baseAttackCooldown * (mods.attackCooldownMult or 1) * powerPenalty
  self.monster.damageReduction = mods.damageReduction or 0
  self.monster.barricadeDamageMult = mods.barricadeDamageMult or 1
  self.monster.bleedChance = mods.bleedChance or 0
  self.monster.bleedDamage = mods.bleedDamage or 0
  self.monster.lifeSteal = mods.lifeSteal or 0
  self.monster.tetherDrainMult = mods.tetherDrainMult or 1
  self.monster.tetherRegenFlat = mods.tetherRegenFlat or 0
  self.monster.activeTraits = profile.traits
  self.monster.activeSets = profile.sets

  local oldPoiseMax = self.monster.maxPoise or 1
  local oldPoise = self.monster.poise or oldPoiseMax
  local poiseRatio = Math2D.clamp(oldPoise / oldPoiseMax, 0, 1)
  self.monster.maxPoise = math.max(24, math.floor(16 + self.monster.strength * 1.35 + self.monster.maxHealth * 0.08))
  self.monster.poise = Math2D.clamp(self.monster.maxPoise * poiseRatio, 0, self.monster.maxPoise)
  self.monster.poiseRegen = 14
  self.monster.poiseRegenDelayMax = BALANCE.combat.poiseRegenDelay
end

function Game:getControlledEntity()
  if self.controlled == "monster" and self.monster and self.monster.alive then
    return self.monster
  end
  return self.necromancer
end

function Game:addPart(slot)
  local part = pickPartForSlot(slot)
  table.insert(self.inventory[slot], part)
  self.ui.message = "Collected " .. BodyParts.slotNames[slot] .. ": " .. part.name
  self.ui.msgTimer = 4
end

function Game:addGear(category, item)
  if not self.gear or not category or not item then
    return
  end
  self.gear.owned[category][item.id] = item
  self.gear.equipped[category] = item
  self.ui.message = string.format("Recovered %s: %s (equipped)", GearLoot.categoryNames[category] or category, item.name)
  self.ui.msgTimer = 3.5
  if self.monster and self.monster.alive then
    self:refreshMonsterStats()
  end
end

function Game:handleEnemyDefeat(enemy)
  if not enemy or enemy.dropHandled then
    return
  end
  enemy.dropHandled = true

  self.drop.sinceGear = (self.drop.sinceGear or 0) + 1
  local category, item = pickGearDrop(self, enemy)
  if not category or not item then
    return
  end

  self.drop.sinceGear = 0
  table.insert(self.map.pickups, {
    x = enemy.x + love.math.random(-6, 6),
    y = enemy.y + love.math.random(-6, 6),
    kind = "gear",
    category = category,
    item = item,
    taken = false,
  })
end

local function isEnemyEntity(game, entity)
  for _, enemy in ipairs(game.enemies or {}) do
    if enemy == entity then
      return true
    end
  end
  return false
end

function Game:handleWallSlam(entity, speed)
  if not entity or not entity.alive then
    return
  end

  if speed < BALANCE.combat.wallSlamSpeed then
    return
  end

  entity.slamCooldown = 0.35
  local raw = (speed - BALANCE.combat.wallSlamSpeed) / 65
  local damage = Math2D.clamp(math.floor(raw + 1.5), 1, BALANCE.combat.wallSlamMaxDamage)

  entity.health = entity.health - damage
  entity.hitStun = math.max(entity.hitStun or 0, 0.16)
  self:applyPoiseHit(entity, 12 + damage * 2, 0.24)
  self:impact(0.8, 0.03)

  if entity.health <= 0 then
    entity.health = 0
    entity.alive = false
    if isEnemyEntity(self, entity) then
      self:handleEnemyDefeat(entity)
    end
  end
end

function Game:assembleMonster()
  local buildSpot = self.map and self.map.buildSpot
  local actor = (self.getControlledEntity and self:getControlledEntity()) or self.necromancer
  if not buildSpot then
    self.ui.message = "No stitching altar is configured."
    self.ui.msgTimer = 3
    return
  end
  local buildRange = buildSpot.radius or 40
  if not actor or not actor.alive or Math2D.distSq(actor.x, actor.y, buildSpot.x, buildSpot.y) > buildRange * buildRange then
    self.ui.message = "You can only assemble a monster at the Hill Chapel stitching altar."
    self.ui.msgTimer = 3
    return
  end

  if not BuildMenu.requiredComplete(self.build.equipped) then
    self.ui.message = "Assembly failed: all six body slots are required."
    self.ui.msgTimer = 3
    return
  end

  local stats = { speed = 78, strength = 16, health = 75 }
  for _, slot in ipairs(BodyParts.slotOrder) do
    local p = self.build.equipped[slot]
    stats.speed = stats.speed + p.stats.speed
    stats.strength = stats.strength + p.stats.strength
    stats.health = stats.health + p.stats.health
  end

  local spawnX = self.necromancer.x + 26
  local spawnY = self.necromancer.y
  if Map.entityCollides(self.map, spawnX, spawnY, 14) then
    spawnX = self.necromancer.x - 26
  end

  local parts = cloneEquippedParts(self.build.equipped)

  self.monster = {
    x = spawnX,
    y = spawnY,
    radius = 14,
    speed = Math2D.clamp(stats.speed, 70, 220),
    strength = stats.strength,
    health = stats.health,
    maxHealth = stats.health,
    attackCooldown = 0,
    attackRange = 42,
    attackArc = math.rad(102),
    attackDamage = stats.strength,
    attackCooldownBase = 0.35,
    baseAttackCooldown = 0.35,
    baseAttackRange = 42,
    baseAttackArc = math.rad(102),
    weapon = "claws",
    facingX = self.necromancer.facingX or 0,
    facingY = self.necromancer.facingY or 1,
    attackAnim = 0,
    comboStep = 0,
    comboTimer = 0,
    alive = true,
    parts = parts,
    baseStats = {
      speed = stats.speed,
      strength = stats.strength,
      health = stats.health,
    },
  }

  self:refreshMonsterStats()
  self.monster.health = self.monster.maxHealth

  self.ui.message = "Monster assembled. Press Q to designate control."
  self.ui.msgTimer = 4
end

function Game:toggleControl()
  if not self.monster or not self.monster.alive then
    self.ui.message = "No active monster to designate."
    self.ui.msgTimer = 3
    return
  end
  if not self.necromancer.alive then
    return
  end

  if self.controlled == "necromancer" then
    self.controlled = "monster"
    self.ui.message = "Controlling Monster. Necromancer body is vulnerable."
  else
    self.controlled = "necromancer"
    self.ui.message = "Returned to Necromancer."
  end

  local controlled = self:getControlledEntity()
  local zx, zy = Map.getZoneForWorld(self.map, controlled.x, controlled.y)
  if zx ~= self.zone.x or zy ~= self.zone.y then
    local viewW, viewH = Display.getLogicalSize()
    Camera.beginZonePan(self, zx, zy, controlled.x - viewW * 0.5, controlled.y - viewH * 0.5)
  end

  self.ui.msgTimer = 3
end

function Game:toggleEnemySuppression()
  if not self.debug then
    return
  end

  self.debug.suppressEnemies = not self.debug.suppressEnemies
  if self.debug.suppressEnemies then
    self.debug.storedEnemies = self.enemies
    self.enemies = {}
    self.ui.message = "Enemy suppression ON (F6)."
  else
    self.enemies = self.debug.storedEnemies or self.enemies or {}
    self.debug.storedEnemies = nil
    self.ui.message = "Enemy suppression OFF (F6)."
  end

  self.ui.msgTimer = 2.6
end

local function collectPickups(game)
  local collector = (game.getControlledEntity and game:getControlledEntity()) or game.necromancer
  if not collector or not collector.alive then
    return
  end
  for _, pickup in ipairs(game.map.pickups) do
    if not pickup.taken and Math2D.distSq(collector.x, collector.y, pickup.x, pickup.y) < 20 * 20 then
      pickup.taken = true
      if pickup.kind == "gear" then
        if pickup.category and pickup.item then
          game:addGear(pickup.category, pickup.item)
        elseif pickup.category and pickup.itemId then
          local item = findGearItem(pickup.category, pickup.itemId)
          if item then
            game:addGear(pickup.category, item)
          end
        end
      else
        game:addPart(pickup.slot)
      end
    end
  end
end

local function updateTether(game, dt)
  if not game.tether or not game.monster or not game.monster.alive or not game.necromancer.alive then
    return
  end

  local d = math.sqrt(Math2D.distSq(game.necromancer.x, game.necromancer.y, game.monster.x, game.monster.y))
  local nearDist = BALANCE.tether.nearDistance
  local farDist = BALANCE.tether.farDistance
  local distanceFactor = Math2D.clamp((d - nearDist) / (farDist - nearDist), 0, 1)

  local drain = 0
  local regen = BALANCE.tether.baseRegen + (game.monster.tetherRegenFlat or 0)
  if game.controlled == "monster" then
    drain = BALANCE.tether.controlledBaseDrain + distanceFactor * BALANCE.tether.controlledDistanceDrain
    regen = regen * BALANCE.tether.controlledRegenScale
  else
    drain = distanceFactor * BALANCE.tether.idleDistanceDrain
  end

  drain = drain * (game.monster.tetherDrainMult or 1)
  game.tether.value = Math2D.clamp(game.tether.value + (regen - drain) * dt, 0, game.tether.max)

  if game.tether.value <= 0 and game.controlled == "monster" then
    game.controlled = "necromancer"
    game.ui.message = "Ritual tether snaps. Control returns to the necromancer."
    game.ui.msgTimer = 3
    game.flash = 0.2
    game.necromancer.health = math.max(1, game.necromancer.health - BALANCE.tether.snapHealthPenalty)
  end

  game:refreshMonsterStats()
end

local function updateKnockbackActors(game, dt)
  Movement.updateKnockback(game, game.necromancer, dt)
  if game.monster then
    Movement.updateKnockback(game, game.monster, dt)
  end
  for _, enemy in ipairs(game.enemies) do
    Movement.updateKnockback(game, enemy, dt)
  end
end

local function updatePoiseActor(entity, dt)
  if not entity or entity.alive == false or not entity.maxPoise then
    return
  end

  entity.comboTimer = math.max(0, (entity.comboTimer or 0) - dt)
  if entity.comboTimer <= 0 then
    entity.comboStep = 0
  end

  entity.poiseBreakFlash = math.max(0, (entity.poiseBreakFlash or 0) - dt)
  entity.poiseRegenDelay = math.max(0, (entity.poiseRegenDelay or 0) - dt)
  if entity.poiseRegenDelay <= 0 then
    entity.poise = Math2D.clamp((entity.poise or entity.maxPoise) + (entity.poiseRegen or 0) * dt, 0, entity.maxPoise)
  end
end

local function updatePoiseActors(game, dt)
  updatePoiseActor(game.necromancer, dt)
  if game.monster then
    updatePoiseActor(game.monster, dt)
  end
  for _, enemy in ipairs(game.enemies) do
    updatePoiseActor(enemy, dt)
  end
end

local function checkWinLose(game)
  if not game.necromancer.alive then
    game.lose = true
  end
  if game.map.exit and game.necromancer.alive then
    local exitPos = Map.tileToWorld(game.map.exit.tx, game.map.exit.ty)
    if Math2D.distSq(game.necromancer.x, game.necromancer.y, exitPos.x, exitPos.y) < 15 * 15 then
      game.win = true
    end
  end
end

function Game.update(dt)
  if Game.win or Game.lose then
    return
  end

  if Game.activePad and not Game.activePad:isConnected() then
    Game:setActiveController(choosePreferredController())
  end

  Camera.updateShake(Game, dt)
  if (Game.hitstop or 0) > 0 then
    Game.hitstop = math.max(0, Game.hitstop - dt)
    dt = 0
  end

  updateTether(Game, dt)
  updateKnockbackActors(Game, dt)
  updatePoiseActors(Game, dt)

  if Game.ui.menu.open then
    Game.ui.msgTimer = math.max(0, Game.ui.msgTimer - dt)
    Camera.update(Game, dt)
    return
  end

  Game.flash = math.max(0, Game.flash - dt)
  Game.ui.msgTimer = math.max(0, Game.ui.msgTimer - dt)

  local controlled = Game:getControlledEntity()
  local blockedByInteraction = (Game.ui.dialog ~= nil) or (Game.ui.dig ~= nil)
  if not Game.zone.transitioning and not blockedByInteraction then
    Player.updateControl(Game, controlled, dt, Movement.moveWithCollisions, Combat.performAttack, Camera.tryZoneTransition)
  end

  Interactions.updateDigging(Game, dt)
  Interactions.updateWarpTouch(Game, dt)

  Enemies.updateAll(Game, dt)

  Combat.updateCooldowns(Game, dt)
  collectPickups(Game)
  checkWinLose(Game)
  Camera.update(Game, dt)

  if Game.controlled == "monster" and (not Game.monster or not Game.monster.alive) then
    Game.controlled = "necromancer"
  end
end

function Game.draw()
  love.graphics.push()
  love.graphics.translate(-(Game.camera.x + (Game.camera.shakeX or 0)), -(Game.camera.y + (Game.camera.shakeY or 0)))
  Rendering.drawWorld(Game)
  love.graphics.pop()

  Rendering.drawHUD(Game)
  BuildMenu.draw(Game.ui.menu, Game)
end

function Game.keypressed(key)
  if key == "f3" then
    Game.debug.enabled = not Game.debug.enabled
    if not Game.debug.enabled then
      Game.debug.showPaths = false
      Game.debug.showLOS = false
    end
    return
  elseif key == "f4" then
    Game.debug.showPaths = not Game.debug.showPaths
    Game.debug.enabled = Game.debug.showPaths or Game.debug.enabled
    return
  elseif key == "f5" then
    Game.debug.showLOS = not Game.debug.showLOS
    Game.debug.enabled = Game.debug.showLOS or Game.debug.enabled
    return
  elseif key == "f6" then
    Game:toggleEnemySuppression()
    return
  end

  if key == "r" and (Game.win or Game.lose) then
    Game.load()
    return
  end

  if Interactions.handleDialogKey(Game, key) then
    return
  end

  if BuildMenu.keypressed(Game.ui.menu, Game, key) then
    return
  end

  if key == "tab" then
    if not Game.ui.dig then
      Game.ui.message = "Use E at the Hill Chapel stitching altar to open stitching."
      Game.ui.msgTimer = 2.2
    end
  elseif key == "q" then
    if not Game.ui.dig then
      Game:toggleControl()
    end
  elseif key == "e" then
    Interactions.interact(Game)
  elseif key == "j" or key == "space" or key == "k" then
    if not Game.ui.menu.open and not Game.zone.transitioning and not Game.ui.dig and not Game.ui.dialog then
      local entity = Game:getControlledEntity()
      local mode = (key == "k") and "heavy" or "light"
      Combat.performAttack(Game, entity, mode)
    end
  elseif key == "a" and Game.ui.menu.open then
    Game:assembleMonster()
  end
end

function Game.joystickadded(joystick)
  if not Game.activePad or not Game.activePad:isConnected() then
    Game:setActiveController(joystick)
    return
  end
  if joystick:isGamepad() and not Game.activePad:isGamepad() then
    Game:setActiveController(joystick)
  end
end

function Game.joystickremoved(joystick)
  if Game.activePad == joystick then
    Game:setActiveController(choosePreferredController())
  end
end

function Game.gamepadpressed(joystick, button)
  if not joystick then
    return
  end
  if joystick ~= Game.activePad then
    Game:setActiveController(joystick)
  end
  local key = mapGamepadButtonToKey(Game, button)
  if key then
    Game.keypressed(key)
  end
end

function Game.joystickpressed(joystick, button)
  if not joystick or joystick:isGamepad() then
    return
  end
  if joystick ~= Game.activePad then
    Game:setActiveController(joystick)
  end
  local key = mapJoystickButtonToKey(Game, button)
  if key then
    Game.keypressed(key)
  end
end

function Game.mousepressed(x, y, button)
  BuildMenu.mousepressed(Game.ui.menu, Game, x, y, button)
end

return Game
