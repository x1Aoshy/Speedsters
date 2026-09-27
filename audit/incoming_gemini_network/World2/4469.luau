--[[
	IndexScript - drives the designer-made Index panel (StarterGui.Index).
	Displays Evolution Skins from SuitCatalog so players can view requirements
	and equip unlocked skins. Communicates directly with SkinSystem server
	via SkinIndexRequest and SkinIndexUpdate.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local screenGui = script.Parent

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local SuitCatalog = require(Shared:WaitForChild("SuitCatalog"))
local Config = require(Shared:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SkinIndexRequest = Remotes:WaitForChild("SkinIndexRequest")
local SkinIndexUpdate = Remotes:WaitForChild("SkinIndexUpdate")

local mainFrame = screenGui:WaitForChild("Index")
local scrollFrame = mainFrame:WaitForChild("ScrollingFrame")
local equippedTemplate = scrollFrame:WaitForChild("Template")
local unequippedTemplate = scrollFrame:WaitForChild("UnequippedTemplate")
local gridLayout = scrollFrame:WaitForChild("UIGridLayout")
local closeButton = mainFrame:WaitForChild("Close")
local dim = screenGui:FindFirstChild("Dim")

scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y

-- Pre-hide templates (they serve only as clone prototypes)
equippedTemplate.Visible = false
unequippedTemplate.Visible = false

local isOpen = false
local isAnimating = false
local currentSkins = {}
local ownedSkins = {}
local equippedSkinId = ""

-- Build static skin list from SuitCatalog.Ordered as initial fallback
for _, entry in ipairs(SuitCatalog.Ordered) do
	table.insert(currentSkins, {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		RequiredLevel = entry.RequiredLevel or 0,
		RequiredRebirths = entry.RequiredRebirths or 0,
		Stamina = entry.Stamina or 0,
	})
end

local function updateCanvasSize()
	local contentHeight = gridLayout.AbsoluteContentSize.Y
	if contentHeight > 0 then
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 28)
	else
		local totalItems = math.max(1, #currentSkins)
		local rows = math.ceil(totalItems / 2)
		local estimatedRowHeight = 160
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (estimatedRowHeight + 10) + 28)
	end
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvasSize)

local function getSkinThumbnail(assetId)
	if not assetId or assetId == 0 then
		return "rbxassetid://97111421088356"
	end
	return "rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=420&h=420"
end

local function rebuildGrid()
	-- Clean existing card clones
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= equippedTemplate and child ~= unequippedTemplate and not child:IsA("UIGridLayout") and not child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end

	for index, skin in ipairs(currentSkins) do
		local isEquipped = (skin.Id == equippedSkinId)
		local isOwned = (ownedSkins[skin.Id] == true)
		if skin.Id == "FlashSuit" then
			isOwned = true
		end

		local card
		if isEquipped then
			card = equippedTemplate:Clone()
		else
			card = unequippedTemplate:Clone()
		end

		card.Name = "Skin_" .. tostring(skin.Id)
		card.LayoutOrder = index
		card.Visible = true
		card.Parent = scrollFrame

		-- Set Name Label
		local innerFrame = card:FindFirstChild("Frame")
		if innerFrame then
			local nameLbl = innerFrame:FindFirstChild("Name")
			if nameLbl and nameLbl:IsA("TextLabel") then
				nameLbl.Text = tostring(skin.DisplayName or skin.Id)
			end

			-- Set Preview Icon
			local icon = innerFrame:FindFirstChild("Icon")
			if icon and icon:IsA("ImageLabel") then
				icon.Image = getSkinThumbnail(skin.PreviewAssetId)
			end
		end

		-- Setup Action Button
		local actionBtn = card:FindFirstChild("EquippedTemplate") or card:FindFirstChild("Equip")
		if actionBtn and (actionBtn:IsA("ImageButton") or actionBtn:IsA("TextButton")) then
			local btnLabel = actionBtn:FindFirstChild("Name")
			if isEquipped then
				if btnLabel and btnLabel:IsA("TextLabel") then
					btnLabel.Text = "EQUIPPED"
				end
				actionBtn.ImageColor3 = Color3.fromRGB(0, 230, 118)
				actionBtn.AutoButtonColor = false
			elseif isOwned then
				if btnLabel and btnLabel:IsA("TextLabel") then
					btnLabel.Text = "EQUIP"
				end
				actionBtn.ImageColor3 = Color3.fromRGB(0, 170, 255)
				actionBtn.AutoButtonColor = true

				actionBtn.Activated:Connect(function()
					SkinIndexRequest:FireServer("Equip", skin.Id)
					equippedSkinId = skin.Id
					rebuildGrid()
				end)
			else
				-- Locked skin: show requirements
				local reqText = "LOCKED"
				local reqLvl = tonumber(skin.RequiredLevel) or 0
				local reqR = tonumber(skin.RequiredRebirths) or 0
				if reqLvl > 0 and reqR > 0 then
					reqText = string.format("LVL %d / %dR", reqLvl, reqR)
				elseif reqLvl > 0 then
					reqText = string.format("LVL %d", reqLvl)
				elseif reqR > 0 then
					reqText = string.format("%d REBIRTHS", reqR)
				end

				if btnLabel and btnLabel:IsA("TextLabel") then
					btnLabel.Text = reqText
				end
				actionBtn.ImageColor3 = Color3.fromRGB(80, 80, 80)
				actionBtn.AutoButtonColor = false

				actionBtn.Activated:Connect(function()
					-- Direct player to Evolve panel to unlock this skin
					MenuEvents.Request("Evolve")
				end)
			end
		end
	end

	task.defer(updateCanvasSize)
end

-- Listen to server updates
SkinIndexUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end

	if type(payload.Skins) == "table" and #payload.Skins > 0 then
		currentSkins = payload.Skins
	end

	if type(payload.Owned) == "table" then
		ownedSkins = payload.Owned
	end

	if payload.EquippedSkin ~= nil then
		equippedSkinId = tostring(payload.EquippedSkin)
	end

	if isOpen then
		rebuildGrid()
	end
end)

