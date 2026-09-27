local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.GameName = "+1 Speed Speedster Escape"

                                                                  
Config.StageCount = 10

                                                                            
                                                                            
                                                                           
Config.World1PlaceId = 85065221510105
Config.World2PlaceId = 96501592055150
Config.World2SafeZoneSuffix = ".2"
Config.World2WalkSpeedMultiplier = 1
local explicitWorldNumber = ReplicatedStorage:GetAttribute("PlaceWorldNumber")
	or workspace:GetAttribute("PlaceWorldNumber")

local hasWorld2Map = workspace:FindFirstChild("safezone2.2") ~= nil
	or workspace:FindFirstChild("Japanese Torii Gate") ~= nil
	or workspace:FindFirstChild("Sonic.EXE") ~= nil
	or workspace:FindFirstChild("WinStage.2") ~= nil
	or workspace:FindFirstChild("SixSevenArea") ~= nil

Config.IsWorld2Place = (explicitWorldNumber == 2)
	or (game.PlaceId == Config.World2PlaceId)
	or (game.PlaceId == 96501592055150)
	or (game.PlaceId == 116359653478954)
	or (hasWorld2Map == true)

                                                                          
                                                                             
                                                                              
                                  
Config.NewWorld1MapMarkerName = "neworld1"
Config.IsNewWorld1Map = Config.IsWorld2Place ~= true
	and (workspace:FindFirstChild(Config.NewWorld1MapMarkerName) ~= nil
		or ReplicatedStorage:GetAttribute("NewWorld1MapActive") == true)
Config.NewWorld1SafeZonePrefix = "stage"
if Config.IsNewWorld1Map then
	Config.StageCount = 11
end

                                                                          
                                                                             
                                     
Config.AbilityFlightEnabled = true
Config.AbilityFlightUpgradeName = "Flight"
Config.AbilityFlightWinsCost = 25000000
Config.AbilityFlightGamePassId = 1978623069
Config.AbilityFlightProductId = 1978623069
Config.AbilityFlightPriceRobux = 799
Config.AbilityFlightPoweredSpeedMultiplier = 0.3151
Config.AbilityFlightVerticalSpeedMultiplier = 0.3151
Config.AbilityFlightMinimumUpSpeed = 24.66
Config.AbilityFlightGlideForwardMultiplier = 1.2519
Config.AbilityFlightGlideDownRunMultiplier = 0.3255
Config.AbilityFlightGlideMinimumDownSpeed = 22.32
Config.AbilityFlightLoopSoundId = "rbxassetid://596046130"
Config.AbilityFlightLoopSoundVolume = 1.2
Config.AbilityFlightSteeringResponse = 28
Config.AbilityFlightOrientationResponse = 34
Config.AbilityFlightDrainPerSecond = 11.7
Config.AbilityFlightMinimumStaminaToPower = 0.25
Config.AbilityFlightPoweredAnimationId = "rbxassetid://74232261112592"
Config.AbilityFlightGlideAnimationId = "rbxassetid://80682143002357"

Config.AbilitySpeedForceEnabled = Config.IsWorld2Place == true
Config.AbilitySpeedForceHoldSeconds = 0.37
Config.AbilitySpeedForceServerTimeoutSeconds = 10.75

Config.World2StageWinRewards = {
	[2] = 50000,
	[3] = 75000,
	[4] = 125000,
	[5] = 150000,
	[6] = 175000,
	[7] = 235000,
	[8] = 300000,
	[9] = 375000,
	[10] = 500000,
}
Config.World2FinalWinReward = 1000000

local function roundWorld2TeleportWins(value)
	local step = 25000
	return math.floor((math.max(0, tonumber(value) or 0) + step * 0.5) / step) * step
end

Config.World2TeleportWinsCosts = {}
for stage, reward in pairs(Config.World2StageWinRewards) do
	Config.World2TeleportWinsCosts[stage] = roundWorld2TeleportWins(reward * 1.45)
end

