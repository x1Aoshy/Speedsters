-- UI/TitlesController.client.luau (Update 4, 2026-09-25)
-- The designer's "Titles" panel (design/ui/uineww.rbxm, put in StarterGui by the build), used
-- as authored: root frame "Titles" with Tittle, Icon, Close, the tab bar "Frame" (All / Staff /
-- Leaderboards / Ranked) and a ScrollingFrame holding two template rows, "None" and "Top500".
-- "None" stays as the first row (equips "none": no title above the head); "Top500" is hidden
-- and cloned once per TitleCatalog entry at start (no clones afterwards). A row's two TextLabels
-- are both named "Title", so they are told apart by order, never by FindFirstChild.
-- The server (Social/TitleSystem) owns everything: "Get" on open, "Equip" <pref>, "Seen" while
-- the notice count is up; TitlesUpdate answers with Owned / Equipped / Ranks / Progress.
-- Opened through MenuEvents "Titles" (the Main HUD side menu's Titles button since the
-- 2026-09-25 cleanup, MainHUDController; no longer a topbar icon), works with
-- mouse, touch and gamepad (ConsolePanelSupport), and fits phones (MenuPanelLayout).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TitleCatalog = require(Shared:WaitForChild("TitleCatalog"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))
local ModalJuice = require(Shared:WaitForChild("ModalJuice"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))

local gui = playerGui:WaitForChild("Titles", 8)
if not gui or not gui:IsA("ScreenGui") then
	return -- a place built without the designer panel
end
local frame = gui:WaitForChild("Titles", 5)
local scroll = frame and frame:WaitForChild("ScrollingFrame", 5)
local noneRow = scroll and scroll:WaitForChild("None", 5)
local templateRow = scroll and scroll:WaitForChild("Top500", 5)
local closeButton = frame and frame:WaitForChild("Close", 5)
local tabBar = frame and frame:WaitForChild("Frame", 5)
if not (frame and scroll and noneRow and templateRow and closeButton and tabBar) then
	warn("[TitlesController] the Titles panel is missing parts; not bound")
	return
end
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TitlesRequest = Remotes:WaitForChild("TitlesRequest", 30)
local TitlesUpdate = Remotes:WaitForChild("TitlesUpdate", 30)
if not TitlesRequest or not TitlesUpdate then
	return -- titles are off on this server build
end

local GREEN = Color3.fromRGB(60, 255, 0) -- the designer's "Equipped" / selected tab
local IDLE = Color3.fromRGB(255, 237, 244) -- the designer's unselected tab / "Locked"
local EQUIP = Color3.fromRGB(0, 190, 255)
local LOCKED = Color3.fromRGB(150, 150, 160)
-- The server's RemoteGuard takes one TitlesRequest per 0.3 s and drops the rest, so requests
-- are paced here: one closer than this to the previous one waits for its turn (the latest of
-- each kind wins), and an Equip tapped right after opening is not lost to the "Get".
local REQUEST_GAP = 0.45 -- 0.3 s plus room for network jitter

local lang = TitleCatalog.Language(TutorialText.ForPlayer(player))
local words = TitleCatalog.Words[lang]

-- Parts of a row, by class and order: the name label sits above the unlock hint (the designer's
-- rows put them at Y 0.28 and 0.69), so the two "Title" labels are ordered by height, not by
-- child order (which a Clone does not promise to keep).
local function rowParts(row: Instance)
	local labels = {}
	for _, child in row:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	local button = row:FindFirstChildOfClass("ImageButton")
	local buttonLabel = button and button:FindFirstChildOfClass("TextLabel")
	local swatch = row:FindFirstChildOfClass("Frame")
	return {
		Row = row,
		Title = labels[1],
		Hint = labels[2],
		Button = button,
		ButtonLabel = buttonLabel,
		TitleGradient = labels[1] and labels[1]:FindFirstChildOfClass("UIGradient"),
		SwatchGradient = swatch and swatch:FindFirstChildOfClass("UIGradient"),
	}
end

local function sequence(colors)
	local c1, c2 = colors[1], colors[2] or colors[1]
	return ColorSequence.new(Color3.fromRGB(c1[1], c1[2], c1[3]), Color3.fromRGB(c2[1], c2[2], c2[3]))
end

-- Rows ---------------------------------------------------------------------------------------
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
local layout = scroll:FindFirstChildOfClass("UIListLayout")
if layout then
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	-- AbsoluteContentSize comes out multiplied by the UIScales above (ModalJuice's pop-in,
	-- ConsoleUiScale) while CanvasSize is read before them: divide, or the list is cut short.
	local function fitCanvas()
		local scale = MenuPanelLayout.ScaleChain(scroll)
		if scale < 0.05 then
			return -- mid pop-in from nothing: measured again as it grows
		end
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale + 8)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)
	fitCanvas()
end

templateRow.Visible = false
-- The designer's English header and tabs, in the player's language.
local header = frame:FindFirstChild("Tittle")
if header and header:IsA("TextLabel") then
	header.Text = words.Header
