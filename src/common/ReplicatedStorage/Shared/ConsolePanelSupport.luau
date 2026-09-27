local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ConsolePanelSupport = {}

-- 2026-09-26 (owner): console / gamepad, first-class. Helpers the panels share, on top of
-- ConsoleUiScale (the universal manager: ButtonB closes the active menu through
-- MenuEvents.CloseAll, the console safe insets) and Bind below:
--   * GamepadActive, Shown, FirstButton, Select, ClearSelection: the selection only ever lands
--     on a button that is actually on screen, the first sensible one (reading order, not the
--     Close button, not a full-screen dim), and is given back (nil) when a panel closes;
--   * Tabs: ButtonL1 / ButtonR1 step a panel's tabs while it is open (Cycle wraps around);
--   * Back: ButtonB closes the top-most layer first (a sub-panel over its window) and passes
--     on to ConsoleUiScale's universal close otherwise.
-- Above ConsoleUiScale's ButtonB (High) and SpeedsterClient's L1 sprint (High + 100), under the
-- race input (High + 200), so an open panel's bumpers never sprint.
ConsolePanelSupport.Priority = Enum.ContextActionPriority.High.Value + 150
-- Buttons that are never "the first sensible button": a window's way out, and the full-screen
-- dims some panels close on.
ConsolePanelSupport.SkipNames = { "close", "exit", "dim", "overlay", "backdrop", "blocker", "shade" }

function ConsolePanelSupport.GamepadActive(): boolean
	if GuiService:IsTenFootInterface() then
		return true
	end
	return UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

-- Drawn right now: every GuiObject from `object` up to its ScreenGui is Visible and the
-- ScreenGui is Enabled (a parentless or out-of-GUI object is not).
function ConsolePanelSupport.Shown(object: Instance?): boolean
	local node = object
	while node do
		if node:IsA("LayerCollector") then
			return node.Enabled == true
		end
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return false
end

local function skipped(button: Instance): boolean
	if button.Name == "X" then
		return true
	end
	local lower = string.lower(button.Name)
	for _, word in ConsolePanelSupport.SkipNames do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- Inside the visible part of every ScrollingFrame it sits in (up to `root`).
local function inView(button: GuiObject, root: Instance): boolean
	local centre = button.AbsolutePosition + button.AbsoluteSize / 2
	local node = button.Parent
	while node and node ~= root do
		if node:IsA("ScrollingFrame") then
			local top, window = node.AbsolutePosition, node.AbsoluteWindowSize
			if centre.X < top.X - 1 or centre.X > top.X + window.X + 1 or centre.Y < top.Y - 1 or centre.Y > top.Y + window.Y + 1 then
				return false
			end
		end
		node = node.Parent
	end
	return true
end

-- `a` comes before `b` in reading order: the higher row first (rows are centres closer than half
-- the smaller height), then the left one.
local function readsBefore(a: GuiObject, b: GuiObject?): boolean
	if not b then
		return true
	end
	local ay = a.AbsolutePosition.Y + a.AbsoluteSize.Y / 2
	local by = b.AbsolutePosition.Y + b.AbsoluteSize.Y / 2
	if math.abs(ay - by) > math.min(a.AbsoluteSize.Y, b.AbsoluteSize.Y) / 2 then
		return ay < by
	end
	return a.AbsolutePosition.X < b.AbsolutePosition.X
end

-- The first sensible button under `root`: shown, Active, not a way out or a full-screen dim,
-- first in reading order among those inside their scroll windows (else among all of them; the
-- engine scrolls to a selection). Positions are compared with each other only, so a window still
-- sliding in (off screen) is read the same. options.Skip(button) -> true leaves a button out.
function ConsolePanelSupport.FirstButton(root: Instance?, options: any?): GuiButton?
	if not root then
		return nil
	end
	local gui = if root:IsA("LayerCollector") then root else root:FindFirstAncestorWhichIsA("LayerCollector")
	local screen = gui and gui:IsA("GuiBase2d") and gui.AbsoluteSize or nil
	local extraSkip = type(options) == "table" and options.Skip or nil
	local best, bestInView = nil, nil
	for _, object in root:GetDescendants() do
		if object:IsA("GuiButton") and object.Active and not skipped(object) and ConsolePanelSupport.Shown(object)
			and not (extraSkip and extraSkip(object))
		then
			local size = object.AbsoluteSize
			local fullScreen = screen ~= nil and screen.X > 0 and size.X >= 0.9 * screen.X and size.Y >= 0.9 * screen.Y
			if not fullScreen then
				if readsBefore(object, best) then
					best = object
				end
				if inView(object, root) and readsBefore(object, bestInView) then
					bestInView = object
				end
			end
		end
	end
	return bestInView or best
end

-- Selects `object` when a gamepad drives the UI and it is shown; returns whether it did.
function ConsolePanelSupport.Select(object: Instance?): boolean
	if not object or not object:IsA("GuiObject") or GuiService.MenuIsOpen or not ConsolePanelSupport.GamepadActive() then
		return false
	end
	if not ConsolePanelSupport.Shown(object) then
		return false
	end
	object.Selectable = true
	GuiService.SelectedObject = object
	return true
end

-- A closing panel gives the selection back: nil when it is inside `root`.
function ConsolePanelSupport.ClearSelection(root: Instance?)
	local selected = GuiService.SelectedObject
	if root and selected and selected:IsDescendantOf(root) then
		GuiService.SelectedObject = nil
	end
end

