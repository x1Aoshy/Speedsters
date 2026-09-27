local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"
local requirementFailSound = SoundService:FindFirstChild("SpeedsterRequirementFailSound")
if not requirementFailSound or not requirementFailSound:IsA("Sound") then
    if requirementFailSound then
        requirementFailSound:Destroy()
    end
    requirementFailSound = Instance.new("Sound")
    requirementFailSound.Name = "SpeedsterRequirementFailSound"
    requirementFailSound.Parent = SoundService
end
requirementFailSound.SoundId = REQUIREMENT_FAIL_SOUND_ID
requirementFailSound.Volume = 0.9
requirementFailSound.PlaybackSpeed = 1

local function playRequirementFailSound()
    requirementFailSound.TimePosition = 0
    SoundService:PlayLocalSound(requirementFailSound)
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipSkin = Remotes:WaitForChild("EquipSkin")
local EvolveSkinUpdate = Remotes:WaitForChild("EvolveSkinUpdate")

local openEvolvePanel = MenuEvents.Get("OpenEvolvePanel")
local openRebirthPanel = MenuEvents.Get("OpenRebirthPanel")
local openDailyPanel = MenuEvents.Get("OpenDailyPanel")
local openTrailsPanel = MenuEvents.Get("OpenTrailsPanel")
local openIndexPanel = MenuEvents.Get("OpenIndexPanel")
local openAurasPanel = MenuEvents.Get("OpenAurasPanel")
local openTeleportPanel = MenuEvents.Get("OpenTeleportPanel")
local openAbilitiesPanel = MenuEvents.Get("OpenAbilitiesPanel")

local FLASH_LEVEL_REQUIRED = 0

local EVOLVE_CHAIN = {}
for _, entry in ipairs(SuitCatalog.Ordered) do
	table.insert(EVOLVE_CHAIN, {
		SkinId = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		RequiredLevel = entry.RequiredLevel,
		RequiredRebirths = entry.RequiredRebirths or 0,
		Stamina = entry.Stamina,
	})
end

local currentNextSkinId = "ReverseSpeedsterSuit"
local maxEvolved = false
local currentOwnedSkins = {}

local PANEL_SIZE = Vector2.new(860, 545)
local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.26)
local EVOLVE_SOUND_ID = "rbxassetid://80736831159506"
local EVOLVE_HEADER_COLOR = Color3.fromRGB(95, 255, 24)

local currentLevel = 1
local currentRebirths = 0
local unlocked = false
local isFlashEquipped = false
local isOpen = false
local activeTween = nil
local dimTween = nil

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function makeText(parent, name, text, pos, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 12
	label.Parent = parent
	addStroke(label, math.max(2, math.floor(textSize / 12)))
	return label
end

local function makeButton(parent, name, text, pos, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = pos
	button.Size = size
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 34
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.TextYAlignment = Enum.TextYAlignment.Center
	button.ZIndex = 13
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, 4, Color3.fromRGB(0, 0, 0))
	StudUi.StyleButton(button, 10)
	return button
end

local function thumbnailForUserId(userId)
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
	end)

	return ok and content or ""
end


local function getSuitSpeedMultiplier(skinId)
	skinId = tostring(skinId or "")

	local defaultMultiplier = tonumber(Config.DefaultSuitSpeedGainMultiplier) or 1
	local multipliers = Config.SuitSpeedGainMultipliers

	if type(multipliers) == "table" and multipliers[skinId] ~= nil then
		return tonumber(multipliers[skinId]) or defaultMultiplier
	end

	return defaultMultiplier
end

local function formatMultiplier(value)
	value = tonumber(value) or 1

	if value >= 1000000 then
		return string.format("%.2e", value)
	elseif value >= 100 then
		return string.format("%.0f", value)
	elseif value >= 10 then
		return string.format("%.1f", value):gsub("0+$", ""):gsub("%.$", "")
	end

	return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function getSkinInfo(skinId)
	skinId = tostring(skinId or "")

	for _, info in ipairs(EVOLVE_CHAIN) do
		if info.SkinId == skinId then
			return info
		end
	end

	return nil
end

