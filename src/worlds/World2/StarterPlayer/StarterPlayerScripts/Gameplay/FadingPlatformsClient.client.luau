-- Per-player fading platforms. Keep Gemini's timings; own and cancel local work.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local FADE_TIME = 2.0
local RESPAWN_TIME = 3.0
local FADED_TRANSPARENCY = 0.95
local fadingParts = {}

local function resetPart(part, state)
	state.run = nil -- Invalidate before Cancel resumes a waiting coroutine.
	if state.tween then state.tween:Cancel(); state.tween = nil end
	if part.Parent then
		part.Transparency = state.transparency
		part.CanCollide = state.canCollide
	end
end

local function setupFadingPart(part)
	if not part:IsA("BasePart") or fadingParts[part] then return end
	if not part.Name:find("Fading") and not (part.Parent and part.Parent.Name:find("Fading")) then return end
	local state = { transparency = part.Transparency, canCollide = part.CanCollide }
	fadingParts[part] = state
	state.connection = part.Touched:Connect(function(hit)
		local character = player.Character
		-- Accessories/tools alone should not consume the player's platform.
		if not character or not hit:IsA("BasePart") or hit.Parent ~= character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or state.run then return end
		local run = {}
		state.run = run
		local function current()
			return fadingParts[part] == state and state.run == run
				and part:IsDescendantOf(Workspace) and player.Character == character
		end
		local function tweenTo(transparency, duration, direction)
			if not current() then return false end
			local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, direction), { Transparency = transparency })
			state.tween = tween
			tween:Play()
			tween.Completed:Wait()
			if not current() then return false end
			state.tween = nil
			return true
		end
		if not tweenTo(FADED_TRANSPARENCY, FADE_TIME, Enum.EasingDirection.Out) then return end
		part.CanCollide = false
		task.wait(RESPAWN_TIME)
		if not current() then return end
		if not tweenTo(state.transparency, 0.8, Enum.EasingDirection.In) then return end
		resetPart(part, state)
	end)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do setupFadingPart(descendant) end
Workspace.DescendantAdded:Connect(setupFadingPart)
Workspace.DescendantRemoving:Connect(function(part)
	local state = fadingParts[part]
	if not state then return end
	fadingParts[part] = nil
	state.connection:Disconnect()
	resetPart(part, state)
end)
local function resetAll()
	for part, state in pairs(fadingParts) do resetPart(part, state) end
end
player.CharacterRemoving:Connect(resetAll)
player.CharacterAdded:Connect(resetAll)
