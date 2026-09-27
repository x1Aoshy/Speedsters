-- test_world3_pads.luau
-- World 3 (Desert), step 3, run offline against the built place:
--
--   1. World3ManualStagePads builds a Win, x2 and Skip pad on every checkpoint (Stages
--      2-10) paying Config.World3StageWinRewards, and the finish (10M / 20M) on the End's
--      floor with confetti, the victory sound and a FINISH sign. Claims go through
--      RewardPadClaims and back to the lobby; x2 needs the pass; Skip prompts the product
--      with the right pending stage (Stage 10 -> the finish).
--   2. World3TreadmillOverheadLabels puts World 3's multiplier and requirement over the
--      four lobby treadmills, facing the spawn.
--   3. WorldPortalService: World 2 -> World 3 needs 15 Rebirths + Level 200 and saves
--      World3Unlocked; World 3 -> World 2 / World 1 is always free.
--   4. World3Unlocked is saved like World2Unlocked, and the shared scripts carry World 3's
--      treadmill locks and the last stage's skip.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local PAD_SCRIPT = "src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau"
local SIGN_SCRIPT = "src/worlds/World3/ServerScriptService/Progression/World3TreadmillOverheadLabels.server.luau"
local TELEPORT_MODULE = "src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"
local PORTAL_SCRIPT = "src/common/ServerScriptService/Worlds/WorldPortalService.server.luau"

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

local function datatypes(env)
	for _, name in { "CFrame", "Vector3", "Vector2", "Color3", "UDim2", "UDim", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		env[name] = env[name] or roblox[name]
	end
	env.typeof = typeof
	env._G = env._G or {}
	env.print = env.print or function() end
	env.warn = env.warn or function() end
	return setmetatable(env, { __index = _G })
end

-- Forwards to an offline instance, adding what Lune instances lack.
local function forward(real, extra)
	return setmetatable({}, {
		__index = function(_, key)
			if extra and extra[key] ~= nil then
				return extra[key]
			end
			local value = real[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(real, ...)
				end
			end
			return value
		end,
	})
end

local placeFile = PlaceFiles.World3
local place = roblox.deserializePlace(fs.readFile(placeFile))
local realWorkspace = place:GetService("Workspace")

-- Config, read from the World 3 place.
local configEnv = datatypes({})
configEnv.workspace = forward(realWorkspace)
configEnv.game = { PlaceId = 0, GetService = function(_, name)
	return forward(place:GetService(name))
end }
local Config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = configEnv })()
assert(Config.IsWorld3Place == true, "The built place must be World 3")
local WinsMath = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/WinsMath.luau"), { environment = datatypes({}) })()

local modules = { Config = Config, WinsMath = WinsMath }
local function marker(name)
	return { __module = name, WaitForChild = function(_, child)
		return { __module = child }
	end }
end
local sharedFolder = { WaitForChild = function(_, name)
	return { __module = name }
end }

-- 1. Pads ------------------------------------------------------------------
local feedback = {}
local prompts = {}
local claims = {}
local purchases = {}
local victorySound = { IsA = function(_, class)
	return class == "Sound"
end, SoundId = "rbxassetid://424242" }
local workspaceProxy
workspaceProxy = forward(realWorkspace, {
	DescendantAdded = signal(),
	DescendantRemoving = signal(),
	GetServerTimeNow = function()
		return 1000
	end,
	FindFirstChild = function(_, name)
		if name == "winner!" then
			return victorySound
		end
		return realWorkspace:FindFirstChild(name)
	end,
})
local runtime = roblox.Instance.new("Folder")
runtime.Name = "World3ManualStagePads_Runtime"
runtime.Parent = realWorkspace

local replicated = {
	WaitForChild = function(_, name)
		assert(name == "Shared", name)
		return sharedFolder
	end,
	FindFirstChild = function(_, name)
		if name == "Remotes" then
			return { FindFirstChild = function(_, child)
				assert(child == "WinPadFeedback", child)
				return { FireClient = function(_, player, soundId)
					table.insert(feedback, { Player = player, SoundId = soundId })
				end }
			end }
		end
		return nil
	end,
}
local playersFake = { PlayerRemoving = signal(), PlayerAdded = signal(), GetPlayers = function()
	return {}
end }
function playersFake:GetPlayerFromCharacter(character)
	return character.Player
