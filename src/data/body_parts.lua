local BodyParts = {
  head = {
    {
      id = "grim_skull",
      name = "Grim Skull",
      stats = { speed = 6, strength = 2, health = 10 },
      trait = "Feral Focus",
    },
    {
      id = "stag_helm",
      name = "Stag Helm",
      stats = { speed = 2, strength = 4, health = 16 },
      trait = "Bone Antlers",
    },
  },
  torso = {
    {
      id = "iron_ribcage",
      name = "Iron Ribcage",
      stats = { speed = -4, strength = 6, health = 40 },
      trait = "Dense Frame",
    },
    {
      id = "stitched_chest",
      name = "Stitched Chest",
      stats = { speed = 4, strength = 2, health = 26 },
      trait = "Elastic Tendons",
    },
  },
  left_arm = {
    {
      id = "hook_arm",
      name = "Hook Arm",
      stats = { speed = 0, strength = 7, health = 8 },
      trait = "Rend",
    },
    {
      id = "scout_arm",
      name = "Scout Arm",
      stats = { speed = 4, strength = 3, health = 6 },
      trait = "Swift Strikes",
    },
  },
  right_arm = {
    {
      id = "crusher_arm",
      name = "Crusher Arm",
      stats = { speed = -2, strength = 8, health = 14 },
      trait = "Siege Punch",
    },
    {
      id = "duelist_arm",
      name = "Duelist Arm",
      stats = { speed = 4, strength = 4, health = 8 },
      trait = "Quick Jab",
    },
  },
  left_leg = {
    {
      id = "wolf_leg",
      name = "Wolf Leg",
      stats = { speed = 10, strength = 2, health = 10 },
      trait = "Lunge",
    },
    {
      id = "pillar_leg",
      name = "Pillar Leg",
      stats = { speed = -2, strength = 5, health = 22 },
      trait = "Stable Gait",
    },
  },
  right_leg = {
    {
      id = "lynx_leg",
      name = "Lynx Leg",
      stats = { speed = 10, strength = 1, health = 8 },
      trait = "Fleet Step",
    },
    {
      id = "bulwark_leg",
      name = "Bulwark Leg",
      stats = { speed = -1, strength = 5, health = 24 },
      trait = "Grounded",
    },
  },
}

BodyParts.slotOrder = {
  "head",
  "torso",
  "left_arm",
  "right_arm",
  "left_leg",
  "right_leg",
}

BodyParts.slotNames = {
  head = "Head",
  torso = "Torso",
  left_arm = "Left Arm",
  right_arm = "Right Arm",
  left_leg = "Left Leg",
  right_leg = "Right Leg",
}

return BodyParts
