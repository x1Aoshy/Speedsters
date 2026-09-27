-- StarterPlayer/StarterPlayerScripts/Gameplay/LobbyNpcsClient.client.luau — Update 4 (2026-09-25):
-- everything a player sees of the two lobby NPCs (Gameplay/LobbyNpcs prepares them: the owner's
-- own models placed in Workspace, or the spawned Flash; Shared/LobbyNpcConfig has the rules):
--   * Finding them: by the tag the server gives each (LobbyNpcEggman / LobbyNpcFlash), as they
--     stream in and out (StreamingEnabled), once the server has prepared them (attribute LobbyNpc).
--   * Poses: Shared/LobbyNpcPose on the joints' Transform, on Stepped: R6 joints, or their R15
--     equivalents (Root, Neck, LeftShoulder...: LobbyNpcRig.FindJoints); a rig without shoulders
--     and hips keeps still (one warning) and still talks. Only within AnimateRadius of the camera
--     (every frame within FullRateRadius, ReducedHz beyond; half the radii on the Low tier: phones
--     under 30 FPS, Shared/RaceFeelTier). The clock is the server's, so every player sees the same
--     moment of the idle.
--   * Flash's sparks: off since 2026-09-26 (owner: "NO sparkles"; syncSparks never turns them
--     on): Gameplay/FlashGateClient draws his electricity as segmented Beams.
--   * Name tags, Eggman's gold "!" while a quest reward or a quest choice waits (the player's
--     QuestRewardReady / QuestAvailable attributes), prompts in the player's language.
--   * Dr. Eggman's prompt: he laughs, his line types out in a speech bubble, then the quests
--     panel opens (MenuEvents.Request("Quests", ...)).
--   * The Flash's prompt: his sign-up window (Shared/LobbyNpcUi): Beginners / My Rank / Open
--     send RaceRequest { action = "Join", source = "Npc", category = ... } (the race server
--     owns what happens next and answers with its own toasts); Beginners is greyed out while
--     the race server's RaceBracket attribute says "Mid" or "Pro". WEEKLY RECORDS opens the
--     race panel (its FASTEST RACERS list). Works with a mouse, touch and a gamepad (B closes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local LobbyNpcConfig = require(Shared:WaitForChild("LobbyNpcConfig"))
local LobbyNpcText = require(Shared:WaitForChild("LobbyNpcText"))
local LobbyNpcPose = require(Shared:WaitForChild("LobbyNpcPose"))
local LobbyNpcRig = require(Shared:WaitForChild("LobbyNpcRig"))
local LobbyNpcUi = require(Shared:WaitForChild("LobbyNpcUi"))
local RaceUiKit = require(Shared:WaitForChild("RaceUiKit"))
local RaceText = require(Shared:WaitForChild("RaceText"))
local RaceFeelTier = require(Shared:WaitForChild("RaceFeelTier"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
-- 2026-09-26 (owner): Eggman in his Egg Mobile plays EggMobile.PoseKind (Gameplay/EggMobileClient
-- runs the ship and its QUESTS sign, whose "!" replaces his alert).
local EggMobile = require(Shared:WaitForChild("EggMobile"))

local CLIENT = LobbyNpcConfig.Client
local DIALOG_MENU = "LobbyNpcFlash"
local BOLT_TEXTURE = RaceUiKit.Art.Lightning
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local BOLT_COLOR = Color3.fromRGB(255, 222, 70)
local POP_IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local ALERT_BOUNCE = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local lang = LobbyNpcText.ForPlayer(player)
local kit = RaceUiKit.new()
local RaceRequest: RemoteEvent? = nil
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 60)
	local remote = remotes and remotes:WaitForChild("RaceRequest", 60)
	if remote and remote:IsA("RemoteEvent") then
		RaceRequest = remote
	end
end)

local function words(key: string, ...: any): string
	return LobbyNpcText.Format(key, lang, ...)
end

local function styleAll(root: Instance)
	for _, object in root:GetDescendants() do
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			LobbyNpcText.Style(object, lang)
		end
	end
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function characterRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

----------------------------------------------------------------------
-- Tier (phones under 30 FPS pose fewer NPCs, less often, and show no sparks)
----------------------------------------------------------------------
local meter = RaceFeelTier.NewMeter()
local tier = RaceFeelTier.Detect(nil)
local tierClock = 0

----------------------------------------------------------------------
-- The NPCs
----------------------------------------------------------------------
type Joint = { name: string, motor: Motor6D, basis: CFrame, inverse: CFrame }
type Npc = {
	model: Model,
	kind: string,
	poseKind: string, -- the LobbyNpcPose def it plays: its kind, or EggMobile.PoseKind in the ship
	root: BasePart,
	head: BasePart,
	headTop: number, -- studs from the head's (or root's) centre to the top of the model
	joints: { Joint },
	out: any,
	nextPoseAt: number,
	reaction: string?,
	reactionStart: number,
	aim: { yaw: number, pitch: number }, -- 2026-09-26: where the driving Eggman looks / points (his root's axes)
	aimAt: number,
	prompt: ProximityPrompt?,
	tag: BillboardGui?,
	alert: BillboardGui?,
	alertTween: Tween?,
	bubble: BillboardGui?,
	bubbleToken: number,
	emitters: { ParticleEmitter }?,
	sparkState: string?,
	connections: { RBXScriptConnection },
}
local npcs: { [Model]: Npc } = {}
local byKind: { [string]: Npc } = {}

local warned: { [string]: boolean } = {}

-- The pose joints on an R6 or an R15 rig, with each joint's C0 basis (the pose is given in the
-- parent part's axes). A rig without both shoulders and both hips is not posed (one warning when
-- `final`: the register tries again while a streamed rig finishes arriving).
local function findJoints(model: Model, final: boolean): { Joint }
	local found, rig, complete = LobbyNpcRig.FindJoints(model)
	if not complete then
		if final and not warned[model.Name] then
			warned[model.Name] = true
			warn(("[LobbyNpcs] %s (%s rig) has no R6 or R15 shoulders and hips: it will talk but not move"):format(model:GetFullName(), rig))
		end
		return {}
	end
	local joints = {}
	for _, joint in found do
		local basis = joint.motor.C0.Rotation
		table.insert(joints, { name = joint.name, motor = joint.motor, basis = basis, inverse = basis:Inverse() })
	end
	return joints