local function getSuitDisplayName(skinId)
	skinId = tostring(skinId or "")

	if skinId == "" then
		return "Current"
	end

	local info = getSkinInfo(skinId)
	if info then
		return info.DisplayName
	end

	return skinId:gsub("(%l)(%u)", "%1 %2")
end

local function getNextSkinInfo(ownedSkins)
	ownedSkins = type(ownedSkins) == "table" and ownedSkins or {}
	for _, info in ipairs(EVOLVE_CHAIN) do
		if ownedSkins[info.SkinId] ~= true then
			return info
		end
	end
	return nil
end

local function getHighestOwnedSkinInfo(ownedSkins)
	ownedSkins = type(ownedSkins) == "table" and ownedSkins or {}
	for index = #EVOLVE_CHAIN, 1, -1 do
		local info = EVOLVE_CHAIN[index]
		if ownedSkins[info.SkinId] == true then
			return info
		end
	end
	return nil
end

local function getSkinPreviewImage(skinId, fallbackImage)
	skinId = tostring(skinId or "")

	if skinId == "" then
		return fallbackImage
	end

	local info = getSkinInfo(skinId)
	if info and info.PreviewAssetId then
		return "rbxthumb://type=Asset&id=" .. tostring(info.PreviewAssetId) .. "&w=420&h=420"
	end

	return fallbackImage
end

local oldGui = playerGui:FindFirstChild("EvolvePanelGui")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "EvolvePanelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 80
gui.Enabled = false
gui.Parent = playerGui

local evolveSound = Instance.new("Sound")
evolveSound.Name = "SuitEvolveSound"
evolveSound.SoundId = EVOLVE_SOUND_ID
evolveSound.Volume = 0.9
evolveSound.Parent = gui

local pendingEvolveSoundSkinId = nil

local function playEvolveSound()
	evolveSound.TimePosition = 0
	evolveSound:Play()
end

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 9
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.Rotation = 0
panel.ZIndex = 10
panel.Parent = gui

                         
                                                                                             
local responsivePanelScale = Instance.new("UIScale")
responsivePanelScale.Name = "MobileResponsiveScale"
responsivePanelScale.Scale = 1
responsivePanelScale.Parent = panel

local function updateResponsivePanelScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local horizontalMargin = UserInputService.TouchEnabled and 18 or 40
	local verticalMargin = UserInputService.TouchEnabled and 14 or 34
	local availableWidth = math.max(1, viewport.X - horizontalMargin)
	local availableHeight = math.max(1, viewport.Y - inset.Y - verticalMargin)
	local fit = math.min(availableWidth / PANEL_SIZE.X, availableHeight / PANEL_SIZE.Y)
	local maximum = UserInputService.TouchEnabled and 0.98 or 1.08

	responsivePanelScale.Scale = math.clamp(fit, 0.42, maximum)
end

updateResponsivePanelScale()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsivePanelScale)
end
panel.ClipsDescendants = true
addCorner(panel, 14)
addStroke(panel, 5, Color3.fromRGB(0, 0, 0))
StudUi.AddSurface(panel, 10, 14)

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = EVOLVE_HEADER_COLOR
header.BackgroundTransparency = 0
header.BorderSizePixel = 0
header.Position = UDim2.fromOffset(0, 0)
header.Size = UDim2.new(1, 0, 0, 84)
header.ZIndex = 10
header.Parent = panel
header.ClipsDescendants = true

                                                                       
local evolveIcon = Instance.new("ImageLabel")
evolveIcon.Name = "TopLeftEvolveIcon"
evolveIcon.BackgroundTransparency = 1
evolveIcon.BorderSizePixel = 0
evolveIcon.Image = "rbxassetid://136041183142482"
evolveIcon.AnchorPoint = Vector2.new(0, 0.5)
evolveIcon.Position = UDim2.new(0, 8, 0.5, 0)
evolveIcon.Size = UDim2.fromOffset(74, 74)
evolveIcon.ScaleType = Enum.ScaleType.Fit
evolveIcon.ZIndex = 35
evolveIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.BorderSizePixel = 0
title.Text = "Evolve"
title.Font = Enum.Font.FredokaOne
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0
title.TextScaled = false
title.TextSize = 48
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Position = UDim2.new(0, 102, 0, 0)
title.Size = UDim2.new(1, -210, 1, 0)
title.ZIndex = 35
title.Parent = header

