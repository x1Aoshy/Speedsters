local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ConsolePanelSupport = {}

function ConsolePanelSupport.Bind(gui, frame, primaryButton, closeButton, close)
	local action = "CloseSpeedsterPanel_" .. gui.Name
	local previousSelection
	local scale
	local function fitConsole()
		if frame:GetAttribute("SidebarLayoutManaged") then
			if scale then scale.Scale = 1 end
			return
		end
		if not GuiService:IsTenFootInterface() then return end
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "ConsoleSafeScale"
			scale.Parent = frame
		end
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local size = frame.AbsoluteSize / math.max(scale.Scale, 0.001)
		local viewport = camera.ViewportSize
		if size.X > 0 and size.Y > 0 then
			scale.Scale = math.min(1, viewport.X * 0.9 / size.X, viewport.Y * 0.85 / size.Y)
		end
	end
	local function sync()
		if gui.Enabled then
			task.defer(fitConsole)
			if UserInputService.GamepadEnabled then
				if not GuiService.SelectedObject or not GuiService.SelectedObject:IsDescendantOf(frame) then
					previousSelection = GuiService.SelectedObject
					GuiService.SelectedObject = primaryButton
				end
			end
			ContextActionService:BindActionAtPriority(action, function(_, state)
				if state == Enum.UserInputState.Begin then close() end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
		else
			ContextActionService:UnbindAction(action)
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then
				GuiService.SelectedObject = previousSelection and previousSelection.Parent and previousSelection or nil
			end
		end
	end
	primaryButton.Selectable = true
	closeButton.Selectable = true
	primaryButton.NextSelectionUp = closeButton
	closeButton.NextSelectionDown = primaryButton
	gui:GetPropertyChangedSignal("Enabled"):Connect(sync)
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		if tostring(inputType):find("Gamepad") then sync() end
	end)
	local cameraConnection
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitConsole) end
		fitConsole()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	sync()
end

return ConsolePanelSupport