end
for _, tabButton in tabBar:GetChildren() do
	local tabLabel = tabButton:IsA("GuiButton") and tabButton:FindFirstChildOfClass("TextLabel")
	if tabLabel and words.Tabs[tabButton.Name] then
		tabLabel.Text = words.Tabs[tabButton.Name]
	end
end
local none = rowParts(noneRow)
noneRow.LayoutOrder = 0
if none.Title then
	none.Title.Text = words.None
end
if none.Hint then
	none.Hint.Text = words.NoTitle
end

local rows = {} -- [id] = parts
for _, entry in TitleCatalog.Entries do
	local row = templateRow:Clone()
	row.Name = "Title_" .. entry.Id
	row.Visible = true
	row.Parent = scroll
	local parts = rowParts(row)
	parts.Entry = entry
	if parts.Title then
		parts.Title.Text = entry.Text
	end
	if parts.TitleGradient then
		parts.TitleGradient.Color = sequence(entry.Colors)
	end
	if parts.SwatchGradient then
		parts.SwatchGradient.Color = sequence(entry.Colors)
	end
	rows[entry.Id] = parts
end

-- State ----------------------------------------------------------------------------------------
local state = { Owned = {}, Equipped = "", Preference = "", Progress = {}, Ranks = {} }
local currentTab = "All"
local isOpen, isClosing = false, false
local lastRequestAt = -math.huge
local queued = {} -- { {action, arg} } waiting for the gap, one per action
local flushScheduled = false

local function flushRequests()
	flushScheduled = false
	local nextRequest = table.remove(queued, 1)
	if not nextRequest then
		return
	end
	lastRequestAt = os.clock()
	TitlesRequest:FireServer(nextRequest[1], nextRequest[2])
	if #queued > 0 then
		flushScheduled = true
		task.delay(REQUEST_GAP, flushRequests)
	end
end

local function request(action: string, arg: any?)
	for index, pending in queued do
		if pending[1] == action then
			table.remove(queued, index)
			break
		end
	end
	table.insert(queued, { action, arg })
	if flushScheduled then
		return
	end
	local delaySeconds = REQUEST_GAP - (os.clock() - lastRequestAt)
	if delaySeconds <= 0 then
		flushRequests()
	else
		flushScheduled = true
		task.delay(delaySeconds, flushRequests)
	end
end

local function setButton(parts, mode: string)
	local button, label = parts.Button, parts.ButtonLabel
	if not button then
		return
	end
	if mode == "Equipped" then
		button.ImageColor3 = GREEN
	elseif mode == "Equip" then
		button.ImageColor3 = EQUIP
	else
		button.ImageColor3 = LOCKED
	end
	button.Active = mode == "Equip"
	button.AutoButtonColor = mode == "Equip"
	button.Selectable = true
	if label then
		label.Text = words[mode] or mode
	end
end

local function render()
	local owned = {}
	for _, id in state.Owned do
		owned[id] = true
	end
	local equipped = if state.Equipped ~= "" then state.Equipped else nil
	setButton(none, if equipped == nil then "Equipped" else "Equip")
	for order, entry in TitleCatalog.Sorted(owned, equipped) do
		local parts = rows[entry.Id]
		if parts then
			local have = owned[entry.Id] == true
			parts.Row.LayoutOrder = order
			parts.Row.Visible = currentTab == "All" or entry.Tab == currentTab
			setButton(parts, if entry.Id == equipped then "Equipped" elseif have then "Equip" else "Locked")
			if parts.Title then
				parts.Title.TextTransparency = if have then 0 else 0.35
			end
			if parts.Hint then
				parts.Hint.Text = TitleCatalog.UnlockText(entry, lang, if have then nil else state.Progress[entry.Id])
			end
		end
	end
	for _, button in tabBar:GetChildren() do
		if button:IsA("ImageButton") then
			button.ImageColor3 = if button.Name == currentTab then GREEN else IDLE
		end
	end
end

local function equip(pref: string)
	request("Equip", pref)
end

if none.Button then
	none.Button.Activated:Connect(function()
		if state.Equipped ~= "" then
			equip(TitleCatalog.None)
		end
	end)
end
for id, parts in rows do
	if parts.Button then
		parts.Button.Activated:Connect(function()
			if table.find(state.Owned, id) and state.Equipped ~= id then
				equip(id)
			end
		end)
	end
end
local function switchTab(name: string)
	currentTab = name
	render()
	scroll.CanvasPosition = Vector2.zero
end
for _, button in tabBar:GetChildren() do
	if button:IsA("ImageButton") and table.find(TitleCatalog.Tabs, button.Name) then
		button.Activated:Connect(function()
			switchTab(button.Name)
		end)
	end
end