end

local function react(npc: Npc, reaction: string)
	npc.reaction = reaction
	npc.reactionStart = serverNow()
	npc.nextPoseAt = 0
end

-- 2026-09-26 (owner): the driving Eggman's gestures ("come here", the glance, the talk reaction) aim at
-- this player when near him (def.AimRadius), else straight ahead; eased so he never snaps round
-- (exponential in the time since the last pose: the same at any frame rate).
local function updateAim(npc: Npc, def: any, t: number)
	local yaw, pitch = -20, 5
	local root = characterRoot()
	if root and npc.root.Parent then
		local rel = npc.root.CFrame:PointToObjectSpace(root.Position + Vector3.new(0, 1.5, 0))
		local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		if rel.Magnitude <= (def.AimRadius or 60) and flat > 1 then
			yaw = math.clamp(math.deg(math.atan2(-rel.X, -rel.Z)), -70, 70)
			pitch = math.clamp(math.deg(math.atan2(rel.Y, flat)), -15, 35)
		end
	end
	local dt = math.clamp(t - npc.aimAt, 0, 0.5)
	npc.aimAt = t
	local k = 1 - math.exp(-3 * dt)
	npc.aim.yaw += (yaw - npc.aim.yaw) * k
	npc.aim.pitch += (pitch - npc.aim.pitch) * k
end

