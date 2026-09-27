local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local Config = require(Shared:WaitForChild("Config"))

local WORLD_1_PLACE_ID = Config.World1PlaceId or 85065221510105
local WORLD_2_PLACE_ID = Config.World2PlaceId or 96501592055150
local WORLD_2_REQUIRED_REBIRTHS = 7
local WORLD_2_REQUIRED_LEVEL = 100
local OPEN_POSITION = UDim2.fromScale(0.5, 0.48)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.28)
local PORTAL_TOUCH_COOLDOWN = 1.5
local PORTAL_SOUND_ID = "rbxassetid://72264591133889"

local GREEN_GRADIENT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(132, 255, 0)),
	ColorSequenceKeypoint.new(0.78, Color3.fromRGB(30, 210, 45)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 165, 93)),
})
local GREEN_STROKE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 255, 55)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(123, 255, 75)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 17)),
})

local ORANGE_GRADIENT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 3)),
	ColorSequenceKeypoint.new(0.78, Color3.fromRGB(210, 203, 14)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 116, 19)),
})
local ORANGE_STROKE_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(251, 255, 3)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(255, 240, 29)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 187, 52)),
})

local isOpen = false
local activeTween = nil
local dimTween = nil
local openSerial = 0
local lastPortalTouch = 0

-- Clean up any obsolete sound clone
local oldClickSound = SoundService:FindFirstChild("WorldsPanelClickSound")
if oldClickSound then
	oldClickSound:Destroy()
end

local clickSound = Instance.new("Sound")
clickSound.Name = "WorldsPanelClickSound"
clickSound.SoundId = PORTAL_SOUND_ID
clickSound.Volume = 0.65
clickSound.PlaybackSpeed = 1
clickSound.Parent = SoundService

local function playClick()
	clickSound.TimePosition = 0
	SoundService:PlayLocalSound(clickSound)
end

local worldsGui = playerGui:WaitForChild("Worlds")
worldsGui.ResetOnSpawn = false
local worldsFrame = worldsGui:WaitForChild("Worlds")
local closeButton = worldsFrame:WaitForChild("Close")
local scrollingFrame = worldsFrame:WaitForChild("ScrollingFrame")

local world1Frame = scrollingFrame:WaitForChild("World1")
local world2Frame = scrollingFrame:WaitForChild("World2")

local world1FrameInner = world1Frame:WaitForChild("Frame")
for _, child in ipairs(world1FrameInner:GetChildren()) do
	if child:IsA("GuiButton") and child.Name ~= "Button" then
		child:Destroy()
	end
end

local world2FrameInner = world2Frame:WaitForChild("Frame")
for _, child in ipairs(world2FrameInner:GetChildren()) do
	if child:IsA("GuiButton") and child.Name ~= "Button" then
		child:Destroy()
	end
end

local world1Button = world1FrameInner:WaitForChild("Button")
local world2Button = world2FrameInner:WaitForChild("Button")

-- All world travel is server-authoritative: WorldPortalService owns the
-- 7 Rebirths + Level 100 gate, the World2Unlocked flag and the teleport itself.
local WorldsRemotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldPortalAction = WorldsRemotes:WaitForChild("WorldPortalAction")
local WorldsPortalRemote = WorldsRemotes:WaitForChild("WorldPortalUpdate")

-- Transient message area (lock reasons, teleport errors, studio preview notes).
local statusLabel = worldsFrame:FindFirstChild("WorldStatusLabel")
if not statusLabel or not statusLabel:IsA("TextLabel") then
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "WorldStatusLabel"
	statusLabel.AnchorPoint = Vector2.new(0.5, 1)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -8)
	statusLabel.Size = UDim2.new(1, -40, 0, 50)
	statusLabel.BackgroundTransparency = 1
	statusLabel.BorderSizePixel = 0
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextSize = 14
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.ZIndex = 10

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = statusLabel

	statusLabel.Parent = worldsFrame
end

local function setStatus(text)
	statusLabel.Text = text or ""
end

-- First-visit confirmation: the first click on World 2 arms a "TELEPORT" button
-- instead of travelling; a second click confirms. Once World2Unlocked is set,
-- later visits travel directly with no confirmation.
local world2ConfirmArmed = false

local function resetWorld2Confirm()
	world2ConfirmArmed = false
end

-- Requirement helpers mirror WorldPortalService's authoritative gate so the
-- panel can explain the 7 Rebirths + Level 100 rule before asking the server.
local function getRebirths()
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Rebirths")
	return value and tonumber(value.Value) or 0
end

local function getLevel()
	local level = tonumber(player:GetAttribute("Level"))
	if level then
		return math.max(1, math.floor(level))
	end
	local dataFolder = player:FindFirstChild("SpeedsterData")
	local value = dataFolder and dataFolder:FindFirstChild("Level")
	return math.max(1, math.floor(tonumber(value and value.Value) or 1))
