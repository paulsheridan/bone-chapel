local Map = require("src.world.map")
local LOS = require("src.ai.los")
local BodyParts = require("src.data.body_parts")
local GearLoot = require("src.data.gear_loot")
local Combat = require("src.systems.combat")
local Display = require("src.core.display")

local Rendering = {}

local CHARACTER_TILE_W = 16
local CHARACTER_TILE_H = 16
local CHARACTER_SPACING = 1
local CHARACTER_MARGIN = 0
local CHARACTER_SET_INDEX = 6
local CHARACTER_SCALE = 2
local HIDE_UI_OVERLAY_FOR_TESTING = true

local ENEMY_CHARACTER_SET = {
  brute = 1,
  hunter = 2,
  skirmisher = 3,
}

local characterSheet
local characterQuadCache

local function initCharacterSheet()
  if characterSheet then
    return
  end

  characterSheet = love.graphics.newImage("assets/Characters.png")
  characterSheet:setFilter("nearest", "nearest")

  characterQuadCache = {}
end

local function getCharacterQuads(setIndex)
  initCharacterSheet()
  if characterQuadCache[setIndex] then
    return characterQuadCache[setIndex]
  end

  local dirColumns = {
    left = 0,
    down = 1,
    up = 2,
    right = 3,
  }

  local setStartRow = (setIndex - 1) * 3
  local quads = {}
  for dir, col in pairs(dirColumns) do
    quads[dir] = {}
    for row = 0, 2 do
      local x = CHARACTER_MARGIN + col * (CHARACTER_TILE_W + CHARACTER_SPACING)
      local y = CHARACTER_MARGIN + (setStartRow + row) * (CHARACTER_TILE_H + CHARACTER_SPACING)
      quads[dir][row + 1] = love.graphics.newQuad(
        x,
        y,
        CHARACTER_TILE_W,
        CHARACTER_TILE_H,
        characterSheet:getWidth(),
        characterSheet:getHeight()
      )
    end
  end

  characterQuadCache[setIndex] = quads
  return quads
end

local function drawCharacterSprite(entity, setIndex)
  local quads = getCharacterQuads(setIndex)

  local dir = entity.spriteFacing or "down"
  local frame = entity.spriteFrame or 1
  local dirSet = quads[dir] or quads.down
  local quad = dirSet[frame] or dirSet[1]

  love.graphics.draw(
    characterSheet,
    quad,
    entity.x,
    entity.y,
    0,
    CHARACTER_SCALE,
    CHARACTER_SCALE,
    CHARACTER_TILE_W * 0.5,
    CHARACTER_TILE_H * 0.5
  )
end

local function drawNecromancerSprite(entity)
  love.graphics.setColor(1, 1, 1, 1)
  drawCharacterSprite(entity, CHARACTER_SET_INDEX)
end

local function drawEnemySprite(enemy)
  local setIndex = ENEMY_CHARACTER_SET[enemy.kind] or 4
  if enemy.attackWindup and enemy.attackWindup > 0 then
    love.graphics.setColor(1, 0.9, 0.9, 1)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end
  drawCharacterSprite(enemy, setIndex)
end

local function drawFriendlyNpcSprite(npc)
  local setIndex = npc.spriteSet or 4
  love.graphics.setColor(1, 1, 1, 1)
  drawCharacterSprite(npc, setIndex)
end

local function slotColor(slot)
  if slot == "head" then
    return 0.8, 0.82, 0.76
  elseif slot == "torso" then
    return 0.6, 0.74, 0.7
  elseif slot == "left_arm" or slot == "right_arm" then
    return 0.77, 0.62, 0.57
  end
  return 0.69, 0.69, 0.56
end

