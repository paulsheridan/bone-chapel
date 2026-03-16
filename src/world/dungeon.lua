local Config = require("src.world.dungeon.config")
local Generator = require("src.world.dungeon.generator")
local MacroLayout = require("src.world.dungeon.macro_layout")
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
    local macro
    if Config.macro and Config.macro.enabled then
      macro = MacroLayout.generate(context, rng, Config)
    end

    local layout
    if macro then
      layout = Generator.generateComposite(context, macro, rng, Config)
    else
      layout = Generator.generate(context, rng, Config)
    end

    if layout then
      local populateContext = context
      if macro then
        populateContext = {
          tileToWorld = context.tileToWorld,
          globalLayout = true,
        }
      end

      local content = Populate.generate(populateContext, layout, rng, Config)
      if Validate.check(context, layout, content, Config) then
        if layout.cornerSpacingPassed ~= false then
          if macro and macro.zoneSet then
            context.generatedZoneSet = macro.zoneSet
          end
          Apply.apply(context, layout, content)
          map.procgen = map.procgen or {}
          map.procgen.cave = {
            seed = seed,
            attempts = attempt,
            zoneX = context.anchorZoneX,
            zoneY = context.anchorZoneY,
            tileThemeSource = (context.tileTheme and context.tileTheme.source) or nil,
            tileTheme = context.tileTheme,
            cornerSpacingViolations = layout.cornerSpacingViolations or 0,
            cornerSpacingAllowed = layout.cornerSpacingAllowedViolations or 0,
            cornerSpacingRelaxed = false,
            areaCount = layout.areaCount or 1,
            generatedZones = layout.generatedZones or nil,
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

  if fallback and fallbackContent and ((Config.cornerSpacing and Config.cornerSpacing.allowRelaxedFallback) == true) then
    if fallback.generatedZoneSet then
      context.generatedZoneSet = fallback.generatedZoneSet
    end
    Apply.apply(context, fallback, fallbackContent)
    map.procgen = map.procgen or {}
    map.procgen.cave = {
      seed = seed,
      attempts = fallbackAttempt or Config.maxAttempts,
      zoneX = context.anchorZoneX,
      zoneY = context.anchorZoneY,
      tileThemeSource = (context.tileTheme and context.tileTheme.source) or nil,
      tileTheme = context.tileTheme,
      cornerSpacingViolations = fallback.cornerSpacingViolations or 0,
      cornerSpacingAllowed = fallback.cornerSpacingAllowedViolations or 0,
      cornerSpacingRelaxed = true,
      areaCount = fallback.areaCount or 1,
      generatedZones = fallback.generatedZones or nil,
    }
    return true
  end

  return false
end

return Dungeon
