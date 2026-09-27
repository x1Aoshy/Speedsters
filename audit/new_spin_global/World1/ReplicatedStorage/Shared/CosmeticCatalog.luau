local Catalog = {}

Catalog.Version = 10

Catalog.Auras = {
    {
        Id = "Aura01", DisplayName = "Purple Aura", TemplateName = "Aura01",
		ShopEnabled = true, WinsCost = 1000, SpeedMultiplier = 10, SortOrder = 3,
        RobuxPurchaseId = 3701552828, RobuxPurchaseType = "Auto", RobuxPrice = 15,
        IconImage = "rbxassetid://109849084599581",
        ThemeColor = Color3.fromRGB(176, 93, 255),
        ThemeDarkColor = Color3.fromRGB(83, 28, 130),
    },
    {
        Id = "Aura02", DisplayName = "Red Aura", TemplateName = "Aura02",
		ShopEnabled = true, WinsCost = 100, SpeedMultiplier = 5, SortOrder = 2,
        RobuxPurchaseId = 3701552425, RobuxPurchaseType = "Auto", RobuxPrice = 7,
        IconImage = "rbxassetid://84342015728151",
        ThemeColor = Color3.fromRGB(255, 72, 72),
        ThemeDarkColor = Color3.fromRGB(120, 18, 18),
    },
    {
        Id = "Aura03", DisplayName = "White Aura", TemplateName = "Aura03",
		ShopEnabled = true, WinsCost = 1000000, SpeedMultiplier = 100, SortOrder = 6,
        RobuxPurchaseId = 3701556972, RobuxPurchaseType = "Auto", RobuxPrice = 79,
        IconImage = "rbxassetid://138814004538031",
        ThemeColor = Color3.fromRGB(242, 242, 242),
        ThemeDarkColor = Color3.fromRGB(132, 132, 132),
    },
    {
        Id = "Aura04", DisplayName = "Black Aura", TemplateName = "Aura04",
		ShopEnabled = true, WinsCost = 10000000, SpeedMultiplier = 1000, SortOrder = 7,
        RobuxPurchaseId = 3701557711, RobuxPurchaseType = "Auto", RobuxPrice = 179,
        IconImage = "rbxassetid://105921859502781",
        ThemeColor = Color3.fromRGB(20, 20, 20),
        ThemeDarkColor = Color3.fromRGB(0, 0, 0),
    },
    {
        Id = "Aura05", DisplayName = "Orange Aura", TemplateName = "Aura05",
		ShopEnabled = true, WinsCost = 10, SpeedMultiplier = 2.5, SortOrder = 1,
        RobuxPurchaseId = 3701551447, RobuxPurchaseType = "Auto", RobuxPrice = 3,
        IconImage = "rbxassetid://82176677996191",
        ThemeColor = Color3.fromRGB(255, 143, 43),
        ThemeDarkColor = Color3.fromRGB(133, 56, 0),
    },
    {
        Id = "Aura06", DisplayName = "Yellow Aura", TemplateName = "Aura06",
		ShopEnabled = true, WinsCost = 100000, SpeedMultiplier = 50, SortOrder = 5,
        RobuxPurchaseId = 3701555411, RobuxPurchaseType = "Auto", RobuxPrice = 59,
        IconImage = "rbxassetid://83233880177230",
        ThemeColor = Color3.fromRGB(255, 220, 52),
        ThemeDarkColor = Color3.fromRGB(145, 111, 4),
    },
    {
        Id = "Aura07", DisplayName = "Blue Aura", TemplateName = "Aura07",
		ShopEnabled = true, WinsCost = 10000, SpeedMultiplier = 25, SortOrder = 4,
        RobuxPurchaseId = 3701554428, RobuxPurchaseType = "Auto", RobuxPrice = 29,
        IconImage = "rbxassetid://131657973400525",
        ThemeColor = Color3.fromRGB(66, 159, 255),
        ThemeDarkColor = Color3.fromRGB(16, 59, 128),
    },
}

