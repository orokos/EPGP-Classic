-- A library to compute Gear Points for items as described in

local MAJOR_VERSION = "LibGearPoints-1.3"
local MINOR_VERSION = 10300

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local Debug = LibStub("LibDebug-1.0")
local ItemUtils = LibStub("LibItemUtils-1.0")
local LN = LibStub("LibLocalConstant-1.0")

-- Return recommended parameters
function lib:GetRecommendIlvlParams(version, levelCap)
  -- 0.06973 is our coefficient so that ilvl 359 chests cost exactly
  -- 1000gp.  In 4.2 and higher, we renormalize to make ilvl 378
  -- chests cost 1000.  Repeat ad infinitum!
  local standardIlvl
  local standardIlvlLastTier
  local standardIlvlNextTier
  local ilvlDenominator = 26 -- how much ilevel difference from standard affects cost, higher values mean less effect
  local version = version or select(4, GetBuildInfo())
  local levelCap = levelCap or MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]

  if version < 11303 then
    standardIlvl = 66
    standardIlvlLastTier = nil
    standardIlvlNextTier = 76
    ilvlDenominator = 10
  elseif version < 11306 then
    standardIlvl = 76
    standardIlvlLastTier = 66
    standardIlvlNextTier = 86
    ilvlDenominator = 10
  elseif version < 20501 then
    standardIlvl = 86
    standardIlvlLastTier = 76
    standardIlvlNextTier = nil
    ilvlDenominator = 10
  else
    standardIlvl = 120
    standardIlvlLastTier = nil
    standardIlvlNextTier = 133
    ilvlDenominator = 13
  -- elseif version < 40200 then
  --   standardIlvl = 359
  -- elseif version < 40300 then
  --   standardIlvl = 378
  -- elseif version < 50200 then
  --   standardIlvl = 496
  -- elseif version < 50400 then
  --   standardIlvl = 522
  -- elseif version < 60000 or levelCap == 90 then
  --   standardIlvl = 553
  -- elseif version < 60200 then
  --   standardIlvl = 680
  --   ilvlDenominator = 30
  -- elseif version < 70000 then
  --   standardIlvl = 710 -- HFC HC
  --   ilvlDenominator = 30
  -- elseif version < 70200 then
  --   standardIlvl = 890 -- The Nighthold HC
  --   ilvlDenominator = 30
  -- elseif version < 70300 then
  --   standardIlvl = 915 -- Tomb of Sargeras HC
  --   ilvlDenominator = 30
  -- elseif version < 80000 then
  --   standardIlvl = 945 -- Antorus, the Burning Throne HC
  --   ilvlDenominator = 30
  -- else
  --   standardIlvl = 370 -- Uldir
  --   ilvlDenominator = 32
  end

  return standardIlvl, standardIlvlLastTier, standardIlvlNextTier, ilvlDenominator
end

