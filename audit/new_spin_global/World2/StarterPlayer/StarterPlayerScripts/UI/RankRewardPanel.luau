local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GroupService = game:GetService("GroupService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MenuPanelLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuPanelLayout"))
local RankRewardEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RankRewardEvent")

local GROUP_ID = 771624731
local REWARD_MARKER = "RankReward_GroupLike_v1"
local PANEL_SIZE = MenuPanelLayout.ModalSizes.RankReward or Vector2.new(690, 430)

local WHITE = Color3.fromRGB(255, 255, 255)
local GREEN = Color3.fromRGB(55, 205, 90)

-- ====================================================================
-- 1. VINCULACIÓN A LA UI DE ROBLOX STUDIO
-- ====================================================================
local gui = playerGui:WaitForChild("RankRewardGui", 10)
if not gui then
	return
end
gui.ResetOnSpawn = false
local dim = gui:WaitForChild("Dim")
local panel = gui:WaitForChild("Panel")
local header = panel:FindFirstChild("Header") or panel

-- Evita que clics dentro del panel traspasen al fondo Dim
panel.Active = true
if dim:IsA("GuiObject") then
	dim.Active = true
end

-- ====================================================================
-- 2. HARDCODEAR POSICIÓN EXACTA DE ICON Y CLOSE DENTRO DE LAS ESQUINAS
-- ====================================================================
-- Icono del grupo (esquina superior izquierda, dentro del Header)
local icon = gui:FindFirstChild("Icon", true) or gui:FindFirstChild("IconLabel", true) or gui:FindFirstChild("GroupIcon", true)
if icon and icon:IsA("GuiObject") then
	icon.Parent = header
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0, 56, 0.5, 0)
	icon.Size = UDim2.fromOffset(70, 66)
	icon.ZIndex = 80
end

-- Botón cerrar (esquina superior derecha, dentro del Header)
local close = gui:FindFirstChild("Close", true) or gui:FindFirstChild("CloseLabel", true) or gui:FindFirstChild("CloseButton", true)
if close and close:IsA("GuiObject") then
	close.Parent = header
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -50, 0.5, 0)
	close.Size = UDim2.fromOffset(60, 60)
	close.ZIndex = 85
end

-- Título centrado entre el Icon y el botón Close
local title = header:FindFirstChild("Title") or panel:FindFirstChild("Title", true)
if title and title:IsA("TextLabel") then
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.5, 0)
	title.Size = UDim2.new(1, -210, 1, -12)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = 75
end

-- Elementos interactivos
local joinButton = gui:FindFirstChild("JoinGroup", true)
local claimButton = gui:FindFirstChild("ClaimReward", true)
local status = gui:FindFirstChild("Status", true)

-- Escala canónica para animaciones fluidas
local uiScale = panel:FindFirstChild("UIScale")
if not uiScale or not uiScale:IsA("UIScale") then
	uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Scale = 1
	uiScale.Parent = panel
end

local targetScale = 1

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	targetScale = MenuPanelLayout.GetModalScale(viewport, PANEL_SIZE, UserInputService.TouchEnabled)
	uiScale.Scale = targetScale
end
local cameraConnection
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

-- ====================================================================
-- 3. ANIMACIONES: AGITARSE (ICON WIGGLE), HOVER Y CLOSE
-- ====================================================================

