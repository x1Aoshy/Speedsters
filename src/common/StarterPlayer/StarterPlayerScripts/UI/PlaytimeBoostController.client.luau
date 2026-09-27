-- PlaytimeBoostController.client.luau (Update 4, 2026-09-25)
-- The designer's "Playtime Boost" panel (uineww.rbxm, put in StarterGui by the build), used as
-- it is: root frame "Playtime Boost" with Title, Close, Descri, Speed (two labels both named
-- "Speed": "Current Boost:" and the value), Info (the 10M/30M/1H/Max marker frames, plus text
-- labels that share some of those names), Bar/Fill and Time.
-- Opens through MenuEvents "PlaytimeBoost" (the topbar icon). Social/RetentionService counts
-- the time; this panel only draws it: the server publishes PlaytimeSessionAnchor (the server
-- time the counter would have started from zero) on join and on every +10 %, and the seconds
-- are counted here from Workspace:GetServerTimeNow(), once a second and only while open.
-- Duplicated names are told apart by class and position, never by FindFirstChild.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local gui = playerGui:WaitForChild("Playtime Boost", 8)
local window = gui and gui:WaitForChild("Playtime Boost", 5)
if not gui or not gui:IsA("ScreenGui") or not window or not window:IsA("GuiObject") then
	-- The designer's panel is not in this place yet (the build puts it there).
	warn("[PlaytimeBoostController] 'Playtime Boost' panel not found; the Playtime Boost has no window")
	return
end
gui.ResetOnSpawn = false

local U4 = require(Shared:WaitForChild("Update4Config"))
local RetentionMath = require(Shared:WaitForChild("RetentionMath"))
local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))
local ModalJuice = require(Shared:WaitForChild("ModalJuice"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))

local PLAYTIME = U4.Playtime
local lang = TutorialText.ForPlayer(player)
local REACHED_COLOR = Color3.fromRGB(255, 214, 64)

local function childrenOf(parent: Instance?, className: string, name: string?): { Instance }
	local list = {}
	if parent then
		for _, child in parent:GetChildren() do
			if child:IsA(className) and (name == nil or child.Name == name) then
				table.insert(list, child)
			end
		end
	end
	return list
end
local function firstOf(parent: Instance?, className: string, name: string?): any
	return childrenOf(parent, className, name)[1]
end

-- The designer's pieces, found once.
local closeButton = firstOf(window, "GuiButton", "Close")
local timeLabel = firstOf(window, "TextLabel", "Time")
local bar = firstOf(window, "Frame", "Bar")
local fill = firstOf(bar, "GuiObject", "Fill")
local info = firstOf(window, "Frame", "Info")
-- "Speed" frame: its two labels are both named "Speed"; the value is the one whose authored
-- text ends in "Speed" ("+0% Speed"), else the lower one ("Current Boost:" sits above it).
local speedFrame = firstOf(window, "Frame", "Speed")
local valueLabel = nil
do
	local labels = childrenOf(speedFrame, "TextLabel", "Speed")
	table.sort(labels, function(a: any, b: any)
		return a.Position.Y.Scale > b.Position.Y.Scale
	end)
	for _, label: any in labels do
		if string.find(label.Text, "Speed%s*$") then
			valueLabel = label
			break
		end
	end
	valueLabel = valueLabel or labels[1]
end

-- The markers: the Frames (not the TextLabels of the same name) 10M / 30M / 1H / Max; their
-- X is where the bar reaches 10 m / 30 m / 1 h / 100 min (≈0.148 / 0.331 / 0.594 / 0.992).
local MARKER_NAMES = { "10M", "30M", "1H", "Max" }
local MARKER_SECONDS = { 600, 1800, 3600, RetentionMath.PlaytimeMaxSeconds(PLAYTIME) }
local markers = {}
local fillPoints = { { 0, 0 } }
for index, name in MARKER_NAMES do
	local marker = firstOf(info, "Frame", name)
	if marker then
		local dots = {}
		for _, dot in marker:GetChildren() do
			if dot:IsA("Frame") then
				table.insert(dots, { Frame = dot, Color = dot.BackgroundColor3 })
			end
		end
		markers[index] = { Seconds = MARKER_SECONDS[index], Dots = dots }
		table.insert(fillPoints, { MARKER_SECONDS[index], marker.Position.X.Scale })
	end
end
if #fillPoints == 1 then
	fillPoints = { { 0, 0 }, { MARKER_SECONDS[4], 1 } }
