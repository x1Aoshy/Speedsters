-- ConsoleUiScale & Universal Gamepad UI Navigation Manager
-- Handles TV safe areas, gamepad selection boxes, virtual cursor, LeftSideBar HUD navigation, and Gamepad Hints bar.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local isConsole = GuiService:IsTenFootInterface()

-- 1. Enable Gamepad Navigation Flags
GuiService.AutoSelectGuiEnabled = true

local function isGamepadActive(): boolean
	return isConsole or (UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil)
end

-- Disable virtual cursor during character movement so it never overlaps with ShiftLock
local function disableVirtualCursor()
	pcall(function()
		local GamepadService = game:GetService("GamepadService")
		if GamepadService and GamepadService.DisableGamepadCursor then
			GamepadService:DisableGamepadCursor()
		end
	end)
end

-- 2. Console TV Insets & Auto-Selectable Configuration
local function configureGui(gui: Instance)
	if not gui:IsA("ScreenGui") then return end
	if isConsole then
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.ClipToDeviceSafeArea = true
	end

	local function makeSelectable(desc: Instance)
		if desc:IsA("GuiButton") or desc:IsA("ScrollingFrame") then
			desc.Selectable = true
		end
	end

	for _, desc in ipairs(gui:GetDescendants()) do
		makeSelectable(desc)
	end
	gui.DescendantAdded:Connect(makeSelectable)
end

for _, gui in ipairs(playerGui:GetChildren()) do
	configureGui(gui)
end
playerGui.ChildAdded:Connect(configureGui)

-- 3. Universal Modal Tracking & Gamepad Navigation
local MANAGED_MENUS = {
	["Update Logs"] = true,
	["Settings"] = true,
	["Shop"] = true,
	["Rebirth"] = true,
	["Evolve"] = true,
	["Abilities"] = true,
	["DailyReward"] = true,
	["TimeGift"] = true,
	["Worlds"] = true,
	["StageTeleport"] = true,
	["RankRewardGui"] = true,
	["Backpack"] = true,
	["Index"] = true,
	["Treadmill"] = true,
}

local activeMenuGui: ScreenGui? = nil
local trackedMenus = {}
local menuSerial = 0
local ACTION_CONSOLE_BACK = "ConsoleMenuClose_ButtonB_Universal"
local ACTION_FOCUS_SIDEBAR = "ConsoleFocus_LeftSideBar_Universal"

local function isVisibleButton(button)
	if not button or not button:IsA("GuiButton") or not button.Active then return false end
	local current = button
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return current == playerGui
end

local function findCloseOrPrimaryButton(gui: ScreenGui): GuiButton?
	local closeBtn: GuiButton? = nil
	local firstBtn: GuiButton? = nil

	for _, desc in ipairs(gui:GetDescendants()) do
		if isVisibleButton(desc) then
			local lowerName = desc.Name:lower()
			if lowerName:find("close") or lowerName:find("exit") or desc.Name == "X" then
				return desc
			end
			if not firstBtn then
				firstBtn = desc
			end
		end
	end
	return closeBtn or firstBtn
end

local function isObjectInSidebar(obj: Instance?): boolean
	if not obj then return false end
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local leftBar = mainhud and mainhud:FindFirstChild("LeftSideBar", true)
	if leftBar and obj:IsDescendantOf(leftBar) then
		return true
	end
	return false
end

local updateGamepadHints: () -> () = function() end

local function closeActiveMenu()
	if not activeMenuGui then return end
	local targetGui = activeMenuGui
	activeMenuGui = nil

	pcall(function()
		local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
		MenuEvents.CloseAll:Fire()
	end)

	if targetGui and targetGui.Parent then
		targetGui.Enabled = false
	end

	pcall(function()
		ContextActionService:UnbindAction(ACTION_CONSOLE_BACK)
	end)

	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(targetGui) then
		GuiService.SelectedObject = nil
	end

	GuiService.GuiNavigationEnabled = false
	disableVirtualCursor()

	task.defer(updateGamepadHints)
end

