local WallRules = {}

local function pickSparseVariant(variants, x, y, fallback, secondaryPct, tertiaryPct)
  if type(variants) ~= "table" or #variants == 0 then
    return fallback
  end

  local base = variants[1] or fallback
  local second = variants[2]
  local third = variants[3]
  if not second then
    return base
  end

  local roll = (x * 12582917 + y * 4256249) % 100
  if third and roll < (tertiaryPct or 4) then
    return third
  end
  if roll < ((secondaryPct or 8) + (tertiaryPct or 4)) then
    return second
  end
  return base
end

function WallRules.pick(theme, isWalkable, x, y, fallbackWallGid, opts)
  opts = opts or {}
  local walls = theme and theme.walls or nil
  local innerOverrides = theme and theme.innerCornerOverrides or nil
  local useInnerTopLeft = innerOverrides and innerOverrides.topLeft
  local useInnerTopRight = innerOverrides and innerOverrides.topRight
  local useInnerBottomLeft = innerOverrides and innerOverrides.bottomLeft
  local useInnerBottomRight = innerOverrides and innerOverrides.bottomRight
  local outerTopLeft = walls and (walls.outerTopLeft or walls.topLeft) or nil
  local outerTopRight = walls and (walls.outerTopRight or walls.topRight) or nil
  local outerBottomLeft = walls and (walls.outerBottomLeft or walls.bottomLeft) or nil
  local outerBottomRight = walls and (walls.outerBottomRight or walls.bottomRight) or nil

  local floorN = isWalkable(x, y - 1)
  local floorS = isWalkable(x, y + 1)
  local floorW = isWalkable(x - 1, y)
  local floorE = isWalkable(x + 1, y)
  local floorNN = isWalkable(x, y - 2)
  local floorSS = isWalkable(x, y + 2)
  local floorSSW = isWalkable(x - 1, y + 2)
  local floorSSE = isWalkable(x + 1, y + 2)
  local floorNW = isWalkable(x - 1, y - 1)
  local floorNE = isWalkable(x + 1, y - 1)
  local floorSW = isWalkable(x - 1, y + 1)
  local floorSE = isWalkable(x + 1, y + 1)

  if not floorS and floorSS then
    if floorW and not floorE then
      return (walls and (walls.topCapRight or walls.topCap) or fallbackWallGid), "top_cap_right_end"
    elseif floorE and not floorW then
      return (walls and (walls.topCapLeft or walls.topCap) or fallbackWallGid), "top_cap_left_end"
    end
    return (walls and (walls.topCap or walls.top) or fallbackWallGid), "top_cap"
  end

  if not floorN and not floorS and not floorW and not floorE then
    if not opts.skipTierUnderRule then
      local _, aboveRule = WallRules.pick(theme, isWalkable, x, y - 1, fallbackWallGid, { skipTierUnderRule = true })
      if aboveRule == "outer_top_cap_right_tier" then
        return (walls and (walls.right or walls.topCapLeft or walls.topCap) or fallbackWallGid),
          "right_under_outer_right_tier"
      end
    end

    if not floorSS then
      if floorSSE and not floorSSW and not floorSE then
        return (walls and (walls.outerTopCapLeft or walls.topCapLeft or walls.topCap or fallbackWallGid) or fallbackWallGid),
          "outer_top_cap_left_tier"
      elseif floorSSW and not floorSSE and not floorSW then
        return (walls and (walls.outerTopCapRight or walls.topCapRight or walls.topCap or fallbackWallGid) or fallbackWallGid),
          "outer_top_cap_right_tier"
      end
    end

    if floorSW and not floorSE then
      return (walls and (walls.right or fallbackWallGid) or fallbackWallGid), "right_stub"
    elseif floorSE and not floorSW then
      return (walls and (walls.left or fallbackWallGid) or fallbackWallGid), "left_stub"
    elseif floorNW and not floorNE then
      return (outerBottomRight or (walls and (walls.bottom or fallbackWallGid)) or fallbackWallGid), "outer_bottom_right"
    elseif floorNE and not floorNW then
      return (outerBottomLeft or (walls and (walls.bottom or fallbackWallGid)) or fallbackWallGid), "outer_bottom_left"
    elseif floorNN and not floorSS then
      if floorSSE and not floorSSW then
        if useInnerTopLeft then
          return (walls and (walls.innerTopLeft or walls.outerTopCapLeft or outerTopLeft or walls.top or fallbackWallGid)
              or fallbackWallGid),
            "inner_top_left_override"
        end
        return (walls and (walls.outerTopCapLeft or outerTopLeft or walls.top or fallbackWallGid) or fallbackWallGid),
          "outer_top_cap_left"
      elseif floorSSW and not floorSSE then
        if useInnerTopRight then
          return (walls and (walls.innerTopRight or walls.outerTopCapRight or outerTopRight or walls.top or fallbackWallGid)
              or fallbackWallGid),
            "inner_top_right_override"
        end
        return (walls and (walls.outerTopCapRight or outerTopRight or walls.top or fallbackWallGid) or fallbackWallGid),
          "outer_top_cap_right"
      end
    end

    return pickSparseVariant(theme and theme.unwalkableFloors, x, y, fallbackWallGid, 1, 0), "unwalkable_fill"
  end

  if not walls then
    return fallbackWallGid, "fallback_wall"
  end

  if floorS and floorE and not floorN and not floorW then
    return outerTopLeft or walls.top or fallbackWallGid, "outer_top_left"
  elseif floorS and floorW and not floorN and not floorE then
    return outerTopRight or walls.top or fallbackWallGid, "outer_top_right"
  elseif floorN and floorE and not floorS and not floorW then
    if useInnerBottomLeft then
      return walls.innerBottomLeft or outerBottomLeft or walls.bottom or fallbackWallGid, "inner_bottom_left_override"
    end
    return outerBottomLeft or walls.bottom or fallbackWallGid, "outer_bottom_left"
  elseif floorN and floorW and not floorS and not floorE then
    if useInnerBottomRight then
      return walls.innerBottomRight or outerBottomRight or walls.bottom or fallbackWallGid, "inner_bottom_right_override"
    end
    return outerBottomRight or walls.bottom or fallbackWallGid, "outer_bottom_right"
  end

  if floorS and floorE and floorW and not floorN and not floorSE then
    return walls.innerTopLeft or walls.top or fallbackWallGid, "inner_top_left"
  elseif floorS and floorE and floorW and not floorN and not floorSW then
    return walls.innerTopRight or walls.top or fallbackWallGid, "inner_top_right"
  elseif floorN and floorE and floorW and not floorS and not floorNE then
    return walls.innerBottomLeft or walls.bottom or fallbackWallGid, "inner_bottom_left"
  elseif floorN and floorE and floorW and not floorS and not floorNW then
    return walls.innerBottomRight or walls.bottom or fallbackWallGid, "inner_bottom_right"
  end

  if floorS and not floorN then
    return walls.top or fallbackWallGid, "top"
  elseif floorN and not floorS then
    return walls.bottom or fallbackWallGid, "bottom"
  elseif floorE and not floorW then
    return walls.left or fallbackWallGid, "left"
  elseif floorW and not floorE then
    return walls.right or fallbackWallGid, "right"
  elseif floorE or floorW then
    return walls.left or fallbackWallGid, "left_fallback"
  end

  return walls.top or fallbackWallGid, "top_fallback"
end

return WallRules
