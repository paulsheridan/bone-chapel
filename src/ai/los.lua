local Map = require("src.world.map")

local LOS = {}

function LOS.canSee(map, x1, y1, x2, y2)
  local tx1, ty1 = Map.worldToTile(x1, y1)
  local tx2, ty2 = Map.worldToTile(x2, y2)

  local dx = math.abs(tx2 - tx1)
  local sx = tx1 < tx2 and 1 or -1
  local dy = -math.abs(ty2 - ty1)
  local sy = ty1 < ty2 and 1 or -1
  local err = dx + dy

  local cx, cy = tx1, ty1
  while true do
    if Map.isBlocked(map, cx, cy) and not (cx == tx1 and cy == ty1) and not (cx == tx2 and cy == ty2) then
      return false
    end
    if cx == tx2 and cy == ty2 then
      break
    end
    local e2 = 2 * err
    if e2 >= dy then
      err = err + dy
      cx = cx + sx
    end
    if e2 <= dx then
      err = err + dx
      cy = cy + sy
    end
  end
  return true
end

return LOS