-- World 3's Robux prices (2026-09-18 pre-launch review): each aura and trail has its
-- RobuxPrice below. Each is sold as a developer product: create it on the Creator
-- Dashboard at that price and put its id here. Until an id is set, the Backpack shows the
-- price and says "Soon!" when it is pressed; SpeedProductPurchases grants the item as soon
-- as the id is here. Aura 67 has no Robux price: only the Spin Wheel gives it.
local WORLD3_PRODUCT_IDS: { [string]: number? } = {
    Aura10 = 3713531554, -- Cursed Green, 159 R$ (Original: 199 R$)
    Aura11 = 3713531613, -- Cursed Red, 199 R$ (Original: 249 R$)
    Aura12 = 3713531670, -- Cursed Purple, 239 R$ (Original: 299 R$)
    Aura13 = 3713531736, -- Cursed Blue, 279 R$ (Original: 349 R$)
    Aura08 = 3713531808, -- Aquatic Aura, 359 R$ (Original: 449 R$)
    Aura09 = 3713531851, -- Galactic Singularity, 479 R$ (Original: 599 R$)
    Aura15 = 3713531889, -- Doodle Aura, 559 R$ (Original: 699 R$)
    Aura14 = 3713531945, -- Shidou Demon, 639 R$ (Original: 799 R$)
    Aura16 = 3713532000, -- Demon Aura, 799 R$ (Original: 999 R$)
    Aura17 = 3713532092, -- Lightning Aura V2, 800 R$ (Original: 1299 R$)
    Aura18 = 3713532154, -- Musical Aura, 850 R$ (Original: 1999 R$)
    Trail08 = 3713532241, -- Electric Trail, 60 R$ (Original: 199 R$)
    Trail09 = 3713532299, -- Fire Trail, 119 R$ (Original: 249 R$)
    Trail10 = 3713532367, -- Chain Trail, 139 R$ (Original: 299 R$)
    Trail11 = 3713532421, -- Glitched Trail, 177 R$ (Original: 349 R$)
    Trail12 = 3713532485, -- Water Trail, 200 R$ (Original: 449 R$)
    Trail13 = 3713532529, -- Spatial Beam, 219 R$ (Original: 599 R$)
    Trail14 = 3713532591, -- Pixeled Trail, 278 R$ (Original: 799 R$)
    Trail15 = 3713532641, -- Trail 67, 399 R$ (Original: 1199 R$)
}