-- A. Animación de agitarse para el Icono (idéntica a las demás UIs)
local function attachIconShake(targetIcon)
	if not targetIcon or not targetIcon:IsA("GuiObject") then return end

	local iconScale = targetIcon:FindFirstChild("IconScale")
	if not iconScale or not iconScale:IsA("UIScale") then
		iconScale = Instance.new("UIScale")
		iconScale.Name = "IconScale"
		iconScale.Scale = 1.0
		iconScale.Parent = targetIcon
	end

	local isHovered = false

	local function playWiggle()
		local t1 = TweenService:Create(iconScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.20 })
		local r1 = TweenService:Create(targetIcon, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 8 })
		t1:Play(); r1:Play()
		t1.Completed:Wait()

		local t2 = TweenService:Create(iconScale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 })
		local r2 = TweenService:Create(targetIcon, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = -8 })
		t2:Play(); r2:Play()
		t2.Completed:Wait()

		local t3 = TweenService:Create(iconScale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.08 })
		local r3 = TweenService:Create(targetIcon, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 5 })
		t3:Play(); r3:Play()
		t3.Completed:Wait()

		local t4 = TweenService:Create(iconScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
		local r4 = TweenService:Create(targetIcon, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 })
		t4:Play(); r4:Play()
		t4.Completed:Wait()
	end

	-- Ciclo periódico espontáneo mientras la UI está abierta
	task.spawn(function()
		task.wait(1.5)
		while targetIcon.Parent do
			task.wait(math.random(35, 55) / 10)
			if not gui.Enabled or not targetIcon.Visible then continue end
			if not isHovered and math.abs(iconScale.Scale - 1.0) < 0.05 then
				playWiggle()
			end
		end
	end)

	-- Efecto interactivo al pasar el cursor o tocar el icono
	targetIcon.MouseEnter:Connect(function()
		isHovered = true
		TweenService:Create(iconScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.18 }):Play()
		TweenService:Create(targetIcon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 10 }):Play()
	end)
	targetIcon.MouseLeave:Connect(function()
		isHovered = false
		TweenService:Create(iconScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		TweenService:Create(targetIcon, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	end)
end

if icon then
	attachIconShake(icon)
end

-- B. Animación de Hover y Presión para Botones (Claim Reward y Join Group)
local function attachButtonHover(button)
	if not button or not button:IsA("GuiButton") then return end

	local bScale = button:FindFirstChild("ButtonScale")
	if not bScale or not bScale:IsA("UIScale") then
		bScale = Instance.new("UIScale")
		bScale.Name = "ButtonScale"
		bScale.Scale = 1.0
		bScale.Parent = button
	end

	local isHovered = false

	local function onHoverIn()
		isHovered = true
		TweenService:Create(bScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	end

	local function onHoverOut()
		isHovered = false
		TweenService:Create(bScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	end

	local function onPressDown()
		TweenService:Create(bScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
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
end

if joinButton then attachButtonHover(joinButton) end
if claimButton then attachButtonHover(claimButton) end

-- C. Animación de Hover, Click y Cierre para el botón Close
if close and close:IsA("GuiButton") then
	local cScale = close:FindFirstChild("CloseScale")
	if not cScale or not cScale:IsA("UIScale") then
		cScale = Instance.new("UIScale")
		cScale.Name = "CloseScale"
		cScale.Scale = 1.0
		cScale.Parent = close
	end

	local isCloseHovered = false

	local function onHoverIn()
		isCloseHovered = true
		TweenService:Create(cScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.16 }):Play()
		TweenService:Create(close, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = -10 }):Play()
	end

	local function onHoverOut()
		isCloseHovered = false
		TweenService:Create(cScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		TweenService:Create(close, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	end

	local function onPressDown()
		TweenService:Create(cScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.88 }):Play()
		TweenService:Create(close, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = -5 }):Play()
	end

	close.MouseEnter:Connect(onHoverIn)
	close.MouseLeave:Connect(onHoverOut)
	close.MouseButton1Down:Connect(onPressDown)
	close.MouseButton1Up:Connect(function()
		if isCloseHovered then onHoverIn() else onHoverOut() end
	end)
	close.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onPressDown()
		end
	end)
	close.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onHoverOut()
		end
	end)
end

-- ====================================================================
-- 4. ESTADO Y APERTURA / CIERRE CONTROLADOS
-- ====================================================================
local isOpen = false
local dismissedUntilNextEntry = false
local promptBusy = false
local claimBusy = false
local claimed = false
local lastAutoPrompt = 0
local openTime = 0
local activeOpenTween = nil
local activeDimTween = nil

local function cancelTweens()
	if activeOpenTween then
		activeOpenTween:Cancel()
		activeOpenTween = nil
	end
	if activeDimTween then
		activeDimTween:Cancel()
		activeDimTween = nil
	end
end

local function checkClaimedLocally()
	local data = player:FindFirstChild("SpeedsterData")
	local owned = data and data:FindFirstChild("OwnedUpgrades")
	local marker = owned and owned:FindFirstChild(REWARD_MARKER)
	return marker ~= nil and marker:IsA("BoolValue") and marker.Value == true
end

local function setStatus(text, color)
	if status and status:IsA("TextLabel") then
		status.Text = text
		status.TextColor3 = color or WHITE
	end
end

local function setClaimedState(value)
	claimed = value == true
	if claimed then
		if claimButton and claimButton:IsA("TextButton") then
			claimButton.Text = "CLAIMED!"
			claimButton.BackgroundColor3 = Color3.fromRGB(100, 190, 100)
		end
		if joinButton and joinButton:IsA("TextButton") then
			joinButton.Text = "GROUP"
		end
	else
		if claimButton and claimButton:IsA("TextButton") then
			claimButton.Text = "CLAIM REWARD"
			claimButton.BackgroundColor3 = GREEN
		end
		if joinButton and joinButton:IsA("TextButton") then
			joinButton.Text = "JOIN GROUP"
		end
	end
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	dismissedUntilNextEntry = true
	cancelTweens()

	activeOpenTween = TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = targetScale * 0.88,
	})
	activeDimTween = TweenService:Create(dim, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	activeOpenTween:Play()
	activeDimTween:Play()

	activeOpenTween.Completed:Once(function()
		if not isOpen then
			gui.Enabled = false
			panel.Visible = false
			dim.Visible = false
			dim.Active = false
			if close then close.Visible = false end
			if icon then icon.Visible = false end
		end
	end)
end

-- Botón cerrar con animación de salida
if close and close:IsA("GuiButton") then
	close.Activated:Connect(function()
		TweenService:Create(close, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = -35 }):Play()
		closePanel()
	end)
