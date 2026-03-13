local Helpers = require("src.world.world_helpers")

local Population = {}

function Population.apply(map, tileToWorld, terrainMeta)
  local interiors = terrainMeta.interiors
  local i1, i2, i3, i4 = interiors[1], interiors[2], interiors[3], interiors[4]

  Helpers.addNpc(map, tileToWorld, 1, 1, 9, 12, "Mara the Miller", "The old trail east reaches the cave through the pines.")
  Helpers.addNpc(map, tileToWorld, 1, 2, 14, 9, "Old Bram", "The town now stretches from hilltop to riverbank.")
  Helpers.addNpc(map, tileToWorld, 1, 3, 11, 11, "Rook the Tanner", "If you need parts, graves north of here are untouched.")
  Helpers.addNpc(map, tileToWorld, 2, 1, 10, 10, "Sister Ysolde", "I keep watch over the hill town above the graves.")
  Helpers.addNpc(map, tileToWorld, i1.zx, i1.zy, i1.lx + 5, i1.ly + 3, "Mara", "Welcome home. The kettle's still warm.")
  Helpers.addNpc(map, tileToWorld, i2.zx, i2.zy, i2.lx + 4, i2.ly + 3, "Bram", "Do not mind the creak. These beams are old.")
  Helpers.addNpc(map, tileToWorld, i3.zx, i3.zy, i3.lx + 7, i3.ly + 3, "Rook", "Boots by the door, tools by the hearth.")
  Helpers.addNpc(map, tileToWorld, i4.zx, i4.zy, i4.lx + 5, i4.ly + 3, "Ysolde", "Even indoors, keep a light for wandering souls.")

  Helpers.addGrave(map, tileToWorld, 2, 2, 8, 7, "head")
  Helpers.addGrave(map, tileToWorld, 2, 2, 12, 8, "torso")
  Helpers.addGrave(map, tileToWorld, 2, 2, 16, 7, "left_arm")
  Helpers.addGrave(map, tileToWorld, 2, 2, 20, 8, "right_arm")
  Helpers.addGrave(map, tileToWorld, 2, 2, 10, 13, "left_leg")
  Helpers.addGrave(map, tileToWorld, 2, 2, 14, 14, "right_leg")
  Helpers.addGrave(map, tileToWorld, 2, 2, 18, 13, "head")
  Helpers.addGrave(map, tileToWorld, 2, 2, 22, 14, "torso")

  Helpers.addWarp(map, tileToWorld, 4, 2, 29, 11, 2, 3, 5, 11, "You descend into the cave.")
  Helpers.addWarp(map, tileToWorld, 2, 3, 4, 11, 4, 2, 28, 11, "You emerge into the forest.")

  Helpers.placePickup(map, tileToWorld, 2, 3, 8, 6, "head")
  Helpers.placePickup(map, tileToWorld, 2, 3, 12, 6, "head")
  Helpers.placePickup(map, tileToWorld, 2, 3, 16, 6, "torso")
  Helpers.placePickup(map, tileToWorld, 2, 3, 20, 6, "torso")
  Helpers.placePickup(map, tileToWorld, 2, 3, 8, 10, "left_arm")
  Helpers.placePickup(map, tileToWorld, 2, 3, 12, 10, "left_arm")
  Helpers.placePickup(map, tileToWorld, 2, 3, 16, 10, "right_arm")
  Helpers.placePickup(map, tileToWorld, 2, 3, 20, 10, "right_arm")
  Helpers.placePickup(map, tileToWorld, 2, 3, 8, 14, "left_leg")
  Helpers.placePickup(map, tileToWorld, 2, 3, 12, 14, "left_leg")
  Helpers.placePickup(map, tileToWorld, 2, 3, 16, 14, "right_leg")
  Helpers.placePickup(map, tileToWorld, 2, 3, 20, 14, "right_leg")

  Helpers.placeEnemy(map, tileToWorld, 4, 2, 9, 9, "hunter")
  Helpers.placeEnemy(map, tileToWorld, 4, 2, 16, 14, "brute")
  Helpers.placeEnemy(map, tileToWorld, 4, 2, 22, 8, "skirmisher")
  Helpers.placeEnemy(map, tileToWorld, 2, 3, 24, 10, "hunter")
  Helpers.placeEnemy(map, tileToWorld, 3, 3, 18, 8, "skirmisher")
  Helpers.placeEnemy(map, tileToWorld, 4, 3, 10, 11, "brute")

  local bTx, bTy = Helpers.zoneTile(map, 4, 3, 26, 11)
  table.insert(map.barricades, {
    tx = bTx,
    ty = bTy,
    health = 55,
    maxHealth = 55,
    broken = false,
    requiredStrength = 28,
  })

  local eTx, eTy = Helpers.zoneTile(map, 4, 3, 30, 11)
  map.exit = { tx = eTx, ty = eTy }
end

return Population
