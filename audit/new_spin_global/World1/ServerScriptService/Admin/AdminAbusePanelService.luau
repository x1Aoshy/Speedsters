--!strict
-- AdminAbusePanelService.server.luau
-- Server side of the Admin Abuse Panel (UI/AdminAbusePanelController). One remote,
-- AdminAbusePanel, carries every action; the panel is deliberately basic until the
-- designer's admin UI arrives, but every button here does its job.
--
--   Abuse:       Rocket, Ragdoll, Jail, Balloon, Tiny, Inverse, Control, Jumpscare, NoGravity
--   Events:      Disco (a disco ball over the lobby), Snow (lava and bosses freeze),
--                Sandstorm, Confetti (with a duration)
--   Boosts:      server Speed / Wins boosts at any multiplier
--   Treadmills:  a rainbow admin treadmill with a sign and the game's aura VFX
--   Stats:       give Speed / Wins / Rebirths, reset stats, gamepasses on and off, force a
--                rebirth, redeem a code, travel to another world
--   Music:       play a track for the server, stop it
--   Announce:    a filtered message to every player, in a banner theme
--   Moderation:  Kick, Ban, Mute, Unmute, Go To, Bring, Give Speed, Remove Speed
--
-- Scope "All" runs events, boosts, announcements and Everyone-targeted abuse on every
-- server through MessagingService. Effects that move a character run on that player's
-- own client (AdminAbuseEffects), because the client owns its character's physics.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local PotionServer = require(Services:WaitForChild("PotionServer"))
local RateLimiter = require(Services:WaitForChild("ServerRateLimiter"))
local Validation = require(ServerScriptService:WaitForChild("Admin"):WaitForChild("AdminRequestValidation"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local Panel = remote("AdminAbusePanel")
local AnnouncementRemote = remote("DisplayGlobalAnnouncement")
-- /admin and /panel in chat (ChatBoostCommands) open the panel through this one. It used
-- to come from the first admin panel's service, which is switched off.
remote("AdminPanelStatus")

local TOPIC = "SpeedsterAdminAbusePanel_v1"
local ANNOUNCEMENT_TOPIC = "SpeedsterGlobalAnnouncements_v1"
local acceptEvent = Validation.NewEventCache()

local OWNER_IDS: { [number]: boolean } = {
	[767108248] = true,
	[5113549114] = true,
}

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() or OWNER_IDS[player.UserId] or AdminBannerConfig.IsAdmin(player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank >= 254
	end
	return false
end

local function toast(player: Player?, ok: boolean, message: string)
	if player and player.Parent == Players then
		Panel:FireClient(player, { kind = "Toast", ok = ok, message = message })
	end
end

local function number(value: any, default: number, low: number, high: number): number
	local parsed = tonumber(value)
	if parsed == nil or parsed ~= parsed or math.abs(parsed) == math.huge then
		return default
	end
	return math.clamp(parsed, low, high)
end

local function targetsFor(admin: Player?, target: any): { Player }
	if target == "All" then
		return Players:GetPlayers()
	end
	local userId = tonumber(target)
	local player = userId and Players:GetPlayerByUserId(userId)
	if player then
		return { player }
	end
	return if admin and target == nil then { admin } else {}
end

local function aliveRoot(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, root, humanoid
end

----------------------------------------------------------------------
-- Abuse
----------------------------------------------------------------------
local CLIENT_EFFECTS = { Rocket = true, Balloon = true, Inverse = true, Control = true, Jumpscare = true, NoGravity = true, FakeReset = true }

local function ragdoll(player: Player, duration: number): boolean
	local character = aliveRoot(player)
	if not character then
		return false
	end
	local event = character:FindFirstChild("RagdollEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire("Ragdoll", duration)
	else
		character:SetAttribute("RagdollDuration", duration)
		character:SetAttribute("Ragdolled", true)
	end
	return true
end

local function tiny(player: Player, duration: number): boolean
	local character = aliveRoot(player)
	if not character then
		return false
	end
	local ok = pcall(function()
		character:ScaleTo(0.45)
	end)
	if not ok then
		return false
	end
	local token = HttpService:GenerateGUID(false)
	character:SetAttribute("AdminTinyToken", token)
	task.delay(duration, function()
		if character.Parent and character:GetAttribute("AdminTinyToken") == token then
			pcall(function()
				character:ScaleTo(1)
			end)
		end
	end)
	return true
end

-- Snail: a crawl at SNAIL_SPEED until the time is up, with a snail sign and a slime trail
-- that everyone sees. The movement scripts read AdminSnailUntil (InstantMovementController
-- on the player's client, PlayerStats on the server), so the player's own speed comes back
-- by itself when the time runs out.
local SNAIL_SPEED = 2.5
local function snail(player: Player, duration: number): boolean
	local character, root = aliveRoot(player)
	if not character or not root then
		return false
	end
	local untilTime = Workspace:GetServerTimeNow() + duration
	player:SetAttribute("AdminSnailUntil", untilTime)
	local old = character:FindFirstChild("AdminSnail")
	if old then
		old:Destroy()
	end
	local kit = Instance.new("Folder")
	kit.Name = "AdminSnail"
	local sign = Instance.new("BillboardGui")
	sign.Name = "SnailSign"
	sign.Adornee = root
	sign.Size = UDim2.fromScale(7, 2.2)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	sign.MaxDistance = 150
	sign.Parent = kit
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.28, 1)
	icon.TextScaled = true
	icon.Text = "🐌"
	icon.Parent = sign
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.3, 0.1)
	title.Size = UDim2.fromScale(0.7, 0.8)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(160, 255, 100)
	title.Text = "SNAIL MODE"
	title.Parent = sign
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(11, 27, 61)
	outline.Thickness = 3
	outline.Parent = title
	-- The slime trail, from two points at the feet.
	local left = Instance.new("Attachment")
	left.Name = "AdminSnailSlimeLeft"
	left.Position = Vector3.new(-0.8, -2.9, 0)
	left.Parent = root
	local right = Instance.new("Attachment")
	right.Name = "AdminSnailSlimeRight"
	right.Position = Vector3.new(0.8, -2.9, 0)
	right.Parent = root
	local slime = Instance.new("Trail")
	slime.Name = "Slime"
	slime.Attachment0 = left
	slime.Attachment1 = right
	slime.Lifetime = 2.5
	slime.LightEmission = 0.3
	slime.Color = ColorSequence.new(Color3.fromRGB(170, 255, 100), Color3.fromRGB(70, 190, 60))
	slime.Transparency = NumberSequence.new(0.25, 1)
	slime.Parent = kit
	kit.Parent = character
	pcall(function()
		_G.SpeedsterApplyWalkSpeed(player)
	end)
	Panel:FireClient(player, { kind = "Effect", effect = "Snail", duration = duration })
	task.delay(duration, function()
		if player:GetAttribute("AdminSnailUntil") == untilTime then
			player:SetAttribute("AdminSnailUntil", nil)
			pcall(function()
				_G.SpeedsterApplyWalkSpeed(player)
			end)
		end
		kit:Destroy()
		left:Destroy()
		right:Destroy()
	end)
	return true
end

local function jail(player: Player, duration: number): boolean
	local character, root, humanoid = aliveRoot(player)
	if not character or not root or not humanoid then
		return false
	end
	local center = root.Position
	local previous = Workspace:FindFirstChild("AdminJail_" .. player.UserId)
	if previous then
		previous:Destroy()
	end
	local cage = Instance.new("Model")
	cage.Name = "AdminJail_" .. player.UserId
	local SIZE, HEIGHT, BAR = 8, 10, 0.5
	local floorY = center.Y - humanoid.HipHeight - root.Size.Y / 2
	local function bar(size: Vector3, offset: Vector3, transparency: number)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = size
		part.CFrame = CFrame.new(Vector3.new(center.X, floorY, center.Z) + offset)
		part.Color = Color3.fromRGB(60, 64, 72)
		part.Material = Enum.Material.DiamondPlate
		part.Transparency = transparency
		part.Parent = cage
		return part
	end
	bar(Vector3.new(SIZE + BAR, BAR, SIZE + BAR), Vector3.new(0, -BAR / 2, 0), 0)
	bar(Vector3.new(SIZE + BAR, BAR, SIZE + BAR), Vector3.new(0, HEIGHT + BAR / 2, 0), 0)
	-- Walls: solid but see-through, with bars drawn on them.
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local wallSize = if side.X ~= 0 then Vector3.new(BAR, HEIGHT, SIZE) else Vector3.new(SIZE, HEIGHT, BAR)
		bar(wallSize, side * (SIZE / 2) + Vector3.new(0, HEIGHT / 2, 0), 0.85)
		for step = -3, 3 do
			local along = if side.X ~= 0 then Vector3.new(0, 0, step * SIZE / 7) else Vector3.new(step * SIZE / 7, 0, 0)
			local barPart = bar(Vector3.new(0.3, HEIGHT, 0.3), side * (SIZE / 2) + along + Vector3.new(0, HEIGHT / 2, 0), 0)
			barPart.CanCollide = false
		end
	end
	cage.Parent = Workspace
	character:PivotTo(CFrame.new(Vector3.new(center.X, floorY + humanoid.HipHeight + root.Size.Y / 2 + 0.2, center.Z)))
	local released = false
	local left: RBXScriptConnection? = nil
	local function release()
		if released then
			return
		end
		released = true
		if left then
			left:Disconnect()
		end
		cage:Destroy()
	end
	humanoid.Died:Once(release)
	-- A reset or leaving the game takes the character away without a death.
	left = character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(Workspace) then
			release()
		end
	end)
	task.delay(duration, release)
	return true
end

-- `byName` is who to credit (a request from another server has no admin here).
local function applyAbuse(admin: Player?, effect: string, target: any, duration: number, byName: string?): (number, number)
	local targets = targetsFor(admin, target)
	local credit = byName or (if admin then admin.DisplayName else "Admin")
	local done = 0
	for _, player in targets do
		local ok = false
		if CLIENT_EFFECTS[effect] then
			if aliveRoot(player) then
				Panel:FireClient(player, {
					kind = "Effect",
					effect = effect,
					duration = duration,
					adminUserId = if admin then admin.UserId else nil,
					adminName = credit,
				})
				ok = true
			end
		elseif effect == "Ragdoll" then
			ok = ragdoll(player, duration)
		elseif effect == "Tiny" then
			ok = tiny(player, duration)
		elseif effect == "Jail" then
			ok = jail(player, duration)
		elseif effect == "Snail" then
			ok = snail(player, duration)
		end
		if ok then
			done += 1
		end
	end
	return done, #targets
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local eventTokens: { [string]: string } = {}

-- Where a map-wide event stands: above the lobby's spawn.
local function lobbyCenter(): Vector3
	local best = nil
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			best = descendant
			break
		end
	end
	return if best then best.CFrame.Position else Vector3.new(0, 50, 0)
end

-- Disco: a party over the lobby's dance floor (Config.AdminDisco). The server only marks it
-- on Workspace; every client draws the mirror ball, its beams and spotlights, the dance
-- floor and the night (AdminAbuseEffects), turning the ball by the server's clock so it
-- spins smoothly and in step for everyone, wherever they are.
--   AdminDiscoUntil       when it ends (os.time)
--   AdminDiscoCenter      the middle of the mirror ball
--   AdminDiscoFloor       the middle of the dance floor, on the lobby floor
--   AdminDiscoFloorSize   the dance floor's width (X) and length (Z)
local DISCO_ATTRIBUTES = { "AdminDiscoUntil", "AdminDiscoCenter", "AdminDiscoFloor", "AdminDiscoFloorSize" }

-- This lobby's dance floor: its middle on the floor and its size. A place without one gets
-- a floor around its spawn.
local function discoFloor(): (Vector3, Vector3, number)
	local settings = Config.AdminDisco
	local height = if settings and tonumber(settings.BallHeight) then settings.BallHeight else 34
	local key = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" elseif Config.IsNewWorld1Map then "World1" else nil
	local spot = key and settings and settings.WorldPlacement and settings.WorldPlacement[key]
	if spot and typeof(spot.Floor) == "Vector3" and typeof(spot.Size) == "Vector3" then
		return spot.Floor, spot.Size, height
	end
	return lobbyCenter(), Vector3.new(60, 0, 60), height
end

-- The DJ booth (Config.AdminDisco: Booth, BoothScale): while the disco is on, the admin who
-- started it dances as a giant DJ on a giant stage out past the lobby's back wall. Seen
-- from the dance floor the wall hides the stage, the console rises over the wall and hides
-- the DJ's legs, and the DJ shows from the waist up. The server builds the set and the
-- admin's own avatar and plays the dance; every client lights the set in time with the
-- music (AdminAbuseEffects) and fades it away in confetti when the party ends.
--   Parts marked DJNeon (a colour phase), DJBar (an equaliser bar), DJWoofer and DJSpot
--   are the ones the clients animate; the model's Leaving attribute starts the fade and
--   its DJScale attribute sizes the confetti.
local DJ_BOOTH_NAME = "AdminDJBooth"
-- The DJ against a scale-1 set; the whole set, DJ included, is then BoothScale times that.
local DJ_SCALE = 1.6
local DJ_LEAVE_SECONDS = 2.5
local DJ_DANCE_SECONDS = 10
-- The set, in units of its scale: the stage's thickness, and the console, which stands to
-- the DJ's waist. The DJ's hips go just under the console's top, whatever their legs.
local DJ_STAGE = 1.2
local DJ_DESK_HEIGHT = 4.8
local DJ_DESK_TOP = DJ_STAGE + DJ_DESK_HEIGHT
local DJ_HIPS_UNDER_DESK = 0.1
local DJ_STAND_Z = 0.3
local DJ_CHEST = DJ_DESK_TOP + 2.2
local DJ_DANCES = {
	R15 = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" },
	R6 = { "rbxassetid://182435998", "rbxassetid://182436842", "rbxassetid://182436935" },
}
local djToken: string? = nil

-- This lobby's booth spot (the stage's bottom, facing its dance floor) and its scale. A
-- place without one gets a normal-size booth beside its dance floor.
local function boothSpot(): (CFrame, number)
	local settings = Config.AdminDisco
	local key = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" elseif Config.IsNewWorld1Map then "World1" else nil
	local spot = key and settings and settings.WorldPlacement and settings.WorldPlacement[key]
	local booth = spot and spot.Booth
	if booth and typeof(booth.Position) == "Vector3" and typeof(booth.Face) == "Vector3" then
		local scale = tonumber(settings.BoothScale) or 1
		return CFrame.lookAt(booth.Position, Vector3.new(booth.Face.X, booth.Position.Y, booth.Face.Z)), math.clamp(scale, 1, 12)
	end
	local floor, size = discoFloor()
	local position = floor - Vector3.new(0, 0, size.Z / 2 + 10)
	return CFrame.lookAt(position, floor), 1
end

local function boothPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function neon(model: Model, name: string, size: Vector3, cframe: CFrame, phase: number): BasePart
	local part = boothPart(model, name, size, cframe, Color3.fromRGB(255, 80, 200), Enum.Material.Neon)
	part.CanCollide = false
	part.CastShadow = false
	part:SetAttribute("DJNeon", phase)
	return part
end

-- The set, built on `spot` (the stage's bottom, facing the dance floor), `u` times a
-- normal booth: a stage on a tower that reaches down behind the wall, the console in
-- front of the DJ (two decks and a mixer on it, glowing bars down its front), a speaker
-- stack each side, an LED wall of equaliser bars behind, and a truss of spotlights on the DJ.
local function buildBoothSet(spot: CFrame, u: number): Model
	local model = Instance.new("Model")
	model.Name = DJ_BOOTH_NAME
	model:SetAttribute("DJScale", u)
	local DARK = Color3.fromRGB(26, 26, 36)
	local METAL = Color3.fromRGB(120, 124, 136)
	-- Local frame, in units of u: X right, Y up, -Z towards the dance floor.
	local function at(x: number, y: number, z: number): CFrame
		return spot * CFrame.new(x * u, y * u, z * u)
	end
	local function size(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * u
	end
	if u > 1 then
		-- Out past the wall the stage would float: a tower carries it down out of sight.
		local tower = boothPart(model, "StageTower", size(22, 40, 10), at(0, -20, 0), Color3.fromRGB(18, 18, 26), Enum.Material.SmoothPlastic)
		tower.CastShadow = false
	end
	boothPart(model, "Stage", size(22, DJ_STAGE, 10), at(0, DJ_STAGE / 2, 0), DARK, Enum.Material.SmoothPlastic)
	neon(model, "StageLip", size(22, 0.35, 0.4), at(0, DJ_STAGE - 0.2, -5.05), 0)
	neon(model, "StageLipLeft", size(0.4, 0.35, 10), at(-11.05, DJ_STAGE - 0.2, 0), 0.25)
	neon(model, "StageLipRight", size(0.4, 0.35, 10), at(11.05, DJ_STAGE - 0.2, 0), 0.75)

	-- The console, right in front of the DJ and up to their waist: its glowing front, the
	-- decks and the mixer.
	boothPart(model, "Desk", size(15, DJ_DESK_HEIGHT, 1.6), at(0, DJ_STAGE + DJ_DESK_HEIGHT / 2, -1.6), DARK, Enum.Material.SmoothPlastic)
	for index = 0, 2 do
		neon(model, "DeskGlow", size(14, 0.35, 0.2), at(0, DJ_STAGE + 1 + index * 1.3, -2.45), index / 3)
	end
	for _, side in { -1, 1 } do
		local deck = boothPart(model, "Deck", size(0.3, 2.8, 2.8), at(side * 4.2, DJ_DESK_TOP + 0.15, -1.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(12, 12, 16), Enum.Material.SmoothPlastic)
		deck.Shape = Enum.PartType.Cylinder
		local label = neon(model, "DeckLabel", size(0.34, 0.9, 0.9), at(side * 4.2, DJ_DESK_TOP + 0.16, -1.6) * CFrame.Angles(0, 0, math.rad(90)), if side < 0 then 0.1 else 0.6)
		label.Shape = Enum.PartType.Cylinder
	end
	boothPart(model, "Mixer", size(2.6, 0.4, 1.4), at(0, DJ_DESK_TOP + 0.2, -1.6), Color3.fromRGB(40, 40, 52), Enum.Material.Metal)
	for index = 0, 3 do
		neon(model, "MixerKnob", size(0.35, 0.2, 0.35), at(-0.9 + index * 0.6, DJ_DESK_TOP + 0.5, -1.9), index / 4)
	end

	-- The speaker stacks: a cabinet, two woofers with glowing rings.
	for _, side in { -1, 1 } do
		boothPart(model, "Speaker", size(3.6, 12, 3.6), at(side * 9.6, DJ_STAGE + 6, -0.5), Color3.fromRGB(16, 16, 22), Enum.Material.SmoothPlastic)
		for _, height in { 4.5, 9 } do
			local ring = neon(model, "WooferRing", size(0.2, 3.1, 3.1), at(side * 9.6, DJ_STAGE + height, -2.32) * CFrame.Angles(0, math.rad(90), 0), 0.5 + side * 0.1)
			ring.Shape = Enum.PartType.Cylinder
			ring:SetAttribute("DJWoofer", true)
			local woofer = boothPart(model, "Woofer", size(0.3, 2.6, 2.6), at(side * 9.6, DJ_STAGE + height, -2.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 40, 48), Enum.Material.SmoothPlastic)
			woofer.Shape = Enum.PartType.Cylinder
			woofer.CanCollide = false
		end
	end

	-- The LED wall behind the DJ: twelve equaliser bars on a black screen, standing from
	-- the console's height so they show over it.
	boothPart(model, "LedWall", size(18, 14, 0.6), at(0, DJ_STAGE + 7, 3.4), Color3.fromRGB(8, 8, 12), Enum.Material.SmoothPlastic)
	for index = 1, 12 do
		local x = -6.6 + (index - 1) * 1.2
		local bar = neon(model, "EqBar", size(1, 1, 0.3), at(x, DJ_DESK_TOP + 0.9, 3), index / 12)
		bar:SetAttribute("DJBar", index)
		-- Where the bar stands (its foot) and its tallest, for the clients.
		bar:SetAttribute("DJBarFoot", at(x, DJ_DESK_TOP + 0.4, 3))
		bar:SetAttribute("DJBarMax", 8.4 * u)
	end

	-- The truss and its spotlights, all on the DJ's chest.
	boothPart(model, "TrussBeam", size(23, 0.8, 0.8), at(0, 17.2, -1), METAL, Enum.Material.DiamondPlate)
	for _, side in { -1, 1 } do
		boothPart(model, "TrussPost", size(0.8, 16, 0.8), at(side * 11.5, DJ_STAGE + 8, -1), METAL, Enum.Material.DiamondPlate)
	end
	local chest = at(0, DJ_CHEST, DJ_STAND_Z).Position
	for index, x in { -7, -2.5, 2.5, 7 } do
		local position = at(x, 16.3, -1.2).Position
		local head = boothPart(model, "SpotHead", size(1.2, 1.2, 1.2), CFrame.lookAt(position, chest), Color3.fromRGB(30, 30, 38), Enum.Material.Metal)
		head.CanCollide = false
		head:SetAttribute("DJSpot", index)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 32
		-- Roblox lights reach 60 studs at most.
		light.Range = math.min(60, 22 * u)
		light.Brightness = 6
		light.Shadows = false
		light.Parent = head
	end
	return model
end

-- The admin's own avatar (or a plain one), made the DJ: `scale` times their size, fixed in
-- place, touching nothing, named in the game's style over the head, and dancing.
local function makeDJ(userId: number, name: string, scale: number): Model?
	local rig: Model? = nil
	if userId > 0 then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		rig = if ok then result else nil
	end
	if not rig then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		rig = if ok then result else nil
	end
	if not rig then
		return nil
	end
	rig.Name = "DJ"
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	pcall(function()
		rig:ScaleTo(scale)
	end)
	return rig
end

-- Where the DJ's hips are: the top of the thighs (R15) or of the legs (R6). Falls back to
-- the root, the hips' height on both rigs.
local DJ_THIGHS = { LeftUpperLeg = true, RightUpperLeg = true, ["Left Leg"] = true, ["Right Leg"] = true }
local function hipsOf(rig: Model): number?
	local hips = nil
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") and DJ_THIGHS[part.Name] then
			local up = part.CFrame:VectorToObjectSpace(Vector3.new(0, 1, 0))
			local half = 0.5 * (math.abs(up.X) * part.Size.X + math.abs(up.Y) * part.Size.Y + math.abs(up.Z) * part.Size.Z)
			hips = math.max(hips or -math.huge, part.CFrame.Position.Y + half)
		end
	end
	if hips then
		return hips
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.CFrame.Position.Y else nil
end

-- Stands the DJ behind the console on `spot`'s stage, facing the dance floor, with the hips
-- just under the console's top: the legs stay hidden, however long they are. Every part
-- moves with the root (it is the only anchored one).
local function placeDJ(rig: Model, spot: CFrame, u: number)
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hips = hipsOf(rig)
	if not root or not hips then
		return
	end
	local stand = spot * CFrame.new(0, (DJ_DESK_TOP - DJ_HIPS_UNDER_DESK) * u, DJ_STAND_Z * u)
	-- Keep the root's height over the hips, turn it to face the floor.
	local rootOverHips = root.CFrame.Position.Y - hips
	local target = CFrame.new(stand.Position + Vector3.new(0, rootOverHips, 0)) * spot.Rotation
	local move = target * root.CFrame:Inverse()
	-- The rig is one jointed assembly: moving it by its pivot moves every limb once. (Part by
	-- part is only for a rig that is not an assembly, as in the offline checks.)
	local moved = pcall(function()
		rig:PivotTo(move * rig:GetPivot())
	end)
	if not moved then
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = move * part.CFrame
			end
		end
	end
end

local function signDJ(rig: Model, name: string, u: number)
	local head = rig:FindFirstChild("Head") or rig:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "DJSign"
	sign.Size = UDim2.fromScale(16 * u, 3.4 * u)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 4.2 * u, 0)
	sign.MaxDistance = 2000
	sign.LightInfluence = 0
	local board = Instance.new("Frame")
	board.Name = "Plate"
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.fromScale(0.5, 0.5)
	board.Size = UDim2.fromScale(1, 1)
	board.BackgroundColor3 = Color3.fromRGB(50, 78, 111)
	board.BackgroundTransparency = 0.2
	board.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = board
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(11, 27, 61)
	edge.Thickness = 3
	edge.Parent = board
	-- The headphones on their own either side (an emoji inside outlined text sits off its line).
	for _, entry in { { "HeadphonesLeft", 0.02 }, { "HeadphonesRight", 0.82 } } do
		local icon = Instance.new("TextLabel")
		icon.Name = entry[1]
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromScale(entry[2], 0.08)
		icon.Size = UDim2.fromScale(0.16, 0.84)
		icon.TextScaled = true
		icon.Text = "🎧"
		icon.Parent = board
	end
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.18, 0.08)
	title.Size = UDim2.fromScale(0.64, 0.84)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "DJ " .. name
	title.Parent = board
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(11, 27, 61)
	outline.Thickness = 3
	outline.Parent = title
	local rainbow = Instance.new("UIGradient")
	rainbow.Name = "Rainbow"
	rainbow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 230)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90)),
	})
	rainbow.Parent = title
	sign.Parent = head