-- World 3's auras. Their art is NewAurasFactory (Aura08-Aura15) and the models in
-- ServerStorage.AuthoredAuras (Shidou, Demon, Lightning, Musical, 67); see
-- CosmeticTemplateBuilder. They sit above Black on the ladder: an aura and a trail
-- multiply each other, so each step is a modest gain for a steep Wins price (World 3
-- pays about 26.5M Wins a lap). Aura 67 is not sold: only the Spin Wheel gives it.
local WORLD3_AURAS = {
    { Id = "Aura10", DisplayName = "Cursed Green", RobuxPrice = 159, OriginalRobuxPrice = 199, WinsCost = 25000000, SpeedMultiplier = 1200,
        IconImage = "rbxassetid://82176677996191", ThemeColor = Color3.fromRGB(46, 204, 113), ThemeDarkColor = Color3.fromRGB(20, 90, 45) },
    { Id = "Aura11", DisplayName = "Cursed Red", RobuxPrice = 199, OriginalRobuxPrice = 249, WinsCost = 50000000, SpeedMultiplier = 1300,
        IconImage = "rbxassetid://84342015728151", ThemeColor = Color3.fromRGB(231, 76, 60), ThemeDarkColor = Color3.fromRGB(120, 20, 20) },
    { Id = "Aura12", DisplayName = "Cursed Purple", RobuxPrice = 239, OriginalRobuxPrice = 299, WinsCost = 100000000, SpeedMultiplier = 1400,
        IconImage = "rbxassetid://109849084599581", ThemeColor = Color3.fromRGB(155, 89, 182), ThemeDarkColor = Color3.fromRGB(75, 30, 95) },
    { Id = "Aura13", DisplayName = "Cursed Blue", RobuxPrice = 279, OriginalRobuxPrice = 349, WinsCost = 150000000, SpeedMultiplier = 1500,
        IconImage = "rbxassetid://131657973400525", ThemeColor = Color3.fromRGB(52, 152, 219), ThemeDarkColor = Color3.fromRGB(20, 65, 110) },
    { Id = "Aura08", DisplayName = "Aquatic Aura", RobuxPrice = 359, OriginalRobuxPrice = 449, WinsCost = 250000000, SpeedMultiplier = 1650,
        IconImage = "rbxassetid://131657973400525", ThemeColor = Color3.fromRGB(0, 210, 255), ThemeDarkColor = Color3.fromRGB(0, 80, 140) },
    { Id = "Aura09", DisplayName = "Galactic Singularity", RobuxPrice = 479, OriginalRobuxPrice = 599, WinsCost = 400000000, SpeedMultiplier = 1800,
        IconImage = "rbxassetid://109849084599581", ThemeColor = Color3.fromRGB(138, 43, 226), ThemeDarkColor = Color3.fromRGB(48, 10, 90) },
    { Id = "Aura15", DisplayName = "Doodle Aura", RobuxPrice = 559, OriginalRobuxPrice = 699, WinsCost = 600000000, SpeedMultiplier = 2000,
        IconImage = "rbxassetid://83233880177230", ThemeColor = Color3.fromRGB(255, 230, 80), ThemeDarkColor = Color3.fromRGB(130, 110, 20) },
    { Id = "Aura14", DisplayName = "Shidou Demon", RobuxPrice = 639, OriginalRobuxPrice = 799, WinsCost = 1000000000, SpeedMultiplier = 2200,
        IconImage = "rbxassetid://84342015728151", ThemeColor = Color3.fromRGB(255, 20, 100), ThemeDarkColor = Color3.fromRGB(100, 5, 35) },
    { Id = "Aura16", DisplayName = "Demon Aura", RobuxPrice = 799, OriginalRobuxPrice = 999, WinsCost = 1500000000, SpeedMultiplier = 2400,
        IconImage = "rbxassetid://84342015728151", ThemeColor = Color3.fromRGB(220, 20, 60), ThemeDarkColor = Color3.fromRGB(90, 10, 25) },
    { Id = "Aura17", DisplayName = "Lightning Aura V2", RobuxPrice = 800, OriginalRobuxPrice = 1299, WinsCost = 2500000000, SpeedMultiplier = 2700,
        IconImage = "rbxassetid://83233880177230", ThemeColor = Color3.fromRGB(255, 235, 100), ThemeDarkColor = Color3.fromRGB(130, 100, 10) },
    { Id = "Aura18", DisplayName = "Musical Aura", RobuxPrice = 850, OriginalRobuxPrice = 1999, WinsCost = 5000000000, SpeedMultiplier = 3000,
        IconImage = "rbxassetid://109849084599581", ThemeColor = Color3.fromRGB(180, 110, 255), ThemeDarkColor = Color3.fromRGB(75, 20, 120) },
}
for index, entry in ipairs(WORLD3_AURAS) do
    entry.TemplateName = entry.Id
    entry.ShopEnabled = true
    entry.RobuxPurchaseType = "DeveloperProduct"
    entry.RobuxPurchaseId = WORLD3_PRODUCT_IDS[entry.Id]
    entry.SortOrder = 7 + index
    entry.World = 3
    table.insert(Catalog.Auras, entry)
end

table.insert(Catalog.Auras, {
    Id = "Aura67", DisplayName = "Aura 67", TemplateName = "Aura67",
    ShopEnabled = false, Exclusive = "SpinWheel", WinsCost = 0, SpeedMultiplier = 1500, SortOrder = 30, World = 3,
    IconImage = "rbxassetid://127283711015110", CardIcon = "rbxassetid://127283711015110",
    ThemeColor = Color3.fromRGB(12, 142, 255),
    ThemeDarkColor = Color3.fromRGB(2, 21, 76),
})