local function drawEnemyLOS(game)
  local targets = { game.necromancer, game.monster }
  for _, enemy in ipairs(game.enemies) do
    if enemy.alive then
      local lx, ly = enemy.lookX or 1, enemy.lookY or 0
      local len = math.sqrt(lx * lx + ly * ly)
      if len < 0.0001 then
        lx, ly = 1, 0
      else
        lx, ly = lx / len, ly / len
      end

      local px, py = -ly, lx
      local coneAngle = math.rad(80)
      local half = coneAngle * 0.5
      local c = math.cos(half)
      local s = math.sin(half)
      local leftX = lx * c - ly * s
      local leftY = lx * s + ly * c
      local rightX = lx * c + ly * s
      local rightY = -lx * s + ly * c

      love.graphics.setColor(0.95, 0.86, 0.24, 0.2)
      love.graphics.circle("line", enemy.x, enemy.y, enemy.visionRange)
      love.graphics.line(enemy.x, enemy.y, enemy.x + leftX * enemy.visionRange, enemy.y + leftY * enemy.visionRange)
      love.graphics.line(enemy.x, enemy.y, enemy.x + rightX * enemy.visionRange, enemy.y + rightY * enemy.visionRange)
      love.graphics.setColor(0.95, 0.86, 0.24, 0.35)
      love.graphics.line(enemy.x, enemy.y, enemy.x + lx * enemy.visionRange, enemy.y + ly * enemy.visionRange)

      for _, target in ipairs(targets) do
        if target and target.alive then
          local dx, dy = target.x - enemy.x, target.y - enemy.y
          local d2 = dx * dx + dy * dy
          if d2 <= enemy.visionRange * enemy.visionRange and LOS.canSee(game.map, enemy.x, enemy.y, target.x, target.y) then
            love.graphics.setColor(0.98, 0.34, 0.28, 0.9)
            love.graphics.line(enemy.x, enemy.y, target.x, target.y)
          end
        end
      end
    end
  end
end

local function drawEntityShadow(entity)
  love.graphics.setColor(0, 0, 0, 0.2)
  love.graphics.ellipse("fill", entity.x, entity.y + entity.radius + 3, entity.radius + 2, 5)
end

local function drawHealthBar(entity, width)
  local ratio = entity.health / entity.maxHealth
  love.graphics.setColor(0.08, 0.08, 0.08, 0.8)
  love.graphics.rectangle("fill", entity.x - width / 2, entity.y - entity.radius - 14, width, 6)
  love.graphics.setColor(0.8 * (1 - ratio), 0.78 * ratio, 0.23)
  love.graphics.rectangle("fill", entity.x - width / 2, entity.y - entity.radius - 14, width * ratio, 6)

  if entity.maxPoise and entity.maxPoise > 0 then
    local poiseRatio = (entity.poise or entity.maxPoise) / entity.maxPoise
    local y = entity.y - entity.radius - 7
    love.graphics.setColor(0.08, 0.08, 0.08, 0.75)
    love.graphics.rectangle("fill", entity.x - width / 2, y, width, 4)
    if (entity.poiseBreakFlash or 0) > 0 then
      love.graphics.setColor(0.95, 0.45, 0.3, 0.92)
    else
      love.graphics.setColor(0.35, 0.68, 0.92, 0.92)
    end
    love.graphics.rectangle("fill", entity.x - width / 2, y, width * poiseRatio, 4)
  end
end

local function drawEnemyPaths(game)
  for _, enemy in ipairs(game.enemies) do
    if enemy.alive and enemy.path and enemy.pathIndex and enemy.pathIndex <= #enemy.path then
      love.graphics.setColor(0.28, 0.82, 0.95, 0.85)
      love.graphics.circle("line", enemy.x, enemy.y, enemy.radius + 4)

      local lastX, lastY = enemy.x, enemy.y
      for i = enemy.pathIndex, #enemy.path do
        local node = enemy.path[i]
        local pos = Map.tileToWorld(node.tx, node.ty)
        love.graphics.line(lastX, lastY, pos.x, pos.y)
        love.graphics.circle("fill", pos.x, pos.y, 3)
        lastX, lastY = pos.x, pos.y
      end

      love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
      love.graphics.print(enemy.state, enemy.x - 14, enemy.y - enemy.radius - 28)
    end
  end
end

