--!strict
-- AdminPanelController.luau
-- Clean, modern admin mini-panel for authorized users.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15) or ReplicatedStorage
local AdminPanelAction = Remotes:WaitForChild("AdminPanelAction", 15) :: RemoteEvent?
local AdminPanelStatus = Remotes:WaitForChild("AdminPanelStatus", 15) :: RemoteEvent?

if not AdminPanelAction or not AdminPanelStatus then
	return
end

local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local toastFrame: Frame? = nil
local toastText: TextLabel? = nil
local autoRebirthBtn: TextButton? = nil
local autoRebirthModeBtn: TextButton? = nil
local autoRebirthActive = false
local autoRebirthMode = "Threshold"
local isPanelOpen = false

-- Theme Colors
local COLOR_BG = Color3.fromRGB(16, 18, 26)
local COLOR_HEADER = Color3.fromRGB(22, 26, 38)
local COLOR_CARD = Color3.fromRGB(26, 30, 44)
local COLOR_GOLD = Color3.fromRGB(245, 185, 45)
local COLOR_ACCENT = Color3.fromRGB(50, 140, 255)
local COLOR_GREEN = Color3.fromRGB(40, 190, 100)
local COLOR_RED = Color3.fromRGB(210, 50, 50)
local COLOR_TEXT = Color3.fromRGB(240, 240, 250)
local COLOR_SUBTEXT = Color3.fromRGB(160, 165, 180)