end
local marketplace = {
	PromptProductPurchase = function(_, player, id)
		table.insert(prompts, { Player = player, ProductId = id })
	end,
}
local services = {
	Workspace = workspaceProxy,
	ReplicatedStorage = replicated,
	Players = playersFake,
	MarketplaceService = marketplace,
	ServerScriptService = { WaitForChild = function(_, name)
		return marker(name)
	end },
}
local gameFake = { PlaceId = 0, GetService = function(_, name)
	return assert(services[name], name)
end }

modules.RewardPadClaims = {
	Claim = function(player, pad, reward, stage, isFinal, returnToStart, onGranted)
		table.insert(claims, { Player = player, Pad = pad, Reward = reward, Stage = stage, IsFinal = isFinal, Return = returnToStart })
		local ok, err = pcall(onGranted, reward)
		assert(ok, tostring(err))
		return true
	end,
}
local touchHandlers = {}
modules.PadTouchService = { Connect = function(pad, callback)
	touchHandlers[pad] = callback
end }
modules.DoubleWinsPad = {
	GamePassId = 1941409601,
	IsEntitled = function(player)
		return player.OwnsDoubleWins == true
	end,
	RequestPurchase = function(player, pad)
		table.insert(purchases, { Player = player, Pad = pad })
	end,
	Clear = function() end,
}

local function moduleEnv()
	return datatypes({
		game = gameFake,
		workspace = workspaceProxy,
		require = function(target)
			return assert(modules[target.__module], "module " .. tostring(target.__module))
		end,
		task = { defer = function() end, spawn = function(fn, ...)
			fn(...)
		end, delay = function() end, wait = function() end },
	})
end
modules.World3StageTeleportService = luau.load(fs.readFile(TELEPORT_MODULE), { environment = moduleEnv() })()
local padEnv = moduleEnv()
padEnv.script = { Parent = { WaitForChild = function(_, name)
	return { __module = name }
end } }
local Pads = luau.load(fs.readFile(PAD_SCRIPT), { environment = padEnv })()