addCorner(header, 14)
addStroke(header, 5, Color3.fromRGB(0, 0, 0))
StudUi.AddSurface(header, 11, 14)

local closeX = makeButton(header, "TopRightXCloseButton", "X", UDim2.new(1, -38, 0.5, 0), UDim2.fromOffset(58, 58), Color3.fromRGB(255, 75, 75))
closeX.TextSize = 36

local beforeTitle = makeText(panel, "BeforeTitle", "Before", UDim2.new(0.18, 0, 0, 86), UDim2.fromOffset(220, 44), 34)
local afterTitle = makeText(panel, "AfterTitle", "After", UDim2.new(0.56, 0, 0, 86), UDim2.fromOffset(220, 44), 34)
beforeTitle.TextColor3 = EVOLVE_HEADER_COLOR
afterTitle.TextColor3 = EVOLVE_HEADER_COLOR

local function makePreview(name, centerXScale, labelText)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(centerXScale, 0, 0, 138)
	holder.Size = UDim2.fromOffset(160, 160)
	holder.BackgroundColor3 = Color3.fromRGB(38, 41, 48)
	holder.BackgroundTransparency = 0
	holder.BorderSizePixel = 0
	holder.ZIndex = 11
	holder.Parent = panel
	addCorner(holder, 8)
	addStroke(holder, 3, Color3.fromRGB(0, 0, 0))

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "PreviewImage"
	avatar.BackgroundTransparency = 1
	avatar.Position = UDim2.fromOffset(8, 8)
	avatar.Size = UDim2.new(1, -16, 1, -16)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.ZIndex = 12
	avatar.Parent = holder

	local label = makeText(panel, name .. "Label", labelText, UDim2.new(centerXScale, -120, 0, 302), UDim2.fromOffset(240, 38), 30)
	local speedLabel = makeText(panel, name .. "SpeedPerSecondLabel", "1 Speed/s", UDim2.new(centerXScale, -120, 0, 338), UDim2.fromOffset(240, 30), 22, Color3.fromRGB(255, 220, 42))

	return holder, avatar, label, speedLabel
end

local beforeBox, beforeAvatar, beforeName, beforeSpeedPerSecond = makePreview("BeforeBox", 0.30, "Current")
local afterBox, afterAvatar, afterName, afterSpeedPerSecond = makePreview("AfterBox", 0.70, "Flash Suit")
beforeName.TextColor3 = EVOLVE_HEADER_COLOR
afterName.TextColor3 = EVOLVE_HEADER_COLOR
if Config.IsWorld2Place ~= true then
	beforeSpeedPerSecond.Text = formatMultiplier(getSuitSpeedMultiplier("FlashSuit")) .. " Speed/s"
	afterSpeedPerSecond.Text = formatMultiplier(getSuitSpeedMultiplier("ReverseSpeedsterSuit")) .. " Speed/s"
end

makeText(panel, "Arrow", "➡", UDim2.new(0.5, -45, 0, 185), UDim2.fromOffset(90, 70), 54, EVOLVE_HEADER_COLOR)

local levelBack = Instance.new("Frame")
levelBack.Name = "LevelRequirementBar"
levelBack.AnchorPoint = Vector2.new(0.5, 0)
levelBack.Position = UDim2.new(0.5, 0, 0, 382)
levelBack.Size = UDim2.fromOffset(520, 44)
levelBack.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
levelBack.BorderSizePixel = 0
levelBack.ZIndex = 11
levelBack.Parent = panel
addCorner(levelBack, 8)
addStroke(levelBack, 3, Color3.fromRGB(0, 0, 0))

local levelFill = Instance.new("Frame")
levelFill.Name = "LevelFill"
levelFill.Size = UDim2.fromScale(0, 1)
levelFill.BackgroundColor3 = Color3.fromRGB(255, 184, 28)
levelFill.BorderSizePixel = 0
levelFill.ZIndex = 12
levelFill.Parent = levelBack
addCorner(levelFill, 8)

