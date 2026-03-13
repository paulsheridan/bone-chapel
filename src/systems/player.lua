local Math2D = require("src.core.math2d")

local Player = {}

local function deadzone(v, dz)
  if math.abs(v) < dz then
    return 0
  end
  return v
end

local function controllerInput(game)
  local pad = game.activePad
  if not pad or not pad:isConnected() then
    return 0, 0, false, false
  end

  local x, y = 0, 0
  local light, heavy = false, false

  if pad:isGamepad() then
    x = x + deadzone(pad:getGamepadAxis("leftx") or 0, 0.22)
    y = y + deadzone(pad:getGamepadAxis("lefty") or 0, 0.22)
    if pad:isGamepadDown("dpleft") then
      x = x - 1
    end
    if pad:isGamepadDown("dpright") then
      x = x + 1
    end
    if pad:isGamepadDown("dpup") then
      y = y - 1
    end
    if pad:isGamepadDown("dpdown") then
      y = y + 1
    end
    light = pad:isGamepadDown("a")
    heavy = pad:isGamepadDown("x")
  else
    x = x + deadzone(pad:getAxis(1) or 0, 0.22)
    y = y + deadzone(pad:getAxis(2) or 0, 0.22)
    local hat = pad:getHat(1) or "c"
    if string.find(hat, "l", 1, true) then
      x = x - 1
    end
    if string.find(hat, "r", 1, true) then
      x = x + 1
    end
    if string.find(hat, "u", 1, true) then
      y = y - 1
    end
    if string.find(hat, "d", 1, true) then
      y = y + 1
    end
    light = pad:isDown(1)
    heavy = pad:isDown(2)
  end

  return x, y, light, heavy
end

function Player.updateControl(game, entity, dt, moveWithCollisions, attackFn, zoneTransitionFn)
  if not entity or not entity.alive then
    return
  end

  if (entity.hitStun or 0) > 0 then
    zoneTransitionFn(game, entity)
    return
  end

  local rawX, rawY = 0, 0
  local padX, padY, padLight, padHeavy = controllerInput(game)
  rawX = rawX + padX
  rawY = rawY + padY

  if love.keyboard.isDown("w") then
    rawY = rawY - 1
  end
  if love.keyboard.isDown("s") then
    rawY = rawY + 1
  end
  if love.keyboard.isDown("a") then
    rawX = rawX - 1
  end
  if love.keyboard.isDown("d") then
    rawX = rawX + 1
  end

  if math.abs(rawX) > 0.12 or math.abs(rawY) > 0.12 then
    entity.facingX, entity.facingY = Math2D.normalize(rawX, rawY)
  end

  local mx, my = Math2D.normalize(rawX, rawY)
  moveWithCollisions(game, entity, mx * entity.speed * dt, my * entity.speed * dt)

  if love.keyboard.isDown("k") or padHeavy then
    attackFn(game, entity, "heavy")
  elseif love.keyboard.isDown("space") or love.keyboard.isDown("j") or padLight then
    attackFn(game, entity, "light")
  end

  zoneTransitionFn(game, entity)
end

return Player
