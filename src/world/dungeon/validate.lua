local Validate = {}

local neighbors = {
  { 1, 0 },
  { -1, 0 },
  { 0, 1 },
  { 0, -1 },
}

local function inBounds(layout, x, y)
  return x >= 1 and y >= 1 and x <= layout.width and y <= layout.height
end

local function floodFill(layout, entry)
  if not inBounds(layout, entry.x, entry.y) then
    return nil, 0
  end
  if layout.blocked[entry.y][entry.x] then
    return nil, 0
  end

  local visited = {}
  local qx = { entry.x }
  local qy = { entry.y }
  local head = 1
  local tail = 1
  local count = 0

  visited[entry.y] = { [entry.x] = true }

  while head <= tail do
    local x = qx[head]
    local y = qy[head]
    head = head + 1
    count = count + 1

    for _, n in ipairs(neighbors) do
      local nx = x + n[1]
      local ny = y + n[2]
      if inBounds(layout, nx, ny) and not layout.blocked[ny][nx] then
        if not visited[ny] then
          visited[ny] = {}
        end
        if not visited[ny][nx] then
          visited[ny][nx] = true
          tail = tail + 1
          qx[tail] = nx
          qy[tail] = ny
        end
      end
    end
  end

  return visited, count
end

local function isReachable(visited, x, y)
  return visited and visited[y] and visited[y][x]
end

function Validate.check(_, layout, content, config)
  local visited, floorCount = floodFill(layout, layout.entry)
  if not visited then
    return false
  end
  if floorCount < config.minFloorTiles then
    return false
  end

  for _, pickup in ipairs(content.pickups) do
    if not isReachable(visited, pickup.x, pickup.y) then
      return false
    end
  end

  for _, enemy in ipairs(content.enemies) do
    if not isReachable(visited, enemy.x, enemy.y) then
      return false
    end
  end

  return true
end

return Validate
