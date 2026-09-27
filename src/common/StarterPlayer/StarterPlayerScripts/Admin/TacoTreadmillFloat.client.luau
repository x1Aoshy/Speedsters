-- TacoTreadmillFloat.client.luau
-- The one taco that floats over the Taco Treadmill, turning and bobbing.
-- The server only places it (tag TacoTreadmillFloat, attribute FloatBase); moving it from there
-- meant 20 CFrames a second over the network and a taco that ticked round. Here it is moved
-- every rendered frame, from the server clock, so it is smooth and the same on every screen.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "TacoTreadmillFloat"
local BOB_STUDS, BOB_SPEED, TURN_SPEED = 0.9, 1.4, 1.1
local floating = {} -- part -> base CFrame

local function track(part)
	if not part:IsA("BasePart") then
		return
	end
	local function read()
		local base = part:GetAttribute("FloatBase")
		floating[part] = if typeof(base) == "CFrame" then base else part.CFrame
	end
	read()
	part:GetAttributeChangedSignal("FloatBase"):Connect(read)
end

for _, part in CollectionService:GetTagged(TAG) do
	track(part)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(part)
	floating[part] = nil
end)

RunService:BindToRenderStep("TacoTreadmillFloat", Enum.RenderPriority.First.Value, function(dt)
	if next(floating) == nil then
		return
	end
	-- While the treadmill is arriving as a meteor the reveal moves all of it, this taco included.
	if Workspace:FindFirstChild("TacoMeteor_Local") then
		return
	end
	local t = Workspace:GetServerTimeNow()
	local turn = (t * TURN_SPEED) % (2 * math.pi)
	local bob = math.sin(t * BOB_SPEED) * BOB_STUDS
	-- Eased towards the pose rather than set to it, so it also glides back after the arrival.
	local ease = 1 - math.exp(-10 * math.min(dt, 0.1))
	for part, base in floating do
		if part.Parent then
			local target = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0)
			if (part.Position - target.Position).Magnitude < 40 then
				part.CFrame = part.CFrame:Lerp(target, ease)
			end
		else
			floating[part] = nil
		end
	end
end)