local function fakePlayer(name)
	local attributes = { DataLoaded = true }
	local player = { Name = name, UserId = #name }
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:SetAttribute(key, value)
		attributes[key] = value
	end
	local humanoid = { Health = 100 }
	local character = { Player = player, Parent = workspaceProxy }
	function character:IsA(class)
		return class == "Model"
	end
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	local hit = { Parent = character }
	function hit:IsA(class)
		return class == "BasePart"
	end
	player.Hit = hit
	return player
end

local rewards = Config.World3StageWinRewards
local expectedLabels = { [2] = "+750,000 Wins", [3] = "+1,000,000 Wins", [8] = "+5,000,000 Wins", [9] = "+6,500,000 Wins", [10] = "+8,000,000 Wins" }
for stage = 2, 10 do
	local set = Pads.Built.Stages[stage]
	assert(set, "Stage " .. stage .. " pads were not built")
	local markers = modules.World3StageTeleportService.GetStageMarkers(stage)
	for kind, pad in { win = set.Win, x2 = set.X2, skip = set.Skip } do
		assert(pad.Parent == runtime, "Stage " .. stage .. " " .. kind .. " pad must live in the runtime folder")
		local billboard = pad:FindFirstChild("WinRewardBillboard")
		assert(billboard and billboard.MaxDistance >= 110 and billboard.MaxDistance <= 120, "Stage " .. stage .. " " .. kind .. " label must show within 110-120 studs")
		assert(pad:GetAttribute("World3ManualStage") == stage and pad:GetAttribute("World3ManualPad") == true, "pad attributes")
	end
	for _, source in { markers.Win, markers.X2, markers.Skip } do
		assert(source.Transparency == 1 and source.CanTouch == false, "The authored flat part must be hidden: " .. source:GetFullName())
	end
	local winText = set.Win.WinRewardBillboard.RewardText.Text
	assert(set.Win:GetAttribute("WinReward") == rewards[stage], "Stage " .. stage .. " Win pays World3StageWinRewards")
	assert(winText == "+" .. Pads.FormatNumber(rewards[stage]) .. " Wins", "Win label: " .. winText)
	if expectedLabels[stage] then
		assert(winText == expectedLabels[stage], "Stage " .. stage .. " Win label must read " .. expectedLabels[stage] .. ", got " .. winText)
	end
	assert(set.X2:GetAttribute("DoubledWinReward") == rewards[stage] * 2, "x2 pays double")
	assert(set.X2.WinRewardBillboard.RewardText.Text == "x2 Wins\n+" .. Pads.FormatNumber(rewards[stage] * 2) .. " Wins", "x2 label")
	assert(set.Skip.WinRewardBillboard.RewardText.Text == "Skip Stage", "Skip label")
	assert(set.Win.Color ~= set.X2.Color and set.X2.Color ~= set.Skip.Color, "Win, x2 and Skip have their own colours")
end
print("PASS Stages 2-10 each get a Win, x2 and Skip pad with World 3's rewards and World 2's labels")

-- Claims.
local runner = fakePlayer("Runner")
local stage3 = Pads.Built.Stages[3]
assert(touchHandlers[stage3.Win](runner.Hit) == true, "Stepping on a Win pad claims it")
local claim = claims[#claims]
assert(claim.Reward == rewards[3] and claim.Stage == 3 and claim.IsFinal == false, "Win pads claim their stage's reward through RewardPadClaims")
assert(feedback[#feedback].SoundId == "rbxassetid://136993031050456", "Stage pads play the pad sound")

local claimsBefore = #claims
touchHandlers[stage3.X2](runner.Hit)
assert(#claims == claimsBefore and purchases[#purchases].Pad == stage3.X2, "Without the pass, the x2 pad offers it and pays nothing")
runner.OwnsDoubleWins = true
touchHandlers[stage3.X2](runner.Hit)
assert(claims[#claims].Reward == rewards[3] * 2 and claims[#claims].Pad == stage3.X2, "With the pass, the x2 pad claims double")

touchHandlers[Pads.Built.Stages[5].Skip](runner.Hit)
assert(prompts[#prompts].ProductId == Config.SkipStageProductId, "Skip prompts the Skip Stage product")
assert(runner:GetAttribute("PendingSkipStageFrom") == 5 and runner:GetAttribute("PendingSkipStageTarget") == 6
	and runner:GetAttribute("PendingSkipStageWorld") == 3, "Skip on Stage 5 is pending towards Stage 6 in World 3")
touchHandlers[Pads.Built.Stages[8].Skip](fakePlayer("Skipper8").Hit)
assert(prompts[#prompts].Player:GetAttribute("PendingSkipStageTarget") == 9
	and Pads.Built.Stages[8].Skip:GetAttribute("SkipTargetIsFinish") == false, "Skip on Stage 8 now leads to Stage 9")
touchHandlers[Pads.Built.Stages[10].Skip](fakePlayer("Skipper").Hit)
local skipper = prompts[#prompts].Player
assert(skipper:GetAttribute("PendingSkipStageFrom") == 10 and skipper:GetAttribute("PendingSkipStageTarget") == 11
	and Pads.Built.Stages[10].Skip:GetAttribute("SkipTargetIsFinish") == true, "Skip on Stage 10 is pending towards the finish")
print("PASS pads claim through RewardPadClaims, x2 needs the pass, Skip prompts with the right pending stage (10 -> finish)")

-- The finish.
local finish = modules.World3StageTeleportService.GetFinish()
local built = Pads.Built.Finish
assert(built, "The finish must be built")
assert(finish.Checkpoint:GetAttribute("World3FinalWinStage") == true, "The finish block is marked World3FinalWinStage")
assert(built.Win:GetAttribute("WinReward") == 10000000 and built.Win.WinRewardBillboard.RewardText.Text == "+10,000,000 Wins", "The finish Win pays 10M")
assert(built.X2:GetAttribute("DoubledWinReward") == 20000000 and built.X2.WinRewardBillboard.RewardText.Text == "x2 Wins\n+20,000,000 Wins", "The finish x2 pays 20M")
assert(built.Win.Size.X > Pads.Built.Stages[2].Win.Size.X, "The finish pads are bigger")
for _, pad in { built.Win, built.X2 } do
	assert(pad:FindFirstChild("FinishConfetti") and pad.FinishConfetti:IsA("ParticleEmitter"), "The finish pads burst confetti")
end
assert(finish.End and finish.Skip == nil, "There is nothing to skip at the finish (the End has no Skip marker)")
-- The End's markers are sunk into its floor: the pads stand on the floor, over the markers.
local floorTop = finish.Checkpoint.CFrame.Position.Y + finish.Checkpoint.Size.Y / 2
for pad, marker in { [built.Win] = finish.Win, [built.X2] = finish.X2 } do
	assert(math.abs(pad.CFrame.Position.Y - (floorTop + pad.Size.Y / 2)) < 0.01, "The finish pads stand on the End's floor")
	assert(Vector3.new(pad.CFrame.Position.X - marker.CFrame.Position.X, 0, pad.CFrame.Position.Z - marker.CFrame.Position.Z).Magnitude < 0.01, "...over their markers")
	assert(marker.Transparency == 1 and marker.CanTouch == false, "The End's markers are hidden")
end
local toFinish = finish.Checkpoint.CFrame.Position - modules.World3StageTeleportService.GetStageReferencePosition(10)
toFinish = Vector3.new(toFinish.X, 0, toFinish.Z).Unit
assert(built.Sign.CFrame.LookVector:Dot(toFinish) > 0.99 and built.Sign.FinishText.Face == roblox.Enum.NormalId.Back
	and built.Sign.FinishText.Finish.Text == "FINISH", "The FINISH sign faces the runners coming from Stage 10")
local finisher = fakePlayer("Finisher")
finisher.OwnsDoubleWins = true
touchHandlers[built.X2](finisher.Hit)
local final = claims[#claims]
assert(final.IsFinal == true and final.Stage == 10 and final.Reward == 20000000, "The finish x2 claims 20M as the final pad")
assert(feedback[#feedback].Player == finisher and feedback[#feedback].SoundId == "rbxassetid://424242", "The finish plays the place's victory sound")
assert(finisher:GetAttribute("World3FinalWinStageClaimed") == true, "Finishing is recorded")
print("PASS the finish (10M / 20M) is built on the End's floor with confetti, victory sound and a FINISH sign")

-- 2. Treadmill signs --------------------------------------------------------
local signEnv = datatypes({
	game = { GetService = function(_, name)
		if name == "Workspace" then
			return realWorkspace
		elseif name == "ReplicatedStorage" then
			return replicated
		elseif name == "MarketplaceService" then
			return { GetProductInfo = function(_, id)
				return { PriceInRobux = id % 1000 }
			end }
		end
		error(name)
	end },
	require = function(target)
		return modules[target.__module]
	end,
	task = { spawn = function(fn, ...)
		fn(...)
	end, wait = function() end },
})
local Signs = luau.load(fs.readFile(SIGN_SCRIPT), { environment = signEnv })()
local spawnAt = realWorkspace.Lobby.SpawnLocation.CFrame.Position
for name, profile in Config.World3TreadmillProfiles do
	if name ~= "Admin3000" then
		local sign = Signs.Signs[name]
		assert(sign, "No sign over " .. name)
		local front = sign:FindFirstChildOfClass("SurfaceGui")
		assert(front.Steps.Text == profile.DisplayText, name .. " sign must show " .. profile.DisplayText)
		local row = front:FindFirstChild("RequirementRow")
		local requirement = row and row.Requirement.Text
		if not profile.GamePassId and not profile.RequiredRebirths then
			assert(row == nil and profile.StarterOnly, name .. " is the starter: its sign has no requirement")
		elseif profile.GamePassId then
			assert(requirement == tostring(profile.GamePassId % 1000), name .. " sign must show the pass's live price, got " .. requirement)
		else
			assert(requirement == profile.RequiredRebirths .. " Rebirths\nRequired", name .. " sign must show its Rebirths")
		end
		local toSpawn = Vector3.new(spawnAt.X - sign.CFrame.Position.X, 0, spawnAt.Z - sign.CFrame.Position.Z).Unit
		assert(sign.CFrame.LookVector:Dot(toSpawn) > 0.99, name .. " sign must face the spawn")
		local belt = realWorkspace.Lobby[name]:FindFirstChild("Treadmil", true)
		local beltTop = -math.huge
		for _, part in belt:GetDescendants() do
			if part:IsA("BasePart") then
				beltTop = math.max(beltTop, part.CFrame.Position.Y + part.Size.Y / 2)
			end
		end
		assert(sign.CFrame.Position.Y - sign.Size.Y / 2 > beltTop, name .. " sign must hang above its belt")
	end
end
assert(Signs.Signs.Diamond:FindFirstChildOfClass("SurfaceGui").Steps.Text == "x20 Speed"
	and Signs.Signs.Diamond:FindFirstChildOfClass("SurfaceGui").RequirementRow.Requirement.Text == "12 Rebirths\nRequired", "Diamond: x20, 12 Rebirths")
print("PASS the four lobby treadmills show World 3's multiplier and requirement (Diamond x20 / 12 Rebirths, passes with live price), facing the spawn")

-- 3. Portal -----------------------------------------------------------------
local function portalRun(world, places, configOverrides)
	local now = 1000
	local states, teleports, commits = {}, {}, {}
	local overrides = { IsWorld2Place = world == 2, IsWorld3Place = world == 3 }
	if configOverrides then
		for k, v in pairs(configOverrides) do
			overrides[k] = v
		end
	end
	local worldConfig = setmetatable(overrides, { __index = Config })
	local portalAction, portalPart = signal(), nil
	local portalWorkspace = { DescendantAdded = signal() }
	portalPart = { Name = "PortalWorld2", Parent = portalWorkspace, Size = Vector3.new(4, 20, 12), Position = Vector3.zero, Touched = signal() }
	function portalPart:IsA(class)
		return class == "BasePart"
	end
	function portalWorkspace:GetDescendants()
		return { portalPart }
	end
	local playersList = { PlayerRemoving = signal() }
	function playersList:GetPlayerFromCharacter(character)
		return character.Player
	end
	local dataService = {
		GetHandle = function()
			return {}
		end,
		Commit = function(_, request)
			table.insert(commits, request)
			return { kind = "Committed" }
		end,
	}
	local env = datatypes({
		os = { clock = function()
			return now
		end, time = os.time },
		task = { spawn = function(fn, ...)
			fn(...)
		end, delay = function() end, wait = function() end },
		require = function(target)
			if target == dataService.__marker then
				return dataService
			end
			return ({ Config = worldConfig, AdminBannerConfig = { IsAdmin = function()
				return false
			end } })[target.__module]
		end,
		Instance = { new = function()
			return { SetTeleportData = function() end }
		end },
	})
	dataService.__marker = { __module = "DataService" }
	env._G.SpeedsterSavePlayer = function()
		return true
	end
	env.game = {
		PlaceId = 0,
		CreatorType = roblox.Enum.CreatorType.User,
		CreatorId = 1,
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return { WaitForChild = function(_, child)
					if child == "Shared" then
						return sharedFolder
					elseif child == "AdminBannerConfig" then
						return { __module = "AdminBannerConfig" }
					end
					return { WaitForChild = function(_, remote)
						if remote == "WorldPortalAction" then
							return { OnServerEvent = portalAction }
						end
						return { FireClient = function(_, player, state)
							table.insert(states, state)
						end }
					end }
				end }
			elseif name == "Workspace" then
				return portalWorkspace
			elseif name == "Players" then
				return playersList
			elseif name == "RunService" then
				return { IsStudio = function()
					return false
				end }
			elseif name == "AssetService" then
				return { GetGamePlacesAsync = function()
					return { IsFinished = true, GetCurrentPage = function()
						return places
					end }
				end }
			elseif name == "TeleportService" then
				return {
					TeleportInitFailed = signal(),
					TeleportAsync = function(_, placeId)
						table.insert(teleports, placeId)
					end,
				}
			elseif name == "ServerScriptService" then
				return { Services = { Data = { DataService = dataService.__marker } } }
			end
			error(name)
		end,
	}
	luau.load(fs.readFile(PORTAL_SCRIPT), { environment = env })()

	local function player(rebirths, level, attributes)
		attributes = attributes or {}
		attributes.DataLoaded = true
		attributes.Level = level
		local p = { Name = "P" .. rebirths, UserId = 5000 + rebirths, Parent = playersList }
		function p:GetAttribute(key)
			return attributes[key]
		end
		function p:SetAttribute(key, value)
			attributes[key] = value
		end
		function p:FindFirstChild(name)
			if name == "leaderstats" then
				return { FindFirstChild = function(_, stat)
					return if stat == "Rebirths" then { Value = rebirths } else nil
				end }
			end
			return nil
		end
		local character = { Player = p }
		function character:IsA(class)
			return class == "Model"
		end
		function character:FindFirstChildOfClass()
			return { Health = 100 }
		end
		p.Hit = { Parent = character, IsA = function(_, class)
			return class == "BasePart"
		end }
		return p
	end
	return {
		States = states,
		Teleports = teleports,
		Commits = commits,
		Player = player,
		Touch = function(p)
			portalPart.Touched:Fire(p.Hit)
		end,
		Travel = function(p, destination)
			now += 5
			portalAction:Fire(p, "Travel", destination)
		end,
		Advance = function(seconds)
			now += seconds
		end,
	}
end

-- From World 2.
local places = {}
local fromWorld2 = portalRun(2, places, { World3PlaceId = false })
local almost = fromWorld2.Player(14, 250)
fromWorld2.Touch(almost)
fromWorld2.Travel(almost, 3)
local last = fromWorld2.States[#fromWorld2.States]
assert(last.Status == "Locked" and last.Message == "Need 1 more Rebirths", "14 Rebirths must not open World 3: " .. tostring(last.Message))
local lowLevel = fromWorld2.Player(20, 199)
fromWorld2.Touch(lowLevel)
fromWorld2.Travel(lowLevel, 3)
last = fromWorld2.States[#fromWorld2.States]
assert(last.Status == "Locked" and last.Message == "Need 1 more Levels", "Level 199 must not open World 3")
assert(#fromWorld2.Teleports == 0, "Nobody travels without the requirements")

local ready = fromWorld2.Player(15, 200)
fromWorld2.Touch(ready)
fromWorld2.Travel(ready, 3)
last = fromWorld2.States[#fromWorld2.States]
assert(last.Status == "ComingSoon" and #fromWorld2.Teleports == 0, "Without a World 3 place the portal says it is coming soon")
local unlock = fromWorld2.Commits[#fromWorld2.Commits]
assert(unlock and unlock.commands[1].key == "World3Unlocked" and unlock.commands[1].value == true, "Meeting 15 Rebirths + Level 200 saves World3Unlocked")
table.insert(places, { PlaceId = 777, Name = "World 3" })
fromWorld2.Advance(61)
fromWorld2.Touch(ready)
fromWorld2.Travel(ready, 3)
assert(fromWorld2.Teleports[#fromWorld2.Teleports] == 777, "Once the World 3 place exists, the portal takes the player there")
assert(fromWorld2.States[1].World3RequiredRebirths == 15 and fromWorld2.States[1].World3RequiredLevel == 200, "The menu is told the World 3 requirements")

local fromWorld2Configured = portalRun(2, {})
fromWorld2Configured.Touch(ready)
fromWorld2Configured.Travel(ready, 3)
assert(fromWorld2Configured.Teleports[#fromWorld2Configured.Teleports] == (tonumber(Config.World3PlaceId) or 94956471703437), "Configured World 3 place teleports directly")

-- Admins (e.g. Gekkoh UserId 767108248) can travel without meeting rebirth/level requirements:
local adminPlayer = fromWorld2Configured.Player(0, 1)
adminPlayer.UserId = 767108248
fromWorld2Configured.Travel(adminPlayer, 3)
assert(fromWorld2Configured.Teleports[#fromWorld2Configured.Teleports] == (tonumber(Config.World3PlaceId) or 94956471703437), "Admins travel to World 3 without rebirths or level requirements")
assert(adminPlayer:GetAttribute("World3Unlocked") == true, "Admin traveling to World 3 gets World3Unlocked set")

-- From World 3: back to World 2 or World 1, no requirements, no portal touch needed.
local fromWorld3 = portalRun(3, {})
local newcomer = fromWorld3.Player(0, 5, { World2Unlocked = false })
fromWorld3.Travel(newcomer, 2)
assert(fromWorld3.Teleports[#fromWorld3.Teleports] == (Config.World2PlaceId or 96501592055150), "World 3 -> World 2 is always open")
-- (newcomer is now mid-teleport; another player goes to World 1)
local returning = fromWorld3.Player(1, 3, { World2Unlocked = false })
fromWorld3.Travel(returning, 1)
assert(fromWorld3.Teleports[#fromWorld3.Teleports] == (Config.World1PlaceId or 138540610580146), "World 3 -> World 1 is always open")
local stayer = fromWorld3.Player(2, 9)
fromWorld3.Touch(stayer)
fromWorld3.Travel(stayer, 3)
assert(fromWorld3.States[#fromWorld3.States].Status == "Current", "World 3 knows it is World 3")
print("PASS World 2 -> World 3 needs 15 Rebirths + Level 200 and saves World3Unlocked; World 3 -> World 2 / 1 is always open")

-- 4. Saving and the shared scripts ---------------------------------------------
local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
local profile = Codec.CreateDefault()
assert(profile.World3Unlocked == false, "New profiles start with World 3 locked")
local applied = Reducers.ApplyCommand(profile, { kind = "SetPersistent", key = "World3Unlocked", value = true }, 1000)
assert(applied.ok and profile.World3Unlocked == true, "SetPersistent World3Unlocked must be accepted")
local encoded = Codec.Encode(profile)
assert(encoded.World3Unlocked == true, "World3Unlocked must be written to the save")
local decoded = Codec.Decode(encoded)
local decodedProfile = decoded.value or decoded.profile or decoded
assert(decodedProfile.World3Unlocked == true, "World3Unlocked must load back")
for file, needle in {
	["src/common/ServerScriptService/Services/Stats/StatsProjection.luau"] = 'player:SetAttribute("World3Unlocked", profile.World3Unlocked == true)',
	["src/common/ServerScriptService/Progression/PlayerStatsBridge.luau"] = '{"FirstTimeTutorialSeen","World2Unlocked","World3Unlocked"}',
	["src/common/ServerScriptService/Progression/TreadmillTraining.server.luau"] = "elseif Config.IsWorld3Place == true then Config.World3TreadmillProfiles",
	["src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau"] = "teleported, reason = StageTeleportService.TeleportSkipPurchase(player, fromStage)",
	["src/common/StarterPlayer/StarterPlayerScripts/UI/WorldsController.client.luau"] = 'WorldPortalAction:FireServer("Travel", 3)',
} do
	assert(string.find(fs.readFile(file), needle, 1, true), file .. " must contain: " .. needle)
end
print("PASS World3Unlocked saves and loads; treadmill locks, the last stage's skip and the Worlds menu know World 3")
