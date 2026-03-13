local Generator = {}

local function makeGrid(width, height, value)
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do
      grid[y][x] = value
    end
  end
  return grid
end

local function inBounds(layout, x, y)
  return x >= 1 and y >= 1 and x <= layout.width and y <= layout.height
end

local function carveTile(layout, x, y)
  if inBounds(layout, x, y) then
    layout.blocked[y][x] = false
  end
end

local function carveRect(layout, x1, y1, x2, y2)
  for y = y1, y2 do
    for x = x1, x2 do
      carveTile(layout, x, y)
    end
  end
end

local function isRectClear(rooms, x1, y1, x2, y2, padding)
  for _, room in ipairs(rooms) do
    if x1 <= room.x2 + padding and x2 >= room.x1 - padding and y1 <= room.y2 + padding and y2 >= room.y1 - padding then
      return false
    end
  end
  return true
end

local function addRoom(layout, rooms, x1, y1, w, h, padding)
  local x2 = x1 + w - 1
  local y2 = y1 + h - 1
  if not isRectClear(rooms, x1, y1, x2, y2, padding) then
    return nil
  end
  local room = {
    x1 = x1,
    y1 = y1,
    x2 = x2,
    y2 = y2,
    cx = math.floor((x1 + x2) * 0.5),
    cy = math.floor((y1 + y2) * 0.5),
  }
  table.insert(rooms, room)
  carveRect(layout, room.x1, room.y1, room.x2, room.y2)
  return room
end

local function carveHorizontal(layout, x1, x2, y, width)
  local minOff = -math.floor((width - 1) * 0.5)
  local maxOff = math.floor(width * 0.5)
  local step = (x1 <= x2) and 1 or -1
  local x = x1
  while true do
    for oy = minOff, maxOff do
      carveTile(layout, x, y + oy)
    end
    if x == x2 then
      break
    end
    x = x + step
  end
end

local function carveVertical(layout, y1, y2, x, width)
  local minOff = -math.floor((width - 1) * 0.5)
  local maxOff = math.floor(width * 0.5)
  local step = (y1 <= y2) and 1 or -1
  local y = y1
  while true do
    for ox = minOff, maxOff do
      carveTile(layout, x + ox, y)
    end
    if y == y2 then
      break
    end
    y = y + step
  end
end

local function carveCorridor(layout, a, b, width, rng)
  local cornerPad = 1
  if rng:random() < 0.5 then
    carveHorizontal(layout, a.cx, b.cx, a.cy, width)
    carveVertical(layout, a.cy, b.cy, b.cx, width)
    carveRect(layout, b.cx - cornerPad, a.cy - cornerPad, b.cx + cornerPad, a.cy + cornerPad)
  else
    carveVertical(layout, a.cy, b.cy, a.cx, width)
    carveHorizontal(layout, a.cx, b.cx, b.cy, width)
    carveRect(layout, a.cx - cornerPad, b.cy - cornerPad, a.cx + cornerPad, b.cy + cornerPad)
  end
end

local function buildMST(rooms)
  local edges = {}
  if #rooms <= 1 then
    return edges
  end

  local connected = { [1] = true }
  local connectedCount = 1

  while connectedCount < #rooms do
    local bestA, bestB
    local bestDist = math.huge

    for i = 1, #rooms do
      if connected[i] then
        for j = 1, #rooms do
          if not connected[j] then
            local a = rooms[i]
            local b = rooms[j]
            local d = math.abs(a.cx - b.cx) + math.abs(a.cy - b.cy)
            if d < bestDist then
              bestDist = d
              bestA = i
              bestB = j
            end
          end
        end
      end
    end

    if not bestA or not bestB then
      break
    end

    table.insert(edges, { a = bestA, b = bestB })
    connected[bestB] = true
    connectedCount = connectedCount + 1
  end

  return edges
end

local function edgeKey(i, j)
  if i < j then
    return i .. ":" .. j
  end
  return j .. ":" .. i
end