end

local function meetsWorld2Requirements()
	return getRebirths() >= WORLD_2_REQUIRED_REBIRTHS and getLevel() >= WORLD_2_REQUIRED_LEVEL
end

local function getCurrentWorld()
	if Config.IsWorld2Place == true
		or ReplicatedStorage:GetAttribute("PlaceWorldNumber") == 2
		or Workspace:GetAttribute("PlaceWorldNumber") == 2
		or game.PlaceId == WORLD_2_PLACE_ID
		or game.PlaceId == 96501592055150
		or game.PlaceId == 116359653478954
		or Workspace:FindFirstChild("safezone2.2") ~= nil
		or Workspace:FindFirstChild("SixSevenArea") ~= nil
		or Workspace:FindFirstChild("Japanese Torii Gate") ~= nil
	then
		return 2
	end
	return 1
end

local currentWorld = getCurrentWorld()

local function applyButtonTheme(button, isCurrentWorld, text)
	if not button then
		return
	end
	local label = button:FindFirstChild("Name")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end

	local grad = button:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = isCurrentWorld and GREEN_GRADIENT_COLOR or ORANGE_GRADIENT_COLOR
	end

	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("UIStroke") then
			local strokeGrad = child:FindFirstChildOfClass("UIGradient")
			if strokeGrad then
				strokeGrad.Color = isCurrentWorld and GREEN_STROKE_COLOR or ORANGE_STROKE_COLOR
			end
		end
	end

	button.Active = not isCurrentWorld
	button.AutoButtonColor = not isCurrentWorld
end

local function updateWorldButtons()
	currentWorld = getCurrentWorld()
	local unlockedW2 = player:GetAttribute("World2Unlocked") == true or meetsWorld2Requirements()

	if currentWorld == 1 then
		applyButtonTheme(world1Button, true, "Actual World")
		local w2Text = world2ConfirmArmed and "TELEPORT" or (unlockedW2 and "TELEPORT" or "Unlock world 2")
		applyButtonTheme(world2Button, false, w2Text)
	else
		applyButtonTheme(world2Button, true, "Actual World")
		applyButtonTheme(world1Button, false, "TELEPORT")
	end
end

local function closePanel()
	if not isOpen and not worldsGui.Enabled then
		return
	end
	isOpen = false
	resetWorld2Confirm()
	setStatus("")
	openSerial += 1
	local currentSerial = openSerial
	if activeTween then
		activeTween:Cancel()
	end
	if dimTween then
		dimTween:Cancel()
	end
	local dim = worldsGui:FindFirstChild("Dim")
	if dim and dim:IsA("GuiObject") then
		dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		dimTween:Play()
	end
	activeTween = TweenService:Create(
		worldsFrame,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = CLOSED_POSITION }
	)
	activeTween:Play()
	task.delay(0.18, function()
		if openSerial == currentSerial and not isOpen then
			worldsGui.Enabled = false
			worldsFrame.Position = CLOSED_POSITION
			if dim and dim:IsA("GuiObject") then
				dim.Visible = false
			end
		end
	end)
end

local function openPanel()
	if isOpen then
		return
	end
	MenuEvents.CloseAll:Fire("Worlds")
	openSerial += 1
	isOpen = true
	worldsGui.Enabled = true
	currentWorld = getCurrentWorld()
	updateWorldButtons()
	resetWorld2Confirm()
	setStatus("")
	WorldPortalAction:FireServer("RequestState")

	if activeTween then
		activeTween:Cancel()
	end
	if dimTween then
		dimTween:Cancel()
	end

	worldsFrame.Position = CLOSED_POSITION
	activeTween = TweenService:Create(
		worldsFrame,
		TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = OPEN_POSITION }
	)
	activeTween:Play()
end

closeButton.Activated:Connect(function()
	playClick()
	closePanel()
end)

world1Button.Activated:Connect(function()
	currentWorld = getCurrentWorld()
	if currentWorld == 1 then
		return
	end
	playClick()
	resetWorld2Confirm()
	if RunService:IsStudio() then
		setStatus("Studio: Teleport to World 1 ready (Place ID: " .. tostring(WORLD_1_PLACE_ID) .. "). Test in Roblox app!")
		print("[WorldsController] Studio: Teleport to World 1 ready (Place ID: " .. tostring(WORLD_1_PLACE_ID) .. ")")
	else
		setStatus("Teleporting to World 1...")
	end
	WorldPortalAction:FireServer("Travel", 1)
end)