end

-- Plays the DJ's dances on a loop, a new one every DJ_DANCE_SECONDS, while the booth stands.
local function danceDJ(rig: Model, booth: Model)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local okRig, rigType = pcall(function()
		return humanoid.RigType
	end)
	local list = if okRig and rigType == Enum.HumanoidRigType.R6 then DJ_DANCES.R6 else DJ_DANCES.R15
	task.spawn(function()
		local index = 0
		local playing: AnimationTrack? = nil
		while booth.Parent and booth:GetAttribute("Leaving") == nil do
			index = index % #list + 1
			local animation = Instance.new("Animation")
			animation.AnimationId = list[index]
			local ok, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.4)
				if playing then
					playing:Stop(0.4)
				end
				playing = track
			end
			task.wait(DJ_DANCE_SECONDS)
		end
		if playing then
			playing:Stop(0)
		end
	end)
end

-- Takes the booth down: the clients fade it into confetti, then it goes.
local function removeBooth()
	djToken = nil
	local booth = Workspace:FindFirstChild(DJ_BOOTH_NAME)
	if not booth or booth:GetAttribute("Leaving") ~= nil then
		return
	end
	booth:SetAttribute("Leaving", os.time())
	task.delay(DJ_LEAVE_SECONDS, function()
		if booth.Parent and booth:GetAttribute("Leaving") ~= nil then
			booth:Destroy()
		end
	end)