end

-- The fill grows from the bar's left edge (the designer left it at a fixed pixel size).
if fill then
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	for _, constraint in fill:GetChildren() do
		if constraint:IsA("UIAspectRatioConstraint") or constraint:IsA("UISizeConstraint") then
			constraint:Destroy()
		end
	end
end
for _, label in { valueLabel, timeLabel } do
	if label then
		label.AutoLocalize = false
	end
end

local isOpen = false
local shownPct, shownFill, shownTime = -1, -1, ""

local function currentSeconds(): number
	local anchor = tonumber(player:GetAttribute("PlaytimeSessionAnchor"))
	if not anchor or anchor <= 0 then
		return 0
	end
	return math.clamp(Workspace:GetServerTimeNow() - anchor, 0, RetentionMath.PlaytimeMaxSeconds(PLAYTIME))
end

local function paint()
	local enabled = U4.IsOn("PlaytimeBoost")
	local seconds = if enabled then currentSeconds() else 0
	-- The server's word wins once it is there; the local count only runs ahead of it by < 5 s.
	local pct = math.max(RetentionMath.PlaytimePercent(seconds, PLAYTIME), tonumber(player:GetAttribute("PlaytimeBoostPct")) or 0)
	if not enabled then
		pct = 0
	end
	if pct ~= shownPct and valueLabel then
		shownPct = pct
		valueLabel.Text = RetentionMath.Text("SpeedBoost", lang, pct)
		for _, marker in markers do
			local reached = pct >= RetentionMath.PlaytimePercent(marker.Seconds, PLAYTIME)
			for _, dot in marker.Dots do
				dot.Frame.BackgroundColor3 = if reached then REACHED_COLOR else dot.Color
			end
		end
	end
	local nextIn = RetentionMath.PlaytimeNextStepIn(seconds, PLAYTIME)
	local text = if not enabled then "--:--" elseif nextIn then RetentionMath.FormatClock(nextIn) else RetentionMath.Text("Max", lang)
	if text ~= shownTime and timeLabel then
		shownTime = text
		timeLabel.Text = text
	end
	local frac = math.clamp(RetentionMath.PiecewiseFill(seconds, fillPoints), 0, 1)
	if fill and math.abs(frac - shownFill) > 0.001 then
		shownFill = frac
		fill.Size = UDim2.fromScale(frac, 1)
		fill.Visible = frac > 0.002
	end
end

-- Once a second while open; nothing runs while it is closed.
local ticker = nil
local function startTicker()
	if ticker then
		return
	end
	ticker = task.spawn(function()
		while isOpen do
			paint()
			task.wait(1)
		end
		ticker = nil
	end)
end

local OPEN_POS = window.Position
-- 2026-09-26 (owner): "too low, move it up a little and make it a bit smaller": on phones the
-- window and its header take 80% of the room (was about 95%), raised 4% of it (PhoneBlock).
MenuPanelLayout.BindPhoneFit(gui, window, OPEN_POS, OPEN_POS, function(fit)
	OPEN_POS = fit.Open
	if isOpen then
		window.Position = OPEN_POS
	end
end, nil, MenuPanelLayout.PhoneBlock)
ModalJuice.WatchGui(gui)

local function open()
	if isOpen then
		return
	end
	isOpen = true
	window.Position = OPEN_POS
	window.Visible = true
	gui.Enabled = true
	shownPct, shownFill, shownTime = -1, -1, ""
	startTicker()
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
end

if closeButton then
	closeButton.Activated:Connect(function()
		if isOpen then
			MenuEvents.Request("PlaytimeBoost")
		end
	end)
end
ConsolePanelSupport.Bind(gui, window, closeButton, closeButton, function()
	if isOpen then
		MenuEvents.Request("PlaytimeBoost")
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and isOpen then
		MenuEvents.Request("PlaytimeBoost")
	end
end)
for _, attribute in { "PlaytimeSessionAnchor", "PlaytimeBoostPct" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if isOpen then
			paint()
		end
	end)
end

MenuEvents.Get("OpenPlaytimeBoostPanel").Event:Connect(function(action)
	if action == "Close" then
		close()
	elseif action == "Open" then
		open()
	elseif isOpen then
		close()
	else
		open()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "PlaytimeBoost" then
		close()
	end
end)
MenuEvents.MarkReady("PlaytimeBoost", function()
	return isOpen
end)
gui.Enabled = false