end

local function promptJoinGroup()
	if promptBusy or claimed then
		return
	end
	promptBusy = true
	if joinButton and joinButton:IsA("TextButton") then
		joinButton.Text = "OPENING..."
	end
	setStatus("Roblox group join prompt is opening...", WHITE)

	local ok, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)

	promptBusy = false
	if joinButton and joinButton:IsA("TextButton") then
		joinButton.Text = claimed and "GROUP" or "JOIN GROUP"
	end
	if not ok then
		setStatus("Roblox couldn't open the group prompt. Try again.", Color3.fromRGB(255, 225, 120))
		return
	end

	if result == Enum.GroupMembershipStatus.Joined or result == Enum.GroupMembershipStatus.AlreadyMember then
		setStatus("Group joined! Like the game, then press CLAIM REWARD.", Color3.fromRGB(180, 255, 185))
	elseif result == Enum.GroupMembershipStatus.JoinRequestPending then
		setStatus("Your group join request is pending approval.", Color3.fromRGB(255, 235, 145))
	else
		setStatus("Join the group, Like the game, then claim your reward.", WHITE)
	end
end

local function openPanel(wasClaimed)
	setClaimedState(wasClaimed or checkClaimedLocally())
	if isOpen then return end
	openTime = os.clock()

	-- Notificar que RankReward se abre (para cerrar otras ventanas)
	pcall(function()
		local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
		MenuEvents.CloseAll:Fire("RankReward")
	end)

	isOpen = true
	gui.Enabled = true
	panel.Visible = true
	dim.Visible = true
	dim.Active = true
	if close then close.Visible = true end
	if icon then icon.Visible = true end
	updateScale()

	cancelTweens()

	uiScale.Scale = targetScale * 0.88
	dim.BackgroundTransparency = 1

	activeOpenTween = TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = targetScale,
	})
	activeDimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.48,
	})
	activeOpenTween:Play()
	activeDimTween:Play()

	if claimed then
		setStatus("You already claimed this Rank Reward!", Color3.fromRGB(185, 255, 190))
		return
	end

	if RunService:IsStudio() then
		setStatus("Studio test: pad/menu active. JOIN GROUP may need the published Roblox app.", Color3.fromRGB(255, 245, 175))
		return
	end

	if GuiService:IsTenFootInterface() or UserInputService:GetLastInputType().Name:find("Gamepad") then
		setStatus("Select JOIN GROUP, then CLAIM REWARD.", Color3.fromRGB(255, 245, 175))
		return
	end
	if UserInputService.TouchEnabled then
		setStatus("Tap JOIN GROUP, then come back and tap CLAIM REWARD.", Color3.fromRGB(255, 245, 175))
		return
	end

	setStatus("", WHITE)
	local now = os.clock()
	if now - lastAutoPrompt > 3 then
		lastAutoPrompt = now
		task.delay(0.18, function()
			if isOpen and not claimed then
				promptJoinGroup()
			end
		end)
	end
end

-- Fondo Dim: clic afuera cierra la ventana tras un pequeño margen
dim.InputBegan:Connect(function(input)
	if os.clock() - openTime < 0.25 then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

-- IMPORTANTE: Solo cerrar si el menú que se abre NO es RankReward
pcall(function()
	local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
	MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
		if exceptMenuName == "RankReward" then
			return
		end
		closePanel()
	end)
end)

if joinButton and joinButton:IsA("GuiButton") then
	joinButton.Activated:Connect(promptJoinGroup)
end

if claimButton and claimButton:IsA("GuiButton") then
	claimButton.Activated:Connect(function()
		if claimed or claimBusy then
			return
		end
		claimBusy = true
		if claimButton:IsA("TextButton") then
			claimButton.Text = "CHECKING..."
		end
		setStatus("Checking your group membership...", WHITE)
		RankRewardEvent:FireServer("Claim")
	end)
end

RankRewardEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Type == "Open" then
		if dismissedUntilNextEntry then return end
		openPanel(payload.Claimed == true)
	elseif payload.Type == "ClaimResult" then
		claimBusy = false
		setClaimedState(payload.Claimed == true)
		if payload.Success then
			setStatus(payload.Message, Color3.fromRGB(180, 255, 185))
		else
			setStatus(payload.Message, Color3.fromRGB(255, 225, 125))
			if not claimed and claimButton and claimButton:IsA("TextButton") then
				claimButton.Text = "CLAIM REWARD"
			end
		end
	end