local function applyPose(npc: Npc, t: number)
	local age = if npc.reaction then t - npc.reactionStart else nil
	local def = LobbyNpcPose.Defs[npc.poseKind]
	if npc.reaction and (age :: number) >= def.Reactions[npc.reaction].Duration then
		npc.reaction, age = nil, nil
	end
	local aim = nil
	if def.Aims then
		updateAim(npc, def, t)
		aim = npc.aim
	end
	local out = LobbyNpcPose.Sample(npc.poseKind, t, npc.out, npc.reaction, age, aim)
	for _, joint in npc.joints do
		if joint.motor.Parent then
			local v = out[joint.name]
			local rotation = CFrame.new(v[1], v[2], v[3]) * CFrame.Angles(math.rad(v[4]), math.rad(v[5]), math.rad(v[6]))
			joint.motor.Transform = joint.inverse * rotation * joint.basis
		end
	end
end

----------------------------------------------------------------------
-- Flash's sparks
----------------------------------------------------------------------
local function newEmitter(name: string, texture: string, parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(BOLT_COLOR, Color3.fromRGB(255, 150, 40))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Enabled = false
	pcall(function()
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	end)
	emitter.Parent = parent
	return emitter
end

local function ensureSparks(npc: Npc): { ParticleEmitter }
	if npc.emitters then
		return npc.emitters
	end
	local list = {}
	local torso = npc.model:FindFirstChild("Torso") or npc.model:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local bolts = newEmitter("NpcBolts", BOLT_TEXTURE, torso)
		bolts.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) })
		bolts.Lifetime = NumberRange.new(0.12, 0.24)
		bolts.Speed = NumberRange.new(3, 6)
		table.insert(list, bolts)
	end
	for _, names in { { "Left Leg", "LeftLowerLeg" }, { "Right Leg", "RightLowerLeg" } } do
		local leg = npc.model:FindFirstChild(names[1]) or npc.model:FindFirstChild(names[2])
		if leg and leg:IsA("BasePart") then
			local sparks = newEmitter("NpcSparks", SPARK_TEXTURE, leg)
			sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			sparks.Lifetime = NumberRange.new(0.15, 0.3)
			sparks.Speed = NumberRange.new(4, 8)
			sparks.Acceleration = Vector3.new(0, -8, 0)
			table.insert(list, sparks)
		end
	end
	npc.emitters = list
	return list
end

-- Emitters on for `tier` near Flash, off otherwise (written only when that changes).
local function syncSparks(npc: Npc, near: boolean)
	-- 2026-09-26 (owner: "NO sparkles"): off; Gameplay/FlashGateClient draws his crackles (Beams).
	local on = false and near and tier ~= "Low"
	local key = if on then tier else "Off"
	if npc.sparkState == key or (not on and not npc.emitters) then
		return
	end
	npc.sparkState = key
	for index, emitter in ensureSparks(npc) do
		local enabled = on and (tier == "High" or index == 1)
		emitter.Rate = if index == 1 then (if tier == "High" then 5 else 3) else 4
		emitter.Enabled = enabled
	end
end

local function burst(npc: Npc)
	if tier == "Low" or not npc.emitters then
		return
	end
	local bolts = npc.emitters[1]
	if bolts and bolts.Parent then
		bolts:Emit(if tier == "High" then 14 else 6)
	end
end

----------------------------------------------------------------------
-- Tags, the "!" and speech bubbles
----------------------------------------------------------------------
local function questWaiting(): boolean
	return player:GetAttribute("QuestRewardReady") == true or player:GetAttribute("QuestAvailable") == true
end

-- Workspace.U4Off_Npcs: the server switches the prompts off; here the NPCs stop moving and lose
-- their tags, "!" and window.
local function npcsOff(): boolean
	return Workspace:GetAttribute(LobbyNpcConfig.KillAttribute) == true
end

