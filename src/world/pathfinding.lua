local Pathfinding = {}

local function key(tx, ty)
  return tx .. ":" .. ty
end

local function heuristic(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end

local neighbors = {
  { 1, 0 },
  { -1, 0 },
  { 0, 1 },
  { 0, -1 },
  { 1, 1 },
  { 1, -1 },
  { -1, 1 },
  { -1, -1 },
}

function Pathfinding.findPath(map, startTx, startTy, goalTx, goalTy, isBlocked)
  if isBlocked(goalTx, goalTy) then
    return nil
  end

  local open = {}
  local openMap = {}
  local cameFrom = {}
  local gScore = {}
  local fScore = {}

  local startKey = key(startTx, startTy)
  gScore[startKey] = 0
  fScore[startKey] = heuristic(startTx, startTy, goalTx, goalTy)
  table.insert(open, { tx = startTx, ty = startTy, k = startKey })
  openMap[startKey] = true

  local function popLowest()
    local bestIndex = 1
    local bestNode = open[1]
    local bestF = fScore[bestNode.k] or math.huge
    for i = 2, #open do
      local node = open[i]
      local nodeF = fScore[node.k] or math.huge
      if nodeF < bestF then
        bestF = nodeF
        bestNode = node
        bestIndex = i
      end
    end
    table.remove(open, bestIndex)
    openMap[bestNode.k] = nil
    return bestNode
  end

  while #open > 0 do
    local current = popLowest()
    if current.tx == goalTx and current.ty == goalTy then
      local path = { { tx = goalTx, ty = goalTy } }
      local ck = current.k
      while cameFrom[ck] do
        local prev = cameFrom[ck]
        table.insert(path, 1, { tx = prev.tx, ty = prev.ty })
        ck = prev.k
      end
      return path
    end

    for _, n in ipairs(neighbors) do
      local nx = current.tx + n[1]
      local ny = current.ty + n[2]
      local canUse = not isBlocked(nx, ny)

      if canUse and n[1] ~= 0 and n[2] ~= 0 then
        if isBlocked(current.tx + n[1], current.ty) or isBlocked(current.tx, current.ty + n[2]) then
          canUse = false
        end
      end

      if canUse then
        local nk = key(nx, ny)
        local stepCost = (n[1] == 0 or n[2] == 0) and 1 or 1.414
        local tentativeG = (gScore[current.k] or math.huge) + stepCost
        if tentativeG < (gScore[nk] or math.huge) then
          cameFrom[nk] = { tx = current.tx, ty = current.ty, k = current.k }
          gScore[nk] = tentativeG
          fScore[nk] = tentativeG + heuristic(nx, ny, goalTx, goalTy)
          if not openMap[nk] then
            table.insert(open, { tx = nx, ty = ny, k = nk })
            openMap[nk] = true
          end
        end
      end
    end
  end
  return nil
end

return Pathfinding