local levelText = makeText(levelBack, "LevelText", "Level 0/1", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28, Color3.fromRGB(255, 255, 255))
StudUi.AddSurface(levelFill, 13, 8)
levelText.ZIndex = 15

local statusText = makeText(panel, "StatusText", "", UDim2.new(0.5, -300, 0, 436), UDim2.fromOffset(600, 48), 32, Color3.fromRGB(255, 220, 42))
statusText.Visible = false                                

local evolveButton = makeButton(panel, "EvolveButton", "Evolve", UDim2.new(0.5, 0, 0, 502), UDim2.fromOffset(280, 58), Color3.fromRGB(255, 205, 20))

beforeAvatar.Image = thumbnailForUserId(player.UserId)
afterAvatar.Image = getSkinPreviewImage("FlashSuit", beforeAvatar.Image)

local function updateFromData(data)
	data = type(data) == "table" and data or {}

	currentLevel = tonumber(data.Level) or player:GetAttribute("Level") or 1
	currentRebirths = tonumber(data.Rebirths) or tonumber(player:GetAttribute("Rebirths")) or 0

	local currentSkinId = tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or "")
	if type(data.OwnedSkins) == "table" then
		currentOwnedSkins = data.OwnedSkins
	end
	if SuitCatalog.IsValid(currentSkinId) then
		currentOwnedSkins[currentSkinId] = true
	end
	currentOwnedSkins[SuitCatalog.DefaultSkinId or "FlashSuit"] = true

	local nextInfo = getNextSkinInfo(currentOwnedSkins)
	local highestOwnedInfo = getHighestOwnedSkinInfo(currentOwnedSkins)
	local beforeSkinId = highestOwnedInfo and highestOwnedInfo.SkinId or currentSkinId
	local requiredLevel = nextInfo and (tonumber(nextInfo.RequiredLevel) or FLASH_LEVEL_REQUIRED) or 0
	local requiredRebirths = nextInfo and (tonumber(nextInfo.RequiredRebirths) or 0) or 0
	local nextSkinId = nextInfo and nextInfo.SkinId or ""

	currentNextSkinId = nextSkinId
	maxEvolved = nextInfo == nil
	unlocked = nextInfo ~= nil
		and currentLevel >= requiredLevel
		and currentRebirths >= requiredRebirths
	isFlashEquipped = currentSkinId == "FlashSuit"

	beforeName.Text = getSuitDisplayName(beforeSkinId)
	afterName.Text = nextInfo and getSuitDisplayName(nextSkinId) or "Max Evolved"

	beforeSpeedPerSecond.Text = formatMultiplier(getSuitSpeedMultiplier(beforeSkinId)) .. " Speed/s"
	afterSpeedPerSecond.Text = nextInfo and (formatMultiplier(getSuitSpeedMultiplier(nextSkinId)) .. " Speed/s") or "MAX"

	beforeAvatar.Image = getSkinPreviewImage(beforeSkinId, thumbnailForUserId(player.UserId))
	afterAvatar.Image = nextInfo and getSkinPreviewImage(nextSkinId, beforeAvatar.Image) or beforeAvatar.Image

	local ratio = maxEvolved and 1 or math.clamp(currentLevel / math.max(1, requiredLevel), 0, 1)
	levelFill.Size = UDim2.fromScale(ratio, 1)

	if maxEvolved then
		levelText.Text = "Max Evolved"
		levelText.TextSize = 28
	elseif requiredRebirths > 0 then
		levelText.Text = "Level "
			.. tostring(math.floor(currentLevel))
			.. "/"
			.. tostring(requiredLevel)
			.. "  |  Rebirths "
			.. tostring(math.floor(currentRebirths))
			.. "/"
			.. tostring(requiredRebirths)
		levelText.TextSize = 23
	else
		levelText.Text = "Level " .. tostring(math.floor(currentLevel)) .. "/" .. tostring(requiredLevel)
		levelText.TextSize = 28
	end

	evolveButton.Text = maxEvolved and "Max" or "Evolve"
	statusText.Visible = false

	if maxEvolved then
		statusText.Text = ""
		evolveButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
		evolveButton.AutoButtonColor = false
	elseif not unlocked then
		statusText.Text = ""
		evolveButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
		evolveButton.AutoButtonColor = false
	else
		statusText.Text = ""
		evolveButton.BackgroundColor3 = Color3.fromRGB(255, 205, 20)
		evolveButton.AutoButtonColor = true
	end