local function syncAlert(npc: Npc)
	local alert = npc.alert
	if not alert then
		return
	end
	local show = questWaiting() and not npcsOff() and not (npc.bubble and npc.bubble.Enabled)
	if alert.Enabled == show then
		return
	end
	alert.Enabled = show
	if npc.alertTween then
		npc.alertTween:Cancel()
		npc.alertTween = nil
	end
	local scale = alert:FindFirstChild("Badge") and alert.Badge:FindFirstChild("Bounce")
	if show and scale then
		scale.Scale = 1
		npc.alertTween = TweenService:Create(scale, ALERT_BOUNCE, { Scale = 1.18 })
		npc.alertTween:Play()
	end
end

local function makeTag(npc: Npc)
	local tag = LobbyNpcUi.BuildTag()
	tag.Name = LobbyNpcUi.TagName .. npc.kind
	tag.MaxDistance = CLIENT.TagDistance
	tag.Adornee = npc.head
	tag.StudsOffsetWorldSpace = Vector3.new(0, npc.headTop + 1.4, 0)
	tag.NameLabel.Text = words(if npc.kind == "Eggman" then "EggmanName" else "FlashName")
	tag.Role.Text = words(if npc.kind == "Eggman" then "EggmanRole" else "FlashRole")
	styleAll(tag)
	tag.Enabled = not npcsOff()
	tag.Parent = playerGui
	npc.tag = tag
	-- In the Egg Mobile the QUESTS sign's "!" is his alert (Gameplay/EggMobileClient).
	if npc.kind == "Eggman" and npc.poseKind == npc.kind then
		local alert = LobbyNpcUi.BuildAlert()
		alert.Name = LobbyNpcUi.AlertName .. npc.kind
		alert.MaxDistance = CLIENT.AlertDistance
		alert.Adornee = npc.head
		alert.StudsOffsetWorldSpace = Vector3.new(0, npc.headTop + 3.6, 0)
		alert.Parent = playerGui
		npc.alert = alert
		syncAlert(npc)
	end
end

-- `text` types out in a bubble over the NPC for `seconds`, then pops away.
local function say(npc: Npc, text: string, seconds: number)
	local bubble = npc.bubble
	if not bubble then
		bubble = LobbyNpcUi.BuildBubble()
		bubble.Name = LobbyNpcUi.BubbleName .. npc.kind
		bubble.Adornee = npc.head
		bubble.StudsOffsetWorldSpace = Vector3.new(0, npc.headTop + 2.9, 0)
		styleAll(bubble)
		bubble.Parent = playerGui
		npc.bubble = bubble
	end
	npc.bubbleToken += 1
	local token = npc.bubbleToken
	local label = bubble.Holder.Plate.Text
	local pop = bubble.Holder.Pop
	label.Text = text
	label.MaxVisibleGraphemes = 0
	bubble.Enabled = true
	if npc.tag then
		npc.tag.Enabled = false
	end
	syncAlert(npc)
	pop.Scale = 0.6
	TweenService:Create(pop, POP_IN, { Scale = 1 }):Play()
	task.spawn(function()
		local count = utf8.len(text) or #text
		local shown = 0
		while shown < count and npc.bubbleToken == token do
			shown = math.min(count, shown + 2)
			label.MaxVisibleGraphemes = shown
			task.wait(0.03)
		end
		if npc.bubbleToken ~= token then
			return
		end
		label.MaxVisibleGraphemes = -1
		task.wait(seconds)
		if npc.bubbleToken ~= token then
			return
		end
		local out = TweenService:Create(pop, POP_OUT, { Scale = 0.6 })
		out:Play()
		out.Completed:Wait()
		if npc.bubbleToken == token then
			bubble.Enabled = false
			if npc.tag then
				npc.tag.Enabled = not npcsOff()
			end
			syncAlert(npc)
		end
	end)
end

----------------------------------------------------------------------
-- Dr. Eggman: his line, then the quests
----------------------------------------------------------------------
local talking = false