end

-- Puts up the booth for the admin `by` (their avatar dancing, their name on the sign).
local function raiseBooth(by: { UserId: number, Name: string }?)
	local existing = Workspace:FindFirstChild(DJ_BOOTH_NAME)
	if existing then
		existing:Destroy()
	end
	local token = HttpService:GenerateGUID(false)
	djToken = token
	local spot, u = boothSpot()
	local booth = buildBoothSet(spot, u)
	booth.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	booth:SetAttribute("DJName", if by then by.Name else "Admin")
	booth.Parent = Workspace
	-- The avatar takes a moment to load; the stage is up meanwhile.
	task.spawn(function()
		local name = if by then by.Name else "Admin"
		local rig = makeDJ(if by then by.UserId else 0, name, DJ_SCALE * u)
		if not rig or djToken ~= token or not booth.Parent then
			if rig then
				rig:Destroy()
			end
			return
		end
		-- Roughly in place first, then measured and set exactly once its joints have
		-- settled in the world (a rig out of the world has not laid its limbs out yet).
		placeDJ(rig, spot, u)
		rig.Parent = booth
		task.wait()
		if djToken ~= token or not booth.Parent then
			return
		end
		placeDJ(rig, spot, u)
		signDJ(rig, name, u)
		danceDJ(rig, booth)
	end)
end

