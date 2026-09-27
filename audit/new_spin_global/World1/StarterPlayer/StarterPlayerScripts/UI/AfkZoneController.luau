-- AfkZoneController.client.luau
-- AFK Mode on this player's side (the server holds it: Social/AfkZoneService). The AFK
-- Zone's circle in the lobby is gone (2026-09-18, Sung's request): AFK Mode is turned on
-- and off from the Earnings panel (UI/AfkRewardsController). This script:
--   * shows a small AFK MODE line (time, Speed and Spin Tickets earned) while AFK Mode is on
--     and the panel is closed; tapping it opens the panel again (with Exit AFK);
--   * keeps the player from Roblox's 20-minute idle kick while AFK Mode is on: on
--     Player.Idled it nudges the controls through VirtualUser, and where the engine does not
--     let a game script do that, it rejoins this same place a little before the kick with
--     teleport data that turns AFK Mode back on (AfkModeResume).
--
-- A preview feature (Shared.FeatureGate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FeatureGate = require(Shared:WaitForChild("FeatureGate"))
if not FeatureGate.IsPreviewPlayer(player) then
	return
end

local Config = require(Shared:WaitForChild("Config"))
local settings = Config.AfkZone
if type(settings) ~= "table" or settings.Enabled ~= true then
	return
end

local DesignerUiBuilder = require(Shared:WaitForChild("DesignerUiBuilder"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local SpinWheelCatalog = require(Shared:WaitForChild("SpinWheelCatalog"))
local SpinWheelGuiSpec = require(Shared:WaitForChild("DesignerUi"):WaitForChild("SpinWheelGui"))

-- Roblox kicks after 20 minutes without input. Past this many idle seconds, with the
-- controls not nudged, AFK Mode rejoins.
local REJOIN_AFTER_IDLE_SECONDS = 16 * 60

-- The designer's text style (white GothamSSm with a scaled dark stroke), taken from the
-- Spin Wheel panel's countdown label so every preview surface reads alike.
local styleSource = DesignerUiBuilder.Build(SpinWheelGuiSpec)
local templateLabel = styleSource:FindFirstChild("Button"):FindFirstChild("TextLabel")
local function styledLabel(text, parent)
	local label = templateLabel:Clone()
	local constraint = label:FindFirstChildOfClass("UIAspectRatioConstraint")
	if constraint then
		constraint:Destroy()
	end
	label.Text = text
	label.Parent = parent
	return label
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

----------------------------------------------------------------------
-- The AFK MODE line, while the panel is closed
----------------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "AfkZoneHud"
hud.ResetOnSpawn = false
hud.Enabled = false
hud.Parent = player:WaitForChild("PlayerGui")

local hudLabel = styledLabel("", hud)
hudLabel.AnchorPoint = Vector2.new(0.5, 1)
-- Above the level bar's "Speed" readout, with room to spare.
hudLabel.Position = UDim2.new(0.5, 0, 0.655, 0)
hudLabel.Size = UDim2.new(0.32, 0, 0.025, 0)
hudLabel.TextColor3 = Color3.fromRGB(120, 205, 255)

-- The whole line is a button: it opens the panel (with Exit AFK) again.
local reopen = Instance.new("TextButton")
reopen.Name = "Open"
reopen.BackgroundTransparency = 1
reopen.Text = ""
reopen.Size = UDim2.fromScale(1, 1)
reopen.Parent = hudLabel
reopen.Activated:Connect(function()
	MenuEvents.Get("OpenAfkPanel"):Fire("Open")
end)

styleSource:Destroy()

local playerGui = player:WaitForChild("PlayerGui")
local function earningsOpen()
	local panel = playerGui:FindFirstChild("AfkRewardsGui")
	return panel ~= nil and panel:IsA("ScreenGui") and panel.Enabled
end

local function active()
	return player:GetAttribute("AfkModeActive") == true
end

local function refresh()
	hud.Enabled = active() and not earningsOpen()
	if hud.Enabled then
		local since = tonumber(player:GetAttribute("AfkModeSince")) or Workspace:GetServerTimeNow()
		hudLabel.Text = "AFK MODE  "
			.. clock(Workspace:GetServerTimeNow() - since)
			.. "  |  +"
			.. SpinWheelCatalog.FormatNumber(tonumber(player:GetAttribute("AfkModeSpeed")) or 0)
			.. " Speed  |  +"
			.. tostring(tonumber(player:GetAttribute("AfkModeTickets")) or 0)
			.. " Spins"
	end
end

for _, attribute in { "AfkModeActive", "AfkModeSpeed", "AfkModeTickets", "AfkModeRewardIn" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
task.spawn(function()
	local panel = playerGui:WaitForChild("AfkRewardsGui", 30)
	if panel then
		panel:GetPropertyChangedSignal("Enabled"):Connect(refresh)
	end
end)
refresh()

----------------------------------------------------------------------
-- Staying past the idle kick
----------------------------------------------------------------------
-- VirtualUser's methods are for Roblox's own scripts; in a live game a game script is
-- usually refused, so this answers with a pcall and falls back to the rejoin.
local function nudge(): boolean
	local ok = pcall(function()
		local VirtualUser = game:GetService("VirtualUser")
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
	return ok
end

local rejoining = false
local function rejoin()
	if rejoining then
		return
	end
	rejoining = true
	local ok = pcall(function()
		TeleportService:Teleport(game.PlaceId, player, { AfkModeResume = true })
	end)
	if not ok then
		rejoining = false
	end
end

player.Idled:Connect(function(idleSeconds)
	if not active() then
		return
	end
	if nudge() then
		return
	end
	if (tonumber(idleSeconds) or 0) >= REJOIN_AFTER_IDLE_SECONDS then
		rejoin()
	end
end)
TeleportService.TeleportInitFailed:Connect(function(who)
	if who == player then
		rejoining = false
	end
end)

-- The clock on the line ticks every second while it shows.
task.spawn(function()
	while true do
		task.wait(1)
		if hud.Enabled then
			refresh()
		end
	end
end)

----------------------------------------------------------------------
-- Movement detection: prompt exit confirmation when player tries to move
----------------------------------------------------------------------
local lastMovePromptAt = 0
local function onMovementDetected()
	if not active() then
		return
	end
	if os.clock() - lastMovePromptAt < 1.0 then
		return
	end
	lastMovePromptAt = os.clock()
	MenuEvents.Get("OpenAfkPanel"):Fire("MovementPrompt")
end

RunService.RenderStepped:Connect(function()
	if not active() then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if humanoid.MoveDirection.Magnitude > 0.05 or humanoid.Jump then
		onMovementDetected()
	end
end)

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Space] = true,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not active() then
		return
	end
	if MOVE_KEYS[input.KeyCode] then
		onMovementDetected()
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or not active() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local pos = input.Position
		if Vector2.new(pos.X, pos.Y).Magnitude > 0.25 then
			onMovementDetected()
		end
	end
end)

print("[AfkModeController] ready")