local function onButtonBInput(actionName, inputState, inputObject)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if activeMenuGui and activeMenuGui.Enabled then
			closeActiveMenu()
			return Enum.ContextActionResult.Sink
		end

		if isObjectInSidebar(GuiService.SelectedObject) then
			GuiService.SelectedObject = nil
			GuiService.GuiNavigationEnabled = false
			disableVirtualCursor()
			task.defer(updateGamepadHints)
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

local function handleMenuOpened(gui: ScreenGui)
	if not gui.Parent or not gui.Enabled or not findCloseOrPrimaryButton(gui) then return end
	activeMenuGui = gui
	GuiService.GuiNavigationEnabled = isGamepadActive()

	-- 1. Release ShiftLock so camera doesn't lock cursor during modal navigation
	pcall(function()
		local shiftLockEvent = playerScripts:FindFirstChild("ShiftLockControlEvent")
		if shiftLockEvent then
			shiftLockEvent:Fire("Disable")
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)

	-- 2. Bind ButtonB to close the modal
	pcall(function()
		ContextActionService:BindActionAtPriority(
			ACTION_CONSOLE_BACK,
			onButtonBInput,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonB
		)
	end)

	-- 3. On Gamepad / Console: set SelectedObject to close button or primary button
	if isGamepadActive() then
		task.defer(function()
			if gui.Parent and gui.Enabled and not GuiService.MenuIsOpen then
				local button = findCloseOrPrimaryButton(gui)
				if button then
					button.Selectable = true
					GuiService.SelectedObject = button
				end
				updateGamepadHints()
			end
		end)
	end
end

local function handleMenuClosed(gui: ScreenGui)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if activeMenuGui ~= gui then return end
	activeMenuGui = nil
	ContextActionService:UnbindAction(ACTION_CONSOLE_BACK)
	GuiService.GuiNavigationEnabled = false
	disableVirtualCursor()
	local nextGui, newest = nil, -1
	for candidate, state in trackedMenus do
		if candidate ~= gui and candidate.Parent and candidate.Enabled and findCloseOrPrimaryButton(candidate) and state.serial > newest then
			nextGui, newest = candidate, state.serial
		end
	end
	if nextGui then handleMenuOpened(nextGui) end
	task.defer(updateGamepadHints)
end

local function hookMenu(gui: Instance)
	if not gui:IsA("ScreenGui") or not MANAGED_MENUS[gui.Name] or trackedMenus[gui] then return end
	local state = { open = false, serial = 0, queued = false, connections = {}, objects = {} }
	trackedMenus[gui] = state
	local function sync()
		state.queued = false
		if not trackedMenus[gui] then return end
		local target = gui.Enabled and findCloseOrPrimaryButton(gui)
		local isOpen = target ~= nil and target ~= false
		if isOpen and not state.open then
			state.open = true
			menuSerial += 1; state.serial = menuSerial
			handleMenuOpened(gui)
		elseif not isOpen then
			state.open = false
			handleMenuClosed(gui)
		elseif activeMenuGui == gui and isGamepadActive() and not GuiService.MenuIsOpen then
			local selected = GuiService.SelectedObject
			if not isVisibleButton(selected) or not selected:IsDescendantOf(gui) then
				target.Selectable = true
				GuiService.SelectedObject = target
			end
		end
	end
	local function scheduleSync()
		if state.queued then return end
		state.queued = true
		task.defer(sync)
	end
	local function observe(object)
		if not object:IsA("GuiObject") or state.objects[object] then return end
		local connections = { object:GetPropertyChangedSignal("Visible"):Connect(scheduleSync) }
		if object:IsA("GuiButton") then table.insert(connections, object:GetPropertyChangedSignal("Active"):Connect(scheduleSync)) end
		state.objects[object] = connections
	end
	local function forget(object)
		for _, connection in state.objects[object] or {} do connection:Disconnect() end
		state.objects[object] = nil
		scheduleSync()
	end
	for _, object in gui:GetDescendants() do observe(object) end
	table.insert(state.connections, gui:GetPropertyChangedSignal("Enabled"):Connect(scheduleSync))
	table.insert(state.connections, gui.DescendantAdded:Connect(function(object) observe(object); scheduleSync() end))
	table.insert(state.connections, gui.DescendantRemoving:Connect(forget))
	table.insert(state.connections, GuiService.MenuClosed:Connect(scheduleSync))
	table.insert(state.connections, gui.Destroying:Connect(function()
		trackedMenus[gui] = nil
		for _, connection in state.connections do connection:Disconnect() end
		for _, connections in state.objects do
			for _, connection in connections do connection:Disconnect() end
		end
		table.clear(state.objects)
		handleMenuClosed(gui)
	end))
	scheduleSync()
