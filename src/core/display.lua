local Display = {
  baseWidth = 960,
  baseHeight = 640,
}

function Display.getLogicalSize()
  return Display.baseWidth, Display.baseHeight
end

function Display.getScaleAndOffset()
  local winW, winH = love.graphics.getDimensions()
  local scaleX = winW / Display.baseWidth
  local scaleY = winH / Display.baseHeight
  local scale = math.min(scaleX, scaleY)
  local drawW = Display.baseWidth * scale
  local drawH = Display.baseHeight * scale
  local offsetX = (winW - drawW) * 0.5
  local offsetY = (winH - drawH) * 0.5
  return scale, offsetX, offsetY
end

function Display.toLogicalCoords(screenX, screenY)
  local scale, offsetX, offsetY = Display.getScaleAndOffset()
  local x = (screenX - offsetX) / scale
  local y = (screenY - offsetY) / scale
  return x, y
end

function Display.isInViewport(screenX, screenY)
  local x, y = Display.toLogicalCoords(screenX, screenY)
  return x >= 0 and y >= 0 and x <= Display.baseWidth and y <= Display.baseHeight
end

return Display
