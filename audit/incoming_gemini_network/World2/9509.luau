--!strict
-- AdminPanelController.luau
-- DESACTIVADO: El panel de administración ha sido desactivado para que no aparezca a ningún admin.
local ADMIN_PANEL_ENABLED = false
if not ADMIN_PANEL_ENABLED then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local MenuPanelLayout = require(ReplicatedStorage.Shared:WaitForChild("MenuPanelLayout"))
local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15) or ReplicatedStorage
local AdminPanelAction = Remotes:WaitForChild("AdminPanelAction", 15) :: RemoteEvent?
local AdminPanelStatus = Remotes:WaitForChild("AdminPanelStatus", 15) :: RemoteEvent?

if not AdminPanelAction or not AdminPanelStatus then
	return
end

-- Assets & UI Constants
local ADMIN_IMAGE = "rbxassetid://10723374641" -- Sharp Lucide Crown
local CLICK_SOUND_ID = "rbxassetid://72264591133889"
local SUCCESS_SOUND_ID = "rbxassetid://80736831159506"
local BASE_MODAL_SIZE = MenuPanelLayout.ModalSizes.Admin or Vector2.new(680, 440)

-- Signature Game Theme Colors
local COLOR_NAVY_STROKE = Color3.fromRGB(11, 27, 61)   -- The iconic deep navy outline used in all game menus
local COLOR_FRAME_TOP = Color3.fromRGB(26, 42, 72)     -- Gradient top
local COLOR_FRAME_BOT = Color3.fromRGB(16, 24, 42)     -- Gradient bottom
local COLOR_FRAME_BG = Color3.fromRGB(20, 32, 54)      -- Base background
local COLOR_CONTAINER_BG = Color3.fromRGB(14, 22, 38)  -- Content container background
local COLOR_CARD_BG = Color3.fromRGB(22, 34, 58)       -- Card background
local COLOR_CARD_HOVER = Color3.fromRGB(28, 44, 76)    -- Card hover
local COLOR_GOLD = Color3.fromRGB(255, 215, 0)         -- Golden yellow accent
local COLOR_GOLD_TEXT = Color3.fromRGB(12, 18, 32)     -- Dark text for gold buttons
local COLOR_GREEN = Color3.fromRGB(45, 195, 95)        -- Confirm green
local COLOR_RED = Color3.fromRGB(235, 60, 60)          -- Close / danger red
local COLOR_CYAN = Color3.fromRGB(45, 170, 255)        -- Global / info cyan
local COLOR_TEXT = Color3.fromRGB(240, 245, 255)       -- Clean white text
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)      -- Pure white
local COLOR_SUBTEXT = Color3.fromRGB(160, 175, 205)    -- Muted text

local function playClickSound()
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = CLICK_SOUND_ID
		snd.Volume = 0.6
		snd.PlayOnRemove = true
		snd.Parent = SoundService
		snd:Destroy()
	end)
end

local function playSuccessSound()
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = SUCCESS_SOUND_ID
		snd.Volume = 0.7
		snd.PlayOnRemove = true
		snd.Parent = SoundService
		snd:Destroy()
	end)
end

-- UI Component Helpers
local function makeCorner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLOR_NAVY_STROKE
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- Main State
local screenGui: ScreenGui? = nil
local dim: Frame? = nil
local mainFrame: Frame? = nil
local uiScale: UIScale? = nil
local targetScale = 1
local isOpen = false
local isClosing = false

local toastFrame: Frame? = nil
local toastText: TextLabel? = nil
local autoRebirthBtn: TextButton? = nil
local autoRebirthActive = false
local autoRebirthMode = "Threshold"

local function showToast(message: string, success: boolean)
	if not toastFrame or not toastText then return end
	toastText.Text = message
	toastFrame.BackgroundColor3 = if success then COLOR_GREEN else COLOR_RED
	toastFrame.Visible = true

	local tweenIn = TweenService:Create(toastFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 24),
	})
	tweenIn:Play()

	task.delay(3.5, function()
		if toastFrame then
			local tweenOut = TweenService:Create(toastFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -60),
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if toastFrame and toastFrame.Position.Y.Offset <= -50 then
					toastFrame.Visible = false
				end
			end)
		end
	end)
end

local function updateScale()
	if not mainFrame or not uiScale then return end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	targetScale = MenuPanelLayout.GetModalScale(viewport, BASE_MODAL_SIZE, UserInputService.TouchEnabled)
	uiScale.Scale = targetScale
end

local function openPanel()
	if isOpen and not isClosing then return end
	if not screenGui or not mainFrame or not dim or not uiScale then return end

	isClosing = false
	isOpen = true
	mainFrame.Visible = true
	dim.Visible = true
	dim.Active = true

	updateScale()
	MenuEvents.SetHUDVisible(false, "Admin")
	MenuPanelLayout.AnimateOpen(mainFrame, dim, uiScale, targetScale, 0.24)
end

local function closePanel(instant: boolean?)
	if not screenGui or not mainFrame or not dim or not uiScale then return end
	if not isOpen and not mainFrame.Visible then return end

	if instant then
		isOpen = false
		isClosing = false
		mainFrame.Visible = false
		dim.Visible = false
		dim.Active = false
		MenuEvents.SetHUDVisible(true, nil)
		return
	end

	if isClosing then return end
	isClosing = true

	MenuPanelLayout.AnimateClose(mainFrame, dim, uiScale, targetScale, function()
		isClosing = false
		isOpen = false
		MenuEvents.SetHUDVisible(true, nil)
	end, 0.18)
end

local function togglePanel()
	if isOpen then
		closePanel()
	else
		openPanel()
	end
end