Config.World2TreadmillProfiles = {
	Golden = {
		BaseGain = 3,
		PopupColor = Color3.fromRGB(255, 190, 0),
		PopupBurstCount = 1,
		DisplayText = "Starter\nx3 Speed",
		StarterOnly = true,
		UseNestedTreadmil = true,
	},
	Candy = {
		BaseGain = 15,
		RequiredRebirths = 9,
		PopupColor = Color3.fromRGB(255, 92, 202),
		PopupBurstCount = 5,
		DisplayText = "x15 Speed",
		UseNestedTreadmil = true,
	},
	Diamond = {
		BaseGain = 30,
		RequiredRebirths = 11,
		PopupColor = Color3.fromRGB(30, 180, 255),
		PopupBurstCount = 10,
		DisplayText = "x30 Speed",
		UseNestedTreadmil = true,
	},
	Needoh = {
		BaseGain = 25,
		GamePassId = 1941090466,
		PopupColor = Color3.fromRGB(255, 55, 190),
		PopupBurstCount = 10,
		DisplayText = "x25 Speed",
		UseNestedTreadmil = true,
	},
	Admin = {
		BaseGain = 100,
		GamePassId = 1941342451,
		PopupColor = Color3.fromRGB(255, 55, 55),
		PopupBurstCount = 18,
		DisplayText = "x100 Speed",
		UseNestedTreadmil = true,
	},
	Hacker = {
		BaseGain = 300,
		GamePassId = 1954325260,
		PopupColor = Color3.fromRGB(65, 255, 115),
		PopupBurstCount = 24,
		DisplayText = "x300 Speed",
		UseNestedTreadmil = true,
	},
}

                                                                          
                                                                            
                                                                               
                                                            
Config.NewWorld1TreadmillProfiles = {
	Basic = {
		BaseGain = 1,
		PopupColor = Color3.fromRGB(145, 80, 35),
		PopupBurstCount = 1,
		DisplayText = "Starter\nx1 Speed",
	},
	Golden = {
		BaseGain = 3,
		RequiredRebirths = 1,
		PopupColor = Color3.fromRGB(255, 190, 0),
		PopupBurstCount = 3,
		DisplayText = "x3 Speed",
	},
	Candy = {
		BaseGain = 5,
		RequiredRebirths = 3,
		PopupColor = Color3.fromRGB(255, 92, 202),
		PopupBurstCount = 5,
		DisplayText = "x5 Speed",
	},
	Diamond = {
		BaseGain = 10,
		RequiredRebirths = 7,
		PopupColor = Color3.fromRGB(30, 180, 255),
		PopupBurstCount = 10,
		DisplayText = "x10 Speed",
	},
	Needoh = {
		BaseGain = 25,
		GamePassId = 1941090466,
		PopupColor = Color3.fromRGB(255, 55, 190),
		PopupBurstCount = 10,
		DisplayText = "x25 Speed",
	},
	Admin = {
		BaseGain = 100,
		GamePassId = 1941342451,
		PopupColor = Color3.fromRGB(255, 55, 55),
		PopupBurstCount = 18,
		DisplayText = "x100 Speed",
	},
	Hacker = {
		BaseGain = 300,
		GamePassId = 1954325260,
		PopupColor = Color3.fromRGB(65, 255, 115),
		PopupBurstCount = 24,
		DisplayText = "x300 Speed",
	},
}

                                                                                  
                                                                            
Config.SkipStageProductId = 3675714820

                                                       
Config.StartingSpeed = 1

                                        
Config.BaseWalkSpeed = 8
Config.SpeedToWalkSpeedMultiplier = 0.08
Config.UseWalkSpeedCap = false
Config.MaxWalkSpeed = 120

                                              
                            
                                              
                                                  
Config.UseSmoothRealSpeedFormula = true
Config.RealWalkSpeedMin = 8
Config.RealWalkSpeedReferenceDisplayedSpeed = 3.37e15
Config.RealWalkSpeedAtReference = 300

                                                           
Config.RealWalkSpeedCurve = 2

                         
                                                                                       
Config.MaxStoredSpeed = 1e50

                        
                                                                     