local function talkToEggman(npc: Npc)
	if talking then
		return
	end
	talking = true
	local prompt = npc.prompt
	if prompt then
		prompt.Enabled = false
	end
	-- 2026-09-26 (owner): in his Egg Mobile he turns to the player, points and opens his arms ("Talk").
	local def = LobbyNpcPose.Defs[npc.poseKind]
	react(npc, if def and def.TalkReaction then def.TalkReaction else "Laugh")
	PurchaseButtonSound.Play()
	local line = if player:GetAttribute("QuestRewardReady") == true then words("EggmanReward") else words("EggmanLine")
	say(npc, line, CLIENT.TalkSeconds + 1.4)
	-- 2026-09-26 (owner): "the Spin the Wheel shows Quests". The quests opened TalkSeconds after
	-- the talk whatever the player did meanwhile, so a menu opened in those seconds (the Spin
	-- button beside x2 Speed, the lobby wheel's prompt, a topbar icon) was shut and the Quests
	-- came up in its place. A menu asked for after the talk (MenuEvents.Request fires CloseAll
	-- with its name; a respawn or the console's Back with none) or one that opened by itself
	-- meanwhile (the Daily after the Update Logs) now wins: the quests stay shut.
	local busyAtTalk = MenuEvents.AnyOpen("Quests")
	local superseded = false
	local watch = MenuEvents.CloseAll.Event:Connect(function(except)
		if except ~= "Quests" then
			superseded = true
		end
	end)
	task.delay(CLIENT.TalkSeconds, function()
		watch:Disconnect()
		if not superseded and (busyAtTalk or not MenuEvents.AnyOpen("Quests")) then
			-- An argument makes Request open (never toggle shut) the panel.
			MenuEvents.Request("Quests", "Npc")
		end
		task.wait(1)
		talking = false
		if prompt and prompt.Parent then
			prompt.Enabled = true
		end
	end)
end

----------------------------------------------------------------------
-- The Flash: the sign-up window
----------------------------------------------------------------------
local dialog = LobbyNpcUi.BuildFlashDialog()
local window = dialog.Window
local fit = window.FitScale
local tiles = window.Tiles
local status = window.Status
local dialogOpen = false
local dialogMotion = 0

window.Title.Text = words("FlashTitle")
window.Speech.Speaker.Text = string.upper(words("FlashName"))
window.Speech.Line.Text = words("FlashLine")
for category, keys in LobbyNpcText.CategoryKeys do
	local tile = tiles[category]
	tile.Text = words(keys.Title)
	tile.Label.Text = words(keys.Title)
	tile.Sub.Text = words(keys.Sub)
end
window.Records.Text = words("Records")
window.Records.Label.Text = words("Records")
styleAll(dialog)
dialog.Parent = playerGui

-- 2026-09-26 (owner, phone playtest: "the race sign-up is too big"): the window centres in the
-- room under the top bar and inside the notch (the dialog uses CoreUISafeInsets) and, on a
-- phone, takes its compact arrangement at the Index's share of that room (LobbyNpcUi.Fit).
local function fitScale(): number
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local room = dialog.AbsoluteSize
	if room.X < 2 or room.Y < 2 then
		room = Vector2.new(view.X, view.Y - GuiService:GetGuiInset().Y)
	end
	return LobbyNpcUi.Fit(kit.env, window, view.X, view.Y, room.X, room.Y, UserInputService.TouchEnabled).Scale
end

local function unlocked(): boolean
	return player:GetAttribute("FirstTimeTutorialSeen") == true or (tonumber(player:GetAttribute("Rebirths")) or 0) >= 1
end

local function allowed(category: string): boolean
	return unlocked() and LobbyNpcConfig.CategoryAllowed(category, player:GetAttribute(LobbyNpcConfig.BracketAttribute))
end

local function paintTiles()
	for _, category in LobbyNpcConfig.Categories do
		local tile = tiles[category]
		local open = allowed(category)
		kit:paint(tile, if open then LobbyNpcUi.TilePalettes[category] else LobbyNpcUi.LockedPalette)
		tile.Selectable = open
		tile:SetAttribute("Locked", not open)
		local keys = LobbyNpcText.CategoryKeys[category]
		local sub = if open then words(keys.Sub) elseif category == "Beginner" and unlocked() then words("BeginnerLocked") else words(keys.Sub)
		if tile.Sub.Text ~= sub then
			tile.Sub.Text = sub
		end
	end
end

local function statusLine(): string
	if not U4.IsOn("Race") then
		return RaceText.Get("RaceOff", lang)
	elseif not unlocked() then
		return RaceText.Get("RaceLockedTutorial", lang)
	elseif player:GetAttribute("RaceState") == "Queued" then
		return words("Queued")
	end
	local phase = Workspace:GetAttribute("RacePhase")
	local remaining = math.max(0, (tonumber(Workspace:GetAttribute("RacePhaseEndsAt")) or 0) - serverNow())
	local timer
	if phase == "Gathering" or phase == "Results" or phase == "Cooldown" then
		timer = RaceText.Clock(remaining)
	elseif phase == "Staging" or phase == "Countdown" then
		timer = RaceText.Get("StartingSoon", lang)
	elseif phase == "Running" then
		timer = RaceText.Format("Live", lang, RaceText.Clock(remaining))
	else
		timer = RaceText.Get("Now", lang)
	end
	local ready = RaceText.Format("Ready", lang, tonumber(Workspace:GetAttribute("RaceQueueCount")) or 0,
		tonumber(Workspace:GetAttribute("RaceMaxPlayers")) or U4.Race.Queue.MaxPlayers)
	return RaceText.Get("NextRace", lang) .. ": " .. timer .. "  ·  " .. ready
end

local function closeDialog()
	if not dialogOpen then
		return
	end
	dialogOpen = false
	dialogMotion += 1
	local motion = dialogMotion
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(dialog) then
		GuiService.SelectedObject = nil
	end
	local tween = TweenService:Create(fit, POP_OUT, { Scale = fitScale() * 0.85 })
	tween:Play()
	tween.Completed:Connect(function()
		if motion == dialogMotion and not dialogOpen then
			dialog.Enabled = false
			if not MenuEvents.AnyOpen(DIALOG_MENU) then
				MenuEvents.SetHUDVisible(true, nil)
			end
		end
	end)
end

local function openDialog()
	if dialogOpen then
		return
	end
	dialogOpen = true
	dialogMotion += 1
	MenuEvents.CloseAll:Fire(DIALOG_MENU)
	MenuEvents.SetHUDVisible(false, DIALOG_MENU)
	paintTiles()
	status.Text = statusLine()
	local target = fitScale()
	fit.Scale = target * 0.85
	dialog.Enabled = true
	TweenService:Create(fit, POP_IN, { Scale = target }):Play()
	task.spawn(function()
		while dialogOpen do
			task.wait(0.5)
			if not dialogOpen then
				break
			end
			local flash = byKind.Flash
			local root = characterRoot()
			local tooFar = not flash or not flash.root.Parent or not root
				or (root.Position - flash.root.Position).Magnitude > CLIENT.DialogCloseDistance
			local state = player:GetAttribute("RaceState")
			if tooFar or state == "Staged" or state == "Racing" or not U4.IsOn("Race") then
				closeDialog()
				break
			end
			status.Text = statusLine()
		end
	end)
end

local function choose(category: string)
	if not dialogOpen then
		return
	end
	PurchaseButtonSound.Play()
	if not allowed(category) then
		return
	end
	local payload = LobbyNpcConfig.JoinPayload(category)
	local remote = RaceRequest
	local sent = payload ~= nil and remote ~= nil
	if sent then
		remote:FireServer(payload)
	end
	closeDialog()
	local flash = byKind.Flash
	if flash then
		-- Refusals (tutorial, AFK, cooldown...) come back as the race server's own toasts.
		if sent then
			react(flash, "Point")
			burst(flash)
		end
		say(flash, words(if sent then "FlashGo" else "FlashLater"), 2.2)
	end
end

for _, category in LobbyNpcConfig.Categories do
	tiles[category].Activated:Connect(function()
		choose(category)
	end)
end
window.Records.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closeDialog()
	-- An argument makes Request open the race panel (its FASTEST RACERS list) rather than toggle it.
	MenuEvents.Request("Race", "Weekly")
end)
window.Close.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closeDialog()
end)
ConsolePanelSupport.Bind(dialog, window, tiles.Rank, window.Close, closeDialog)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= DIALOG_MENU then
		closeDialog()
	end
