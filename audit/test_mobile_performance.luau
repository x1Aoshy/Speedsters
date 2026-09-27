-- test_mobile_performance.luau
-- Most players are on phones and tablets (about 82%, around 860 MB and 36 FPS). This pins
-- what keeps the game light there: no remote fired every frame, player state replicated at
-- 10 Hz or less, other players' cosmetics thinned out by distance, and the heavy local
-- effects (afterimages, the disco floor) lighter on touch devices.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- 1. No remote fires every frame
----------------------------------------------------------------------
do
	-- Every remote fired inside a per-frame callback, found by walking the sources. Each of
	-- these was reviewed and fires on a state change or behind a cooldown; anything new
	-- that fires every frame fails here until it is reviewed too.
	local REVIEWED = {
		["src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"] = "the local death watchdog, once per death",
		["src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RedBallContact.client.luau"] = "a hit report behind REPORT_COOLDOWN",
		["src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau"] = "the Esc reset, once per press",
		["src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau"] = "the boss's kill, once per catch",
	}
	local function walk(path, out)
		for _, name in fs.readDir(path) do
			local full = path .. "/" .. name
			if fs.isDir(full) then
				walk(full, out)
			elseif string.sub(name, -5) == ".luau" then
				table.insert(out, full)
			end
		end
		return out
	end
	local found = {}
	for _, file in walk("src", {}) do
		local lines = string.split(fs.readFile(file), "\n")
		local index = 1
		while index <= #lines do
			local line = lines[index]
			if string.find(line, "RenderStepped:Connect(", 1, true) or string.find(line, "Heartbeat:Connect(", 1, true)
				or string.find(line, "Stepped:Connect(", 1, true) or string.find(line, "BindToRenderStep(", 1, true)
			then
				local indent = #(string.match(line, "^[\t ]*"))
				local stop = index + 1
				while stop <= #lines do
					local body = lines[stop]
					if string.match(body, "^[\t ]*end%)") and #(string.match(body, "^[\t ]*")) <= indent then
						break
					end
					if string.find(body, ":FireServer(", 1, true) or string.find(body, ":FireClient(", 1, true) or string.find(body, ":FireAllClients(", 1, true) then
						found[file] = true
					end
					stop += 1
				end
				index = stop
			end
			index += 1
		end
	end
	for file in found do
		assert(REVIEWED[file], file .. " fires a remote inside a per-frame callback: make it event-driven or throttled (5-10 Hz), then list it here")
	end
	print("PASS remotes: nothing fires a remote every frame (" .. #(function() local n = {} for f in found do table.insert(n, f) end return n end)() .. " guarded per-frame reports reviewed)")
end

----------------------------------------------------------------------
-- 2. Player state replicates at 10 Hz or less
----------------------------------------------------------------------
do
	local bootstrap = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
	local interval = tonumber(string.match(bootstrap, "local STAMINA_PUBLICATION_INTERVAL = ([%d%.]+)"))
	assert(interval and interval >= 0.1, "Stamina attributes are published at 10 Hz at most (" .. tostring(interval) .. " s)")
	has(bootstrap, "if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end", "...and only when they change")
	local config = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
	local tick = tonumber(string.match(config, "Config%.TrainingTickSeconds = ([%d%.]+)"))
	assert(tick and tick >= 0.1, "Running Speed is added at 10 Hz at most (" .. tostring(tick) .. " s)")
	local purchases = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	has(purchases, "task.wait(0.15)\n\tend\nend)\n\nprint(\"[SpeedProductPurchases]", "The safe-zone tracker runs at about 7 Hz")
	has(purchases, 'if player:GetAttribute("CurrentSafeZoneStage") ~= currentStage then', "...and writes only on change")
	local cosmetics = fs.readFile("src/common/ServerScriptService/Economy/Cosmetics/CosmeticService.luau")
	has(cosmetics, 'if slot:GetAttribute("EffectsReady") ~= true then\n\t\tenableEffects(slot)', "The cosmetic watchdog switches effects on once per slot, not every tick")
	print("PASS replication: stamina at 4 Hz on change, Speed at 2 Hz, the safe zone at 7 Hz, cosmetics enabled once")
end

----------------------------------------------------------------------
-- 3. Other players' cosmetics thin out with distance (this client only)
----------------------------------------------------------------------
do
	local source = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/AuraSpecialEffectsClient.client.luau")
	-- Lune's parts have no .Position; the same point through CFrame.
	local chunk = string.gsub(between(source, "local LOD = {", "local lodClock = 0"), "root%.Position", "root.CFrame.Position")
	local me, other = {}, {}
	local function dressed(rootPosition)
		local character = rb.Instance.new("Model")
		local root = rb.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = rb.CFrame.new(rootPosition)
		root.Parent = character
		local cosmetics = rb.Instance.new("Folder")
		cosmetics.Name = "SpeedsterCosmetics"
		cosmetics.Parent = character
		local holder = rb.Instance.new("Part")
		holder.Parent = cosmetics
		local emitter = rb.Instance.new("ParticleEmitter")
		emitter.Rate = 20
		emitter.Parent = holder
		local trail = rb.Instance.new("Trail")
		trail.Enabled = true
		trail.Parent = holder
		return character, emitter, trail
	end
	local myCharacter, myEmitter = dressed(rb.Vector3.new(0, 0, 0))
	local theirCharacter, theirEmitter, theirTrail = dressed(rb.Vector3.new(0, 0, 0))
	me.Character, other.Character = myCharacter, theirCharacter
	local env = setmetatable({
		Players = { GetPlayers = function() return { me, other } end },
		localPlayer = me,
	}, { __index = _G })
	local updateLod = luau.load(chunk .. "\nreturn updateLod", { environment = env })()
	local now = 0
	local function at(distance)
		theirCharacter.HumanoidRootPart.CFrame = rb.CFrame.new(distance, 0, 0)
		now += 0.25
		updateLod(rb.Vector3.new(0, 0, 0), now)
	end
	at(50)
	assert(theirEmitter.Rate == 20 and theirTrail.Enabled, "Near (50 studs): full")
	at(100)
	assert(math.abs(theirEmitter.Rate - 6) < 1e-6 and theirTrail.Enabled, "Past 75 studs: 30% of the particles")
	at(200)
	assert(theirEmitter.Rate == 0 and not theirTrail.Enabled, "Past 150 studs: no particles, no trail")
	at(60)
	assert(theirEmitter.Rate == 20 and theirTrail.Enabled, "Back near: all of it again, at its own rate")
	assert(myEmitter.Rate == 20, "The player's own cosmetics are never thinned")
	-- A new emitter (a re-equip) is picked up at its own rate.
	at(100)
	local fresh = rb.Instance.new("ParticleEmitter")
	fresh.Rate = 40
	fresh.Parent = theirCharacter.SpeedsterCosmetics
	now += 2
	updateLod(rb.Vector3.new(0, 0, 0), now)
	assert(math.abs(fresh.Rate - 12) < 1e-6, "A re-equipped cosmetic is thinned too, from its own rate")
	has(source, "LOD.Interval", "Distances are checked a few times a second, not every frame")
	print("PASS LOD: other players' auras and trails at full rate within 75 studs, 30% to 150, none beyond; your own always full")
end

----------------------------------------------------------------------
-- 4. The heavy local effects are lighter on phones, and never outlive the character
----------------------------------------------------------------------
do
	local run = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau")
	has(run, "local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled", "Touch devices are told apart")
	has(run, "if LOW_POWER then\n\tMAX_AFTERIMAGES = 3", "Phones keep 3 afterimages, not 5")
	has(run, "local sources = if LOW_POWER then character:GetChildren() else character:GetDescendants()", "...copies of the body alone")
	has(run, "if not LOW_POWER then\n\t\tlocal silhouette = Instance.new(\"Highlight\")", "...and no Highlight per ghost")
	has(run, "character.AncestryChanged:Connect(function()\n\tif not character:IsDescendantOf(Workspace) and afterimageFolder.Parent then", "The afterimages go with the character, however it goes")
	local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	has(effects, "LowPowerColourSeconds = 1 / 12,", "The disco floor repaints 12 times a second on phones")
	has(effects, "FarColourSeconds = 0.5,", "...and twice a second when the camera is far from it")
	print("PASS local effects: fewer, lighter afterimages and a slower disco floor on phones; nothing left in the world after a respawn")
end
