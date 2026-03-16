local Config = {
  enabled = true,
  maxAttempts = 100,

  macro = {
    enabled = true,
    targetAreas = 12,
    variance = 3,
    minAreas = 8,
    maxAreas = 16,
    branchChance = 0.45,
    loopChance = 0.2,
    connectorWidth = 3,
    allowedZoneRect = {
      x1 = 5,
      y1 = 1,
      x2 = 8,
      y2 = 6,
    },
  },

  rooms = {
    min = 6,
    max = 10,
    minW = 5,
    maxW = 9,
    minH = 5,
    maxH = 7,
    padding = 2,
    placementAttempts = 120,
  },

  corridors = {
    width = 3,
  },

  extraConnections = {
    min = 1,
    max = 2,
  },

  wallThickness = {
    minVertical = 3,
    minHorizontal = 3,
    passes = 2,
  },

  cornerSpacing = {
    minStraightBetweenCorners = 2,
    allowedViolations = 1,
    passes = 12,
    allowRelaxedFallback = true,
  },

  entrySafeRadius = 3,
  minFloorTiles = 120,
  minFloorTilesPerArea = 110,

  enemies = {
    min = 8,
    max = 20,
    scalePerRoom = 0.55,
    scalePerArea = 0.25,
    variance = 1,
    minEntryDistance = 8,
    minPickupDistance = 5,
  },

  pickups = {
    extraMin = 2,
    extraMax = 4,
    minEntryDistance = 6,
  },
}

return Config