end)
MenuEvents.MarkReady(DIALOG_MENU, function()
	return dialogOpen
end)
-- Keys 1 / 2 / 3 pick a category while the window is open.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not dialogOpen then
		return
	end
	local index = if input.KeyCode == Enum.KeyCode.One then 1 elseif input.KeyCode == Enum.KeyCode.Two then 2
		elseif input.KeyCode == Enum.KeyCode.Three then 3 else nil
	if index then
		choose(LobbyNpcConfig.Categories[index])
	end
end)
for _, name in { LobbyNpcConfig.BracketAttribute, "FirstTimeTutorialSeen", "Rebirths" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if dialogOpen then
			paintTiles()
		end
	end)
end
local function onViewport()
	if dialogOpen then
		fit.Scale = fitScale()
	end
end
local viewportConnection: RBXScriptConnection? = nil
local function bindCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
	end
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
dialog:GetPropertyChangedSignal("AbsoluteSize"):Connect(onViewport)
player.CharacterRemoving:Connect(closeDialog)

local function talkToFlash(npc: Npc)
	if dialogOpen then
		return
	end
	react(npc, "Point")
	burst(npc)
	openDialog()
end

----------------------------------------------------------------------
-- Registering the NPCs as they stream in and out
----------------------------------------------------------------------
local function unregister(model: Instance)
	local npc = npcs[model :: Model]
	if not npc then
		return
	end
	npcs[model :: Model] = nil
	if byKind[npc.kind] == npc then
		byKind[npc.kind] = nil
	end
	for _, connection in npc.connections do
		connection:Disconnect()
	end
	if npc.alertTween then
		npc.alertTween:Cancel()
	end
	npc.bubbleToken += 1
	for _, gui in { npc.tag, npc.alert, npc.bubble } do
		if gui then
			gui:Destroy()
		end
	end
	if npc.kind == "Flash" then
		closeDialog()
	end
