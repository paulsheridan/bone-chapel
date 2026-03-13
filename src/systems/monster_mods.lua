local BodyParts = require("src.data.body_parts")
local GearLoot = require("src.data.gear_loot")

local MonsterMods = {}

local traitModsByPartId = {
  grim_skull = { attackArcMult = 1.1 },
  stag_helm = { attackDamageFlat = 3, attackRangeFlat = 6 },
  iron_ribcage = { damageReduction = 0.1, speedMult = 0.92 },
  stitched_chest = { attackCooldownMult = 0.92 },
  hook_arm = { bleedChance = 0.22, bleedDamage = 4 },
  scout_arm = { attackCooldownMult = 0.9 },
  crusher_arm = { barricadeDamageMult = 1.45 },
  duelist_arm = { attackCooldownMult = 0.88, attackDamageMult = 1.05 },
  wolf_leg = { speedMult = 1.08, attackRangeFlat = 6 },
  pillar_leg = { damageReduction = 0.06, speedMult = 0.95 },
  lynx_leg = { speedMult = 1.1 },
  bulwark_leg = { healthFlat = 16, damageReduction = 0.05 },
}

local setBonuses = {
  {
    name = "Predator Gait",
    requires = { "wolf_leg", "lynx_leg" },
    mods = {
      speedMult = 1.12,
      attackRangeFlat = 8,
    },
  },
  {
    name = "Siege Construct",
    requires = { "iron_ribcage", "crusher_arm", "hook_arm" },
    mods = {
      attackDamageMult = 1.12,
      speedMult = 0.94,
      barricadeDamageMult = 1.5,
    },
  },
  {
    name = "Quickstitch Duelist",
    requires = { "stitched_chest", "scout_arm", "duelist_arm" },
    mods = {
      attackCooldownMult = 0.78,
      speedMult = 1.06,
    },
  },
  {
    name = "Grave Bulwark",
    requires = { "iron_ribcage", "pillar_leg", "bulwark_leg" },
    mods = {
      healthFlat = 24,
      damageReduction = 0.14,
    },
  },
}

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function applyMods(target, source)
  if not source then
    return
  end
  for key, value in pairs(source) do
    if type(value) == "number" then
      if string.sub(key, -4) == "Mult" then
        target[key] = (target[key] or 1) * value
      else
        target[key] = (target[key] or 0) + value
      end
    end
  end
end

local function collectPartIds(equipped)
  local ids = {}
  for _, slot in ipairs(BodyParts.slotOrder) do
    local part = equipped[slot]
    if part and part.id then
      ids[part.id] = true
    end
  end
  return ids
end

local function hasAll(ids, required)
  for _, id in ipairs(required) do
    if not ids[id] then
      return false
    end
  end
  return true
end

function MonsterMods.compute(equipped, equippedGear)
  local mods = {}
  local activeTraits = {}
  local activeSets = {}
  local activeGear = {}

  for _, slot in ipairs(BodyParts.slotOrder) do
    local part = equipped[slot]
    if part then
      table.insert(activeTraits, part.trait)
      applyMods(mods, traitModsByPartId[part.id])
    end
  end

  local ids = collectPartIds(equipped)
  for _, bonus in ipairs(setBonuses) do
    if hasAll(ids, bonus.requires) then
      table.insert(activeSets, bonus.name)
      applyMods(mods, bonus.mods)
    end
  end

  equippedGear = equippedGear or {}
  for _, category in ipairs(GearLoot.categoryOrder) do
    local item = equippedGear[category]
    if item then
      activeGear[category] = item.name
      applyMods(mods, item.mods)
    end
  end

  mods.damageReduction = clamp(mods.damageReduction or 0, 0, 0.45)
  mods.bleedChance = clamp(mods.bleedChance or 0, 0, 0.65)

  return {
    mods = mods,
    traits = activeTraits,
    sets = activeSets,
    gear = activeGear,
  }
end

function MonsterMods.projectStats(baseStats, equipped, equippedGear, stability)
  local profile = MonsterMods.compute(equipped, equippedGear)
  local mods = profile.mods
  local t = clamp(stability or 1, 0, 1)
  local power = 0.68 + 0.32 * t

  local speed = (baseStats.speed + (mods.speedFlat or 0)) * (mods.speedMult or 1) * power
  local strength = (baseStats.strength + (mods.strengthFlat or 0)) * (mods.strengthMult or 1) * (0.72 + 0.28 * t)
  local health = (baseStats.health + (mods.healthFlat or 0)) * (mods.healthMult or 1)

  return {
    speed = math.max(1, math.floor(speed + 0.5)),
    strength = math.max(1, math.floor(strength + 0.5)),
    health = math.max(1, math.floor(health + 0.5)),
    profile = profile,
  }
end

return MonsterMods
