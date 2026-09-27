local SuitCatalog = {}

SuitCatalog.DefaultSkinId = "FlashSuit"
local WORLD_2_PLACE_ID = 116359653478954
local IS_WORLD_2_PLACE = game.PlaceId == WORLD_2_PLACE_ID

                                                                       
                                                              
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
		RequiredRebirths = IS_WORLD_2_PLACE and 6 or 7,
		Stamina = 35,
		PreviewAssetId = 111075229495775,
		MaskId = 111075229495775,
		HairId = 136828432298752,
		ShirtId = 99715184434658,
		PantsId = 105102583031517,
	},
	{
		Id = "BlackFlashSuit",
		DisplayName = "Black Flash",
		RequiredLevel = 100,
		RequiredRebirths = IS_WORLD_2_PLACE and 7 or 9,
		Stamina = 45,
		PreviewAssetId = 71482589805519,
		MaskId = 71482589805519,
		ShirtId = 14656937333,
		PantsId = 14656894017,
	},
}

                                                                               
                                                                             
                                                     
if not IS_WORLD_2_PLACE then
	table.insert(SuitCatalog.Ordered, {
		Id = "SonicSuit",
		DisplayName = "Sonic",
		RequiredLevel = 125,
		RequiredRebirths = 11,
		Stamina = 50,
		PreviewAssetId = 134463237703042,
		MaskId = 134463237703042,
		ShirtId = 19005794684,
		PantsId = 19005802461,
	})
	table.insert(SuitCatalog.Ordered, {
		Id = "SuperSonicSuit",
		DisplayName = "Super Sonic",
		RequiredLevel = 155,
		RequiredRebirths = 13,
		Stamina = 55,
		PreviewAssetId = 92267659861534,
		MaskId = 92267659861534,
		ShirtId = 74116910523887,
		PantsId = 101611425229994,
	})
	table.insert(SuitCatalog.Ordered, {
		Id = "SuperSaiyanSonicSuit",
		DisplayName = "Super Saiyan Sonic",
		RequiredLevel = 175,
		RequiredRebirths = 15,
		Stamina = 60,
		PreviewAssetId = 135502835814559,
		MaskId = 135502835814559,
		ShirtId = 87398404462163,
		PantsId = 9313515742,
	})

	                                                                        
	                                                                      
	                                                                          
	                                                                             
	local foundWallyWest = false
	local previousRequiredRebirths = 0
	for _, entry in ipairs(SuitCatalog.Ordered) do
		if entry.Id == "WallyWestSuit" then
			foundWallyWest = true
			previousRequiredRebirths = tonumber(entry.RequiredRebirths) or 0
		elseif foundWallyWest then
			entry.RequiredRebirths = previousRequiredRebirths + 2
			previousRequiredRebirths = entry.RequiredRebirths
		end
	end
end

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

SuitCatalog.ById = {}
for index, entry in ipairs(SuitCatalog.Ordered) do
	entry.Order = index
	SuitCatalog.ById[entry.Id] = entry
end
for _, entry in ipairs(SuitCatalog.Limited) do
	SuitCatalog.ById[entry.Id] = entry
end

function SuitCatalog.Get(skinId)
	return SuitCatalog.ById[tostring(skinId or "")]
end

function SuitCatalog.IsValid(skinId)
	return SuitCatalog.Get(skinId) ~= nil
end

return SuitCatalog