Config.BoostStaminaDisplayBase = 17
Config.BoostStaminaDisplayFlash = 5
Config.BoostStaminaDisplayReverseSpeedster = 10
Config.BoostStaminaFlashSkinName = "FlashSuit"
Config.SuitStaminaMax = {
	FlashSuit = 5,
	ReverseSpeedsterSuit = 10,
	ZoomSuit = 15,
	SavitarSuit = 20,
	KidFlashSuit = 25,
	WhiteSpeedsterSuit = 25,
	WallyWestSuit = 30,
	MobiusWallyWestSuit = 35,
	BlackFlashSuit = 45,
	SonicSuit = 50,
	SuperSonicSuit = 55,
	SuperSaiyanSonicSuit = 60,
}
Config.BoostDrainPerSecond = 5.78
Config.MinimumStaminaToStartBoost = 1.4
Config.BoostWalkSpeedMultiplier = 1.7
Config.BoostFov = 95
Config.BoostSpeedMultiplier = 1.7
Config.NormalFov = 70
Config.BoostRegenDelaySeconds = 3
                                                                    
Config.BoostRegenTickSeconds = 0.7
Config.BoostRegenPercentPerTick = 0.27
Config.BoostRunningGainMultiplier = 3
Config.BoostRunningVisualAmountMultiplier = 3
Config.BoostRunningPopupBurstMultiplier = 2
Config.BoostRunningPopupMaxBurst = 36
Config.BoostRunningPopupSoundExtraSpeed = 0.35
Config.BoostRunningPopupSoundMaxPlaybackSpeed = 2.25

                 
Config.TrainingTickSeconds = 0.5

                            
                                             
Config.TreadmillBaseGains = {
	Treadmill1_basic = 1,
	Treadmill2_fast = 5,
	Treadmill3_superfast = 10,
	Treadmill4_hyperspeed = 25,
	Treadmill5_insanespeed = 50000000,
}

if Config.IsWorld2Place then
	for treadmillName, profile in pairs(Config.World2TreadmillProfiles) do
		Config.TreadmillBaseGains[treadmillName] = profile.BaseGain
	end
else
	for treadmillName, profile in pairs(Config.NewWorld1TreadmillProfiles or {}) do
		Config.TreadmillBaseGains[treadmillName] = profile.BaseGain
	end
end

                          
Config.TreadmillPopupColors = {
	Treadmill1_basic = Color3.fromRGB(145, 80, 35),
	Treadmill2_fast = Color3.fromRGB(255, 190, 0),
	Treadmill3_superfast = Color3.fromRGB(0, 145, 255),
	Treadmill4_hyperspeed = Color3.fromRGB(255, 55, 190),
	Treadmill5_insanespeed = Color3.fromRGB(255, 0, 0),
}

if Config.IsWorld2Place then
	for treadmillName, profile in pairs(Config.World2TreadmillProfiles) do
		Config.TreadmillPopupColors[treadmillName] = profile.PopupColor or Color3.fromRGB(255, 255, 255)
	end
end

                                   
Config.TreadmillPopupBurstCounts = {
	Treadmill1_basic = 1,
	Treadmill2_fast = 3,
	Treadmill3_superfast = 6,
	Treadmill4_hyperspeed = 10,
	Treadmill5_insanespeed = 18,
}

if Config.IsWorld2Place then
	for treadmillName, profile in pairs(Config.World2TreadmillProfiles) do
		Config.TreadmillPopupBurstCounts[treadmillName] = math.max(1, math.floor(tonumber(profile.PopupBurstCount) or 3))
	end
end

