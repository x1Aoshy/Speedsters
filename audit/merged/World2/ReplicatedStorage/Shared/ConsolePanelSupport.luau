local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ConsolePanelSupport = {}

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
				local target = if button(primaryButton) then primaryButton elseif button(closeButton) then closeButton else nil
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
		if object and object:IsA("GuiButton") then object.Selectable = true end
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