Catalog.Trails = {
    {
        Id = "Trail01", DisplayName = "Purple Trail", TemplateName = "Trail01",
        ShopEnabled = true, WinsCost = 1000, SpeedMultiplier = 10, SortOrder = 3,
        RobuxPurchaseId = 3701441929, RobuxPurchaseType = "Auto", RobuxPrice = 15,
        IconImage = "rbxassetid://98640220351972",
        ThemeColor = Color3.fromRGB(176, 93, 255),
        ThemeDarkColor = Color3.fromRGB(83, 28, 130),
    },
    {
        Id = "Trail02", DisplayName = "Red Trail", TemplateName = "Trail02",
        ShopEnabled = true, WinsCost = 100, SpeedMultiplier = 5, SortOrder = 2,
        RobuxPurchaseId = 3701440521, RobuxPurchaseType = "Auto", RobuxPrice = 7,
        IconImage = "rbxassetid://78795694520145",
        ThemeColor = Color3.fromRGB(255, 72, 72),
        ThemeDarkColor = Color3.fromRGB(120, 18, 18),
    },
    {
        Id = "Trail03", DisplayName = "White Trail", TemplateName = "Trail03",
        ShopEnabled = true, WinsCost = 1000000, SpeedMultiplier = 100, SortOrder = 6,
        RobuxPurchaseId = 3701549435, RobuxPurchaseType = "Auto", RobuxPrice = 79,
        IconImage = "rbxassetid://104187528469789",
        ThemeColor = Color3.fromRGB(242, 242, 242),
        ThemeDarkColor = Color3.fromRGB(132, 132, 132),
    },
    {
        Id = "Trail04", DisplayName = "Secret Trail", TemplateName = "Trail04",
        ShopEnabled = true, WinsCost = 10000000, SpeedMultiplier = 1000, SortOrder = 7,
        RobuxPurchaseId = 3701550223, RobuxPurchaseType = "Auto", RobuxPrice = 179,
        IconImage = "rbxassetid://81036269316578",
        ThemeColor = Color3.fromRGB(20, 20, 20),
        ThemeDarkColor = Color3.fromRGB(0, 0, 0), IsSecret = true,
    },
    {
        Id = "Trail05", DisplayName = "Orange Trail", TemplateName = "Trail05",
        ShopEnabled = true, WinsCost = 10, SpeedMultiplier = 2.5, SortOrder = 1,
        RobuxPurchaseId = 3701439651, RobuxPurchaseType = "Auto", RobuxPrice = 3,
        IconImage = "rbxassetid://116755979380966",
        ThemeColor = Color3.fromRGB(255, 143, 43),
        ThemeDarkColor = Color3.fromRGB(133, 56, 0),
    },
    {
        Id = "Trail06", DisplayName = "Yellow Trail", TemplateName = "Trail06",
        ShopEnabled = true, WinsCost = 100000, SpeedMultiplier = 50, SortOrder = 5,
        RobuxPurchaseId = 3701548211, RobuxPurchaseType = "Auto", RobuxPrice = 59,
        IconImage = "rbxassetid://119603954438829",
        ThemeColor = Color3.fromRGB(255, 220, 52),
        ThemeDarkColor = Color3.fromRGB(145, 111, 4),
    },
    {
        Id = "Trail07", DisplayName = "Blue Trail", TemplateName = "Trail07",
        ShopEnabled = true, WinsCost = 10000, SpeedMultiplier = 25, SortOrder = 4,
        RobuxPurchaseId = 1940887606, RobuxPurchaseType = "Auto",
        IconImage = "rbxassetid://115062858785901",
        ThemeColor = Color3.fromRGB(66, 159, 255),
        ThemeDarkColor = Color3.fromRGB(16, 59, 128),
    },
}