-- The Disco perk (Config.AdminDisco): while the disco is on, every living player gets
-- DiscoSpeedGainMultiplier = PassiveSpeedMultiplier (the Speed gain is multiplied by it, and
-- their HUD shows a [Disco] card). A player dancing gets DanceSpeedMultiplier instead and
-- DiscoDancing, which makes the running loop (Bootstrap) pay them as if running while they
-- dance. Their client says when a dance plays on their character (AdminDiscoDance: the
-- dance floor's dance or /e dance); the server only believes it while they stand still on
-- the ground, alive, off the treadmills, so a false claim earns nothing a real dance would
-- not. The party ending, dying or leaving takes it all away.
local DISCO_PAD_ATTRIBUTE = "DiscoSpeedGainMultiplier"
local DISCO_DANCE_ATTRIBUTE = "DiscoDancing"
local DISCO_PAD_INTERVAL = 0.25
local DISCO_DANCE_MAX_SPEED = 4 -- studs a second across the ground: still enough to be dancing
local danceReports: { [Player]: boolean } = {}
local function discoMultipliers(): (number, number)
	local settings = Config.AdminDisco
	local passive = math.max(1, tonumber(settings and settings.PassiveSpeedMultiplier) or 2)
	local dance = math.max(passive, tonumber(settings and settings.DanceSpeedMultiplier) or 100)
	return passive, dance
end

-- Whether a player who says they are dancing really could be: alive, on the ground, not
-- sitting, not on a treadmill, not in AFK Mode (which pays on its own) and standing still.
local function canDance(player: Player, humanoid: Humanoid, root: BasePart?): boolean
	if humanoid.FloorMaterial == Enum.Material.Air or humanoid.Sit or player:GetAttribute("IsOnTreadmill") == true
		or player:GetAttribute("AfkModeActive") == true
	then
		return false
	end
	if humanoid.MoveDirection.Magnitude > 0.1 then
		return false
	end
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude <= DISCO_DANCE_MAX_SPEED
end

local function updateDiscoPad()
	local untilTime = tonumber(Workspace:GetAttribute("AdminDiscoUntil"))
	local active = untilTime ~= nil and os.time() < untilTime
	local passive, dance = discoMultipliers()
	for _, player in Players:GetPlayers() do
		local want, dancing = nil, nil
		if active then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and not (character:GetAttribute("Dead") == true or character:GetAttribute("Ragdolled") == true) then
				want = passive
				if danceReports[player] == true and canDance(player, humanoid, if root and root:IsA("BasePart") then root else nil) then
					want, dancing = dance, true
				end
			end
		end
		if player:GetAttribute(DISCO_PAD_ATTRIBUTE) ~= want then
			player:SetAttribute(DISCO_PAD_ATTRIBUTE, want)
		end
		if player:GetAttribute(DISCO_DANCE_ATTRIBUTE) ~= dancing then
			player:SetAttribute(DISCO_DANCE_ATTRIBUTE, dancing)
		end
	end
end

-- A client saying whether a dance is playing on its character (on change, and again every
-- couple of seconds). Only true or false is kept; a flood is dropped.
local DanceRemote = remote("AdminDiscoDance")
DanceRemote.OnServerEvent:Connect(function(player: Player, dancing: any)
	if not RateLimiter.Allow(player, "AdminDiscoDance", 0.2) then
		return
	end
	danceReports[player] = if dancing == true then true else nil
end)
Players.PlayerRemoving:Connect(function(player: Player)
	danceReports[player] = nil
end)

local function stopDisco()
	eventTokens.Disco = nil
	removeBooth()
	for _, name in DISCO_ATTRIBUTES do
		Workspace:SetAttribute(name, nil)
	end
	-- The party is over: nobody keeps the Disco bonus.
	pcall(updateDiscoPad)
end

local function startDisco(duration: number, by: { UserId: number, Name: string }?)
	stopDisco()
	local token = HttpService:GenerateGUID(false)
	eventTokens.Disco = token
	raiseBooth(by)
	local floor, size, height = discoFloor()
	Workspace:SetAttribute("AdminDiscoFloor", floor)
	Workspace:SetAttribute("AdminDiscoFloorSize", size)
	Workspace:SetAttribute("AdminDiscoCenter", floor + Vector3.new(0, height, 0))
	Workspace:SetAttribute("AdminDiscoUntil", os.time() + duration)
	task.delay(duration, function()
		if eventTokens.Disco == token then
			stopDisco()
		end
	end)
end

local stopSandstorm
local parkedAtmospheres: { Instance } = {}
local previousSandstormBoostExpire: number? = nil
local previousSandstormBoostMultiplier: number? = nil

local function startSandstorm(duration: number)
	if stopSandstorm then
		stopSandstorm()
	end
	local token = HttpService:GenerateGUID(false)
	eventTokens.Sandstorm = token
	local atmosphere = Lighting:FindFirstChild("AdminSandstorm") or Instance.new("Atmosphere")
	atmosphere.Name = "AdminSandstorm"
	atmosphere.Density = 0.62
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(214, 176, 120)
	atmosphere.Decay = Color3.fromRGB(168, 120, 70)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.6
	-- Lighting holds one Atmosphere; park the map's own while the storm runs.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child ~= atmosphere then
			table.insert(parkedAtmospheres, child)
			child.Parent = nil
		end
	end
	atmosphere.Parent = Lighting

	-- Ventisca da x2 de Speed durante el evento
	previousSandstormBoostExpire = tonumber(Workspace:GetAttribute("ServerBoostExpiresUnix"))
	previousSandstormBoostMultiplier = tonumber(Workspace:GetAttribute("ServerBoostMultiplier"))
	Workspace:SetAttribute("ServerBoostExpiresUnix", os.time() + duration)
	Workspace:SetAttribute("ServerBoostMultiplier", 2)

	Panel:FireAllClients({ kind = "Effect", effect = "Sandstorm", duration = duration })
	task.delay(duration, function()
		if eventTokens.Sandstorm == token then
			if stopSandstorm then
				stopSandstorm()
			end
		end
	end)
end

stopSandstorm = function()
	eventTokens.Sandstorm = nil
	local atmosphere = Lighting:FindFirstChild("AdminSandstorm")
	if atmosphere then
		atmosphere:Destroy()
	end
	for _, child in parkedAtmospheres do
		if child and not child.Parent then
			child.Parent = Lighting
		end
	end
	table.clear(parkedAtmospheres)
	Workspace:SetAttribute("ServerBoostExpiresUnix", previousSandstormBoostExpire)
	Workspace:SetAttribute("ServerBoostMultiplier", previousSandstormBoostMultiplier)
	previousSandstormBoostExpire = nil
	previousSandstormBoostMultiplier = nil
	Panel:FireAllClients({ kind = "Effect", effect = "Sandstorm", duration = 0 })
end

-- Snow: a snowfall with a winter sky on every client (AdminAbuseEffects), and the world
-- freezes: lava turns to ice and stops burning, bosses stand frozen and catch nobody. The
-- lava's kill scripts, World 1's rising lava and the boss scripts all check
-- AdminWorldFrozen; this turns it on and off and dresses the ice.
local frozenParts: { [BasePart]: { Material: Enum.Material, Color: Color3, Reflectance: number } } = {}
local frozenLooks: { [Instance]: { [string]: any } } = {} -- textures, decals and lights, as they were
local frozenAdded: { Instance } = {} -- the sparkles added to the ice
local frozenBosses: { Instance } = {}
local BOSS_NAMES = { Zoom = true, ReverseFlashBoss = true, ["Sonic.EXE"] = true }
local ICE_COLOR = Color3.fromRGB(165, 220, 255)
local ICE_LIGHT = Color3.fromRGB(170, 225, 255)

-- Lava is what burns: a part with a kill script, cracked-lava material, or a part named
-- lava dressed as lava (its lava texture or glow). The desert's minecart props named
-- "Lava" are sand and burn nobody, so they stay as they are.
local function isLava(part: BasePart): boolean
	if part:FindFirstChild("Kill script") or part.Material == Enum.Material.CrackedLava then
		return true
	end
	return string.find(string.lower(part.Name), "lava", 1, true) ~= nil
		and (part:FindFirstChildOfClass("Texture") ~= nil or part:FindFirstChildOfClass("SurfaceLight") ~= nil)
end

local function remember(object: Instance, properties: { string })
	if frozenLooks[object] then
		return
	end
	local saved = {}
	for _, property in properties do
		saved[property] = (object :: any)[property]
	end
	frozenLooks[object] = saved
end

-- A lava part becomes ice: its lava texture and decals hidden, its glow turned cold and
-- dim, its fire and smoke off, and a few sparkles on top.
local function freezePart(part: BasePart)
	frozenParts[part] = { Material = part.Material, Color = part.Color, Reflectance = part.Reflectance }
	-- Every client reads this: the character scripts that kill on touching lava leave ice alone.
	part:SetAttribute("AdminFrozenLava", true)
	part.Material = Enum.Material.Ice
	part.Color = ICE_COLOR
	part.Reflectance = 0.15
	for _, child in part:GetDescendants() do
		if child:IsA("Texture") or child:IsA("Decal") then
			remember(child, { "Transparency" })
			child.Transparency = 1
		elseif child:IsA("SurfaceLight") or child:IsA("PointLight") or child:IsA("SpotLight") then
			remember(child, { "Color", "Brightness" })
			child.Color = ICE_LIGHT
			child.Brightness = child.Brightness * 0.3
		elseif (child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Smoke")) and child.Enabled then
			remember(child, { "Enabled" })
			child.Enabled = false
		end
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "AdminIceSparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	sparkles.Size = NumberSequence.new(0.6)
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.LightEmission = 0.6
	sparkles.Parent = part
	table.insert(frozenAdded, sparkles)
end

local function freezeWorld()
	Workspace:SetAttribute("AdminWorldFrozen", true)
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") and not frozenParts[descendant] and isLava(descendant) then
			freezePart(descendant)
		elseif descendant:IsA("Model") and BOSS_NAMES[descendant.Name] and descendant:FindFirstChildWhichIsA("Humanoid", true) and not descendant:FindFirstChild("AdminFrozen") then
			local ice = Instance.new("Highlight")
			ice.Name = "AdminFrozen"
			ice.FillColor = ICE_COLOR
			ice.FillTransparency = 0.35
			ice.OutlineColor = Color3.fromRGB(235, 250, 255)
			ice.Parent = descendant
			descendant:SetAttribute("AdminFrozen", true)
			table.insert(frozenBosses, descendant)
		end
	end
end

local function thawWorld()
	Workspace:SetAttribute("AdminWorldFrozen", nil)
	for part, original in frozenParts do
		if part.Parent then
			part.Material = original.Material
			part.Color = original.Color
			part.Reflectance = original.Reflectance
			part:SetAttribute("AdminFrozenLava", nil)
		end
	end
	table.clear(frozenParts)
	for object, saved in frozenLooks do
		if object.Parent then
			for property, value in saved do
				(object :: any)[property] = value
			end
		end
	end
	table.clear(frozenLooks)
	for _, added in frozenAdded do
		added:Destroy()
	end
	table.clear(frozenAdded)
	for _, boss in frozenBosses do
		local ice = boss:FindFirstChild("AdminFrozen")
		if ice then
			ice:Destroy()
		end
		boss:SetAttribute("AdminFrozen", nil)
	end
	table.clear(frozenBosses)
end

local previousSnowWinsExpire: number? = nil
local previousSnowWinsMultiplier: number? = nil

local function stopSnow()
	local wasActive = eventTokens.Snow ~= nil
	local snowUntil = Workspace:GetAttribute("AdminSnowUntil")
	eventTokens.Snow = nil
	Workspace:SetAttribute("AdminSnowUntil", nil)
	if wasActive and Workspace:GetAttribute("ServerWinsBoostExpiresUnix") == snowUntil
		and Workspace:GetAttribute("ServerWinsBoostMultiplier") == 2 then
		Workspace:SetAttribute("ServerWinsBoostExpiresUnix", previousSnowWinsExpire)
		Workspace:SetAttribute("ServerWinsBoostMultiplier", previousSnowWinsMultiplier)
	end
	previousSnowWinsExpire = nil
	previousSnowWinsMultiplier = nil
	thawWorld()
end

local function startSnow(duration: number)
	stopSnow()
	local token = HttpService:GenerateGUID(false)
	eventTokens.Snow = token
	previousSnowWinsExpire = tonumber(Workspace:GetAttribute("ServerWinsBoostExpiresUnix"))
	previousSnowWinsMultiplier = tonumber(Workspace:GetAttribute("ServerWinsBoostMultiplier"))
	Workspace:SetAttribute("AdminSnowUntil", os.time() + duration)
	if not previousSnowWinsExpire or previousSnowWinsExpire <= os.time() or (previousSnowWinsMultiplier or 1) <= 2 then
		Workspace:SetAttribute("ServerWinsBoostExpiresUnix", Workspace:GetAttribute("AdminSnowUntil"))
		Workspace:SetAttribute("ServerWinsBoostMultiplier", 2)
	end
	freezeWorld()
	task.delay(duration, function()
		if eventTokens.Snow == token then
			stopSnow()
		end
	end)
end

local function stopEvent(name: string)
	if name == "Disco" then
		stopDisco()
		return
	elseif name == "Snow" then
		stopSnow()
		return
	elseif name == "Sandstorm" then
		if stopSandstorm then
			stopSandstorm()
		end
		return
	end
	eventTokens[name] = nil
	local object = Lighting:FindFirstChild("Admin" .. name)
	if object then
		object:Destroy()
	end
	Panel:FireAllClients({ kind = "Effect", effect = name, duration = 0 })
end

----------------------------------------------------------------------
-- Boosts, treadmills, music, announcements
----------------------------------------------------------------------
local function boost(stat: string, multiplier: number, minutes: number, byName: string)
	if stat == "Speed" then
		local grant = PotionServer.GrantServerBoost(minutes, multiplier, byName)
		if grant and grant.Notify then
			grant.Notify()
		end
	else
		for _, player in Players:GetPlayers() do
			pcall(function()
				local grant = PotionServer.GrantWinsPotion(player, minutes, multiplier)
				if grant and grant.Notify then
					grant.Notify()
				end
			end)
		end
	end
end

-- `by` is the admin who started it (the disco's DJ).
local function runEvent(name: string, duration: number, enabled: boolean, by: { UserId: number, Name: string }?)
	if not enabled then
		stopEvent(name)
		return
	end
	if name == "Disco" then
		startDisco(duration, by)
	elseif name == "Snow" then
		startSnow(duration)
		local minutes = math.max(1, math.ceil(duration / 60))
		boost("Speed", 2, minutes, if by and by.Name then by.Name else "Blizzard")
	elseif name == "Sandstorm" then
		startSandstorm(duration)
	elseif name == "Confetti" then
		Panel:FireAllClients({ kind = "Effect", effect = "Confetti", duration = duration })
		local minutes = math.max(1, math.ceil(duration / 60))
		boost("Wins", 2, minutes, if by and by.Name then by.Name else "Confetti Party")
	elseif name == "Fireworks" then
		-- Rockets go up from the lobby's dance floor (AdminAbuseEffects draws them).
		local floor, size = discoFloor()
		Panel:FireAllClients({ kind = "Effect", effect = "Fireworks", duration = duration, origin = floor, size = size })
	end
end

local TREADMILL_FOLDER = "AdminSpawnedTreadmills"

-- Where a treadmill model stands and which way its runner faces, read from its parts: the
-- belt runs along its longest low part, the runner faces the end with the tall handle
-- posts, and the model rests on its lowest corner.
type TreadmillFrame = { Centre: Vector3, Belt: Vector3, Bottom: number, BeltTop: number, Face: Vector3 }
local function treadmillFrame(model: Model): TreadmillFrame?
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			local half = descendant.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
						high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
					end
				end
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	local centre = (low + high) / 2
	local axis, longest, beltTop = nil, 0, low.Y
	local beltSum, beltCount = Vector3.zero, 0
	for _, part in parts do
		local cframe = part.CFrame
		if part.Size.Y < 4 and cframe.Position.Y < low.Y + 4 then
			beltTop = math.max(beltTop, cframe.Position.Y + part.Size.Y / 2)
			beltSum += cframe.Position
			beltCount += 1
			for _, pair in { { part.Size.X, cframe.RightVector }, { part.Size.Z, cframe.LookVector } } do
				local flat = pair[2] * Vector3.new(1, 0, 1)
				if pair[1] > longest and flat.Magnitude > 0.9 then
					longest, axis = pair[1], flat.Unit
				end
			end
		end
	end
	if not axis then
		return nil
	end
	local handles, count = 0, 0
	for _, part in parts do
		if part.CFrame.Position.Y > low.Y + 6 then
			handles += (part.CFrame.Position - centre):Dot(axis)
			count += 1
		end
	end
	local face = if count > 0 and handles < 0 then -axis else axis
	local belt = beltSum / beltCount
	return { Centre = Vector3.new(centre.X, low.Y, centre.Z), Belt = Vector3.new(belt.X, beltTop, belt.Z), Bottom = low.Y, BeltTop = beltTop, Face = face }
end

-- Moves every part of a treadmill so it stands on `floor` at `position` (x, z) with its
-- runner facing along `face`. Returns where a player stands on the belt.
local function placeTreadmill(model: Model, position: Vector3, floorY: number, face: Vector3): Vector3?
	local frame = treadmillFrame(model)
	if not frame then
		return nil
	end
	local function heading(direction: Vector3): number
		return math.atan2(-direction.Z, direction.X)
	end
	local turn = heading(face) - heading(frame.Face)
	local function moveBy(move: CFrame)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CFrame = move * descendant.CFrame
			end
		end
	end
	moveBy(CFrame.Angles(0, turn, 0))
	-- Turned, its footprint has a new middle and bottom: set those on the spot.
	local turned = treadmillFrame(model) :: TreadmillFrame
	moveBy(CFrame.new(Vector3.new(position.X, floorY, position.Z) - turned.Centre))
	local placed = treadmillFrame(model) :: TreadmillFrame
	-- On the middle of the belt, a step back from the handles.
	return placed.Belt + Vector3.new(0, 3, 0) - placed.Face * 3
end

-- This lobby's treadmill spot (Config.AdminTreadmill). A place without one gets a spot
-- beside its spawn.
local function treadmillSpot(): (Vector3, Vector3)
	local settings = Config.AdminTreadmill
	local key = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" elseif Config.IsNewWorld1Map then "World1" else nil
	local spot = key and settings and settings.WorldPlacement and settings.WorldPlacement[key]
	if spot and typeof(spot.Position) == "Vector3" and typeof(spot.Face) == "Vector3" then
		local face = (spot.Face - spot.Position) * Vector3.new(1, 0, 1)
		if face.Magnitude > 0.1 then
			return spot.Position, face.Unit
		end
	end
	return lobbyCenter() + Vector3.new(0, 0, -30), Vector3.new(1, 0, 0)
end

-- The floor under a spot: the first solid thing a ray from above meets, skipping players
-- and admin treadmills; the spot's own height when the ray finds nothing.
local function floorAt(position: Vector3): number
	local ignore: { Instance } = {}
	local folder = Workspace:FindFirstChild(TREADMILL_FOLDER)
	if folder then
		table.insert(ignore, folder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else position.Y
end

-- The spawned treadmill is a show: every part glows (every client turns the colours into
-- a rainbow, AdminAbuseEffects), a big ADMIN TREADMILL sign floats over it, and it wears
-- the game's own aura effects (ServerStorage.AuthoredAuras) and confetti.
local TREADMILL_AURAS = { "LightningAura", "Musical", "Shidou" }
-- The Speed a step on it pays: the Admin3000 profile's, the Hacker treadmill's plus 5%.
local function adminTreadmillSpeedGain(): number
	local gains = Config.TreadmillBaseGains
	return tonumber(gains and gains.Admin3000) or 315
end
local MAX_EMITTERS_PER_AURA = 4
local function dressAdminTreadmill(model: Model, multiplier: number, minutes: number)
	model:SetAttribute("AdminRainbow", true)
	model:SetAttribute("AdminMultiplier", multiplier)
	model:SetAttribute("AdminExpiresAt", os.time() + minutes * 60)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.Neon
		end
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = "AdminTreadmillVFX"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Size = Vector3.new(math.max(4, boxSize.X), 1, math.max(4, boxSize.Z))
	anchor.CFrame = boxCFrame * CFrame.new(0, boxSize.Y / 2, 0)
	anchor.Parent = model
	local light = Instance.new("PointLight")
	light.Name = "RainbowLight"
	light.Range = 40
	light.Brightness = 5
	light.Parent = anchor
	local auras = ServerStorage:FindFirstChild("AuthoredAuras")
	for _, auraName in TREADMILL_AURAS do
		local aura = auras and auras:FindFirstChild(auraName)
		local added = 0
		for _, source in if aura then aura:GetDescendants() else {} do
			if source:IsA("ParticleEmitter") and added < MAX_EMITTERS_PER_AURA then
				local emitter = source:Clone()
				emitter.Enabled = true
				emitter.Rate = math.clamp(emitter.Rate, 4, 30)
				emitter.Parent = anchor
				added += 1
			end
		end
	end
	local confetti = ServerStorage:FindFirstChild("Confetti")
	for _, source in if confetti then confetti:GetDescendants() else {} do
		if source:IsA("ParticleEmitter") then
			local emitter = source:Clone()
			emitter.Enabled = true
			emitter.Rate = math.clamp(emitter.Rate, 2, 12)
			emitter.Parent = anchor
		end
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "AdminTreadmillSign"
	sign.Size = UDim2.fromScale(26, 8)
	sign.StudsOffsetWorldSpace = Vector3.new(0, boxSize.Y / 2 + 9, 0)
	sign.MaxDistance = 400
	sign.LightInfluence = 0
	sign.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.62)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "ADMIN TREADMILL"
	title.TextColor3 = Color3.new(1, 1, 1)
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 3
	titleStroke.Color = Color3.fromRGB(11, 27, 45)
	titleStroke.Parent = title
	local rainbow = Instance.new("UIGradient")
	rainbow.Name = "Rainbow"
	rainbow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 240, 80)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 170)),
	})
	rainbow.Parent = title
	title.Parent = sign
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0, 0.62)
	subtitle.Size = UDim2.fromScale(1, 0.38)
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextScaled = true
	local speedGain = model:GetAttribute("AdminSpeedGain")
	subtitle.Text = (if speedGain then "x" .. speedGain .. " Speed + " else "") .. "x" .. multiplier .. " Wins - hop on!"
	subtitle.TextColor3 = Color3.fromRGB(255, 230, 90)
	local subtitleStroke = Instance.new("UIStroke")
	subtitleStroke.Thickness = 2
	subtitleStroke.Color = Color3.fromRGB(11, 27, 45)
	subtitleStroke.Parent = subtitle
	subtitle.Parent = sign
