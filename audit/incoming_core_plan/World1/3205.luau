-- CtrlShiftLock.client.luau
-- Universal ShiftLock controller supporting PC (Keyboard/Mouse) and Console (PS4/PS5/Xbox).
-- Provides over-the-shoulder camera offset, center reticle, continuous mouse locking,
-- and continuous character yaw orientation matching the camera look direction.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local playerGui = player:WaitForChild("PlayerGui")

-- Create centered reticle GUI (visible on both PC and Console when ShiftLock is active)
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
local DEBOUNCE_TIME = 0.20
local RENDER_STEP_NAME = "SpeedsterShiftLockRenderStep"

local function isGamepadOrConsole(): boolean
	return GuiService:IsTenFootInterface() 
		or UserInputService.GamepadEnabled 
		or #UserInputService:GetConnectedGamepads() > 0
end

local function getCameraController()
	local ok, result = pcall(function()
		local pm = require(playerScripts:WaitForChild("PlayerModule"))
		local cameras = pm:GetCameras()
		return cameras and cameras.activeCameraController or nil
	end)
	if ok then return result end
	return nil
end

local function syncCameraMouseLock(active: boolean)
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
end

-- Clear Roblox's default MouseLockController BoundKeys so LeftShift (sprint) doesn't conflict
task.spawn(function()
	pcall(function()
		local pm = playerScripts:WaitForChild("PlayerModule", 8)
		if not pm then return end
		local cm = pm:WaitForChild("CameraModule", 8)
		if not cm then return end
		local mlc = cm:WaitForChild("MouseLockController", 5)
		if mlc then
			local bk = mlc:FindFirstChild("BoundKeys") or mlc:WaitForChild("BoundKeys", 3)
			if bk and bk:IsA("StringValue") then
				bk.Value = ""
			end
		end
	end)
end)

local function applyShiftLock(active: boolean)
	isShiftLockActive = active

	syncCameraMouseLock(active)

	pcall(function()
		if active then
			UserGameSettings.RotationType = Enum.RotationType.CameraRelative
		else
			UserGameSettings.RotationType = Enum.RotationType.MovementRelative
		end
	end)

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if active then
		if hum then
			hum.AutoRotate = false
		end
		reticleImage.Visible = true

		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		if isGamepadOrConsole() then
			pcall(function()
				local gp = game:GetService("GamepadService")
				if gp and gp.DisableGamepadCursor then gp:DisableGamepadCursor() end
			end)
		end
	else
		reticleImage.Visible = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		if hum then
			hum.AutoRotate = true
		end
	end
end

local function toggleShiftLock()
	local now = tick()
	if now - lastToggleTime < DEBOUNCE_TIME then return end
	lastToggleTime = now

	if player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() or GuiService.SelectedObject ~= nil then
		if isShiftLockActive then applyShiftLock(false) end
		return
	end

	applyShiftLock(not isShiftLockActive)
end

-- Continuous frame-by-frame lock: binds immediately after Camera updates (priority 201)
local function onRenderStep(deltaTime: number)
	if not isShiftLockActive then
		return
	end

	local inModalOrChat = GuiService.MenuIsOpen 
		or (GuiService.SelectedObject ~= nil) 
		or (UserInputService:GetFocusedTextBox() ~= nil)

	if inModalOrChat then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		reticleImage.Visible = false
		return
	end

	reticleImage.Visible = true

	-- Continuously maintain LockCenter so PC mouse never drifts or unlocks
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	if isGamepadOrConsole() then
		pcall(function()
			local gp = game:GetService("GamepadService")
			if gp and gp.DisableGamepadCursor then gp:DisableGamepadCursor() end
		end)
	end

	local char = player.Character
	if not char then return end

	-- Do not override rotation if seated or flying
	local isFlying = (player:GetAttribute("AdminFlying") == true)
		or (player:GetAttribute("FlightAbilityActive") == true)
		or (char:GetAttribute("FlightAbilityLocalActive") == true)

	if isFlying then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera

	if hum and hrp and hum.Health > 0 and not hum.Sit and cam then
		hum.AutoRotate = false
		local _, yaw, _ = cam.CFrame:ToOrientation()
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
	end
end

RunService:BindToRenderStep(
	RENDER_STEP_NAME,
	Enum.RenderPriority.Camera.Value + 1,
	onRenderStep
)

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

-- When character respawns, sync AutoRotate and camera mouse lock state
player.CharacterAdded:Connect(function(newChar)
	task.defer(function()
		local hum = newChar:WaitForChild("Humanoid", 4)
		if hum then
			if isShiftLockActive then
				hum.AutoRotate = false
			else
				hum.AutoRotate = true
			end
			hum.Died:Connect(function()
				hum.AutoRotate = true
			end)
		end
		if isShiftLockActive then
			syncCameraMouseLock(true)
		end
	end)
end)

-- Initial character setup if already loaded
if player.Character then
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			hum.AutoRotate = true
		end)
	end
end

-- InputBegan fallback for toggle keys
local function handleToggleInput(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end

	if input.KeyCode == Enum.KeyCode.ButtonL3 
		or input.KeyCode == Enum.KeyCode.DPadDown 
		or input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.RightControl then
		toggleShiftLock()
	end
end

UserInputService.InputBegan:Connect(handleToggleInput)

-- ContextActionService binding at high priority to guarantee L3/DPadDown/LeftControl reach us
ContextActionService:BindActionAtPriority(
	"SpeedsterShiftLockToggleDirect",
	function(actionName, inputState, inputObject)
		if player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox() then 
			return Enum.ContextActionResult.Pass 
		end
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
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl
)

-- When a GUI element gets selected (modal opened), release ShiftLock
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if GuiService.SelectedObject ~= nil and isShiftLockActive then
		applyShiftLock(false)
	end
end)

GuiService.MenuOpened:Connect(function() applyShiftLock(false) end)
UserInputService.WindowFocusReleased:Connect(function() applyShiftLock(false) end)
player:GetAttributeChangedSignal("SpeedsterMenuOpen"):Connect(function() if player:GetAttribute("SpeedsterMenuOpen") then applyShiftLock(false) end end)
UserInputService.GamepadDisconnected:Connect(function() applyShiftLock(false) end)

-- Start with ShiftLock OFF
task.defer(function()
	applyShiftLock(false)
end)