local function showToast(message: string, success: boolean)
	if not toastFrame or not toastText then return end
	toastText.Text = message
	toastFrame.BackgroundColor3 = if success then COLOR_GREEN else COLOR_RED
	toastFrame.Visible = true

	local tweenIn = TweenService:Create(toastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 20),
	})
	tweenIn:Play()

	task.delay(3.5, function()
		if toastFrame then
			local tweenOut = TweenService:Create(toastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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

local function makeCorner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makeDraggable(frame: Frame, dragHandle: GuiObject?)
	local handle = dragHandle or frame
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.new()
	local startPos = UDim2.new()

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local function buildAdminUI()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpeedsterAdminMiniPanel"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 9999
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Toast Notification Frame
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "ToastFrame"
	toastFrame.Size = UDim2.new(0, 380, 0, 42)
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, -60)
	toastFrame.BackgroundColor3 = COLOR_GREEN
	toastFrame.BorderSizePixel = 0
	toastFrame.Visible = false
	toastFrame.ZIndex = 100
	toastFrame.Parent = screenGui
	makeCorner(toastFrame, 8)
	makeStroke(toastFrame, Color3.new(1, 1, 1), 1)

	toastText = Instance.new("TextLabel")
	toastText.Name = "ToastText"
	toastText.Size = UDim2.new(1, -20, 1, 0)
	toastText.Position = UDim2.new(0, 10, 0, 0)
	toastText.BackgroundTransparency = 1
	toastText.Font = Enum.Font.FredokaOne
	toastText.TextSize = 14
	toastText.TextColor3 = Color3.new(1, 1, 1)
	toastText.TextXAlignment = Enum.TextXAlignment.Center
	toastText.TextWrapped = true
	toastText.Parent = toastFrame

	-- Floating Toggle Button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "AdminToggleButton"
	toggleBtn.Size = UDim2.new(0, 110, 0, 36)
	toggleBtn.Position = UDim2.new(1, -125, 0, 65)
	toggleBtn.BackgroundColor3 = COLOR_HEADER
	toggleBtn.Text = "👑 ADMIN"
	toggleBtn.TextColor3 = COLOR_GOLD
	toggleBtn.Font = Enum.Font.FredokaOne
	toggleBtn.TextSize = 14
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Active = true
	toggleBtn.Parent = screenGui
	makeCorner(toggleBtn, 18)
	local tStroke = makeStroke(toggleBtn, COLOR_GOLD, 1.5)
	makeDraggable(toggleBtn)

	-- Main Modal Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainModalFrame"
	mainFrame.Size = UDim2.new(0, 560, 0, 430)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundColor3 = COLOR_BG
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Active = true
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	makeCorner(mainFrame, 12)
	makeStroke(mainFrame, COLOR_GOLD, 1.5)

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = COLOR_HEADER
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	makeCorner(header, 12)
	makeDraggable(mainFrame, header)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -60, 0, 26)
	titleLabel.Position = UDim2.new(0, 14, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "👑 PANEL DE CONTROL ADMIN"
	titleLabel.TextColor3 = COLOR_GOLD
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(1, -60, 0, 16)
	subLabel.Position = UDim2.new(0, 14, 0, 28)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "Control de Servidor, Recompensas y Pases Gratis"
	subLabel.TextColor3 = COLOR_SUBTEXT
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 11
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 14
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header
	makeCorner(closeBtn, 6)

	local function togglePanel()
		isPanelOpen = not isPanelOpen
		mainFrame.Visible = isPanelOpen
		if isPanelOpen then
			mainFrame.Position = UDim2.new(0.5, 0, 0.5, 20)
			local tw = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, 0),
			})
			tw:Play()
		end
	end

	toggleBtn.Activated:Connect(togglePanel)
	closeBtn.Activated:Connect(togglePanel)

	-- Navigation Tabs
	local navFrame = Instance.new("Frame")
	navFrame.Name = "NavFrame"
	navFrame.Size = UDim2.new(1, -20, 0, 34)
	navFrame.Position = UDim2.new(0, 10, 0, 54)
	navFrame.BackgroundTransparency = 1
	navFrame.Parent = mainFrame

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.Padding = UDim.new(0, 6)
	navLayout.Parent = navFrame

	local tabContentContainer = Instance.new("Frame")
	tabContentContainer.Name = "TabContainer"
	tabContentContainer.Size = UDim2.new(1, -20, 1, -98)
	tabContentContainer.Position = UDim2.new(0, 10, 0, 92)
	tabContentContainer.BackgroundColor3 = COLOR_CARD
	tabContentContainer.BorderSizePixel = 0
	tabContentContainer.Parent = mainFrame
	makeCorner(tabContentContainer, 8)

	local tabs = {}
	local tabButtons = {}

	local tabNames = {
		{ Id = "Boosts", Label = "⚡ Boosts" },
		{ Id = "Rebirths", Label = "🔄 Rebirths" },
		{ Id = "Stats", Label = "🏆 Stats" },
		{ Id = "Passes", Label = "🎟️ Pases" },
		{ Id = "World2", Label = "🌍 World 2" },
		{ Id = "Announce", Label = "📢 Anuncio" },
	}

	local currentTabId = "Boosts"

	local function selectTab(id: string)
		currentTabId = id
		for tId, page in pairs(tabs) do
			page.Visible = (tId == id)
		end
		for tId, btn in pairs(tabButtons) do
			if tId == id then
				btn.BackgroundColor3 = COLOR_GOLD
				btn.TextColor3 = Color3.fromRGB(20, 20, 30)
			else
				btn.BackgroundColor3 = COLOR_HEADER
				btn.TextColor3 = COLOR_SUBTEXT
			end
		end
	end

	for _, tInfo in ipairs(tabNames) do
		local btn = Instance.new("TextButton")
		btn.Name = "TabBtn_" .. tInfo.Id
		btn.Size = UDim2.new(0, 84, 1, 0)
		btn.BackgroundColor3 = COLOR_HEADER
		btn.Text = tInfo.Label
		btn.TextColor3 = COLOR_SUBTEXT
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 12
		btn.BorderSizePixel = 0
		btn.Parent = navFrame
		makeCorner(btn, 6)

		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. tInfo.Id
		page.Size = UDim2.new(1, -16, 1, -16)
		page.Position = UDim2.new(0, 8, 0, 8)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 4
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
			selectTab(tInfo.Id)
		end)
	end

	-- Helper to create Target Selector (Todos vs Tú Mismo)
	local function createTargetSelector(parent: Instance, layoutOrder: number): () -> string
		local selFrame = Instance.new("Frame")
		selFrame.Name = "TargetSelector"
		selFrame.Size = UDim2.new(1, 0, 0, 36)
		selFrame.BackgroundColor3 = COLOR_HEADER
		selFrame.BorderSizePixel = 0
		selFrame.LayoutOrder = layoutOrder
		selFrame.Parent = parent
		makeCorner(selFrame, 6)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0, 90, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Destinatario:"
		lbl.TextColor3 = COLOR_SUBTEXT
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = selFrame

		local target = "All"
		local btnAll = Instance.new("TextButton")
		btnAll.Size = UDim2.new(0, 160, 0, 26)
		btnAll.Position = UDim2.new(0, 100, 0, 5)
		btnAll.BackgroundColor3 = COLOR_GOLD
		btnAll.Text = "🌐 Todos los Jugadores"
		btnAll.TextColor3 = Color3.fromRGB(20, 20, 30)
		btnAll.Font = Enum.Font.FredokaOne
		btnAll.TextSize = 11
		btnAll.BorderSizePixel = 0
		btnAll.Parent = selFrame
		makeCorner(btnAll, 5)

		local btnSelf = Instance.new("TextButton")
		btnSelf.Size = UDim2.new(0, 130, 0, 26)
		btnSelf.Position = UDim2.new(0, 268, 0, 5)
		btnSelf.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
		btnSelf.Text = "👤 Solo Yo (Admin)"
		btnSelf.TextColor3 = COLOR_SUBTEXT
		btnSelf.Font = Enum.Font.FredokaOne
		btnSelf.TextSize = 11
		btnSelf.BorderSizePixel = 0
		btnSelf.Parent = selFrame
		makeCorner(btnSelf, 5)

		btnAll.Activated:Connect(function()
			target = "All"
			btnAll.BackgroundColor3 = COLOR_GOLD
			btnAll.TextColor3 = Color3.fromRGB(20, 20, 30)
			btnSelf.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
			btnSelf.TextColor3 = COLOR_SUBTEXT
		end)

		btnSelf.Activated:Connect(function()
			target = "Self"
			btnSelf.BackgroundColor3 = COLOR_ACCENT
			btnSelf.TextColor3 = Color3.new(1, 1, 1)
			btnAll.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
			btnAll.TextColor3 = COLOR_SUBTEXT
		end)

		return function()
			return target
		end
	end

	-------------------------------------------------------------------------
	-- TAB 1: BOOSTS SERVIDOR
	-------------------------------------------------------------------------
	local pBoosts = tabs["Boosts"]
	local bDesc = Instance.new("TextLabel")
	bDesc.Size = UDim2.new(1, 0, 0, 30)
	bDesc.BackgroundTransparency = 1
	bDesc.Text = "🚀 Activa 2x Speed y 2x Wins para TODO el servidor:"
	bDesc.TextColor3 = COLOR_TEXT
	bDesc.Font = Enum.Font.FredokaOne
	bDesc.TextSize = 14
	bDesc.TextXAlignment = Enum.TextXAlignment.Left
	bDesc.LayoutOrder = 1
	bDesc.Parent = pBoosts

	local bGrid = Instance.new("Frame")
	bGrid.Size = UDim2.new(1, 0, 0, 75)
	bGrid.BackgroundTransparency = 1
	bGrid.LayoutOrder = 2
	bGrid.Parent = pBoosts

	local durations = {
		{ Mins = 15, Label = "15 Minutos ⚡" },
		{ Mins = 30, Label = "30 Minutos ⚡" },
		{ Mins = 60, Label = "1 Hora ⚡" },
		{ Mins = 120, Label = "2 Horas ⚡" },
	}

	for i, d in ipairs(durations) do
		local x = ((i - 1) % 2) * 260
		local y = math.floor((i - 1) / 2) * 38
		local bBtn = Instance.new("TextButton")
		bBtn.Size = UDim2.new(0, 250, 0, 32)
		bBtn.Position = UDim2.new(0, x, 0, y)
		bBtn.BackgroundColor3 = COLOR_HEADER
		bBtn.Text = d.Label
		bBtn.TextColor3 = COLOR_GOLD
		bBtn.Font = Enum.Font.FredokaOne
		bBtn.TextSize = 13
		bBtn.BorderSizePixel = 0
		bBtn.Parent = bGrid
		makeCorner(bBtn, 6)
		makeStroke(bBtn, COLOR_GOLD, 1)

		bBtn.Activated:Connect(function()
			AdminPanelAction:FireServer({
				action = "ServerBoost",
				minutes = d.Mins,
			})
		end)
	end

	-------------------------------------------------------------------------
	-- TAB 2: REBIRTHS & AUTO REBIRTH
	-------------------------------------------------------------------------
	local pRebirths = tabs["Rebirths"]
	local getRebirthTarget = createTargetSelector(pRebirths, 1)

	local rTitle = Instance.new("TextLabel")
	rTitle.Size = UDim2.new(1, 0, 0, 24)
	rTitle.BackgroundTransparency = 1
	rTitle.Text = "🎁 Otorgar Rebirths:"
	rTitle.TextColor3 = COLOR_TEXT
	rTitle.Font = Enum.Font.FredokaOne
	rTitle.TextSize = 13
	rTitle.TextXAlignment = Enum.TextXAlignment.Left
	rTitle.LayoutOrder = 2
	rTitle.Parent = pRebirths

	local rQuickFrame = Instance.new("Frame")
	rQuickFrame.Size = UDim2.new(1, 0, 0, 32)
	rQuickFrame.BackgroundTransparency = 1
	rQuickFrame.LayoutOrder = 3
	rQuickFrame.Parent = pRebirths

	local rLayout = Instance.new("UIListLayout")
	rLayout.FillDirection = Enum.FillDirection.Horizontal
	rLayout.Padding = UDim.new(0, 8)
	rLayout.Parent = rQuickFrame

	local rAmounts = { 1, 2, 5, 10, 50, 100 }
	for _, amt in ipairs(rAmounts) do
		local qBtn = Instance.new("TextButton")
		qBtn.Size = UDim2.new(0, 75, 1, 0)
		qBtn.BackgroundColor3 = COLOR_HEADER
		qBtn.Text = "+" .. tostring(amt)
		qBtn.TextColor3 = COLOR_GOLD
		qBtn.Font = Enum.Font.FredokaOne
		qBtn.TextSize = 13
		qBtn.BorderSizePixel = 0
		qBtn.Parent = rQuickFrame
		makeCorner(qBtn, 6)

		qBtn.Activated:Connect(function()
			AdminPanelAction:FireServer({
				action = "GiveRebirths",
				target = getRebirthTarget(),
				amount = amt,
			})
		end)
	end

	-- Auto Rebirth & Reset Section
	local div = Instance.new("Frame")
	div.Size = UDim2.new(1, 0, 0, 1)
	div.BackgroundColor3 = Color3.fromRGB(40, 45, 65)
	div.BorderSizePixel = 0
	div.LayoutOrder = 4
	div.Parent = pRebirths

	local autoTitle = Instance.new("TextLabel")
	autoTitle.Size = UDim2.new(1, 0, 0, 22)
	autoTitle.BackgroundTransparency = 1
	autoTitle.Text = "⚡ Auto Rebirth (Reinicia stats a 1 y da Rebirths):"
	autoTitle.TextColor3 = COLOR_GOLD
	autoTitle.Font = Enum.Font.FredokaOne
	autoTitle.TextSize = 13
	autoTitle.TextXAlignment = Enum.TextXAlignment.Left
	autoTitle.LayoutOrder = 5
	autoTitle.Parent = pRebirths

	local autoControlFrame = Instance.new("Frame")
	autoControlFrame.Size = UDim2.new(1, 0, 0, 36)
	autoControlFrame.BackgroundTransparency = 1
	autoControlFrame.LayoutOrder = 6
	autoControlFrame.Parent = pRebirths

	autoRebirthBtn = Instance.new("TextButton")
	autoRebirthBtn.Size = UDim2.new(0, 180, 1, 0)
	autoRebirthBtn.Position = UDim2.new(0, 0, 0, 0)
	autoRebirthBtn.BackgroundColor3 = COLOR_RED
	autoRebirthBtn.Text = "AUTO REBIRTH: OFF"
	autoRebirthBtn.TextColor3 = Color3.new(1, 1, 1)
	autoRebirthBtn.Font = Enum.Font.FredokaOne
	autoRebirthBtn.TextSize = 12
	autoRebirthBtn.BorderSizePixel = 0
	autoRebirthBtn.Parent = autoControlFrame
	makeCorner(autoRebirthBtn, 6)

	autoRebirthModeBtn = Instance.new("TextButton")
	autoRebirthModeBtn.Size = UDim2.new(0, 190, 1, 0)
	autoRebirthModeBtn.Position = UDim2.new(0, 190, 0, 0)
	autoRebirthModeBtn.BackgroundColor3 = COLOR_HEADER
	autoRebirthModeBtn.Text = "Modo: Al Cumplir Nivel"
	autoRebirthModeBtn.TextColor3 = COLOR_SUBTEXT
	autoRebirthModeBtn.Font = Enum.Font.GothamBold
	autoRebirthModeBtn.TextSize = 11
	autoRebirthModeBtn.BorderSizePixel = 0
	autoRebirthModeBtn.Parent = autoControlFrame
	makeCorner(autoRebirthModeBtn, 6)

	local manualResetBtn = Instance.new("TextButton")
	manualResetBtn.Size = UDim2.new(0, 130, 1, 0)
	manualResetBtn.Position = UDim2.new(0, 390, 0, 0)
	manualResetBtn.BackgroundColor3 = COLOR_ACCENT
	manualResetBtn.Text = "🔄 1 Rebirth Ahora"
	manualResetBtn.TextColor3 = Color3.new(1, 1, 1)
	manualResetBtn.Font = Enum.Font.FredokaOne
	manualResetBtn.TextSize = 11
	manualResetBtn.BorderSizePixel = 0
	manualResetBtn.Parent = autoControlFrame
	makeCorner(manualResetBtn, 6)

	autoRebirthBtn.Activated:Connect(function()
		autoRebirthActive = not autoRebirthActive
		autoRebirthBtn.BackgroundColor3 = if autoRebirthActive then COLOR_GREEN else COLOR_RED
		autoRebirthBtn.Text = if autoRebirthActive then "AUTO REBIRTH: ON" else "AUTO REBIRTH: OFF"
		AdminPanelAction:FireServer({
			action = "AutoRebirth",
			enabled = autoRebirthActive,
			mode = autoRebirthMode,
		})
	end)

	autoRebirthModeBtn.Activated:Connect(function()
		autoRebirthMode = if autoRebirthMode == "Threshold" then "Forced" else "Threshold"
		autoRebirthModeBtn.Text = if autoRebirthMode == "Forced" then "Modo: Rápido (cada 3s)" else "Modo: Al Cumplir Nivel"
		if autoRebirthActive then
			AdminPanelAction:FireServer({
				action = "AutoRebirth",
				enabled = true,
				mode = autoRebirthMode,
			})
		end
	end)

	manualResetBtn.Activated:Connect(function()
		AdminPanelAction:FireServer({ action = "ManualRebirthReset" })
	end)

	-------------------------------------------------------------------------
	-- TAB 3: SPEED & WINS
	-------------------------------------------------------------------------
	local pStats = tabs["Stats"]
	local getStatsTarget = createTargetSelector(pStats, 1)

	local statType = "Speed"
	local statTypeFrame = Instance.new("Frame")
	statTypeFrame.Size = UDim2.new(1, 0, 0, 32)
	statTypeFrame.BackgroundTransparency = 1
	statTypeFrame.LayoutOrder = 2
	statTypeFrame.Parent = pStats

	local btnSpeed = Instance.new("TextButton")
	btnSpeed.Size = UDim2.new(0, 150, 1, 0)
	btnSpeed.Position = UDim2.new(0, 0, 0, 0)
	btnSpeed.BackgroundColor3 = COLOR_GOLD
	btnSpeed.Text = "🏃 Velocidad (Speed)"
	btnSpeed.TextColor3 = Color3.fromRGB(20, 20, 30)
	btnSpeed.Font = Enum.Font.FredokaOne
	btnSpeed.TextSize = 12
	btnSpeed.BorderSizePixel = 0
	btnSpeed.Parent = statTypeFrame
	makeCorner(btnSpeed, 6)

	local btnWins = Instance.new("TextButton")
	btnWins.Size = UDim2.new(0, 150, 1, 0)
	btnWins.Position = UDim2.new(0, 160, 0, 0)
	btnWins.BackgroundColor3 = COLOR_HEADER
	btnWins.Text = "🏆 Victorias (Wins)"
	btnWins.TextColor3 = COLOR_SUBTEXT
	btnWins.Font = Enum.Font.FredokaOne
	btnWins.TextSize = 12
	btnWins.BorderSizePixel = 0
	btnWins.Parent = statTypeFrame
	makeCorner(btnWins, 6)

	btnSpeed.Activated:Connect(function()
		statType = "Speed"
		btnSpeed.BackgroundColor3 = COLOR_GOLD
		btnSpeed.TextColor3 = Color3.fromRGB(20, 20, 30)
		btnWins.BackgroundColor3 = COLOR_HEADER
		btnWins.TextColor3 = COLOR_SUBTEXT
	end)

	btnWins.Activated:Connect(function()
		statType = "Wins"
		btnWins.BackgroundColor3 = COLOR_ACCENT
		btnWins.TextColor3 = Color3.new(1, 1, 1)
		btnSpeed.BackgroundColor3 = COLOR_HEADER
		btnSpeed.TextColor3 = COLOR_SUBTEXT
	end)

	local sQuickFrame = Instance.new("Frame")
	sQuickFrame.Size = UDim2.new(1, 0, 0, 75)
	sQuickFrame.BackgroundTransparency = 1
	sQuickFrame.LayoutOrder = 3
	sQuickFrame.Parent = pStats

	local statQuickAmounts = {
		{ Label = "+100,000", Amt = 100000 },
		{ Label = "+1,000,000 (1M)", Amt = 1000000 },
		{ Label = "+10,000,000 (10M)", Amt = 10000000 },
		{ Label = "+100,000,000 (100M)", Amt = 100000000 },
		{ Label = "+1,000,000,000 (1B)", Amt = 1000000000 },
		{ Label = "+10,000,000,000 (10B)", Amt = 10000000000 },
	}

	for i, q in ipairs(statQuickAmounts) do
		local x = ((i - 1) % 3) * 175
		local y = math.floor((i - 1) / 3) * 38
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 165, 0, 32)
		btn.Position = UDim2.new(0, x, 0, y)
		btn.BackgroundColor3 = COLOR_HEADER
		btn.Text = q.Label
		btn.TextColor3 = COLOR_GOLD
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 12
		btn.BorderSizePixel = 0
		btn.Parent = sQuickFrame
		makeCorner(btn, 6)

		btn.Activated:Connect(function()
			AdminPanelAction:FireServer({
				action = "GiveStats",
				target = getStatsTarget(),
				stat = statType,
				amount = q.Amt,
			})
		end)
	end

	-------------------------------------------------------------------------
	-- TAB 4: PASES GRATIS (ACTIVAR / DESACTIVAR)
	-------------------------------------------------------------------------
	local pPasses = tabs["Passes"]
	local getPassTarget = createTargetSelector(pPasses, 1)

	-- Batch row: Todos los pases
	local batchFrame = Instance.new("Frame")
	batchFrame.Size = UDim2.new(1, 0, 0, 32)
	batchFrame.BackgroundTransparency = 1
	batchFrame.LayoutOrder = 2
	batchFrame.Parent = pPasses

	local btnAllPassesOn = Instance.new("TextButton")
	btnAllPassesOn.Size = UDim2.new(0, 250, 1, 0)
	btnAllPassesOn.Position = UDim2.new(0, 0, 0, 0)
	btnAllPassesOn.BackgroundColor3 = COLOR_GREEN
	btnAllPassesOn.Text = "✨ ACTIVAR TODOS LOS PASES"
	btnAllPassesOn.TextColor3 = Color3.new(1, 1, 1)
	btnAllPassesOn.Font = Enum.Font.FredokaOne
	btnAllPassesOn.TextSize = 12
	btnAllPassesOn.BorderSizePixel = 0
	btnAllPassesOn.Parent = batchFrame
	makeCorner(btnAllPassesOn, 6)

	local btnAllPassesOff = Instance.new("TextButton")
	btnAllPassesOff.Size = UDim2.new(0, 250, 1, 0)
	btnAllPassesOff.Position = UDim2.new(0, 260, 0, 0)
	btnAllPassesOff.BackgroundColor3 = COLOR_RED
	btnAllPassesOff.Text = "❌ DESACTIVAR TODOS"
	btnAllPassesOff.TextColor3 = Color3.new(1, 1, 1)
	btnAllPassesOff.Font = Enum.Font.FredokaOne
	btnAllPassesOff.TextSize = 12
	btnAllPassesOff.BorderSizePixel = 0
	btnAllPassesOff.Parent = batchFrame
	makeCorner(btnAllPassesOff, 6)

	btnAllPassesOn.Activated:Connect(function()
		AdminPanelAction:FireServer({
			action = "TogglePass",
			target = getPassTarget(),
			pass = "All",
			enabled = true,
		})
	end)

	btnAllPassesOff.Activated:Connect(function()
		AdminPanelAction:FireServer({
			action = "TogglePass",
			target = getPassTarget(),
			pass = "All",
			enabled = false,
		})
	end)

	local passList = {
		{ Id = "VIP", Name = "👑 VIP", Desc = "Tag VIP, +100% ganancias Speed & Wins" },
		{ Id = "Flight", Name = "🦅 Vuelo (Flight)", Desc = "Vuelo libre presionando doble salto / espacio" },
		{ Id = "TwoXSpeed", Name = "⚡ 2x Speed Permanente", Desc = "Multiplicador de velocidad x2 para siempre" },
		{ Id = "TwoXVictory", Name = "🏆 2x Wins Permanente", Desc = "Multiplicador de victorias x2 y Double Wins Pad" },
		{ Id = "InfiniteRevives", Name = "🛡️ Infinite Revives", Desc = "Revive ilimitado sin costo al caer" },
		{ Id = "DarkZonic", Name = "🦔 Dark Zonic (Skin)", Desc = "Skin legendaria exclusiva de Dark Zonic" },
	}

	for i, pass in ipairs(passList) do
		local pRow = Instance.new("Frame")
		pRow.Size = UDim2.new(1, 0, 0, 36)
		pRow.BackgroundColor3 = COLOR_HEADER
		pRow.BorderSizePixel = 0
		pRow.LayoutOrder = 10 + i
		pRow.Parent = pPasses
		makeCorner(pRow, 6)

		local pLabel = Instance.new("TextLabel")
		pLabel.Size = UDim2.new(1, -210, 1, 0)
		pLabel.Position = UDim2.new(0, 10, 0, 0)
		pLabel.BackgroundTransparency = 1
		pLabel.Text = string.format("<b>%s</b> <font color=\"rgb(160,165,180)\">(%s)</font>", pass.Name, pass.Desc)
		pLabel.RichText = true
		pLabel.TextColor3 = COLOR_TEXT
		pLabel.Font = Enum.Font.GothamBold
		pLabel.TextSize = 11
		pLabel.TextXAlignment = Enum.TextXAlignment.Left
		pLabel.TextTruncate = Enum.TextTruncate.AtEnd
		pLabel.Parent = pRow

		local onBtn = Instance.new("TextButton")
		onBtn.Size = UDim2.new(0, 90, 0, 26)
		onBtn.Position = UDim2.new(1, -195, 0, 5)
		onBtn.BackgroundColor3 = COLOR_GREEN
		onBtn.Text = "ACTIVAR"
		onBtn.TextColor3 = Color3.new(1, 1, 1)
		onBtn.Font = Enum.Font.FredokaOne
		onBtn.TextSize = 11
		onBtn.BorderSizePixel = 0
		onBtn.Parent = pRow
		makeCorner(onBtn, 5)

		local offBtn = Instance.new("TextButton")
		offBtn.Size = UDim2.new(0, 90, 0, 26)
		offBtn.Position = UDim2.new(1, -100, 0, 5)
		offBtn.BackgroundColor3 = COLOR_RED
		offBtn.Text = "DESACTIVAR"
		offBtn.TextColor3 = Color3.new(1, 1, 1)
		offBtn.Font = Enum.Font.FredokaOne
		offBtn.TextSize = 11
		offBtn.BorderSizePixel = 0
		offBtn.Parent = pRow
		makeCorner(offBtn, 5)

		onBtn.Activated:Connect(function()
			AdminPanelAction:FireServer({
				action = "TogglePass",
				target = getPassTarget(),
				pass = pass.Id,
				enabled = true,
			})
		end)

		offBtn.Activated:Connect(function()
			AdminPanelAction:FireServer({
				action = "TogglePass",
				target = getPassTarget(),
				pass = pass.Id,
				enabled = false,
			})
		end)
	end

	-------------------------------------------------------------------------
	-- TAB 5: WORLD 2 (BYPASS & TELEPORT)
	-------------------------------------------------------------------------
	local pWorld2 = tabs["World2"]
	local getW2Target = createTargetSelector(pWorld2, 1)

	local w2Desc = Instance.new("TextLabel")
	w2Desc.Size = UDim2.new(1, 0, 0, 36)
	w2Desc.BackgroundTransparency = 1
	w2Desc.Text = "🌍 Acceso a World 2 sin requerir Rebirths ni Niveles:\nComo admin tienes pase directo garantizado."
	w2Desc.TextColor3 = COLOR_TEXT
	w2Desc.Font = Enum.Font.FredokaOne
	w2Desc.TextSize = 13
	w2Desc.TextXAlignment = Enum.TextXAlignment.Left
	w2Desc.LayoutOrder = 2
	w2Desc.Parent = pWorld2

	local w2BtnFrame = Instance.new("Frame")
	w2BtnFrame.Size = UDim2.new(1, 0, 0, 75)
	w2BtnFrame.BackgroundTransparency = 1
	w2BtnFrame.LayoutOrder = 3
	w2BtnFrame.Parent = pWorld2

	local btnUnlockW2 = Instance.new("TextButton")
	btnUnlockW2.Size = UDim2.new(0, 250, 0, 34)
	btnUnlockW2.Position = UDim2.new(0, 0, 0, 0)
	btnUnlockW2.BackgroundColor3 = COLOR_GREEN
	btnUnlockW2.Text = "🔓 DESBLOQUEAR WORLD 2 (Permanente)"
	btnUnlockW2.TextColor3 = Color3.new(1, 1, 1)
	btnUnlockW2.Font = Enum.Font.FredokaOne
	btnUnlockW2.TextSize = 11
	btnUnlockW2.BorderSizePixel = 0
	btnUnlockW2.Parent = w2BtnFrame
	makeCorner(btnUnlockW2, 6)

	local btnLockW2 = Instance.new("TextButton")
	btnLockW2.Size = UDim2.new(0, 250, 0, 34)
	btnLockW2.Position = UDim2.new(0, 260, 0, 0)
	btnLockW2.BackgroundColor3 = COLOR_RED
	btnLockW2.Text = "🔒 BLOQUEAR WORLD 2"
	btnLockW2.TextColor3 = Color3.new(1, 1, 1)
	btnLockW2.Font = Enum.Font.FredokaOne
	btnLockW2.TextSize = 11
	btnLockW2.BorderSizePixel = 0
	btnLockW2.Parent = w2BtnFrame
	makeCorner(btnLockW2, 6)

	local btnTeleportW2 = Instance.new("TextButton")
	btnTeleportW2.Size = UDim2.new(0, 510, 0, 34)
	btnTeleportW2.Position = UDim2.new(0, 0, 0, 40)
	btnTeleportW2.BackgroundColor3 = COLOR_ACCENT
	btnTeleportW2.Text = "🚀 TELETRANSPORTAR A WORLD 2 AHORA"
	btnTeleportW2.TextColor3 = Color3.new(1, 1, 1)
	btnTeleportW2.Font = Enum.Font.FredokaOne
	btnTeleportW2.TextSize = 13
	btnTeleportW2.BorderSizePixel = 0
	btnTeleportW2.Parent = w2BtnFrame
	makeCorner(btnTeleportW2, 6)

	btnUnlockW2.Activated:Connect(function()
		AdminPanelAction:FireServer({
			action = "UnlockWorld2",
			target = getW2Target(),
			enabled = true,
		})
	end)

	btnLockW2.Activated:Connect(function()
		AdminPanelAction:FireServer({
			action = "UnlockWorld2",
			target = getW2Target(),
			enabled = false,
		})
	end)

	btnTeleportW2.Activated:Connect(function()
		AdminPanelAction:FireServer({ action = "TeleportWorld2" })
	end)

	-------------------------------------------------------------------------
	-- TAB 6: ANUNCIO GLOBAL
	-------------------------------------------------------------------------
	local pAnnounce = tabs["Announce"]

	local annDesc = Instance.new("TextLabel")
	annDesc.Size = UDim2.new(1, 0, 0, 26)
	annDesc.BackgroundTransparency = 1
	annDesc.Text = "📢 Transmitir un Anuncio Global en la pantalla de todos:"
	annDesc.TextColor3 = COLOR_TEXT
	annDesc.Font = Enum.Font.FredokaOne
	annDesc.TextSize = 13
	annDesc.TextXAlignment = Enum.TextXAlignment.Left
	annDesc.LayoutOrder = 1
	annDesc.Parent = pAnnounce

	local annBox = Instance.new("TextBox")
	annBox.Size = UDim2.new(1, 0, 0, 60)
	annBox.BackgroundColor3 = COLOR_HEADER
	annBox.PlaceholderText = "Escribe tu anuncio aquí (máx. 250 caracteres)..."
	annBox.PlaceholderColor3 = COLOR_SUBTEXT
	annBox.Text = ""
	annBox.TextColor3 = COLOR_TEXT
	annBox.Font = Enum.Font.FredokaOne
	annBox.TextSize = 13
	annBox.TextXAlignment = Enum.TextXAlignment.Left
	annBox.TextYAlignment = Enum.TextYAlignment.Top
	annBox.TextWrapped = true
	annBox.ClearTextOnFocus = false
	annBox.BorderSizePixel = 0
	annBox.LayoutOrder = 2
	annBox.Parent = pAnnounce
	makeCorner(annBox, 6)
	local annPadding = Instance.new("UIPadding")
	annPadding.PaddingTop = UDim.new(0, 8)
	annPadding.PaddingLeft = UDim.new(0, 10)
	annPadding.PaddingRight = UDim.new(0, 10)
	annPadding.Parent = annBox

	local sendAnnounceBtn = Instance.new("TextButton")
	sendAnnounceBtn.Size = UDim2.new(1, 0, 0, 36)
	sendAnnounceBtn.BackgroundColor3 = COLOR_GOLD
	sendAnnounceBtn.Text = "📢 ENVIAR ANUNCIO GLOBAL"
	sendAnnounceBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
	sendAnnounceBtn.Font = Enum.Font.FredokaOne
	sendAnnounceBtn.TextSize = 13
	sendAnnounceBtn.BorderSizePixel = 0
	sendAnnounceBtn.LayoutOrder = 3
	sendAnnounceBtn.Parent = pAnnounce
	makeCorner(sendAnnounceBtn, 6)

	sendAnnounceBtn.Activated:Connect(function()
		local text = annBox.Text
		if #text > 0 then
			AdminPanelAction:FireServer({
				action = "BroadcastAnnouncement",
				message = text,
			})
			annBox.Text = ""
		end
	end)

	-- Select default tab
	selectTab("Boosts")

	-- Hotkey F4 toggle
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F4 then
			togglePanel()
		end
	end)
end

-- Server status listener
AdminPanelStatus.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end

	if payload.kind == "Permission" and payload.allowed == true then
		buildAdminUI()
		if payload.autoRebirthEnabled ~= nil then
			autoRebirthActive = payload.autoRebirthEnabled
			if autoRebirthBtn then
				autoRebirthBtn.BackgroundColor3 = if autoRebirthActive then COLOR_GREEN else COLOR_RED
				autoRebirthBtn.Text = if autoRebirthActive then "AUTO REBIRTH: ON" else "AUTO REBIRTH: OFF"
			end
		end
		if payload.autoRebirthMode then
			autoRebirthMode = payload.autoRebirthMode
			if autoRebirthModeBtn then
				autoRebirthModeBtn.Text = if autoRebirthMode == "Forced" then "Modo: Rápido (cada 3s)" else "Modo: Al Cumplir Nivel"
			end
		end

	elseif payload.kind == "Toast" then
		showToast(tostring(payload.message or ""), payload.success == true)
	end
end)

-- Initial check
AdminPanelAction:FireServer({ action = "CheckPermission" })

print("[AdminPanelController] Initialized and verified.")
