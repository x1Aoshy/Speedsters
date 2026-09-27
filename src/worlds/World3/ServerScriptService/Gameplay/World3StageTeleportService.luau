-- World3StageTeleportService.luau
-- Where every World 3 (Desert) stage starts, for stage teleports, Skip purchases and
-- revives. Services.StageTeleportService hands this module out in World 3, so every
-- caller that already works in World 2 works here unchanged.
--
-- The desert map keeps each stage in a Workspace folder named "Stage N". The checkpoint
-- at the start of Stage N (2-10) sits inside that folder: a large block named "stage1"
-- carrying the "X1" (x2 Wins), "Win1" and "Skip1" pads. The designer copied one template,
-- so every stage's parts end in 1; the stage number comes from the folder, never from
-- the part name. Stage 1 starts at the lobby SpawnLocation and has no checkpoint.
--
-- The finish is the End (Workspace.End, after Stage 10), in World 1's naming: its
-- "Winstage1" marks the final Win pad and "Winstage2" (added by audit/compose_world3) the
-- final x2 pad; the finish block is the End's floor under them. An older map's finish,
-- the checkpoint template once more outside every Stage folder, is still read.
-- World3ManualStagePads marks it World3FinalWinStage = true; a part or model carrying
-- that mark always wins over both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local STAGE_COUNT = math.max(2, math.floor(tonumber(Config.World3StageCount) or 8))
local FINAL_ATTRIBUTE = "World3FinalWinStage"
local RUNTIME_FOLDER_NAME = "World3ManualStagePads_Runtime"
local ARRIVAL_GRACE_SECONDS = 1.75
local VERSION = "W3StageTeleport2"

local Service = {}
Service.StageCount = STAGE_COUNT
Service.FinalAttribute = FINAL_ATTRIBUTE

local PAD_PATTERNS = {
	{ Kind = "Checkpoint", Pattern = "^stage%d*$" },
	{ Kind = "Win", Pattern = "^win%d*$" },
	{ Kind = "Skip", Pattern = "^skip%d*$" },
	{ Kind = "X2", Pattern = "^x%d+$" },
	-- The End's final pads (World 1's naming).
	{ Kind = "FinalWin", Pattern = "^winstage1$" },
	{ Kind = "FinalX2", Pattern = "^winstage2$" },
}

local function normalizeName(value)
	return (string.gsub(string.lower(tostring(value or "")), "[^%w]", ""))
end

local function stageFromFolderName(name)
	local stage = tonumber(string.match(string.lower(tostring(name or "")), "^stage%s*(%d+)$"))
	if stage and stage >= 1 and stage <= STAGE_COUNT then
		return math.floor(stage)
	end
	return nil
end

local function padKind(object)
	if not object:IsA("BasePart") then
		return nil
	end
	local name = normalizeName(object.Name)
	for _, entry in PAD_PATTERNS do
		if string.match(name, entry.Pattern) then
			return entry.Kind
		end
	end
	return nil
end

-- Reads the course from `root` (the Workspace, or a copy of it offline). Returns
-- {
--   Stages = { [N] = { Folder, Checkpoint, Win, Skip, X2 } } for every "Stage N" folder,
--   Spawn = the SpawnLocation directly in the "Lobby" folder, else the first one anywhere,
--   Finish = { Model, Checkpoint, Win, X2, Skip } for the finish block,
--   Final = the first object marked World3FinalWinStage, else the finish block,
--   Problems = { text } for anything a stage is missing or has twice,
-- }
-- Pure reads of names, classes and attributes, so the offline tests run it on the map.
local function insideStageFolder(object, root)
	local current = object.Parent
	while current and current ~= root do
		if current:IsA("Folder") and stageFromFolderName(current.Name) then
			return true
		end
		current = current.Parent
	end
	return false
end

