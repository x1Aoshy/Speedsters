local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.GameName = "+1 Speed Speedster Escape"

                                                                  
Config.StageCount = 10

                                                                            
                                                                            
                                                                           
Config.World2PlaceId = 116359653478954
Config.World2SafeZoneSuffix = ".2"
Config.World2WalkSpeedMultiplier = 1 / 3
Config.IsWorld2Place = game.PlaceId == Config.World2PlaceId

                                                                          
                                                                             
                                                                              
                                  
Config.NewWorld1MapMarkerName = "neworld1"
Config.IsNewWorld1Map = Config.IsWorld2Place ~= true
	and (workspace:FindFirstChild(Config.NewWorld1MapMarkerName) ~= nil
		or ReplicatedStorage:GetAttribute("NewWorld1MapActive") == true)
Config.NewWorld1SafeZonePrefix = "stage"
if Config.IsNewWorld1Map then
	Config.StageCount = 11
end

                                                                          
                                                                             
                                     
Config.AbilityFlightEnabled = Config.IsWorld2Place ~= true
Config.AbilityFlightUpgradeName = "Flight"
Config.AbilityFlightWinsCost = 1000000
Config.AbilityFlightProductId = 3708338152
Config.AbilityFlightPriceRobux = 79
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

                                                                            
                                                                            
                                                                         
Config.World2TreadmillProfiles = {
	TreadmillGold = {
		SourceName = "Treadmill2_fast",
		BaseGain = 3,
		RequiredRebirths = 1,
	},
	TreadmillDiamond = {
		SourceName = "Treadmill3_superfast",
		BaseGain = 9,
		RequiredRebirths = 5,
	},
	TreadmillCandy = {
		SourceName = "Treadmill4_hyperspeed",
		BaseGain = 25,
		RequiredRebirths = 10,
	},
	TreadmillAdmin = {
		SourceName = "Treadmill5_insanespeed",
		BaseGain = 50000000,
		GamePassId = 1941342451,
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
end

                          
Config.TreadmillPopupColors = {
	Treadmill1_basic = Color3.fromRGB(145, 80, 35),
	Treadmill2_fast = Color3.fromRGB(255, 190, 0),
	Treadmill3_superfast = Color3.fromRGB(0, 145, 255),
	Treadmill4_hyperspeed = Color3.fromRGB(255, 55, 190),
	Treadmill5_insanespeed = Color3.fromRGB(255, 0, 0),
}

if Config.IsWorld2Place then
	Config.TreadmillPopupColors.TreadmillGold = Config.TreadmillPopupColors.Treadmill2_fast
	Config.TreadmillPopupColors.TreadmillDiamond = Config.TreadmillPopupColors.Treadmill3_superfast
	Config.TreadmillPopupColors.TreadmillCandy = Config.TreadmillPopupColors.Treadmill4_hyperspeed
	Config.TreadmillPopupColors.TreadmillAdmin = Config.TreadmillPopupColors.Treadmill5_insanespeed
end

                                   
Config.TreadmillPopupBurstCounts = {
	Treadmill1_basic = 1,
	Treadmill2_fast = 3,
	Treadmill3_superfast = 6,
	Treadmill4_hyperspeed = 10,
	Treadmill5_insanespeed = 18,
}

if Config.IsWorld2Place then
	Config.TreadmillPopupBurstCounts.TreadmillGold = Config.TreadmillPopupBurstCounts.Treadmill2_fast
	Config.TreadmillPopupBurstCounts.TreadmillDiamond = Config.TreadmillPopupBurstCounts.Treadmill3_superfast
	Config.TreadmillPopupBurstCounts.TreadmillCandy = Config.TreadmillPopupBurstCounts.Treadmill4_hyperspeed
	Config.TreadmillPopupBurstCounts.TreadmillAdmin = Config.TreadmillPopupBurstCounts.Treadmill5_insanespeed
end

Config.DefaultPopupBurstCount = 3
Config.InsanePopupBurstCount = 18

                                                                             
                                                                        
                                            
Config.RunningSpeedPerTick = Config.IsWorld2Place and 0.25 or 1

                        
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
	{ Tier = 1, ProductId = 3641603114, PriceRobux = 7,  Percent = 10,   GainMultiplier = 0.10 },
	{ Tier = 2, ProductId = 3641605426, PriceRobux = 15, Percent = 30,   GainMultiplier = 0.30 },
	{ Tier = 3, ProductId = 3641608334, PriceRobux = 39, Percent = 100,  GainMultiplier = 1.00 },
	{ Tier = 4, ProductId = 3641610998, PriceRobux = 79, Percent = 1000, GainMultiplier = 10.00 },
}

Config.SpeedProductDisplayRefreshSeconds = 1
Config.SpeedProductDisplayRoundDownStep = 10
Config.SpeedProductBackgroundIconImage = "rbxassetid://18209577000"

                                                                        
                                                                                 
                                                              
Config.PermanentBaseSpeedMultiplierDefault = 1
Config.PermanentSpeedMultiplierProducts = {
	{ Stage = 1, ProductId = 3650735503, PriceRobux = 3,  Label = "x2 Speed",  TargetMultiplier = 2,  Theme = "Gold" },
	{ Stage = 2, ProductId = 3650778372, PriceRobux = 7,  Label = "x4 Speed",  TargetMultiplier = 4,  Theme = "Rainbow" },
	{ Stage = 3, ProductId = 3650798979, PriceRobux = 19, Label = "x10 Speed", TargetMultiplier = 10, Theme = "Galactic", RepeatAddMultiplier = 10 },
}

                                                                               
                                                                              
                                                     
Config.PermanentWinsMultiplierDefault = 1

                                                                      
                                                                           
Config.DoubleWinsPadGamePassId = 1941409601
Config.PermanentWinsMultiplierProducts = {
	{ Stage = 1, ProductId = 3674002277, PriceRobux = 3,  Label = "x2 Wins",  TargetMultiplier = 2,  Theme = "Gold" },
	{ Stage = 2, ProductId = 3674011914, PriceRobux = 7,  Label = "x4 Wins",  TargetMultiplier = 4,  Theme = "Rainbow" },
	{ Stage = 3, ProductId = 3674018331, PriceRobux = 19, Label = "x10 Wins", TargetMultiplier = 10, Theme = "Galactic", RepeatAddMultiplier = 10 },
}

                                                                         
                                                                                
Config.StarterPackGamePassId = 1941169289
Config.StarterPackPriceRobux = 7
Config.StarterPackIconImage = "rbxthumb://type=Asset&id=120522986837915&w=420&h=420"
Config.StarterPackVisibleSeconds = 17 * 60
Config.StarterPackSpeedReward = 100000
Config.StarterPackWinsReward = 100
Config.StarterPackTrailReward = "Trail02"

Config.ReviveProductId = 3679899328
Config.RevivePriceRobux = 7
Config.ReviveIconImage = "rbxthumb://type=Asset&id=12492678216&w=420&h=420"
Config.ReviveOfferSeconds = 5

                                                                            
                                                                               
Config.InfiniteRevivesGamePassId = 1941301459
Config.InfiniteRevivesIconImage = Config.ReviveIconImage

                                                     
                                                                              
                                                                        
                                                                          
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
if Config.IsNewWorld1Map then
	Config.TeleportStageOptions = {
		{ Stage = 1, WinsCost = 20, ProductId = 3651982563, PriceRobux = 3 },
		{ Stage = 2, WinsCost = 70, ProductId = 3651996160, PriceRobux = 5 },
		{ Stage = 3, WinsCost = 100, ProductId = 3652015050, PriceRobux = 7 },
		{ Stage = 4, WinsCost = 150, ProductId = 3652021435, PriceRobux = 15 },
		{ Stage = 5, WinsCost = 700, ProductId = 3652028654, PriceRobux = 29 },
		{ Stage = 6, WinsCost = 1500, ProductId = 3701431169, PriceRobux = 39 },
		{ Stage = 7, WinsCost = 7500, ProductId = 3701432747, PriceRobux = 59 },
		{ Stage = 8, WinsCost = 14000, ProductId = 3701433971, PriceRobux = 79 },
		{ Stage = 9, WinsCost = 40000, ProductId = 3701436062, PriceRobux = 99 },
		{ Stage = 10, WinsCost = 150000, ProductId = 0, PriceRobux = 0, WinsOnly = true },
		{ Stage = 11, WinsCost = 700000, ProductId = 0, PriceRobux = 0, WinsOnly = true },
	}
end

          
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