-- Open / Close handling (capture designer position from Studio GUI)
local OPEN_POS = mainFrame.Position
local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.28, 0)
local openTween = nil
local dimTween = nil

local function hidePanel(instant)
	if not isOpen and not screenGui.Enabled then return end
	if isAnimating and not instant then return end

	if instant then
		isOpen = false
		isAnimating = false
		if openTween then openTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		screenGui.Enabled = false
		mainFrame.Visible = false
		mainFrame.Position = CLOSED_POS
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
			dim.BackgroundTransparency = 1
		end
		return
	end

	isAnimating = true
	if dim and dim:IsA("GuiObject") then
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = CLOSED_POS,
	})
	openTween:Play()
	openTween.Completed:Connect(function()
		mainFrame.Visible = false
		screenGui.Enabled = false
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
		end
		isOpen = false
		isAnimating = false
	end)
end

local function showPanel()
	if isOpen or isAnimating then return end
	isAnimating = true
	isOpen = true

	SkinIndexRequest:FireServer("RequestState")

	screenGui.Enabled = true
	mainFrame.Visible = true
	mainFrame.Position = CLOSED_POS

	rebuildGrid()

	if dim and dim:IsA("GuiObject") then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.48,
		})
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = OPEN_POS,
	})
	openTween:Play()
	openTween.Completed:Connect(function()
		isAnimating = false
	end)
end

if closeButton then
	closeButton.Activated:Connect(function()
		hidePanel(false)
	end)
end

if dim and dim:IsA("GuiObject") then
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			hidePanel(false)
		end
	end)
end

local openEvent = MenuEvents.Get("OpenIndexPanel")
openEvent.Event:Connect(function(action, ...)
	if action == "Close" then
		hidePanel(false)
	elseif action == "Open" then
		showPanel()
	else
		if isOpen then
			hidePanel(false)
		else
			showPanel()
		end
	end
end)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Index" then
		hidePanel(true)
	end
end)

MenuEvents.MarkReady("Index", function()
	return isOpen
end)

hidePanel(true)
