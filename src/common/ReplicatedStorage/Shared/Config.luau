local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.GameName = "+1 Speed Speedster Escape"

                                                                  
Config.StageCount = 10

                                                                            
                                                                            
                                                                           
Config.World1PlaceId = 85065221510105
Config.World2PlaceId = 116359653478954
Config.World2SafeZoneSuffix = ".2"
-- 2026-09-22 (owner's choice): half of World 1's walk, up from a third. At a third, a runner
-- entering World 2 walked 32 studs/s against 96 in World 1 at the same Speed.
Config.World2WalkSpeedMultiplier = 0.5
-- Repeat legitimate runs across all worlds without a hidden three-minute lockout.
Config.FinalPadCooldownSeconds = 1.5
Config.World2FinalPadCooldownSeconds = 1.5
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

-- World 3 (Desert). Its place carries PlaceWorldNumber = 3 on Workspace and
-- ReplicatedStorage, as World 1 and World 2 carry 1 and 2. World3PlaceId is production.
-- The map check is only a fallback for a copy that lost the
-- attribute, so it never runs in a place that has a world number.
Config.World3PlaceId = 128432111599629
-- Stages 9 (Scorpion Trail) and 10 (Sandstorm Cliffs) and the End came with the final desert
-- map on 2026-09-18.
Config.World3StageCount = 10
-- What it takes to travel to World 3 the first time; after that it stays unlocked
-- (World3Unlocked on the profile). Returning from World 3 is always free.
Config.World3UnlockRebirths = 15
Config.World3UnlockLevel = 200
-- The same for World 2 (World2Unlocked on the profile; the server unlocks it the moment
-- both are met). 2026-09-22: moved here from WorldPortalService and WorldsController,
-- which each had their own copy, and the World 2 card text is now written from these,
-- so a new gate is this one edit. 2026-09-22 (owner's choice): 6 Rebirths + Level 50, down
-- from 7 + 100. Modelled for a free runner with no aura or trail: ~38 min instead of ~5.3 h
-- (R6 -> R7 was the wall); the unlock is permanent once saved.
Config.World2UnlockRebirths = 6
Config.World2UnlockLevel = 50
local hasWorld3Map = explicitWorldNumber == nil
	and workspace:FindFirstChild("Lobby") ~= nil
	and workspace:FindFirstChild("Stage 1") ~= nil
	and workspace:FindFirstChild("Stage 8") ~= nil
Config.IsWorld3Place = Config.IsWorld2Place ~= true
	and ((explicitWorldNumber == 3)
		or (Config.World3PlaceId ~= nil and game.PlaceId == Config.World3PlaceId)
		or (game.PlaceId == 94956471703437)
		or hasWorld3Map)

-- Walking slows world by world: World 2 walks at half of World 1's speed, and World 3
-- at a quarter. WorldWalkSpeedMultiplier is this place's.
-- 2026-09-22: World 3 is its own number, no longer World 2's divided by 3, so retuning
-- World 2 cannot silently change the desert.
-- 2026-09-22 feel pass: 1/9 played like molasses; the owner raised it to 0.25 (still
-- heavier than World 2's 0.5, 2.25 times the old desert walk).
-- StatsService never lets the scaled walk drop under the rules' minimum (8).
Config.World3WalkSpeedMultiplier = 0.25
Config.WorldWalkSpeedMultiplier = if Config.IsWorld2Place == true then Config.World2WalkSpeedMultiplier
	elseif Config.IsWorld3Place == true then Config.World3WalkSpeedMultiplier
	else 1

                                                                          
                                                                             
                                                                              
                                  
Config.NewWorld1MapMarkerName = "neworld1"
Config.IsNewWorld1Map = Config.IsWorld2Place ~= true
	and Config.IsWorld3Place ~= true
	and (workspace:FindFirstChild(Config.NewWorld1MapMarkerName) ~= nil
		or ReplicatedStorage:GetAttribute("NewWorld1MapActive") == true)
Config.NewWorld1SafeZonePrefix = "stage"
if Config.IsNewWorld1Map then
	Config.StageCount = 11
elseif Config.IsWorld3Place then
	Config.StageCount = Config.World3StageCount
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
Config.AbilityFlightGlideDownRunMultiplier = 0.08
Config.AbilityFlightGlideMinimumDownSpeed = 8.0
Config.AbilityFlightLoopSoundId = "rbxassetid://596046130"
Config.AbilityFlightLoopSoundVolume = 1.2
Config.AbilityFlightSteeringResponse = 28
Config.AbilityFlightOrientationResponse = 34
-- Flight cost, as a share of the player's OWN stamina bar (Shared.FlightStamina).
-- Percentages, not flat numbers: suits range from 5 to 60 stamina, so a flat cost
-- either deletes the small suits or is free for the big ones. Every suit therefore
-- gets the same flight; the suit buys longer sprints, not different flight.
--
--   climb  ~2.5 s of powered ascent from a full bar
--   glide  ~7.1 s of descent from a full bar
--   lift off at 12% of the bar, so a player who just sprinted can still take off
Config.AbilityFlightDrainPercentPerSecond = 0.35
Config.AbilityFlightDrainFloorPerSecond = 0.5
Config.AbilityFlightGlideDrainPercentPerSecond = 0.14
Config.AbilityFlightGlideDrainFloorPerSecond = 0.2
Config.AbilityFlightMinimumStaminaPercent = 0.12
Config.AbilityFlightMinimumStaminaFloor = 0.5
-- Jump once and keep the button held: flight engages this long after leaving the
-- ground, instead of making the player hold through a full ground timer.
Config.AbilityFlightAirborneHoldSeconds = 0.18

-- Promo codes.
--
-- Redeeming happens in the Shop's Codes section (it owns the text box), reachable
-- in one tap from the topbar Codes icon. Shared.Catalogs.CodesCatalog is
-- authoritative for which codes redeem, and the Update Logs banner lists
-- CodesCatalog.Active.
--
-- The separate "Codes Modal" - the card list that used to shove itself in the
-- player's face when the Update Logs closed - stays parked. It duplicated the shop
-- section with hardcoded cards. Flip this to true to bring it back.
Config.PromoCodesModalEnabled = false

-- Preview features: the Spin Wheel, AFK Rewards and the AFK Zone, Quests and the old
-- full-screen Glass Shatter (Shared.FeatureGate; the sprint no longer plays it: the glass
-- now breaks at stage barriers and the finish for everyone, Shared.GlassBurst). They show
-- in Studio and on the testing places below for everyone; on live servers only the
-- preview accounts see them.
Config.PreviewFeatures = {
	AllPlayers = true,
	Enabled = true,
	UserIds = {
		767108248, -- GekkoH
	},
	-- PlaceIds of the testing places (every player there sees the preview features).
	TestingPlaceIds = {
		138540610580146, -- World 1 testing place
		96501592055150, -- World 2 testing place
		94956471703437, -- World 3 testing place
	},
}

-- Spin Wheel (Shared.SpinWheelCatalog holds the segments and their odds).
-- Spins come from Spin Tickets (Quests, the AFK Zone, Robux packs, Wins) and one free
-- spin per window. Windows are global, so every server agrees on when the free spin resets.
Config.SpinWheel = {
	Enabled = true,
	-- One free spin every 12 hours: whoever comes back the next day always finds one waiting
	-- (the Day 1 return), without handing out so many that the packs mean nothing.
	FreeSpinWindowSeconds = 12 * 3600,
	SpinSeconds = 4.6,
	-- The "Skip" game pass: its owners get a Skip check on the panel that lands the wheel in
	-- SkipSpinSeconds instead of SpinSeconds. Pressing the check without the pass opens its
	-- purchase. Create a pass named "Skip" at SkipPriceRobux on the Creator Dashboard and put
	-- its id here; until then the check tells players it is coming soon. In Studio and for
	-- preview accounts (Shared.FeatureGate) it works without the pass, for testing.
	SkipGamePassId = 1986854592,
	SkipPriceRobux = 49,
	SkipSpinSeconds = 0.6,
	-- The floor point the world wheel stands on, and the point it turns to face.
	-- Chosen from the maps: flat, clear lobby floor in view of the spawn.
	WorldPlacement = {
		World1 = { Position = Vector3.new(328.3, 37467.69, -1753.1), Face = Vector3.new(280.3, 37467.69, -1781.1) },
		World2 = { Position = Vector3.new(-828.8, 36626.65, -1003.8), Face = Vector3.new(-783.8, 36626.65, -993.8) },
		-- On the desert lobby's floor (top at y 95.61), facing the spawn: in the open sand north
		-- of the treadmills (2026-09-18: in front of them it was in the way of "Train Speed").
		World3 = { Position = Vector3.new(345.0, 95.61, 390.0), Face = Vector3.new(265.3, 95.61, 521.6) },
	},
	-- Robux spin packs behind the panel's X1, X3 and X10 buttons (X10 is added beside the
	-- wheel): developer products that grant Spin Tickets.
	Products = {
		{ Key = "Spins1", Button = "X1", ProductId = 3713535039, Spins = 1, PriceRobux = 29 },
		{ Key = "Spins3", Button = "X3", ProductId = 3713535083, Spins = 3, PriceRobux = 69 },
		{ Key = "Spins10", Button = "X10", ProductId = 3713535151, Spins = 10, PriceRobux = 199, Caption = "BEST VALUE" },
	},
	-- One spin bought with Wins, for players with Wins to burn: a flat FixedCost, far above
	-- what the wheel pays back in Wins on average (about an eighth of a lap of the player's
	-- world), and capped per window, so it is a Wins sink and never a Wins farm.
	WinsPurchase = {
		Enabled = true,
		MaxPerWindow = 2,
		WindowSeconds = 3600,
		FixedCost = 50000000,
		PrizeMultiple = 20,
		MinimumCost = 50000,
	},
	-- The Wins segments pay a share of a lap of the world the player is in (LapWins, set
	-- below once the worlds' rewards are known): 15% on the small one, 60% on the big one.
	SmallLapShare = 0.15,
	LargeLapShare = 0.6,
}

-- AFK Mode (2026-09-18, Sung's request; it replaced the AFK Zone circle in the lobbies):
-- turned on with Go AFK! on the Earnings panel (the AFK icon on the top bar opens it). The
-- player's character stands on this lobby's AFK spot (WorldPlacement; many players share
-- it in a ring up to SpotRadius wide), anchored and safe. Every RewardIntervalSeconds the
-- server pays SpeedShare of their Speed (never under SpeedFloor; x VipSpeedMultiplier with
-- VIP), and a Spin Ticket every TicketIntervalSeconds, until Exit AFK. The client keeps
-- them past Roblox's 20-minute idle kick (Social/AfkZoneService, UI/AfkZoneController).
Config.AfkZone = {
	Enabled = true,
	RewardIntervalSeconds = 60,
	-- Speed per reward: this share of the player's current Speed, never below the floor.
	SpeedShare = 0.005,
	SpeedFloor = 500,
	VipSpeedMultiplier = 5,
	TicketIntervalSeconds = 600,
	SpotRadius = 22,
	SlotSpacing = 2.8,
	-- Earnings while away (Social/AfkRewardsService), +1 Monkey style: back after at least
	-- OfflineMinMinutes, each minute away (up to OfflineMaxMinutes, 8 hours) pays
	-- OfflineSpeedShare of the player's Speed, never less than 50 + 10 per level. That is
	-- 6% of AFK Mode's own rate: staying in AFK Mode always pays more. 8 hours away pay
	-- about 14% of the player's Speed; x5, about 72%.
	OfflineMinMinutes = 10,
	OfflineMaxMinutes = 8 * 60,
	OfflineSpeedShare = 0.0003,
	-- "Get x5" on the Earnings panel for every player (independent of VIP): a
	-- developer product that collects the rewards on screen five times over. Its live
	-- Creator Hub price is 19 R$; PriceRobux is only the UI fallback if price lookup fails.
	ClaimX5 = { ProductId = 3713742489, PriceRobux = 19 },
	-- Open floor beside each spawn, clear of the main walk and lobby props for 60 slots.
	WorldPlacement = {
		World1 = Vector3.new(318.0, 37467.69, -1770.0),
		World2 = Vector3.new(-746.0, 36626.65, -994.0),
		World3 = Vector3.new(224.0, 95.61, 500.0), -- the desert lobby's floor
	},
}

-- The admin treadmill's place in each lobby (Admin/AdminAbusePanelService): the floor point
-- under its middle and a point a runner on it looks toward. Since 2026-09-18 (pre-launch
-- review) it stands centred right in front of the way out to Stage 1, in the last stretch of
-- lobby floor before the first obstacle, its runner looking out at the track:
--   World 1: on the start strip's line (Folder.Union, x 278.5), between the strip and the
--            gap before Stage 1's first platform (the lobby floor ends at z -1600.1).
--   World 2: in the middle of the opening between the two walls (x -807.3 and -745.0) that
--            lead onto the parkour (the floor ends at z -924.5).
--   World 3: on the start strip's line (Lobby.Union, x 267.07), between the strip and Stage
--            1's Starting Platform (the lobby floor ends at z 340.6).
-- The treadmill is about 38 studs long and 27 wide; each spot leaves a few studs of floor
-- in front of it and is clear of the spawn and the Spin Wheel.
Config.AdminTreadmill = {
	WorldPlacement = {
		World1 = { Position = Vector3.new(278.51, 37467.69, -1623.0), Face = Vector3.new(278.51, 37467.69, -1583.0) },
		World2 = { Position = Vector3.new(-776.15, 36626.65, -948.0), Face = Vector3.new(-776.15, 36626.65, -908.0) },
		World3 = { Position = Vector3.new(267.07, 95.61, 363.5), Face = Vector3.new(267.07, 95.61, 323.5) },
	},
}
-- Plank bridges that run smooth (Gameplay/SmoothBridges, 2026-09-18, Sung's video: the
-- wooden bridge jerked runners at every plank): the bridge models, by name, in each world.
-- An invisible ramp follows the planks' tops and the planks only show.
Config.SmoothBridges = {
	Enabled = true,
	World1 = {},
	World2 = { "Japanese Bridge" },
	World3 = { "Bridge" }, -- the two over Stage 5's quicksand
}

-- The Disco Party in each lobby (Admin/AdminAbusePanelService, AdminAbuseEffects): the
-- middle of the dance floor on the lobby floor and the floor's size. The mirror ball hangs
-- BallHeight over its middle. Chosen from the maps: the open main lobby floor before the
-- stages, flat all over, between the treadmill and leaderboard areas.
--
-- Booth is the giant DJ booth where the admin who started the party dances: the bottom
-- of its stage (middle) and a point it faces (the dance floor), BoothScale times the
-- size of a normal booth. It stands out past the lobby's back wall, the side away from the
-- stages, at the height where, from the dance floor, the wall hides the stage, the
-- console rises over the wall and hides the DJ's legs, and the DJ shows from the waist
-- up. Found with sightlines against the maps; audit/test_admin_abuse_panel checks them.
Config.AdminDisco = {
	-- Raised from 34 on 2026-09-18 (the user wanted the ball higher over the dance floor).
	BallHeight = 44,
	BoothScale = 5.5,
	-- The Disco perk (2026-09-18 pre-launch review): while the party is on, every player on
	-- the server gets PassiveSpeedMultiplier on their Speed gain, wherever they are. A player
	-- who dances (the dance floor's own dance, or /e dance anywhere), standing still on the
	-- ground, gets DanceSpeedMultiplier instead and earns Speed as if running for as long as
	-- they dance. Their HUD shows a [Disco] card with the multiplier.
	PassiveSpeedMultiplier = 3,
	DanceSpeedMultiplier = 100,
	WorldPlacement = {
		World1 = {
			Floor = Vector3.new(290.28, 37467.69, -1755.14),
			Size = Vector3.new(112, 0, 140),
			Booth = { Position = Vector3.new(275.86, 37561.69, -1979.68), Face = Vector3.new(290.28, 37561.69, -1755.14) },
		},
		World2 = {
			Floor = Vector3.new(-781.83, 36626.65, -980.76),
			Size = Vector3.new(76, 0, 94),
			Booth = { Position = Vector3.new(-791.71, 36678.65, -1145.46), Face = Vector3.new(-781.83, 36678.65, -980.76) },
		},
		World3 = {
			Floor = Vector3.new(259.30, 95.61, 505.64),
			Size = Vector3.new(112, 0, 120),
			Booth = { Position = Vector3.new(267.03, 235.61, 770.53), Face = Vector3.new(259.30, 235.61, 505.64) },
		},
	},
}
Config.CodesTopbarIconImage = "rbxassetid://138738878130228"

-- Background music playlist (PXuTo's list). Shuffled once per session and played
-- through; the track order differs per player so a lobby does not hear the same
-- loop in sync. Edit here, not in BackgroundMusic.client.
--
-- Sounds in ReplicatedStorage.Music still win if that folder has any, so authored
-- audio keeps priority over this list.
Config.BackgroundMusicTracks = {
	{ Id = "rbxassetid://85735197482652",  Name = "DRIFT NIGHT PHONK (Car Motion Edit)" },
	{ Id = "rbxassetid://139777823649977", Name = "phonkmusic" },
	{ Id = "rbxassetid://122959603077641", Name = "Harbor at Dusk" },
	{ Id = "rbxassetid://136221009150327", Name = "MONTAGEM DRIFT ETERNO" },
	{ Id = "rbxassetid://140521045204459", Name = "BATE FORTE" },
	{ Id = "rbxassetid://139959590610806", Name = "FUNK FESTA" },
	{ Id = "rbxassetid://95131770144654",  Name = "AURA (Brazilian Phonk/Funk)" },
}
Config.BackgroundMusicVolume = 0.24
Config.BackgroundMusicDuckedVolume = 0.06
-- Retired: this was an absolute 5 against bars from 5 to 60, so the FlashSuit
-- needed a full bar to lift off at all. See AbilityFlightMinimumStaminaPercent.
Config.AbilityFlightMinimumStaminaToPower = nil
Config.AbilityFlightHoldSeconds = 0.85
Config.AbilityFlightPoweredAnimationId = "rbxassetid://74232261112592"
Config.AbilityFlightGlideAnimationId = "rbxassetid://80682143002357"

Config.AbilitySpeedForceEnabled = Config.IsWorld2Place == true
Config.AbilitySpeedForceHoldSeconds = 0.37
Config.AbilitySpeedForceServerTimeoutSeconds = 10.75

-- Sonic Burst (Core/Abilities/SonicBurstService, Movement/SonicBurstClient): hold the sprint
-- (Shift; a gamepad's sprint trigger; the Burst button on phones) and the stamina bar drains
-- into the charge while a bubble of glass and lightning swells round the player; let go
-- and it shatters (the Glass Shatter) and throws them forward for DashSeconds, harder the
-- fuller the charge (Shared.SonicBurstMath). Bought with Wins in the Abilities panel.
--
-- Price: an endgame (World 3) ability, damped like Flight by the square root of the
-- permanent Wins multiplier (Shared.WinsMath.GetProgressionPrice). A World 3 lap pays
-- 41M at x1, so 500M is about 12 laps at x1, 6 at x4, 3 at x16 and still over 2 at x32:
-- a real goal at every rung, never a lap's pocket money (audit/test_wins_economy).
Config.AbilitySonicBurstEnabled = true
Config.AbilitySonicBurstUpgradeName = "SonicBurst"
Config.AbilitySonicBurstGamePassId = 1985906818
Config.AbilitySonicBurstPriceRobux = 499
Config.AbilitySonicBurstWinsCost = 500000000
Config.AbilitySonicBurstCooldownSeconds = 9
-- The bubble's pulse beats every ChargeSeconds; also MovementGuard's margin.
Config.AbilitySonicBurstChargeSeconds = 0.4
Config.AbilitySonicBurstDashSeconds = 0.35
-- The throw (Shared.SonicBurstMath): dash speed = speed + Gain * ln(1 + speed / Knee),
-- where speed is the player's speedometer speed (or how fast they already go). A new
-- player at 16 studs/s dashes ~6x faster (about 30 studs); a veteran at 1000 gets a
-- ~500-stud burst. Never over MaxDashSpeed, and it stops at the first wall.
Config.AbilitySonicBurstGain = 90
Config.AbilitySonicBurstKnee = 12
Config.AbilitySonicBurstMaxDashSpeed = 2200
-- The camera: 70 -> 88 FOV and back with an elastic settle, and a short shake.
Config.AbilitySonicBurstFovPunch = 18
Config.AbilitySonicBurstChargeSoundId = "rbxassetid://9114277757" -- Electric Zaps 12 (SFX)
Config.AbilitySonicBurstBoomSoundId = "rbxassetid://9119382815" -- Sonic Boom 5 (SFX)

-- Heat Vision Trail (2026-09-18): Superman's own skill, for whoever wears the Superman skin
-- (no purchase). R on a keyboard, Y on a gamepad or its HUD button fires red beams from the
-- eyes that melt a path of molten rock on the ground ahead, toward the mouse, the tapped
-- point or where the camera looks, to cross gaps. The path runs from the feet up to
-- MaxLength studs (never under MinLength), stops short of any wall, lasts BridgeSeconds
-- and then cools and fades; one every CooldownSeconds (Core/Abilities/HeatVisionService,
-- Movement/HeatVisionClient, Shared/HeatVisionMath).
Config.AbilityHeatVision = {
	Enabled = true,
	SkinId = "SupermanSuit",
	MaxLength = 40,
	MinLength = 10,
	BridgeSeconds = 3.5,
	CooldownSeconds = 18,
	Width = 6,
	Thickness = 1.2,
	SegmentLength = 5,
	DrawSeconds = 0.35,
	FadeSeconds = 0.6,
}

-- The glass: breaking through a stage barrier or the finish at speed, and the Sonic Burst
-- bubble (Shared.GlassBurst). Stage crossing shatter is disabled by default (Config.StageBarrierShatterEnabled = false).
-- Sprint glass shatter triggers after 3 seconds with +2% speed boost.
Config.GlassBreakSoundId = "rbxassetid://9114615010"
Config.StageBarrierShatterMinSpeed = 45
Config.StageBarrierShatterEnabled = false
Config.SprintSonicBuildupSeconds = 3.0
Config.SprintSonicBoostMultiplier = 1.02

-- The Silver Surfer's board (SkinSystem, Movement/SurfboardPose): how far it lifts the
-- body (Humanoid.HipHeight, a relative offset on R6) so the board floats over the floor.
Config.SurfboardHover = 0.85

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
-- Stage 10 is one stage away from the finish, and the finish pays World2FinalWinReward: twice
-- what Stage 10's own pad pays. Priced like the others (725,000, against its own 500,000 pad) the
-- trip left 275,000 Wins of profit for running a single stage, so players reached the goal far
-- too cheaply. It is priced against the pad it really leads to: 1.5 finishes = 1,500,000.
Config.World2FinalStageTeleportFinishes = 1.5
Config.World2TeleportWinsCosts[10] = math.max(
	Config.World2TeleportWinsCosts[10],
	roundWorld2TeleportWins(Config.World2FinalWinReward * Config.World2FinalStageTeleportFinishes)
)

-- World 3: Stage 1 starts at the lobby spawn; Stage N (2-10) is the checkpoint inside the
-- map's "Stage N" folder, where its Win pad pays World3StageWinRewards[N]. The finish (the
-- End, after Stage 10) pays World3FinalWinReward. Rewards continue past World 2's final pad.
Config.World3StageWinRewards = {
	[2] = 750000,
	[3] = 1000000,
	[4] = 1500000,
	[5] = 2000000,
	[6] = 2750000,
	[7] = 3500000,
	[8] = 5000000,
	[9] = 6500000,
	[10] = 8000000,
}
Config.World3FinalWinReward = 10000000

-- What one lap pays in each world, for the Spin Wheel's Wins prizes. World 1's pads live in
-- its world script (NewWorld1ManualStagePads); audit/test_wins_economy keeps this in step.
Config.SpinWheel.LapWins = { World1 = 1157020 }
do
	local world2, world3 = Config.World2FinalWinReward, Config.World3FinalWinReward
	for _, reward in pairs(Config.World2StageWinRewards) do
		world2 += reward
	end
	for _, reward in pairs(Config.World3StageWinRewards) do
		world3 += reward
	end
	Config.SpinWheel.LapWins.World2 = world2
	Config.SpinWheel.LapWins.World3 = world3
end

Config.World3TeleportWinsCosts = {}
for stage, reward in pairs(Config.World3StageWinRewards) do
	Config.World3TeleportWinsCosts[stage] = roundWorld2TeleportWins(reward * 1.45)
end

Config.World2TreadmillProfiles = {
	Golden = {
		BaseGain = 10,
		PopupColor = Color3.fromRGB(255, 190, 0),
		PopupBurstCount = 1,
		DisplayText = "Starter\nx10 Speed",
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
	-- The paid Valentine treadmill (149 R$). 2026-09-22: x40, above every free treadmill
	-- in every world (World 2's Diamond is x30); it was x25.
	Needoh = {
		BaseGain = 40,
		GamePassId = 1941090466,
		PopupColor = Color3.fromRGB(255, 55, 190),
		PopupBurstCount = 10,
		DisplayText = "x40 Speed",
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
	-- The admin panel's treadmill (Admin/AdminAbusePanelService): the Hacker treadmill's 300
	-- plus exactly 5% (the admin's multiplier only raises the Wins it pays).
	Admin3000 = {
		BaseGain = 315,
		PopupColor = Color3.fromRGB(255, 215, 0),
		PopupBurstCount = 28,
		DisplayText = "x315 Speed\n(+5% Hacker)",
		UseNestedTreadmil = true,
		-- Built on demand by the admin panel and never authored in the map, so it is
		-- expected to be missing when the server starts.
		SpawnedAtRuntime = true,
	},
}

                                                                          
                                                                            
                                                                               
                                                            
-- World 3's lobby has the Basic, Diamond, Needoh, Admin and Hacker treadmills, built like
-- World 2's. Basic is the starter anyone can use (World 2's Golden, added to the lobby by
-- audit/compose_world3.luau). Diamond is slower than World 2's and locked behind more
-- Rebirths, so Speed in the desert is a grind. Needoh, Admin and Hacker are sold as game
-- passes with the multiplier shown in the shop, so they keep it in every world.
Config.World3TreadmillProfiles = {
	Basic = {
		BaseGain = 10,
		PopupColor = Color3.fromRGB(255, 190, 0),
		PopupBurstCount = 1,
		DisplayText = "Starter\nx10 Speed",
		StarterOnly = true,
		UseNestedTreadmil = true,
	},
	Diamond = {
		BaseGain = 30,
		RequiredRebirths = 12,
		PopupColor = Color3.fromRGB(30, 180, 255),
		PopupBurstCount = 10,
		DisplayText = "x30 Speed",
		UseNestedTreadmil = true,
	},
	Needoh = Config.World2TreadmillProfiles.Needoh,
	Admin = Config.World2TreadmillProfiles.Admin,
	Hacker = Config.World2TreadmillProfiles.Hacker,
	Admin3000 = Config.World2TreadmillProfiles.Admin3000,
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
	-- 2026-09-20 pacing (audit): each rebirth cycle took 3-5 times the one before, and the jump
	-- from under 4 minutes to 14 and then 51 fell at minute 5-20 of a first session, exactly
	-- where new players start leaving faster. The free treadmills now unlock one rebirth apart
	-- (Candy was 3, Diamond was 7), which halves rebirths 5, 6 and 7. Gains are unchanged, so
	-- the paid treadmills keep their lead; World 2's gate (Config.World2UnlockRebirths and
	-- World2UnlockLevel, near the top) did not change with them.
	Candy = {
		BaseGain = 5,
		RequiredRebirths = 2,
		PopupColor = Color3.fromRGB(255, 92, 202),
		PopupBurstCount = 5,
		DisplayText = "x5 Speed",
	},
	Diamond = {
		BaseGain = 10,
		RequiredRebirths = 4,
		PopupColor = Color3.fromRGB(30, 180, 255),
		PopupBurstCount = 10,
		DisplayText = "x10 Speed",
	},
	-- The paid Valentine treadmill (149 R$). 2026-09-22: x40, above every free treadmill
	-- in every world (World 2's Diamond is x30); it was x25.
	Needoh = {
		BaseGain = 40,
		GamePassId = 1941090466,
		PopupColor = Color3.fromRGB(255, 55, 190),
		PopupBurstCount = 10,
		DisplayText = "x40 Speed",
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
	-- The admin panel's treadmill (Admin/AdminAbusePanelService): the Hacker treadmill's 300
	-- plus exactly 5% (the admin's multiplier only raises the Wins it pays).
	Admin3000 = {
		BaseGain = 315,
		PopupColor = Color3.fromRGB(255, 215, 0),
		PopupBurstCount = 28,
		DisplayText = "x315 Speed\n(+5% Hacker)",
		UseNestedTreadmil = true,
		-- Built on demand by the admin panel and never authored in the map, so it is
		-- expected to be missing when the server starts.
		SpawnedAtRuntime = true,
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
	SupermanSuit = 40,
	BlackFlashSuit = 45,
	ATrainSuit = 48,
	SonicSuit = 50,
	SuperSonicSuit = 55,
	SuperSaiyanSonicSuit = 60,
	ShadowSuit = 65,
	SilverSurferSuit = 70,
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
Config.TreadmillTrainingTickSeconds = 0.5

                            
                                             
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
elseif Config.IsWorld3Place then
	for treadmillName, profile in pairs(Config.World3TreadmillProfiles) do
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
elseif Config.IsWorld3Place then
	for treadmillName, profile in pairs(Config.World3TreadmillProfiles) do
		Config.TreadmillPopupColors[treadmillName] = profile.PopupColor or Color3.fromRGB(255, 255, 255)
	end
else
	for treadmillName, profile in pairs(Config.NewWorld1TreadmillProfiles or {}) do
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
elseif Config.IsWorld3Place then
	for treadmillName, profile in pairs(Config.World3TreadmillProfiles) do
		Config.TreadmillPopupBurstCounts[treadmillName] = math.max(1, math.floor(tonumber(profile.PopupBurstCount) or 3))
	end
else
	for treadmillName, profile in pairs(Config.NewWorld1TreadmillProfiles or {}) do
		Config.TreadmillPopupBurstCounts[treadmillName] = math.max(1, math.floor(tonumber(profile.PopupBurstCount) or 3))
	end
end

Config.DefaultPopupBurstCount = 7
Config.InsanePopupBurstCount = 18

                                                                             
                                                                        
                                            
Config.RunningSpeedPerTick = (Config.IsWorld2Place or Config.IsWorld3Place) and 0.25 or 1

                        
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
if Config.IsWorld2Place or Config.IsWorld3Place then
	Config.SuitSpeedGainMultipliers = {
		FlashSuit = 5,
		ReverseSpeedsterSuit = 20,
		ZoomSuit = 35,
		SavitarSuit = 50,
		KidFlashSuit = 65,
		WhiteSpeedsterSuit = 80,
		WallyWestSuit = 95,
		MobiusWallyWestSuit = 110,
		SupermanSuit = 118,
		BlackFlashSuit = 125,
		ATrainSuit = 133,
		SonicSuit = 140,
		SuperSonicSuit = 155,
		SuperSaiyanSonicSuit = 170,
		ShadowSuit = 185,
		-- The paid limited (Config.DarkZonicGamePassId): top of the ladder here too. It was
		-- missing from this table, so in World 2/3 it fell back to x1, below the free Flash.
		DarkZonicSuit = 300,
		-- The Spin Wheel's Tung Tung Sahur: level with the top of this ladder.
		TungTungSuit = 200,
		-- World 3's mythic Silver Surfer, won by finishing World 3.
		SilverSurferSuit = 250,
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
		SupermanSuit = 118,
		BlackFlashSuit = 125,
		ATrainSuit = 133,
		SonicSuit = 140,
		SuperSonicSuit = 155,
		SuperSaiyanSonicSuit = 170,
		ShadowSuit = 185,
		DarkZonicSuit = 300,
		-- The Spin Wheel's Tung Tung Sahur: above every evolution, below the paid limited.
		TungTungSuit = 200,
		-- World 3's mythic Silver Surfer (won by finishing World 3): above Tung Tung, still
		-- below the paid limited.
		SilverSurferSuit = 250,
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
-- M50 (2026-09-25): the dial never goes under the Roblox walk speed, and a runner whose full
-- speed is still at most 24 is never slowed at all (CharacterStatsAdapter, WalkSpeedSelector).
Config.WalkSpeedSelectorFloor = 16
Config.WalkSpeedSelectorFullBelow = 24
-- H10 (2026-09-25): MovementGuard measures its strict lane without acting on it ("Observe");
-- "Enforce" only after the MG_StrictPass_v2 / MG_StrictWouldReject_v2 numbers say so.
Config.MovementGuardMode = "Observe"

                                                       
                                                                           
                                                                             
                                               
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

-- x2 Wins pads: ONE permanent gamepass. Buy it once and every x2 pad pays double.
-- The shop and the HUD call it "2X Victory"; both names are the same pass.
Config.TwoXVictoryGamePassId = 1941409601
Config.DoubleWinsPadGamePassId = 1941409601
-- Retired: the per-claim "2x Wins (PAD)" developer product that briefly replaced the
-- pass. Never prompted again; SpeedProductPurchases only honours an in-flight receipt.
Config.RetiredDoubleWinsPadProductId = 3712435111

Config.TwoXSpeedGamePassId = 1941060529
Config.TenXSpeedGamePassId = tonumber(Config.TenXSpeedGamePassId) or nil
-- Wins multiplier ladder: five developer products, bought in order, each one a
-- permanent multiplier on EVERY wins reward. Ids from the Creator Dashboard:
--   product  3710772221  "2x Wins"
--   product  3710772271  "4x Wins"
--   product  3710772305  "8x Wins"
--   product  3710772331  "16x Wins"
--   product  3710772380  "32x Wins"
--
-- Separate from the x2 pads gamepass above (1941409601), which only doubles the x2
-- pads. The two stack. PriceRobux is a display fallback; the live dashboard price wins.
-- Keep the x2 rung at or above the pads pass: at the old 20 R$ it sold x2 on every
-- reward for less than a tenth of what the pass charges for x2 on the pads alone.
--
-- Economic note, measured against the live tables. A full World 1 lap pays
-- 1,157,020 wins (11 stage pads = 457,020, plus the 700,000 final pad); a full
-- World 2 lap pays 2,985,000. The FIXED unlock pool - every unlock whose price
-- does not move - is 7 auras (11,111,110) + 7 trails (11,111,110) + Flight
-- (25,000,000) = 47,222,220. Rebirths cost Level, not Wins. World 3 adds a much deeper
-- cosmetic sink on top (its auras and trails, from 20M up to 5B each); the ladder below
-- is tuned against the fixed pool, which World 3 does not change.
--
-- Against a pool that small, an undamped ladder eats the game:
--
--   tier   World 1 laps to buy every fixed unlock
--   x1                 40.8
--   x4                 10.2
--   x8                  5.1
--   x16                 2.6
--   x32                 1.3
--
-- x32 is not the disease. x16 clears the same pool in 2.6 laps; the pool is just
-- shallow. Capping the ladder only moves the number, so the fix is on the price
-- side, not the ladder side - see ProgressionPriceMultiplierExponent below.
Config.PermanentWinsMultiplierProducts = {
	{ Stage = 1, ProductId = 3710772221, PriceRobux = 249,  Label = "x2 Wins",  TargetMultiplier = 2,  Theme = "Gold" },
	{ Stage = 2, ProductId = 3710772271, PriceRobux = 349,  Label = "x4 Wins",  TargetMultiplier = 4,  Theme = "Rainbow" },
	{ Stage = 3, ProductId = 3710772305, PriceRobux = 649,  Label = "x8 Wins",  TargetMultiplier = 8,  Theme = "Galactic" },
	{ Stage = 4, ProductId = 3710772331, PriceRobux = 1199, Label = "x16 Wins", TargetMultiplier = 16, Theme = "Obsidian" },
	{ Stage = 5, ProductId = 3710772380, PriceRobux = 2199, Label = "x32 Wins", TargetMultiplier = 32, Theme = "Solar" },
}

Config.MaxPermanentWinsMultiplier = 32

-- How hard progression unlocks push back against the ladder above.
--
-- Flight and Sonic Burst are priced as
-- `baseCost * permanentMultiplier ^ exponent` (Shared.WinsMath.GetProgressionPrice).
-- Stage teleports are NOT (since 2026-09-20): a trip lands beside pads that pay with the full
-- multiplier, so damping its price let players loop teleport -> pad for free Wins. A trip costs
-- `WinsCost * every Wins multiplier * 2 with the x2 pads pass` (WinsMath.GetStageTripPrice).
-- Cosmetics are deliberately NOT priced this way: making auras and trails land
-- sooner is the thing the player actually bought.
--
--   0    no scaling. x32 buys every fixed unlock in 1.3 World 1 laps.
--   0.5  x32 reaches Flight 5.7x faster than x1, and still runs ~3.8 laps for it.
--   1    x32 pays exactly 32x more, so the ladder buys nothing at all here.
--
-- 0.5 is the setting that makes each rung worth its price without letting it skip
-- the run. Set to 0 to restore flat pricing.
Config.ProgressionPriceMultiplierExponent = 0.5

-- Retired: the OG ladder ids. Never offered, but still redeemable so a receipt
-- already in flight is honoured instead of being retried forever by Roblox.
Config.RetiredPermanentWinsMultiplierProducts = {
	{ ProductId = 3674002277, TargetMultiplier = 2 },
	{ ProductId = 3674011914, TargetMultiplier = 4 },
	{ ProductId = 3674018331, TargetMultiplier = 10 },
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

-- Gifting game passes. Roblox only sells a pass to the player buying it, so each giftable
-- pass gets a developer product at the same price. Buying that product for someone saves
-- the pass on their profile (Services/Monetization/GiftedPasses) and the game treats it as
-- owning the pass, on every server and every join. A pass without a ProductId shows
-- "Not giftable" in the gift panel until the product exists.
Config.GamePassGiftProducts = {
	{ PassId = 1941409601, Name = "2x Wins Pads", ProductId = 3713527917 },
	{ PassId = 1941060529, Name = "2x Speed", ProductId = 3713528200 },
	{ PassId = 1903494497, Name = "VIP", ProductId = 3713528334 },
	{ PassId = 1941301459, Name = "Infinite Revives", ProductId = 3713528700 },
	{ PassId = 1978623069, Name = "Flight", ProductId = 3713528771 },
	{ PassId = 1941169289, Name = "Starter Pack", ProductId = 3713528820 },
	-- The pass treadmills (2026-09-18): a gift unlocks the treadmill (TreadmillTraining).
	{ PassId = 1941090466, Name = "Valentine Treadmill", ProductId = 3713529108 },
	{ PassId = 1941342451, Name = "Admin Treadmill", ProductId = 3713529193 },
	{ PassId = 1954325260, Name = "Hacker Treadmill", ProductId = 3713529324 },
}

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
elseif Config.IsWorld3Place then
	-- Same teleport products as the other worlds; each one names its stage.
	Config.TeleportStageOptions = {}
	for _, option in ipairs(WORLD2_TELEPORT_STAGE_OPTIONS) do
		if option.Stage <= Config.World3StageCount then
			table.insert(Config.TeleportStageOptions, {
				Stage = option.Stage,
				WinsCost = Config.World3TeleportWinsCosts[option.Stage],
				ProductId = option.ProductId,
				PriceRobux = option.PriceRobux,
			})
		end
	end
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
-- Dev / Tester titles (ReplicatedStorage.Titles): the title's text sits in pixels just above
-- the name and speed (OverheadStats), so the two never overlap at any distance; the title
-- part, which carries the particle emitters, is welded this many studs above the head.
Config.OverheadTitleHeight = 34
Config.OverheadTitleGap = 5
Config.TitleParticleHeight = 4
Config.TitleParticleDrop = 0.2
Config.OverheadAfkTagHeight = 26
Config.OverheadAfkTagColor = Color3.fromRGB(120, 205, 255)
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
Config.Testers = {
	["himothy09871"] = true,
	["realwhisper0909"] = true,
	["jay_1231600"] = true,
	["fabbyy_yt"] = true,
	["dripreeper"] = true,
	["techssasinbadass"] = true,
	["supermangolflow"] = true,
}

-- Only the pre-Update 4 DEV tag reads this (Bootstrap's overhead fallback, UI/VipChatTag's chat
-- fallback) while the Titles feature is off; with Titles on, Update4Config.Titles decides.
-- 2026-09-26 (owner): Gekkoh (767108248, formerly spartakiller45) removed: he was forced to DEV.
Config.Developers = {
	[111827288] = true, -- pxuto
}

function Config.IsTester(player): boolean
	if not player then return false end
	if type(player.GetAttribute) == "function" and player:GetAttribute("IsTester") == true then return true end
	-- Update 4 (2026-09-25): Name (unique) or UserId only. A DisplayName can be set to anyone's
	-- username, so matching it handed out staff titles and panels.
	local name = if type(player.Name) == "string" then string.lower(player.Name) else ""
	if (name ~= "" and Config.Testers[name]) or (player.UserId and Config.Testers[player.UserId]) then
		return true
	end
	return false
end

function Config.IsDeveloper(player): boolean
	if not player then return false end
	if type(player.GetAttribute) == "function" and player:GetAttribute("IsDev") == true then return true end
	local name = if type(player.Name) == "string" then string.lower(player.Name) else ""
	if (name ~= "" and Config.Developers[name]) or (player.UserId and Config.Developers[player.UserId]) then
		return true
	end
	return false
end

return Config