function Service.ReadCourse(root)
	local course = { Stages = {}, Spawn = nil, Finish = nil, Final = nil, Problems = {} }
	for _, child in root:GetChildren() do
		local stage = child:IsA("Folder") and stageFromFolderName(child.Name) or nil
		if stage then
			if course.Stages[stage] then
				table.insert(course.Problems, "Two folders for Stage " .. stage)
			else
				local entry = { Folder = child }
				for _, descendant in child:GetDescendants() do
					local kind = padKind(descendant)
					if kind and kind ~= "FinalWin" and kind ~= "FinalX2" then
						if entry[kind] then
							table.insert(course.Problems, "Stage " .. stage .. " has two " .. kind .. " parts: " .. descendant:GetFullName())
						else
							entry[kind] = descendant
						end
					end
				end
				course.Stages[stage] = entry
			end
		end
	end
	for stage = 2, STAGE_COUNT do
		local entry = course.Stages[stage]
		if not entry then
			table.insert(course.Problems, "Stage " .. stage .. " folder is missing")
		else
			for _, kind in { "Checkpoint", "Win", "Skip", "X2" } do
				if not entry[kind] then
					table.insert(course.Problems, "Stage " .. stage .. " has no " .. kind .. " part")
				end
			end
		end
	end

	local lobby = root:FindFirstChild("Lobby")
	local anywhere = nil
	local finalWin, finalX2 = nil, nil
	for _, descendant in root:GetDescendants() do
		local kind = padKind(descendant)
		if kind == "FinalWin" and not finalWin and not insideStageFolder(descendant, root) then
			finalWin = descendant
		elseif kind == "FinalX2" and not finalX2 and not insideStageFolder(descendant, root) then
			finalX2 = descendant
		end
		if descendant:IsA("SpawnLocation") then
			if lobby and descendant.Parent == lobby then
				course.Spawn = descendant
			elseif not anywhere then
				anywhere = descendant
			end
		end
		if not course.Final and descendant:GetAttribute(FINAL_ATTRIBUTE) == true
			and (descendant:IsA("BasePart") or descendant:IsA("Model"))
		then
			course.Final = descendant
		end
		if padKind(descendant) == "Checkpoint" and descendant.Parent ~= root and not insideStageFolder(descendant, root) then
			local finish = { Model = descendant.Parent, Checkpoint = descendant }
			for _, sibling in descendant.Parent:GetDescendants() do
				local kind = padKind(sibling)
				if kind and kind ~= "Checkpoint" and not finish[kind] then
					finish[kind] = sibling
				end
			end
			if finish.Win and finish.X2 then
				if course.Finish then
					table.insert(course.Problems, "Two finish blocks: " .. descendant:GetFullName())
				else
					course.Finish = finish
				end
			end
		end
	end
	-- The End: the final pad markers on the floor under them: of the wide parts of their
	-- folder that cover the Win marker, the lowest surface not below it (the markers are sunk
	-- into the floor; the finish arch overhead is not the floor).
	if not course.Finish and finalWin then
		local floor, floorTop = nil, math.huge
		local winCentre = finalWin.CFrame.Position
		for _, part in finalWin.Parent:GetDescendants() do
			if part:IsA("BasePart") and part ~= finalWin and part ~= finalX2 then
				local local_ = part.CFrame:PointToObjectSpace(winCentre)
				local top = part.CFrame.Position.Y + part.Size.Y / 2
				if math.abs(local_.X) <= part.Size.X / 2 and math.abs(local_.Z) <= part.Size.Z / 2
					and top >= winCentre.Y and part.Size.X * part.Size.Z > 2500 and top < floorTop
				then
					floor, floorTop = part, top
				end
			end
		end
		if floor then
			course.Finish = { Model = finalWin.Parent, Checkpoint = floor, Win = finalWin, X2 = finalX2, End = true }
			if not finalX2 then
				table.insert(course.Problems, "The End has no Winstage2 (the finish's x2 pad)")
			end
		else
			table.insert(course.Problems, "No floor under the End's Winstage1")
		end
	end
	course.Spawn = course.Spawn or anywhere
	course.Final = course.Final or (course.Finish and course.Finish.Checkpoint)
	if not course.Spawn then
		table.insert(course.Problems, "No SpawnLocation")
	end
	if not course.Finish then
		table.insert(course.Problems, "No finish (the End's Winstage1, or a stage block with Win and X pads outside the Stage folders)")
	end
	return course
end

----------------------------------------------------------------------
-- The live course, re-read whenever a part that could belong to it changes
----------------------------------------------------------------------
local course = nil

local function affectsCourse(object)
	if object:IsA("SpawnLocation") or padKind(object) then
		return true
	end
	if object:IsA("Folder") and stageFromFolderName(object.Name) then
		return true
	end
	return object:GetAttribute(FINAL_ATTRIBUTE) ~= nil
end

local function currentCourse()
	if not course then
		course = Service.ReadCourse(Workspace)
		for _, problem in course.Problems do
			warn("[World3StageTeleportService] " .. problem)
		end
	end
	return course
end

local function invalidate(object)
	if course and affectsCourse(object) then
		course = nil
	end
end

----------------------------------------------------------------------
-- Geometry
----------------------------------------------------------------------
local function bounds(object)
	if not object or not object.Parent then
		return nil, nil
	end
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	if object:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return cframe, size
		end
	end
	return nil, nil
end