Config.DefaultPopupBurstCount = 3
Config.InsanePopupBurstCount = 18

                                                                             
                                                                        
                                            
Config.RunningSpeedPerTick = 1

                        
Config.WalkingPopupEnabled = true
Config.WalkingPopupColor = Color3.fromRGB(255, 255, 255)
Config.WalkingPopupBurstCount = 1
Config.WalkingPopupName = "Walking"

                                      
                                                                             
                                                                           
                                                    
                                                                
Config.WalkingPopupShowEveryTick = true
Config.WalkingPopupVisualAmount = 1
Config.WalkingPopupSoundPitchFromBurst = false
Config.WalkingPopupTiers = {
	{
		Name = "BrownTreadmillAmount",
		MinimumSpeed = 0,
		BurstCount = Config.TreadmillPopupBurstCounts.Treadmill1_basic,
		SoundPlaybackSpeed = 1.0,
	},
	{
		Name = "GoldTreadmillAmount",
		MinimumSpeed = 1e9,                   
		BurstCount = Config.TreadmillPopupBurstCounts.Treadmill2_fast,
		SoundPlaybackSpeed = 1.15,
	},
	{
		Name = "BlueTreadmillAmount",
		MinimumSpeed = 1e15,                       
		BurstCount = Config.TreadmillPopupBurstCounts.Treadmill3_superfast,
		SoundPlaybackSpeed = 1.35,
	},
	{
		Name = "PinkTreadmillAmount",
		MinimumSpeed = 1e18,                       
		BurstCount = Config.TreadmillPopupBurstCounts.Treadmill4_hyperspeed,
		SoundPlaybackSpeed = 1.55,
	},
	{
		Name = "AdminTreadmillAmount",
		MinimumSpeed = 1e33,                     
		BurstCount = Config.TreadmillPopupBurstCounts.Treadmill5_insanespeed,
		SoundPlaybackSpeed = 1.85,
	},
}

                                                                            
                                                                        
Config.SpeedPopupSoundId = Config.IsWorld2Place
	and "rbxassetid://127105730240202"
	or "rbxassetid://96750121076266"
Config.SpeedPopupSoundVolume = Config.IsWorld2Place and 5.0 or 0.37
Config.SpeedPopupSoundPlaybackSpeed = 1.0

                            
                                                                          
                                                                             
                                                     
                                            
Config.DefaultSuitSpeedGainMultiplier = 1
if Config.IsWorld2Place then
	Config.SuitSpeedGainMultipliers = {
		FlashSuit = 5,
		ReverseSpeedsterSuit = 10,
		ZoomSuit = 15,
		SavitarSuit = 20,
		KidFlashSuit = 25,
		WhiteSpeedsterSuit = 30,
		WallyWestSuit = 35,
		MobiusWallyWestSuit = 40,
		BlackFlashSuit = 45,
		SonicSuit = 50,
		SuperSonicSuit = 55,
		SuperSaiyanSonicSuit = 60,
	}
else
	Config.SuitSpeedGainMultipliers = {
		FlashSuit = 5,
		ReverseSpeedsterSuit = 20,
		ZoomSuit = 35,
		SavitarSuit = 50,
		KidFlashSuit = 65,
		WhiteSpeedsterSuit = 80,
		WallyWestSuit = 95,
		MobiusWallyWestSuit = 110,
		BlackFlashSuit = 125,
		SonicSuit = 140,
		SuperSonicSuit = 155,
		SuperSaiyanSonicSuit = 170,
		DarkZonicSuit = 300,
	}
end

Config.DarkZonicGamePassId = 1963032723
Config.DarkZonicLimitedTotal = 370

Config.VipGamePassId = 1903494497
Config.VipPriceRobux = 499
Config.VipSpeedGainMultiplier = 2
Config.VipWinsMultiplier = 2
Config.VipTestUserIds = {1051594227}

                  
                                    
                                                  
                                                                          
Config.RebirthFirstLevelRequired = 5
Config.RebirthLevelStep = 15
Config.RebirthMultiplierPerRebirth = 1.5

                            
Config.DefaultGlobalSpeedGainMultiplier = 1
Config.DefaultTrailSpeedGainMultiplier = 1
Config.DefaultAuraSpeedGainMultiplier = 1
Config.DefaultUpgradeSpeedGainMultiplier = 1
Config.DefaultGamepassSpeedGainMultiplier = 1

                                       
Config.TreadmillZonePadding = Vector3.new(5, 8, 5)

                                  
                                                                          
                                                               
                                                                          
