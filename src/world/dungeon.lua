local Config = require("src.world.dungeon.config")
local Generator = require("src.world.dungeon.generator")
local Populate = require("src.world.dungeon.populate")
local Validate = require("src.world.dungeon.validate")
local Apply = require("src.world.dungeon.apply")

local Dungeon = {}

local function makeSeed()
  return love.math.random(1, 2147483646)
end

function Dungeon.applyProceduralCave(map, helpers, tileTheme)
  if not Config.enabled or not map or not map.tiled then
    return false
  end

  local context = Apply.resolveContext(map, helpers, tileTheme)
  if not context then
    return false
  end

  local seed = makeSeed()
  local rng = love.math.newRandomGenerator(seed)
  local fallback = nil
  local fallbackContent = nil
  local fallbackAttempt = nil

  for attempt = 1, Config.maxAttempts do
    local layout = Generator.generate(context, rng, Config)
    if layout then
      local content = Populate.generate(context, layout, rng, Config)
      if Validate.check(context, layout, content, Config) then
        if layout.cornerSpacingPassed ~= false then
          Apply.apply(context, layout, content)
          map.procgen = map.procgen or {}
          map.procgen.cave = {
            seed = seed,
            attempts = attempt,
            zoneX = context.zoneX,
            zoneY = context.zoneY,
            tileThemeSource = (context.tileTheme and context.tileTheme.source) or nil,
            cornerSpacingViolations = layout.cornerSpacingViolations or 0,
            cornerSpacingAllowed = layout.cornerSpacingAllowedViolations or 0,
            cornerSpacingRelaxed = false,
          }
          return true
        end

        local best = fallback and (fallback.cornerSpacingViolations or math.huge) or math.huge
        local current = layout.cornerSpacingViolations or math.huge
        if current < best then
          fallback = layout
          fallbackContent = content
          fallbackAttempt = attempt
        end
      end
    end
  end

  if fallback and fallbackContent then
    Apply.apply(context, fallback, fallbackContent)
    map.procgen = map.procgen or {}
    map.procgen.cave = {
      seed = seed,
      attempts = fallbackAttempt or Config.maxAttempts,
      zoneX = context.zoneX,
      zoneY = context.zoneY,
      tileThemeSource = (context.tileTheme and context.tileTheme.source) or nil,
      cornerSpacingViolations = fallback.cornerSpacingViolations or 0,
      cornerSpacingAllowed = fallback.cornerSpacingAllowedViolations or 0,
      cornerSpacingRelaxed = true,
    }
    return true
  end

  return false
end

return Dungeon