local function drawEnemyTelegraph(enemy)
  if not enemy.attackWindup or enemy.attackWindup <= 0 then
    return
  end

  local duration = enemy.windupDuration or 0.3
  local progress = 1 - math.max(0, enemy.attackWindup / duration)
  local pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 6)
  local ringR = enemy.radius + 5 + progress * 6

  love.graphics.setColor(0.95, 0.35 + 0.45 * pulse, 0.24, 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", enemy.x, enemy.y, ringR)
  if enemy.attackTarget and enemy.attackTarget.alive then
    love.graphics.line(enemy.x, enemy.y, enemy.attackTarget.x, enemy.attackTarget.y)
  end
  love.graphics.setLineWidth(1)
end

local function drawBuildSpot(game)
  local spot = game.map and game.map.buildSpot
  if not spot then
    return
  end

  local t = love.timer.getTime()
  local pulse = 0.5 + 0.5 * math.sin(t * 2.8)
  local radius = 10 + pulse * 3
  local outer = (spot.radius or 36) * 0.55

  love.graphics.setColor(0.32, 0.82, 0.94, 0.2)
  love.graphics.circle("fill", spot.x, spot.y, outer)
  love.graphics.setColor(0.56, 0.9, 0.96, 0.86)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", spot.x, spot.y, radius)
  love.graphics.line(spot.x - 6, spot.y, spot.x + 6, spot.y)
  love.graphics.line(spot.x, spot.y - 6, spot.x, spot.y + 6)
  love.graphics.setLineWidth(1)
end

function Rendering.drawWorld(game)
  if game.map.tiled then
    Map.draw(game.map, {
      skipLayerNames = {
        roofs = true,
      },
    })
  else
    Map.draw(game.map)
  end

  for _, npc in ipairs(game.map.npcs or {}) do
    if npc.alive ~= false then
      drawEntityShadow(npc)
      drawFriendlyNpcSprite(npc)
      love.graphics.setColor(0.94, 0.92, 0.8, 0.95)
      love.graphics.print("!", npc.x - 2, npc.y - npc.radius - 14)
    end
  end

  if game.necromancer.alive then
    drawEntityShadow(game.necromancer)
    drawNecromancerSprite(game.necromancer)
    Combat.drawWeapon(game.necromancer, game.ui.dig ~= nil)
    drawHealthBar(game.necromancer, 34)
  end

  if game.monster and game.monster.alive then
    drawEntityShadow(game.monster)
    love.graphics.setColor(0.74, 0.62, 0.55)
    love.graphics.circle("fill", game.monster.x, game.monster.y, game.monster.radius)
    Combat.drawWeapon(game.monster, false)
    drawHealthBar(game.monster, 44)
  end

  for _, enemy in ipairs(game.enemies) do
    if enemy.alive then
      drawEntityShadow(enemy)
      drawEnemySprite(enemy)
      drawEnemyTelegraph(enemy)
      drawHealthBar(enemy, 28)
    end
  end

  drawBuildSpot(game)

  if game.map.tiled then
    local roofHideRects = Map.getRoofHideRects(game.map, { game.necromancer, game.monster })
    Map.drawLayerByName(game.map, "roofs", { hideRects = roofHideRects })
  end

  if game.debug and game.debug.showPaths then
    drawEnemyPaths(game)
  end
  if game.debug and game.debug.showLOS then
    drawEnemyLOS(game)
  end
end

function Rendering.drawHUD(game)
  love.graphics.origin()
  local screenW, screenH = Display.getLogicalSize()

  if HIDE_UI_OVERLAY_FOR_TESTING then
    return
  end

  love.graphics.setColor(0.04, 0.05, 0.06, 0.75)
  love.graphics.rectangle("fill", 12, 12, 420, 154, 10, 10)

  love.graphics.setColor(0.82, 0.88, 0.84)
  love.graphics.print("Bone Chapel", 24, 22)
  love.graphics.setColor(0.72, 0.76, 0.72)
  local controlledName = (game.controlled == "monster") and "Monster" or "Necromancer"
  love.graphics.print("Controlled: " .. controlledName .. " (Q to swap)", 24, 44)
  love.graphics.print(string.format("Zone: %d,%d  WASD move, J/Space light, K heavy, E interact", game.zone.x, game.zone.y), 24, 64)
  local inputName = game.controllerName or "Keyboard / Mouse"
  love.graphics.print("Input: " .. inputName, 24, 84)

  if game.tether then
    local ratio = game.tether.value / game.tether.max
    local bx, by, bw, bh = 24, 120, 220, 10
    love.graphics.setColor(0.12, 0.12, 0.14)
    love.graphics.rectangle("fill", bx, by, bw, bh, 5, 5)
    love.graphics.setColor(0.22 + 0.56 * ratio, 0.24 + 0.45 * ratio, 0.36 - 0.18 * ratio)
    love.graphics.rectangle("fill", bx, by, bw * ratio, bh, 5, 5)
    love.graphics.setColor(0.82, 0.86, 0.9)
    love.graphics.print(string.format("Ritual Tether: %d%%", math.floor(ratio * 100 + 0.5)), bx, by - 16)
  end

  local aliveEnemies = 0
  for _, enemy in ipairs(game.enemies) do
    if enemy.alive then
      aliveEnemies = aliveEnemies + 1
    end
  end
  love.graphics.print("Remaining Wardens: " .. aliveEnemies, 24, 140)

  if game.ui.msgTimer > 0 and game.ui.message then
    love.graphics.setColor(0.06, 0.08, 0.09, 0.8)
    love.graphics.rectangle("fill", 12, screenH - 56, 600, 40, 10, 10)
    love.graphics.setColor(0.9, 0.9, 0.84)
    love.graphics.print(game.ui.message, 22, screenH - 42)
  end

  if game.ui.dig then
    local barW = 260
    local barH = 14
    local barX = screenW * 0.5 - barW * 0.5
    local barY = screenH - 98
    local progress = 1 - (game.ui.dig.timer / game.ui.dig.duration)
    love.graphics.setColor(0.05, 0.06, 0.07, 0.9)
    love.graphics.rectangle("fill", barX - 10, barY - 22, barW + 20, 44, 10, 10)
    love.graphics.setColor(0.86, 0.88, 0.8)
    love.graphics.printf("Digging grave... (E to cancel)", barX - 4, barY - 18, barW + 8, "center")
    love.graphics.setColor(0.12, 0.12, 0.12)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 7, 7)
    love.graphics.setColor(0.63, 0.48, 0.34)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 7, 7)
  end

  if game.ui.dialog then
    local boxW = screenW - 180
    local boxH = 150
    local boxX = 90
    local boxY = screenH - boxH - 30
    love.graphics.setColor(0.03, 0.04, 0.05, 0.93)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10, 10)
    local portrait = { x = boxX + 16, y = boxY + 16, w = 96, h = 118 }
    love.graphics.setColor(0.26, 0.3, 0.29)
    love.graphics.rectangle("fill", portrait.x, portrait.y, portrait.w, portrait.h, 8, 8)
    love.graphics.setColor(0.86, 0.84, 0.74)
    love.graphics.circle("fill", portrait.x + portrait.w * 0.5, portrait.y + 40, 18)
    love.graphics.setColor(0.64, 0.68, 0.6)
    love.graphics.rectangle("fill", portrait.x + 28, portrait.y + 60, 40, 48, 8, 8)
    love.graphics.setColor(0.9, 0.94, 0.87)
    love.graphics.print(game.ui.dialog.name, boxX + 128, boxY + 18)
    love.graphics.setColor(0.84, 0.86, 0.8)
    love.graphics.printf(game.ui.dialog.text, boxX + 128, boxY + 46, boxW - 146)
    love.graphics.setColor(0.7, 0.74, 0.68)
    love.graphics.printf("Press E, Enter, or Space", boxX + 128, boxY + boxH - 28, boxW - 146)
  end

  local x = screenW - 260
  love.graphics.setColor(0.05, 0.06, 0.07, 0.8)
  love.graphics.rectangle("fill", x, 12, 248, 126, 10, 10)
  love.graphics.setColor(0.84, 0.88, 0.84)
  love.graphics.print("Recovered Parts", x + 10, 20)

  local py = 44
  for _, slot in ipairs(BodyParts.slotOrder) do
    local r, g, b = slotColor(slot)
    love.graphics.setColor(r, g, b)
    local count = #game.inventory[slot]
    love.graphics.print(string.format("%s: %d", BodyParts.slotNames[slot], count), x + 12, py)
    py = py + 18
  end

  if game.gear and game.gear.equipped then
    local gy = 170
    love.graphics.setColor(0.05, 0.06, 0.07, 0.8)
    love.graphics.rectangle("fill", x, gy, 248, 92, 10, 10)
    love.graphics.setColor(0.84, 0.88, 0.84)
    love.graphics.print("Equipped Relics", x + 10, gy + 8)
    local lineY = gy + 30
    for _, category in ipairs(GearLoot.categoryOrder) do
      local item = game.gear.equipped[category]
      local name = item and item.name or "None"
      love.graphics.setColor(0.76, 0.8, 0.78)
      love.graphics.print(string.format("%s: %s", GearLoot.categoryNames[category], name), x + 10, lineY)
      lineY = lineY + 18
    end
  end

  if game.monster and game.monster.alive and game.monster.activeSets and #game.monster.activeSets > 0 then
    local sx, sy = 12, screenH - 146
    love.graphics.setColor(0.05, 0.06, 0.07, 0.82)
    love.graphics.rectangle("fill", sx, sy, 420, 64, 10, 10)
    love.graphics.setColor(0.84, 0.88, 0.84)
    love.graphics.print("Active Set Bonuses", sx + 10, sy + 8)
    love.graphics.setColor(0.72, 0.78, 0.74)
    love.graphics.printf(table.concat(game.monster.activeSets, ", "), sx + 10, sy + 30, 400)
  end

  if game.flash > 0 then
    love.graphics.setColor(0.95, 0.2, 0.15, game.flash * 0.4)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  if game.win or game.lose then
    love.graphics.setColor(0.04, 0.04, 0.05, 0.84)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(0.9, 0.95, 0.9)
    local text = game.win and "The crypt yields. You and your creation survive." or "The necromancer falls. The ritual is severed."
    love.graphics.printf(text, 0, screenH * 0.46, screenW, "center")
    love.graphics.setColor(0.78, 0.82, 0.76)
    love.graphics.printf("Press R to restart", 0, screenH * 0.53, screenW, "center")
  end

  if game.debug and game.debug.enabled then
    local chase, patrol, search = 0, 0, 0
    for _, enemy in ipairs(game.enemies) do
      if enemy.alive then
        if enemy.state == "chase" then
          chase = chase + 1
        elseif enemy.state == "search" then
          search = search + 1
        else
          patrol = patrol + 1
        end
      end
    end

    local dbgX, dbgY = 12, 132
    local caveProcgen = (game.map and game.map.procgen and game.map.procgen.cave) or nil
    local caveProcgenText = "Cave procgen: static fallback"
    if caveProcgen then
      caveProcgenText = string.format(
        "Cave procgen: seed=%d attempts=%d zone=%d,%d",
        caveProcgen.seed or 0,
        caveProcgen.attempts or 0,
        caveProcgen.zoneX or 0,
        caveProcgen.zoneY or 0
      )
    end

    love.graphics.setColor(0.03, 0.03, 0.04, 0.85)
    love.graphics.rectangle("fill", dbgX, dbgY, 452, 164, 10, 10)
    love.graphics.setColor(0.86, 0.92, 0.96)
    love.graphics.print("Debug Overlay (F3)", dbgX + 12, dbgY + 10)
    love.graphics.setColor(0.72, 0.8, 0.84)
    love.graphics.print(string.format("Zone: %d,%d", game.zone.x, game.zone.y), dbgX + 12, dbgY + 30)
    love.graphics.print(string.format("Enemies  patrol:%d chase:%d search:%d", patrol, chase, search), dbgX + 12, dbgY + 48)
    love.graphics.print(string.format("Warp cooldown: %.2f", game.warpCooldown or 0), dbgX + 12, dbgY + 66)
    love.graphics.print(caveProcgenText, dbgX + 12, dbgY + 84)
    if game.tether then
      love.graphics.print(string.format("Tether: %.1f / %.1f", game.tether.value, game.tether.max), dbgX + 12, dbgY + 102)
    end
    love.graphics.print(string.format("Enemy suppression: %s", (game.debug and game.debug.suppressEnemies) and "ON" or "OFF"), dbgX + 12, dbgY + 120)
    love.graphics.print("F4: Toggle NPC path lines", dbgX + 262, dbgY + 10)
    love.graphics.print("F5: Toggle LOS debug", dbgX + 262, dbgY + 28)
    love.graphics.print("F6: Toggle enemy suppression", dbgX + 262, dbgY + 46)
  end
end

return Rendering
