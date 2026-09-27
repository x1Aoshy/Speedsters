local SuitCatalog = {}

SuitCatalog.DefaultSkinId = "FlashSuit"

                                                                       
                                                              
SuitCatalog.Ordered = {
	{
		Id = "FlashSuit",
		DisplayName = "Flash",
		RequiredLevel = 0,
		RequiredRebirths = 0,
		Stamina = 5,
		PreviewAssetId = 97111421088356,
		SpecialApplyMode = "Flash",
		MaskId = 97111421088356,
		ShirtId = 955766290,
		PantsId = 83870697444502,
	},
	{
		Id = "ReverseSpeedsterSuit",
		DisplayName = "Reverse Flash",
		RequiredLevel = 10,
		RequiredRebirths = 0,
		Stamina = 10,
		PreviewAssetId = 122419525213200,
		MaskId = 122419525213200,
		ShirtId = 212690295,
		PantsId = 99789483690368,
	},
	{
		Id = "ZoomSuit",
		DisplayName = "Zoom",
		RequiredLevel = 20,
		RequiredRebirths = 1,
		Stamina = 15,
		PreviewAssetId = 132005514117950,
		MaskId = 132005514117950,
		ShirtId = 3673065919,
		PantsId = 3673054397,
	},
	{
		Id = "SavitarSuit",
		DisplayName = "Savitar",
		RequiredLevel = 40,
		RequiredRebirths = 2,
		Stamina = 20,
		PreviewAssetId = 16014323120,
		MaskId = 16014323120,
		ShirtId = 6507970832,
		PantsId = 15309290342,
	},
	{
		Id = "KidFlashSuit",
		DisplayName = "Kid Flash",
		RequiredLevel = 55,
		RequiredRebirths = 3,
		Stamina = 25,
		PreviewAssetId = 120260245366958,
		MaskId = 120260245366958,
		HairId = 136828432298752,
		ShirtId = 5464288292,
		PantsId = 2700006055,
	},
	{
		Id = "WhiteSpeedsterSuit",
		DisplayName = "White Speedster",
		RequiredLevel = 60,
		RequiredRebirths = 4,
		Stamina = 25,
		PreviewAssetId = 14778713670,
		MaskId = 14778713670,
		ShirtId = 13978232700,
		PantsId = 13978239731,
	},
	{
		Id = "WallyWestSuit",
		DisplayName = "Wally West",
		RequiredLevel = 65,
		RequiredRebirths = 5,
		Stamina = 30,
		PreviewAssetId = 107539477684737,
		MaskId = 107539477684737,
		HairId = 136828432298752,
		ShirtId = 105443727455330,
		PantsId = 113637274430768,
	},
	{
		Id = "MobiusWallyWestSuit",
		DisplayName = "Mobius Wally West",
		RequiredLevel = 75,
		RequiredRebirths = 7,
		Stamina = 35,
		PreviewAssetId = 111075229495775,
		MaskId = 111075229495775,
		HairId = 136828432298752,
		ShirtId = 99715184434658,
		PantsId = 105102583031517,
	},
	-- Superman and A-Train are worn from their rigs (ReplicatedStorage.SkinRigs, captured
	-- from the models the team placed in World 1): their shirt, pants, accessories, face
	-- and exact skin tone ("RigOutfit" in SkinSystem). The rig is also the Index picture.
	{
		Id = "SupermanSuit",
		DisplayName = "Superman",
		RequiredLevel = 100,
		RequiredRebirths = 8,
		Stamina = 40,
		SpecialApplyMode = "RigOutfit",
		SourceModelName = "Superman",
		PreviewRig = "Superman",
	},
	{
		Id = "BlackFlashSuit",
		DisplayName = "Black Flash",
		RequiredLevel = 100,
		RequiredRebirths = 9,
		Stamina = 45,
		PreviewAssetId = 71482589805519,
		MaskId = 71482589805519,
		ShirtId = 14656937333,
		PantsId = 14656894017,
	},
	{
		Id = "ATrainSuit",
		DisplayName = "A-Train",
		RequiredLevel = 115,
		RequiredRebirths = 10,
		Stamina = 48,
		SpecialApplyMode = "RigOutfit",
		SourceModelName = "ATrain",
		PreviewRig = "ATrain",
	},
	{
		Id = "SonicSuit",
		DisplayName = "Sonic",
		RequiredLevel = 125,
		RequiredRebirths = 11,
		Stamina = 50,
		PreviewAssetId = 134463237703042,
		MaskId = 134463237703042,
		ShirtId = 19005794684,
		PantsId = 19005802461,
	},
	{
		Id = "SuperSonicSuit",
		DisplayName = "Super Sonic",
		RequiredLevel = 140,
		RequiredRebirths = 12,
		Stamina = 55,
		PreviewAssetId = 92267659861534,
		MaskId = 92267659861534,
		ShirtId = 74116910523887,
		PantsId = 101611425229994,
	},
	{
		Id = "SuperSaiyanSonicSuit",
		DisplayName = "Super Saiyan Sonic",
		RequiredLevel = 160,
		RequiredRebirths = 14,
		Stamina = 60,
		PreviewAssetId = 135502835814559,
		MaskId = 135502835814559,
		ShirtId = 87398404462163,
		PantsId = 9313515742,
	},
	-- Shadow the Hedgehog: catalog pieces (his head is a hair accessory).
	{
		Id = "ShadowSuit",
		DisplayName = "Shadow",
		RequiredLevel = 180,
		RequiredRebirths = 15,
		Stamina = 65,
		PreviewAssetId = 140470689397913,
		HairId = 140470689397913,
		ShirtId = 17640070614,
		PantsId = 124377132418733,
	},
}
-- (World 2 used to restack every rebirth requirement after Wally West's at +2 per suit.
-- That gave the same numbers as the table above, and would have moved the suits added
-- between them, so each suit now states its own requirement for every world.)