-- The middle of the object's top face.
local function topCentre(object)
	local cframe, size = bounds(object)
	if not cframe then
		return nil
	end
	return (cframe * CFrame.new(0, size.Y / 2, 0)).Position
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Where each stage starts, in course order: [1] the lobby spawn, [N] Stage N's checkpoint.
function Service.GetStageReferencePosition(stage)
	stage = math.floor(tonumber(stage) or 0)
	local live = currentCourse()
	if stage == 1 then
		return live.Spawn and live.Spawn.Parent and live.Spawn.CFrame.Position or nil
	end
	local entry = live.Stages[stage]
	return entry and topCentre(entry.Checkpoint) or nil
end

-- The markers of Stage N's checkpoint (Checkpoint, Win, Skip, X2), for the pad services.
function Service.GetStageMarkers(stage)
	local entry = currentCourse().Stages[math.floor(tonumber(stage) or 0)]
	if not entry then
		return nil
	end
	return { Checkpoint = entry.Checkpoint, Win = entry.Win, Skip = entry.Skip, X2 = entry.X2 }
end

function Service.GetFinalMarker()
	local final = currentCourse().Final
	return if final and final.Parent then final else nil
end

-- The finish block and its pads (Checkpoint, Win, X2, Skip), for the pad services.
function Service.GetFinish()
	local finish = currentCourse().Finish
	if not finish or not finish.Checkpoint.Parent then
		return nil
	end
	return { Model = finish.Model, Checkpoint = finish.Checkpoint, Win = finish.Win, X2 = finish.X2, Skip = finish.Skip, End = finish.End }
end

-- The direction the course runs from `stage` on, level with the ground.
local function forwardFrom(stage)
	local here = Service.GetStageReferencePosition(stage)
	local ahead = if stage < STAGE_COUNT then Service.GetStageReferencePosition(stage + 1) else nil
	if not ahead and stage >= STAGE_COUNT then
		ahead = topCentre(Service.GetFinalMarker())
	end
	if here and ahead and flat(ahead - here).Magnitude > 1 then
		return flat(ahead - here).Unit
	end
	local behind = if stage > 1 then Service.GetStageReferencePosition(stage - 1) else nil
	if here and behind and flat(here - behind).Magnitude > 1 then
		return flat(here - behind).Unit
	end
	return Vector3.new(0, 0, -1)
end

-- How far past its middle a checkpoint still counts as reached, along the course: half
-- its depth in that direction, so standing anywhere on the block counts.
local function halfDepthAlong(object, direction)
	local cframe, size = bounds(object)
	if not cframe then
		return 0
	end
	return math.abs(cframe.RightVector:Dot(direction)) * size.X / 2
		+ math.abs(cframe.UpVector:Dot(direction)) * size.Y / 2
		+ math.abs(cframe.LookVector:Dot(direction)) * size.Z / 2
end

-- The stage whose checkpoint `position` has most recently passed along the course, and
-- the level distance to that checkpoint. A revive from here never moves anyone ahead of
-- where they fell, even when the next checkpoint is closer.
function Service.GetNearestStage(position)
	if typeof(position) ~= "Vector3" then
		return nil, nil
	end
	local live = currentCourse()
	local reached = 1
	-- The checkpoints are anchored map blocks that nothing moves: the line through them is
	-- measured once per course read (adding or removing a piece of the course starts a new
	-- read), not for every player ten times a second (MovementGuard and World3Hazards ask).
	local line = live.Line
	if not line then
		line = {}
		local previous = Service.GetStageReferencePosition(1)
		for stage = 2, STAGE_COUNT do
			local entry = live.Stages[stage]
			local here = entry and topCentre(entry.Checkpoint)
			if here then
				local from = previous or here
				local segment = flat(here - from)
				if segment.Magnitude > 1 then
					local direction = segment.Unit
					table.insert(line, {
						Stage = stage,
						From = from,
						Direction = direction,
						Reach = segment.Magnitude - halfDepthAlong(entry.Checkpoint, direction),
					})
				end
				previous = here
			end
		end
		live.Line = line
	end
	for _, leg in line do
		if flat(position - leg.From):Dot(leg.Direction) >= leg.Reach then
			reached = leg.Stage
		end
	end
	local reference = Service.GetStageReferencePosition(reached)
	return reached, reference and flat(position - reference).Magnitude or nil
end

----------------------------------------------------------------------
-- Teleports
----------------------------------------------------------------------
local function isPad(part)
	local kind = padKind(part)
	return part:GetAttribute("World3ManualPad") == true or (kind ~= nil and kind ~= "Checkpoint")
end

