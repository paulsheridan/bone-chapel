local Math2D = {}

function Math2D.clamp(v, minV, maxV)
  return math.max(minV, math.min(maxV, v))
end

function Math2D.normalize(x, y)
  local len = math.sqrt(x * x + y * y)
  if len <= 0.0001 then
    return 0, 0
  end
  return x / len, y / len
end

function Math2D.distSq(aX, aY, bX, bY)
  local dx = bX - aX
  local dy = bY - aY
  return dx * dx + dy * dy
end

return Math2D
