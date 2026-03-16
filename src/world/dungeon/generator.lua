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
  local cornerPad = math.ceil(width * 0.75)
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

local function randomRoomPlacement(layout, rooms, rng, config)
  local targetRooms = rng:random(config.rooms.min, config.rooms.max)
  local tries = 0
  while #rooms < targetRooms and tries < config.rooms.placementAttempts do
    tries = tries + 1
    local w = rng:random(config.rooms.minW, config.rooms.maxW)
    local h = rng:random(config.rooms.minH, config.rooms.maxH)
    local x = rng:random(2, math.max(2, layout.width - w))
    local y = rng:random(2, math.max(2, layout.height - h))
    addRoom(layout, rooms, x, y, w, h, config.rooms.padding)
  end
end

local sealPerimeter
local enforceWallThickness
local enforceMinStraightWalls

local function generateArea(width, height, rng, config, entryLocal)
  local area = {
    width = width,
    height = height,
    blocked = makeGrid(width, height, true),
    rooms = {},
    entry = nil,
  }

  local firstW = rng:random(config.rooms.minW, config.rooms.maxW)
  local firstH = rng:random(config.rooms.minH, config.rooms.maxH)

  local firstX
  local firstY
  if entryLocal and entryLocal.x and entryLocal.y then
    local ex = math.max(2, math.min(width - 1, math.floor(entryLocal.x)))
    local ey = math.max(2, math.min(height - 1, math.floor(entryLocal.y)))
    firstX = math.max(2, math.min(width - firstW, ex - math.floor(firstW * 0.5)))
    firstY = math.max(2, math.min(height - firstH, ey - math.floor(firstH * 0.5)))
    area.entry = { x = ex, y = ey }
  else
    firstX = rng:random(2, math.max(2, width - firstW))
    firstY = rng:random(2, math.max(2, height - firstH))
  end

  addRoom(area, area.rooms, firstX, firstY, firstW, firstH, config.rooms.padding)
  randomRoomPlacement(area, area.rooms, rng, config)

  local edges = buildMST(area.rooms)
  addExtraConnections(edges, area.rooms, rng, config.extraConnections.min, config.extraConnections.max)
  for _, edge in ipairs(edges) do
    local a = area.rooms[edge.a]
    local b = area.rooms[edge.b]
    carveCorridor(area, a, b, config.corridors.width, rng)
  end

  if area.entry then
    carveEntryBubble(area, area.entry, config.entrySafeRadius)
  end

  enforceWallThickness(area, config.wallThickness)
  sealPerimeter(area)
  if area.entry then
    carveTile(area, area.entry.x, area.entry.y)
  end
  local cornerViolations, cornerAllowed = enforceMinStraightWalls(area, config.cornerSpacing)
  area.cornerSpacingViolations = cornerViolations
  area.cornerSpacingAllowedViolations = cornerAllowed
  area.cornerSpacingPassed = cornerViolations <= cornerAllowed
  if area.entry then
    carveTile(area, area.entry.x, area.entry.y)
  end

  return area
end

local function zoneKey(zx, zy)
  return zx .. ":" .. zy
end

local function carveHorizontalConnector(layout, x1, x2, y, width)
  carveHorizontal(layout, x1, x2, y, width)
end

local function carveVerticalConnector(layout, y1, y2, x, width)
  carveVertical(layout, y1, y2, x, width)
end

