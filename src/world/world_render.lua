local Render = {}

function Render.draw(map, tileSize, tileToWorld, getZoneBoundsPixels)
  for y = 1, map.height do
    for x = 1, map.width do
      local worldX = (x - 1) * tileSize
      local worldY = (y - 1) * tileSize
      if map.tiles[y][x] == "wall" then
        love.graphics.setColor(0.18, 0.21, 0.18)
      else
        local tint = ((x + y) % 2 == 0) and 0.3 or 0.33
        love.graphics.setColor(0.2, tint, 0.24)
      end
      love.graphics.rectangle("fill", worldX, worldY, tileSize, tileSize)
    end
  end

  for zx = 1, map.zonesX do
    for zy = 1, map.zonesY do
      local b = getZoneBoundsPixels(map, zx, zy)
      love.graphics.setColor(0.36, 0.42, 0.34, 0.26)
      love.graphics.rectangle("line", b.left + 2, b.top + 2, b.right - b.left - 4, b.bottom - b.top - 4)
    end
  end

  for _, path in ipairs(map.paths) do
    love.graphics.setColor(0.56, 0.52, 0.34, 0.95)
    love.graphics.rectangle("fill", path.x, path.y, path.w, path.h, 8, 8)
    love.graphics.setColor(0.64, 0.6, 0.4, 0.28)
    love.graphics.rectangle("line", path.x, path.y, path.w, path.h, 8, 8)
  end

  if map.exit then
    local pos = tileToWorld(map.exit.tx, map.exit.ty)
    love.graphics.setColor(0.3, 0.8, 0.4)
    love.graphics.circle("fill", pos.x, pos.y, tileSize * 0.28)
  end

  for _, barricade in ipairs(map.barricades) do
    if not barricade.broken then
      local pos = tileToWorld(barricade.tx, barricade.ty)
      love.graphics.setColor(0.48, 0.26, 0.14)
      love.graphics.rectangle("fill", pos.x - tileSize * 0.4, pos.y - tileSize * 0.4, tileSize * 0.8, tileSize * 0.8)
      love.graphics.setColor(0.85, 0.4, 0.28)
      local ratio = barricade.health / barricade.maxHealth
      love.graphics.rectangle("fill", pos.x - tileSize * 0.4, pos.y - tileSize * 0.52, tileSize * 0.8 * ratio, 5)
    end
  end

  for _, grave in ipairs(map.graves) do
    if grave.dug then
      love.graphics.setColor(0.28, 0.2, 0.16)
      love.graphics.rectangle("fill", grave.x - 10, grave.y - 6, 20, 12)
    else
      love.graphics.setColor(0.66, 0.66, 0.62)
      love.graphics.rectangle("fill", grave.x - 8, grave.y - 12, 16, 24)
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.rectangle("line", grave.x - 8, grave.y - 12, 16, 24)
    end
  end

  for _, npc in ipairs(map.npcs) do
    love.graphics.setColor(0.82, 0.83, 0.68)
    love.graphics.circle("fill", npc.x, npc.y, 10)
    love.graphics.setColor(0.16, 0.2, 0.18)
    love.graphics.print("!", npc.x - 3, npc.y - 8)
  end

  for _, warp in ipairs(map.warps) do
    if warp.kind == "door" then
      local w, h = 16, 20
      love.graphics.setColor(0.42, 0.27, 0.16, 0.92)
      love.graphics.rectangle("fill", warp.fromX - w * 0.5, warp.fromY - h, w, h, 6, 6)
      love.graphics.setColor(0.62, 0.45, 0.28, 0.95)
      love.graphics.rectangle("line", warp.fromX - w * 0.5, warp.fromY - h, w, h, 6, 6)
      love.graphics.setColor(0.88, 0.79, 0.36, 0.95)
      love.graphics.circle("fill", warp.fromX + 4, warp.fromY - h * 0.45, 2)
    else
      love.graphics.setColor(0.2, 0.38, 0.86, 0.35)
      love.graphics.circle("fill", warp.fromX, warp.fromY, 12)
      love.graphics.setColor(0.46, 0.63, 0.9)
      love.graphics.circle("line", warp.fromX, warp.fromY, 11)
      love.graphics.circle("line", warp.fromX, warp.fromY, 15)
    end
  end

  for _, pickup in ipairs(map.pickups) do
    if not pickup.taken then
      if pickup.kind == "gear" then
        local category = pickup.category or "tools"
        if category == "armor" then
          love.graphics.setColor(0.58, 0.76, 0.84)
        elseif category == "weapons" then
          love.graphics.setColor(0.84, 0.56, 0.4)
        else
          love.graphics.setColor(0.72, 0.82, 0.52)
        end
        love.graphics.rectangle("fill", pickup.x - 7, pickup.y - 7, 14, 14, 3, 3)
        love.graphics.setColor(0.12, 0.12, 0.12)
        love.graphics.print((category:sub(1, 1) or "?"):upper(), pickup.x - 4, pickup.y - 8)
      else
        love.graphics.setColor(0.85, 0.82, 0.74)
        love.graphics.circle("fill", pickup.x, pickup.y, tileSize * 0.2)
        love.graphics.setColor(0.2, 0.2, 0.22)
        local tag = pickup.slot:sub(1, 1):upper()
        love.graphics.print(tag, pickup.x - 4, pickup.y - 8)
      end
    end
  end
end

return Render
