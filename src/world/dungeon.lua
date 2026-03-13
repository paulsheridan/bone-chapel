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

  for attempt = 1, Config.maxAttempts do
    local layout = Generator.generate(context, rng, Config)
    local content = Populate.generate(context, layout, rng, Config)
    if Validate.check(context, layout, content, Config) then
      Apply.apply(context, layout, content)
      map.procgen = map.procgen or {}
      map.procgen.cave = {
        seed = seed,
        attempts = attempt,
        zoneX = context.zoneX,
        zoneY = context.zoneY,
        tileThemeSource = (context.tileTheme and context.tileTheme.source) or nil,
      }
      return true
    end
  end

  return false
end

return Dungeon
