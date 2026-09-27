-- test_afk_zone.luau
-- AFK Mode (2026-09-18, Sung's request; it replaced the AFK Zone circle). Runs the real
-- service (Social/AfkZoneService) second by second:
--   * Go AFK! sets the character down on its slot of the lobby's AFK spot and publishes
--     AfkModeActive. 2026-09-26 (owner): STANDING: never anchored, never seated (a seated
--     player is unseated), feet on the floor under the slot (the rig's standing height, or the
--     one measured under a standing character, + 0.25 to settle), velocity cleared;
--   * 2026-09-26 (owner): MOVING ENDS IT: movement input (Humanoid.MoveDirection), a jump, a
--     run (horizontal speed) or leaving the small radius end AFK Mode at once; what the stint
--     earned is claimed x1 exactly as Exit AFK claims it, nothing more accrues, and a claim
--     that does not land is retried (same operation) until it does; settling onto the feet,
--     a small drift or standing still does not end it;
--   * Speed every minute (0.5% of the player's Speed, x5 with VIP) and a Spin Ticket every
--     ten minutes, paid straight into their data, while AFK Mode is on and only then;
--   * a reset puts the new character back on the spot; a rejoin with AfkModeResume starts
--     in AFK Mode; players outside the preview cannot turn it on.
-- Then the client side: no circle in the lobby any more, the AFK MODE line, the idle-kick
-- answer (VirtualUser in a pcall, else a rejoin with AfkModeResume), the Earnings panel's
-- Go AFK! / Exit AFK, and (2026-09-26) movement input asking ExitAfk at once (no "Are you
-- sure you want to exit AFK?" / "Stay in AFK" prompt any more).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local source = fs.readFile("src/common/ServerScriptService/Social/AfkZoneService.server.luau")
local V3 = roblox.Vector3

local function has(text, needle, message)
	assert(string.find(text, needle, 1, true), message)
end

local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
	}
end

local function run(options)
	options = options or {}
	local center = V3.new(100, 50, -20)
	-- 2026-09-26: the floor the service's raycasts see (options.floorY: a flat floor at that
	-- height; nil: no Workspace:Raycast, as before).
	local floorY = options.floorY
	local function makeCharacter()
		local rootPart = { Position = options.startAt or (center + V3.new(300, 40, 0)), Size = V3.new(2, 2, 1),
			Anchored = options.anchored == true, AssemblyLinearVelocity = V3.zero, AssemblyAngularVelocity = V3.zero }
		function rootPart:IsA(class)
			return class == "BasePart"
		end
		local humanoid = { Health = 100, HipHeight = options.hipHeight or 2, RigType = options.rigType or roblox.Enum.HumanoidRigType.R15,
			MoveDirection = V3.zero, Jump = false, Sit = false, SeatPart = nil, FloorMaterial = options.floorMaterial or roblox.Enum.Material.Air }
		if options.seated then
			local weld = { Destroyed = false }
			function weld:Destroy()
				self.Destroyed = true
			end
			humanoid.Sit = true
			humanoid.SeatPart = { Weld = weld, FindFirstChild = function(self, name)
				return if name == "SeatWeld" and not weld.Destroyed then weld else nil
			end }
		end
		local character = {
			Root = rootPart,
			Humanoid = humanoid,
			FindFirstChild = function(_, name)
				return if name == "HumanoidRootPart" then rootPart else nil
			end,
			FindFirstChildOfClass = function(_, class)
				return if class == "Humanoid" then humanoid else nil
			end,
		}
		function character:PivotTo(frame)
			assert(not rootPart.Anchored, "The root is let go before it is moved")
			assert(not humanoid.Sit, "Out of any seat before it is moved")
			rootPart.Position = frame.Position
			rootPart.CFrame = frame
			rootPart.AssemblyLinearVelocity = V3.new(0, -30, 0) -- whatever it had: the service clears it
		end
		return character
	end
	local attributes = { DataLoaded = true, VIPGamepassOwned = options.vip == true }
	local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	local characterAdded = signal()
	local player = {
		UserId = 42,
		Name = "Idler",
		Parent = Players,
		Character = makeCharacter(),
		CharacterAdded = characterAdded,
		GetAttribute = function(_, name)
			return attributes[name]
		end,
		SetAttribute = function(_, name, value)
			attributes[name] = value
		end,
		GetJoinData = function()
			return { TeleportData = options.teleportData }
		end,
	}
	-- The player joins once the service is running (PlayerAdded), not before.
	local present = {}
	function Players:GetPlayers()
		return present
	end

	local commits = {}
	local operation = 0
	local rebased = 0
	local request = { OnServerEvent = signal() }
	local modules = {
		Config = {
			IsNewWorld1Map = true,
			AfkZone = {
				Enabled = true,
				RewardIntervalSeconds = 60,
				SpeedShare = 0.005,
				SpeedFloor = 500,
				VipSpeedMultiplier = 5,
				TicketIntervalSeconds = 600,
				SpotRadius = 12,
				WorldPlacement = { World1 = center },
			},
		},
		FeatureGate = { IsPreviewPlayer = function()
			return options.previewed ~= false
		end },
		DataService = {
			GetHandle = function()
				return {}
			end,
			Inspect = function()
				return { ok = true, value = { profile = { Speed = 2000000 } } }
			end,
			Commit = function(_, commit)
				table.insert(commits, commit)
				if options.onCommit then return options.onCommit(commit) end
				return { kind = "Committed" }
			end,
			NewOperationId = function()
				operation += 1
				return "op" .. operation
			end,
		},
		ServerRateLimiter = { Allow = function()
			return true
		end },
	}
	local function node(name)
		return {
			Name = name,
			WaitForChild = function(_, child)
				return node(child)
			end,
			FindFirstChild = function(_, child)
				return if child == "AfkRewardsRequest" then request else nil
			end,
		}
	end
	local services = {
		Players = Players,
		ReplicatedStorage = node("ReplicatedStorage"),
		ServerScriptService = node("ServerScriptService"),
		Workspace = {
			GetServerTimeNow = function()
				return 7000
			end,
			-- 2026-09-26: only with options.floorY (else, as a live Workspace:Raycast failing, the pcall falls back).
			Raycast = if floorY
				then function(_, origin, direction)
					if origin.Y >= floorY and origin.Y + direction.Y <= floorY then
						return { Position = V3.new(origin.X, floorY, origin.Z), Normal = V3.new(0, 1, 0) }
					end
					return nil
				end
				else nil,
		},
	}

	local mainLoop = nil
	local loaded = false
	local elapsed = 0
	local stopAt = 0
	local delayed = {}
	local globals = { VortexMovementGuardRebase = function()
		rebased += 1
	end }
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], name)
		end },
		require = function(object)
			return assert(modules[object.Name], object.Name)
		end,
		Vector3 = V3,
		CFrame = roblox.CFrame,
		Enum = roblox.Enum,
		RaycastParams = { new = function()
			return {}
		end },
		Instance = { new = function()
			error("the remote already exists")
		end },
		_G = globals,
		warn = function() end,
		print = function() end,
		task = {
			spawn = function(fn, ...)
				if not loaded then
					mainLoop = fn
				else
					fn(...)
				end
			end,
			delay = function(_, fn)
				table.insert(delayed, fn)
			end,
			wait = function()
				elapsed += 1
				if elapsed > stopAt then
					error("stop")
				end
			end,
		},
	}, { __index = _G })
	luau.load(source, { environment = env })()
	loaded = true
	assert(mainLoop, "The service must run a once-a-second loop")
	present = { player }
	Players.PlayerAdded:Fire(player)

	local function advance(seconds)
		stopAt = elapsed + seconds
		local ok, err = pcall(mainLoop)
		assert(not ok and string.find(tostring(err), "stop"), "Loop failed: " .. tostring(err))
	end

	return {
		center = center,
		player = player,
		advance = advance,
		commits = commits,
		attributes = attributes,
		globals = globals,
		rebased = function()
			return rebased
		end,
		send = function(payload)
			request.OnServerEvent:Fire(player, payload)
		end,
		respawn = function()
			player.Character = makeCharacter()
			characterAdded:Fire(player.Character)
			for _, fn in delayed do
				fn()
			end
			table.clear(delayed)
		end,
	}