end

local function register(model: Instance, kind: string)
	if not model:IsA("Model") or npcs[model] then
		return
	end
	-- Prepared by the server (its root anchored, its prompt on): the attribute says so.
	local deadline = os.clock() + 15
	while model:GetAttribute(LobbyNpcConfig.KindAttribute) ~= kind and model.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	if model:GetAttribute(LobbyNpcConfig.KindAttribute) ~= kind or not model:IsDescendantOf(Workspace) then
		return
	end
	local root = LobbyNpcRig.FindRoot(model)
	if not root then
		root = model:WaitForChild("HumanoidRootPart", 5)
	end
	if not (root and root:IsA("BasePart")) or not model:IsDescendantOf(Workspace) or npcs[model] then
		return
	end
	local headPart = model:FindFirstChild("Head")
	local head: BasePart = if headPart and headPart:IsA("BasePart") then headPart else root
	-- The tag, "!" and bubble sit over the model's top (hats and hair included), whatever its size.
	local headTop = head.Size.Y / 2
	pcall(function()
		local box, size = model:GetBoundingBox()
		headTop = math.max(headTop, box.Position.Y + size.Y / 2 - head.Position.Y)
	end)
	local npc: Npc = {
		model = model,
		kind = kind,
		poseKind = if kind == "Eggman" and model:FindFirstChild(EggMobile.ModelName) then EggMobile.PoseKind else kind,
		root = root,
		head = head,
		headTop = headTop,
		joints = findJoints(model, false),
		out = LobbyNpcPose.NewOut(),
		nextPoseAt = 0,
		reaction = nil,
		reactionStart = 0,
		aim = { yaw = -20, pitch = 5 },
		aimAt = 0,
		prompt = nil,
		tag = nil,
		alert = nil,
		alertTween = nil,
		bubble = nil,
		bubbleToken = 0,
		emitters = nil,
		sparkState = nil,
		connections = {},
	}
	npcs[model] = npc
	byKind[kind] = npc

	local promptAttachment = root:FindFirstChild("PromptAttachment")
	local prompt = promptAttachment and promptAttachment:FindFirstChild("NpcPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		npc.prompt = prompt
		-- The server wrote English; this copy speaks the player's language.
		if kind == "Eggman" then
			prompt.ActionText = words("EggmanPrompt")
			prompt.ObjectText = words("EggmanPromptObject")
		else
			prompt.ActionText = words("FlashPrompt")
			prompt.ObjectText = words("FlashPromptObject")
		end
		table.insert(npc.connections, prompt.Triggered:Connect(function(who)
			-- 2026-09-26 (owner): only this player's own press talks to him (FlashGateClient checks the same).
			if npcsOff() or (who ~= nil and who ~= player) then
				return
			end
			if kind == "Eggman" then
				talkToEggman(npc)
			else
				talkToFlash(npc)
			end
		end))
	end
	makeTag(npc)
	if #npc.joints == 0 then
		task.spawn(function()
			for attempt = 1, 3 do
				task.wait(2)
				if npcs[model] ~= npc then
					return
				end
				local joints = findJoints(model, attempt == 3)
				if #joints > 0 then
					npc.joints = joints
					return
				end
			end
		end)
	end
	table.insert(npc.connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			unregister(model)
		end
	end))
