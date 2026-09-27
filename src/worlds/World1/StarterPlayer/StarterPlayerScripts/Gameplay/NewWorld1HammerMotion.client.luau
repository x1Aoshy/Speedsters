-- NewWorld1HammerMotion.client.luau
-- Swings World 1's hammers on this client, from the shared server clock.
--
-- The server no longer moves the hammers (it replicated 12 CFrames per hammer 30 times a
-- second, which stuttered and made the pieces look loose). It tags each hammer and leaves on
-- it the pivot, axis, phase and start time (Shared/World1HammerMotion). Here the real parts
-- are moved every frame, all in one BulkMoveTo, so the swing is smooth and the same on every
-- screen. Only hammers near this player move: beyond Motion.MidRadius they are left alone, and
-- between the two radii they move every second frame. Contact is still judged by
-- NewWorld1MapMotion on these same parts, so what is seen is what kills.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end
local Motion = require(Shared:WaitForChild("World1HammerMotion"))
local names = Motion.Attributes
local player = Players.LocalPlayer

local TIER_CHECK_SECONDS = 0.25
local hammers = {} -- model -> state

local function readSwing(model, state)
	local pivot = model:GetAttribute(names.Pivot)
	local axis = model:GetAttribute(names.Axis)
	local phase = model:GetAttribute(names.Phase)
	local epoch = model:GetAttribute(names.Epoch)
	if typeof(pivot) == "Vector3" and typeof(axis) == "Vector3" and axis.Magnitude > 0.5
		and type(phase) == "number" and type(epoch) == "number"
	then
		state.Pivot, state.Axis, state.Phase, state.Epoch = pivot, axis.Unit, phase, epoch
		state.Dirty = true -- its reach is measured from the pivot
	else
		state.Pivot = nil
	end
end

local function track(model)
	if hammers[model] then
		return
	end
	local state = {
		Bases = {}, -- part -> authored CFrame
		PartList = {}, BaseList = {}, Targets = {},
		Dirty = true,
		Tier = "far",
		NextTierAt = 0,
		Crossing = nil,
		Connections = {},
	}
	hammers[model] = state

	-- Parts stream in and out, and the server may tag them a moment after they arrive.
	local function consider(part)
		if not part:IsA("BasePart") then
			return
		end
		local function refresh()
			if part:GetAttribute(names.Moving) == true and part:IsDescendantOf(model) then
				if not state.Bases[part] then
					local base = part:GetAttribute(names.Base)
					state.Bases[part] = if typeof(base) == "CFrame" then base else part.CFrame
					state.Dirty = true
				end
			elseif state.Bases[part] then
				state.Bases[part] = nil
				state.Dirty = true
			end
		end
		table.insert(state.Connections, part:GetAttributeChangedSignal(names.Moving):Connect(refresh))
		refresh()
	end
	for _, item in model:GetDescendants() do
		consider(item)
	end
	table.insert(state.Connections, model.DescendantAdded:Connect(consider))
	table.insert(state.Connections, model.DescendantRemoving:Connect(function(item)
		if state.Bases[item] then
			state.Bases[item] = nil
			state.Dirty = true
		end
	end))
	for _, name in { names.Pivot, names.Axis, names.Phase, names.Epoch } do
		table.insert(state.Connections, model:GetAttributeChangedSignal(name):Connect(function()
			readSwing(model, state)
		end))
	end
	readSwing(model, state)
end

local function untrack(model)
	local state = hammers[model]
	if not state then
		return
	end
	hammers[model] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
end

for _, model in CollectionService:GetTagged(Motion.Tag) do
	track(model)
end
CollectionService:GetInstanceAddedSignal(Motion.Tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(Motion.Tag):Connect(untrack)

local function focusPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local function whoosh(model)
	local sound = model:FindFirstChild("VortexHammerWhoosh", true)
	if sound and sound:IsA("Sound") then
		sound.TimePosition = 0
		sound:Play()
	end
end

local frame = 0
RunService:BindToRenderStep("NewWorld1HammerMotion", Enum.RenderPriority.First.Value, function()
	frame += 1
	local clock = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local course = Workspace:GetAttribute(Motion.CourseAttribute)
	course = if typeof(course) == "Vector3" then course else nil
	local focus = nil
	for model, state in hammers do
		if not state.Pivot then
			continue
		end
		if state.Dirty then
			state.Dirty = false
			table.clear(state.PartList)
			table.clear(state.BaseList)
			table.clear(state.Targets)
			for part, base in state.Bases do
				table.insert(state.PartList, part)
				table.insert(state.BaseList, base)
			end
			state.Reach = Motion.Reach(state.Pivot, state.BaseList, state.PartList)
		end
		if clock >= state.NextTierAt then
			focus = focus or focusPosition()
			-- Passed hammers stand still: nothing behind the runner is moved.
			state.Tier = Motion.TierFor(focus, state.Pivot, course, state.Reach)
			state.NextTierAt = clock + TIER_CHECK_SECONDS
		end
		local tier = state.Tier
		if tier == "far" or (tier == "mid" and frame % Motion.MidFrameSkip ~= 0) then
			if tier == "far" then
				state.Crossing = nil
			end
			continue
		end
		if #state.PartList == 0 then
			continue
		end
		local elapsed = serverNow - state.Epoch
		local transform = Motion.Transform(state.Pivot, state.Axis, Motion.AngleAt(state.Phase, elapsed))
		local targets = state.Targets
		for index, base in state.BaseList do
			targets[index] = transform * base
		end
		Workspace:BulkMoveTo(state.PartList, targets, Enum.BulkMoveMode.FireCFrameChanged)

		-- The whoosh as the head passes the middle, for the hammers close enough to hear.
		if tier == "near" then
			local crossing = math.floor(Motion.PhaseAt(state.Phase, elapsed) / math.pi)
			if state.Crossing ~= nil and crossing ~= state.Crossing then
				whoosh(model)
			end
			state.Crossing = crossing
		else
			state.Crossing = nil
		end
	end
end)