Config.WalkSpeedSelectorDefaultMode = "Red"
Config.WalkSpeedSelectorMultipliers = {
	Green = 0.20,
	Yellow = 17 / 30,                                   
	Red = 1.00,
}

                                                       
                                                                           
                                                                             
                                               
Config.SpeedProductTiers = {
	{ Tier = 1, ProductId = 3641603114, PriceRobux = 7,  Percent = 10,   GainMultiplier = 0.10, MinGain = 500 },
	{ Tier = 2, ProductId = 3641605426, PriceRobux = 15, Percent = 30,   GainMultiplier = 0.30, MinGain = 2500 },
	{ Tier = 3, ProductId = 3641608334, PriceRobux = 39, Percent = 100,  GainMultiplier = 1.00, MinGain = 10000 },
	{ Tier = 4, ProductId = 3641610998, PriceRobux = 79, Percent = 1000, GainMultiplier = 10.00, MinGain = 50000 },
}

Config.SpeedProductDisplayRefreshSeconds = 1
Config.SpeedProductDisplayRoundDownStep = 10
Config.SpeedProductBackgroundIconImage = "rbxassetid://18209577000"

                                                                        
                                                                                 
                                                              
Config.PermanentBaseSpeedMultiplierDefault = 1
Config.MaxPermanentSpeedMultiplier = 32
Config.PermanentSpeedMultiplierProducts = {
	{ Stage = 1, ProductId = 3710622733, PriceRobux = 20,  Label = "x2 Speed",  TargetMultiplier = 2,  Theme = "Gold" },
	{ Stage = 2, ProductId = 3710682799, PriceRobux = 40,  Label = "x4 Speed",  TargetMultiplier = 4,  Theme = "Rainbow" },
	{ Stage = 3, ProductId = 3710682843, PriceRobux = 80,  Label = "x8 Speed",  TargetMultiplier = 8,  Theme = "Galactic" },
	{ Stage = 4, ProductId = 3710682884, PriceRobux = 160, Label = "x16 Speed", TargetMultiplier = 16, Theme = "Galactic" },
	{ Stage = 5, ProductId = 3710682914, PriceRobux = 320, Label = "x32 Speed", TargetMultiplier = 32, Theme = "Galactic" },
}

                                                                               
                                                                              
                                                     
Config.PermanentWinsMultiplierDefault = 1

Config.TwoXVictoryGamePassId = 1941409601
Config.DoubleWinsPadGamePassId = 1941409601
Config.DoubleWinsPadProductId = 3712435111

Config.TwoXSpeedGamePassId = 1941060529
Config.TenXSpeedGamePassId = tonumber(Config.TenXSpeedGamePassId) or nil
Config.PermanentWinsMultiplierProducts = {
	{ Stage = 1, ProductId = 3712435111, IsGamePass = false, PriceRobux = 20,  Label = "x2 Wins",  TargetMultiplier = 2,  Theme = "Gold" },
	{ Stage = 2, ProductId = 3710772271, PriceRobux = 40,  Label = "x4 Wins",  TargetMultiplier = 4,  Theme = "Rainbow" },
	{ Stage = 3, ProductId = 3710772305, PriceRobux = 80,  Label = "x8 Wins",  TargetMultiplier = 8,  Theme = "Galactic" },
	{ Stage = 4, ProductId = 3710772331, PriceRobux = 160, Label = "x16 Wins", TargetMultiplier = 16, Theme = "Obsidian" },
	{ Stage = 5, ProductId = 3710772380, PriceRobux = 320, Label = "x32 Wins", TargetMultiplier = 32, Theme = "Solar" },
}

Config.PotionWinsProducts = {
	{ Label = "2x Wins 10m", ShopFrame = "PotionSmall", DurationMinutes = 10, TargetMultiplier = 2, ProductId = 3710906712, PriceRobux = 39 },
	{ Label = "2x Wins 30m", ShopFrame = "PotionMedium", DurationMinutes = 30, TargetMultiplier = 2, ProductId = 3710906741, PriceRobux = 119 },
	{ Label = "2x Wins 1h", ShopFrame = "PotionLarge", DurationMinutes = 60, TargetMultiplier = 2, ProductId = 3710906762, PriceRobux = 219 },
}

