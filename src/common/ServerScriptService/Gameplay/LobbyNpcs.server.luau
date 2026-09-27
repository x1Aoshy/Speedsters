-- ServerScriptService/Gameplay/LobbyNpcs.server.luau — Update 4 (2026-09-25): the two lobby NPCs of
-- every world (Shared/LobbyNpcConfig has the rules):
--   * Dr. Eggman — the OWNER's model (2026-09-25: "I will put him in Workspace myself"): any Model
--     named Eggman / DrEggman / "Dr. Eggman" / "Dr Eggman" / Robotnik (with a Humanoid or an
--     AnimationController), or tagged LobbyNpcEggman, anywhere under Workspace, now or later.
--     ProximityPrompt "Talk to Dr. Eggman": the client says his line and opens the quests.
--     The parts-built Eggman (Shared/LobbyNpcRig) only with LobbyNpcConfig.SpawnPartsEggman.
--   * The Flash — the owner's model when there is one (Flash / TheFlash, tag LobbyNpcFlash; e.g.
--     design/npc/Flash.rbxm, Steal a Hero's R15 Flash). Else an R6 avatar in the game's FlashSuit
--     (shirt, pants and the mask, Players:CreateHumanoidModelFromDescription), spawned beside the
--     Race Gate, or on the booth's kiosk (RaceGate.FlashSpot) without his base disc; an owner's
--     Flash that turns up later replaces it. No parts-built Flash (owner, 2026-09-25).
--     ProximityPrompt "Sign up to race": the client opens his window, which sends RaceRequest
--     { action = "Join", source = "Npc", category = ... } (the race server owns that; nothing
--     is joined here). The prompt is off while the race feature is (U4.IsOn("Race")).
-- An owner's model stays where he put it: its root is anchored, the body joined to it moves only
-- with its joints and never collides, touches or blocks a ray, its scripts are switched off and
-- its Animators removed (LobbyNpcRig.PrepareOwnerModel). Every NPC gets attribute LobbyNpc and
-- the tag of its kind, and streams Atomic; the clients find them by tag and pose them
-- (Gameplay/LobbyNpcsClient: the procedural R6 idle, R15 joints mapped). The server never
-- moves them.
-- Kill switch: Workspace attribute U4Off_Npcs = true takes the spawned NPCs out of the lobby and
-- switches every NPC prompt off (the owner's models stay, as statues), live.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local U4 = require(Shared:WaitForChild("Update4Config"))
local SuitCatalog = require(Shared:WaitForChild("SuitCatalog"))
local LobbyNpcConfig = require(Shared:WaitForChild("LobbyNpcConfig"))
local LobbyNpcRig = require(Shared:WaitForChild("LobbyNpcRig"))
local LobbyNpcText = require(Shared:WaitForChild("LobbyNpcText"))

local WORLD = LobbyNpcConfig.WorldKey(Config)
local ENV = { Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum }
local FLASH_SKIN_ID = "FlashSuit"
local AVATAR_RETRY_SECONDS = 20
local AVATAR_TRIES = 3

local function killed(): boolean
	return Workspace:GetAttribute(LobbyNpcConfig.KillAttribute) == true
end

-- The NPCs this script spawns (the avatar Flash, the flagged parts Eggman).
local folder = Instance.new("Folder")
folder.Name = LobbyNpcConfig.FolderName

type Npc = { kind: string, root: BasePart, prompt: ProximityPrompt?, owner: boolean }
local npcs: { [Model]: Npc } = {}
local spawnedFlash: Model? = nil

local function hasOwner(kind: string): boolean
	for _, npc in npcs do
		if npc.owner and npc.kind == kind then
			return true
		end
	end
	return false
end

local function refreshPrompts()
	local off = killed()
	local raceOn = U4.IsOn("Race")
	for _, npc in npcs do
		if npc.prompt then
			npc.prompt.Enabled = not off and (npc.kind ~= "Flash" or raceOn)
		end
	end
end

-- The prompt in English (each client puts its own language on its copy), the attribute and tag
-- the clients look for, Atomic streaming (the whole rig arrives at once).
local function register(model: Model, kind: string, root: BasePart, owner: boolean)
	local settings = LobbyNpcConfig.Prompt[kind]
	local action = LobbyNpcText.Get(if kind == "Eggman" then "EggmanPrompt" else "FlashPrompt", "en")
	local object = LobbyNpcText.Get(if kind == "Eggman" then "EggmanPromptObject" else "FlashPromptObject", "en")
	-- An owner's model may be bigger than a player: the prompt reaches past its sides and height.
	local reach = settings.MaxDistance
	pcall(function()
		local size = model:GetExtentsSize()
		reach = math.max(reach, math.max(size.X, size.Z) / 2 + 6, size.Y * 0.6)
	end)
	local prompt = LobbyNpcRig.AddPrompt(ENV, root, settings.Offset, reach, action, object)
	npcs[model] = { kind = kind, root = root, prompt = prompt, owner = owner }
	model:SetAttribute(LobbyNpcConfig.KindAttribute, kind)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	CollectionService:AddTag(model, LobbyNpcConfig.Tags[kind])
	refreshPrompts()
end

----------------------------------------------------------------------
-- The owner's models
----------------------------------------------------------------------
local function isCharacter(model: Instance): boolean
	local cursor: Instance? = model
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") and Players:GetPlayerFromCharacter(cursor) then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local ensureFlash: () -> ()

local function adopt(model: Instance, taggedKind: string?)
	if not model:IsA("Model") or npcs[model] or not model:IsDescendantOf(Workspace)
		or model:IsDescendantOf(folder) or isCharacter(model) then
		return
	end
	-- One NPC per model: never a model inside another NPC.
	for other in npcs do
		if model:IsDescendantOf(other) then
			return
		end
	end
	local kind, root = LobbyNpcRig.OwnerKind(model, taggedKind)
	if not kind or not root then
		return
	end
	local report = LobbyNpcRig.PrepareOwnerModel(ENV, model, root)
	register(model, kind, root, true)
	print(string.format("[LobbyNpcs] %s: the owner's %s is %s (%d body parts, %d loose, %d scripts off)",
		WORLD, kind, model:GetFullName(), report.Joined, report.Loose, report.Scripts))
	if kind == "Flash" and spawnedFlash then
		-- The owner's Flash replaces the one this script spawned.
		npcs[spawnedFlash] = nil
		spawnedFlash:Destroy()
		spawnedFlash = nil
	end
	model.AncestryChanged:Connect(function()
		if npcs[model] and not model:IsDescendantOf(Workspace) then
			npcs[model] = nil
			if kind == "Flash" then
				task.delay(2, ensureFlash)
			end
		end
	end)
end

local function consider(instance: Instance)
	if instance:IsA("Model") and LobbyNpcConfig.KindForName(instance.Name) then
		-- Deferred: the model's children arrive with it, and a character is claimed by its player first.
		task.defer(adopt, instance, nil)
	end
end

----------------------------------------------------------------------
-- The spawned NPCs
----------------------------------------------------------------------
local function flashEntry(): any
	for _, entry in SuitCatalog.Ordered do
		if entry.Id == FLASH_SKIN_ID then
			return entry
		end
	end
	return nil
end

-- Where the spawned Flash stands: the booth's FlashSpot when the gate is the booth (true), else
-- beside the gate (LobbyNpcConfig, false).
local function flashSpot(): (any?, boolean)
	for _, name in LobbyNpcConfig.BoothNames do
		local booth = Workspace:FindFirstChild(name)
		local marker = booth and booth:FindFirstChild(LobbyNpcConfig.FlashSpotName, true)
		if marker and marker:IsA("BasePart") then
			return LobbyNpcConfig.MarkerSpot(marker.CFrame, marker.Size.Y), true
		elseif marker and marker:IsA("Attachment") then
			return LobbyNpcConfig.MarkerSpot(marker.WorldCFrame, 0), true
		end
	end
	return LobbyNpcConfig.Spot(WORLD, "Flash"), false
end

-- Stands the spawned Flash (an R6 on its base disc) on `spot`. On the booth's kiosk the disc
-- goes: the booth has its own floor and colliders.
local function standFlash(model: Model, spot: any, onBooth: boolean)
	if onBooth then
		for _, name in { LobbyNpcRig.BaseName, LobbyNpcRig.RimName } do
			local part = model:FindFirstChild(name)
			if part then
				part:Destroy()
			end
		end
	end
	local lift = if model:FindFirstChild(LobbyNpcRig.BaseName) then LobbyNpcRig.BaseHeight else 0
	model:PivotTo(LobbyNpcConfig.SpotCFrame(spot) * CFrame.new(0, lift + LobbyNpcRig.R6RootHeight, 0))
end

-- The mask, shirt and pants from the catalog when the description left one out.
local function wearMissing(model: Model, entry: any)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local function load(assetId: number?, className: string): Instance?
		if not assetId then
			return nil
		end
		local ok, loaded = pcall(InsertService.LoadAsset, InsertService, assetId)
		if not ok or not loaded then
			return nil
		end
		local found = if loaded:IsA(className) then loaded else loaded:FindFirstChildWhichIsA(className, true)
		if found then
			found.Parent = nil
		end
		loaded:Destroy()
		return found
	end
	if not model:FindFirstChildOfClass("Shirt") then
		local shirt = load(tonumber(entry.ShirtId), "Shirt")
		if shirt then
			shirt.Parent = model
		end
	end
	if not model:FindFirstChildOfClass("Pants") then
		local pants = load(tonumber(entry.PantsId), "Pants")
		if pants then
			pants.Parent = model
		end
	end
	if humanoid and not model:FindFirstChildOfClass("Accessory") then
		local mask = load(tonumber(entry.MaskId), "Accessory")
		if mask then
			pcall(humanoid.AddAccessory, humanoid, mask)
			if not mask.Parent then
				mask.Parent = model
			end
		end
	end
end

-- The avatar service's R6 in the FlashSuit, on `floor` with its base disc; nil when it fails.
local function avatarFlash(entry: any, floor: CFrame): Model?
	local description = Instance.new("HumanoidDescription")
	pcall(function()
		description.Shirt = tonumber(entry.ShirtId) or 0
		description.Pants = tonumber(entry.PantsId) or 0
		description.HatAccessory = tostring(entry.MaskId or "")
		local skin = Color3.fromRGB(234, 184, 146)
		description.HeadColor, description.TorsoColor = skin, skin
		description.LeftArmColor, description.RightArmColor = skin, skin
		description.LeftLegColor, description.RightLegColor = skin, skin
	end)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	description:Destroy()
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[LobbyNpcs] Flash's avatar could not be built: " .. tostring(model))
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not model:FindFirstChild("Torso") then
		model:Destroy()
		return nil
	end
	-- Nothing may play or overwrite the joints: the client poses them.
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Animator") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
	wearMissing(model, entry)
	root.Anchored = true
	model.PrimaryPart = root
	model:PivotTo(floor * CFrame.new(0, LobbyNpcRig.BaseHeight + LobbyNpcRig.R6RootHeight, 0))
	local base = LobbyNpcRig.AddBase(ENV, model, floor, LobbyNpcRig.FlashColors)
	LobbyNpcRig.Configure(model, root, base)
	return model
end

local building = false
local tries = 0
ensureFlash = function()
	if building or spawnedFlash or hasOwner("Flash") then
		return
	end
	local spot, onBooth = flashSpot()
	local entry = flashEntry()
	if not spot or not entry then
		return
	end
	building = true
	tries += 1
	local model = avatarFlash(entry, LobbyNpcConfig.SpotCFrame(spot))
	building = false
	if not model then
		if tries < AVATAR_TRIES then
			task.delay(AVATAR_RETRY_SECONDS, ensureFlash)
		end
		return
	end
	if hasOwner("Flash") then
		-- The owner's Flash turned up while the avatar service was busy.
		model:Destroy()
		return
	end
	standFlash(model, spot, onBooth)
	model.Name = LobbyNpcConfig.ModelNames.Flash
	register(model, "Flash", model:FindFirstChild("HumanoidRootPart") :: BasePart, false)
	model.Parent = folder
	spawnedFlash = model
end

-- A booth that arrives after Flash was placed (the race server builds its gate at runtime when
-- the place has none): the spawned Flash moves onto its FlashSpot.
local function replaceFlash()
	local model = spawnedFlash
	if not model or not model.Parent then
		return
	end
	local spot, onBooth = flashSpot()
	if spot then
		standFlash(model, spot, onBooth)
	end
end

local function spawnPartsEggman()
	local spot = LobbyNpcConfig.Spot(WORLD, "Eggman")
	if not spot or hasOwner("Eggman") then
		return
	end
	local model = LobbyNpcRig.BuildEggman(ENV, LobbyNpcConfig.SpotCFrame(spot))
	model.Name = LobbyNpcConfig.ModelNames.Eggman
	register(model, "Eggman", model:FindFirstChild("HumanoidRootPart") :: BasePart, false)
	model.Parent = folder
end

----------------------------------------------------------------------
-- Start
----------------------------------------------------------------------
-- The owner's models already in the place (adopted before anything is spawned), and any that come
-- later: inserted in a running server, or tagged.
for _, instance in Workspace:GetDescendants() do
	if instance:IsA("Model") and LobbyNpcConfig.KindForName(instance.Name) then
		adopt(instance, nil)
	end
end
for kind, tag in LobbyNpcConfig.Tags do
	for _, instance in CollectionService:GetTagged(tag) do
		adopt(instance, kind)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		task.defer(adopt, instance, kind)
	end)