end

local function tally(commits)
	local speed, tickets, amounts, totalSpeed = 0, 0, {}, 0
	for _, request in commits do
		for _, command in request.commands do
			if command.kind == "GrantExact" and command.stat == "Speed" then
				speed += 1
				totalSpeed += command.amount
				amounts[command.amount] = true
			elseif command.kind == "GrantSpinTickets" then
				tickets += command.amount
			end
		end
	end
	return speed, tickets, amounts, totalSpeed
end

do
	local afk = run()
	afk.advance(120)
	assert(#afk.commits == 0 and afk.attributes.AfkModeActive == false, "Nothing until AFK Mode is turned on")
	afk.send({ action = "EnterAfk" })
	assert(afk.attributes.AfkModeActive == true and afk.attributes.AfkModeSince == 7000, "Go AFK! turns it on")
	local root = afk.player.Character.Root
	local offset = root.Position - afk.center
	local flat = V3.new(offset.X, 0, offset.Z).Magnitude
	-- 2026-09-26 (owner): standing, never anchored or seated; feet on the floor (an R15 rig's
	-- HipHeight 2 + half its 2-stud root = 3 over the floor, + 0.25 to settle onto its feet).
	assert(root.Anchored == false, "The character is never anchored (it stands on its own)")
	assert(afk.player.Character.Humanoid.Sit == false, "...never seated")
	assert(flat > 1 and flat <= 12 and math.abs(offset.Y - 3.25) < 1e-4, "...on the lobby's AFK spot, feet on its floor (" .. flat .. " studs out, root " .. offset.Y .. " over it)")
	assert(root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0, "...set down still")
	local look = root.CFrame.LookVector
	assert(look:Dot(V3.new(-offset.X, 0, -offset.Z).Unit) > 0.99, "...facing the middle of the spot")
	assert(afk.rebased() == 1, "The move is sanctioned for the anti-teleport check")

	afk.advance(59)
	assert(#afk.commits == 0 and afk.attributes.AfkModeRewardIn == 1, "Nothing before the first full minute; the countdown is published")
	assert(afk.attributes.AfkModeNextSpeed == 10000, "The panel is told what the next Speed payment is")
	afk.advance(1)
	assert(afk.attributes.AfkModeSpeed == 10000, "...and the panel shows what it has paid")
	assert(afk.attributes.AfkHasUnclaimed == true, "Rewards accumulate as unclaimed")
	assert(#afk.commits == 0, "Rewards are not automatically committed until claimed")
	afk.send({ action = "ClaimAfkZone" })
	local speed, _, amounts, totalSpeed = tally(afk.commits)
	assert(totalSpeed == 10000 and amounts[10000], "A minute in AFK Mode pays 0.5% of the player's Speed upon claim")
	assert(afk.attributes.AfkModeSpeed == 0 and afk.attributes.AfkHasUnclaimed == false, "Claim resets unclaimed counters")

	afk.advance(540)
	assert(afk.attributes.AfkModeTickets == 1 and afk.attributes.AfkModeSpeed == 90000, "Ten minutes accumulates Speed and Spin Ticket")
	afk.send({ action = "ClaimAfkZone" })
	local _, tickets10, _, totalSpeed10 = tally(afk.commits)
	assert(totalSpeed10 == 100000 and tickets10 == 1 and afk.attributes.AfkModeTickets == 0, "Ten minutes: 100,000 Speed (10 payments) and a Spin Ticket")

	afk.respawn()
	local newRoot = afk.player.Character.Root
	assert(newRoot.Anchored == false and (newRoot.Position - root.Position).Magnitude < 1e-3, "A reset puts the new character back on the spot, standing")
	afk.advance(3)
	assert(afk.attributes.AfkModeActive == true, "...and it is still AFK there")

	afk.send({ action = "ExitAfk" })
	assert(afk.attributes.AfkModeActive == false and afk.attributes.AfkModeRewardIn == nil, "Exit AFK turns it off")
	assert(afk.player.Character.Root.Anchored == false, "...and the character was never held")
	afk.advance(1200)
	local _, ticketsAfter, _, totalSpeedAfter = tally(afk.commits)
	assert(totalSpeedAfter == 100000 and ticketsAfter == 1, "Nothing more is paid once it is off")
	print("PASS AFK Mode: Go AFK! sets the character down standing (never anchored or seated, feet on the floor) on the lobby spot; Speed every minute and a Spin every ten, accumulated and claimed; a reset goes back; Exit AFK stops it")
end

do
	local vip = run({ vip = true })
	vip.send({ action = "EnterAfk" })
	vip.advance(60)
	vip.send({ action = "ClaimAfkZone" })
	local _, _, amounts = tally(vip.commits)
	assert(amounts[50000], "VIP: AFK Mode pays x5")
	print("PASS AFK Mode: x5 with VIP")
end

do
	local back = run({ teleportData = { AfkModeResume = true } })
	assert(back.attributes.AfkModeActive == true, "A rejoin with AfkModeResume starts in AFK Mode")
	local other = run({ teleportData = { AfkModeResume = "yes" } })
	assert(other.attributes.AfkModeActive == false, "...only with exactly that")
	print("PASS AFK Mode: the idle-kick rejoin comes back in AFK Mode")
end

do
	local outsider = run({ previewed = false })
	outsider.send({ action = "EnterAfk" })
	outsider.advance(1200)
	assert(#outsider.commits == 0 and outsider.attributes.AfkModeActive == false, "Players outside the preview cannot turn it on")
	print("PASS AFK Mode: inert for players outside the preview")
end

----------------------------------------------------------------------
-- The client
----------------------------------------------------------------------
do
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkZoneController.client.luau")
	assert(not string.find(controller, "Cylinder", 1, true) and not string.find(controller, '"Ring"', 1, true), "No circle in the lobby any more")
	has(controller, 'player:GetAttribute("AfkModeActive") == true', "The AFK MODE line follows AFK Mode")
	has(controller, "player.Idled:Connect(function(idleSeconds)", "It answers Roblox's idle warning")
	has(controller, "VirtualUser:CaptureController()\n\t\tVirtualUser:ClickButton2(Vector2.new())", "...with VirtualUser")
	has(controller, "local ok = pcall(function()\n\t\tlocal VirtualUser", "...in a pcall (a game script is usually refused)")
	has(controller, "TeleportService:Teleport(game.PlaceId, player, { AfkModeResume = true })", "...else a rejoin that turns AFK Mode back on")
	local rejoinAfter = tonumber(string.match(controller, "local REJOIN_AFTER_IDLE_SECONDS = (%d+) %* 60"))
	assert(rejoinAfter and rejoinAfter < 20, "The rejoin comes before the 20-minute kick")
	has(controller, 'MenuEvents.Get("OpenAfkPanel"):Fire("Open")', "Tapping the line opens the panel again")
	-- 2026-09-26 (owner): movement input ends AFK Mode at once (no prompt).
	has(controller, 'request:FireServer({ action = "ExitAfk", reason = "Moved" })', "Movement input asks the server to end AFK Mode")
	has(controller, "if humanoid.MoveDirection.Magnitude > 0.05 or humanoid.Jump then\n\t\tonMovementDetected()", "...on walking or a jump")
	has(controller, "if MOVE_KEYS[input.KeyCode] then\n\t\tonMovementDetected()", "...on a movement key")
	has(controller, "if input.KeyCode == Enum.KeyCode.Thumbstick1 then", "...on a thumbstick")
	has(controller, '"AFK MODE ENDED  |  you moved"', "...and says so")
	assert(not string.find(controller, 'Fire("MovementPrompt")', 1, true), "No exit prompt from the controller any more")

	local panel = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau")
	has(panel, 'setText(parts.ClaimText, if current == "Afk" then "Exit AFK" elseif current == "Idle" then "Go AFK!" else CLAIM_TEXT)', "The panel's button: Go AFK! / Exit AFK")
	has(panel, 'AfkRewardsRequest:FireServer({ action = if current == "Afk" then "ExitAfk" else "EnterAfk" })', "...which asks the server")
	has(panel, 'setText(subtitle, "AFK for " .. clock(Workspace:GetServerTimeNow() - since))', "It shows how long the player has been AFK")
	has(panel, 'SpinWheelCatalog.FormatNumber(tonumber(LocalPlayer:GetAttribute("AfkModeSpeed")) or 0)', "...the Speed paid")
	has(panel, 'tostring(tonumber(LocalPlayer:GetAttribute("AfkModeTickets")) or 0)', "...and the Spin Tickets")
	has(panel, 'LocalPlayer:GetAttributeChangedSignal("AfkModeActive"):Connect(onAfkChanged)', "Turning AFK Mode on opens the panel")
	for _, gone in { "Are you sure you want to exit AFK?", "Stay in AFK", "isMovementExitPrompt", 'Fire("MovementPrompt")' } do
		assert(not string.find(panel, gone, 1, true), "The panel's movement exit prompt is gone: " .. gone)
	end
	for _, path in {
		"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkZoneController.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau",
		"src/common/ServerScriptService/Social/AfkZoneService.server.luau",
	} do
		assert(not string.find(fs.readFile(path), "AfkZoneInside", 1, true), path .. " no longer knows the circle")
	end
	print("PASS AFK Mode client: no circle, an AFK MODE line, the idle kick answered, Go AFK! / Exit AFK on the panel, movement input ends AFK Mode (no prompt)")
end

do
	local afk = run()
	assert(afk.globals.SpeedsterAfkZoneTake(afk.player) == nil, "Nothing to take outside AFK Mode")
	afk.send({ action = "EnterAfk" })
	assert(afk.globals.SpeedsterAfkZoneTake(afk.player) == nil, "Nothing to take before the first payment")
	afk.advance(600)
	local taken = afk.globals.SpeedsterAfkZoneTake(afk.player)
	assert(taken and taken.Speed == 100000 and taken.Tickets == 1, "Get x5 takes the stint's unclaimed Speed and tickets")
	assert(afk.attributes.AfkModeSpeed == 0 and afk.attributes.AfkHasUnclaimed == false, "...out of the session")
	afk.send({ action = "ClaimAfkZone" })
	assert(#afk.commits == 0, "...so Claim cannot pay them a second time")
	taken.Restore()
	taken.Restore() -- a repeated failure callback must not restore twice
	assert(afk.attributes.AfkModeSpeed == 100000 and afk.attributes.AfkModeTickets == 1, "A receipt that does not land puts them back")
	local again = afk.globals.SpeedsterAfkZoneTake(afk.player)
	afk.send({ action = "ExitAfk" })
	assert(#afk.commits == 0, "Exit AFK pays nothing that Get x5 holds")
	again.Restore()
	local speed, tickets, _, total = tally(afk.commits)
	assert(total == 100000 and tickets == 1, "...and a failed receipt after Exit AFK still pays them x1")
	print("PASS Get x5 take / restore on AFK Mode")
end
do
    local afk = run()
    afk.send({ action = "EnterAfk" })
    local root = afk.player.Character.Root
    root.Position += V3.new(30, 0, 0)
    afk.advance(1)
    assert(afk.attributes.AfkModeActive == false and not root.Anchored, "Teleporting off the AFK spot clears AFK")
end

----------------------------------------------------------------------
-- 2026-09-26 (owner): standing, and moving ends it
----------------------------------------------------------------------
-- Moving (each way) ends AFK Mode at once, claims what the stint earned x1 exactly as Exit AFK
-- does, and nothing more accrues.
local function movesOut(label, move)
	local afk = run()
	afk.send({ action = "EnterAfk" })
	afk.advance(90) -- one payment (60 s) and settled
	assert(afk.attributes.AfkModeActive == true and afk.attributes.AfkModeSpeed == 10000, label .. ": AFK and earning before moving")
	move(afk)
	afk.advance(1)
	assert(afk.attributes.AfkModeActive == false and afk.attributes.AfkModeSpeed == nil, label .. ": moving ends AFK Mode")
	local speed, tickets, amounts, total = tally(afk.commits)
	assert(#afk.commits == 1 and speed == 1 and total == 10000 and amounts[10000] and tickets == 0, label .. ": what the stint earned is claimed x1, once")
	assert(string.find(afk.commits[1].operationId, "afkmode-claim:", 1, true) == 1, label .. ": through the same claim as Exit AFK")
	afk.advance(1200)
	local _, _, _, after = tally(afk.commits)
	assert(#afk.commits == 1 and after == 10000 and afk.attributes.AfkModeActive == false, label .. ": nothing more accrues")
	assert(not afk.player.Character.Root.Anchored, label .. ": never anchored")
	return afk
end

do
	local function character(afk)
		return afk.player.Character
	end
	movesOut("walking (movement input)", function(afk)
		character(afk).Humanoid.MoveDirection = V3.new(0.7, 0, 0.7)
	end)
	movesOut("a jump", function(afk)
		character(afk).Root.Position += V3.new(0, 4, 0)
	end)
	movesOut("Humanoid.Jump", function(afk)
		character(afk).Humanoid.Jump = true
	end)
	movesOut("running (horizontal speed)", function(afk)
		character(afk).Root.AssemblyLinearVelocity = V3.new(12, 0, 0)
	end)
	movesOut("leaving the small radius", function(afk)
		character(afk).Root.Position += V3.new(4.5, 0, 4.5)
	end)
	movesOut("the client's ExitAfk on movement", function(afk)
		afk.send({ action = "ExitAfk", reason = "Moved" })
	end)
	print("PASS AFK Mode (owner, 2026-09-26): walking, a jump, running, leaving the radius or the client's ExitAfk end it at once; the stint's Speed is claimed x1 once; nothing more accrues")
end

do
	-- Standing still, settling onto its feet and a small drift never end it.
	local afk = run()
	afk.send({ action = "EnterAfk" })
	local root = afk.player.Character.Root
	root.Position -= V3.new(0, 0.25, 0) -- it settles onto its feet
	root.AssemblyLinearVelocity = V3.new(0, -3, 0) -- landing
	afk.advance(1)
	assert(afk.attributes.AfkModeActive == true, "Settling onto its feet is not moving")
	root.AssemblyLinearVelocity = V3.zero
	afk.advance(2)
	root.Position += V3.new(1.2, 0, -0.8) -- nudged
	afk.advance(597)
	assert(afk.attributes.AfkModeActive == true and afk.attributes.AfkModeSpeed == 100000 and afk.attributes.AfkModeTickets == 1,
		"Standing (a small drift included) keeps AFK Mode on and earning: 10 minutes")
	-- A jump is measured from where it settled.
	root.Position += V3.new(0, 2.6, 0)
	afk.advance(1)
	assert(afk.attributes.AfkModeActive == false, "...a jump off its settled height ends it")
	print("PASS AFK Mode: settling onto its feet, a landing and a small drift are not moving; standing earns; a jump from the settled height ends it")
end

do
	-- Seated: unseated first; an old anchored root is let go; R6 and a measured height.
	local seated = run({ seated = true, anchored = true })
	local humanoid = seated.player.Character.Humanoid
	local weld = humanoid.SeatPart.Weld
	seated.send({ action = "EnterAfk" })
	assert(humanoid.Sit == false and weld.Destroyed, "A seated player is unseated (SeatWeld gone, Sit off) before being set down")
	assert(seated.player.Character.Root.Anchored == false, "An anchored root is let go: AFK Mode never holds one")

	local r6 = run({ rigType = roblox.Enum.HumanoidRigType.R6, hipHeight = 0 })
	r6.send({ action = "EnterAfk" })
	local lift = r6.player.Character.Root.Position.Y - r6.center.Y
	assert(math.abs(lift - 3.25) < 1e-4, "R6: 2-stud legs + half the root over the floor, + 0.25 (" .. lift .. ")")

	-- A floor raised over the spot's point (the old anchored height sank bodies into floors like
	-- it): the slot's floor is raycast, and a character standing now gives its own height.
	local floorY = 51.5
	local measured = run({ floorY = floorY, floorMaterial = roblox.Enum.Material.Grass, startAt = V3.new(400, floorY + 4.1, 0) })
	measured.send({ action = "EnterAfk" })
	local mroot = measured.player.Character.Root
	assert(math.abs(mroot.Position.Y - (floorY + 4.1 + 0.25)) < 1e-3, "Feet on the slot's own floor at the character's measured standing height (" .. mroot.Position.Y .. ")")
	local fallback = run({ floorY = floorY })
	fallback.send({ action = "EnterAfk" })
	assert(math.abs(fallback.player.Character.Root.Position.Y - (floorY + 3.25)) < 1e-3, "In the air when it went AFK: the rig's height over the slot's floor")
	print("PASS AFK Mode: unseated, never anchored; R6 / R15 / measured standing heights put the feet on the slot's floor")
end

do
	-- A claim that does not land when the player moves: nothing more accrues, AFK Mode ends when it lands.
	local pendingLeft = 2
	local afk = run({ onCommit = function()
		if pendingLeft > 0 then
			pendingLeft -= 1
			return { kind = "Pending" }
		end
		return { kind = "Committed" }
	end })
	afk.send({ action = "EnterAfk" })
	afk.advance(90)
	afk.player.Character.Humanoid.MoveDirection = V3.new(1, 0, 0)
	afk.advance(1)
	assert(afk.attributes.AfkModeActive == true and #afk.commits == 1, "The claim is pending: the session waits for it")
	afk.player.Character.Humanoid.MoveDirection = V3.zero -- stopped: it still ends
	afk.advance(1)
	assert(afk.attributes.AfkModeSpeed == 10000, "...earning nothing more meanwhile")
	afk.advance(1)
	assert(afk.attributes.AfkModeActive == false and #afk.commits == 3, "...retried every second until it lands, then AFK Mode ends")
	assert(afk.commits[1].operationId == afk.commits[3].operationId, "...with the same durable operation (paid once)")
	afk.send({ action = "EnterAfk" })
	assert(afk.attributes.AfkModeActive == true, "Go AFK! works again afterwards")
	print("PASS AFK Mode: a claim still pending when the player moved stops the stint's earnings and is retried (same operation) until AFK Mode ends")
end

do
	-- The source: no anchoring, seating or freezing anywhere in AFK Mode.
	for _, path in {
		"src/common/ServerScriptService/Social/AfkZoneService.server.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkZoneController.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau",
	} do
		local code = string.gsub(fs.readFile(path), "%-%-[^\n]*", "")
		for _, banned in { "Anchored = true", "Sit = true", "PlatformStand", "WalkSpeed = 0", "JumpPower = 0", "JumpHeight = 0", "HumanoidStateType.Seated" } do
			assert(not string.find(code, banned, 1, true), path .. ": AFK Mode must not " .. banned)
		end
	end
	print("PASS AFK Mode source: nothing anchors, seats or freezes the character")
end


do
    local afk
    afk = run({ onCommit = function()
        assert(afk.globals.SpeedsterAfkZoneTake(afk.player) == nil, "x5 cannot take a stint while its normal claim yields")
        assert(afk.attributes.AfkModeClaimBusy == true)
        return { kind = "Pending" }
    end })
    afk.send({ action = "EnterAfk" })
    afk.advance(60)
    afk.send({ action = "ClaimAfkZone" })
    assert(afk.globals.SpeedsterAfkZoneTake(afk.player) == nil, "An uncertain normal claim keeps its reservation")
    afk.send({ action = "ClaimAfkZone" })
    assert(afk.commits[1].operationId == afk.commits[2].operationId, "A retry uses the same durable operation")
end

print("ALL AFK MODE CHECKS PASSED")
