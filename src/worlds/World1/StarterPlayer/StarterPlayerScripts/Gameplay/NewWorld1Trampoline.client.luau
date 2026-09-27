-- NewWorld1Trampoline.client.luau
-- The trampoline at the top of Stage 9's climb bounces this player's own character: a
-- character's physics belong to its client, so the bounce is immediate and exact here, where a
-- velocity written by the server would arrive late or not at all.
--
-- The server measures how far the feet must rise to come over the ledge of Stage 10 and
-- publishes it on the trampoline model (Shared/World1Trampoline has the maths and the story
-- of the 277,777 studs/s conveyor this replaces). Standing or landing on the trampoline
-- throws the character up with exactly the speed for that rise: v = sqrt(2 g h).
--
-- While the character rises, VortexLaunchUntil tells the run controller and the anti-fling
-- that this lift is meant; without it the controller flattens any upward speed of a runner
-- pushing against a wall, and the shaft is all walls.
--
-- Cost: nothing while no trampoline is streamed in or the character is further than
-- Trampoline.NearStuds from it; one short ray a frame while it stands near one.
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
local Trampoline = require(Shared:WaitForChild("World1Trampoline"))
local player = Players.LocalPlayer

local trampolines = {} -- model -> RaycastParams
local function track(model)
	if trampolines[model] then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	trampolines[model] = params
end
for _, model in CollectionService:GetTagged(Trampoline.Tag) do
	track(model)
end
CollectionService:GetInstanceAddedSignal(Trampoline.Tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(Trampoline.Tag):Connect(function(model)
	trampolines[model] = nil
end)

local lastBounceAt = -math.huge
local launchSpeed = 0

-- After the physics step, so the anti-fling (which compares the speed before and after a
-- step) never sees the launch as an impulse that came out of a collision.
RunService.Heartbeat:Connect(function()
	if next(trampolines) == nil then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or character:GetAttribute("Dead") == true then
		return
	end
	local now = os.clock()
	local velocity = root.AssemblyLinearVelocity

	local held = Trampoline.HeldSpeed(Workspace.Gravity, launchSpeed, now - lastBounceAt, velocity.Y)
	if held then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, held, velocity.Z)
		return
	end

	for model, params in trampolines do
		local rise = model:GetAttribute(Trampoline.RiseAttribute)
		if type(rise) ~= "number" or not model.Parent then
			continue
		end
		local speed = Trampoline.LaunchSpeed(Workspace.Gravity, rise)
		if not Trampoline.ShouldBounce(now, lastBounceAt, velocity.Y, speed) then
			continue
		end
		local pivot = model:IsA("PVInstance") and model:GetPivot().Position or root.Position
		if (pivot - root.Position).Magnitude > Trampoline.NearStuds then
			continue
		end
		local reach = Trampoline.FeetBelowRoot(humanoid.RigType == Enum.HumanoidRigType.R6, humanoid.HipHeight, root.Size.Y)
			+ Trampoline.ContactSlack
		if not Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) then
			continue
		end

		lastBounceAt, launchSpeed = now, speed
		character:SetAttribute(Trampoline.LaunchAttribute, now + Trampoline.AscentSeconds(Workspace.Gravity, rise) + 0.3)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, speed, velocity.Z)
		break
	end
end)
