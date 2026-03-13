local TiledMap = {}

local TILE_FLIP_HORIZONTAL = 2147483648
local TILE_FLIP_VERTICAL = 1073741824
local TILE_FLIP_DIAGONAL = 536870912

local function splitGidFlags(gid)
  local id = math.floor(tonumber(gid) or 0)
  if id <= 0 then
    return 0, false, false, false
  end

  local h = false
  local v = false
  local d = false

  if id >= TILE_FLIP_HORIZONTAL then
    h = true
    id = id - TILE_FLIP_HORIZONTAL
  end
  if id >= TILE_FLIP_VERTICAL then
    v = true
    id = id - TILE_FLIP_VERTICAL
  end
  if id >= TILE_FLIP_DIAGONAL then
    d = true
    id = id - TILE_FLIP_DIAGONAL
  end

  return id, h, v, d
end

local function dirname(path)
  return path:match("^(.*)/[^/]+$") or "."
end

local function joinPath(a, b)
  if not b or b == "" then
    return a or "."
  end
  if b:sub(1, 1) == "/" then
    return b
  end
  local path
  if a == "." then
    path = b
  else
    path = a .. "/" .. b
  end

  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then
        table.remove(parts)
      end
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  return table.concat(parts, "/")
end

local function decodeTileLayerData(layer)
  if type(layer.data) == "table" then
    return layer.data
  end
  return nil
end

local function parseTsx(tilesetPath)
  local text, err = love.filesystem.read(tilesetPath)
  if not text then
    return nil, err
  end

  local function attr(name)
    local pattern = name .. '="([^"]+)"'
    return text:match(pattern)
  end

  local imageSource = text:match("source%s*=%s*\"([^\"]+)\"")
  if not imageSource then
    imageSource = text:match("source%s*=%s*'([^']+)'")
  end
  local tilewidth = tonumber(attr("tilewidth") or "16")
  local tileheight = tonumber(attr("tileheight") or "16")
  local spacing = tonumber(attr("spacing") or "0")
  local margin = tonumber(attr("margin") or "0")
  local tilecount = tonumber(attr("tilecount") or "0")
  local columns = tonumber(attr("columns") or "1")

  return {
    image = imageSource,
    tilewidth = tilewidth,
    tileheight = tileheight,
    spacing = spacing,
    margin = margin,
    tilecount = tilecount,
    columns = columns,
  }
end

local function makeTilesetRuntime(mapDir, tileset)
  local resolved = tileset
  local externalRef = tileset.source or tileset.filename
  if externalRef then
    local tsxPath = joinPath(mapDir, externalRef)
    local parsed, err = parseTsx(tsxPath)
    if not parsed then
      error("Failed to parse TSX '" .. tsxPath .. "': " .. tostring(err))
    end
    parsed.firstgid = tileset.firstgid
    parsed._baseDir = dirname(tsxPath)
    resolved = parsed
  end

  if not resolved.image then
    error("Tileset image source missing for tileset firstgid=" .. tostring(resolved.firstgid))
  end

  local imageBase = resolved._baseDir or mapDir
  local imagePath = joinPath(imageBase, resolved.image)
  local image = love.graphics.newImage(imagePath)
  image:setFilter("nearest", "nearest")

  local quads = {}
  local tileWidth = resolved.tilewidth
  local tileHeight = resolved.tileheight
  local spacing = resolved.spacing or 0
  local margin = resolved.margin or 0
  local columns = resolved.columns or 1
  local tileCount = resolved.tilecount or columns

  for i = 0, tileCount - 1 do
    local col = i % columns
    local row = math.floor(i / columns)
    local x = margin + col * (tileWidth + spacing)
    local y = margin + row * (tileHeight + spacing)
    quads[i + 1] = love.graphics.newQuad(x, y, tileWidth, tileHeight, image:getDimensions())
  end

  return {
    firstgid = resolved.firstgid,
    image = image,
    quads = quads,
    tilewidth = tileWidth,
    tileheight = tileHeight,
  }
end