-- World 3's trails. Each is a ribbon drawn from one texture (CosmeticTemplateBuilder
-- builds it from Ribbon): Colors tint it (a coloured texture keeps white), Mode and
-- Length say how the texture runs along the path. Trail 67 also throws 6s and 7s in
-- Aura 67's blues. Same ladder rule as World 3's auras.
local PALETTE_67 = { Color3.fromRGB(12, 142, 255), Color3.fromRGB(11, 96, 255), Color3.fromRGB(2, 21, 76) }
local WORLD3_TRAILS = {
    { Id = "Trail08", DisplayName = "Electric Trail", RobuxPrice = 60, OriginalRobuxPrice = 199, WinsCost = 20000000, SpeedMultiplier = 1200,
        ThemeColor = Color3.fromRGB(90, 200, 255), ThemeDarkColor = Color3.fromRGB(20, 60, 140),
        Ribbon = { Texture = "rbxassetid://13280245934", Mode = "Static", Length = 14, Emission = 1, Brightness = 4,
            Colors = { Color3.fromRGB(150, 240, 255), Color3.fromRGB(90, 140, 255) } } },
    { Id = "Trail09", DisplayName = "Fire Trail", RobuxPrice = 119, OriginalRobuxPrice = 249, WinsCost = 40000000, SpeedMultiplier = 1300,
        ThemeColor = Color3.fromRGB(255, 120, 30), ThemeDarkColor = Color3.fromRGB(130, 40, 0),
        Ribbon = { Texture = "rbxassetid://11767688250", Mode = "Static", Length = 16, Emission = 0.8, Brightness = 3 } },
    { Id = "Trail10", DisplayName = "Chain Trail", RobuxPrice = 139, OriginalRobuxPrice = 299, WinsCost = 75000000, SpeedMultiplier = 1450,
        ThemeColor = Color3.fromRGB(150, 155, 170), ThemeDarkColor = Color3.fromRGB(55, 58, 70),
        Ribbon = { Texture = "rbxassetid://52513855", Mode = "Wrap", Length = 3, Emission = 0, Influence = 1, Brightness = 1,
            Colors = { Color3.fromRGB(235, 235, 245), Color3.fromRGB(170, 175, 190) } } },
    { Id = "Trail11", DisplayName = "Glitched Trail", RobuxPrice = 177, OriginalRobuxPrice = 349, WinsCost = 125000000, SpeedMultiplier = 1600,
        ThemeColor = Color3.fromRGB(255, 60, 200), ThemeDarkColor = Color3.fromRGB(40, 10, 60),
        Ribbon = { Texture = "rbxassetid://107624017803706", Mode = "Static", Length = 10, Emission = 0.6, Brightness = 3 } },
    { Id = "Trail12", DisplayName = "Water Trail", RobuxPrice = 200, OriginalRobuxPrice = 449, WinsCost = 250000000, SpeedMultiplier = 1800,
        ThemeColor = Color3.fromRGB(30, 150, 255), ThemeDarkColor = Color3.fromRGB(0, 60, 140),
        Ribbon = { Texture = "rbxassetid://124411921429725", Mode = "Static", Length = 18, Emission = 0.3, Brightness = 2 } },
    { Id = "Trail13", DisplayName = "Spatial Beam", RobuxPrice = 219, OriginalRobuxPrice = 599, WinsCost = 500000000, SpeedMultiplier = 2100,
        ThemeColor = Color3.fromRGB(150, 110, 255), ThemeDarkColor = Color3.fromRGB(40, 20, 110),
        Ribbon = { Texture = "rbxassetid://16892366666", Mode = "Stretch", Length = 10, Emission = 1, Brightness = 5,
            Colors = { Color3.fromRGB(190, 140, 255), Color3.fromRGB(90, 210, 255), Color3.fromRGB(255, 120, 230) } } },
    { Id = "Trail14", DisplayName = "Pixeled Trail", RobuxPrice = 278, OriginalRobuxPrice = 799, WinsCost = 1000000000, SpeedMultiplier = 2500,
        ThemeColor = Color3.fromRGB(0, 230, 160), ThemeDarkColor = Color3.fromRGB(0, 80, 60),
        Ribbon = { Texture = "rbxassetid://14339514555", Mode = "Static", Length = 8, Emission = 1, Brightness = 4,
            Colors = { Color3.fromRGB(0, 255, 170), Color3.fromRGB(255, 70, 220) } } },
    { Id = "Trail15", DisplayName = "Trail 67", RobuxPrice = 399, OriginalRobuxPrice = 1199, WinsCost = 2000000000, SpeedMultiplier = 3000,
        ThemeColor = PALETTE_67[1], ThemeDarkColor = PALETTE_67[3],
        CardIcon = "rbxassetid://127283711015110",
        Ribbon = { Texture = "rbxassetid://7216850022", Mode = "Static", Length = 30, Emission = 1, Brightness = 5, Colors = PALETTE_67 },
        -- The same studded digits Aura 67 throws (its "Ls" and "Ws" emitters).
        Numbers = {
            { Name = "Six", Texture = "rbxassetid://90832162759563" },
            { Name = "Seven", Texture = "rbxassetid://89820489250506" },
        } },
}
for index, entry in ipairs(WORLD3_TRAILS) do
    entry.TemplateName = entry.Id
    entry.ShopEnabled = true
    entry.RobuxPurchaseType = "DeveloperProduct"
    entry.RobuxPurchaseId = WORLD3_PRODUCT_IDS[entry.Id]
    entry.SortOrder = 7 + index
    entry.World = 3
    entry.CardIcon = entry.CardIcon or entry.Ribbon.Texture
    entry.IconImage = entry.CardIcon
    table.insert(Catalog.Trails, entry)
