local BodyParts = require("src.data.body_parts")
local Display = require("src.core.display")
local GearLoot = require("src.data.gear_loot")
local MonsterMods = require("src.systems.monster_mods")

local BuildMenu = {}

local function pointInRect(px, py, r)
  return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function sumStats(equipped, equippedGear)
  local base = { speed = 78, strength = 16, health = 75 }
  for _, slot in ipairs(BodyParts.slotOrder) do
    local part = equipped[slot]
    if part then
      base.speed = base.speed + part.stats.speed
      base.strength = base.strength + part.stats.strength
      base.health = base.health + part.stats.health
    end
  end

  local projected = MonsterMods.projectStats(base, equipped, equippedGear, 1)
  return {
    speed = projected.speed,
    strength = projected.strength,
    health = projected.health,
    traits = projected.profile.traits,
    sets = projected.profile.sets,
  }
end

function BuildMenu.new()
  return {
    open = false,
    selectedSlot = "head",
    selectedIndex = 1,
    slotButtons = {},
    partButtons = {},
    assembleButton = nil,
    designateButton = nil,
  }
end

function BuildMenu.toggle(menu)
  menu.open = not menu.open
end

function BuildMenu.requiredComplete(equipped)
  for _, slot in ipairs(BodyParts.slotOrder) do
    if not equipped[slot] then
      return false
    end
  end
  return true
end

function BuildMenu.draw(menu, game)
  if not menu.open then
    return
  end

  local w, h = Display.getLogicalSize()
  love.graphics.setColor(0.05, 0.07, 0.09, 0.88)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local panel = { x = 90, y = 60, w = w - 180, h = h - 120 }
  love.graphics.setColor(0.11, 0.14, 0.16)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 14, 14)

  love.graphics.setColor(0.78, 0.84, 0.8)
  love.graphics.printf("The Stitching Table", panel.x, panel.y + 20, panel.w, "center")

  local left = { x = panel.x + 26, y = panel.y + 64, w = 220, h = panel.h - 96 }
  local middle = { x = left.x + left.w + 20, y = left.y, w = 280, h = left.h }
  local right = { x = middle.x + middle.w + 20, y = left.y, w = panel.x + panel.w - (middle.x + middle.w + 46), h = left.h }

  love.graphics.setColor(0.17, 0.2, 0.22)
  love.graphics.rectangle("fill", left.x, left.y, left.w, left.h, 10, 10)
  love.graphics.rectangle("fill", middle.x, middle.y, middle.w, middle.h, 10, 10)
  love.graphics.rectangle("fill", right.x, right.y, right.w, right.h, 10, 10)

  love.graphics.setColor(0.7, 0.77, 0.73)
  love.graphics.print("Slots", left.x + 12, left.y + 10)
  love.graphics.print("Assembly", middle.x + 12, middle.y + 10)
  love.graphics.print("Parts in Satchel", right.x + 12, right.y + 10)

  menu.slotButtons = {}
  local y = left.y + 42
  for _, slot in ipairs(BodyParts.slotOrder) do
    local selected = slot == menu.selectedSlot
    local rect = { x = left.x + 12, y = y, w = left.w - 24, h = 36, slot = slot }
    love.graphics.setColor(selected and 0.34 or 0.24, selected and 0.4 or 0.26, selected and 0.32 or 0.3)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setColor(0.9, 0.9, 0.86)
    local label = BodyParts.slotNames[slot]
    local equipped = game.build.equipped[slot]
    if equipped then
      label = label .. ": " .. equipped.name
    end
    love.graphics.print(label, rect.x + 10, rect.y + 10)
    table.insert(menu.slotButtons, rect)
    y = y + 44
  end

  local centerX = middle.x + middle.w * 0.5
  local centerY = middle.y + middle.h * 0.5 + 8
  love.graphics.setColor(0.28, 0.33, 0.35)
  love.graphics.circle("fill", centerX, centerY - 120, 30)
  love.graphics.rectangle("fill", centerX - 38, centerY - 84, 76, 120, 8, 8)
  love.graphics.rectangle("fill", centerX - 108, centerY - 78, 44, 92, 8, 8)
  love.graphics.rectangle("fill", centerX + 64, centerY - 78, 44, 92, 8, 8)
  love.graphics.rectangle("fill", centerX - 44, centerY + 38, 36, 110, 8, 8)
  love.graphics.rectangle("fill", centerX + 8, centerY + 38, 36, 110, 8, 8)

  local summary = sumStats(game.build.equipped, game.gear and game.gear.equipped or nil)
  local complete = BuildMenu.requiredComplete(game.build.equipped)

  love.graphics.setColor(0.82, 0.86, 0.82)
  love.graphics.print("Projected Monster", middle.x + 16, middle.y + middle.h - 186)
  love.graphics.print(string.format("Speed: %d", summary.speed), middle.x + 16, middle.y + middle.h - 162)
  love.graphics.print(string.format("Strength: %d", summary.strength), middle.x + 16, middle.y + middle.h - 142)
  love.graphics.print(string.format("Health: %d", summary.health), middle.x + 16, middle.y + middle.h - 122)
  if complete then
    love.graphics.setColor(0.42, 0.82, 0.46)
    love.graphics.print("All required parts equipped", middle.x + 16, middle.y + middle.h - 98)
  else
    love.graphics.setColor(0.88, 0.56, 0.35)
    love.graphics.print("Missing one or more body slots", middle.x + 16, middle.y + middle.h - 98)
  end

  love.graphics.setColor(0.86, 0.88, 0.82)
  love.graphics.print("Traits:", middle.x + 16, middle.y + middle.h - 70)
  local traitText = #summary.traits > 0 and table.concat(summary.traits, ", ") or "None"
  love.graphics.printf(traitText, middle.x + 16, middle.y + middle.h - 50, middle.w - 30)

  love.graphics.setColor(0.82, 0.86, 0.82)
  love.graphics.print("Set Bonuses:", middle.x + 16, middle.y + middle.h - 16)
  local setText = #summary.sets > 0 and table.concat(summary.sets, ", ") or "None"
  love.graphics.printf(setText, middle.x + 104, middle.y + middle.h - 16, middle.w - 118)

  if game.gear and game.gear.equipped then
    local gy = middle.y + 28
    for _, category in ipairs(GearLoot.categoryOrder) do
      local item = game.gear.equipped[category]
      local text = string.format("%s: %s", GearLoot.categoryNames[category], item and item.name or "None")
      love.graphics.setColor(0.74, 0.8, 0.78)
      love.graphics.print(text, middle.x + 16, gy)
      gy = gy + 16
    end
  end

  menu.partButtons = {}
  local parts = game.inventory[menu.selectedSlot]
  local py = right.y + 42
  for i, part in ipairs(parts) do
    local isSelected = i == menu.selectedIndex
    local rect = { x = right.x + 12, y = py, w = right.w - 24, h = 56, index = i }
    love.graphics.setColor(isSelected and 0.36 or 0.24, isSelected and 0.3 or 0.23, isSelected and 0.25 or 0.21)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setColor(0.9, 0.9, 0.85)
    love.graphics.print(part.name, rect.x + 10, rect.y + 8)
    local line = string.format("Spd %+d  Str %+d  HP %+d", part.stats.speed, part.stats.strength, part.stats.health)
    love.graphics.print(line, rect.x + 10, rect.y + 30)
    table.insert(menu.partButtons, rect)
    py = py + 64
    if py + 56 > right.y + right.h - 120 then
      break
    end
  end

  menu.assembleButton = { x = right.x + 12, y = right.y + right.h - 96, w = right.w - 24, h = 38 }
  menu.designateButton = { x = right.x + 12, y = right.y + right.h - 50, w = right.w - 24, h = 38 }

  love.graphics.setColor(0.26, 0.46, 0.34)
  love.graphics.rectangle("fill", menu.assembleButton.x, menu.assembleButton.y, menu.assembleButton.w, menu.assembleButton.h, 8, 8)
  love.graphics.setColor(0.9, 0.95, 0.9)
  love.graphics.printf("Assemble Monster (A)", menu.assembleButton.x, menu.assembleButton.y + 11, menu.assembleButton.w, "center")

  love.graphics.setColor(0.27, 0.35, 0.5)
  love.graphics.rectangle("fill", menu.designateButton.x, menu.designateButton.y, menu.designateButton.w, menu.designateButton.h, 8, 8)
  love.graphics.setColor(0.9, 0.95, 0.98)
  love.graphics.printf("Designate Control (Q)", menu.designateButton.x, menu.designateButton.y + 11, menu.designateButton.w, "center")