Config.PotionSpeedProducts = {
	{ Label = "2x Speed 10m", ShopFrame = "2XSpeedpotion10MinSmall", DurationMinutes = 10, TargetMultiplier = 2, ProductId = 3710906127, PriceRobux = 9 },
	{ Label = "2x Speed 30m", ShopFrame = "2XSpeedPotionMedium", DurationMinutes = 30, TargetMultiplier = 2, ProductId = 3710906251, PriceRobux = 27 },
	{ Label = "2x Speed 1h", ShopFrame = "PotionLarge2xSpeed", DurationMinutes = 60, TargetMultiplier = 2, ProductId = 3710906297, PriceRobux = 42 },
}

Config.PotionSpeedMultiplier = 2
Config.PotionWinsMultiplier = 2

Config.ServerSpeedBoostProduct = {
	Label = "2x Speed Server Boost",
	DurationMinutes = 30,
	TargetMultiplier = 2,
	ProductId = 3712435260,
	PriceRobux = 550,
}
                                                                         
                                                                                
Config.StarterPackGamePassId = 1941169289
Config.StarterPackPriceRobux = 50
Config.StarterPackIconImage = "rbxthumb://type=Asset&id=120522986837915&w=420&h=420"
Config.StarterPackVisibleSeconds = 17 * 60
Config.StarterPackSpeedReward = 100000
Config.StarterPackWinsReward = 100
Config.StarterPackTrailReward = "Trail02"

Config.ReviveProductId = 3679899328
Config.RevivePriceRobux = 7
Config.ReviveIconImage = "rbxthumb://type=Asset&id=12492678216&w=420&h=420"
Config.ReviveOfferSeconds = 10

                                                                            
                                                                               
Config.InfiniteRevivesGamePassId = 1941301459
Config.InfiniteRevivesIconImage = Config.ReviveIconImage

-- Valentine treadmill pass (owner-confirmed 1941090466; shared with the
-- in-world Needoh treadmill, so buying it unlocks both).
Config.ValentineTreadmillPassId = 1941090466

                                                     
                                                                              
                                                                        
                                                                          
Config.TeleportMenuIconImage = "rbxassetid://72658080659794"
Config.TeleportWinsIconImage = "rbxassetid://15540211845"
Config.TeleportStageOptions = {
	{ Stage = 2, WinsCost = 10,    ProductId = 3651982563, PriceRobux = 3 },
	{ Stage = 3, WinsCost = 20,    ProductId = 3651996160, PriceRobux = 5 },
	{ Stage = 4, WinsCost = 70,    ProductId = 3652015050, PriceRobux = 7 },
	{ Stage = 5, WinsCost = 300,   ProductId = 3652021435, PriceRobux = 15 },
	{ Stage = 6, WinsCost = 1300,  ProductId = 3652028654, PriceRobux = 29 },
	{ Stage = 7, WinsCost = 4500,  ProductId = 3701431169, PriceRobux = 39 },
	{ Stage = 8, WinsCost = 8500,  ProductId = 3701432747, PriceRobux = 59 },
	{ Stage = 9, WinsCost = 13000, ProductId = 3701433971, PriceRobux = 79 },
	{ Stage = 10, WinsCost = 25000, ProductId = 3701436062, PriceRobux = 99 },
}
local WORLD2_TELEPORT_STAGE_OPTIONS = {
	{ Stage = 2, WinsCost = Config.World2TeleportWinsCosts[2], ProductId = 3651982563, PriceRobux = 3 },
	{ Stage = 3, WinsCost = Config.World2TeleportWinsCosts[3], ProductId = 3651996160, PriceRobux = 5 },
	{ Stage = 4, WinsCost = Config.World2TeleportWinsCosts[4], ProductId = 3652015050, PriceRobux = 7 },
	{ Stage = 5, WinsCost = Config.World2TeleportWinsCosts[5], ProductId = 3652021435, PriceRobux = 15 },
	{ Stage = 6, WinsCost = Config.World2TeleportWinsCosts[6], ProductId = 3652028654, PriceRobux = 29 },
	{ Stage = 7, WinsCost = Config.World2TeleportWinsCosts[7], ProductId = 3701431169, PriceRobux = 39 },
	{ Stage = 8, WinsCost = Config.World2TeleportWinsCosts[8], ProductId = 3701432747, PriceRobux = 59 },
	{ Stage = 9, WinsCost = Config.World2TeleportWinsCosts[9], ProductId = 3701433971, PriceRobux = 79 },
	{ Stage = 10, WinsCost = Config.World2TeleportWinsCosts[10], ProductId = 3701436062, PriceRobux = 99 },
}

