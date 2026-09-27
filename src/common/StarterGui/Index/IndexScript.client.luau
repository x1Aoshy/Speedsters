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
local SkinPreview = require(Shared:WaitForChild("SkinPreview"))

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

screenGui.IgnoreGuiInset = false
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
screenGui.ClipToDeviceSafeArea = true

scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y

-- Pre-hide templates (they serve only as clone prototypes)
equippedTemplate.Visible = false
unequippedTemplate.Visible = false

local isOpen = false
local currentSkins = {}
local ownedSkins = {}
local equippedSkinId = ""

-- Build static skin list from SuitCatalog.Ordered as initial fallback
for _, entry in ipairs(SuitCatalog.Ordered) do
	table.insert(currentSkins, {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		PreviewRig = entry.PreviewRig,
		RequiredLevel = entry.RequiredLevel or 0,
		RequiredRebirths = entry.RequiredRebirths or 0,
		Stamina = entry.Stamina or 0,
	})
end

-- Preserve the authored panel on desktop, cap its width on ultrawide displays,
-- and use the safe landscape area on small screens so the cards remain readable.
local COMPACT_PANEL_SIZE = UDim2.fromScale(0.94, 0.84)
local COMPACT_COLUMNS = 3
local COMPACT_GAP = 8
local authoredPanelSize = mainFrame.Size
local authoredCellSize = gridLayout.CellSize
local authoredCellPadding = gridLayout.CellPadding
local panelAspect = mainFrame:FindFirstChildOfClass("UIAspectRatioConstraint")
local authoredAspect = panelAspect and panelAspect.AspectRatio
local panelScale = Instance.new("UIScale")
panelScale.Name = "ResponsivePanelScale"
panelScale.Parent = mainFrame
local cardShape = equippedTemplate:FindFirstChildOfClass("UIAspectRatioConstraint")
local CARD_ASPECT = if cardShape and cardShape.AspectRatio > 0 then cardShape.AspectRatio else 1.155

local function isCompact()
	local safe = screenGui.AbsoluteSize
	return safe.X < 700 or safe.Y < 500
end

local function fitGrid()
	if not isCompact() then
		gridLayout.CellSize = authoredCellSize
		gridLayout.CellPadding = authoredCellPadding
		return
	end
	local width = scrollFrame.AbsoluteSize.X / math.max(panelScale.Scale, 0.01) - scrollFrame.ScrollBarThickness - 4
	if width <= 0 then
		return
	end
	local cellWidth = math.floor((width - (COMPACT_COLUMNS + 1) * COMPACT_GAP) / COMPACT_COLUMNS)
	gridLayout.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth / CARD_ASPECT))
	gridLayout.CellPadding = UDim2.fromOffset(COMPACT_GAP, COMPACT_GAP)
end

local function fitPanel()
	local safe = screenGui.AbsoluteSize
	if safe.X <= 0 or safe.Y <= 0 then return end
	local compact = isCompact()
	mainFrame.Size = if compact then COMPACT_PANEL_SIZE else authoredPanelSize
	local width = mainFrame.Size.X.Scale * safe.X + mainFrame.Size.X.Offset
	local height = mainFrame.Size.Y.Scale * safe.Y + mainFrame.Size.Y.Offset
	if panelAspect then
		panelAspect.AspectRatio = if compact then width / math.max(height, 1) else authoredAspect
		height = width / panelAspect.AspectRatio
	end
	panelScale.Scale = math.min(1, 760 / math.max(width, 1),
		(safe.X - 28) / math.max(width, 1), (safe.Y - 28) / math.max(height, 1))
	fitGrid()
end

-- The layout reports its height in screen pixels, after ResponsivePanelScale, while CanvasSize
-- is read in the panel's own units, before it. Used as it came, a panel drawn at 90% got a
-- canvas 10% too short and the last row could not be scrolled into view (wide phones, 1440p
-- and ultrawide screens). So the height goes back to panel units first (as fitGrid does with
-- the width), and the list ends with room to spare.
local CANVAS_BOTTOM_PADDING = 48

local function updateCanvasSize()
	local contentHeight = gridLayout.AbsoluteContentSize.Y / math.max(panelScale.Scale, 0.01)
	if contentHeight > 0 then
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.ceil(contentHeight) + CANVAS_BOTTOM_PADDING)
	else
		local totalItems = math.max(1, #currentSkins)
		local rows = math.ceil(totalItems / 2)
		local estimatedRowHeight = 160
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, rows * (estimatedRowHeight + 10) + CANVAS_BOTTOM_PADDING)
	end
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)
-- A new scale alone (the drawn size can stay at 760 px while it changes) moves the canvas too.
panelScale:GetPropertyChangedSignal("Scale"):Connect(updateCanvasSize)
scrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	fitGrid()
	updateCanvasSize()