-- Build UI Structure
local function buildAdminUI()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpeedsterAdminMiniPanel"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = true
	screenGui.Parent = playerGui

	-- Dim Backdrop
	dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(2, 0, 2, 0)
	dim.Position = UDim2.new(0.5, 0, 0.5, 0)
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Visible = false
	dim.Active = true
	dim.ZIndex = 1
	dim.Parent = screenGui

	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)

	-- Floating Admin Button (Companion launcher on screen matching game UI)
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "FloatingAdminBtn"
	toggleBtn.Size = UDim2.fromOffset(105, 34)
	toggleBtn.Position = UDim2.new(1, -115, 0, 70)
	toggleBtn.BackgroundColor3 = COLOR_CARD_BG
	toggleBtn.Text = "👑 ADMIN"
	toggleBtn.TextColor3 = COLOR_GOLD
	toggleBtn.Font = Enum.Font.FredokaOne
	toggleBtn.TextSize = 13
	toggleBtn.BorderSizePixel = 0
	toggleBtn.ZIndex = 50
	toggleBtn.Parent = screenGui
	makeCorner(toggleBtn, 8)
	makeStroke(toggleBtn, COLOR_NAVY_STROKE, 2)

	toggleBtn.Activated:Connect(function()
		playClickSound()
		togglePanel()
	end)

	-- Toast Notification Frame
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "ToastFrame"
	toastFrame.Size = UDim2.new(0, 420, 0, 44)
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, -60)
	toastFrame.BackgroundColor3 = COLOR_GREEN
	toastFrame.BorderSizePixel = 0
	toastFrame.Visible = false
	toastFrame.ZIndex = 100
	toastFrame.Parent = screenGui
	makeCorner(toastFrame, 10)
	makeStroke(toastFrame, COLOR_NAVY_STROKE, 2.5)

	toastText = Instance.new("TextLabel")
	toastText.Name = "ToastText"
	toastText.Size = UDim2.new(1, -20, 1, 0)
	toastText.Position = UDim2.new(0, 10, 0, 0)
	toastText.BackgroundTransparency = 1
	toastText.Text = ""
	toastText.TextColor3 = COLOR_WHITE
	toastText.Font = Enum.Font.FredokaOne
	toastText.TextSize = 14
	toastText.TextWrapped = true
	toastText.Parent = toastFrame

	-- Main Window Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, BASE_MODAL_SIZE.X, 0, BASE_MODAL_SIZE.Y)
	mainFrame.Position = UDim2.new(0.5, 0, 0.48, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = COLOR_FRAME_BG
	mainFrame.Visible = false
	mainFrame.Active = true
	mainFrame.ZIndex = 10
	mainFrame.Parent = screenGui
	makeCorner(mainFrame, 16)
	makeStroke(mainFrame, COLOR_NAVY_STROKE, 3)

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLOR_FRAME_TOP),
		ColorSequenceKeypoint.new(1, COLOR_FRAME_BOT),
	})
	bgGradient.Rotation = 90
	bgGradient.Parent = mainFrame

	uiScale = MenuPanelLayout.EnsureSingleScale(mainFrame)
	updateScale()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end)

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundTransparency = 1
	header.Parent = mainFrame

	local headerIcon = Instance.new("ImageLabel")
	headerIcon.Name = "Icon"
	headerIcon.Size = UDim2.fromOffset(36, 36)
	headerIcon.Position = UDim2.new(0, 18, 0.5, 0)
	headerIcon.AnchorPoint = Vector2.new(0, 0.5)
	headerIcon.BackgroundTransparency = 1
	headerIcon.Image = ADMIN_IMAGE
	headerIcon.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -120, 1, 0)
	headerTitle.Position = UDim2.new(0.5, 0, 0.5, 0)
	headerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = "PANEL DE ADMINISTRACIÓN"
	headerTitle.TextColor3 = COLOR_GOLD
	headerTitle.Font = Enum.Font.FredokaOne
	headerTitle.TextSize = 22
	headerTitle.Parent = header
	makeStroke(headerTitle, COLOR_NAVY_STROKE, 2.5)

	-- Red Circle Close Button (Matching Game Modal Close Buttons)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "Close"
	closeBtn.Size = UDim2.fromOffset(34, 34)
	closeBtn.Position = UDim2.new(1, -18, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.BackgroundColor3 = COLOR_RED
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = COLOR_WHITE
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 16
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header
	makeCorner(closeBtn, 17)
	makeStroke(closeBtn, COLOR_NAVY_STROKE, 2)

	closeBtn.Activated:Connect(function()
		playClickSound()
		closePanel()
	end)

	-- Navigation Tabs Bar
	local navFrame = Instance.new("Frame")
	navFrame.Name = "NavFrame"
	navFrame.Size = UDim2.new(1, -28, 0, 36)
	navFrame.Position = UDim2.new(0, 14, 0, 54)
	navFrame.BackgroundTransparency = 1
	navFrame.Parent = mainFrame

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.Padding = UDim.new(0, 6)
	navLayout.Parent = navFrame

	-- Content Container
	local tabContentContainer = Instance.new("Frame")
	tabContentContainer.Name = "TabContainer"
	tabContentContainer.Size = UDim2.new(1, -28, 1, -104)
	tabContentContainer.Position = UDim2.new(0, 14, 0, 94)
	tabContentContainer.BackgroundColor3 = COLOR_CONTAINER_BG
	tabContentContainer.BorderSizePixel = 0
	tabContentContainer.Parent = mainFrame
	makeCorner(tabContentContainer, 10)
	makeStroke(tabContentContainer, COLOR_NAVY_STROKE, 2)

	local tabs: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}

	local tabNames = {
		{ Id = "Codes", Label = "🎁 Códigos" },
		{ Id = "Boosts", Label = "⚡ Boosts" },
		{ Id = "Stats", Label = "🏆 Stats" },
		{ Id = "Passes", Label = "🎟️ Pases" },
		{ Id = "World", Label = "🌍 Teleport" },
		{ Id = "Announce", Label = "📢 Announcement" },
	}

	local currentTabId = "Codes"

	local function selectTab(id: string)
		currentTabId = id
		for tId, page in pairs(tabs) do
			page.Visible = (tId == id)
		end
		for tId, btn in pairs(tabButtons) do
			if tId == id then
				btn.BackgroundColor3 = COLOR_GOLD
				btn.TextColor3 = COLOR_GOLD_TEXT
			else
				btn.BackgroundColor3 = COLOR_CARD_BG
				btn.TextColor3 = COLOR_SUBTEXT
			end
		end
	end

	for _, tInfo in ipairs(tabNames) do
		local btn = Instance.new("TextButton")
		btn.Name = "TabBtn_" .. tInfo.Id
		btn.Size = UDim2.new(0, 103, 1, 0)
		btn.BackgroundColor3 = COLOR_CARD_BG
		btn.Text = tInfo.Label
		btn.TextColor3 = COLOR_SUBTEXT
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 12
		btn.BorderSizePixel = 0
		btn.Parent = navFrame
		makeCorner(btn, 8)
		makeStroke(btn, COLOR_NAVY_STROKE, 1.5)

		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. tInfo.Id
		page.Size = UDim2.new(1, -16, 1, -16)
		page.Position = UDim2.new(0, 8, 0, 8)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 5
		page.ScrollBarImageColor3 = COLOR_GOLD
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.Visible = false
		page.Parent = tabContentContainer

		local pageLayout = Instance.new("UIListLayout")
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 10)
		pageLayout.Parent = page

		tabs[tInfo.Id] = page
		tabButtons[tInfo.Id] = btn

		btn.Activated:Connect(function()
			playClickSound()
			selectTab(tInfo.Id)
		end)
	end

	-- Helper: Create Standard Target Selector
	local function createTargetSelector(parent: Instance, layoutOrder: number): () -> string
		local selFrame = Instance.new("Frame")
		selFrame.Name = "TargetSelector"
		selFrame.Size = UDim2.new(1, 0, 0, 38)
		selFrame.BackgroundColor3 = COLOR_CARD_BG
		selFrame.BorderSizePixel = 0
		selFrame.LayoutOrder = layoutOrder
		selFrame.Parent = parent
		makeCorner(selFrame, 8)
		makeStroke(selFrame, COLOR_NAVY_STROKE, 1.5)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 95, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Destinatario:"
		lbl.TextColor3 = COLOR_SUBTEXT
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = selFrame

		local target = "All"
		local btnAll = Instance.new("TextButton")
		btnAll.Size = UDim2.new(0, 185, 0, 28)
		btnAll.Position = UDim2.new(0, 110, 0, 5)
		btnAll.BackgroundColor3 = COLOR_GOLD
		btnAll.Text = "🌐 Todos los Jugadores"
		btnAll.TextColor3 = COLOR_GOLD_TEXT
		btnAll.Font = Enum.Font.FredokaOne
		btnAll.TextSize = 12
		btnAll.BorderSizePixel = 0
		btnAll.Parent = selFrame
		makeCorner(btnAll, 6)
		makeStroke(btnAll, COLOR_NAVY_STROKE, 1)

		local btnSelf = Instance.new("TextButton")
		btnSelf.Size = UDim2.new(0, 150, 0, 28)
		btnSelf.Position = UDim2.new(0, 305, 0, 5)
		btnSelf.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
		btnSelf.Text = "👤 Solo Yo (Admin)"
		btnSelf.TextColor3 = COLOR_SUBTEXT
		btnSelf.Font = Enum.Font.FredokaOne
		btnSelf.TextSize = 12
		btnSelf.BorderSizePixel = 0
		btnSelf.Parent = selFrame
		makeCorner(btnSelf, 6)
		makeStroke(btnSelf, COLOR_NAVY_STROKE, 1)

		btnAll.Activated:Connect(function()
			playClickSound()
			target = "All"
			btnAll.BackgroundColor3 = COLOR_GOLD
			btnAll.TextColor3 = COLOR_GOLD_TEXT
			btnSelf.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
			btnSelf.TextColor3 = COLOR_SUBTEXT
		end)

		btnSelf.Activated:Connect(function()
			playClickSound()
			target = "Self"
			btnSelf.BackgroundColor3 = COLOR_CYAN
			btnSelf.TextColor3 = COLOR_WHITE
			btnAll.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
			btnAll.TextColor3 = COLOR_SUBTEXT
		end)

		return function()
			return target
		end
	end

	-------------------------------------------------------------------------
	-- TAB 1: 🎁 CÓDIGOS (ESTE SERVIDOR / GLOBAL)
	-------------------------------------------------------------------------
	local pCodes = tabs["Codes"]

	local cDesc = Instance.new("TextLabel")
	cDesc.Size = UDim2.new(1, 0, 0, 24)
	cDesc.BackgroundTransparency = 1
	cDesc.Text = "🎁 Activa códigos promocionales para todos los jugadores de forma instantánea:"
	cDesc.TextColor3 = COLOR_TEXT
	cDesc.Font = Enum.Font.FredokaOne
	cDesc.TextSize = 13
	cDesc.TextXAlignment = Enum.TextXAlignment.Left
	cDesc.LayoutOrder = 1
	cDesc.Parent = pCodes

	-- Scope Selector
	local scopeFrame = Instance.new("Frame")
	scopeFrame.Name = "ScopeFrame"
	scopeFrame.Size = UDim2.new(1, 0, 0, 38)
	scopeFrame.BackgroundColor3 = COLOR_CARD_BG
	scopeFrame.BorderSizePixel = 0
	scopeFrame.LayoutOrder = 2
	scopeFrame.Parent = pCodes
	makeCorner(scopeFrame, 8)
	makeStroke(scopeFrame, COLOR_NAVY_STROKE, 1.5)

	local scopeLbl = Instance.new("TextLabel")
	scopeLbl.Size = UDim2.new(0, 90, 1, 0)
	scopeLbl.Position = UDim2.new(0, 10, 0, 0)
	scopeLbl.BackgroundTransparency = 1
	scopeLbl.Text = "Alcance:"
	scopeLbl.TextColor3 = COLOR_SUBTEXT
	scopeLbl.Font = Enum.Font.FredokaOne
	scopeLbl.TextSize = 13
	scopeLbl.TextXAlignment = Enum.TextXAlignment.Left
	scopeLbl.Parent = scopeFrame

	local selectedScope = "Server"

	local btnScopeServer = Instance.new("TextButton")
	btnScopeServer.Size = UDim2.new(0, 210, 0, 28)
	btnScopeServer.Position = UDim2.new(0, 105, 0, 5)
	btnScopeServer.BackgroundColor3 = COLOR_GOLD
	btnScopeServer.Text = "🖥️ Este Servidor (Todos)"
	btnScopeServer.TextColor3 = COLOR_GOLD_TEXT
	btnScopeServer.Font = Enum.Font.FredokaOne
	btnScopeServer.TextSize = 12
	btnScopeServer.BorderSizePixel = 0
	btnScopeServer.Parent = scopeFrame
	makeCorner(btnScopeServer, 6)
	makeStroke(btnScopeServer, COLOR_NAVY_STROKE, 1)

	local btnScopeGlobal = Instance.new("TextButton")
	btnScopeGlobal.Size = UDim2.new(0, 240, 0, 28)
	btnScopeGlobal.Position = UDim2.new(0, 325, 0, 5)
	btnScopeGlobal.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
	btnScopeGlobal.Text = "🌐 GLOBAL (Todos los Servidores)"
	btnScopeGlobal.TextColor3 = COLOR_SUBTEXT
	btnScopeGlobal.Font = Enum.Font.FredokaOne
	btnScopeGlobal.TextSize = 12
	btnScopeGlobal.BorderSizePixel = 0
	btnScopeGlobal.Parent = scopeFrame
	makeCorner(btnScopeGlobal, 6)
	makeStroke(btnScopeGlobal, COLOR_NAVY_STROKE, 1)

	btnScopeServer.Activated:Connect(function()
		playClickSound()
		selectedScope = "Server"
		btnScopeServer.BackgroundColor3 = COLOR_GOLD
		btnScopeServer.TextColor3 = COLOR_GOLD_TEXT
		btnScopeGlobal.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
		btnScopeGlobal.TextColor3 = COLOR_SUBTEXT
	end)

	btnScopeGlobal.Activated:Connect(function()
		playClickSound()
		selectedScope = "Global"
		btnScopeGlobal.BackgroundColor3 = COLOR_CYAN
		btnScopeGlobal.TextColor3 = COLOR_WHITE
		btnScopeServer.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
		btnScopeServer.TextColor3 = COLOR_SUBTEXT
	end)

	-- Custom Code Input Box
	local inputLabel = Instance.new("TextLabel")
	inputLabel.Size = UDim2.new(1, 0, 0, 20)
	inputLabel.BackgroundTransparency = 1
	inputLabel.Text = "Código a activar:"
	inputLabel.TextColor3 = COLOR_GOLD
	inputLabel.Font = Enum.Font.FredokaOne
	inputLabel.TextSize = 13
	inputLabel.TextXAlignment = Enum.TextXAlignment.Left
	inputLabel.LayoutOrder = 3
	inputLabel.Parent = pCodes

	local inputFrame = Instance.new("Frame")
	inputFrame.Size = UDim2.new(1, 0, 0, 38)
	inputFrame.BackgroundColor3 = COLOR_CARD_BG
	inputFrame.BorderSizePixel = 0
	inputFrame.LayoutOrder = 4
	inputFrame.Parent = pCodes
	makeCorner(inputFrame, 8)
	makeStroke(inputFrame, COLOR_NAVY_STROKE, 1.5)

	local codeBox = Instance.new("TextBox")
	codeBox.Size = UDim2.new(1, -20, 1, 0)
	codeBox.Position = UDim2.new(0, 10, 0, 0)
	codeBox.BackgroundTransparency = 1
	codeBox.PlaceholderText = "Escribe o selecciona un código (ej. geko, admingiveaway)..."
	codeBox.PlaceholderColor3 = Color3.fromRGB(120, 135, 165)
	codeBox.Text = "geko"
	codeBox.TextColor3 = COLOR_GOLD
	codeBox.Font = Enum.Font.FredokaOne
	codeBox.TextSize = 14
	codeBox.TextXAlignment = Enum.TextXAlignment.Left
	codeBox.ClearTextOnFocus = false
	codeBox.Parent = inputFrame

	-- Quick Selection Grid
	local quickTitle = Instance.new("TextLabel")
	quickTitle.Size = UDim2.new(1, 0, 0, 20)
	quickTitle.BackgroundTransparency = 1
	quickTitle.Text = "⚡ Códigos Populares (clic para seleccionar rápido):"
	quickTitle.TextColor3 = COLOR_SUBTEXT
	quickTitle.Font = Enum.Font.FredokaOne
	quickTitle.TextSize = 12
	quickTitle.TextXAlignment = Enum.TextXAlignment.Left
	quickTitle.LayoutOrder = 5
	quickTitle.Parent = pCodes

	local quickGrid = Instance.new("Frame")
	quickGrid.Size = UDim2.new(1, 0, 0, 114)
	quickGrid.BackgroundTransparency = 1
	quickGrid.LayoutOrder = 6
	quickGrid.Parent = pCodes

	local quickCodes = {
		{ Code = "Gekkoh", Label = "👑 Gekkoh (20m Fly + 800K XP + 20K Wins)" },
		{ Code = "admingiveaway", Label = "🎁 admingiveaway (1M Speed + 25K Wins)" },
		{ Code = "update2", Label = "⚡ update2 (10m 2x Speed Potion)" },
		{ Code = "7kccu", Label = "🏆 7kccu (10m Wins Potion + XP)" },
		{ Code = "sorry4bugs", Label = "🐛 sorry4bugs (2 Rebirths + Potions)" },
		{ Code = "5mvisits", Label = "🎉 5mvisits (500K Speed + 15K Wins)" },
	}

	for i, qc in ipairs(quickCodes) do
		local x = ((i - 1) % 2) * 295
		local y = math.floor((i - 1) / 2) * 38
		local qBtn = Instance.new("TextButton")
		qBtn.Size = UDim2.new(0, 285, 0, 32)
		qBtn.Position = UDim2.new(0, x, 0, y)
		qBtn.BackgroundColor3 = COLOR_CARD_BG
		qBtn.Text = qc.Label
		qBtn.TextColor3 = COLOR_TEXT
		qBtn.Font = Enum.Font.FredokaOne
		qBtn.TextSize = 11
		qBtn.BorderSizePixel = 0
		qBtn.Parent = quickGrid
		makeCorner(qBtn, 6)
		makeStroke(qBtn, COLOR_NAVY_STROKE, 1)

		qBtn.Activated:Connect(function()
			playClickSound()
			codeBox.Text = qc.Code
		end)
	end

	-- Force claim toggle
	local forceFrame = Instance.new("Frame")
	forceFrame.Size = UDim2.new(1, 0, 0, 34)
	forceFrame.BackgroundTransparency = 1
	forceFrame.LayoutOrder = 7
	forceFrame.Parent = pCodes

	local isForce = true

	local forceBtn = Instance.new("TextButton")
	forceBtn.Size = UDim2.new(1, 0, 1, 0)
	forceBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 70)
	forceBtn.Text = "☑️ Otorgar a TODOS (activo: se otorgan recompensas incluso a quienes ya lo canjearon)"
	forceBtn.TextColor3 = COLOR_GOLD
	forceBtn.Font = Enum.Font.FredokaOne
	forceBtn.TextSize = 12
	forceBtn.BorderSizePixel = 0
	forceBtn.Parent = forceFrame
	makeCorner(forceBtn, 6)
	makeStroke(forceBtn, COLOR_NAVY_STROKE, 1)

	forceBtn.Activated:Connect(function()
		playClickSound()
		isForce = not isForce
		if isForce then
			forceBtn.Text = "☑️ Otorgar a TODOS (activo: se otorgan recompensas incluso a quienes ya lo canjearon)"
			forceBtn.TextColor3 = COLOR_GOLD
			forceBtn.BackgroundColor3 = Color3.fromRGB(28, 42, 70)
		else
			forceBtn.Text = "☐ Respetar canjes previos (desactivado: jugadores que ya lo canjearon son omitidos)"
			forceBtn.TextColor3 = COLOR_SUBTEXT
			forceBtn.BackgroundColor3 = COLOR_CARD_BG
		end
	end)

	-- Big Green Action Button
	local btnActivateCode = Instance.new("TextButton")
	btnActivateCode.Size = UDim2.new(1, 0, 0, 42)
	btnActivateCode.BackgroundColor3 = COLOR_GREEN
	btnActivateCode.Text = "🚀 ACTIVAR CÓDIGO AHORA"
	btnActivateCode.TextColor3 = COLOR_WHITE
	btnActivateCode.Font = Enum.Font.FredokaOne
	btnActivateCode.TextSize = 15
	btnActivateCode.BorderSizePixel = 0
	btnActivateCode.LayoutOrder = 8
	btnActivateCode.Parent = pCodes
	makeCorner(btnActivateCode, 8)
	makeStroke(btnActivateCode, COLOR_NAVY_STROKE, 2)

	btnActivateCode.Activated:Connect(function()
		local raw = tostring(codeBox.Text or "")
		local clean = string.match(raw, "^%s*(.-)%s*$") or ""
		if #clean == 0 then
			showToast("Escribe o selecciona un código primero.", false)
			return
		end
		playSuccessSound()
		AdminPanelAction:FireServer({
			action = "ActivateCode",
			code = clean,
			scope = selectedScope,
			force = isForce,
		})
	end)

	-------------------------------------------------------------------------
	-- TAB 2: ⚡ BOOSTS & VUELO
	-------------------------------------------------------------------------
	local pBoosts = tabs["Boosts"]

	-- Geko Fly Giveaway Card
	local gekoCard = Instance.new("Frame")
	gekoCard.Size = UDim2.new(1, 0, 0, 95)
	gekoCard.BackgroundColor3 = COLOR_CARD_BG
	gekoCard.BorderSizePixel = 0
	gekoCard.LayoutOrder = 1
	gekoCard.Parent = pBoosts
	makeCorner(gekoCard, 10)
	makeStroke(gekoCard, COLOR_NAVY_STROKE, 2)

	local gekoTitle = Instance.new("TextLabel")
	gekoTitle.Size = UDim2.new(1, -20, 0, 24)
	gekoTitle.Position = UDim2.new(0, 12, 0, 8)
	gekoTitle.BackgroundTransparency = 1
	gekoTitle.Text = "👑 GEKKOH FLY GIVEAWAY (Vuelo + XP Especial)"
	gekoTitle.TextColor3 = COLOR_GOLD
	gekoTitle.Font = Enum.Font.FredokaOne
	gekoTitle.TextSize = 14
	gekoTitle.TextXAlignment = Enum.TextXAlignment.Left
	gekoTitle.Parent = gekoCard

	local gekoSub = Instance.new("TextLabel")
	gekoSub.Size = UDim2.new(1, -20, 0, 18)
	gekoSub.Position = UDim2.new(0, 12, 0, 30)
	gekoSub.BackgroundTransparency = 1
	gekoSub.Text = "Otorga 20 minutos de Vuelo + 800,000 Speed + 20,000 Wins a todos los jugadores."
	gekoSub.TextColor3 = COLOR_SUBTEXT
	gekoSub.Font = Enum.Font.FredokaOne
	gekoSub.TextSize = 11
	gekoSub.TextXAlignment = Enum.TextXAlignment.Left
	gekoSub.Parent = gekoCard

	local gekoBtn = Instance.new("TextButton")
	gekoBtn.Size = UDim2.new(1, -24, 0, 32)
	gekoBtn.Position = UDim2.new(0, 12, 0, 54)
	gekoBtn.BackgroundColor3 = COLOR_GREEN
	gekoBtn.Text = "🎁 OTORGAR GEKKOH FLY A TODOS (20m Fly + 800K XP + 20K Wins)"
	gekoBtn.TextColor3 = COLOR_WHITE
	gekoBtn.Font = Enum.Font.FredokaOne
	gekoBtn.TextSize = 12
	gekoBtn.BorderSizePixel = 0
	gekoBtn.Parent = gekoCard
	makeCorner(gekoBtn, 6)
	makeStroke(gekoBtn, COLOR_NAVY_STROKE, 1.5)

	gekoBtn.Activated:Connect(function()
		playSuccessSound()
		AdminPanelAction:FireServer({
			action = "GekoFlyGiveaway",
			target = "All",
			minutes = 20,
		})
	end)

	-- Server Boost Durations
	local bDesc = Instance.new("TextLabel")
	bDesc.Size = UDim2.new(1, 0, 0, 24)
	bDesc.BackgroundTransparency = 1
	bDesc.Text = "🚀 Activa Boost 2x Speed y 2x Wins para TODO el servidor:"
	bDesc.TextColor3 = COLOR_TEXT
	bDesc.Font = Enum.Font.FredokaOne
	bDesc.TextSize = 13
	bDesc.TextXAlignment = Enum.TextXAlignment.Left
	bDesc.LayoutOrder = 2
	bDesc.Parent = pBoosts

	local bGrid = Instance.new("Frame")
	bGrid.Size = UDim2.new(1, 0, 0, 80)
	bGrid.BackgroundTransparency = 1
	bGrid.LayoutOrder = 3
	bGrid.Parent = pBoosts

	local durations = {
		{ Mins = 15, Label = "15 Minutos ⚡" },
		{ Mins = 30, Label = "30 Minutos ⚡" },
		{ Mins = 60, Label = "1 Hora ⚡" },
		{ Mins = 120, Label = "2 Horas ⚡" },
	}

	for i, d in ipairs(durations) do
		local x = ((i - 1) % 2) * 295
		local y = math.floor((i - 1) / 2) * 40
		local bBtn = Instance.new("TextButton")
		bBtn.Size = UDim2.new(0, 285, 0, 34)
		bBtn.Position = UDim2.new(0, x, 0, y)
		bBtn.BackgroundColor3 = COLOR_CARD_BG
		bBtn.Text = d.Label
		bBtn.TextColor3 = COLOR_GOLD
		bBtn.Font = Enum.Font.FredokaOne
		bBtn.TextSize = 13
		bBtn.BorderSizePixel = 0
		bBtn.Parent = bGrid
		makeCorner(bBtn, 6)
		makeStroke(bBtn, COLOR_NAVY_STROKE, 1.5)

		bBtn.Activated:Connect(function()
			playSuccessSound()
			AdminPanelAction:FireServer({
				action = "ServerBoost",
				minutes = d.Mins,
			})
		end)
	end

	-------------------------------------------------------------------------
	-- TAB 3: 🏆 STATS & REBIRTHS
	-------------------------------------------------------------------------
	local pStats = tabs["Stats"]
	local getStatTarget = createTargetSelector(pStats, 1)

	local function makeStatSection(title: string, amounts: { number }, statKey: string, layoutOrder: number)
		local secTitle = Instance.new("TextLabel")
		secTitle.Size = UDim2.new(1, 0, 0, 22)
		secTitle.BackgroundTransparency = 1
		secTitle.Text = title
		secTitle.TextColor3 = COLOR_TEXT
		secTitle.Font = Enum.Font.FredokaOne
		secTitle.TextSize = 13
		secTitle.TextXAlignment = Enum.TextXAlignment.Left
		secTitle.LayoutOrder = layoutOrder
		secTitle.Parent = pStats

		local grid = Instance.new("Frame")
		grid.Size = UDim2.new(1, 0, 0, 36)
		grid.BackgroundTransparency = 1
		grid.LayoutOrder = layoutOrder + 1
		grid.Parent = pStats

		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 8)
		list.Parent = grid

		for _, amt in ipairs(amounts) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 138, 1, 0)
			btn.BackgroundColor3 = COLOR_CARD_BG
			btn.Text = "+" .. tostring(amt >= 1000000 and (amt / 1000000 .. "M") or (amt >= 1000 and (amt / 1000 .. "K") or amt)) .. " " .. statKey
			btn.TextColor3 = COLOR_GOLD
			btn.Font = Enum.Font.FredokaOne
			btn.TextSize = 12
			btn.BorderSizePixel = 0
			btn.Parent = grid
			makeCorner(btn, 6)
			makeStroke(btn, COLOR_NAVY_STROKE, 1.5)

			btn.Activated:Connect(function()
				playSuccessSound()
				AdminPanelAction:FireServer({
					action = if statKey == "Rebirths" then "GiveRebirths" else "GiveStat",
					target = getStatTarget(),
					stat = statKey,
					amount = amt,
				})
			end)
		end
	end

	makeStatSection("⚡ Otorgar Speed:", { 50000, 500000, 5000000, 50000000 }, "Speed", 2)
	makeStatSection("🏆 Otorgar Wins:", { 1000, 10000, 100000, 1000000 }, "Wins", 4)
	makeStatSection("🔄 Otorgar Rebirths:", { 1, 5, 10, 50 }, "Rebirths", 6)

	-- Auto Rebirth & Reset Section
	local autoFrame = Instance.new("Frame")
	autoFrame.Size = UDim2.new(1, 0, 0, 75)
	autoFrame.BackgroundColor3 = COLOR_CARD_BG
	autoFrame.BorderSizePixel = 0
	autoFrame.LayoutOrder = 8
	autoFrame.Parent = pStats
	makeCorner(autoFrame, 10)
	makeStroke(autoFrame, COLOR_NAVY_STROKE, 2)

	local autoTitle = Instance.new("TextLabel")
	autoTitle.Size = UDim2.new(1, -20, 0, 22)
	autoTitle.Position = UDim2.new(0, 12, 0, 6)
	autoTitle.BackgroundTransparency = 1
	autoTitle.Text = "🔄 AUTO REBIRTH y Reinicio para Administrador:"
	autoTitle.TextColor3 = COLOR_GOLD
	autoTitle.Font = Enum.Font.FredokaOne
	autoTitle.TextSize = 13
	autoTitle.TextXAlignment = Enum.TextXAlignment.Left
	autoTitle.Parent = autoFrame

	autoRebirthBtn = Instance.new("TextButton")
	autoRebirthBtn.Size = UDim2.new(0, 270, 0, 32)
	autoRebirthBtn.Position = UDim2.new(0, 12, 0, 32)
	autoRebirthBtn.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
	autoRebirthBtn.Text = "🔄 AUTO REBIRTH: DESACTIVADO"
	autoRebirthBtn.TextColor3 = COLOR_SUBTEXT
	autoRebirthBtn.Font = Enum.Font.FredokaOne
	autoRebirthBtn.TextSize = 12
	autoRebirthBtn.BorderSizePixel = 0
	autoRebirthBtn.Parent = autoFrame
	makeCorner(autoRebirthBtn, 6)
	makeStroke(autoRebirthBtn, COLOR_NAVY_STROKE, 1.5)

	autoRebirthBtn.Activated:Connect(function()
		playClickSound()
		autoRebirthActive = not autoRebirthActive
		if autoRebirthActive then
			autoRebirthBtn.Text = "🔄 AUTO REBIRTH: ACTIVADO"
			autoRebirthBtn.BackgroundColor3 = COLOR_GREEN
			autoRebirthBtn.TextColor3 = COLOR_WHITE
		else
			autoRebirthBtn.Text = "🔄 AUTO REBIRTH: DESACTIVADO"
			autoRebirthBtn.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
			autoRebirthBtn.TextColor3 = COLOR_SUBTEXT
		end
		AdminPanelAction:FireServer({
			action = "AutoRebirth",
			enabled = autoRebirthActive,
			mode = autoRebirthMode,
		})
	end)

	local manualResetBtn = Instance.new("TextButton")
	manualResetBtn.Size = UDim2.new(0, 270, 0, 32)
	manualResetBtn.Position = UDim2.new(0, 296, 0, 32)
	manualResetBtn.BackgroundColor3 = COLOR_CYAN
	manualResetBtn.Text = "✨ Forzar Rebirth y Resetear Stats"
	manualResetBtn.TextColor3 = COLOR_WHITE
	manualResetBtn.Font = Enum.Font.FredokaOne
	manualResetBtn.TextSize = 12
	manualResetBtn.BorderSizePixel = 0
	manualResetBtn.Parent = autoFrame
	makeCorner(manualResetBtn, 6)
	makeStroke(manualResetBtn, COLOR_NAVY_STROKE, 1.5)

	manualResetBtn.Activated:Connect(function()
		playSuccessSound()
		AdminPanelAction:FireServer({ action = "ManualRebirthReset" })
	end)

	-------------------------------------------------------------------------
	-- TAB 4: 🎟️ PASES GRATIS
	-------------------------------------------------------------------------
	local pPasses = tabs["Passes"]
	local getPassTarget = createTargetSelector(pPasses, 1)

	local passActionsFrame = Instance.new("Frame")
	passActionsFrame.Size = UDim2.new(1, 0, 0, 38)
	passActionsFrame.BackgroundTransparency = 1
	passActionsFrame.LayoutOrder = 2
	passActionsFrame.Parent = pPasses

	local allPassesBtn = Instance.new("TextButton")
	allPassesBtn.Size = UDim2.new(0, 285, 1, 0)
	allPassesBtn.Position = UDim2.new(0, 0, 0, 0)
	allPassesBtn.BackgroundColor3 = COLOR_GOLD
	allPassesBtn.Text = "⚡ ACTIVAR TODOS LOS PASES"
	allPassesBtn.TextColor3 = COLOR_GOLD_TEXT
	allPassesBtn.Font = Enum.Font.FredokaOne
	allPassesBtn.TextSize = 13
	allPassesBtn.BorderSizePixel = 0
	allPassesBtn.Parent = passActionsFrame
	makeCorner(allPassesBtn, 8)
	makeStroke(allPassesBtn, COLOR_NAVY_STROKE, 2)

	local deactivateAllPassesBtn = Instance.new("TextButton")
	deactivateAllPassesBtn.Size = UDim2.new(0, 285, 1, 0)
	deactivateAllPassesBtn.Position = UDim2.new(0, 295, 0, 0)
	deactivateAllPassesBtn.BackgroundColor3 = COLOR_RED
	deactivateAllPassesBtn.Text = "🚫 DESACTIVAR TODOS LOS PASES"
	deactivateAllPassesBtn.TextColor3 = COLOR_WHITE
	deactivateAllPassesBtn.Font = Enum.Font.FredokaOne
	deactivateAllPassesBtn.TextSize = 13
	deactivateAllPassesBtn.BorderSizePixel = 0
	deactivateAllPassesBtn.Parent = passActionsFrame
	makeCorner(deactivateAllPassesBtn, 8)
	makeStroke(deactivateAllPassesBtn, COLOR_NAVY_STROKE, 2)

	local passesList = {
		{ Id = "VIP", Label = "🎟️ VIP Pass" },
		{ Id = "2xSpeed", Label = "⚡ 2x Speed Pass" },
		{ Id = "2xWins", Label = "🏆 2x Wins Pass" },
		{ Id = "AutoRun", Label = "🏃 Auto Run Pass" },
		{ Id = "DarkZonic", Label = "🦔 Dark Zonic Skin" },
		{ Id = "Teleport", Label = "🚀 Teleport Pass" },
	}

	local passStates: { [string]: boolean } = {}
	local passButtons: { [string]: TextButton } = {}

	allPassesBtn.Activated:Connect(function()
		playSuccessSound()
		for _, p in ipairs(passesList) do
			passStates[p.Id] = true
			if passButtons[p.Id] then
				passButtons[p.Id].Text = "ON"
				passButtons[p.Id].BackgroundColor3 = COLOR_GREEN
			end
			AdminPanelAction:FireServer({
				action = "TogglePass",
				target = getPassTarget(),
				pass = p.Id,
				enabled = true,
			})
		end
		showToast("¡Todos los pases activados!", true)
	end)

	deactivateAllPassesBtn.Activated:Connect(function()
		playClickSound()
		for _, p in ipairs(passesList) do
			passStates[p.Id] = false
			if passButtons[p.Id] then
				passButtons[p.Id].Text = "OFF"
				passButtons[p.Id].BackgroundColor3 = COLOR_RED
			end
			AdminPanelAction:FireServer({
				action = "TogglePass",
				target = getPassTarget(),
				pass = p.Id,
				enabled = false,
			})
		end
		showToast("Todos los pases desactivados.", true)
	end)

	local passGrid = Instance.new("Frame")
	passGrid.Size = UDim2.new(1, 0, 0, 130)
	passGrid.BackgroundTransparency = 1
	passGrid.LayoutOrder = 3
	passGrid.Parent = pPasses

	for i, p in ipairs(passesList) do
		local x = ((i - 1) % 2) * 295
		local y = math.floor((i - 1) / 2) * 42
		passStates[p.Id] = false

		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, 285, 0, 36)
		card.Position = UDim2.new(0, x, 0, y)
		card.BackgroundColor3 = COLOR_CARD_BG
		card.BorderSizePixel = 0
		card.Parent = passGrid
		makeCorner(card, 6)
		makeStroke(card, COLOR_NAVY_STROKE, 1.5)

		local pLbl = Instance.new("TextLabel")
		pLbl.Size = UDim2.new(1, -95, 1, 0)
		pLbl.Position = UDim2.new(0, 10, 0, 0)
		pLbl.BackgroundTransparency = 1
		pLbl.Text = p.Label
		pLbl.TextColor3 = COLOR_TEXT
		pLbl.Font = Enum.Font.FredokaOne
		pLbl.TextSize = 12
		pLbl.TextXAlignment = Enum.TextXAlignment.Left
		pLbl.Parent = card

		local toggle = Instance.new("TextButton")
		toggle.Size = UDim2.new(0, 75, 0, 26)
		toggle.Position = UDim2.new(1, -85, 0, 5)
		toggle.BackgroundColor3 = COLOR_RED
		toggle.Text = "OFF"
		toggle.TextColor3 = COLOR_WHITE
		toggle.Font = Enum.Font.FredokaOne
		toggle.TextSize = 11
		toggle.BorderSizePixel = 0
		toggle.Parent = card
		makeCorner(toggle, 5)
		makeStroke(toggle, COLOR_NAVY_STROKE, 1)

		passButtons[p.Id] = toggle

		toggle.Activated:Connect(function()
			playClickSound()
			passStates[p.Id] = not passStates[p.Id]
			local isOn = passStates[p.Id]
			toggle.Text = if isOn then "ON" else "OFF"
			toggle.BackgroundColor3 = if isOn then COLOR_GREEN else COLOR_RED
			AdminPanelAction:FireServer({
				action = "TogglePass",
				target = getPassTarget(),
				pass = p.Id,
				enabled = isOn,
			})
		end)
	end

	-------------------------------------------------------------------------
	-- TAB 5: 🌍 MUNDOS (TELEPORT & DESBLOQUEO)
	-------------------------------------------------------------------------
	local pWorld = tabs["World"]
	local getWorldTarget = createTargetSelector(pWorld, 1)

	local wDesc = Instance.new("TextLabel")
	wDesc.Size = UDim2.new(1, 0, 0, 24)
	wDesc.BackgroundTransparency = 1
	wDesc.Text = "Regresa a World 1 al instante sin costo ni requisitos:"
	wDesc.TextColor3 = COLOR_TEXT
	wDesc.Font = Enum.Font.FredokaOne
	wDesc.TextSize = 13
	wDesc.TextXAlignment = Enum.TextXAlignment.Left
	wDesc.LayoutOrder = 2
	wDesc.Parent = pWorld

	local wBtnFrame = Instance.new("Frame")
	wBtnFrame.Size = UDim2.new(1, 0, 0, 85)
	wBtnFrame.BackgroundTransparency = 1
	wBtnFrame.LayoutOrder = 3
	wBtnFrame.Parent = pWorld

	local btnUnlockW2 = Instance.new("TextButton")
	btnUnlockW2.Size = UDim2.new(0, 285, 0, 36)
	btnUnlockW2.Position = UDim2.new(0, 0, 0, 0)
	btnUnlockW2.BackgroundColor3 = COLOR_GREEN
	btnUnlockW2.Text = "🔓 DESBLOQUEAR WORLD 2 (Permanente)"
	btnUnlockW2.TextColor3 = COLOR_WHITE
	btnUnlockW2.Font = Enum.Font.FredokaOne
	btnUnlockW2.TextSize = 12
	btnUnlockW2.BorderSizePixel = 0
	btnUnlockW2.Parent = wBtnFrame
	makeCorner(btnUnlockW2, 6)
	makeStroke(btnUnlockW2, COLOR_NAVY_STROKE, 1.5)

	local btnLockW2 = Instance.new("TextButton")
	btnLockW2.Size = UDim2.new(0, 285, 0, 36)
	btnLockW2.Position = UDim2.new(0, 295, 0, 0)
	btnLockW2.BackgroundColor3 = COLOR_RED
	btnLockW2.Text = "🔒 BLOQUEAR WORLD 2"
	btnLockW2.TextColor3 = COLOR_WHITE
	btnLockW2.Font = Enum.Font.FredokaOne
	btnLockW2.TextSize = 12
	btnLockW2.BorderSizePixel = 0
	btnLockW2.Parent = wBtnFrame
	makeCorner(btnLockW2, 6)
	makeStroke(btnLockW2, COLOR_NAVY_STROKE, 1.5)

	local btnTeleport = Instance.new("TextButton")
	btnTeleport.Size = UDim2.new(1, 0, 0, 38)
	btnTeleport.Position = UDim2.new(0, 0, 0, 44)
	btnTeleport.BackgroundColor3 = COLOR_CYAN
	btnTeleport.Text = "🚀 TELETRANSPORTAR A WORLD 1 AHORA"
	btnTeleport.TextColor3 = COLOR_WHITE
	btnTeleport.Font = Enum.Font.FredokaOne
	btnTeleport.TextSize = 13
	btnTeleport.BorderSizePixel = 0
	btnTeleport.Parent = wBtnFrame
	makeCorner(btnTeleport, 6)
	makeStroke(btnTeleport, COLOR_NAVY_STROKE, 2)

	btnUnlockW2.Activated:Connect(function()
		playSuccessSound()
		AdminPanelAction:FireServer({
			action = "UnlockWorld2",
			target = getWorldTarget(),
			enabled = true,
		})
	end)

	btnLockW2.Activated:Connect(function()
		playClickSound()
		AdminPanelAction:FireServer({
			action = "UnlockWorld2",
			target = getWorldTarget(),
			enabled = false,
		})
	end)

	btnTeleport.Activated:Connect(function()
		playSuccessSound()
		AdminPanelAction:FireServer({ action = "TeleportWorld1" })
	end)

	-------------------------------------------------------------------------
	-- TAB 6: 📢 GLOBAL ANNOUNCEMENT (ALL SERVERS)
	-------------------------------------------------------------------------
	local pAnnounce = tabs["Announce"]

	local aDesc = Instance.new("TextLabel")
	aDesc.Size = UDim2.new(1, 0, 0, 24)
	aDesc.BackgroundTransparency = 1
	aDesc.Text = "📢 Broadcast a banner announcement to ALL active servers:"
	aDesc.TextColor3 = COLOR_TEXT
	aDesc.Font = Enum.Font.FredokaOne
	aDesc.TextSize = 13
	aDesc.TextXAlignment = Enum.TextXAlignment.Left
	aDesc.LayoutOrder = 1
	aDesc.Parent = pAnnounce

	local aInputFrame = Instance.new("Frame")
	aInputFrame.Size = UDim2.new(1, 0, 0, 80)
	aInputFrame.BackgroundColor3 = COLOR_CARD_BG
	aInputFrame.BorderSizePixel = 0
	aInputFrame.LayoutOrder = 2
	aInputFrame.Parent = pAnnounce
	makeCorner(aInputFrame, 8)
	makeStroke(aInputFrame, COLOR_NAVY_STROKE, 1.5)

	local aBox = Instance.new("TextBox")
	aBox.Size = UDim2.new(1, -20, 1, -20)
	aBox.Position = UDim2.new(0, 10, 0, 10)
	aBox.BackgroundTransparency = 1
	aBox.PlaceholderText = "Type announcement here (e.g. Special 2x Speed event active!)..."
	aBox.PlaceholderColor3 = Color3.fromRGB(120, 135, 165)
	aBox.Text = ""
	aBox.TextColor3 = COLOR_WHITE
	aBox.Font = Enum.Font.FredokaOne
	aBox.TextSize = 14
	aBox.TextXAlignment = Enum.TextXAlignment.Left
	aBox.TextYAlignment = Enum.TextYAlignment.Top
	aBox.ClearTextOnFocus = false
	aBox.Parent = aInputFrame

	local aBtn = Instance.new("TextButton")
	aBtn.Size = UDim2.new(1, 0, 0, 42)
	aBtn.BackgroundColor3 = COLOR_CYAN
	aBtn.Text = "📢 BROADCAST GLOBAL ANNOUNCEMENT"
	aBtn.TextColor3 = COLOR_WHITE
	aBtn.Font = Enum.Font.FredokaOne
	aBtn.TextSize = 14
	aBtn.BorderSizePixel = 0
	aBtn.LayoutOrder = 3
	aBtn.Parent = pAnnounce
	makeCorner(aBtn, 8)
	makeStroke(aBtn, COLOR_NAVY_STROKE, 2)

	aBtn.Activated:Connect(function()
		local raw = tostring(aBox.Text or "")
		local clean = string.match(raw, "^%s*(.-)%s*$") or ""
		if #clean == 0 then
			showToast("El mensaje no puede estar vacío.", false)
			return
		end
		playSuccessSound()
		AdminPanelAction:FireServer({
			action = "BroadcastAnnouncement",
			message = clean,
		})
		aBox.Text = ""
	end)

	-- Select initial tab
	selectTab("Codes")