local function nextFirstGid(runtime)
  local maxGid = 0
  for _, tileset in ipairs(runtime.tilesets or {}) do
    local lastGid = tileset.firstgid + (#tileset.quads or 0) - 1
    if lastGid > maxGid then
      maxGid = lastGid
    end
  end
  return maxGid + 1
end

function TiledMap.addImageTileset(runtime, spec)
  if not runtime or not spec or not spec.imagePath then
    return nil, "Missing runtime or imagePath"
  end

  local image = love.graphics.newImage(spec.imagePath)
  image:setFilter("nearest", "nearest")

  local tileWidth = spec.tilewidth or spec.tileWidth or runtime.map.tilewidth or 16
  local tileHeight = spec.tileheight or spec.tileHeight or runtime.map.tileheight or 16
  local spacing = spec.spacing or 0
  local margin = spec.margin or 0
  local imageW, imageH = image:getDimensions()

  local columns = spec.columns
  if not columns or columns < 1 then
    columns = math.max(1, math.floor((imageW - margin * 2 + spacing) / (tileWidth + spacing)))
  end
  local rows = math.max(1, math.floor((imageH - margin * 2 + spacing) / (tileHeight + spacing)))
  local maxTileCount = math.max(1, columns * rows)
  local tileCount = spec.tilecount or spec.tileCount or maxTileCount
  tileCount = math.max(1, math.min(tileCount, maxTileCount))

  local firstgid = spec.firstgid or spec.firstGid or nextFirstGid(runtime)
  local quads = {}
  for i = 0, tileCount - 1 do
    local col = i % columns
    local row = math.floor(i / columns)
    local x = margin + col * (tileWidth + spacing)
    local y = margin + row * (tileHeight + spacing)
    quads[i + 1] = love.graphics.newQuad(x, y, tileWidth, tileHeight, imageW, imageH)
  end

  local tileset = {
    firstgid = firstgid,
    image = image,
    quads = quads,
    tilewidth = tileWidth,
    tileheight = tileHeight,
  }
  table.insert(runtime.tilesets, tileset)
  table.sort(runtime.tilesets, function(a, b)
    return a.firstgid < b.firstgid
  end)
  return tileset
end

local function findTilesetForGid(tilesetsRuntime, gid)
  local baseGid = splitGidFlags(gid)
  local best
  for _, tileset in ipairs(tilesetsRuntime) do
    if baseGid >= tileset.firstgid and (not best or tileset.firstgid > best.firstgid) then
      best = tileset
    end
  end
  return best
end

local function drawTileByGid(runtime, gid, tx, ty)
  if gid == 0 then
    return
  end
  local baseGid, flipH, flipV, flipD = splitGidFlags(gid)
  if baseGid == 0 then
    return
  end
  local tileset = findTilesetForGid(runtime.tilesets, baseGid)
  if not tileset then
    return
  end
  local localId = baseGid - tileset.firstgid + 1
  local quad = tileset.quads[localId]
  if not quad then
    return
  end

  local map = runtime.map
  local drawTileW = runtime.drawTileWidth or map.tilewidth
  local drawTileH = runtime.drawTileHeight or map.tileheight
  local px = (tx - 1) * drawTileW
  local py = (ty - 1) * drawTileH
  local sx = drawTileW / tileset.tilewidth
  local sy = drawTileH / tileset.tileheight

  local rotation = 0
  local scaleX = sx
  local scaleY = sy

  if flipD then
    if flipH and flipV then
      rotation = math.pi * 1.5
      scaleX = -scaleX
    elseif flipH then
      rotation = math.pi * 0.5
    elseif flipV then
      rotation = math.pi * 1.5
    else
      rotation = math.pi * 0.5
      scaleX = -scaleX
    end
  else
    if flipH then
      scaleX = -scaleX
    end
    if flipV then
      scaleY = -scaleY
    end
  end

  love.graphics.draw(
    tileset.image,
    quad,
    px + drawTileW * 0.5,
    py + drawTileH * 0.5,
    rotation,
    scaleX,
    scaleY,
    tileset.tilewidth * 0.5,
    tileset.tileheight * 0.5
  )
end

local function shouldSkipLayer(layer, skipLayerNames)
  if not skipLayerNames then
    return false
  end
  local name = string.lower(layer.name or "")
  return skipLayerNames[name] == true
end

local function isHiddenByRect(tx, ty, hideRects)
  if not hideRects then
    return false
  end
  for _, r in ipairs(hideRects) do
    if tx >= r.tx1 and tx <= r.tx2 and ty >= r.ty1 and ty <= r.ty2 then
      return true
    end
  end
  return false
end

local function drawTileLayer(runtime, layer, hideRects)
  local map = runtime.map
  local data = layer.dataDecoded
  for ty = 1, map.height do
    for tx = 1, map.width do
      if not isHiddenByRect(tx, ty, hideRects) then
        local idx = (ty - 1) * map.width + tx
        local gid = data[idx] or 0
        if gid ~= 0 then
          local baseGid = splitGidFlags(gid)
          local tileset = findTilesetForGid(runtime.tilesets, baseGid)
          if tileset then
            local localId = baseGid - tileset.firstgid + 1
            local quad = tileset.quads[localId]
            if quad then
              drawTileByGid(runtime, gid, tx, ty)
            end
          end
        end
      end
    end
  end
end

function TiledMap.loadFromLua(luaPath)
  local chunk, err = love.filesystem.load(luaPath)
  if not chunk then
    return nil, err
  end
  local map = chunk()
  if type(map) ~= "table" then
    return nil, "Tiled export did not return a table"
  end

  local mapDir = dirname(luaPath)
  local runtime = {
    map = map,
    tilelayers = {},
    collisionLayer = nil,
    collisionByName = {},
    objectLayers = {},
    tilesets = {},
  }

  for _, tileset in ipairs(map.tilesets or {}) do
    table.insert(runtime.tilesets, makeTilesetRuntime(mapDir, tileset))
  end

  table.sort(runtime.tilesets, function(a, b)
    return a.firstgid < b.firstgid
  end)

  for _, layer in ipairs(map.layers or {}) do
    if layer.type == "tilelayer" then
      layer.dataDecoded = decodeTileLayerData(layer) or {}
      table.insert(runtime.tilelayers, layer)
      local lname = (layer.name or ""):lower()
      if lname == "collision" then
        runtime.collisionLayer = layer
      end
      runtime.collisionByName[lname] = layer
    elseif layer.type == "objectgroup" then
      runtime.objectLayers[(layer.name or ""):lower()] = layer
    end
  end

  return runtime
end

function TiledMap.draw(runtime, overlay, opts)
  opts = opts or {}
  local skipLayerNames = opts.skipLayerNames
  for _, layer in ipairs(runtime.tilelayers) do
    if layer.visible ~= false and not shouldSkipLayer(layer, skipLayerNames) then
      drawTileLayer(runtime, layer)
    end
  end

  if overlay then
    for _, pickup in ipairs(overlay.pickups or {}) do
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
          love.graphics.rectangle("fill", pickup.x - 6, pickup.y - 6, 12, 12, 3, 3)
          love.graphics.setColor(0.12, 0.12, 0.12)
          love.graphics.print((category:sub(1, 1) or "?"):upper(), pickup.x - 4, pickup.y - 8)
          love.graphics.setColor(1, 1, 1, 1)
        else
          love.graphics.setColor(0.85, 0.82, 0.74)
          love.graphics.circle("fill", pickup.x, pickup.y, 6)
          love.graphics.setColor(0.2, 0.2, 0.22)
          local tag = ((pickup.slot or "?"):sub(1, 1) or "?"):upper()
          love.graphics.print(tag, pickup.x - 4, pickup.y - 8)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
    end
  end
end

function TiledMap.drawLayerByName(runtime, layerName, opts)
  opts = opts or {}
  local wanted = string.lower(layerName or "")
  if wanted == "" then
    return
  end
  for _, layer in ipairs(runtime.tilelayers or {}) do
    if layer.visible ~= false and string.lower(layer.name or "") == wanted then
      drawTileLayer(runtime, layer, opts.hideRects)
      return
    end
  end
end

function TiledMap.isBlocked(runtime, tx, ty)
  local map = runtime.map
  if tx < 1 or ty < 1 or tx > map.width or ty > map.height then
    return true
  end

  local layer = runtime.collisionLayer
  if not layer then
    layer = runtime.collisionByName["walls"] or runtime.collisionByName["blocked"]
  end

  if not layer then
    return false
  end

  local idx = (ty - 1) * map.width + tx
  local gid = (layer.dataDecoded and layer.dataDecoded[idx]) or 0
  return gid ~= 0
end

function TiledMap.getObjects(runtime, layerName)
  local layer = runtime.objectLayers[(layerName or ""):lower()]
  if not layer then
    return {}
  end
  return layer.objects or {}
end

return TiledMap