end

function BuildMenu.keypressed(menu, game, key)
  if not menu.open then
    return false
  end

  if key == "escape" or key == "tab" then
    menu.open = false
    return true
  end

  for i, slot in ipairs(BodyParts.slotOrder) do
    if key == tostring(i) then
      menu.selectedSlot = slot
      menu.selectedIndex = 1
      return true
    end
  end

  local parts = game.inventory[menu.selectedSlot]
  if key == "left" or key == "right" then
    local slotIndex = 1
    for i, slot in ipairs(BodyParts.slotOrder) do
      if slot == menu.selectedSlot then
        slotIndex = i
        break
      end
    end
    if key == "left" then
      slotIndex = ((slotIndex - 2) % #BodyParts.slotOrder) + 1
    else
      slotIndex = (slotIndex % #BodyParts.slotOrder) + 1
    end
    menu.selectedSlot = BodyParts.slotOrder[slotIndex]
    menu.selectedIndex = 1
    return true
  end

  if key == "up" then
    menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
    return true
  elseif key == "down" then
    menu.selectedIndex = math.min(#parts, menu.selectedIndex + 1)
    return true
  elseif key == "return" and parts[menu.selectedIndex] then
    game.build.equipped[menu.selectedSlot] = parts[menu.selectedIndex]
    return true
  elseif key == "a" then
    game:assembleMonster()
    return true
  elseif key == "q" then
    game:toggleControl()
    return true
  end

  return true
end

function BuildMenu.mousepressed(menu, game, x, y, button)
  if not menu.open or button ~= 1 then
    return false
  end

  for _, rect in ipairs(menu.slotButtons) do
    if pointInRect(x, y, rect) then
      menu.selectedSlot = rect.slot
      menu.selectedIndex = 1
      return true
    end
  end

  for _, rect in ipairs(menu.partButtons) do
    if pointInRect(x, y, rect) then
      menu.selectedIndex = rect.index
      local chosen = game.inventory[menu.selectedSlot][menu.selectedIndex]
      if chosen then
        game.build.equipped[menu.selectedSlot] = chosen
      end
      return true
    end
  end

  if menu.assembleButton and pointInRect(x, y, menu.assembleButton) then
    game:assembleMonster()
    return true
  end

  if menu.designateButton and pointInRect(x, y, menu.designateButton) then
    game:toggleControl()
    return true
  end

  return true
end

return BuildMenu
