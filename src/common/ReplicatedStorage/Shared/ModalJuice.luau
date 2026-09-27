--[[
	ModalJuice - Proporciona animaciones de "Game Feel" / Juice para ventanas emergentes.
	Aplica un zoom elástico sutil (0.88 -> 1.0 con Back.Out) en la apertura y contracción
	suave en el cierre, utilizando UIScale nativo para respetar al 100% las posiciones
	y tamaños UDim2 diseñados en Roblox Studio.
--]]

local TweenService = game:GetService("TweenService")

local ModalJuice = {}

local OPEN_SCALE_INFO = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_SCALE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local MODAL_MAIN_FRAMES = {
	Shop = { "Shop" },
	Index = { "Index" },
	Backpack = { "MainFrame" },
	Evolve = { "Evolve" },
	Rebirth = { "Rebirth" },
	Abilities = { "Panel" },
	StageTeleport = { "StageTeleport" },
	Worlds = { "Worlds" },
	Settings = { "Settings" },
	DailyReward = { "Days31" },
	TimeGift = { "TimeGift" },
	Treadmill = { "TimeGift" },
	["Update Logs"] = { "Title" },
	RankRewardGui = { "Panel" },
	-- Update 4 (2026-09-25): the designer's panels keep their root frame's name; the race
	-- windows are built by RaceUiBuilder with a root frame named "Window".
	["Playtime Boost"] = { "Playtime Boost" },
	["Streak Rewards"] = { "Streak Rewards" },
	["Community rewards"] = { "Community rewards" },
	Titles = { "Titles" },
	RacePanelGui = { "Window" },
	RaceResults = { "Window" },
}

function ModalJuice.GetOrCreateScale(frame: GuiObject): UIScale
	local scale = frame:FindFirstChild("ModalJuiceScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "ModalJuiceScale"
		scale.Scale = 1
		scale.Parent = frame
	end
	return scale
end

function ModalJuice.PopIn(frame: GuiObject, startScale: number?, customInfo: TweenInfo?)
	if not frame or not frame:IsA("GuiObject") then return end
	local existingScale = frame:FindFirstChildOfClass("UIScale")
	if existingScale and existingScale.Name ~= "ModalJuiceScale" then return end
	local scale = ModalJuice.GetOrCreateScale(frame)
	scale.Scale = startScale or 0.88
	local tw = TweenService:Create(scale, customInfo or OPEN_SCALE_INFO, { Scale = 1 })
	tw:Play()
	return tw
end

function ModalJuice.PopOut(frame: GuiObject, targetScale: number?, customInfo: TweenInfo?)
	if not frame or not frame:IsA("GuiObject") then return end
	local scale = frame:FindFirstChild("ModalJuiceScale")
	if not scale or not scale:IsA("UIScale") then return end
	local tw = TweenService:Create(scale, customInfo or CLOSE_SCALE_INFO, { Scale = targetScale or 0.88 })
	tw:Play()
	return tw
end

function ModalJuice.AnimateModal(gui: ScreenGui, isOpen: boolean)
	if not gui or not gui:IsA("ScreenGui") then return end
	local frameNames = MODAL_MAIN_FRAMES[gui.Name]
	if not frameNames then
		-- Fallback: animate any child frame not named Dim or Overlay
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "Dim" and child.Name ~= "Overlay" and child.Visible then
				if isOpen then
					ModalJuice.PopIn(child)
				else
					ModalJuice.PopOut(child)
				end
			end
		end
		return
	end

	for _, frameName in ipairs(frameNames) do
		local frame = gui:FindFirstChild(frameName)
		if frame and frame:IsA("GuiObject") then
			if isOpen then
				ModalJuice.PopIn(frame)
			else
				ModalJuice.PopOut(frame)
			end
		end
	end
end

local CLOSE_HOVER_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_HOVER_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function ModalJuice.AttachCloseButtonAnimation(button: GuiButton)
	if not button or not button:IsA("GuiButton") then return end
	if button:GetAttribute("CloseAnimAttached") == true then return end
	if button:FindFirstChildOfClass("UIScale") then return end
	button:SetAttribute("CloseAnimAttached", true)

	local scale = button:FindFirstChild("CloseButtonScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "CloseButtonScale"
		scale.Scale = 1.0
		scale.Parent = button
	end

	local isHovered = false

	local function onHoverIn()
		isHovered = true
		TweenService:Create(scale, CLOSE_HOVER_IN, { Scale = 1.15 }):Play()
		TweenService:Create(button, CLOSE_HOVER_IN, { Rotation = -8 }):Play()
	end

	local function onHoverOut()
		isHovered = false
		TweenService:Create(scale, CLOSE_HOVER_OUT, { Scale = 1.0 }):Play()
		TweenService:Create(button, CLOSE_HOVER_OUT, { Rotation = 0 }):Play()
	end

	local function onPressDown()
		TweenService:Create(scale, CLOSE_PRESS, { Scale = 0.88 }):Play()
		TweenService:Create(button, CLOSE_PRESS, { Rotation = -4 }):Play()
	end

	local function onPressUp()
		if isHovered then
			onHoverIn()
		else
			onHoverOut()
		end
	end

	button.MouseEnter:Connect(onHoverIn)
	button.MouseLeave:Connect(onHoverOut)
	button.MouseButton1Down:Connect(onPressDown)
	button.MouseButton1Up:Connect(onPressUp)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onPressDown()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onHoverOut()
		end
	end)
	button.SelectionGained:Connect(onHoverIn)
	button.SelectionLost:Connect(onHoverOut)
end

local ICON_BOUNCE_IN = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ICON_BOUNCE_MID = TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ICON_BOUNCE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function ModalJuice.AttachHeaderIconAnimation(icon: ImageLabel, isRebirth: boolean)
	if not icon or not icon:IsA("ImageLabel") then return end
	if icon:GetAttribute("HeaderAnimAttached") == true then return end
	if icon:FindFirstChildOfClass("UIScale") then return end
	icon:SetAttribute("HeaderAnimAttached", true)

	local scale = icon:FindFirstChild("HeaderIconScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "HeaderIconScale"
		scale.Scale = 1.0
		scale.Parent = icon
	end

	local rootGui = icon:FindFirstAncestorOfClass("ScreenGui")

	if isRebirth then
		-- Giro espontáneo de 90° (girito de 90°, paran, girito de 90° - no completo)
		task.spawn(function()
			task.wait(math.random(2, 4))
			while icon.Parent do
				task.wait(math.random(35, 65) / 10)
				if rootGui and not rootGui.Enabled then continue end
				if not icon.Visible then continue end

				local curRot = icon.Rotation
				local t1 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 90 })
				t1:Play()
				t1.Completed:Wait()

				task.wait(0.35)

				local t2 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 180 })
				t2:Play()
				t2.Completed:Wait()

				icon.Rotation = (curRot + 180) % 360
			end
		end)
	else
		-- Brincandito de atención periódico estilo Shop ("el otro más")
		task.spawn(function()
			task.wait(1.5)
			while icon.Parent do
				task.wait(math.random(45, 70) / 10)
				if rootGui and not rootGui.Enabled then continue end
				if not icon.Visible then continue end

				if math.abs(scale.Scale - 1.0) < 0.05 then
					local t1 = TweenService:Create(scale, ICON_BOUNCE_IN, { Scale = 1.22 })
					local r1 = TweenService:Create(icon, ICON_BOUNCE_IN, { Rotation = 6 })
					t1:Play(); r1:Play()
					t1.Completed:Wait()

					local t2 = TweenService:Create(scale, ICON_BOUNCE_MID, { Scale = 1.16 })
					local r2 = TweenService:Create(icon, ICON_BOUNCE_MID, { Rotation = -6 })
					t2:Play(); r2:Play()
					r2.Completed:Wait()

					local t3 = TweenService:Create(scale, ICON_BOUNCE_OUT, { Scale = 1.0 })
					local r3 = TweenService:Create(icon, ICON_BOUNCE_OUT, { Rotation = 0 })
					t3:Play(); r3:Play()
					t3.Completed:Wait()
				end
			end
		end)
	end