end

-- By tag: the models stream in (InstanceAdded) and out (InstanceRemoved) with StreamingEnabled.
for kind, tagName in LobbyNpcConfig.Tags do
	for _, model in CollectionService:GetTagged(tagName) do
		task.spawn(register, model, kind)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(model)
		task.spawn(register, model, kind)
	end)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(unregister)
end

Workspace:GetAttributeChangedSignal(LobbyNpcConfig.KillAttribute):Connect(function()
	local off = npcsOff()
	if off then
		closeDialog()
	end
	for _, npc in npcs do
		if npc.tag then
			npc.tag.Enabled = not off and not (npc.bubble and npc.bubble.Enabled)
		end
		syncAlert(npc)
		if npc.kind == "Flash" then
			syncSparks(npc, false)
		end
	end
end)

for _, name in { "QuestRewardReady", "QuestAvailable" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		local eggman = byKind.Eggman
		if eggman then
			syncAlert(eggman)
		end
	end)
end

----------------------------------------------------------------------
-- The loop: poses near the camera, sparks near Flash
----------------------------------------------------------------------
RunService.Stepped:Connect(function(_, dt)
	RaceFeelTier.Sample(meter, dt)
	tierClock += dt
	if tierClock >= CLIENT.TierSeconds then
		tierClock = 0
		tier = RaceFeelTier.Detect(meter)
	end
	if next(npcs) == nil or npcsOff() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local low = tier == "Low"
	local animateRadius = if low then CLIENT.AnimateRadius / 2 else CLIENT.AnimateRadius
	local fullRadius = if low then CLIENT.FullRateRadius / 2 else CLIENT.FullRateRadius
	local t = serverNow()
	for _, npc in npcs do
		if npc.root.Parent then
			local distance = (npc.root.Position - eye).Magnitude
			if #npc.joints == 0 and npc.kind ~= "Flash" then
				continue
			end
			if npc.kind == "Flash" then
				syncSparks(npc, distance <= CLIENT.SparkRadius)
			end
			if distance <= animateRadius and (distance <= fullRadius or npc.reaction ~= nil or t >= npc.nextPoseAt) then
				npc.nextPoseAt = t + 1 / CLIENT.ReducedHz
				applyPose(npc, t)
			end
		end
	end
end)
