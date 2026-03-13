local Game = require("src.game")
local Display = require("src.core.display")

local frameCanvas

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  local baseW, baseH = Display.getLogicalSize()
  love.window.setMode(baseW, baseH, { resizable = true, vsync = 1, minwidth = baseW, minheight = baseH })
  frameCanvas = love.graphics.newCanvas(baseW, baseH)
  frameCanvas:setFilter("nearest", "nearest")
  Game.load()
end

function love.update(dt)
  Game.update(dt)
end

function love.draw()
  love.graphics.setCanvas(frameCanvas)
  love.graphics.clear(0, 0, 0, 1)
  Game.draw()
  love.graphics.setCanvas()

  local scale, offsetX, offsetY = Display.getScaleAndOffset()
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(frameCanvas, offsetX, offsetY, 0, scale, scale)
end

function love.keypressed(key)
  Game.keypressed(key)
end

function love.gamepadpressed(joystick, button)
  Game.gamepadpressed(joystick, button)
end

function love.joystickpressed(joystick, button)
  Game.joystickpressed(joystick, button)
end

function love.joystickadded(joystick)
  Game.joystickadded(joystick)
end

function love.joystickremoved(joystick)
  Game.joystickremoved(joystick)
end

function love.mousepressed(x, y, button)
  if Display.isInViewport(x, y) then
    local gx, gy = Display.toLogicalCoords(x, y)
    Game.mousepressed(gx, gy, button)
  end
end
