-- CtrlShiftLock.client.luau
-- Standalone ShiftLock controller that works on PC AND Console (PS4/PS5/Xbox).
-- Roblox's built-in MouseLockController disables itself on Gamepad ControlMode,
-- so we bypass it entirely: we set RotationType directly, call SetIsMouseLocked
-- on the active camera controller, and render our own centered reticle on console.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local playerGui = player:WaitForChild("PlayerGui")

-- Create a centered reticle GUI for console (PC uses the native mouse-lock cursor)
local reticleGui = Instance.new("ScreenGui")
reticleGui.Name = "ConsoleShiftLockReticle"
reticleGui.ResetOnSpawn = false
reticleGui.DisplayOrder = 90
reticleGui.IgnoreGuiInset = true

local reticleImage = Instance.new("ImageLabel")
reticleImage.Name = "Reticle"
reticleImage.AnchorPoint = Vector2.new(0.5, 0.5)
reticleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
reticleImage.Size = UDim2.new(0, 28, 0, 28)
reticleImage.BackgroundTransparency = 1
reticleImage.Image = "rbxasset://textures/MouseLockedCursor.png"
reticleImage.Visible = false
reticleImage.Parent = reticleGui

reticleGui.Parent = playerGui

local isShiftLockActive = false
local lastToggleTime = 0
local DEBOUNCE_TIME = 0.22

local function getCameraController()
	local ok, result = pcall(function()
		local pm = require(playerScripts:WaitForChild("PlayerModule"))
		local cameras = pm:GetCameras()
		return cameras and cameras.activeCameraController or nil
	end)
	if ok then return result end
	return nil
end

local function applyShiftLock(active: boolean)
	isShiftLockActive = active

	local isConsoleOrGamepad = GuiService:IsTenFootInterface() 
		or UserInputService.GamepadEnabled 
		or #UserInputService:GetConnectedGamepads() > 0

	local camCtrl = getCameraController()
	if camCtrl then
		pcall(function()
			if active then
				camCtrl:SetIsMouseLocked(true)
				camCtrl:SetMouseLockOffset(Vector3.new(1.75, 0, 0))
			else
				camCtrl:SetIsMouseLocked(false)
				camCtrl:SetMouseLockOffset(Vector3.new(0, 0, 0))
			end
		end)
	end

	pcall(function()
		if active then
			UserGameSettings.RotationType = Enum.RotationType.CameraRelative
		else
			UserGameSettings.RotationType = Enum.RotationType.MovementRelative
		end
	end)

	if isConsoleOrGamepad then
		reticleImage.Visible = active
		if active then
			pcall(function()
				local gp = game:GetService("GamepadService")
				if gp and gp.DisableGamepadCursor then gp:DisableGamepadCursor() end
			end)
		end
	else
		reticleImage.Visible = false
		pcall(function()
			if active then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end)
	end
end

local function toggleShiftLock()
	local now = tick()
	if now - lastToggleTime < DEBOUNCE_TIME then return end
	lastToggleTime = now

	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() or GuiService.SelectedObject ~= nil then
		if isShiftLockActive then applyShiftLock(false) end
		return
	end

	applyShiftLock(not isShiftLockActive)
end

-- BindableEvent so UI scripts (ConsoleUiScale, UpdateLogsController) can suspend/disable ShiftLock
local shiftLockEvent = playerScripts:FindFirstChild("ShiftLockControlEvent")
if not shiftLockEvent then
	shiftLockEvent = Instance.new("BindableEvent")
	shiftLockEvent.Name = "ShiftLockControlEvent"
	shiftLockEvent.Parent = playerScripts
end

shiftLockEvent.Event:Connect(function(action, value)
	if action == "Disable" or action == "Off" then
		applyShiftLock(false)
	elseif action == "Enable" or action == "On" then
		applyShiftLock(true)
	elseif action == "Toggle" then
		toggleShiftLock()
	end
end)

-- InputBegan fallback for toggle keys
local function handleToggleInput(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end

	if input.KeyCode == Enum.KeyCode.ButtonL3 
		or input.KeyCode == Enum.KeyCode.DPadDown 
		or input.KeyCode == Enum.KeyCode.LeftControl then
		toggleShiftLock()
	end
end

UserInputService.InputBegan:Connect(handleToggleInput)

-- ContextActionService binding at high priority to guarantee L3/DPadDown/LeftControl reach us
ContextActionService:BindActionAtPriority(
	"SpeedsterShiftLockToggleDirect",
	function(actionName, inputState, inputObject)
		if GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then
			toggleShiftLock()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end,
	false,
	Enum.ContextActionPriority.High.Value + 20,
	Enum.KeyCode.ButtonL3,
	Enum.KeyCode.DPadDown,
	Enum.KeyCode.LeftControl
)

-- When a GUI element gets selected (menu opened), release ShiftLock immediately
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if GuiService.SelectedObject ~= nil and isShiftLockActive then
		applyShiftLock(false)
	end
end)

GuiService.MenuOpened:Connect(function() applyShiftLock(false) end)
UserInputService.GamepadDisconnected:Connect(function() applyShiftLock(false) end)

-- Start with ShiftLock OFF
task.defer(function()
	applyShiftLock(false)
end)