if Config.IsWorld2Place then
	Config.TeleportStageOptions = WORLD2_TELEPORT_STAGE_OPTIONS
elseif Config.IsNewWorld1Map then
	Config.TeleportStageOptions = {
		{ Stage = 2, WinsCost = 70, ProductId = 3651982563, PriceRobux = 3 },
		{ Stage = 3, WinsCost = 100, ProductId = 3651996160, PriceRobux = 5 },
		{ Stage = 4, WinsCost = 150, ProductId = 3652015050, PriceRobux = 7 },
		{ Stage = 5, WinsCost = 700, ProductId = 3652021435, PriceRobux = 15 },
		{ Stage = 6, WinsCost = 1500, ProductId = 3652028654, PriceRobux = 29 },
		{ Stage = 7, WinsCost = 7500, ProductId = 3701431169, PriceRobux = 39 },
		{ Stage = 8, WinsCost = 14000, ProductId = 3701432747, PriceRobux = 59 },
		{ Stage = 9, WinsCost = 40000, ProductId = 3701433971, PriceRobux = 79 },
		{ Stage = 10, WinsCost = 150000, ProductId = 3701436062, PriceRobux = 99 },
		{ Stage = 11, WinsCost = 700000, ProductId = 0, PriceRobux = 0, WinsOnly = true },
	}
end

-- Rebirth Purchase Config (GamePass or DevProduct)
Config.RebirthGamePassId = 1979150655
Config.RebirthProductId = 3712374377  -- Developer Product ID for repeatable rebirth purchase
Config.RebirthPriceRobux = 14

          
-- Modular DataService Activation Switch
Config.UseModularDataService = true

Config.DataStoreName = "SpeedsterEscape_MainSave_v17"
Config.AutoSaveSeconds = 30
Config.LoadRetryCount = 3
Config.LoadRetryDelay = 1
Config.SaveRetryCount = 3
Config.SaveRetryDelay = 1
Config.SaveFlushTimeoutSeconds = 20
Config.ShutdownSaveTimeoutSeconds = 25
Config.SessionLeaseSeconds = 120

      
Config.ClientUiUpdateSeconds = 0.1

                            
Config.OverheadEnabled = true
Config.OverheadStudsOffset = Vector3.new(0, 2.65, 0)
Config.OverheadMaxDistance = 37
Config.OverheadNameTextSize = 22
Config.OverheadSpeedTextSize = 20
Config.OverheadNameColor = Color3.fromRGB(255, 255, 255)
Config.OverheadSpeedColor = Color3.fromRGB(255, 214, 35)

                                            
                                                              
                                                  
Config.InstantMovementControllerEnabled = true
Config.InstantMovementStopDeadzone = 0.03
Config.InstantMovementHorizontalStopMultiplier = 0
Config.InstantMovementPreserveVerticalVelocity = true
Config.InstantMovementForceWalkSpeed = true
Config.InstantMovementUseDirectKeyboardInput = true
Config.InstantMovementUseHeartbeat = true
Config.InstantMovementKeepHumanoidMove = true
Config.InstantMovementAirControl = true

return Config