end
local function spawnTreadmill(admin: Player, multiplier: number, minutes: number): (boolean, string)
	local neworld1 = Workspace:FindFirstChild("neworld1")
	local template = ReplicatedStorage:FindFirstChild("Admin") or (neworld1 and neworld1:FindFirstChild("Basic"))
	if not template or not template:IsA("Model") then
		return false, "Treadmill template not found"
	end
	local folder = Workspace:FindFirstChild(TREADMILL_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TREADMILL_FOLDER
		folder.Parent = Workspace
	end
	-- One admin treadmill at a time, always on the lobby's spot: a new one replaces it.
	folder:ClearAllChildren()
	-- TreadmillTraining pays its Wins with the admin's multiplier; its Speed is the Admin3000
	-- profile's (the Hacker treadmill's plus 5%), whatever the multiplier.
	_G.AdminTreadmillWinMult = multiplier
	local clone = template:Clone()
	clone.Name = "AdminTreadmill"
	clone:SetAttribute("AdminSpawned", true)
	clone:SetAttribute("AdminSpawnedBy", admin.UserId)
	clone:SetAttribute("AdminSpawnedAt", os.time())
	clone:SetAttribute("TreadmillTrainingSourceName", "Admin3000")
	clone:SetAttribute("AdminSpeedGain", adminTreadmillSpeedGain())
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	-- Placed before it is parented, so the treadmill systems only ever see it in place.
	local position, face = treadmillSpot()
	local stand = placeTreadmill(clone, position, floorAt(position), face)
	if not stand then
		clone:Destroy()
		return false, "Treadmill template has no belt"
	end
	clone:SetAttribute("AdminTreadmillStand", stand)
	clone:SetAttribute("AdminTreadmillFace", face)
	-- Streaming: every player gets it, so the GO button can send anyone to it.
	clone.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	clone.Parent = folder
	dressAdminTreadmill(clone, multiplier, minutes)
	task.delay(minutes * 60, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)
	return true, "Treadmill x" .. multiplier .. " for " .. minutes .. "m"
end

-- The GO button on the treadmill's reveal: any player, not only admins, is set down on the
-- admin treadmill's belt, facing its handles, from wherever they are.
local TreadmillGo = remote("AdminTreadmillGo")
local function goToTreadmill(player: Player): boolean
	local folder = Workspace:FindFirstChild(TREADMILL_FOLDER)
	local treadmill = folder and folder:FindFirstChild("AdminTreadmill")
	local stand = treadmill and treadmill:GetAttribute("AdminTreadmillStand")
	local face = treadmill and treadmill:GetAttribute("AdminTreadmillFace")
	local character, root, humanoid = aliveRoot(player)
	if typeof(stand) ~= "Vector3" or typeof(face) ~= "Vector3" or not character or not root or not humanoid then
		return false
	end
	-- The places stream: load the ground there before the player lands on it.
	pcall(function()
		player:RequestStreamAroundAsync(stand, 3)
	end)
	if character.Parent == nil or humanoid.Health <= 0 then
		return false
	end
	humanoid.Sit = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(stand, stand + face))
	return true
end
TreadmillGo.OnServerEvent:Connect(function(player: Player)
	if RateLimiter.Allow(player, "AdminTreadmillGo", 1) then
		goToTreadmill(player)
	end
end)

local function musicTracks(): { { Name: string, Id: string } }
	local list = {}
	local folder = ReplicatedStorage:FindFirstChild("Music")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Sound") and child.SoundId ~= "" then
				table.insert(list, { Name = child.Name, Id = child.SoundId })
			end
		end
	end
	for index, track in Config.BackgroundMusicTracks or {} do
		local id = tostring(if type(track) == "table" then track.Id else track)
		if string.match(id, "^rbxassetid://%d+$") then
			local name = if type(track) == "table" and track.Name then tostring(track.Name) else "Track " .. index
			table.insert(list, { Name = name, Id = id })
		end
	end
	return list
