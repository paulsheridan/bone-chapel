local Config = {
  enabled = true,
  maxAttempts = 20,

  rooms = {
    min = 6,
    max = 10,
    minW = 4,
    maxW = 9,
    minH = 4,
    maxH = 7,
    padding = 1,
    placementAttempts = 120,
  },

  corridors = {
    width = 2,
  },

  extraConnections = {
    min = 1,
    max = 2,
  },

  wallThickness = {
    minVertical = 3,
    minHorizontal = 2,
    passes = 1,
  },

  cornerSpacing = {
    minStraightBetweenCorners = 2,
    passes = 12,
  },

  entrySafeRadius = 3,
  minFloorTiles = 120,

  enemies = {
    min = 3,
    max = 6,
    scalePerRoom = 0.55,
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
