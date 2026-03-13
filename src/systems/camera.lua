local Map = require("src.world.map")
local Math2D = require("src.core.math2d")
local Display = require("src.core.display")

local Camera = {}

function Camera.kick(game, magnitude, duration)
  if not game or not game.camera then
    return
  end

  local cam = game.camera
  local d = duration or 0.12
  cam.shakeTime = math.max(cam.shakeTime or 0, d)
  cam.shakeDuration = math.max(cam.shakeDuration or 0, d)
  cam.shakeMag = math.max(cam.shakeMag or 0, magnitude or 0)
end

function Camera.updateShake(game, dt)
  if not game or not game.camera then
    return
  end

  local cam = game.camera
  local time = cam.shakeTime or 0
  if time <= 0 then
    cam.shakeX = 0
    cam.shakeY = 0
    return
  end

  time = math.max(0, time - dt)
  cam.shakeTime = time
  local duration = cam.shakeDuration or 0.12
  local ratio = (duration > 0) and (time / duration) or 0
  local mag = (cam.shakeMag or 0) * ratio
  cam.shakeX = love.math.random(-100, 100) * 0.01 * mag
  cam.shakeY = love.math.random(-100, 100) * 0.01 * mag

  if time <= 0 then
    cam.shakeX = 0
    cam.shakeY = 0
    cam.shakeMag = 0
  end
end

function Camera.beginZonePan(game, newZoneX, newZoneY, targetCamX, targetCamY)
  local viewW, viewH = Display.getLogicalSize()
  local bounds = Map.getZoneBoundsPixels(game.map, newZoneX, newZoneY)
  local minX = bounds.left
  local maxX = bounds.right - viewW
  local minY = bounds.top
  local maxY = bounds.bottom - viewH

  game.zone.transitioning = true
  game.zone.t = 0
  game.zone.fromX = game.camera.x
  game.zone.fromY = game.camera.y

  if targetCamX and targetCamY then
    game.zone.toX = Math2D.clamp(targetCamX, minX, maxX)
    game.zone.toY = Math2D.clamp(targetCamY, minY, maxY)
  else
    game.zone.toX, game.zone.toY = Map.zoneToCamera(game.map, newZoneX, newZoneY, viewW, viewH)
    game.zone.toX = Math2D.clamp(game.zone.toX, minX, maxX)
    game.zone.toY = Math2D.clamp(game.zone.toY, minY, maxY)
  end

  game.zone.x = newZoneX
  game.zone.y = newZoneY
end

function Camera.snapToZone(game, zoneX, zoneY)
  local viewW, viewH = Display.getLogicalSize()
  game.camera.x, game.camera.y = Map.zoneToCamera(game.map, zoneX, zoneY, viewW, viewH)
  game.zone.x = zoneX
  game.zone.y = zoneY
  game.zone.transitioning = false
  game.zone.t = 0
end

function Camera.initAtStart(game, zoneX, zoneY, targetX, targetY)
  local viewW, viewH = Display.getLogicalSize()
  local b = Map.getZoneBoundsPixels(game.map, zoneX, zoneY)
  game.camera.x = Math2D.clamp(targetX - viewW * 0.5, b.left, b.right - viewW)
  game.camera.y = Math2D.clamp(targetY - viewH * 0.5, b.top, b.bottom - viewH)
end

function Camera.tryZoneTransition(game, entity)
  local zoneBounds = Map.getZoneBoundsPixels(game.map, game.zone.x, game.zone.y)

  if entity.x - entity.radius <= zoneBounds.left then
    if game.zone.x > 1 then
      local viewW = Display.getLogicalSize()
      local newX = game.zone.x - 1
      local newBounds = Map.getZoneBoundsPixels(game.map, newX, game.zone.y)
      entity.x = newBounds.right - entity.radius - 3
      entity.y = Math2D.clamp(entity.y, newBounds.top + entity.radius + 2, newBounds.bottom - entity.radius - 2)
      Camera.beginZonePan(game, newX, game.zone.y, game.camera.x - viewW, game.camera.y)
      return true
    else
      entity.x = zoneBounds.left + entity.radius + 1
    end
  elseif entity.x + entity.radius >= zoneBounds.right then
    if game.zone.x < game.map.zonesX then
      local viewW = Display.getLogicalSize()
      local newX = game.zone.x + 1
      local newBounds = Map.getZoneBoundsPixels(game.map, newX, game.zone.y)
      entity.x = newBounds.left + entity.radius + 3
      entity.y = Math2D.clamp(entity.y, newBounds.top + entity.radius + 2, newBounds.bottom - entity.radius - 2)
      Camera.beginZonePan(game, newX, game.zone.y, game.camera.x + viewW, game.camera.y)
      return true
    else
      entity.x = zoneBounds.right - entity.radius - 1
    end
  end

  if entity.y - entity.radius <= zoneBounds.top then
    if game.zone.y > 1 then
      local _, viewH = Display.getLogicalSize()
      local newY = game.zone.y - 1
      local newBounds = Map.getZoneBoundsPixels(game.map, game.zone.x, newY)
      entity.y = newBounds.bottom - entity.radius - 3
      entity.x = Math2D.clamp(entity.x, newBounds.left + entity.radius + 2, newBounds.right - entity.radius - 2)
      Camera.beginZonePan(game, game.zone.x, newY, game.camera.x, game.camera.y - viewH)
      return true
    else
      entity.y = zoneBounds.top + entity.radius + 1
    end
  elseif entity.y + entity.radius >= zoneBounds.bottom then
    if game.zone.y < game.map.zonesY then
      local _, viewH = Display.getLogicalSize()
      local newY = game.zone.y + 1
      local newBounds = Map.getZoneBoundsPixels(game.map, game.zone.x, newY)
      entity.y = newBounds.top + entity.radius + 3
      entity.x = Math2D.clamp(entity.x, newBounds.left + entity.radius + 2, newBounds.right - entity.radius - 2)
      Camera.beginZonePan(game, game.zone.x, newY, game.camera.x, game.camera.y + viewH)
      return true
    else
      entity.y = zoneBounds.bottom - entity.radius - 1
    end
  end

  return false
end

function Camera.update(game, dt)
  if game.zone.transitioning then
    game.zone.t = math.min(1, game.zone.t + dt / game.zone.duration)
    local t = game.zone.t
    local eased = t * t * (3 - 2 * t)
    game.camera.x = game.zone.fromX + (game.zone.toX - game.zone.fromX) * eased
    game.camera.y = game.zone.fromY + (game.zone.toY - game.zone.fromY) * eased
    if t >= 1 then
      game.zone.transitioning = false
      game.camera.x = game.zone.toX
      game.camera.y = game.zone.toY
    end
    return
  end

  local viewW, viewH = Display.getLogicalSize()
  local target = game:getControlledEntity()
  local bounds = Map.getZoneBoundsPixels(game.map, game.zone.x, game.zone.y)
  local desiredX = target.x - viewW * 0.5
  local desiredY = target.y - viewH * 0.5
  game.camera.x = Math2D.clamp(desiredX, bounds.left, bounds.right - viewW)
  game.camera.y = Math2D.clamp(desiredY, bounds.top, bounds.bottom - viewH)
end

return Camera