end)

-- ====================================================================
-- 5. DETECCIÓN FÍSICA DEL PAD
-- ====================================================================
local localPadParts = {}
local localPadTouchConnections = {}
local insidePad = false
local lastLocalOpen = 0
local accumulator = 0

local function requestOpenFromPad()
	local now = os.clock()
	if isOpen or now - lastLocalOpen < 0.75 then
		return
	end
	lastLocalOpen = now
	dismissedUntilNextEntry = false
	openPanel(checkClaimedLocally())
	RankRewardEvent:FireServer("OpenRequest")
end

local function compactName(name)
	return string.lower((tostring(name or ""):gsub("[%s_%-]", "")))
end

local function candidateHasPad(candidate)
	if not candidate then
		return false
	end
	if candidate:FindFirstChild("Pad", true) then
		return true
	end
	for _, descendant in ipairs(candidate:GetDescendants()) do
		if compactName(descendant.Name) == "pad" then
			return true
		end
	end
	return false
end

local function resolveRewardRoot()
	local exactPlural = Workspace:FindFirstChild("Rank Rewards", true)
	if exactPlural and candidateHasPad(exactPlural) then
		return exactPlural
	end

	local exactSingular = Workspace:FindFirstChild("Rank Reward", true)
	if exactSingular and candidateHasPad(exactSingular) then
		return exactSingular
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local key = compactName(descendant.Name)
		if (key == "rankrewards" or key == "rankreward" or key == "groupreward" or key == "grouprewards")
			and candidateHasPad(descendant)
		then
			return descendant
		end
	end
	return nil
end

local function resolvePadNode(rewardRoot)
	if not rewardRoot then
		return nil
	end
	local exact = rewardRoot:FindFirstChild("Pad", true)
	if exact then
		return exact
	end
	for _, descendant in ipairs(rewardRoot:GetDescendants()) do
		if compactName(descendant.Name) == "pad" then
			return descendant
		end
	end
	return nil
end

local function collectLocalPadParts()
	for _, conn in ipairs(localPadTouchConnections) do
		conn:Disconnect()
	end
	table.clear(localPadTouchConnections)
	table.clear(localPadParts)

	local rewardRoot = resolveRewardRoot()
	if not rewardRoot then
		return
	end
	local padNode = resolvePadNode(rewardRoot)
	if not padNode then
		return
	end

	local function add(part)
		if not part:IsA("BasePart") then return end
		table.insert(localPadParts, part)
		part.CanTouch = true
		table.insert(localPadTouchConnections, part.Touched:Connect(function(hit)
			local character = player.Character
			if not insidePad and character and hit and hit:IsDescendantOf(character) then
				insidePad = true
				requestOpenFromPad()
			end
		end))
	end

	if padNode:IsA("BasePart") then
		add(padNode)
	else
		for _, descendant in ipairs(padNode:GetDescendants()) do
			add(descendant)
		end
	end
	print(("[RankRewardPanel] Pad bound | root=%s | pad=%s | BaseParts=%d"):format(rewardRoot:GetFullName(), padNode:GetFullName(), #localPadParts))
end

local function pointInsidePadFootZone(part, worldPoint)
	local p = part.CFrame:PointToObjectSpace(worldPoint)
	local half = part.Size * 0.5
	return math.abs(p.X) <= half.X + 2.5
		and math.abs(p.Y) <= half.Y + 5.0
		and math.abs(p.Z) <= half.Z + 2.5
end

local lastPadSearch = 0
collectLocalPadParts()

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.10 then
		return
	end
	accumulator = 0

	-- Streaming destroys old instances; a nonempty array can contain only stale parts.
	for index = #localPadParts, 1, -1 do
		if not localPadParts[index]:IsDescendantOf(Workspace) then table.remove(localPadParts, index) end
	end
	if #localPadParts == 0 then
		if os.clock() - lastPadSearch >= 1.5 then
			lastPadSearch = os.clock()
			collectLocalPadParts()
		end
		insidePad = false
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		insidePad = false
		return
	end

	local footPoint = root.Position - Vector3.new(0, math.max(1.5, humanoid.HipHeight + 1.0), 0)
	local nowInside = false
	for _, part in ipairs(localPadParts) do
		if part.Parent and pointInsidePadFootZone(part, footPoint) then
			nowInside = true
			break
		end
	end

	if nowInside then
		if not insidePad then
			insidePad = true
			requestOpenFromPad()
		end
	else
		insidePad = false
	end
end)

print("[RankRewardPanel] ready | reliable Pad touch + Heartbeat detection + responsive Studio UI")