end

local function getList(cosmeticType)
    if cosmeticType == "Aura" then return Catalog.Auras end
    if cosmeticType == "Trail" then return Catalog.Trails end
    return nil
end

function Catalog.GetList(cosmeticType)
    return getList(cosmeticType)
end

function Catalog.GetEntry(cosmeticType, cosmeticId)
    local list = getList(cosmeticType)
    if not list then return nil end
    for _, entry in ipairs(list) do
        if entry.Id == cosmeticId then return entry end
    end
    return nil
end

function Catalog.GetSortedShopEntries(cosmeticType)
    local list = getList(cosmeticType)
    if not list then return {} end
    local output = {}
    for _, entry in ipairs(list) do
        if entry.ShopEnabled == true then table.insert(output, entry) end
    end
    table.sort(output, function(a,b)
        local ao = tonumber(a.SortOrder) or math.huge
        local bo = tonumber(b.SortOrder) or math.huge
        if ao == bo then return tostring(a.DisplayName) < tostring(b.DisplayName) end
        return ao < bo
    end)
    return output
end

-- What a player can own and equip from the Backpack: everything in the shop plus the
-- exclusives (won elsewhere, never sold), in shop order.
function Catalog.GetSortedOwnableEntries(cosmeticType)
    local list = getList(cosmeticType)
    if not list then return {} end
    local output = {}
    for _, entry in ipairs(list) do
        if entry.ShopEnabled == true or entry.Exclusive ~= nil then table.insert(output, entry) end
    end
    table.sort(output, function(a,b)
        local ao = tonumber(a.SortOrder) or math.huge
        local bo = tonumber(b.SortOrder) or math.huge
        if ao == bo then return tostring(a.DisplayName) < tostring(b.DisplayName) end
        return ao < bo
    end)
    return output
end

-- True for an entry a player may equip once owned (shop items and exclusives).
function Catalog.IsOwnable(cosmeticType, cosmeticId)
    local entry = Catalog.GetEntry(cosmeticType, cosmeticId)
    return entry ~= nil and (entry.ShopEnabled == true or entry.Exclusive ~= nil)
end

-- The speed-gain multiplier an equipped cosmetic gives: always a finite number of at
-- least 1, whatever the entry holds (or 1 for no entry), so a bad value can never turn
-- a player's speed gain into 0, NaN or infinity.
function Catalog.GetSpeedMultiplier(cosmeticType, cosmeticId)
    local entry = Catalog.GetEntry(cosmeticType, cosmeticId)
    local value = entry and tonumber(entry.SpeedMultiplier)
    if value == nil or value ~= value or value == math.huge or value < 1 then
        return 1
    end
    return value
end

function Catalog.IsValid(cosmeticType, cosmeticId)
    return Catalog.GetEntry(cosmeticType, cosmeticId) ~= nil
end

return Catalog