end

function ModalJuice.WatchGui(gui: ScreenGui)
	if not gui or not gui:IsA("ScreenGui") then return end
	if gui:GetAttribute("ModalJuiceWatching") then return end
	gui:SetAttribute("ModalJuiceWatching", true)

	local function checkElements(child)
		if child:IsA("GuiButton") and (child.Name == "Close" or child.Name:lower():find("close")) then
			ModalJuice.AttachCloseButtonAnimation(child)
		elseif child:IsA("ImageLabel") then
			local listbutton = gui:FindFirstChild("Listbutton", true)
			if listbutton and (child == listbutton or child:IsDescendantOf(listbutton)) then
				return
			end
			if child.Name ~= "Background" and child.Name ~= "Dim" and child.Name ~= "Overlay" then
				local parent = child.Parent
				if parent and parent:IsA("GuiObject") then
					local isMain = false
					local frameNames = MODAL_MAIN_FRAMES[gui.Name]
					if frameNames then
						for _, fn in ipairs(frameNames) do
							if parent.Name == fn then
								isMain = true
								break
							end
						end
					else
						if parent.Parent == gui and parent:IsA("Frame") then
							isMain = true
						end
					end

					if isMain then
						local isHeader = child.Name == "ImageLabel" or child.Name == "Icon" or child.Name == "Rebirth" or child.Position.Y.Scale <= 0.35
						if isHeader then
							local isRebirth = (gui.Name == "Rebirth" or child.Name == "Rebirth" or (child.Image and child.Image:find("129578402198506") ~= nil))
							ModalJuice.AttachHeaderIconAnimation(child, isRebirth)
						end
					end
				end
			end
		end
	end

	for _, desc in ipairs(gui:GetDescendants()) do
		checkElements(desc)
	end
	gui.DescendantAdded:Connect(checkElements)

	if not MODAL_MAIN_FRAMES[gui.Name] then return end

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			ModalJuice.AnimateModal(gui, true)
		else
			ModalJuice.AnimateModal(gui, false)
		end
	end)

	if gui.Enabled then
		ModalJuice.AnimateModal(gui, true)
	end
end

function ModalJuice.InitAutoJuice(playerGui: Instance)
	if not playerGui then return end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			ModalJuice.WatchGui(child)
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			ModalJuice.WatchGui(child)
		end
	end)
end

return ModalJuice