-- Used to display GP values directly on tier tokens; keys are itemIDs,
-- values are:
-- 1. rarity, int, 4 = epic
-- 2. ilvl, int
-- 3. inventory slot, string
-- 4. an optional boolean value indicating heroic/mythic ilvl should be
--    derived from the bonus list rather than the raw ilvl
--    (mainly for T17+ tier gear)
-- 5. faction (Horde/Alliance), string
local CUSTOM_ITEM_DATA = {
  -- Classic P2
  -- [17204] = { 5, 80, "INVTYPE_2HWEAPON" },
  -- [18422] = { 4, 74, "INVTYPE_NECK", "Horde" }, -- Head of Onyxia
  -- [18423] = { 4, 74, "INVTYPE_NECK", "Alliance" }, -- Head of Onyxia
  -- [18563] = { 5, 80, "INVTYPE_WEAPON" }, -- Legendary Sward
  -- [18564] = { 5, 80, "INVTYPE_WEAPON" }, -- Legendary Sward
  -- [18646] = { 4, 75, "INVTYPE_2HWEAPON" }, -- The Eye of Divinity
  -- [18703] = { 4, 75, "INVTYPE_RANGED" }, -- Ancient Petrified Leaf

  -- Classic P3
  -- [19002] = { 4, 83, "INVTYPE_NECK", "Horde" },
  -- [19003] = { 4, 83, "INVTYPE_NECK", "Alliance" },

  -- Classic P5
  -- [20928] = { 4, 78, "INVTYPE_SHOULDER" }, -- T2.5 shoulder, feet
  -- [20932] = { 4, 78, "INVTYPE_SHOULDER" }, -- T2.5 shoulder, feet
  -- [20930] = { 4, 81, "INVTYPE_HEAD" },     -- T2.5 head
  -- [20926] = { 4, 81, "INVTYPE_HEAD" },     -- T2.5 head
  -- [20927] = { 4, 81, "INVTYPE_LEGS" },     -- T2.5 legs
  -- [20931] = { 4, 81, "INVTYPE_LEGS" },     -- T2.5 legs
  -- [20929] = { 4, 81, "INVTYPE_CHEST" },    -- T2.5 chest
  -- [20933] = { 4, 81, "INVTYPE_CHEST" },    -- T2.5 chest
  -- [21221] = { 4, 88, "INVTYPE_NECK" },     -- 克苏恩之眼
  -- [21232] = { 4, 79, "INVTYPE_WEAPON" },   -- 其拉帝王武器
  -- [21237] = { 4, 79, "INVTYPE_2HWEAPON" }, -- 其拉帝王徽记

  -- Classic P6
  -- [22349] = { 4, 88, "INVTYPE_CHEST" },
  -- [22350] = { 4, 88, "INVTYPE_CHEST" },
  -- [22351] = { 4, 88, "INVTYPE_CHEST" },
  -- [22352] = { 4, 88, "INVTYPE_LEGS" },
  -- [22359] = { 4, 88, "INVTYPE_LEGS" },
  -- [22366] = { 4, 88, "INVTYPE_LEGS" },
  -- [22353] = { 4, 88, "INVTYPE_HEAD" },
  -- [22360] = { 4, 88, "INVTYPE_HEAD" },
  -- [22367] = { 4, 88, "INVTYPE_HEAD" },
  -- [22354] = { 4, 88, "INVTYPE_SHOULDER" },
  -- [22361] = { 4, 88, "INVTYPE_SHOULDER" },
  -- [22368] = { 4, 88, "INVTYPE_SHOULDER" },
  -- [22355] = { 4, 88, "INVTYPE_WRIST" },
  -- [22362] = { 4, 88, "INVTYPE_WRIST" },
  -- [22369] = { 4, 88, "INVTYPE_WRIST" },
  -- [22356] = { 4, 88, "INVTYPE_WAIST" },
  -- [22363] = { 4, 88, "INVTYPE_WAIST" },
  -- [22370] = { 4, 88, "INVTYPE_WAIST" },
  -- [22357] = { 4, 88, "INVTYPE_HAND" },
  -- [22364] = { 4, 88, "INVTYPE_HAND" },
  -- [22371] = { 4, 88, "INVTYPE_HAND" },
  -- [22358] = { 4, 88, "INVTYPE_FEET" },
  -- [22365] = { 4, 88, "INVTYPE_FEET" },
  -- [22372] = { 4, 88, "INVTYPE_FEET" },
  -- [22520] = { 4, 90, "INVTYPE_TRINKET" }, -- 克尔苏加德的护符匣
  -- [22726] = { 5, 90, "INVTYPE_2HWEAPON" }, -- Legendary

  -- Reforged Daggers
  [16834] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Cenarion Helm
  [16836] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Cenarion Spaulders
  [16833] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Cenarion Vestments
  [16830] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Cenarion Bracers
  [16831] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Cenarion Gloves
  [16828] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Cenarion Belt
  [16835] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Cenarion Leggings
  [16829] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Cenarion Boots
  [16846] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Giantstalker's Helmet
  [16848] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Giantstalker's Epaulets
  [16845] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Giantstalker's Breastplate
  [16850] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Giantstalker's Bracers
  [16852] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Giantstalker's Gloves
  [16851] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Giantstalker's Belt
  [16847] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Giantstalker's Leggings
  [16849] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Giantstalker's Boots
  [16795] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Arcanist Crown
  [16797] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Arcanist Mantle
  [16798] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Arcanist Robes
  [16799] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Arcanist Bindings
  [16801] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Arcanist Gloves
  [16802] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Arcanist Belt
  [16796] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Arcanist Leggings
  [16800] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Arcanist Boots
  [16854] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Lawbringer Helm
  [16856] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Lawbringer Spaulders
  [16853] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Lawbringer Chestguard
  [16857] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Lawbringer Bracers
  [16860] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Lawbringer Gauntlets
  [16858] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Lawbringer Belt
  [16855] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Lawbringer Legplates
  [16859] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Lawbringer Boots
  [16813] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Circlet of Prophecy
  [16816] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Mantle of Prophecy
  [16815] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Robes of Prophecy
  [16819] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Vambraces of Prophecy
  [16812] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Gloves of Prophecy
  [16817] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Girdle of Prophecy
  [16814] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Pants of Prophecy
  [16811] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Boots of Prophecy
  [16821] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Nightslayer Cover
  [16823] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Nightslayer Shoulder Pads
  [16820] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Nightslayer Chestpiece
  [16825] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Nightslayer Bracelets
  [16826] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Nightslayer Gloves
  [16827] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Nightslayer Belt
  [16822] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Nightslayer Pants
  [16824] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Nightslayer Boots
  [16808] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Felheart Horns
  [16807] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Felheart Shoulder Pads
  [16809] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Felheart Robes
  [16804] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Felheart Bracers
  [16805] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Felheart Gloves
  [16806] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Felheart Belt
  [16810] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Felheart Pants
  [16803] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Felheart Slippers
  [16861] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Helm of Might
  [16868] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Spaulders of Might
  [16865] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Breastplate of Might
  [16861] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Bracers of Might
  [16863] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Gauntlets of Might
  [16864] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Belt of Might
  [16867] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Legplates of Might
  [16869] = { 4, 66, "CUSTOM_GP", nil, nil, 9 }, -- Sabatons of Might
  [16900] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Stormrage Cover
  [16902] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Stormrage Pauldrons
  [16897] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Stormrage Chestguard
  [16904] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Stormrage Bracers
  [16899] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Stormrage Handguards
  [16930] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Stormrage Belt
  [16901] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Stormrage Legguards
  [16898] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Stormrage Boots
  [16939] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Dragonstalker's Helm
  [16937] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Dragonstalker's Spaulders
  [16942] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Dragonstalker's Breastplate
  [16935] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Dragonstalker's Bracers
  [16940] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Dragonstalker's Gauntlets
  [16936] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Dragonstalker's Belt
  [16938] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Dragonstalker's Legguards
  [16941] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Dragonstalker's Greaves
  [16914] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Netherwind Crown
  [16917] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Netherwind Mantle
  [16916] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Netherwind Robes
  [16918] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Netherwind Bindings
  [16913] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Netherwind Gloves
  [16818] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Netherwind Belt
  [16915] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Netherwind Pants
  [16912] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Netherwind Boots
  [16955] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Judgement Crown
  [16953] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Judgement Spaulders
  [16958] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Judgement Breastplate
  [16951] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Judgement Bindings
  [16956] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Judgement Gauntlets
  [16952] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Judgement Belt
  [16954] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Judgement Legplates
  [16957] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Judgement Sabatons
  [16921] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Halo of Transcendence
  [16924] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Pauldrons of Transcendence
  [16923] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Robes of Transcendence
  [16926] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Bindings of Transcendence
  [16920] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Handguards of Transcendence
  [16925] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Belt of Transcendence
  [16922] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Leggings of Transcendence
  [16919] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Boots of Transcendence
  [16908] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Bloodfang Hood
  [16832] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Bloodfang Spaulders
  [16905] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Bloodfang Chestpiece
  [16911] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Bloodfang Bracers
  [16907] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Bloodfang Gloves
  [16910] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Bloodfang Belt
  [16909] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Bloodfang Pants
  [16906] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Bloodfang Boots
  [16929] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Nemesis Skullcap
  [16932] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Nemesis Spaulders
  [16931] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Nemesis Robes
  [16934] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Nemesis Bracers
  [16928] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Nemesis Gloves
  [16933] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Nemesis Belt
  [16930] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Nemesis Leggings
  [16927] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Nemesis Boots
  [16963] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Helm of Wrath
  [16960] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Pauldrons of Wrath
  [16966] = { 4, 66, "CUSTOM_GP", nil, nil, 54 }, -- Breastplate of Wrath
  [16959] = { 4, 66, "CUSTOM_GP", nil, nil, 27 }, -- Bracelets of Wrath
  [16964] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Gauntlets of Wrath
  [16967] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Waistband of Wrath
  [16961] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Legplates of Wrath
  [16965] = { 4, 66, "CUSTOM_GP", nil, nil, 41 }, -- Sabatons of Wrath
  [17067] = { 4, 66, "CUSTOM_GP", nil, nil, 10 }, -- Ancient Cornerstone Grimoire
  [17068] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Deathbringer
  [18205] = { 4, 66, "CUSTOM_GP", nil, nil, 16 }, -- Eskhandar's Collar
  [18422] = { 4, 66, "CUSTOM_GP", nil, nil, 26 }, -- Head of Onyxia
  [18705] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Mature Black Dragon Sinew
  [18813] = { 4, 66, "CUSTOM_GP", nil, nil, 16 }, -- Ring of Binding
  [17078] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Sapphiron Drape
  [17064] = { 4, 66, "CUSTOM_GP", nil, nil, 24 }, -- Shard of the Scale
  [17075] = { 4, 66, "CUSTOM_GP", nil, nil, 52 }, -- Vis'kag the Bloodletter
  [18861] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Flamewalker Legplates
  [17077] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Crimson Shocker
  [18703] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- Ancient Petrified Leaf
  [17063] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- Band of Accuria
  [18879] = { 4, 66, "CUSTOM_GP", nil, nil, 10 }, -- Heavy Dark Iron Ring
  [19140] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- Cauterizing Band
  [19138] = { 4, 66, "CUSTOM_GP", nil, nil, 19 }, -- Band of Sulfuras
  [17109] = { 4, 66, "CUSTOM_GP", nil, nil, 10 }, -- Choker of Enlightenment
  [18870] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Helm of the Lifegiver
  [18806] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Core Forged Greaves
  [17076] = { 4, 66, "CUSTOM_GP", nil, nil, 75 }, -- Bonereaver's Edge
  [18872] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Manastorm Leggings
  [18805] = { 4, 66, "CUSTOM_GP", nil, nil, 22, 7 }, -- Core Hound Tooth
  [18814] = { 4, 66, "CUSTOM_GP", nil, nil, 30 }, -- Choker of the Fire Lord
  [17073] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Earthshaker
  [19147] = { 4, 66, "CUSTOM_GP", nil, nil, 30 }, -- Ring of Spell Power
  [18803] = { 4, 66, "CUSTOM_GP", nil, nil, 15 }, -- Finkle's Lava Dredger
  [17102] = { 4, 66, "CUSTOM_GP", nil, nil, 17 }, -- Cloak of the Shrouded Mists
  [18203] = { 4, 66, "CUSTOM_GP", nil, nil, 7 }, -- Eskhandar's Right Claw
  [19145] = { 4, 66, "CUSTOM_GP", nil, nil, 14 }, -- Robe of Volatile Power
  [19139] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Fireguard Shoulders
  [18817] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Crown of Destruction
  [17065] = { 4, 66, "CUSTOM_GP", nil, nil, 7 }, -- Medallion of Steadfast Might
  [18875] = { 4, 66, "CUSTOM_GP", nil, nil, 13 }, -- Salamander Scale Pants
  [18811] = { 4, 66, "CUSTOM_GP", nil, nil, 8 }, -- Fireproof Cloak
  [17107] = { 4, 66, "CUSTOM_GP", nil, nil, 16 }, -- Dragon's Blood Cape
  [17069] = { 4, 66, "CUSTOM_GP", nil, nil, 15, 45 }, -- Striker's Mark
  [18878] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Sorcerous Dagger
  [18808] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Gloves of the Hypnotic Flame
  [18815] = { 4, 66, "CUSTOM_GP", nil, nil, 10 }, -- Essence of the Pure Flame
  [19146] = { 4, 66, "CUSTOM_GP", nil, nil, 6 }, -- Wristguards of Stability
  [18809] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Sash of Whispered Secrets
  [17204] = { 5, 80, "CUSTOM_GP", nil, nil, 0 }, -- Eye of Sulfuras
  [18646] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- The Eye of Divinity
  [17106] = { 4, 66, "CUSTOM_GP", nil, nil, 15, 45 }, -- Malistar's Defender
  [17105] = { 4, 66, "CUSTOM_GP", nil, nil, 22 }, -- Aurastone Hammer
  [18810] = { 4, 66, "CUSTOM_GP", nil, nil, 24 }, -- Wild Growth Spaulders
  [19137] = { 4, 66, "CUSTOM_GP", nil, nil, 28 }, -- Onslaught Girdle
  [18564] = { 5, 80, "CUSTOM_GP", nil, nil, 0 }, -- Bindings of the Windseeker
  [18823] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Aged Core Leather Gloves
  [18812] = { 4, 66, "CUSTOM_GP", nil, nil, 8 }, -- Wristguards of True Flight
  [18816] = { 4, 66, "CUSTOM_GP", nil, nil, 56 }, -- Perdition's Blade
  [18832] = { 4, 66, "CUSTOM_GP", nil, nil, 45, 15 }, -- Brutality Blade
  [18829] = { 4, 66, "CUSTOM_GP", nil, nil, 12 }, -- Deep Earth Spaulders
  [17082] = { 4, 66, "CUSTOM_GP", nil, nil, 10 }, -- Shard of the Flame
  [17066] = { 4, 66, "CUSTOM_GP", nil, nil, 21 }, -- Drillborer Disk
  [19142] = { 4, 66, "CUSTOM_GP", nil, nil, 7 }, -- Fire Runed Grimoire
  [17104] = { 4, 66, "CUSTOM_GP", nil, nil, 73 }, -- Spinal Reaper
  [17071] = { 4, 66, "CUSTOM_GP", nil, nil, 22 }, -- Gutgore Ripper
  [19143] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Flameguard Gauntlets
  [18824] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Magma Tempered Boots
  [18564] = { 5, 80, "CUSTOM_GP", nil, nil, 0 }, -- Bindings of the Windseeker
  [19136] = { 4, 66, "CUSTOM_GP", nil, nil, 24 }, -- Mana Igniting Cord
  [17110] = { 4, 66, "CUSTOM_GP", nil, nil, 7 }, -- Seal of the Archmagus
  [18822] = { 4, 66, "CUSTOM_GP", nil, nil, 15 }, -- Obsidian Edged Blade
  [18821] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- Quick Strike Ring
  [19144] = { 4, 66, "CUSTOM_GP", nil, nil, 11 }, -- Sabatons of the Flamewalker
  [17103] = { 4, 66, "CUSTOM_GP", nil, nil, 48 }, -- Azuresong Mageblade
  [18820] = { 4, 66, "CUSTOM_GP", nil, nil, 25 }, -- Talisman of Ephemeral Power
  [17072] = { 4, 66, "CUSTOM_GP", nil, nil, 7, 22 }, -- Blastershot Launcher
  [18842] = { 4, 66, "CUSTOM_GP", nil, nil, 62 }, -- Staff of Dominance
  [17074] = { 4, 66, "CUSTOM_GP", nil, nil, 5 }, -- Shadowstrike
  [19434] = { 4, 66, "CUSTOM_GP", nil, nil, 30 }, -- Band of Dark Dominion
  [19353] = { 4, 66, "CUSTOM_GP", nil, nil, 107 }, -- Drake Talon Cleaver
  [19388] = { 4, 66, "CUSTOM_GP", nil, nil, 37 }, -- Angelista's Grasp
  [19437] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Boots of Pure Thought
  [19394] = { 4, 66, "CUSTOM_GP", nil, nil, 40 }, -- Drake Talon Pauldrons
  [19361] = { 4, 66, "CUSTOM_GP", nil, nil, 84 }, -- Ashjre'thul, Crossbow of Smiting
  [19436] = { 4, 66, "CUSTOM_GP", nil, nil, 30 }, -- Cloak of Draconic Might
  [19395] = { 4, 66, "CUSTOM_GP", nil, nil, 40 }, -- Rejuvenating Gem
  [19387] = { 4, 66, "CUSTOM_GP", nil, nil, 42 }, -- Chromatic Boots
  [19362] = { 4, 66, "CUSTOM_GP", nil, nil, 58, 23 }, -- Doom's Edge
  [19397] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Ring of Blackrock
  [19352] = { 4, 66, "CUSTOM_GP", nil, nil, 70, 28 }, -- Chromatically Tempered Sword
  [19354] = { 4, 66, "CUSTOM_GP", nil, nil, 75 }, -- Draconic Avenger
  [19355] = { 4, 66, "CUSTOM_GP", nil, nil, 107 }, -- Shadow Wing Focus Staff
  [19347] = { 4, 66, "CUSTOM_GP", nil, nil, 84 }, -- Claw of Chromaggus
  [19358] = { 4, 66, "CUSTOM_GP", nil, nil, 93 }, -- Draconic Maul
  [19396] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Taut Dragonhide Belt
  [19349] = { 4, 66, "CUSTOM_GP", nil, nil, 84 }, -- Elementium Reinforced Bulwark
  [19435] = { 4, 66, "CUSTOM_GP", nil, nil, 23 }, -- Essence Gatherer
  [19386] = { 4, 66, "CUSTOM_GP", nil, nil, 37 }, -- Elementium Threaded Cloak
  [19439] = { 4, 66, "CUSTOM_GP", nil, nil, 48 }, -- Interlaced Shadow Jerkin
  [19399] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Black Ash Robe
  [19385] = { 4, 66, "CUSTOM_GP", nil, nil, 56 }, -- Empowered Leggings
  [19438] = { 4, 66, "CUSTOM_GP", nil, nil, 36 }, -- Ringo's Blizzard Boots
  [19365] = { 4, 66, "CUSTOM_GP", nil, nil, 66, 26 }, -- Claw of the Black Drake
  [19392] = { 4, 66, "CUSTOM_GP", nil, nil, 37 }, -- Girdle of the Fallen Crusader
  [19398] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Cloak of Firemaw
  [19393] = { 4, 66, "CUSTOM_GP", nil, nil, 37 }, -- Primalist's Linked Waistguard
  [19336] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Arcane Infused Gem
  [19400] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Firemaw's Clutch
  [19391] = { 4, 66, "CUSTOM_GP", nil, nil, 42 }, -- Shimmering Geta
  [19369] = { 4, 66, "CUSTOM_GP", nil, nil, 38 }, -- Gloves of Rapid Evolution
  [19402] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Legguards of the Fallen Crusader
  [19390] = { 4, 66, "CUSTOM_GP", nil, nil, 42 }, -- Taut Dragonhide Gloves
  [19370] = { 4, 66, "CUSTOM_GP", nil, nil, 38 }, -- Mantle of the Blackwing Cabal
  [19401] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Primalist's Linked Legguards
  [19389] = { 4, 66, "CUSTOM_GP", nil, nil, 42 }, -- Taut Dragonhide Shoulderpads
  [19335] = { 4, 66, "CUSTOM_GP", nil, nil, 63, 25 }, -- Spineshatter
  [19343] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Scrolls of Blinding Light
  [19337] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- The Black Book
  [19376] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Archimtiros' Ring of Reckoning
  [19334] = { 4, 66, "CUSTOM_GP", nil, nil, 101 }, -- The Untamed Blade
  [19345] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Aegis of Preservation
  [19364] = { 4, 66, "CUSTOM_GP", nil, nil, 125, 62 }, -- Ashkandi, Greatsword of the Brotherhood
  [19403] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Band of Forced Concentration
  [19381] = { 4, 66, "CUSTOM_GP", nil, nil, 49 }, -- Boots of the Shadow Flame
  [19346] = { 4, 66, "CUSTOM_GP", nil, nil, 65, 26 }, -- Dragonfang Blade
  [19368] = { 4, 66, "CUSTOM_GP", nil, nil, 26, 80 }, -- Dragonbreath Hand Cannon
  [19378] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Cloak of the Brood Lord
  [19372] = { 4, 66, "CUSTOM_GP", nil, nil, 52 }, -- Helm of Endless Rage
  [19406] = { 4, 66, "CUSTOM_GP", nil, nil, 50 }, -- Drake Fang Talisman
  [19363] = { 4, 66, "CUSTOM_GP", nil, nil, 78, 31 }, -- Crul'shorukh, Edge of Chaos
  [19339] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Mind Quickening Gem
  [19407] = { 4, 66, "CUSTOM_GP", nil, nil, 40 }, -- Ebony Flame Gloves
  [19003] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Head of Nefarian
  [19371] = { 4, 66, "CUSTOM_GP", nil, nil, 34 }, -- Pendant of the Fallen Dragon
  [19405] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Malfurion's Blessed Bulwark
  [19360] = { 4, 66, "CUSTOM_GP", nil, nil, 94 }, -- Lok'amir il Romathis
  [19348] = { 4, 66, "CUSTOM_GP", nil, nil, 26 }, -- Red Dragonscale Protector
  [19375] = { 4, 66, "CUSTOM_GP", nil, nil, 66 }, -- Mish'undare, Circlet of the Mind Flayer
  [19340] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Rune of Metamorphosis
  [19432] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Circle of Applied Force
  [19379] = { 4, 66, "CUSTOM_GP", nil, nil, 49 }, -- Neltharion's Tear
  [19367] = { 4, 66, "CUSTOM_GP", nil, nil, 26 }, -- Dragon's Touch
  [19377] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Prestor's Talisman of Connivery
  [19373] = { 4, 66, "CUSTOM_GP", nil, nil, 40 }, -- Black Brood Pauldrons
  [19433] = { 4, 66, "CUSTOM_GP", nil, nil, 53 }, -- Emberweave Leggings
  [19382] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Pure Elementium Band
  [19374] = { 4, 66, "CUSTOM_GP", nil, nil, 26 }, -- Bracers of Arcane Accuracy
  [19357] = { 4, 66, "CUSTOM_GP", nil, nil, 107 }, -- Herald of Woe
  [19356] = { 4, 66, "CUSTOM_GP", nil, nil, 125 }, -- Staff of the Shadow Flame
  [19350] = { 4, 66, "CUSTOM_GP", nil, nil, 26, 80 }, -- Heartstriker
  [19430] = { 4, 66, "CUSTOM_GP", nil, nil, 35 }, -- Shroud of Pure Thought
  [19380] = { 4, 66, "CUSTOM_GP", nil, nil, 43 }, -- Therazane's Link
  [19341] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Lifegiving Gem
  [19431] = { 4, 66, "CUSTOM_GP", nil, nil, 40 }, -- Styleen's Impeding Scarab
  [19351] = { 4, 66, "CUSTOM_GP", nil, nil, 66, 26 }, -- Maladath, Runed Blade of the Black Flight
  [19342] = { 4, 66, "CUSTOM_GP", nil, nil, 20 }, -- Venomous Totem

  -- Tier 4
  [29753] = { 4, 120, "INVTYPE_CHEST" },
  [29754] = { 4, 120, "INVTYPE_CHEST" },
  [29755] = { 4, 120, "INVTYPE_CHEST" },
  [29756] = { 4, 120, "INVTYPE_HAND" },
  [29757] = { 4, 120, "INVTYPE_HAND" },
  [29758] = { 4, 120, "INVTYPE_HAND" },
  [29759] = { 4, 120, "INVTYPE_HEAD" },
  [29760] = { 4, 120, "INVTYPE_HEAD" },
  [29761] = { 4, 120, "INVTYPE_HEAD" },
  [29762] = { 4, 120, "INVTYPE_SHOULDER" },
  [29763] = { 4, 120, "INVTYPE_SHOULDER" },
  [29764] = { 4, 120, "INVTYPE_SHOULDER" },
  [29765] = { 4, 120, "INVTYPE_LEGS" },
  [29766] = { 4, 120, "INVTYPE_LEGS" },
  [29767] = { 4, 120, "INVTYPE_LEGS" },

  -- Tier 5
  [30236] = { 4, 133, "INVTYPE_CHEST" },
  [30237] = { 4, 133, "INVTYPE_CHEST" },
  [30238] = { 4, 133, "INVTYPE_CHEST" },
  [30239] = { 4, 133, "INVTYPE_HAND" },
  [30240] = { 4, 133, "INVTYPE_HAND" },
  [30241] = { 4, 133, "INVTYPE_HAND" },
  [30242] = { 4, 133, "INVTYPE_HEAD" },
  [30243] = { 4, 133, "INVTYPE_HEAD" },
  [30244] = { 4, 133, "INVTYPE_HEAD" },
  [30245] = { 4, 133, "INVTYPE_LEGS" },
  [30246] = { 4, 133, "INVTYPE_LEGS" },
  [30247] = { 4, 133, "INVTYPE_LEGS" },
  [30248] = { 4, 133, "INVTYPE_SHOULDER" },
  [30249] = { 4, 133, "INVTYPE_SHOULDER" },
  [30250] = { 4, 133, "INVTYPE_SHOULDER" },

  -- Tier 5 - BoE recipes - BoP crafts
  [30282] = { 4, 128, "INVTYPE_FEET" },
  [30283] = { 4, 128, "INVTYPE_FEET" },
  [30305] = { 4, 128, "INVTYPE_FEET" },
  [30306] = { 4, 128, "INVTYPE_FEET" },
  [30307] = { 4, 128, "INVTYPE_FEET" },
  [30308] = { 4, 128, "INVTYPE_FEET" },
  [30323] = { 4, 128, "INVTYPE_FEET" },
  [30324] = { 4, 128, "INVTYPE_FEET" },

  -- Tier 6
  [31089] = { 4, 146, "INVTYPE_CHEST" },
  [31090] = { 4, 146, "INVTYPE_CHEST" },
  [31091] = { 4, 146, "INVTYPE_CHEST" },
  [31092] = { 4, 146, "INVTYPE_HAND" },
  [31093] = { 4, 146, "INVTYPE_HAND" },
  [31094] = { 4, 146, "INVTYPE_HAND" },
  [31095] = { 4, 146, "INVTYPE_HEAD" },
  [31096] = { 4, 146, "INVTYPE_HEAD" },
  [31097] = { 4, 146, "INVTYPE_HEAD" },
  [31098] = { 4, 146, "INVTYPE_LEGS" },
  [31099] = { 4, 146, "INVTYPE_LEGS" },
  [31100] = { 4, 146, "INVTYPE_LEGS" },
  [31101] = { 4, 146, "INVTYPE_SHOULDER" },
  [31102] = { 4, 146, "INVTYPE_SHOULDER" },
  [31103] = { 4, 146, "INVTYPE_SHOULDER" },
  [34848] = { 4, 154, "INVTYPE_WRIST" },
  [34851] = { 4, 154, "INVTYPE_WRIST" },
  [34852] = { 4, 154, "INVTYPE_WRIST" },
  [34853] = { 4, 154, "INVTYPE_WAIST" },
  [34854] = { 4, 154, "INVTYPE_WAIST" },
  [34855] = { 4, 154, "INVTYPE_WAIST" },
  [34856] = { 4, 154, "INVTYPE_FEET" },
  [34857] = { 4, 154, "INVTYPE_FEET" },
  [34858] = { 4, 154, "INVTYPE_FEET" },

  -- Tier 6 - BoE recipes - BoP crafts
  [32737] = { 4, 141, "INVTYPE_SHOULDER" },
  [32739] = { 4, 141, "INVTYPE_SHOULDER" },
  [32745] = { 4, 141, "INVTYPE_SHOULDER" },
  [32747] = { 4, 141, "INVTYPE_SHOULDER" },
  [32749] = { 4, 141, "INVTYPE_SHOULDER" },
  [32751] = { 4, 141, "INVTYPE_SHOULDER" },
  [32753] = { 4, 141, "INVTYPE_SHOULDER" },
  [32755] = { 4, 141, "INVTYPE_SHOULDER" },

  -- Magtheridon's Head
  [32385] = { 4, 125, "INVTYPE_FINGER", "Alliance" },
  [32386] = { 4, 125, "INVTYPE_FINGER", "Horde" },

  -- Kael'thas' Sphere
  [32405] = { 4, 138, "INVTYPE_NECK" },

  -- T7
  -- [40610] = { 4, 200, "INVTYPE_CHEST" },
  -- [40611] = { 4, 200, "INVTYPE_CHEST" },
  -- [40612] = { 4, 200, "INVTYPE_CHEST" },
  -- [40613] = { 4, 200, "INVTYPE_HAND" },
  -- [40614] = { 4, 200, "INVTYPE_HAND" },
  -- [40615] = { 4, 200, "INVTYPE_HAND" },
  -- [40616] = { 4, 200, "INVTYPE_HEAD" },
  -- [40617] = { 4, 200, "INVTYPE_HEAD" },
  -- [40618] = { 4, 200, "INVTYPE_HEAD" },
  -- [40619] = { 4, 200, "INVTYPE_LEGS" },
  -- [40620] = { 4, 200, "INVTYPE_LEGS" },
  -- [40621] = { 4, 200, "INVTYPE_LEGS" },
  -- [40622] = { 4, 200, "INVTYPE_SHOULDER" },
  -- [40623] = { 4, 200, "INVTYPE_SHOULDER" },
  -- [40624] = { 4, 200, "INVTYPE_SHOULDER" },

  -- T7 (heroic)
  -- [40625] = { 4, 213, "INVTYPE_CHEST" },
  -- [40626] = { 4, 213, "INVTYPE_CHEST" },
  -- [40627] = { 4, 213, "INVTYPE_CHEST" },
  -- [40628] = { 4, 213, "INVTYPE_HAND" },
  -- [40629] = { 4, 213, "INVTYPE_HAND" },
  -- [40630] = { 4, 213, "INVTYPE_HAND" },
  -- [40631] = { 4, 213, "INVTYPE_HEAD" },
  -- [40632] = { 4, 213, "INVTYPE_HEAD" },
  -- [40633] = { 4, 213, "INVTYPE_HEAD" },
  -- [40634] = { 4, 213, "INVTYPE_LEGS" },
  -- [40635] = { 4, 213, "INVTYPE_LEGS" },
  -- [40636] = { 4, 213, "INVTYPE_LEGS" },
  -- [40637] = { 4, 213, "INVTYPE_SHOULDER" },
  -- [40638] = { 4, 213, "INVTYPE_SHOULDER" },
  -- [40639] = { 4, 213, "INVTYPE_SHOULDER" },

  -- Key to the Focusing Iris
  -- [44569] = { 4, 213, "INVTYPE_NECK" },
  -- [44577] = { 4, 226, "INVTYPE_NECK" },

  -- T8
  -- [45635] = { 4, 219, "INVTYPE_CHEST" },
  -- [45636] = { 4, 219, "INVTYPE_CHEST" },
  -- [45637] = { 4, 219, "INVTYPE_CHEST" },
  -- [45647] = { 4, 219, "INVTYPE_HEAD" },
  -- [45648] = { 4, 219, "INVTYPE_HEAD" },
  -- [45649] = { 4, 219, "INVTYPE_HEAD" },
  -- [45644] = { 4, 219, "INVTYPE_HAND" },
  -- [45645] = { 4, 219, "INVTYPE_HAND" },
  -- [45646] = { 4, 219, "INVTYPE_HAND" },
  -- [45650] = { 4, 219, "INVTYPE_LEGS" },
  -- [45651] = { 4, 219, "INVTYPE_LEGS" },
  -- [45652] = { 4, 219, "INVTYPE_LEGS" },
  -- [45659] = { 4, 219, "INVTYPE_SHOULDER" },
  -- [45660] = { 4, 219, "INVTYPE_SHOULDER" },
  -- [45661] = { 4, 219, "INVTYPE_SHOULDER" },

  -- T8 (heroic)
  -- [45632] = { 4, 226, "INVTYPE_CHEST" },
  -- [45633] = { 4, 226, "INVTYPE_CHEST" },
  -- [45634] = { 4, 226, "INVTYPE_CHEST" },
  -- [45638] = { 4, 226, "INVTYPE_HEAD" },
  -- [45639] = { 4, 226, "INVTYPE_HEAD" },
  -- [45640] = { 4, 226, "INVTYPE_HEAD" },
  -- [45641] = { 4, 226, "INVTYPE_HAND" },
  -- [45642] = { 4, 226, "INVTYPE_HAND" },
  -- [45643] = { 4, 226, "INVTYPE_HAND" },
  -- [45653] = { 4, 226, "INVTYPE_LEGS" },
  -- [45654] = { 4, 226, "INVTYPE_LEGS" },
  -- [45655] = { 4, 226, "INVTYPE_LEGS" },
  -- [45656] = { 4, 226, "INVTYPE_SHOULDER" },
  -- [45657] = { 4, 226, "INVTYPE_SHOULDER" },
  -- [45658] = { 4, 226, "INVTYPE_SHOULDER" },

  -- Reply Code Alpha
  -- [46052] = { 4, 226, "INVTYPE_RING" },
  -- [46053] = { 4, 239, "INVTYPE_RING" },

  -- T9.245 (10M heroic/25M)
  -- [47242] = { 4, 245, "INVTYPE_CUSTOM_MULTISLOT_TIER" },

  -- T9.258 (25M heroic)
  -- [47557] = { 4, 258, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [47558] = { 4, 258, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [47559] = { 4, 258, "INVTYPE_CUSTOM_MULTISLOT_TIER" },

  -- T10.264 (10M heroic/25M)
  -- [52025] = { 4, 264, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [52026] = { 4, 264, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [52027] = { 4, 264, "INVTYPE_CUSTOM_MULTISLOT_TIER" },

  -- T10.279 (25M heroic)
  -- [52028] = { 4, 279, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [52029] = { 4, 279, "INVTYPE_CUSTOM_MULTISLOT_TIER" },
  -- [52030] = { 4, 279, "INVTYPE_CUSTOM_MULTISLOT_TIER" },

  -- T11
  -- [63683] = { 4, 359, "INVTYPE_HEAD" },
  -- [63684] = { 4, 359, "INVTYPE_HEAD" },
  -- [63682] = { 4, 359, "INVTYPE_HEAD" },
  -- [64315] = { 4, 359, "INVTYPE_SHOULDER" },
  -- [64316] = { 4, 359, "INVTYPE_SHOULDER" },
  -- [64314] = { 4, 359, "INVTYPE_SHOULDER" },

  -- T11 Heroic
  -- [65001] = { 4, 372, "INVTYPE_HEAD" },
  -- [65000] = { 4, 372, "INVTYPE_HEAD" },
  -- [65002] = { 4, 372, "INVTYPE_HEAD" },
  -- [65088] = { 4, 372, "INVTYPE_SHOULDER" },
  -- [65087] = { 4, 372, "INVTYPE_SHOULDER" },
  -- [65089] = { 4, 372, "INVTYPE_SHOULDER" },
  -- [67424] = { 4, 372, "INVTYPE_CHEST" },
  -- [67425] = { 4, 372, "INVTYPE_CHEST" },
  -- [67423] = { 4, 372, "INVTYPE_CHEST" },
  -- [67426] = { 4, 372, "INVTYPE_LEGS" },
  -- [67427] = { 4, 372, "INVTYPE_LEGS" },
  -- [67428] = { 4, 372, "INVTYPE_LEGS" },
  -- [67431] = { 4, 372, "INVTYPE_HAND" },
  -- [67430] = { 4, 372, "INVTYPE_HAND" },
  -- [67429] = { 4, 372, "INVTYPE_HAND" },

  -- T12
  -- [71674] = { 4, 378, "INVTYPE_SHOULDER" },
  -- [71688] = { 4, 378, "INVTYPE_SHOULDER" },
  -- [71681] = { 4, 378, "INVTYPE_SHOULDER" },
  -- [71668] = { 4, 378, "INVTYPE_HEAD" },
  -- [71682] = { 4, 378, "INVTYPE_HEAD" },
  -- [71675] = { 4, 378, "INVTYPE_HEAD" },

  -- T12 Heroic
  -- [71679] = { 4, 391, "INVTYPE_CHEST" },
  -- [71686] = { 4, 391, "INVTYPE_CHEST" },
  -- [71672] = { 4, 391, "INVTYPE_CHEST" },
  -- [71677] = { 4, 391, "INVTYPE_HEAD" },
  -- [71684] = { 4, 391, "INVTYPE_HEAD" },
  -- [71670] = { 4, 391, "INVTYPE_HEAD" },
  -- [71676] = { 4, 391, "INVTYPE_HAND" },
  -- [71683] = { 4, 391, "INVTYPE_HAND" },
  -- [71669] = { 4, 391, "INVTYPE_HAND" },
  -- [71678] = { 4, 391, "INVTYPE_LEGS" },
  -- [71685] = { 4, 391, "INVTYPE_LEGS" },
  -- [71671] = { 4, 391, "INVTYPE_LEGS" },
  -- [71680] = { 4, 391, "INVTYPE_SHOULDER" },
  -- [71687] = { 4, 391, "INVTYPE_SHOULDER" },
  -- [71673] = { 4, 391, "INVTYPE_SHOULDER" },

  -- T12 misc
  -- [71617] = { 4, 391, "INVTYPE_TRINKET" }, -- crystallized firestone

  -- Other junk that drops; hard to really set a price for, so guilds
  -- will just have to decide on their own.
  -- 69815 -- seething cinder
  -- 71141 -- eternal ember
  -- 69237 -- living ember
  -- 71998 -- essence of destruction

  -- T13 normal
  -- [78184] = { 4, 397, "INVTYPE_CHEST" },
  -- [78179] = { 4, 397, "INVTYPE_CHEST" },
  -- [78174] = { 4, 397, "INVTYPE_CHEST" },
  -- [78182] = { 4, 397, "INVTYPE_HEAD" },
  -- [78177] = { 4, 397, "INVTYPE_HEAD" },
  -- [78172] = { 4, 397, "INVTYPE_HEAD" },
  -- [78183] = { 4, 397, "INVTYPE_HAND" },
  -- [78178] = { 4, 397, "INVTYPE_HAND" },
  -- [78173] = { 4, 397, "INVTYPE_HAND" },
  -- [78181] = { 4, 397, "INVTYPE_LEGS" },
  -- [78176] = { 4, 397, "INVTYPE_LEGS" },
  -- [78171] = { 4, 397, "INVTYPE_LEGS" },
  -- [78180] = { 4, 397, "INVTYPE_SHOULDER" },
  -- [78175] = { 4, 397, "INVTYPE_SHOULDER" },
  -- [78170] = { 4, 397, "INVTYPE_SHOULDER" },

  -- T13 heroic
  -- [78847] = { 4, 410, "INVTYPE_CHEST" },
  -- [78848] = { 4, 410, "INVTYPE_CHEST" },
  -- [78849] = { 4, 410, "INVTYPE_CHEST" },
  -- [78850] = { 4, 410, "INVTYPE_HEAD" },
  -- [78851] = { 4, 410, "INVTYPE_HEAD" },
  -- [78852] = { 4, 410, "INVTYPE_HEAD" },
  -- [78853] = { 4, 410, "INVTYPE_HAND" },
  -- [78854] = { 4, 410, "INVTYPE_HAND" },
  -- [78855] = { 4, 410, "INVTYPE_HAND" },
  -- [78856] = { 4, 410, "INVTYPE_LEGS" },
  -- [78857] = { 4, 410, "INVTYPE_LEGS" },
  -- [78858] = { 4, 410, "INVTYPE_LEGS" },
  -- [78859] = { 4, 410, "INVTYPE_SHOULDER" },
  -- [78860] = { 4, 410, "INVTYPE_SHOULDER" },
  -- [78861] = { 4, 410, "INVTYPE_SHOULDER" },

  -- T14 normal
  -- [89248] = { 4, 496, "INVTYPE_SHOULDER" },
  -- [89247] = { 4, 496, "INVTYPE_SHOULDER" },
  -- [89246] = { 4, 496, "INVTYPE_SHOULDER" },

  -- [89245] = { 4, 496, "INVTYPE_LEGS" },
  -- [89244] = { 4, 496, "INVTYPE_LEGS" },
  -- [89243] = { 4, 496, "INVTYPE_LEGS" },

  -- [89234] = { 4, 496, "INVTYPE_HEAD" },
  -- [89236] = { 4, 496, "INVTYPE_HEAD" },
  -- [89235] = { 4, 496, "INVTYPE_HEAD" },

  -- [89242] = { 4, 496, "INVTYPE_HAND" },
  -- [89241] = { 4, 496, "INVTYPE_HAND" },
  -- [89240] = { 4, 496, "INVTYPE_HAND" },

  -- [89239] = { 4, 496, "INVTYPE_CHEST" },
  -- [89238] = { 4, 496, "INVTYPE_CHEST" },
  -- [89237] = { 4, 496, "INVTYPE_CHEST" },

  -- T14 heroic
  -- [89261] = { 4, 509, "INVTYPE_SHOULDER" },
  -- [89263] = { 4, 509, "INVTYPE_SHOULDER" },
  -- [89262] = { 4, 509, "INVTYPE_SHOULDER" },

  -- [89252] = { 4, 509, "INVTYPE_LEGS" },
  -- [89254] = { 4, 509, "INVTYPE_LEGS" },
  -- [89253] = { 4, 509, "INVTYPE_LEGS" },

  -- [89258] = { 4, 509, "INVTYPE_HEAD" },
  -- [89260] = { 4, 509, "INVTYPE_HEAD" },
  -- [89259] = { 4, 509, "INVTYPE_HEAD" },

  -- [89255] = { 4, 509, "INVTYPE_HAND" },
  -- [89257] = { 4, 509, "INVTYPE_HAND" },
  -- [89256] = { 4, 509, "INVTYPE_HAND" },

  -- [89249] = { 4, 509, "INVTYPE_CHEST" },
  -- [89251] = { 4, 509, "INVTYPE_CHEST" },
  -- [89250] = { 4, 509, "INVTYPE_CHEST" },

  -- T15 normal
  -- [95573] = { 4, 522, "INVTYPE_SHOULDER" },
  -- [95583] = { 4, 522, "INVTYPE_SHOULDER" },
  -- [95578] = { 4, 522, "INVTYPE_SHOULDER" },

  -- [95572] = { 4, 522, "INVTYPE_LEGS" },
  -- [95581] = { 4, 522, "INVTYPE_LEGS" },
  -- [95576] = { 4, 522, "INVTYPE_LEGS" },

  -- [95571] = { 4, 522, "INVTYPE_HEAD" },
  -- [95582] = { 4, 522, "INVTYPE_HEAD" },
  -- [95577] = { 4, 522, "INVTYPE_HEAD" },

  -- [95570] = { 4, 522, "INVTYPE_HAND" },
  -- [95580] = { 4, 522, "INVTYPE_HAND" },
  -- [95575] = { 4, 522, "INVTYPE_HAND" },

  -- [95569] = { 4, 522, "INVTYPE_CHEST" },
  -- [95579] = { 4, 522, "INVTYPE_CHEST" },
  -- [95574] = { 4, 522, "INVTYPE_CHEST" },

  -- T15 heroic
  -- [96699] = { 4, 535, "INVTYPE_SHOULDER" },
  -- [96700] = { 4, 535, "INVTYPE_SHOULDER" },
  -- [96701] = { 4, 535, "INVTYPE_SHOULDER" },

  -- [96631] = { 4, 535, "INVTYPE_LEGS" },
  -- [96632] = { 4, 535, "INVTYPE_LEGS" },
  -- [96633] = { 4, 535, "INVTYPE_LEGS" },

  -- [96625] = { 4, 535, "INVTYPE_HEAD" },
  -- [96623] = { 4, 535, "INVTYPE_HEAD" },
  -- [96624] = { 4, 535, "INVTYPE_HEAD" },

  -- [96599] = { 4, 535, "INVTYPE_HAND" },
  -- [96600] = { 4, 535, "INVTYPE_HAND" },
  -- [96601] = { 4, 535, "INVTYPE_HAND" },

  -- [96567] = { 4, 535, "INVTYPE_CHEST" },
  -- [96568] = { 4, 535, "INVTYPE_CHEST" },
  -- [96566] = { 4, 535, "INVTYPE_CHEST" },

  -- T16 Normal (post-6.0)
  -- [99754] = { 4, 540, "INVTYPE_SHOULDER" },
  -- [99755] = { 4, 540, "INVTYPE_SHOULDER" },
  -- [99756] = { 4, 540, "INVTYPE_SHOULDER" },

  -- [99751] = { 4, 540, "INVTYPE_LEGS" },
  -- [99752] = { 4, 540, "INVTYPE_LEGS" },
  -- [99753] = { 4, 540, "INVTYPE_LEGS" },

  -- [99748] = { 4, 540, "INVTYPE_HEAD" },
  -- [99749] = { 4, 540, "INVTYPE_HEAD" },
  -- [99750] = { 4, 540, "INVTYPE_HEAD" },

  -- [99745] = { 4, 540, "INVTYPE_HAND" },
  -- [99746] = { 4, 540, "INVTYPE_HAND" },
  -- [99747] = { 4, 540, "INVTYPE_HAND" },

  -- [99742] = { 4, 540, "INVTYPE_CHEST" },
  -- [99743] = { 4, 540, "INVTYPE_CHEST" },
  -- [99744] = { 4, 540, "INVTYPE_CHEST" },

  -- T16 Normal Essences (post-6.0)
  -- [105863] = { 4, 540, "INVTYPE_HEAD" },
  -- [105865] = { 4, 540, "INVTYPE_HEAD" },
  -- [105864] = { 4, 540, "INVTYPE_HEAD" },

  -- T16 Heroic (Normal pre-6.0)
  -- [99685] = { 4, 553, "INVTYPE_SHOULDER" },
  -- [99695] = { 4, 553, "INVTYPE_SHOULDER" },
  -- [99690] = { 4, 553, "INVTYPE_SHOULDER" },

  -- [99684] = { 4, 553, "INVTYPE_LEGS" },
  -- [99693] = { 4, 553, "INVTYPE_LEGS" },
  -- [99688] = { 4, 553, "INVTYPE_LEGS" },

  -- [99683] = { 4, 553, "INVTYPE_HEAD" },
  -- [99694] = { 4, 553, "INVTYPE_HEAD" },
  -- [99689] = { 4, 553, "INVTYPE_HEAD" },

  -- [99682] = { 4, 553, "INVTYPE_HAND" },
  -- [99692] = { 4, 553, "INVTYPE_HAND" },
  -- [99687] = { 4, 553, "INVTYPE_HAND" },

  -- [99696] = { 4, 553, "INVTYPE_CHEST" },
  -- [99691] = { 4, 553, "INVTYPE_CHEST" },
  -- [99686] = { 4, 553, "INVTYPE_CHEST" },

  -- T16 Heroic Essences (Normal pre-6.0)
  -- [105857] = { 4, 553, "INVTYPE_HEAD" },
  -- [105859] = { 4, 553, "INVTYPE_HEAD" },
  -- [105858] = { 4, 553, "INVTYPE_HEAD" },

  -- T16 Mythic (Heroic pre-6.0)
  -- [99717] = { 4, 566, "INVTYPE_SHOULDER" },
  -- [99719] = { 4, 566, "INVTYPE_SHOULDER" },
  -- [99718] = { 4, 566, "INVTYPE_SHOULDER" },

  -- [99726] = { 4, 566, "INVTYPE_LEGS" },
  -- [99713] = { 4, 566, "INVTYPE_LEGS" },
  -- [99712] = { 4, 566, "INVTYPE_LEGS" },

  -- [99723] = { 4, 566, "INVTYPE_HEAD" },
  -- [99725] = { 4, 566, "INVTYPE_HEAD" },
  -- [99724] = { 4, 566, "INVTYPE_HEAD" },

  -- [99720] = { 4, 566, "INVTYPE_HAND" },
  -- [99722] = { 4, 566, "INVTYPE_HAND" },
  -- [99721] = { 4, 566, "INVTYPE_HAND" },

  -- [99714] = { 4, 566, "INVTYPE_CHEST" },
  -- [99716] = { 4, 566, "INVTYPE_CHEST" },
  -- [99715] = { 4, 566, "INVTYPE_CHEST" },

  -- T16 Mythic Essences (Heroic pre-6.0)
  -- [105868] = { 4, 566, "INVTYPE_HEAD" },
  -- [105867] = { 4, 566, "INVTYPE_HEAD" },
  -- [105866] = { 4, 566, "INVTYPE_HEAD" },

  -- T17
  -- Item IDs are identical across difficulties, so specify nil for item level
  -- and specify the tier number instead: the raid difficulty and tier number
  -- will be used to get the item level.
  -- [119309] = { 4, 670, "INVTYPE_SHOULDER", true },
  -- [119322] = { 4, 670, "INVTYPE_SHOULDER", true },
  -- [119314] = { 4, 670, "INVTYPE_SHOULDER", true },

  -- [119307] = { 4, 670, "INVTYPE_LEGS", true },
  -- [119320] = { 4, 670, "INVTYPE_LEGS", true },
  -- [119313] = { 4, 670, "INVTYPE_LEGS", true },

  -- [119308] = { 4, 670, "INVTYPE_HEAD", true },
  -- [119321] = { 4, 670, "INVTYPE_HEAD", true },
  -- [119312] = { 4, 670, "INVTYPE_HEAD", true },

  -- [119306] = { 4, 670, "INVTYPE_HAND", true },
  -- [119319] = { 4, 670, "INVTYPE_HAND", true },
  -- [119311] = { 4, 670, "INVTYPE_HAND", true },

  -- [119305] = { 4, 670, "INVTYPE_CHEST", true },
  -- [119318] = { 4, 670, "INVTYPE_CHEST", true },
  -- [119315] = { 4, 670, "INVTYPE_CHEST", true },

  -- T17 essences
  -- [119310] = { 4, 670, "INVTYPE_HEAD", true },
  -- [120277] = { 4, 670, "INVTYPE_HEAD", true },
  -- [119323] = { 4, 670, "INVTYPE_HEAD", true },
  -- [120279] = { 4, 670, "INVTYPE_HEAD", true },
  -- [119316] = { 4, 670, "INVTYPE_HEAD", true },
  -- [120278] = { 4, 670, "INVTYPE_HEAD", true },

  -- T18
  -- [127957] = { 4, 695, "INVTYPE_SHOULDER", true },
  -- [127967] = { 4, 695, "INVTYPE_SHOULDER", true },
  -- [127961] = { 4, 695, "INVTYPE_SHOULDER", true },

  -- [127955] = { 4, 695, "INVTYPE_LEGS", true },
  -- [127965] = { 4, 695, "INVTYPE_LEGS", true },
  -- [127960] = { 4, 695, "INVTYPE_LEGS", true },

  -- [127956] = { 4, 695, "INVTYPE_HEAD", true },
  -- [127966] = { 4, 695, "INVTYPE_HEAD", true },
  -- [127959] = { 4, 695, "INVTYPE_HEAD", true },

  -- [127954] = { 4, 695, "INVTYPE_HAND", true },
  -- [127964] = { 4, 695, "INVTYPE_HAND", true },
  -- [127958] = { 4, 695, "INVTYPE_HAND", true },

  -- [127953] = { 4, 695, "INVTYPE_CHEST", true },
  -- [127963] = { 4, 695, "INVTYPE_CHEST", true },
  -- [127962] = { 4, 695, "INVTYPE_CHEST", true },

  -- T18 trinket tokens (note: slightly higher ilvl)
  -- [127969] = { 4, 705, "INVTYPE_TRINKET", true },
  -- [127970] = { 4, 705, "INVTYPE_TRINKET", true },
  -- [127968] = { 4, 705, "INVTYPE_TRINKET", true },

  -- T19 tokens
  -- [143566] = { 4, 875, "INVTYPE_SHOULDER", true }, -- Conq
  -- [143570] = { 4, 875, "INVTYPE_SHOULDER", true }, -- Vanq
  -- [143576] = { 4, 875, "INVTYPE_SHOULDER", true }, -- Prot

  -- [143564] = { 4, 875, "INVTYPE_LEGS", true },
  -- [143569] = { 4, 875, "INVTYPE_LEGS", true },
  -- [143574] = { 4, 875, "INVTYPE_LEGS", true },

  -- [143565] = { 4, 875, "INVTYPE_HEAD", true },
  -- [143568] = { 4, 875, "INVTYPE_HEAD", true },
  -- [143575] = { 4, 875, "INVTYPE_HEAD", true },

  -- [143563] = { 4, 875, "INVTYPE_HAND", true },
  -- [143567] = { 4, 875, "INVTYPE_HAND", true },
  -- [143573] = { 4, 875, "INVTYPE_HAND", true },

  -- [143562] = { 4, 875, "INVTYPE_CHEST", true },
  -- [143571] = { 4, 875, "INVTYPE_CHEST", true },
  -- [143572] = { 4, 875, "INVTYPE_CHEST", true },

  -- [143577] = { 4, 875, "INVTYPE_CLOAK", true },
  -- [143578] = { 4, 875, "INVTYPE_CLOAK", true },
  -- [143579] = { 4, 875, "INVTYPE_CLOAK", true },

  -- T20 tokens
  -- [147329] = { 4, 900, "INVTYPE_SHOULDER", true }, -- Conq
  -- [147328] = { 4, 900, "INVTYPE_SHOULDER", true }, -- Vanq
  -- [147330] = { 4, 900, "INVTYPE_SHOULDER", true }, -- Prot

  -- [147326] = { 4, 900, "INVTYPE_LEGS", true },
  -- [147325] = { 4, 900, "INVTYPE_LEGS", true },
  -- [147327] = { 4, 900, "INVTYPE_LEGS", true },

  -- [147323] = { 4, 900, "INVTYPE_HEAD", true },
  -- [147322] = { 4, 900, "INVTYPE_HEAD", true },
  -- [147324] = { 4, 900, "INVTYPE_HEAD", true },

  -- [147320] = { 4, 900, "INVTYPE_HAND", true },
  -- [147319] = { 4, 900, "INVTYPE_HAND", true },
  -- [147321] = { 4, 900, "INVTYPE_HAND", true },

  -- [147317] = { 4, 900, "INVTYPE_CHEST", true },
  -- [147316] = { 4, 900, "INVTYPE_CHEST", true },
  -- [147318] = { 4, 900, "INVTYPE_CHEST", true },

  -- [147332] = { 4, 900, "INVTYPE_CLOAK", true },
  -- [147331] = { 4, 900, "INVTYPE_CLOAK", true },
  -- [147333] = { 4, 900, "INVTYPE_CLOAK", true },

  -- T21 tokens
  -- [152515] = { 4, 930, "INVTYPE_CLOAK", true },
  -- [152516] = { 4, 930, "INVTYPE_CLOAK", true },
  -- [152517] = { 4, 930, "INVTYPE_CLOAK", true },

  -- [152518] = { 4, 930, "INVTYPE_CHEST", true },
  -- [152519] = { 4, 930, "INVTYPE_CHEST", true },
  -- [152520] = { 4, 930, "INVTYPE_CHEST", true },

  -- [152521] = { 4, 930, "INVTYPE_HAND", true },
  -- [152522] = { 4, 930, "INVTYPE_HAND", true },
  -- [152523] = { 4, 930, "INVTYPE_HAND", true },

  -- [152524] = { 4, 930, "INVTYPE_HEAD", true },
  -- [152525] = { 4, 930, "INVTYPE_HEAD", true },
  -- [152526] = { 4, 930, "INVTYPE_HEAD", true },

  -- [152527] = { 4, 930, "INVTYPE_LEGS", true },
  -- [152528] = { 4, 930, "INVTYPE_LEGS", true },
  -- [152529] = { 4, 930, "INVTYPE_LEGS", true },

  -- [152530] = { 4, 930, "INVTYPE_SHOULDER", true },
  -- [152531] = { 4, 930, "INVTYPE_SHOULDER", true },
  -- [152532] = { 4, 930, "INVTYPE_SHOULDER", true },
}

function lib:GetCustomItemsDefault()
  return CUSTOM_ITEM_DATA
end

-- Used to add extra GP if the item contains bonus stats
-- generally considered chargeable. Sockets are very
-- valuable in early BFA.
local ITEM_BONUS_GP = {
  [40]  = 50,  -- avoidance
  [41]  = 50,  -- leech
  [42]  = 50,  -- speed
  [43]  = 0,  -- indestructible, no material value
  [523] = 300, -- extra socket
  [563] = 300, -- extra socket
  [564] = 300, -- extra socket
  [565] = 300, -- extra socket
  [572] = 300, -- extra socket
  [1808] = 300, -- extra socket
}

-- The default quality threshold:
-- 0 - Poor
-- 1 - Uncommon
-- 2 - Common
-- 3 - Rare
-- 4 - Epic
-- 5 - Legendary
-- 6 - Artifact
local quality_threshold = 4

local recent_items_queue = {}
local recent_items_map = {}


-- Given a list of item bonuses, return the ilvl delta it represents
-- (15 for Heroic, 30 for Mythic)
local function GetItemBonusLevelDelta(itemBonuses)
  for _, value in pairs(itemBonuses) do
    -- Item modifiers for heroic are 566 and 570; mythic are 567 and 569
    if value == 566 or value == 570 then return 15 end
    if value == 567 or value == 569 then return 30 end
  end
  return 0
end

local function UpdateRecentLoot(itemLink)
  if recent_items_map[itemLink] then return end

  -- Debug("Adding %s to recent items", itemLink)
  table.insert(recent_items_queue, 1, itemLink)
  recent_items_map[itemLink] = true
  if #recent_items_queue > 15 then
    local itemLink = table.remove(recent_items_queue)
    -- Debug("Removing %s from recent items", itemLink)
    recent_items_map[itemLink] = nil
  end
end

function lib:GetNumRecentItems()
  return #recent_items_queue
end

function lib:GetRecentItemLink(i)
  return recent_items_queue[i]
end

--- Return the currently set quality threshold.
function lib:GetQualityThreshold()
  return quality_threshold
end

--- Set the minimum quality threshold.
-- @param itemQuality Lowest allowed item quality.
function lib:SetQualityThreshold(itemQuality)
  itemQuality = itemQuality and tonumber(itemQuality)
  if not itemQuality or itemQuality > 6 or itemQuality < 0 then
    return error("Usage: SetQualityThreshold(itemQuality): 'itemQuality' - number [0,6].", 3)
  end

  quality_threshold = itemQuality
end

function lib:GetValue(item)
  if not item then return end

  local _, itemLink, rarity, ilvl, _, _, itemSubClass, _, equipLoc = GetItemInfo(item)
  if not itemLink then return end

  -- Get the item ID to check against known token IDs
  local itemID = itemLink:match("item:(%d+)")
  if not itemID then return end
  itemID = tonumber(itemID)

  -- For now, just use the actual ilvl, not the upgraded cost
  -- ilvl = ItemUtils:GetItemIlevel(item, ilvl)

  -- Check if item is relevant.  Item is automatically relevant if it
  -- is in CUSTOM_ITEM_DATA (as of 6.0, can no longer rely on ilvl alone
  -- for these).
  -- if ilvl < 339 and not CUSTOM_ITEM_DATA[itemID] then
  --   Debug("%s is not relevant.", itemLink)
  --   return nil, nil, ilvl, rarity, equipLoc
  -- end

  -- Get the bonuses for the item to check against known bonuses
  -- local itemBonuses = ItemUtils:BonusIDs(itemLink)

  -- Check to see if there is custom data for this item ID
  local customItem = EPGP.db.profile.customItems[itemID]
  if customItem then
    rarity = customItem.rarity
    ilvl = customItem.ilvl
    equipLoc = customItem.equipLoc
    -- rarity, ilvl, equipLoc, useItemBonuses = unpack(CUSTOM_ITEM_DATA[itemID])
    -- if useItemBonuses then
    --   ilvl = ilvl + GetItemBonusLevelDelta(itemBonuses)
    -- end

    -- if not ilvl then
    --   return error("GetValue(item): could not determine item level from CUSTOM_ITEM_DATA.", 3)
    -- end
  else
    -- Is the item above our minimum threshold?
    if not rarity or rarity < quality_threshold then
      Debug("%s is below rarity threshold.", itemLink)
      return
    end
  end

  UpdateRecentLoot(itemLink)

  if equipLoc == "CUSTOM_SCALE" then
    local gp1, gp2 = self:CalculateGPFromScale(customItem.s1, customItem.s2, nil, ilvl, rarity)
    return gp1, "", gp2, ""
  elseif equipLoc == "CUSTOM_GP" then
    return customItem.gp1, "", customItem.gp2, ""
  else
    return self:CalculateGPFromEquipLoc(equipLoc, itemSubClass, ilvl, rarity)
  end

  -- Does the item have bonus sockets or tertiary stats?  If so,
  -- set extra GP to apply later.  We don't care about warforged
  -- here as that uses the increased item level instead.
  -- local extra_gp = 0
  -- for _, value in pairs(itemBonuses) do
  --   extra_gp = extra_gp + (ITEM_BONUS_GP[value] or 0)
  -- end
end

local LOCAL_NAME = LN:LocalName()

local switchRanged = {}
switchRanged[LOCAL_NAME.Bow]      = "ranged"
switchRanged[LOCAL_NAME.Gun]      = "ranged"
switchRanged[LOCAL_NAME.Crossbow] = "ranged"
switchRanged[LOCAL_NAME.Wand]     = "wand"
switchRanged[LOCAL_NAME.Thrown]   = "thrown"

local switchEquipLoc = {
  ["INVTYPE_HEAD"]            = "head",
  ["INVTYPE_NECK"]            = "neck",
  ["INVTYPE_SHOULDER"]        = "shoulder",
  -- ["INVTYPE_BODY"]            = "body",
  ["INVTYPE_CHEST"]           = "chest",
  ["INVTYPE_ROBE"]            = "chest",
  ["INVTYPE_WAIST"]           = "waist",
  ["INVTYPE_LEGS"]            = "legs",
  ["INVTYPE_FEET"]            = "feet",
  ["INVTYPE_WRIST"]           = "wrist",
  ["INVTYPE_HAND"]            = "hand",
  ["INVTYPE_FINGER"]          = "finger",
  ["INVTYPE_TRINKET"]         = "trinket",
  ["INVTYPE_CLOAK"]           = "cloak",
  ["INVTYPE_WEAPON"]          = "weapon",
  ["INVTYPE_SHIELD"]          = "shield",
  ["INVTYPE_2HWEAPON"]        = "weapon2H",
  ["INVTYPE_WEAPONMAINHAND"]  = "weaponMainH",
  ["INVTYPE_WEAPONOFFHAND"]   = "weaponOffH",
  ["INVTYPE_HOLDABLE"]        = "holdable",
  ["INVTYPE_RANGED"]          = "ranged", -- bow only
  -- ["INVTYPE_RANGEDRIGHT"]     = "ranged", -- gun, cross-bow, wand
  ["INVTYPE_THROWN"]          = "ranged",
  ["INVTYPE_RELIC"]           = "relic",
  -- ["INVTYPE_BAG"]             = "bag",
  ["INVTYPE_WAND"]            = "wand", -- Fate
}

function lib:GetScale(equipLoc, subClass)
  local name = switchEquipLoc[equipLoc] or switchRanged[subClass]
  if name then
    local vars = EPGP:GetModule("points").db.profile
    local s1 = vars[name .. "Scale1"] or 0; local c1 = vars[name .. "Comment1"] or ""
    local s2 = vars[name .. "Scale2"] or 0; local c2 = vars[name .. "Comment2"] or ""
    local s3 = vars[name .. "Scale3"] or 0; local c3 = vars[name .. "Comment3"] or ""
    if s1 == 0 and c1 == "" then s1 = nil; c1 = nil; end
    if s2 == 0 and c2 == "" then s2 = nil; c2 = nil; end
    if s3 == 0 and c3 == "" then s3 = nil; c3 = nil; end
    return s1, c1, s2, c2, s3, c3
  end
end

function lib:CalculateGPFromScale(s1, s2, s3, ilvl, rarity)
  local vars = EPGP:GetModule("points").db.profile

  local baseGP = vars.baseGP
  local standardIlvl = vars.standardIlvl
  local ilvlDenominator = vars.ilvlDenominator
  local multiplier = baseGP * 2 ^ (-standardIlvl / ilvlDenominator)
  if rarity == 5 then multiplier = multiplier * vars.legendaryScale end
  local gpBase = multiplier * 2 ^ (ilvl / ilvlDenominator)

  local gp1 = (s1 and math.floor(0.5 + gpBase * s1)) or nil
  local gp2 = (s2 and math.floor(0.5 + gpBase * s2)) or nil
  local gp3 = (s3 and math.floor(0.5 + gpBase * s3)) or nil

  return gp1, gp2, gp3
end

function lib:CalculateGPFromEquipLoc(equipLoc, subClass, ilvl, rarity)
  local s1, c1, s2, c2, s3, c3 = self:GetScale(equipLoc, subClass)
  local gp1, gp2, gp3 = self:CalculateGPFromScale(s1, s2, s3, ilvl, rarity)
  return gp1, c1, gp2, c2, gp3, c3, s1, s2, s3
end