-- 2026-09-26 (owner): console / gamepad, first-class. The tabs in the catalog's order that the
-- designer's tab bar has; the bumpers step through them (ConsolePanelSupport.Tabs).
local TAB_ORDER = {}
for _, name in TitleCatalog.Tabs do
	local tabButton = tabBar:FindFirstChild(name)
	if tabButton and tabButton:IsA("GuiButton") then
		table.insert(TAB_ORDER, name)
	end
end

-- The first sensible button of the list as it shows now: the first row (in the list's order,
-- None first) that can be equipped, else the first row shown (the equipped one), else the
-- current tab's button. Never a row the current tab hides.
local function firstRowButton(): GuiButton?
	local shown = {}
	if none.Button and noneRow.Visible then
		table.insert(shown, { order = noneRow.LayoutOrder, button = none.Button })
	end
	for _, parts in rows do
		if parts.Button and parts.Row.Visible then
			table.insert(shown, { order = parts.Row.LayoutOrder, button = parts.Button })
		end
	end
	table.sort(shown, function(a, b)
		return a.order < b.order
	end)
	for _, entry in shown do
		if entry.button.Active then
			return entry.button
		end
	end
	if shown[1] then
		return shown[1].button
	end
	local tabButton = tabBar:FindFirstChild(currentTab)
	return if tabButton and tabButton:IsA("GuiButton") then tabButton else nil
end

TitlesUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	state.Owned = if type(payload.Owned) == "table" then payload.Owned else {}
	state.Equipped = if type(payload.Equipped) == "string" then payload.Equipped else ""
	state.Preference = if type(payload.Preference) == "string" then payload.Preference else ""
	state.Progress = if type(payload.Progress) == "table" then payload.Progress else {}
	state.Ranks = if type(payload.Ranks) == "table" then payload.Ranks else {}
	if isOpen then
		render()
	end
end)

-- Open / close -----------------------------------------------------------------------------------
local OPEN_POS = frame.Position
local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.6, 0)
MenuPanelLayout.BindPhoneFit(gui, frame, OPEN_POS, CLOSED_POS, function(fit)
	OPEN_POS, CLOSED_POS = fit.Open, fit.Closed
end)
ModalJuice.WatchGui(gui)
local moveTween = nil

-- 2026-09-26 (owner): ButtonL1 / ButtonR1 switch tabs while the panel is open, and the selection
-- follows to the new tab's first sensible row (the rows the old tab showed may be hidden now).
local syncTabs = ConsolePanelSupport.Tabs("TitlesGamepadTabs", function()
	return isOpen and not isClosing and gui.Enabled
end, function(step)
	if #TAB_ORDER == 0 then
		return
	end
	local index = table.find(TAB_ORDER, currentTab) or 1
	switchTab(TAB_ORDER[ConsolePanelSupport.Cycle(index, #TAB_ORDER, step)])
	ConsolePanelSupport.Select(firstRowButton())
end)

local function closePanel(instant: boolean?)
	if not isOpen and not gui.Enabled then
		return
	end
	if moveTween then
		moveTween:Cancel()
	end
	if instant then
		isOpen, isClosing = false, false
		gui.Enabled = false
		frame.Position = CLOSED_POS
		syncTabs()
		ConsolePanelSupport.ClearSelection(gui)
		return
	end
	if isClosing then
		return
	end
	isClosing = true
	syncTabs()
	moveTween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	moveTween:Play()
	task.delay(0.18, function()
		if not isClosing then
			return
		end
		isOpen, isClosing = false, false
		gui.Enabled = false
		frame.Position = CLOSED_POS
		ConsolePanelSupport.ClearSelection(gui)
	end)
end

local function openPanel()
	if isOpen and gui.Enabled and not isClosing then
		return
	end
	isOpen, isClosing = true, false
	render()
	gui.Enabled = true
	frame.Visible = true
	frame.Position = CLOSED_POS
	if moveTween then
		moveTween:Cancel()
	end
	moveTween = TweenService:Create(frame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	moveTween:Play()
	-- 2026-09-26 (owner): the bumpers while open; the first sensible row is selected by
	-- ConsolePanelSupport.Bind below (a gamepad as the last input).
	syncTabs()
	request("Get")
	if (tonumber(player:GetAttribute("TitlesNewCount")) or 0) > 0 then
		request("Seen")
	end
end

closeButton.Activated:Connect(function()
	closePanel()
end)

MenuEvents.Listen("Titles", function(action)
	if action == "Open" then
		openPanel()
	elseif action == "Close" then
		closePanel(true)
	elseif isOpen then
		closePanel()
	else
		openPanel()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName == "Titles" then
		return
	end
	closePanel(true)
end)
-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Titles", function()
	return isOpen and not isClosing
end)
-- 2026-09-26 (owner): opened with a gamepad, the first row that can be equipped is selected
-- (firstRowButton), not the None row's (inactive while nothing is equipped) or Close.
ConsolePanelSupport.Bind(gui, frame, firstRowButton, closeButton, function()
	closePanel(true)
end)
closePanel(true)