end

-- Hook Server Responses & Events
AdminPanelStatus.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end

	if payload.kind == "Permission" then
		if payload.allowed == true then
			buildAdminUI()
		end
	elseif payload.kind == "Toast" then
		showToast(tostring(payload.message or ""), payload.success == true)
	end
end)

-- Hook MenuEvents Integration
local openAdminEvent = MenuEvents.Get("OpenAdminPanel")
openAdminEvent.Event:Connect(function(action)
	if action == "Open" or action == "LeftButtonSwitch" then
		openPanel()
	elseif action == "Close" then
		closePanel()
	else
		togglePanel()
	end
end)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Admin" then
		closePanel(true)
	end
end)

MenuEvents.MarkReady("Admin", function()
	return isOpen
end)

-- Keyboard shortcuts (F2 to toggle, ESC to close)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F2 and not gameProcessed then
		togglePanel()
	elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closePanel()
	end
end)

-- Initial permission check
AdminPanelAction:FireServer({ action = "CheckPermission" })

local function checkAdminImmediate(): boolean
	if RunService:IsStudio() then return true end
	if AdminBannerConfig.IsAdmin(LocalPlayer.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and LocalPlayer.UserId == game.CreatorId then return true end
	if LocalPlayer.UserId == 767108248 then return true end
	return false
end

if checkAdminImmediate() then
	buildAdminUI()
end

print("[AdminPanelController] V2 Initialized for World 2. Styled cleanly to match the game UI.")
