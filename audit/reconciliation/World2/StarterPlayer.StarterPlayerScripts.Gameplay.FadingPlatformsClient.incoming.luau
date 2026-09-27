-- FadingPlatformsClient: Runs platform fading 100% on the client.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local FADE_TIME = 2.0
local RESPAWN_TIME = 3.0
local FADED_TRANSPARENCY = 0.95

local fadingParts = {}
local debounces = {}

local function setupFadingPart(part)
	if not part:IsA("BasePart") or fadingParts[part] then return end
	if not part.Name:find("Fading") and not (part.Parent and part.Parent.Name:find("Fading")) then return end
	fadingParts[part] = {
		transparency = part.Transparency,
		canCollide = part.CanCollide
	}
	part.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then return end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		if debounces[part] then return end
		debounces[part] = true

		local orig = fadingParts[part]
		local tweenOut = TweenService:Create(part, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = FADED_TRANSPARENCY
		})
		tweenOut:Play()
		tweenOut.Completed:Wait()

		part.CanCollide = false
		task.wait(RESPAWN_TIME)

		local tweenIn = TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = orig.transparency
		})
		tweenIn:Play()
		tweenIn.Completed:Wait()

		part.CanCollide = orig.canCollide
		debounces[part] = false
	end)
end

for _, desc in ipairs(Workspace:GetDescendants()) do
	if desc.Name:find("Fading") and desc:IsA("BasePart") then
		setupFadingPart(desc)
	end
end
Workspace.DescendantAdded:Connect(function(desc)
	if desc.Name:find("Fading") and desc:IsA("BasePart") then
		setupFadingPart(desc)
	end
end)