function Generator.generateComposite(context, macro, rng, config)
  if not macro or not macro.zones or #macro.zones == 0 then
    return nil
  end

  local map = context.map
  local zoneW = context.zoneWidth
  local zoneH = context.zoneHeight
  local layout = {
    width = map.width,
    height = map.height,
    blocked = makeGrid(map.width, map.height, true),
    rooms = {},
    entry = {
      x = context.entryTile.tx,
      y = context.entryTile.ty,
    },
    generatedZoneSet = {},
    generatedZones = macro.zones,
    macroEdges = macro.edges,
    areaCount = macro.areaCount,
  }

  local zoneCenters = {}

  for _, zone in ipairs(macro.zones) do
    local key = zoneKey(zone.zx, zone.zy)
    layout.generatedZoneSet[key] = true

    local tx1 = (zone.zx - 1) * zoneW + 1
    local ty1 = (zone.zy - 1) * zoneH + 1

    local entryLocal = nil
    if zone.zx == context.anchorZoneX and zone.zy == context.anchorZoneY then
      entryLocal = {
        x = context.entryLocal.x,
        y = context.entryLocal.y,
      }
    end

    local area = generateArea(zoneW, zoneH, rng, config, entryLocal)
    local sx = 0
    local sy = 0
    for _, room in ipairs(area.rooms) do
      local gcx = tx1 + room.cx - 1
      local gcy = ty1 + room.cy - 1
      sx = sx + gcx
      sy = sy + gcy
      table.insert(layout.rooms, {
        x1 = tx1 + room.x1 - 1,
        y1 = ty1 + room.y1 - 1,
        x2 = tx1 + room.x2 - 1,
        y2 = ty1 + room.y2 - 1,
        cx = gcx,
        cy = gcy,
      })
    end

    if #area.rooms > 0 then
      zoneCenters[key] = {
        x = math.floor(sx / #area.rooms + 0.5),
        y = math.floor(sy / #area.rooms + 0.5),
      }
    else
      zoneCenters[key] = {
        x = tx1 + math.floor(zoneW * 0.5),
        y = ty1 + math.floor(zoneH * 0.5),
      }
    end

    for ly = 1, zoneH do
      local gy = ty1 + ly - 1
      for lx = 1, zoneW do
        local gx = tx1 + lx - 1
        if not area.blocked[ly][lx] then
          layout.blocked[gy][gx] = false
        end
      end
    end
  end

  local connectorWidth = math.max(1, math.floor((config.macro and config.macro.connectorWidth) or config.corridors.width or 1))
  local connectorHalf = math.floor((connectorWidth - 1) * 0.5)

  for _, edge in ipairs(macro.edges or {}) do
    local a = macro.zones[edge.a]
    local b = macro.zones[edge.b]
    if a and b then
      local aKey = zoneKey(a.zx, a.zy)
      local bKey = zoneKey(b.zx, b.zy)
      local aCenter = zoneCenters[aKey]
      local bCenter = zoneCenters[bKey]
      if aCenter and bCenter then
        if a.zy == b.zy and math.abs(a.zx - b.zx) == 1 then
          local left = (a.zx < b.zx) and a or b
          local right = (left == a) and b or a
          local seamX = left.zx * zoneW
          local rowTop = (left.zy - 1) * zoneH + 1
          local localY = math.max(3, math.min(zoneH - 2, math.floor(zoneH * 0.5) + rng:random(-3, 3)))
          local gy = rowTop + localY - 1
          carveRect(layout, seamX - connectorHalf, gy - connectorHalf, seamX + 1 + connectorHalf, gy + connectorHalf)
          carveHorizontalConnector(layout, aCenter.x, seamX, gy, connectorWidth)
          carveHorizontalConnector(layout, seamX + 1, bCenter.x, gy, connectorWidth)
        elseif a.zx == b.zx and math.abs(a.zy - b.zy) == 1 then
          local top = (a.zy < b.zy) and a or b
          local bottom = (top == a) and b or a
          local seamY = top.zy * zoneH
          local colLeft = (top.zx - 1) * zoneW + 1
          local localX = math.max(3, math.min(zoneW - 2, math.floor(zoneW * 0.5) + rng:random(-4, 4)))
          local gx = colLeft + localX - 1
          carveRect(layout, gx - connectorHalf, seamY - connectorHalf, gx + connectorHalf, seamY + 1 + connectorHalf)
          carveVerticalConnector(layout, aCenter.y, seamY, gx, connectorWidth)
          carveVerticalConnector(layout, seamY + 1, bCenter.y, gx, connectorWidth)
        end
      end
    end
  end

  enforceWallThickness(layout, config.wallThickness)
  carveTile(layout, layout.entry.x, layout.entry.y)
  local cornerViolations, cornerAllowed = enforceMinStraightWalls(layout, config.cornerSpacing)
  layout.cornerSpacingViolations = cornerViolations
  layout.cornerSpacingAllowedViolations = cornerAllowed
  layout.cornerSpacingPassed = cornerViolations <= cornerAllowed
  carveTile(layout, layout.entry.x, layout.entry.y)

  return layout
end

function Generator.generateArea(width, height, rng, config, entryLocal)
  return generateArea(width, height, rng, config, entryLocal)
end

sealPerimeter = function(layout)
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

enforceWallThickness = function(layout, rules)
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

local function countShortHorizontalEdgeRuns(layout, edgePredicate, requiredRun)
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

local function countShortVerticalEdgeRuns(layout, edgePredicate, requiredRun)
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

local function fillWalkableAsWall(layout, x, y)
  if x < 1 or y < 1 or x > layout.width or y > layout.height then
    return false
  end
  if layout.blocked[y][x] then
    return false
  end
  layout.blocked[y][x] = true
  return true
end

local function repairShortHorizontalEdgeRuns(layout, edgePredicate, requiredRun, isTop)
  local repaired = false
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
          local targetY = isTop and (y + 1) or (y - 1)
          for rx = x1, x2 do
            if fillWalkableAsWall(layout, rx, targetY) then
              repaired = true
            end
          end
        end
      else
        x = x + 1
      end
    end
  end
  return repaired
end

local function repairShortVerticalEdgeRuns(layout, edgePredicate, requiredRun, isLeft)
  local repaired = false
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
          local targetX = isLeft and (x + 1) or (x - 1)
          for ry = y1, y2 do
            if fillWalkableAsWall(layout, targetX, ry) then
              repaired = true
            end
          end
        end
      else
        y = y + 1
      end
    end
  end
  return repaired
end

local function extendShortHorizontalEdgeRuns(layout, edgePredicate, requiredRun, isTop)
  local extended = false
  for y = 2, layout.height - 1 do
    local x = 2
    while x <= layout.width - 1 do
      if edgePredicate(layout, x, y) then
        local x1 = x
        while x <= layout.width - 1 and edgePredicate(layout, x, y) do
          x = x + 1
        end
        local x2 = x - 1
        local runLength = x2 - x1 + 1
        if runLength < requiredRun then
          local needed = requiredRun - runLength
          while needed > 0 do
            local didExtend = false
            if x1 > 2 then
              local canLeft
              if isTop then
                canLeft = isWalkableAt(layout, x1 - 1, y)
                  and isBlockedAt(layout, x1 - 1, y - 1)
                  and isWalkableAt(layout, x1 - 1, y + 1)
              else
                canLeft = isWalkableAt(layout, x1 - 1, y)
                  and isBlockedAt(layout, x1 - 1, y + 1)
                  and isWalkableAt(layout, x1 - 1, y - 1)
              end
              if canLeft then
                layout.blocked[y][x1 - 1] = true
                x1 = x1 - 1
                needed = needed - 1
                extended = true
                didExtend = true
              end
            end
            if needed > 0 and x2 < layout.width - 1 then
              local canRight
              if isTop then
                canRight = isWalkableAt(layout, x2 + 1, y)
                  and isBlockedAt(layout, x2 + 1, y - 1)
                  and isWalkableAt(layout, x2 + 1, y + 1)
              else
                canRight = isWalkableAt(layout, x2 + 1, y)
                  and isBlockedAt(layout, x2 + 1, y + 1)
                  and isWalkableAt(layout, x2 + 1, y - 1)
              end
              if canRight then
                layout.blocked[y][x2 + 1] = true
                x2 = x2 + 1
                needed = needed - 1
                extended = true
                didExtend = true
              end
            end
            if not didExtend then
              break
            end
          end
        end
      else
        x = x + 1
      end
    end
  end
  return extended
end

local function extendShortVerticalEdgeRuns(layout, edgePredicate, requiredRun, isLeft)
  local extended = false
  for x = 2, layout.width - 1 do
    local y = 2
    while y <= layout.height - 1 do
      if edgePredicate(layout, x, y) then
        local y1 = y
        while y <= layout.height - 1 and edgePredicate(layout, x, y) do
          y = y + 1
        end
        local y2 = y - 1
        local runLength = y2 - y1 + 1
        if runLength < requiredRun then
          local needed = requiredRun - runLength
          while needed > 0 do
            local didExtend = false
            if y1 > 2 then
              local canUp
              if isLeft then
                canUp = isWalkableAt(layout, x, y1 - 1)
                  and isBlockedAt(layout, x - 1, y1 - 1)
                  and isWalkableAt(layout, x + 1, y1 - 1)
              else
                canUp = isWalkableAt(layout, x, y1 - 1)
                  and isBlockedAt(layout, x + 1, y1 - 1)
                  and isWalkableAt(layout, x - 1, y1 - 1)
              end
              if canUp then
                layout.blocked[y1 - 1][x] = true
                y1 = y1 - 1
                needed = needed - 1
                extended = true
                didExtend = true
              end
            end
            if needed > 0 and y2 < layout.height - 1 then
              local canDown
              if isLeft then
                canDown = isWalkableAt(layout, x, y2 + 1)
                  and isBlockedAt(layout, x - 1, y2 + 1)
                  and isWalkableAt(layout, x + 1, y2 + 1)
              else
                canDown = isWalkableAt(layout, x, y2 + 1)
                  and isBlockedAt(layout, x + 1, y2 + 1)
                  and isWalkableAt(layout, x - 1, y2 + 1)
              end
              if canDown then
                layout.blocked[y2 + 1][x] = true
                y2 = y2 + 1
                needed = needed - 1
                extended = true
                didExtend = true
              end
            end
            if not didExtend then
              break
            end
          end
        end
      else
        y = y + 1
      end
    end
  end
  return extended
end

enforceMinStraightWalls = function(layout, rules)
  if type(rules) ~= "table" then
    return 0, 0
  end

  local minStraight = math.max(0, math.floor(rules.minStraightBetweenCorners or 0))
  if minStraight <= 0 then
    return 0, 0
  end

  local requiredRun = minStraight + 2
  local allowedViolations = math.max(0, math.floor(rules.allowedViolations or 0))
  local passes = math.max(1, math.floor(rules.passes or 1))

  for _ = 1, passes do
    local changed = false
    if extendShortHorizontalEdgeRuns(layout, isTopEdge, requiredRun, true) then
      changed = true
    end
    if extendShortHorizontalEdgeRuns(layout, isBottomEdge, requiredRun, false) then
      changed = true
    end
    if extendShortVerticalEdgeRuns(layout, isLeftEdge, requiredRun, true) then
      changed = true
    end
    if extendShortVerticalEdgeRuns(layout, isRightEdge, requiredRun, false) then
      changed = true
    end
    if not changed then
      break
    end
  end

  local violations = 0
  violations = violations + countShortHorizontalEdgeRuns(layout, isTopEdge, requiredRun)
  violations = violations + countShortHorizontalEdgeRuns(layout, isBottomEdge, requiredRun)
  violations = violations + countShortVerticalEdgeRuns(layout, isLeftEdge, requiredRun)
  violations = violations + countShortVerticalEdgeRuns(layout, isRightEdge, requiredRun)

  return violations, allowedViolations
end

function Generator.generate(context, rng, config)
  return generateArea(
    context.zoneWidth,
    context.zoneHeight,
    rng,
    config,
    {
      x = context.entryLocal.x,
      y = context.entryLocal.y,
    }
  )
end

return Generator