end

local function cancelTweens()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	if dimTween then
		dimTween:Cancel()
		dimTween = nil
	end
end

local function openPanel()
	cancelTweens()

	beforeAvatar.Image = thumbnailForUserId(player.UserId)
	updateFromData({
		Level = player:GetAttribute("Level") or 1,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		EquippedSkin = player:GetAttribute("EquippedSkin") or "",
	})

	gui.Enabled = true
	isOpen = true

	panel.Position = CLOSED_POSITION
	panel.Rotation = 0
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	dim.BackgroundTransparency = 1

	                                                                   
	activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = OPEN_POSITION,
		Rotation = 0,
	})

	dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.45,
	})

	activeTween:Play()
	dimTween:Play()
end

local function closePanel()
	if not gui.Enabled then
		return
	end

	cancelTweens()
	isOpen = false

	panel.Position = OPEN_POSITION
	panel.Rotation = 0

	activeTween = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = CLOSED_POSITION,
		Rotation = 0,
	})

	dimTween = TweenService:Create(dim, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})

	activeTween:Play()
	dimTween:Play()

	activeTween.Completed:Connect(function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function togglePanel()
	if gui.Enabled and isOpen then
		closePanel()
	else
		openPanel()
	end
end

closeX.Activated:Connect(closePanel)

evolveButton.Activated:Connect(function()
	updateFromData({
		Level = player:GetAttribute("Level") or 1,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		EquippedSkin = player:GetAttribute("EquippedSkin") or "",
	})

	if not unlocked or maxEvolved or currentNextSkinId == "" then
		if not maxEvolved and currentNextSkinId ~= "" and not unlocked then
			playRequirementFailSound()
		end
		return
	end

	                                              
	pendingEvolveSoundSkinId = currentNextSkinId
	EquipSkin:FireServer(currentNextSkinId)
	statusText.Text = ""
end)

openEvolvePanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Evolve", function()
	return isOpen
end)

                                                                 
openRebirthPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

                                                               
openDailyPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openTrailsPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openIndexPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAurasPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openTeleportPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAbilitiesPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

EvolveSkinUpdate.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		local equippedSkin = tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or "")

		if pendingEvolveSoundSkinId and equippedSkin == pendingEvolveSoundSkinId then
			playEvolveSound()
			pendingEvolveSoundSkinId = nil
		end

		updateFromData(data)
	end
end)

player:GetAttributeChangedSignal("Level"):Connect(function()
	updateFromData({
		Level = player:GetAttribute("Level") or 1,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		EquippedSkin = player:GetAttribute("EquippedSkin") or "",
	})
end)

player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	updateFromData({
		Level = player:GetAttribute("Level") or 1,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		EquippedSkin = player:GetAttribute("EquippedSkin") or "",
	})
end)

player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
	local equippedSkin = tostring(player:GetAttribute("EquippedSkin") or "")

	if pendingEvolveSoundSkinId and equippedSkin == pendingEvolveSoundSkinId then
		playEvolveSound()
		pendingEvolveSoundSkinId = nil
	end

	updateFromData({
		Level = player:GetAttribute("Level") or 1,
		Rebirths = player:GetAttribute("Rebirths") or 0,
		EquippedSkin = equippedSkin,
	})
end)


                                     
                                                                               
local function ensureEvolveGuiAlive()
	if gui and gui.Parent ~= playerGui then
		gui.Parent = playerGui
	end
end

player.CharacterAdded:Connect(function()
	isOpen = false
	task.defer(ensureEvolveGuiAlive)
	task.delay(0.5, ensureEvolveGuiAlive)
end)

if Config.IsWorld2Place then
	print("[EvolvePanel] V306GT loaded. Existing Levels plus per-suit Rebirth requirements are enforced and displayed.")
else
	print("[EvolvePanel] V306KBB loaded. World 1 keeps Wally West's requirement, then displays an exact +2-Rebirth chain for every later character.")
end