end

local function playMusic(trackId: string?)
	local sound = Workspace:FindFirstChild("AdminMusic")
	if not trackId then
		if sound then
			sound:Destroy()
		end
		Workspace:SetAttribute("AdminMusicActive", false)
		return
	end
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "AdminMusic"
		sound.Parent = Workspace
	end
	sound.SoundId = trackId
	sound.Looped = true
	sound.Volume = 0.5
	sound:Play()
	Workspace:SetAttribute("AdminMusicActive", true)
end

local ANNOUNCE_THEMES = { Gold = true, Rainbow = true, Alert = true, Ice = true, Party = true }
local function announce(message: string, senderName: string, senderId: number, theme: string?, duration: number?)
	AnnouncementRemote:FireAllClients({
		Message = message,
		EventId = HttpService:GenerateGUID(false),
		OriginJobId = game.JobId,
		SenderName = senderName,
		SenderId = senderId,
		Duration = duration or 8,
		Theme = if theme and ANNOUNCE_THEMES[theme] then theme else "Gold",
		Timestamp = os.time(),
	})
end

----------------------------------------------------------------------
-- Moderation
----------------------------------------------------------------------
local mutedUntil: { [number]: number } = {}

local function setCanSend(player: Player, canSend: boolean)
	local channels = TextChatService:FindFirstChild("TextChannels")
	if not channels then
		return
	end
	for _, channel in channels:GetChildren() do
		if channel:IsA("TextChannel") then
			local source = channel:FindFirstChild(player.Name)
			if source and source:IsA("TextSource") then
				source.CanSend = canSend
			end
		end
	end
end

local function commit(target: Player, commands: { any }, reason: string): boolean
	if target:GetAttribute("DataLoaded") ~= true then
		return false
	end
	local handle = DataService.GetHandle(target.UserId)
	if not handle then
		return false
	end
	local ok, result = pcall(DataService.Commit, handle, {
		operationId = DataService.NewOperationId(),
		fingerprint = reason,
		commands = commands,
	})
	return ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted")
end

-- The player's stats on their HUD and walk speed, after a grant.
local function refreshStats(victim: Player)
	if type(_G.SpeedsterApplyWalkSpeed) == "function" then
		pcall(_G.SpeedsterApplyWalkSpeed, victim)
	end
	if type(_G.SpeedsterSyncRebirthAttributes) == "function" then
		pcall(_G.SpeedsterSyncRebirthAttributes, victim)
	end
end

-- Gamepasses given or taken by an admin: the saved perk first, then the session flags
-- the game reads, once the profile has confirmed.
local PASSES = { VIP = true, Flight = true, TwoXSpeed = true, TwoXVictory = true, InfiniteRevives = true, DarkZonic = true, All = true }
local function setPass(victim: Player, pass: string, enabled: boolean): boolean
	local commands = {}
	for _, id in { "VIP", "Flight", "TwoXSpeed", "TwoXVictory", "InfiniteRevives", "DarkZonic" } do
		if pass == id or pass == "All" then
			if id == "DarkZonic" then
				table.insert(commands, { kind = if enabled then "GrantSkin" else "RemoveSkin", skinId = id })
			else
				table.insert(commands, { kind = if enabled then "GrantUpgrade" else "RemoveUpgrade", upgradeId = id })
			end
			if id == "Flight" then
				table.insert(commands, { kind = "SetAbilityEquipped", equipped = enabled })
			elseif id == "TwoXSpeed" then
				table.insert(commands, { kind = "SetPersistent", key = "PermanentBaseSpeedMultiplier", value = if enabled then 2 else 1 })
			end
		end
	end
	if not commit(victim, commands, "admin_abuse_pass:" .. pass .. ":" .. tostring(enabled)) then
		return false
	end
	if pass == "VIP" or pass == "All" then
		victim:SetAttribute("VIPGamepassOwned", enabled)
		victim:SetAttribute("VIPSpeedGainMultiplier", if enabled then (tonumber(Config.VipSpeedGainMultiplier) or 2) else 1)
		victim:SetAttribute("VIPWinsMultiplier", if enabled then (tonumber(Config.VipWinsMultiplier) or 2) else 1)
	end
	if pass == "TwoXSpeed" or pass == "All" then
		victim:SetAttribute("GamepassSpeedGainMultiplier", if enabled then 2 else 1)
	end
	if pass == "TwoXVictory" or pass == "All" then
		victim:SetAttribute("DoubleWinsPadUnlocked", enabled)
		victim:SetAttribute("TwoXVictoryOwned", enabled)
	end
	if pass == "InfiniteRevives" or pass == "All" then
		victim:SetAttribute("InfiniteRevivesOwned", enabled)
		victim:SetAttribute("InfiniteRevivesOwnershipChecked", true)
	end
	if pass == "DarkZonic" or pass == "All" then
		victim:SetAttribute("DarkZonicOwned", enabled)
	end
	refreshStats(victim)
	if type(_G.SpeedsterRefreshAbilityShop) == "function" then
		pcall(_G.SpeedsterRefreshAbilityShop, victim)
	end
	return true
end

-- Unlock All Cosmetics: every aura and trail the Backpack holds and every skin the Index
-- shows (the evolutions and the Spin Wheel's), free, on the admin's own account, in one
-- commit. Then the showcase set goes on: Aura 67, Trail 67 and Tung Tung Sahur. The paid
-- limited (Dark Zonic) has a stock of its own and stays with the Gamepasses tools.
-- The pass treadmills (the same passes in every world): the admin panel gives one, or all,
-- to the target as a gift saved on their profile ("GiftedPass:<passId>", the way a gift
-- product's receipt does), and the treadmills let them on at once
-- (Progression/TreadmillTraining, GiftedPasses). Taking it away removes the saved gift; a
-- pass bought with Robux stays theirs.
local function treadmillPasses(): { [string]: number }
	local profiles = Config.World2TreadmillProfiles or {}
	local list = {}
	for _, name in { "Needoh", "Admin", "Hacker" } do
		local passId = tonumber(profiles[name] and profiles[name].GamePassId)
		if passId and passId > 0 then
			list[name] = passId
		end
	end
	return list
end
local function setTreadmill(victim: Player, name: string, enabled: boolean): boolean
	local passes = treadmillPasses()
	local commands = {}
	for passName, passId in passes do
		if name == passName or name == "All" then
			table.insert(commands, { kind = if enabled then "GrantUpgrade" else "RemoveUpgrade", upgradeId = "GiftedPass:" .. passId })
		end
	end
	if #commands == 0 or not commit(victim, commands, "admin_abuse_treadmill:" .. name .. ":" .. tostring(enabled)) then
		return false
	end
	if type(_G.SpeedsterForgetTreadmillPasses) == "function" then
		pcall(_G.SpeedsterForgetTreadmillPasses, victim)
	end
	return true
end

local UNLOCK_SHOWCASE = { Aura = "Aura67", Trail = "Trail15", Skin = "TungTungSuit" }
local function unlockAllCosmetics(player: Player): (boolean, string)
	local commands = {}
	local auras = CosmeticCatalog.GetSortedOwnableEntries("Aura")
	local trails = CosmeticCatalog.GetSortedOwnableEntries("Trail")
	for _, entry in auras do
		table.insert(commands, { kind = "GrantAura", auraId = entry.Id })
	end
	for _, entry in trails do
		table.insert(commands, { kind = "GrantTrail", trailId = entry.Id })
	end
	local skins = 0
	for _, list in { SuitCatalog.Ordered, SuitCatalog.Exclusive or {} } do
		for _, entry in list do
			table.insert(commands, { kind = "GrantSkin", skinId = entry.Id })
			skins += 1
		end
	end
	table.insert(commands, { kind = "EquipAura", auraId = UNLOCK_SHOWCASE.Aura })
	table.insert(commands, { kind = "EquipTrail", trailId = UNLOCK_SHOWCASE.Trail })
	if not commit(player, commands, "admin_unlock_cosmetics") then
		return false, "Your data is not ready yet"
	end
	-- What the player sees: the aura and trail on the character, EQUIP on every card, the skin.
	local cosmetics = _G.SpeedsterCosmetics
	if type(cosmetics) == "table" and type(cosmetics.Equip) == "function" then
		pcall(cosmetics.Equip, player, "Aura", UNLOCK_SHOWCASE.Aura)
		pcall(cosmetics.Equip, player, "Trail", UNLOCK_SHOWCASE.Trail)
	end
	for _, refresh in { _G.SpeedsterRefreshAuraShop, _G.SpeedsterRefreshTrailShop } do
		if type(refresh) == "function" then
			pcall(refresh, player, "Unlocked by an admin")
		end
	end
	local wearing = false
	if type(_G.SpeedsterAdminGiveSkin) == "function" then
		local ok, applied = pcall(_G.SpeedsterAdminGiveSkin, player, UNLOCK_SHOWCASE.Skin)
		wearing = ok and applied == true
	end
	return true, ("Unlocked %d auras, %d trails and %d skins%s"):format(#auras, #trails, skins,
		if wearing then "; wearing Aura 67, Trail 67 and Tung Tung" else "; wearing Aura 67 and Trail 67")
end

----------------------------------------------------------------------
-- Cross-server
----------------------------------------------------------------------
local function publish(action: string, data: { [string]: any })
	local eventId = HttpService:GenerateGUID(false)
	acceptEvent(eventId, os.time())
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(TOPIC, { Action = action, Data = data, EventId = eventId, OriginJobId = game.JobId, Timestamp = os.time() })
		end)
		if not ok then
			warn("[AdminAbusePanel] Could not reach the other servers: " .. tostring(err))
		end
	end)
end

local function runShared(action: string, data: any)
	if action == "Abuse" then
		applyAbuse(nil, tostring(data.effect), "All", number(data.duration, 10, 1, 120), string.sub(tostring(data.byName or "Admin"), 1, 32))
	elseif action == "Event" then
		runEvent(tostring(data.name), number(data.duration, 60, 5, 900), data.enabled == true, {
			UserId = number(data.byId, 0, 0, 1e12),
			Name = string.sub(tostring(data.byName or "Admin"), 1, 32),
		})
	elseif action == "Boost" then
		boost(if data.stat == "Wins" then "Wins" else "Speed", number(data.multiplier, 2, 1, 100), number(data.minutes, 15, 1, 240), tostring(data.byName))
	elseif action == "Announce" then
		announce(tostring(data.message), tostring(data.byName), number(data.byId, 0, 0, 1e12), tostring(data.theme or "Gold"), number(data.duration, 8, 4, 30))
	end
end

task.spawn(function()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local payload = message and message.Data
			if type(payload) ~= "table" or payload.OriginJobId == game.JobId or type(payload.Data) ~= "table" then
				return
			end
			if not Validation.Finite(payload.Timestamp) or math.abs(os.time() - payload.Timestamp) > 600 then
				return
			end
			if not acceptEvent(payload.EventId, os.time()) then
				return
			end
			runShared(tostring(payload.Action), payload.Data)
		end)
	end)
end)