world2Button.Activated:Connect(function()
	currentWorld = getCurrentWorld()
	if currentWorld == 2 then
		return
	end
	playClick()

	-- Players who already unlocked World 2 travel directly (no confirmation).
	if player:GetAttribute("World2Unlocked") == true then
		if RunService:IsStudio() then
			setStatus("Studio: Teleport to World 2 ready (Place ID: " .. tostring(WORLD_2_PLACE_ID) .. "). Test in Roblox app!")
			print("[WorldsController] Studio: Teleport to World 2 ready (Place ID: " .. tostring(WORLD_2_PLACE_ID) .. ")")
		else
			setStatus("Teleporting to World 2...")
		end
		WorldPortalAction:FireServer("Travel", 2)
		return
	end

	-- First visit: enforce the 7 Rebirths + Level 100 rule client-side for
	-- immediate feedback (the server still re-checks authoritatively on Travel).
	if not meetsWorld2Requirements() then
		local missing = {}
		if getRebirths() < WORLD_2_REQUIRED_REBIRTHS then
			table.insert(missing, tostring(WORLD_2_REQUIRED_REBIRTHS - getRebirths()) .. " more Rebirths")
		end
		if getLevel() < WORLD_2_REQUIRED_LEVEL then
			table.insert(missing, tostring(WORLD_2_REQUIRED_LEVEL - getLevel()) .. " more Levels")
		end
		setStatus("Need " .. table.concat(missing, " + "))
		return
	end

	-- First eligible click arms a "TELEPORT" confirmation; the second click travels.
	if not world2ConfirmArmed then
		world2ConfirmArmed = true
		local w2Label = world2Button:FindFirstChild("Name")
		if w2Label and w2Label:IsA("TextLabel") then
			w2Label.Text = "TELEPORT"
		end
		return
	end

	resetWorld2Confirm()
	if RunService:IsStudio() then
		setStatus("Studio: Teleport to World 2 ready (Place ID: " .. tostring(WORLD_2_PLACE_ID) .. "). Test in Roblox app!")
		print("[WorldsController] Studio: Teleport to World 2 ready (Place ID: " .. tostring(WORLD_2_PLACE_ID) .. ")")
	else
		setStatus("Teleporting to World 2...")
	end
	WorldPortalAction:FireServer("Travel", 2)
end)

player:GetAttributeChangedSignal("World2Unlocked"):Connect(function()
	if isOpen then
		updateWorldButtons()
	end
end)

local openWorldsEvent = MenuEvents.Get("OpenWorldsPanel")
openWorldsEvent.Event:Connect(function(action)
	if action == "Open" or action == "LeftButtonSwitch" then
		openPanel()
	elseif action == "Close" then
		closePanel()
	else
		if isOpen then
			closePanel()
		else
			openPanel()
		end
	end
end)

-- The server (WorldPortalService) drives this panel: OpenMenu opens it, and
-- Locked/Error/Busy/Teleporting statuses surface their messages in the panel.
-- (Remote is already resolved above; this listener consumes the shared one.)
WorldsPortalRemote.OnClientEvent:Connect(function(state)
	if not state then
		return
	end
	if state.CurrentWorld == 1 or state.CurrentWorld == 2 then
		currentWorld = state.CurrentWorld
		updateWorldButtons()
	end
	if state.OpenMenu == true then
		openPanel()
	end
	local status = tostring(state.Status or "")
	local message = tostring(state.Message or "")
	if status == "Locked" or status == "Error" or status == "Busy" or status == "StudioPreview" or status == "Teleporting" then
		setStatus(message)
	elseif status == "Current" or status == "Touched" or status == "State" then
		setStatus("")
	end
end)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Worlds" then
		closePanel()
	end
end)
MenuEvents.MarkReady("Worlds", function()
	return isOpen
end)
closePanel()

local portalParts = {}
local function scanForPortals()
	table.clear(portalParts)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local name = string.lower(obj.Name)
			if string.find(name, "portal") or string.find(name, "worldportal") then
				table.insert(portalParts, obj)
			end
		end
	end
end

local function onPortalTouched(hit)
	if not hit or not hit:IsA("BasePart") then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Touched fires with `hit` = the body part that hit the portal, which IS a
	-- descendant of the player's character. The previous check was inverted and
	-- returned early on every legit touch, so the panel never opened.
	if not hit:IsDescendantOf(character) then
		return
	end
	local now = os.clock()
	if now - lastPortalTouch < PORTAL_TOUCH_COOLDOWN then
		return
	end
	lastPortalTouch = now
	openPanel()
end

local portalConnections = {}
local function connectPortals()
	for _, conn in ipairs(portalConnections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(portalConnections)

	for _, part in ipairs(portalParts) do
		local conn = part.Touched:Connect(onPortalTouched)
		table.insert(portalConnections, conn)
	end
end

scanForPortals()
connectPortals()

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		local name = string.lower(obj.Name)
		if string.find(name, "portal") or string.find(name, "worldportal") then
			table.insert(portalParts, obj)
			local conn = obj.Touched:Connect(onPortalTouched)
			table.insert(portalConnections, conn)
		end
	end
end)

print("[WorldsController] Loaded. World 2 PlaceId: " .. tostring(WORLD_2_PLACE_ID))