end

for _, child in ipairs(playerGui:GetChildren()) do
	hookMenu(child)
end
playerGui.ChildAdded:Connect(hookMenu)

-- 4. LeftSideBar HUD Focus with D-Pad Up or Select
local function focusLeftSideBar()
	if GuiService.MenuIsOpen then return end
	if activeMenuGui and activeMenuGui.Enabled then
		return
	end

	local mainhud = playerGui:FindFirstChild("Mainhud")
	local leftBar = mainhud and mainhud:FindFirstChild("LeftSideBar", true)
	if not leftBar then return end

	if isObjectInSidebar(GuiService.SelectedObject) then
		GuiService.SelectedObject = nil
		GuiService.GuiNavigationEnabled = false
		disableVirtualCursor()
		updateGamepadHints()
		return
	end

	local targetBtn: GuiButton? = leftBar:FindFirstChild("Shop") :: any
	if not isVisibleButton(targetBtn) then
		targetBtn = nil
		for _, child in ipairs(leftBar:GetChildren()) do
			if isVisibleButton(child) then
				targetBtn = child
				break
			end
		end
	end

	if targetBtn then
		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)

		GuiService.GuiNavigationEnabled = true
		targetBtn.Selectable = true
		GuiService.SelectedObject = targetBtn

		pcall(function()
			ContextActionService:BindActionAtPriority(
				ACTION_CONSOLE_BACK,
				onButtonBInput,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.KeyCode.ButtonB
			)
		end)

		updateGamepadHints()
	end
end

local function onFocusSidebarInput(actionName, inputState, inputObject)
	if GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		if not activeMenuGui or not activeMenuGui.Enabled then
			focusLeftSideBar()
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

pcall(function()
	ContextActionService:BindActionAtPriority(
		ACTION_FOCUS_SIDEBAR,
		onFocusSidebarInput,
		false,
		Enum.ContextActionPriority.Medium.Value + 5,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.ButtonSelect
	)
end)

-- 5. Gamepad On-Screen Indications UI (HUD Hints Bar)
local hintsGui = Instance.new("ScreenGui")
hintsGui.Name = "ConsoleGamepadHints"
hintsGui.DisplayOrder = 100
hintsGui.ResetOnSpawn = false
hintsGui.IgnoreGuiInset = true

local hintsContainer = Instance.new("Frame")
hintsContainer.Name = "HintsContainer"
hintsContainer.AnchorPoint = Vector2.new(0.5, 1)
hintsContainer.Position = UDim2.new(0.5, 0, 1, -10)
hintsContainer.Size = UDim2.new(0, 0, 0, 26)
hintsContainer.AutomaticSize = Enum.AutomaticSize.X
hintsContainer.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
hintsContainer.BackgroundTransparency = 0.25
hintsContainer.Parent = hintsGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintsContainer

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 75, 110)
stroke.Thickness = 1.2
stroke.Transparency = 0.3
stroke.Parent = hintsContainer

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 4)
padding.Parent = hintsContainer

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 12)
layout.Parent = hintsContainer