----------------------------------------------------------------------
-- Requests
----------------------------------------------------------------------
local ABUSE = { Rocket = true, Ragdoll = true, Jail = true, Balloon = true, Tiny = true, Inverse = true, Control = true, Jumpscare = true, NoGravity = true, Snail = true, FakeReset = true }
local EVENTS = { Disco = true, Snow = true, Sandstorm = true, Confetti = true, Fireworks = true }

Panel.OnServerEvent:Connect(function(admin: Player, payload: any)
	if type(payload) ~= "table" or type(payload.action) ~= "string" or #payload.action > 32 then
		return
	end
	if not RateLimiter.Allow(admin, "AdminAbusePanel", 0.3) then
		return
	end
	if not isAllowed(admin) then
		Panel:FireClient(admin, { kind = "Permission", allowed = false })
		return
	end
	local action = payload.action
	local everywhere = payload.scope == "All"
	local target = if payload.target == "All" then "All" else tonumber(payload.target)
	local byName = admin.DisplayName

	if action == "Hello" then
		Panel:FireClient(admin, { kind = "Permission", allowed = true, tracks = musicTracks() })
	elseif action == "Abuse" and ABUSE[payload.effect] then
		local duration = number(payload.duration, 10, 1, 120)
		local done, total = applyAbuse(admin, payload.effect, target, duration)
		if everywhere and target == "All" then
			publish("Abuse", { effect = payload.effect, duration = duration, byName = byName })
		end
		toast(admin, done > 0, payload.effect .. ": " .. done .. "/" .. total .. (if everywhere and target == "All" then " (+ all servers)" else ""))
	elseif action == "Event" and EVENTS[payload.name] then
		local duration = number(payload.duration, 60, 5, 900)
		local enabled = payload.enabled ~= false
		runEvent(payload.name, duration, enabled, { UserId = admin.UserId, Name = byName })
		if everywhere then
			publish("Event", { name = payload.name, duration = duration, enabled = enabled, byId = admin.UserId, byName = byName })
		end
		toast(admin, true, payload.name .. (if enabled then " on for " .. math.floor(duration) .. "s" else " off") .. (if everywhere then " (all servers)" else ""))
	elseif action == "Boost" then
		local stat = if payload.stat == "Wins" then "Wins" else "Speed"
		local multiplier = math.floor(number(payload.multiplier, 2, 1, 100))
		local minutes = math.floor(number(payload.minutes, 15, 1, 240))
		boost(stat, multiplier, minutes, byName)
		if everywhere then
			publish("Boost", { stat = stat, multiplier = multiplier, minutes = minutes, byName = byName })
		end
		toast(admin, true, multiplier .. "x " .. stat .. " for " .. minutes .. "m" .. (if everywhere then " (all servers)" else ""))
	elseif action == "Treadmill" then
		local multiplier = math.floor(number(payload.multiplier, 5, 1, 100))
		local minutes = math.floor(number(payload.minutes, 10, 1, 120))
		local ok, message = spawnTreadmill(admin, multiplier, minutes)
		local withDisco = ok and payload.withDisco == true
		toast(admin, ok, message .. (if withDisco then ", with a Disco Party" else ""))
		if ok then
			-- The places stream: load the treadmill's corner of the lobby for every player now,
			-- so anyone flown there to watch it rise sees the lobby round it, not the void.
			local folder = Workspace:FindFirstChild(TREADMILL_FOLDER)
			local spawned = folder and folder:FindFirstChild("AdminTreadmill")
			local stand = spawned and spawned:GetAttribute("AdminTreadmillStand")
			if typeof(stand) == "Vector3" then
				for _, player in Players:GetPlayers() do
					task.spawn(function()
						pcall(function()
							player:RequestStreamAroundAsync(stand, 3)
						end)
					end)
				end
			end
			if withDisco then
				runEvent("Disco", math.min(minutes * 60, 900), true, { UserId = admin.UserId, Name = admin.DisplayName })
			end
			-- Everyone on the server gets the show and its GO button (AdminTreadmillReveal).
			Panel:FireAllClients({
				kind = "TreadmillReveal",
				byName = admin.DisplayName,
				byUserId = admin.UserId,
				multiplier = multiplier,
				speedGain = adminTreadmillSpeedGain(),
				expiresAt = os.time() + minutes * 60,
			})
		end
	elseif action == "ClearTreadmills" then
		local folder = Workspace:FindFirstChild(TREADMILL_FOLDER)
		local count = if folder then #folder:GetChildren() else 0
		if folder then
			folder:ClearAllChildren()
		end
		toast(admin, true, "Removed " .. count .. " admin treadmill(s)")
	elseif action == "PlayMusic" then
		local id = tostring(payload.trackId or "")
		local allowed = false
		for _, track in musicTracks() do
			if track.Id == id then
				allowed = true
			end
		end
		if allowed then
			playMusic(id)
			toast(admin, true, "Now playing")
		else
			toast(admin, false, "Pick a track first")
		end
	elseif action == "StopMusic" then
		playMusic(nil)
		toast(admin, true, "Music stopped")
	elseif action == "Announce" then
		local raw = string.match(tostring(payload.message or ""), "^%s*(.-)%s*$") or ""
		if raw == "" then
			toast(admin, false, "Write a message first")
			return
		end
		local filtered = Validation.FilterBroadcast(TextService, admin.UserId, string.sub(raw, 1, 250))
		if not filtered then
			toast(admin, false, "Text filtering is unavailable; nothing was sent")
			return
		end
		local theme = if ANNOUNCE_THEMES[payload.theme] then payload.theme else "Gold"
		local seconds = math.floor(number(payload.duration, 8, 4, 30))
		announce(filtered, byName, admin.UserId, theme, seconds)
		if everywhere then
			publish("Announce", { message = filtered, byName = byName, byId = admin.UserId, theme = theme, duration = seconds })
		end
		toast(admin, true, "Message sent" .. (if everywhere then " to all servers" else ""))
	elseif action == "Kick" or action == "Ban" or action == "Mute" or action == "Unmute" or action == "GoTo" or action == "Bring" then
		local victims = if target == "All" then {} else targetsFor(nil, target)
		local victim = victims[1]
		if not victim then
			toast(admin, false, "Select one player")
			return
		end
		if victim ~= admin and isAllowed(victim) and (action == "Kick" or action == "Ban" or action == "Mute") then
			toast(admin, false, "Admins cannot be moderated here")
			return
		end
		local reason = string.sub(tostring(payload.reason or ""), 1, 120)
		if action == "Kick" then
			victim:Kick(if reason ~= "" then "Kicked by an admin: " .. reason else "Kicked by an admin")
			toast(admin, true, "Kicked " .. victim.Name)
		elseif action == "Ban" then
			local hours = number(payload.hours, 0, 0, 24 * 365)
			local ok, err = pcall(function()
				Players:BanAsync({
					UserIds = { victim.UserId },
					ApplyToUniverse = true,
					Duration = if hours > 0 then math.floor(hours * 3600) else -1,
					DisplayReason = if reason ~= "" then reason else "Banned by an admin",
					PrivateReason = "Admin Abuse Panel ban by " .. admin.Name .. " (" .. admin.UserId .. ")",
					ExcludeAltAccounts = false,
				})
			end)
			toast(admin, ok, if ok then "Banned " .. victim.Name else "Ban failed: " .. tostring(err))
		elseif action == "Mute" then
			local minutes = number(payload.minutes, 10, 1, 1440)
			mutedUntil[victim.UserId] = os.time() + minutes * 60
			setCanSend(victim, false)
			toast(admin, true, "Muted " .. victim.Name .. " for " .. math.floor(minutes) .. "m")
		elseif action == "Unmute" then
			mutedUntil[victim.UserId] = nil
			setCanSend(victim, true)
			toast(admin, true, "Unmuted " .. victim.Name)
		elseif action == "GoTo" then
			local _, victimRoot = aliveRoot(victim)
			local adminCharacter = aliveRoot(admin)
			if victimRoot and adminCharacter then
				adminCharacter:PivotTo(victimRoot.CFrame * CFrame.new(0, 0, 4))
				toast(admin, true, "Teleported to " .. victim.Name)
			else
				toast(admin, false, "Both characters must be alive")
			end
		elseif action == "Bring" then
			local victimCharacter = aliveRoot(victim)
			local _, adminRoot = aliveRoot(admin)
			if victimCharacter and adminRoot then
				victimCharacter:PivotTo(adminRoot.CFrame * CFrame.new(0, 0, -4))
				toast(admin, true, "Brought " .. victim.Name)
			else
				toast(admin, false, "Both characters must be alive")
			end
		end
	elseif action == "Unban" then
		local query = string.match(tostring(payload.target or payload.userId or payload.username or target or ""), "^%s*(.-)%s*$") or ""
		if query == "" or query == "All" then
			toast(admin, false, "Provide a Username or UserId to unban")
			return
		end
		local targetUserId = tonumber(query)
		if not targetUserId then
			local okName, resolvedId = pcall(function()
				return Players:GetUserIdFromNameAsync(query)
			end)
			if okName and resolvedId then
				targetUserId = resolvedId
			end
		end
		if not targetUserId or targetUserId <= 0 then
			toast(admin, false, "User not found: " .. query)
			return
		end
		local ok, err = pcall(function()
			Players:UnbanAsync({
				UserIds = { targetUserId },
				ApplyToUniverse = true,
			})
		end)
		if ok then
			toast(admin, true, "Unbanned UserId " .. targetUserId)
		else
			toast(admin, false, "Unban failed: " .. tostring(err))
		end
	elseif action == "UnlockCosmetics" then
		-- Only ever the admin's own account.
		local ok, message = unlockAllCosmetics(admin)
		toast(admin, ok, message)
	elseif action == "GiveSpeed" or action == "RemoveSpeed" then
		local amount = math.floor(number(payload.amount, 0, 0, 1e15))
		if amount <= 0 then
			toast(admin, false, "Enter an amount")
			return
		end
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			local command = if action == "GiveSpeed"
				then { kind = "GrantExact", stat = "Speed", amount = amount }
				else { kind = "DebitSpeed", amount = amount }
			if commit(victim, { command }, "admin_abuse_" .. string.lower(action) .. ":" .. amount) then
				done += 1
				if type(_G.SpeedsterApplyWalkSpeed) == "function" then
					pcall(_G.SpeedsterApplyWalkSpeed, victim)
				end
			end
		end
		toast(admin, done > 0, (if action == "GiveSpeed" then "+" else "-") .. amount .. " Speed: " .. done .. "/" .. #victims)
	elseif action == "GiveStat" then
		local stat = if payload.stat == "Wins" then "Wins" elseif payload.stat == "Rebirths" then "Rebirths" elseif payload.stat == "Tickets" or payload.stat == "SpinTickets" then "SpinTickets" else "Speed"
		local amount = math.floor(number(payload.amount, 0, 0, if stat == "Rebirths" then 10000 elseif stat == "SpinTickets" then 100000 else 1e15))
		if amount <= 0 then
			toast(admin, false, "Enter an amount")
			return
		end
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			local command = if stat == "SpinTickets"
				then { kind = "GrantSpinTickets", amount = amount }
				else { kind = "GrantExact", stat = stat, amount = amount }
			if commit(victim, { command }, "admin_abuse_give:" .. stat .. ":" .. amount) then
				done += 1
				if stat == "SpinTickets" then
					local cur = tonumber(victim:GetAttribute("SpinTickets")) or 0
					victim:SetAttribute("SpinTickets", cur + amount)
				else
					refreshStats(victim)
				end
			end
		end
		toast(admin, done > 0, "+" .. amount .. " " .. stat .. ": " .. done .. "/" .. #victims)
	elseif action == "RemoveStat" then
		local stat = if payload.stat == "Wins" then "Wins" elseif payload.stat == "Rebirths" then "Rebirths" elseif payload.stat == "Tickets" or payload.stat == "SpinTickets" then "SpinTickets" else "Speed"
		local amount = math.floor(number(payload.amount, 0, 0, if stat == "Rebirths" then 10000 elseif stat == "SpinTickets" then 100000 else 1e15))
		if amount <= 0 then
			toast(admin, false, "Enter an amount")
			return
		end
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			local command = { kind = "DebitStat", stat = stat, amount = amount }
			if commit(victim, { command }, "admin_abuse_remove:" .. stat .. ":" .. amount) then
				done += 1
				if stat == "SpinTickets" then
					local cur = tonumber(victim:GetAttribute("SpinTickets")) or 0
					victim:SetAttribute("SpinTickets", math.max(0, cur - amount))
				else
					refreshStats(victim)
				end
			end
		end
		toast(admin, done > 0, "-" .. amount .. " " .. stat .. ": " .. done .. "/" .. #victims)
	elseif action == "SetStat" then
		local stat = if payload.stat == "Wins" then "Wins" elseif payload.stat == "Rebirths" then "Rebirths" elseif payload.stat == "Tickets" or payload.stat == "SpinTickets" then "SpinTickets" else "Speed"
		local amount = math.floor(number(payload.amount, 0, 0, if stat == "Rebirths" then 10000 elseif stat == "SpinTickets" then 100000 else 1e15))
		if amount < 0 then
			toast(admin, false, "Enter a valid amount")
			return
		end
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			local command = { kind = "SetStat", stat = stat, amount = amount }
			if commit(victim, { command }, "admin_abuse_set:" .. stat .. ":" .. amount) then
				done += 1
				if stat == "SpinTickets" then
					victim:SetAttribute("SpinTickets", amount)
				else
					victim:SetAttribute(stat, amount)
					local leaderstats = victim:FindFirstChild("leaderstats")
					if leaderstats then
						local val = leaderstats:FindFirstChild(stat)
						if val and val:IsA("ValueBase") then (val :: any).Value = amount end
					end
					refreshStats(victim)
				end
			end
		end
		toast(admin, done > 0, "Set " .. stat .. " to " .. amount .. ": " .. done .. "/" .. #victims)
	elseif action == "Pass" then
		local pass = tostring(payload.pass or "")
		if not PASSES[pass] then
			toast(admin, false, "Pick a gamepass")
			return
		end
		local enabled = payload.enabled == true
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			if setPass(victim, pass, enabled) then
				done += 1
			end
		end
		toast(admin, done > 0, (if enabled then "Gave " else "Removed ") .. pass .. ": " .. done .. "/" .. #victims)
	elseif action == "GrantTreadmill" then
		local name = tostring(payload.treadmill or "")
		if name ~= "All" and not treadmillPasses()[name] then
			toast(admin, false, "Pick a treadmill")
			return
		end
		local enabled = payload.enabled == true
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			if setTreadmill(victim, name, enabled) then
				done += 1
			end
		end
		toast(admin, done > 0, (if enabled then "Gave the " else "Took the ") .. name .. " treadmill: " .. done .. "/" .. #victims)
	elseif action == "ForceRebirth" then
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			if type(_G.SpeedsterPerformRebirth) == "function" then
				local ok, result = pcall(_G.SpeedsterPerformRebirth, victim, true)
				if ok and result ~= false then
					done += 1
				end
			end
		end
		toast(admin, done > 0, "Rebirth: " .. done .. "/" .. #victims)
	elseif action == "RedeemCode" then
		local code = string.match(tostring(payload.code or ""), "^%s*(.-)%s*$") or ""
		if code == "" or #code > 64 then
			toast(admin, false, "Write a code first")
			return
		end
		if type(_G.SpeedsterRedeemCode) ~= "function" then
			toast(admin, false, "Codes are still loading")
			return
		end
		local done, victims, lastMessage = 0, targetsFor(nil, target), ""
		for _, victim in victims do
			local ok, granted, message = pcall(_G.SpeedsterRedeemCode, victim, code, true, byName)
			if ok and granted then
				done += 1
			elseif ok then
				lastMessage = tostring(message or "")
			end
		end
		toast(admin, done > 0, "Code " .. code .. ": " .. done .. "/" .. #victims .. (if done == 0 and lastMessage ~= "" then " (" .. lastMessage .. ")" else ""))
	elseif action == "Travel" then
		local world = math.floor(number(payload.world, 0, 0, 3))
		if world < 1 then
			toast(admin, false, "Pick a world")
			return
		end
		if type(_G.SpeedsterAdminWorldTravel) ~= "function" then
			toast(admin, false, "World travel is still loading")
			return
		end
		pcall(_G.SpeedsterAdminWorldTravel, admin, world)
		toast(admin, true, "Travelling to World " .. world .. "...")
	elseif action == "ResetStats" then
		local done, victims = 0, targetsFor(nil, target)
		for _, victim in victims do
			if commit(victim, { { kind = "ResetStats", resetSpeedTo = 1 } }, "admin_abuse_resetstats") then
				done += 1
				victim:SetAttribute("Speed", 1)
				victim:SetAttribute("Wins", 0)
				victim:SetAttribute("Rebirths", 0)
				victim:SetAttribute("Level", 1)
				if type(_G.SpeedsterApplyWalkSpeed) == "function" then
					pcall(_G.SpeedsterApplyWalkSpeed, victim)
				end
				if type(_G.SpeedsterSyncRebirthAttributes) == "function" then
					pcall(_G.SpeedsterSyncRebirthAttributes, victim)
				end
			end
		end
		toast(admin, done > 0, "Reset stats: " .. done .. "/" .. #victims)
	elseif action == "WipeData" or action == "WipeProfile" then
		if target == "All" then
			toast(admin, false, "Full Wipe cannot be run on 'All' players for safety. Target a specific player.")
			return
		end
		local victims = targetsFor(nil, target)
		if #victims == 0 then
			toast(admin, false, "Select one player")
			return
		end
		local done = 0
		for _, victim in victims do
			if commit(victim, { { kind = "WipeProfile", resetSpeedTo = 1 } }, "admin_abuse_wipe:" .. victim.UserId .. ":" .. os.time()) then
				done += 1
				victim:SetAttribute("Speed", 1)
				victim:SetAttribute("Wins", 0)
				victim:SetAttribute("Rebirths", 0)
				victim:SetAttribute("Level", 1)
				victim:SetAttribute("World2Unlocked", false)
				victim:SetAttribute("World3Unlocked", false)
				victim:SetAttribute("EquippedSkin", "Default")
				victim:SetAttribute("EquippedAura", "")
				victim:SetAttribute("EquippedTrail", "")
				victim:SetAttribute("SpinTickets", 0)
				victim:SetAttribute("QuestRewardReady", false)
				victim:SetAttribute("VIPGamepassOwned", false)
				victim:SetAttribute("VIPSpeedGainMultiplier", 1)
				victim:SetAttribute("VIPWinsMultiplier", 1)
				victim:SetAttribute("GamepassSpeedGainMultiplier", 1)
				victim:SetAttribute("DoubleWinsPadUnlocked", false)
				victim:SetAttribute("TwoXVictoryOwned", false)
				victim:SetAttribute("InfiniteRevivesOwned", false)
				victim:SetAttribute("InfiniteRevivesOwnershipChecked", false)
				victim:SetAttribute("DarkZonicOwned", false)
				victim:SetAttribute("FlightGamepassOwned", false)
				victim:SetAttribute("FlightAbilityOwned", false)
				victim:SetAttribute("AdminFlying", false)
				victim:SetAttribute("SonicDashPassOwned", false)
				victim:SetAttribute("DailyRewardCycle", 1)
				victim:SetAttribute("DailyLastClaimAt", 0)
				victim:SetAttribute("DailyLastClaimedDay", 0)
				victim:SetAttribute("DailyClaimedDaysCsv", "")
				victim:SetAttribute("DailyStateReady", false)
				victim:SetAttribute("FirstTimeTutorialSeen", false)
				victim:SetAttribute("SpeedCarry", 0)
				victim:SetAttribute("AfkModeActive", false)

				local leaderstats = victim:FindFirstChild("leaderstats")
				if leaderstats then
					local s = leaderstats:FindFirstChild("Speed")
					if s and s:IsA("ValueBase") then (s :: any).Value = 1 end
					local w = leaderstats:FindFirstChild("Wins")
					if w and w:IsA("ValueBase") then (w :: any).Value = 0 end
					local r = leaderstats:FindFirstChild("Rebirths")
					if r and r:IsA("ValueBase") then (r :: any).Value = 0 end
				end

				refreshStats(victim)
				if type(_G.SpeedsterResetCustomization) == "function" then
					pcall(_G.SpeedsterResetCustomization, victim)
				end
				local char = victim.Character
				if char then
					victim:LoadCharacter()
				end
			end
		end
		toast(admin, done > 0, "Wiped all data: " .. done .. "/" .. #victims)
	end
end)

-- Admins are told on arrival: the AdminAbusePanelAllowed attribute replicates with the
-- player, so the topbar icon and F2 work from the first frame whichever script starts
-- first (a message fired this early reaches only the first script listening), and the
-- Permission message brings the music list. The panel's Hello gets the same answer.
local function welcome(player: Player)
	task.spawn(function()
		if player.Parent == Players and isAllowed(player) then
			player:SetAttribute("AdminAbusePanelAllowed", true)
			Panel:FireClient(player, { kind = "Permission", allowed = true, tracks = musicTracks() })
		end
	end)
end
Players.PlayerAdded:Connect(welcome)
for _, player in Players:GetPlayers() do
	welcome(player)
end

-- Mutes survive joining a new channel and end on their own.
task.spawn(function()
	while true do
		task.wait(5)
		local now = os.time()
		for userId, untilTime in mutedUntil do
			local player = Players:GetPlayerByUserId(userId)
			if now >= untilTime then
				mutedUntil[userId] = nil
				if player then
					setCanSend(player, true)
				end
			elseif player then
				setCanSend(player, false)
			end
		end
	end
end)

print("[AdminAbusePanelService] ready")

-- The Disco perk, four times a second (see updateDiscoPad).
task.spawn(function()
	while true do
		task.wait(DISCO_PAD_INTERVAL)
		pcall(updateDiscoPad)
	end
end)