local function addExtraConnections(edges, rooms, rng, minCount, maxCount)
  if #rooms <= 2 then
    return
  end

  local existing = {}
  for _, edge in ipairs(edges) do
    existing[edgeKey(edge.a, edge.b)] = true
  end

  local candidates = {}
  for i = 1, #rooms - 1 do
    for j = i + 1, #rooms do
      local key = edgeKey(i, j)
      if not existing[key] then
        table.insert(candidates, { a = i, b = j })
      end
    end
  end

  if #candidates == 0 then
    return
  end

  local target = math.min(rng:random(minCount, maxCount), #candidates)
  for _ = 1, target do
    local idx = rng:random(1, #candidates)
    table.insert(edges, candidates[idx])
    table.remove(candidates, idx)
    if #candidates == 0 then
      break
    end
  end
end

local function carveEntryBubble(layout, entry, radius)
  carveRect(layout, entry.x - radius, entry.y - radius, entry.x + radius, entry.y + radius)
end

local function sealPerimeter(layout)
  for x = 1, layout.width do
    layout.blocked[1][x] = true
    layout.blocked[layout.height][x] = true
  end
  for y = 1, layout.height do
    layout.blocked[y][1] = true
    layout.blocked[y][layout.width] = true
  end
end

local function enforceVerticalWallThickness(layout, minThickness)
  local changed = false
  local width = layout.width
  local height = layout.height

  for y = 2, height - 1 do
    local x = 2
    while x <= width - 1 do
      if layout.blocked[y][x] then
        local x1 = x
        while x <= width - 1 and layout.blocked[y][x] do
          x = x + 1
        end
        local x2 = x - 1

        if not layout.blocked[y][x1 - 1] and not layout.blocked[y][x2 + 1] then
          local needed = minThickness - (x2 - x1 + 1)
          local left = x1 - 1
          local right = x2 + 1
          while needed > 0 do
            local didGrow = false

            if left >= 2 and not layout.blocked[y][left] then
              layout.blocked[y][left] = true
              left = left - 1
              needed = needed - 1
              changed = true
              didGrow = true
            end

            if needed > 0 and right <= width - 1 and not layout.blocked[y][right] then
              layout.blocked[y][right] = true
              right = right + 1
              needed = needed - 1
              changed = true
              didGrow = true
            end

            if not didGrow then
              break
            end
          end
        end
      else
        x = x + 1
      end
    end
  end

  return changed
end

local function enforceHorizontalWallThickness(layout, minThickness)
  local changed = false
  local width = layout.width
  local height = layout.height

  for x = 2, width - 1 do
    local y = 2
    while y <= height - 1 do
      if layout.blocked[y][x] then
        local y1 = y
        while y <= height - 1 and layout.blocked[y][x] do
          y = y + 1
        end
        local y2 = y - 1

        if not layout.blocked[y1 - 1][x] and not layout.blocked[y2 + 1][x] then
          local needed = minThickness - (y2 - y1 + 1)
          local up = y1 - 1
          local down = y2 + 1
          while needed > 0 do
            local didGrow = false

            if up >= 2 and not layout.blocked[up][x] then
              layout.blocked[up][x] = true
              up = up - 1
              needed = needed - 1
              changed = true
              didGrow = true
            end

            if needed > 0 and down <= height - 1 and not layout.blocked[down][x] then
              layout.blocked[down][x] = true
              down = down + 1
              needed = needed - 1
              changed = true
              didGrow = true
            end

            if not didGrow then
              break
            end
          end
        end
      else
        y = y + 1
      end
    end
  end

  return changed
end

local function enforceWallThickness(layout, rules)
  if type(rules) ~= "table" then
    return
  end

  local minVertical = math.max(1, math.floor(rules.minVertical or 1))
  local minHorizontal = math.max(1, math.floor(rules.minHorizontal or 1))
  local passes = math.max(1, math.floor(rules.passes or 1))

  if minVertical <= 1 and minHorizontal <= 1 then
    return
  end

  for _ = 1, passes do
    local changed = false
    if minVertical > 1 and enforceVerticalWallThickness(layout, minVertical) then
      changed = true
    end
    if minHorizontal > 1 and enforceHorizontalWallThickness(layout, minHorizontal) then
      changed = true
    end
    if not changed then
      break
    end
  end
end

local function isWalkableAt(layout, x, y)
  return x >= 1 and y >= 1 and x <= layout.width and y <= layout.height and not layout.blocked[y][x]
end

local function isBlockedAt(layout, x, y)
  return x >= 1 and y >= 1 and x <= layout.width and y <= layout.height and layout.blocked[y][x]
end

local function isTopEdge(layout, x, y)
  return isBlockedAt(layout, x, y) and not isWalkableAt(layout, x, y - 1) and isWalkableAt(layout, x, y + 1)
end

local function isBottomEdge(layout, x, y)
  return isBlockedAt(layout, x, y) and isWalkableAt(layout, x, y - 1) and not isWalkableAt(layout, x, y + 1)
end

local function isLeftEdge(layout, x, y)
  return isBlockedAt(layout, x, y) and not isWalkableAt(layout, x - 1, y) and isWalkableAt(layout, x + 1, y)
end

local function isRightEdge(layout, x, y)
  return isBlockedAt(layout, x, y) and isWalkableAt(layout, x - 1, y) and not isWalkableAt(layout, x + 1, y)
end

local function removeShortHorizontalEdgeRuns(layout, edgePredicate, requiredRun)
  local violations = 0
  for y = 2, layout.height - 1 do
    local x = 2
    while x <= layout.width - 1 do
      if edgePredicate(layout, x, y) then
        local x1 = x
        while x <= layout.width - 1 and edgePredicate(layout, x, y) do
          x = x + 1
        end
        local x2 = x - 1
        if (x2 - x1 + 1) < requiredRun then
          violations = violations + 1
        end
      else
        x = x + 1
      end
    end
  end
  return violations
end

local function removeShortVerticalEdgeRuns(layout, edgePredicate, requiredRun)
  local violations = 0
  for x = 2, layout.width - 1 do
    local y = 2
    while y <= layout.height - 1 do
      if edgePredicate(layout, x, y) then
        local y1 = y
        while y <= layout.height - 1 and edgePredicate(layout, x, y) do
          y = y + 1
        end
        local y2 = y - 1
        if (y2 - y1 + 1) < requiredRun then
          violations = violations + 1
        end
      else
        y = y + 1
      end
    end
  end
  return violations
end

local function enforceMinStraightWalls(layout, rules)
  if type(rules) ~= "table" then
    return 0, 0
  end

  local minStraight = math.max(0, math.floor(rules.minStraightBetweenCorners or 0))
  if minStraight <= 0 then
    return 0, 0
  end

  local requiredRun = minStraight + 2
  local allowedViolations = math.max(0, math.floor(rules.allowedViolations or 0))

  local violations = 0
  violations = violations + removeShortHorizontalEdgeRuns(layout, isTopEdge, requiredRun)
  violations = violations + removeShortHorizontalEdgeRuns(layout, isBottomEdge, requiredRun)
  violations = violations + removeShortVerticalEdgeRuns(layout, isLeftEdge, requiredRun)
  violations = violations + removeShortVerticalEdgeRuns(layout, isRightEdge, requiredRun)

  return violations, allowedViolations
end

function Generator.generate(context, rng, config)
  local layout = {
    width = context.zoneWidth,
    height = context.zoneHeight,
    blocked = makeGrid(context.zoneWidth, context.zoneHeight, true),
    rooms = {},
    entry = {
      x = context.entryLocal.x,
      y = context.entryLocal.y,
    },
  }

  local firstW = rng:random(config.rooms.minW, config.rooms.maxW)
  local firstH = rng:random(config.rooms.minH, config.rooms.maxH)
  local firstX = math.max(2, math.min(layout.width - firstW, layout.entry.x - math.floor(firstW * 0.5)))
  local firstY = math.max(2, math.min(layout.height - firstH, layout.entry.y - math.floor(firstH * 0.5)))
  addRoom(layout, layout.rooms, firstX, firstY, firstW, firstH, config.rooms.padding)

  local targetRooms = rng:random(config.rooms.min, config.rooms.max)
  local tries = 0
  while #layout.rooms < targetRooms and tries < config.rooms.placementAttempts do
    tries = tries + 1
    local w = rng:random(config.rooms.minW, config.rooms.maxW)
    local h = rng:random(config.rooms.minH, config.rooms.maxH)
    local x = rng:random(2, math.max(2, layout.width - w))
    local y = rng:random(2, math.max(2, layout.height - h))
    addRoom(layout, layout.rooms, x, y, w, h, config.rooms.padding)
  end

  local edges = buildMST(layout.rooms)
  addExtraConnections(edges, layout.rooms, rng, config.extraConnections.min, config.extraConnections.max)

  for _, edge in ipairs(edges) do
    local a = layout.rooms[edge.a]
    local b = layout.rooms[edge.b]
    carveCorridor(layout, a, b, config.corridors.width, rng)
  end

  carveEntryBubble(layout, layout.entry, config.entrySafeRadius)
  enforceWallThickness(layout, config.wallThickness)
  sealPerimeter(layout)
  carveTile(layout, layout.entry.x, layout.entry.y)
  local cornerViolations, cornerAllowed = enforceMinStraightWalls(layout, config.cornerSpacing)
  layout.cornerSpacingViolations = cornerViolations
  layout.cornerSpacingAllowedViolations = cornerAllowed
  layout.cornerSpacingPassed = cornerViolations <= cornerAllowed
  carveTile(layout, layout.entry.x, layout.entry.y)

  return layout
end

return Generator