local function createHintLabel(order: number, iconText: string, actionText: string)
	local holder = Instance.new("Frame")
	holder.Name = "Hint_" .. order
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0, 0, 1, 0)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Parent = hintsContainer

	local hLayout = Instance.new("UIListLayout")
	hLayout.FillDirection = Enum.FillDirection.Horizontal
	hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hLayout.Padding = UDim.new(0, 5)
	hLayout.Parent = holder

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Color3.fromRGB(35, 45, 68)
	badge.TextColor3 = Color3.fromRGB(245, 245, 255)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 11
	badge.Text = iconText
	badge.Size = UDim2.new(0, 0, 0, 18)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Parent = holder

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 4)
	bCorner.Parent = badge

	local bPad = Instance.new("UIPadding")
	bPad.PaddingLeft = UDim.new(0, 5)
	bPad.PaddingRight = UDim.new(0, 5)
	bPad.Parent = badge

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(210, 220, 240)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.Text = actionText
	label.Size = UDim2.new(0, 0, 1, 0)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Parent = holder

	return holder, badge, label
end

local hSprint, badgeSprint, labelSprint = createHintLabel(0, "L2", "Sprint")
local hShiftLock, badgeShift, labelShift = createHintLabel(1, "L3 / \226\134\147", "ShiftLock: OFF")
local hNav, badgeNav, labelNav = createHintLabel(2, "\226\134\145", "Men\195\186s HUD")
local hSelect, badgeSelect, labelSelect = createHintLabel(3, "A", "Seleccionar")
local hBack, badgeBack, labelBack = createHintLabel(4, "B", "Volver")

updateGamepadHints = function()
	if not isGamepadActive() then
		hintsGui.Enabled = false
		return
	end
	hintsGui.Enabled = true

	local isLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	if isLocked then
		labelShift.Text = "ShiftLock: ON"
		labelShift.TextColor3 = Color3.fromRGB(80, 255, 120)
		disableVirtualCursor()
	else
		labelShift.Text = "ShiftLock: OFF"
		labelShift.TextColor3 = Color3.fromRGB(200, 210, 230)
	end

	if activeMenuGui and activeMenuGui.Enabled then
		-- Mode: Modal menu open
		hSprint.Visible = false
		hShiftLock.Visible = false
		badgeNav.Text = "\226\134\145 \226\134\147 \226\134\144 \226\134\146"
		labelNav.Text = "Navegar"
		hNav.Visible = true
		labelSelect.Text = "Elegir"
		hSelect.Visible = true
		labelBack.Text = "Cerrar Men\195\186"
		hBack.Visible = true
	elseif isObjectInSidebar(GuiService.SelectedObject) then
		-- Mode: Navigating LeftSideBar (Backpack, Evolve, etc.)
		hSprint.Visible = false
		hShiftLock.Visible = false
		badgeNav.Text = "\226\134\145 / \226\134\147"
		labelNav.Text = "Elegir Men\195\186"
		hNav.Visible = true
		labelSelect.Text = "Abrir"
		hSelect.Visible = true
		labelBack.Text = "Volver a Moverse"
		hBack.Visible = true
	else
		-- Mode: In-game walking / playing
		hSprint.Visible = true
		hShiftLock.Visible = true
		badgeNav.Text = "\226\134\145"
		labelNav.Text = "Men\195\186s (HUD)"
		hNav.Visible = true
		labelSelect.Text = "Saltar"
		hSelect.Visible = true
		hBack.Visible = false
		disableVirtualCursor()
	end
end

hintsGui.Parent = playerGui

UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
	local isGpad = tostring(lastInputType):find("Gamepad") ~= nil or isConsole
	hintsContainer.Visible = isGpad
	if isGpad then
		if activeMenuGui and activeMenuGui.Enabled then handleMenuOpened(activeMenuGui) end
	else
		local selected = GuiService.SelectedObject
		if isObjectInSidebar(selected) or (selected and activeMenuGui and selected:IsDescendantOf(activeMenuGui)) then
			GuiService.SelectedObject = nil
		end
		GuiService.GuiNavigationEnabled = false
	end
	updateGamepadHints()
end)

UserInputService.GamepadDisconnected:Connect(function()
	if #UserInputService:GetConnectedGamepads()==0 then
		GuiService.SelectedObject=nil
		GuiService.GuiNavigationEnabled=false
		hintsContainer.Visible=false
	end
end)
UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(updateGamepadHints)
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateGamepadHints)

task.defer(function()
	hintsContainer.Visible = isGamepadActive()
	disableVirtualCursor()
	updateGamepadHints()
end)

