local MacroLayout = {}

local neighbors = {
  { 1, 0 },
  { -1, 0 },
  { 0, 1 },
  { 0, -1 },
}

local function zoneKey(zx, zy)
  return zx .. ":" .. zy
end

local function inAllowedRect(rect, zx, zy)
  if type(rect) ~= "table" then
    return true
  end
  local x1 = math.floor(rect.x1 or 1)
  local y1 = math.floor(rect.y1 or 1)
  local x2 = math.floor(rect.x2 or zx)
  local y2 = math.floor(rect.y2 or zy)
  if x2 < x1 then
    x1, x2 = x2, x1
  end
  if y2 < y1 then
    y1, y2 = y2, y1
  end
  return zx >= x1 and zx <= x2 and zy >= y1 and zy <= y2
end

local function clampInt(v, lo, hi)
  return math.max(lo, math.min(hi, math.floor(v)))
end

local function edgeKey(a, b)
  if a < b then
    return a .. ":" .. b
  end
  return b .. ":" .. a
end

function MacroLayout.generate(context, rng, config)
  local macro = (config and config.macro) or {}
  local map = context.map

  local target = math.floor(macro.targetAreas or 8)
  local variance = math.max(0, math.floor(macro.variance or 0))
  local minAreas = math.max(1, math.floor(macro.minAreas or 1))
  local maxAreas = math.max(minAreas, math.floor(macro.maxAreas or (map.zonesX * map.zonesY)))
  local desired = clampInt(target + rng:random(-variance, variance), minAreas, maxAreas)

  local anchor = { zx = context.anchorZoneX, zy = context.anchorZoneY }
  if anchor.zx < 1 or anchor.zx > map.zonesX or anchor.zy < 1 or anchor.zy > map.zonesY then
    return nil
  end

  local zoneSet = {}
  local zones = {}
  local treeEdges = {}
  local frontier = {}

  local function addFrontier(fromKey, zx, zy)
    if zx < 1 or zy < 1 or zx > map.zonesX or zy > map.zonesY then
      return
    end
    if not inAllowedRect(macro.allowedZoneRect, zx, zy) then
      return
    end
    local key = zoneKey(zx, zy)
    if zoneSet[key] or frontier[key] then
      return
    end
    frontier[key] = {
      fromKey = fromKey,
      zx = zx,
      zy = zy,
    }
  end

  local function addZone(zx, zy)
    local key = zoneKey(zx, zy)
    if zoneSet[key] then
      return key
    end
    zoneSet[key] = true
    table.insert(zones, { zx = zx, zy = zy, key = key })
    for _, n in ipairs(neighbors) do
      addFrontier(key, zx + n[1], zy + n[2])
    end
    return key
  end

  addZone(anchor.zx, anchor.zy)
  while #zones < desired do
    local frontierItems = {}
    for _, item in pairs(frontier) do
      table.insert(frontierItems, item)
    end
    if #frontierItems == 0 then
      break
    end

    local choice
    local branchChance = math.max(0, math.min(1, tonumber(macro.branchChance) or 0.45))
    if rng:random() < branchChance then
      choice = frontierItems[rng:random(1, #frontierItems)]
    else
      local bestDist = math.huge
      for _, item in ipairs(frontierItems) do
        local d = math.abs(item.zx - anchor.zx) + math.abs(item.zy - anchor.zy)
        if d < bestDist then
          bestDist = d
          choice = item
        end
      end
    end

    if not choice then
      break
    end

    frontier[zoneKey(choice.zx, choice.zy)] = nil
    local addedKey = addZone(choice.zx, choice.zy)
    if choice.fromKey and addedKey then
      table.insert(treeEdges, {
        a = choice.fromKey,
        b = addedKey,
      })
    end
  end

  local indexByKey = {}
  local minZx, maxZx = math.huge, -math.huge
  local minZy, maxZy = math.huge, -math.huge
  for i, zone in ipairs(zones) do
    indexByKey[zone.key] = i
    minZx = math.min(minZx, zone.zx)
    maxZx = math.max(maxZx, zone.zx)
    minZy = math.min(minZy, zone.zy)
    maxZy = math.max(maxZy, zone.zy)
  end

  local edges = {}
  local edgeSet = {}
  for _, e in ipairs(treeEdges) do
    local ai = indexByKey[e.a]
    local bi = indexByKey[e.b]
    if ai and bi then
      local key = edgeKey(ai, bi)
      if not edgeSet[key] then
        edgeSet[key] = true
        table.insert(edges, { a = ai, b = bi })
      end
    end
  end

  local loopChance = math.max(0, math.min(1, tonumber(macro.loopChance) or 0.2))
  for i = 1, #zones do
    for _, n in ipairs(neighbors) do
      local zx = zones[i].zx + n[1]
      local zy = zones[i].zy + n[2]
      local key = zoneKey(zx, zy)
      local j = indexByKey[key]
      if j and i < j then
        local ek = edgeKey(i, j)
        if not edgeSet[ek] and rng:random() < loopChance then
          edgeSet[ek] = true
          table.insert(edges, { a = i, b = j })
        end
      end
    end
  end

  return {
    zones = zones,
    zoneSet = zoneSet,
    zoneIndexByKey = indexByKey,
    edges = edges,
    targetAreas = desired,
    areaCount = #zones,
    minZx = minZx,
    maxZx = maxZx,
    minZy = minZy,
    maxZy = maxZy,
  }
end

return MacroLayout