-- The ground under `point`: what a character would really stand on, skipping pads and
-- the pads' own decorations. Falls back to `point` itself.
local function groundAt(point, character)
	local filter = {}
	if character then
		table.insert(filter, character)
	end
	local runtime = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
	if runtime then
		table.insert(filter, runtime)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	for _ = 1, 4 do
		local result = Workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		if not result then
			break
		end
		if not isPad(result.Instance) then
			return result.Position
		end
		table.insert(filter, result.Instance)
		params.FilterDescendantsInstances = filter
	end
	return point
end

local function zeroVelocity(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function place(player, ground, forward, stage, markerKind)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false, "Character is not ready"
	end
	local standHeight = math.max(3.25, humanoid.HipHeight + root.Size.Y / 2 + 0.55)
	local target = ground + Vector3.new(0, standHeight, 0)
	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + ARRIVAL_GRACE_SECONDS)
	-- Clients read this copy on the shared clock; the one above is the server's os.clock() (2026-09-21).
	player:SetAttribute("StageTeleportArrivalGraceUntilServerTime", Workspace:GetServerTimeNow() + ARRIVAL_GRACE_SECONDS)
	zeroVelocity(character)
	character:PivotTo(CFrame.lookAt(target, target + forward, Vector3.yAxis))
	zeroVelocity(character)
	player:SetAttribute("LastReachedStage", stage)
	player:SetAttribute("CurrentSafeZoneStage", stage)
	player:SetAttribute("World3TeleportMarkerKind", markerKind)
	player:SetAttribute("World3AtFinalWinStage", markerKind == "final")
	local rebase = _G.VortexMovementGuardRebase
	if type(rebase) == "function" then
		pcall(rebase, player, stage)
	end
	return true
end

function Service.TeleportPlayer(player, stage)
	stage = math.floor(tonumber(stage) or 0)
	if stage < 1 or stage > STAGE_COUNT then
		return false, "Invalid stage"
	end
	local character = player and player.Character
	if stage == 1 then
		local spawn = player and player.RespawnLocation
		if not (spawn and spawn.Parent and spawn:IsA("SpawnLocation")) then
			spawn = currentCourse().Spawn
		end
		if not (spawn and spawn.Parent) then
			return false, "World 3 spawn is not ready"
		end
		return place(player, topCentre(spawn), forwardFrom(1), 1, "spawn")
	end
	local markers = Service.GetStageMarkers(stage)
	local top = markers and topCentre(markers.Checkpoint)
	if not top then
		return false, "World 3 Stage " .. stage .. " checkpoint is not ready"
	end
	return place(player, groundAt(top, character), forwardFrom(stage), stage, "checkpoint")
end

function Service.TeleportToFinalWinStage(player)
	local final = Service.GetFinalMarker()
	local top = topCentre(final)
	if not top then
		return false, "World 3 finish is not ready"
	end
	return place(player, groundAt(top, player and player.Character), forwardFrom(STAGE_COUNT), STAGE_COUNT, "final")
end

-- A bought Skip on Stage N's checkpoint moves the player to Stage N + 1, or to the finish
-- from the last stage.
function Service.TeleportSkipPurchase(player, fromStage)
	fromStage = math.floor(tonumber(fromStage) or 0)
	if fromStage < 2 or fromStage > STAGE_COUNT then
		return false, "Invalid World 3 Skip stage"
	end
	if fromStage == STAGE_COUNT then
		local ok, reason = Service.TeleportToFinalWinStage(player)
		if not ok then
			return false, reason
		end
		return true, { IsFinal = true, FromStage = fromStage, Stage = STAGE_COUNT, Message = "Skipped to the finish" }
	end
	local targetStage = fromStage + 1
	local ok, reason = Service.TeleportPlayer(player, targetStage)
	if not ok then
		return false, reason
	end
	return true, { IsFinal = false, FromStage = fromStage, Stage = targetStage, Message = "Skipped to Stage " .. targetStage }
end

function Service.TeleportToStart(player)
	return Service.TeleportPlayer(player, 1)
end

Service.TeleportToNormalSpawn = Service.TeleportToStart

Workspace.DescendantAdded:Connect(invalidate)
Workspace.DescendantRemoving:Connect(invalidate)

local ready = currentCourse()
local found = 0
for stage = 2, STAGE_COUNT do
	if ready.Stages[stage] and ready.Stages[stage].Checkpoint then
		found += 1
	end
end
print(string.format("[World3StageTeleportService] %s loaded | %d/%d checkpoints | spawn=%s | finish=%s",
	VERSION, found, STAGE_COUNT - 1, tostring(ready.Spawn ~= nil), tostring(ready.Final ~= nil)))

return Service