-- The tab `step` away from `index` among `count`, wrapping around both ends.
function ConsolePanelSupport.Cycle(index: number, count: number, step: number): number
	if count <= 0 then
		return 1
	end
	return ((math.floor(index) - 1 + step) % count) + 1
end

local function bindWhile(action: string, isOpen: () -> boolean, keys: { EnumItem }, onPress: (InputObject) -> ())
	local bound = false
	local function handler(_, state, input)
		if state ~= Enum.UserInputState.Begin or GuiService.MenuIsOpen or not isOpen() then
			return Enum.ContextActionResult.Pass
		end
		onPress(input)
		return Enum.ContextActionResult.Sink
	end
	-- Call it whenever the panel opens or closes: bound exactly while isOpen().
	return function()
		local want = isOpen() == true
		if want and not bound then
			bound = true
			ContextActionService:BindActionAtPriority(action, handler, false, ConsolePanelSupport.Priority, table.unpack(keys))
		elseif not want and bound then
			bound = false
			ContextActionService:UnbindAction(action)
		end
	end
end

-- ButtonL1 / ButtonR1 call step(-1) / step(1) while isOpen(). Returns the sync function.
function ConsolePanelSupport.Tabs(action: string, isOpen: () -> boolean, step: (number) -> ())
	return bindWhile(action, isOpen, { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1 }, function(input)
		step(if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
	end)
end

-- ButtonB calls back() while isOpen() (a layer over the window: the Shop's Gift list); otherwise
-- it passes on to ConsoleUiScale, which closes the window through MenuEvents.CloseAll.
function ConsolePanelSupport.Back(action: string, isOpen: () -> boolean, back: () -> ())
	return bindWhile(action, isOpen, { Enum.KeyCode.ButtonB }, function()
		back()
	end)
end

-- `primaryButton` may be a function returning the button to select (2026-09-26: the Titles
-- panel picks its first row that can be equipped as it opens).
function ConsolePanelSupport.Bind(gui, frame, primaryButton, closeButton, close)
	if not gui or not gui:IsA("ScreenGui") or not frame or not frame:IsA("GuiObject") then return end
	local action = "CloseSpeedsterPanel_" .. gui.Name
	local connections, scale, cameraConnection = {}, nil, nil
	local function visible(object)
		if not object or not object:IsDescendantOf(gui) then return false end
		while object ~= gui do
			if object:IsA("GuiObject") and not object.Visible then return false end
			object = object.Parent
		end
		return gui.Enabled
	end
	local function button(object)
		return object and object:IsA("GuiButton") and object.Active and visible(object)
	end
	local function primary()
		if type(primaryButton) == "function" then
			local ok, resolved = pcall(primaryButton)
			return if ok then resolved else nil
		end
		return primaryButton
	end
	local function fitConsole()
		local existingScale = frame:FindFirstChildOfClass("UIScale")
		if frame:GetAttribute("SidebarLayoutManaged") or (existingScale and existingScale ~= scale) or not GuiService:IsTenFootInterface() then
			if scale then scale.Scale = 1 end
			return
		end
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "ConsoleSafeScale"
			scale.Parent = frame
		end
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local size = frame.AbsoluteSize / math.max(scale.Scale, 0.001)
		if size.X > 0 and size.Y > 0 then
			scale.Scale = math.min(1, camera.ViewportSize.X * 0.9 / size.X, camera.ViewportSize.Y * 0.85 / size.Y)
		end
	end
	local function sync()
		ContextActionService:UnbindAction(action)
		if not visible(frame) then
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then GuiService.SelectedObject = nil end
			return
		end
		task.defer(fitConsole)
		local gamepadInput = GuiService:IsTenFootInterface() or (UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad"))
		if gamepadInput and not GuiService.MenuIsOpen then
			local selected = GuiService.SelectedObject
			if not selected or not visible(selected) then
				-- A resolver's choice is taken as it is (it already chose a sensible one); a fixed
				-- button only while it is Active, as before.
				local first = primary()
				local chosen = first and first:IsA("GuiButton") and visible(first) and (type(primaryButton) == "function" or first.Active)
				local target = if chosen then first elseif button(closeButton) then closeButton else nil
				if target then target.Selectable = true; GuiService.SelectedObject = target end
			end
		end
		if type(close) == "function" then
			-- Universal menu navigation has higher priority; this is a fallback for standalone panels.
			ContextActionService:BindActionAtPriority(action, function(_, state)
				if GuiService.MenuIsOpen or not visible(frame) then return Enum.ContextActionResult.Pass end
				local selected = GuiService.SelectedObject
				if selected and not selected:IsDescendantOf(gui) then return Enum.ContextActionResult.Pass end
				if state == Enum.UserInputState.Begin then close(); return Enum.ContextActionResult.Sink end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.Medium.Value, Enum.KeyCode.ButtonB)
		end
	end
	for _, object in {primaryButton, closeButton} do
		if type(object) ~= "function" and object and object:IsA("GuiButton") then object.Selectable = true end
	end
	local function connect(signal, callback) table.insert(connections, signal:Connect(callback)) end
	connect(gui:GetPropertyChangedSignal("Enabled"), sync)
	connect(frame:GetPropertyChangedSignal("Visible"), sync)
	connect(UserInputService.LastInputTypeChanged, function(inputType)
		if tostring(inputType):find("Gamepad") then sync() end
	end)
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitConsole) end
		fitConsole()
	end
	connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
	connect(gui.Destroying, function()
		ContextActionService:UnbindAction(action)
		if cameraConnection then cameraConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end)
	bindCamera()
	sync()
end

return ConsolePanelSupport