end)
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
fitPanel()

-- Skins won rather than evolved into: what the locked button says and where it leads.
local EXCLUSIVE_SOURCES = {
	SpinWheel = { Label = "SPIN WHEEL", Menu = "SpinWheel", Color = Color3.fromRGB(255, 186, 0) },
	-- The Silver Surfer, World 3's mythic skin: won by finishing World 3.
	World3 = { Label = "BEAT WORLD 3", Color = Color3.fromRGB(170, 205, 255) },
}

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

			-- Set Preview Icon: the thumbnail, or the rig itself (Shared.SkinPreview)
			local icon = innerFrame:FindFirstChild("Icon")
			if icon and icon:IsA("ImageLabel") then
				SkinPreview.Apply(icon, skin)
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
				-- Locked skin: show requirements (or, for an exclusive, where it is won)
				local reqText = "LOCKED"
				local reqLvl = tonumber(skin.RequiredLevel) or 0
				local reqR = tonumber(skin.RequiredRebirths) or 0
				local wonAt = EXCLUSIVE_SOURCES[skin.Exclusive or ""]
				if wonAt then
					reqText = wonAt.Label
				elseif reqLvl > 0 and reqR > 0 then
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

				if wonAt then
					-- An exclusive glows in its source's colour and opens it.
					actionBtn.ImageColor3 = wonAt.Color
				end
				actionBtn.Activated:Connect(function()
					-- Direct player to where this skin is unlocked (World 3's is won in its run)
					if not wonAt then
						MenuEvents.Request("Evolve")
					elseif wonAt.Menu then
						MenuEvents.Request(wonAt.Menu)
					end
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
--
-- A panel that is closing counts as closed: opening it again cancels the close at once and
-- slides it back up from wherever it got to. (It used to refuse to open until the 0.2 s
-- close had finished, while telling MenuEvents it was still open, so reopening it quickly,
-- say right after equipping a skin, only flashed the HUD away and back.) Every open or
-- close bumps `motion`, and a tween from an older one finishing does nothing.
local OPEN_POS = mainFrame.Position
local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.28, 0)
local openTween = nil
local dimTween = nil
local closing = false
local motion = 0

local function cancelTweens()
	if openTween then
		openTween:Cancel()
		openTween = nil
	end
	if dimTween then
		dimTween:Cancel()
		dimTween = nil
	end
end

local function finishClosed()
	isOpen = false
	closing = false
	screenGui.Enabled = false
	mainFrame.Visible = false
	mainFrame.Position = CLOSED_POS
	if dim and dim:IsA("GuiObject") then
		dim.Visible = false
		dim.Active = false
		dim.BackgroundTransparency = 1
	end
end

local function hidePanel(instant)
	if instant then
		motion += 1
		cancelTweens()
		finishClosed()
		return
	end
	if not isOpen then
		return
	end
	motion += 1
	local thisMotion = motion
	isOpen = false
	closing = true
	cancelTweens()
	if dim and dim:IsA("GuiObject") then
		dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		dimTween:Play()
	end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = CLOSED_POS,
	})
	openTween.Completed:Connect(function()
		if motion == thisMotion then
			finishClosed()
		end
	end)
	openTween:Play()
end

local function showPanel()
	if isOpen then
		return
	end
	motion += 1
	local thisMotion = motion
	local wasClosing = closing
	closing = false
	cancelTweens()
	isOpen = true

	SkinIndexRequest:FireServer("RequestState")

	screenGui.Enabled = true
	mainFrame.Visible = true
	if not wasClosing then
		mainFrame.Position = CLOSED_POS
	end

	-- A card that cannot be drawn must never leave the panel half-open.
	local built, problem = pcall(rebuildGrid)
	if not built then
		warn("[IndexScript] Could not build the skins grid: " .. tostring(problem))
	end

	if dim and dim:IsA("GuiObject") then
		dim.Visible = true
		dim.Active = true
		if not wasClosing then
			dim.BackgroundTransparency = 1
		end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.48,
		})
		dimTween:Play()
	end

	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = OPEN_POS,
	})
	openTween.Completed:Connect(function()
		if motion == thisMotion then
			openTween = nil
		end
	end)
	openTween:Play()
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

-- Open while it opens or shows; a closing panel is closed (MenuEvents then opens it again).
MenuEvents.MarkReady("Index", function()
	return isOpen
end)

hidePanel(true)