end
Workspace.DescendantAdded:Connect(consider)

if LobbyNpcConfig.SpawnPartsEggman then
	local ok, problem = pcall(spawnPartsEggman)
	if not ok then
		warn("[LobbyNpcs] the parts Eggman was not built: " .. tostring(problem))
	end
end
folder.Parent = if killed() then nil else Workspace

task.spawn(function()
	-- The avatar service yields (and can fail): Eggman is in the lobby meanwhile.
	local ok, problem = pcall(ensureFlash)
	if not ok then
		warn("[LobbyNpcs] The Flash was not built: " .. tostring(problem))
	end
end)

Workspace:GetAttributeChangedSignal(LobbyNpcConfig.KillAttribute):Connect(function()
	folder.Parent = if killed() then nil else Workspace
	refreshPrompts()
end)
Workspace:GetAttributeChangedSignal(U4.KillAttributePrefix .. "Race"):Connect(refreshPrompts)
Workspace.ChildAdded:Connect(function(child)
	if table.find(LobbyNpcConfig.BoothNames, child.Name) then
		task.delay(1, replaceFlash)
	end
end)

if not hasOwner("Eggman") and not LobbyNpcConfig.SpawnPartsEggman then
	print(string.format("[LobbyNpcs] %s: no Dr. Eggman in Workspace yet (a Model named Eggman, or tagged %s: design/npc/EGGMAN_EN_WORKSPACE.md)",
		WORLD, LobbyNpcConfig.Tags.Eggman))
end