SuitCatalog.Limited = {
	{
		Id = "DarkZonicSuit",
		DisplayName = "Dark Zonic",
		Stamina = 60,
		PreviewAssetId = 101898979975358,
		MaskId = 101898979975358,
		ShirtId = 17438086712,
		PantsId = 80051704518658,
		SpecialApplyMode = "WorkspaceDummy",
		SourceModelName = "DarkZonic",
	},
}

-- Skins that are won, never evolved into or bought: the Spin Wheel's. Each is a whole
-- rig kept in ServerStorage (SourceModelName) that SkinSystem fits onto the player's
-- R6 body ("ModelMorph"), not catalog clothing.
SuitCatalog.Exclusive = {
	{
		Id = "TungTungSuit",
		DisplayName = "Tung Tung Sahur",
		Stamina = 60,
		-- The rig's own asset: its thumbnail is the Tung Tung, face on.
		PreviewAssetId = 114124284706337,
		SpecialApplyMode = "ModelMorph",
		SourceModelName = "TungTung",
		Exclusive = "SpinWheel",
	},
	-- World 3's mythic skin: won by finishing World 3 (its End). The Surfer's '07 set from
	-- the catalog on a silver body, riding a hovering surfboard (SkinSystem welds it under
	-- the feet and lifts the body; Movement/SurfboardPose gives it the surfer's stance).
	{
		Id = "SilverSurferSuit",
		DisplayName = "Silver Surfer",
		Stamina = 70,
		PreviewAssetId = 121883186226008,
		ShirtId = 125551170573176,
		PantsId = 134606364864304,
		Accessories = {
			{ Id = 121883186226008, Field = "HatAccessory" }, -- head
			{ Id = 116050620391341, Field = "FrontAccessory" }, -- torso
			{ Id = 135898206122665, Field = "WaistAccessory" }, -- waist
			{ Id = 133557750004146, Field = "ShoulderAccessory" }, -- left shoulder
			{ Id = 84178960816487, Field = "ShoulderAccessory" }, -- right shoulder
		},
		-- Silver skin (R, G, B).
		SkinColorRGB = { 196, 204, 214 },
		-- The waist board, ridden under the feet; the back board if it cannot load.
		Surfboard = { AssetId = 93465249025940, FallbackAssetId = 113577354579185 },
		Exclusive = "World3",
		Rarity = "Mythic",
	},
}

SuitCatalog.ById = {}
for index, entry in ipairs(SuitCatalog.Ordered) do
	entry.Order = index
	SuitCatalog.ById[entry.Id] = entry
end
for _, entry in ipairs(SuitCatalog.Limited) do
	SuitCatalog.ById[entry.Id] = entry
end
for _, entry in ipairs(SuitCatalog.Exclusive) do
	SuitCatalog.ById[entry.Id] = entry
end

function SuitCatalog.Get(skinId)
	return SuitCatalog.ById[tostring(skinId or "")]
end

function SuitCatalog.IsValid(skinId)
	return SuitCatalog.Get(skinId) ~= nil
end

return SuitCatalog
