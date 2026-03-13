local GearLoot = {
  armor = {
    {
      id = "ossuary_plate",
      name = "Ossuary Plate",
      weight = 1,
      mods = {
        healthFlat = 24,
        speedMult = 0.94,
        damageReduction = 0.1,
      },
    },
    {
      id = "warden_mail",
      name = "Warden Mail",
      weight = 2,
      mods = {
        healthFlat = 14,
        damageReduction = 0.07,
        tetherDrainMult = 0.88,
      },
    },
    {
      id = "leech_hide",
      name = "Leech Hide",
      weight = 3,
      mods = {
        healthFlat = 8,
        lifeSteal = 0.1,
      },
    },
  },
  tools = {
    {
      id = "bone_chisel",
      name = "Bone Chisel",
      weight = 2,
      mods = {
        attackRangeFlat = 8,
        barricadeDamageMult = 1.28,
      },
    },
    {
      id = "ritual_spindle",
      name = "Ritual Spindle",
      weight = 2,
      mods = {
        attackCooldownMult = 0.92,
        tetherRegenFlat = 1.6,
      },
    },
    {
      id = "grave_hook",
      name = "Grave Hook",
      weight = 3,
      mods = {
        attackArcMult = 1.12,
        bleedChance = 0.14,
        bleedDamage = 3,
      },
    },
  },
  weapons = {
    {
      id = "reaper_cleaver",
      name = "Reaper Cleaver",
      weight = 1,
      mods = {
        attackDamageMult = 1.16,
        attackCooldownMult = 1.1,
        attackArcMult = 1.08,
      },
    },
    {
      id = "grave_pike",
      name = "Grave Pike",
      weight = 2,
      mods = {
        attackRangeFlat = 16,
        attackDamageMult = 1.08,
      },
    },
    {
      id = "sawtooth_flail",
      name = "Sawtooth Flail",
      weight = 3,
      mods = {
        attackDamageFlat = 4,
        bleedChance = 0.18,
        bleedDamage = 4,
      },
    },
  },
}

GearLoot.categoryOrder = { "armor", "tools", "weapons" }

GearLoot.categoryNames = {
  armor = "Armor",
  tools = "Tool",
  weapons = "Weapon",
}

return GearLoot
