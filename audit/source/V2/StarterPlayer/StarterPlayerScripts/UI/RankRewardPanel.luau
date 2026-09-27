                                    
                                                                      

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
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local MenuPanelLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuPanelLayout"))
local RankRewardEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RankRewardEvent")

local GROUP_ID = 771624731
local REWARD_MARKER = "RankReward_GroupLike_v1"
local PANEL_SIZE = MenuPanelLayout.ModalSizes.RankReward or Vector2.new(690, 430)
local DARK = Color3.fromRGB(0, 0, 0)
local ORANGE = Color3.fromRGB(255, 110, 35)
local GOLD = Color3.fromRGB(246, 193, 56)
local BLUE = Color3.fromRGB(35, 170, 255)
local GREEN = Color3.fromRGB(55, 205, 90)
local RED = Color3.fromRGB(240, 70, 70)
local WHITE = Color3.fromRGB(255, 255, 255)


local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or DARK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function makeLabel(parent, name, position, size, text, textSize, z)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = DARK
	label.TextStrokeTransparency = 0
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z
	label.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Thickness = 2
	outline.Color = DARK
	outline.Parent = label
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "RankRewardGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 115
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = DARK
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 60
-- Active so tapping outside the panel closes it on mobile (plain frames
-- otherwise let touches pass through and the popup feels stuck).
dim.Active = true
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = WHITE
panel.BorderSizePixel = 0
panel.ZIndex = 61
panel.ClipsDescendants = true
panel.Parent = gui
corner(panel, 18)
stroke(panel, 6, DARK)
StudUi.AddSurface(panel, 62, 18, 9, 6)

local uiScale = MenuPanelLayout.EnsureSingleScale(panel, "UIScale")
local targetScale = 1

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	targetScale = MenuPanelLayout.GetModalScale(viewport, PANEL_SIZE, UserInputService.TouchEnabled)
	uiScale.Scale = targetScale
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = GOLD
header.BorderSizePixel = 0
header.Position = UDim2.fromOffset(0, 0)
header.Size = UDim2.new(1, 0, 0, 92)
header.ZIndex = 64
header.Parent = panel
corner(header, 18)
stroke(header, 5, DARK)
StudUi.AddSurface(header, 65, 18, 9, 2)

makeLabel(header, "Title", UDim2.new(0, 28, 0, 4), UDim2.new(1, -125, 1, -8), "GROUP REWARDS", 46, 68).TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton")
close.Name = "Close"
close.Active = true
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.new(1, -50, 0.5, 0)
close.Size = UDim2.fromOffset(74, 74)
close.BackgroundColor3 = RED
close.BorderSizePixel = 0
close.Font = Enum.Font.FredokaOne
close.Text = "X"
close.TextColor3 = WHITE
close.TextSize = 38
close.ZIndex = 85
close.Parent = header
corner(close, 14)
stroke(close, 4, DARK)
StudUi.StyleButton(close, 14)

local instruction = makeLabel(panel, "Instruction", UDim2.fromOffset(32, 105), UDim2.new(1, -64, 0, 70), "JOIN THE GROUP + LIKE THE GAME", 34, 68)

local rewardCard = Instance.new("Frame")
rewardCard.Name = "RewardCard"
rewardCard.BackgroundColor3 = WHITE
rewardCard.BackgroundTransparency = 1
rewardCard.BorderSizePixel = 0
rewardCard.Position = UDim2.fromOffset(54, 178)
rewardCard.Size = UDim2.new(1, -108, 0, 74)
rewardCard.ZIndex = 66
rewardCard.Parent = panel

makeLabel(rewardCard, "RewardText", UDim2.fromOffset(14, 4), UDim2.new(1, -28, 1, -8), "Reward: +1,000,000 Speed + 1,000 Wins", 28, 69)

local joinButton = Instance.new("TextButton")
joinButton.Name = "JoinGroup"
joinButton.Position = UDim2.fromOffset(68, 272)
joinButton.Size = UDim2.fromOffset(250, 68)
joinButton.BackgroundColor3 = BLUE
joinButton.BorderSizePixel = 0
joinButton.Font = Enum.Font.FredokaOne
joinButton.Text = "JOIN GROUP"
joinButton.TextColor3 = WHITE
joinButton.TextSize = 29
joinButton.ZIndex = 69
joinButton.Parent = panel
corner(joinButton, 13)
stroke(joinButton, 4, DARK)
StudUi.StyleButton(joinButton, 13)

local claimButton = Instance.new("TextButton")
claimButton.Name = "ClaimReward"
claimButton.AnchorPoint = Vector2.new(0, 0)
claimButton.Position = UDim2.fromOffset(372, 272)
claimButton.Size = UDim2.fromOffset(250, 68)
claimButton.BackgroundColor3 = GREEN
claimButton.BorderSizePixel = 0
claimButton.Font = Enum.Font.FredokaOne
claimButton.Text = "CLAIM REWARD"
claimButton.TextColor3 = WHITE
claimButton.TextSize = 27
claimButton.ZIndex = 69
claimButton.Parent = panel
corner(claimButton, 13)
stroke(claimButton, 4, DARK)
StudUi.StyleButton(claimButton, 13)

local status = makeLabel(panel, "Status", UDim2.fromOffset(42, 347), UDim2.new(1, -84, 0, 62), "", 22, 69)
status.TextColor3 = Color3.fromRGB(255, 250, 225)

local openTween = nil
local dimTween = nil
local isOpen = false
local promptBusy = false
local claimBusy = false
local claimed = false
local lastAutoPrompt = 0
local dismissed = false
-- Joining / respawning can drop the player right on the reward pad, which
-- would force the popup open before they even have control. Grant a grace
-- window after every (re)spawn where no auto-open happens.
local spawnGraceUntil = 0
local function grantSpawnGrace()
	spawnGraceUntil = os.clock() + 5
end
local startCharacter = player.Character
if startCharacter then
	grantSpawnGrace()
end
player.CharacterAdded:Connect(grantSpawnGrace)

local function checkClaimedLocally()
	local data = player:FindFirstChild("SpeedsterData")
	local owned = data and data:FindFirstChild("OwnedUpgrades")
	local marker = owned and owned:FindFirstChild(REWARD_MARKER)
	return marker ~= nil and marker:IsA("BoolValue") and marker.Value == true
end

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or WHITE
end

local function setClaimedState(value)
	claimed = value == true
	if claimed then
		claimButton.Text = "CLAIMED!"
		claimButton.BackgroundColor3 = Color3.fromRGB(100, 190, 100)
		joinButton.Text = "GROUP"
	else
		claimButton.Text = "CLAIM REWARD"
		claimButton.BackgroundColor3 = GREEN
		joinButton.Text = "JOIN GROUP"
	end
end

local function closePanel()
	isOpen = false
	dismissed = true
	MenuPanelLayout.AnimateClose(panel, dim, uiScale, targetScale, function()
		gui.Enabled = false
	end, 0.18)
end

local function promptJoinGroup()
	if promptBusy or claimed then
		return
	end
	promptBusy = true
	joinButton.Text = "OPENING..."
	setStatus("Roblox group join prompt is opening...", WHITE)

	local ok, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)

	promptBusy = false
	joinButton.Text = "JOIN GROUP"
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
	if dismissed then
		return
	end
	pcall(function()
		local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
		MenuEvents.CloseAll:Fire("RankReward")
	end)
	setClaimedState(wasClaimed)
	isOpen = true
	gui.Enabled = true
	updateScale()
	MenuPanelLayout.AnimateOpen(panel, dim, uiScale, targetScale, 0.22)

	if claimed then
		setStatus("You already claimed this Rank Reward!", Color3.fromRGB(185, 255, 190))
		return
	end

	if RunService:IsStudio() then
		setStatus("Studio test: pad/menu active. JOIN GROUP may need the published Roblox app.", Color3.fromRGB(255, 245, 175))
		return
	end

	-- Mobile: never auto-open the Roblox group join prompt - it can grab input
	-- and leave the panel feeling stuck. The player taps JOIN GROUP instead.
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

close.Activated:Connect(closePanel)
close.MouseButton1Click:Connect(closePanel)
close.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

dim.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)
pcall(function()
	local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
	MenuEvents.CloseAll.Event:Connect(closePanel)
end)
joinButton.Activated:Connect(promptJoinGroup)

claimButton.Activated:Connect(function()
	if claimed or claimBusy then
		return
	end
	claimBusy = true
	claimButton.Text = "CHECKING..."
	setStatus("Checking your group membership...", WHITE)
	RankRewardEvent:FireServer("Claim")
end)

RankRewardEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Type == "Open" then
		if payload.Claimed == true then
			-- Already claimed: don't pop up again every rejoin/respawn.
			setClaimedState(true)
			if isOpen then
				closePanel()
			end
		elseif not dismissed and os.clock() >= spawnGraceUntil then
			openPanel(false)
		end
	elseif payload.Type == "ClaimResult" then
		claimBusy = false
		setClaimedState(payload.Claimed == true)
		if payload.Success then
			setStatus(payload.Message, Color3.fromRGB(180, 255, 185))
		else
			setStatus(payload.Message, Color3.fromRGB(255, 225, 125))
			if not claimed then
				claimButton.Text = "CLAIM REWARD"
			end
		end
	end
end)


                                            
                                                                             
                                                                               
                                                                                    
local localPadParts = {}
local insidePad = false
local lastLocalOpen = 0
local accumulator = 0

local function requestOpenFromPad()
	if dismissed or checkClaimedLocally() then
		return
	end
	if os.clock() < spawnGraceUntil then
		return
	end
	local now = os.clock()
	if now - lastLocalOpen < 0.75 then
		return
	end
	lastLocalOpen = now
	                                                                            
	                                                  
	openPanel(false)
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
	table.clear(localPadParts)

	local rewardRoot = resolveRewardRoot()
	if not rewardRoot then
		return
	end
	local padNode = resolvePadNode(rewardRoot)
	if not padNode then
		warn(('[RankRewardPanel] Reward container found at %s, but no descendant named Pad was found.'):format(rewardRoot:GetFullName()))
		return
	end

	local function add(part)
		if not part:IsA("BasePart") then return end
		table.insert(localPadParts, part)
	end

	if padNode:IsA("BasePart") then
		add(padNode)
	else
		for _, descendant in ipairs(padNode:GetDescendants()) do
			add(descendant)
		end
	end
	print(("[RankRewardPanel] V306KD bound | root=%s | pad=%s | BaseParts=%d"):format(rewardRoot:GetFullName(), padNode:GetFullName(), #localPadParts))
end

local function pointInsidePadFootZone(part, worldPoint)
	local p = part.CFrame:PointToObjectSpace(worldPoint)
	local half = part.Size * 0.5
	return math.abs(p.X) <= half.X + 1.75
		and math.abs(p.Y) <= half.Y + 4.0
		and math.abs(p.Z) <= half.Z + 1.75
end

local lastPadSearch = 0
collectLocalPadParts()
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.10 then
		return
	end
	accumulator = 0

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

	-- Compute distance to pad. Only clear dismissed when the player has physically walked away (> 28 studs).
	local minDistance = math.huge
	for _, part in ipairs(localPadParts) do
		if part.Parent then
			local dist = (root.Position - part.Position).Magnitude
			if dist < minDistance then
				minDistance = dist
			end
		end
	end
	if minDistance > 28 then
		dismissed = false
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
			if not dismissed and os.clock() >= spawnGraceUntil and not checkClaimedLocally() then
				requestOpenFromPad()
			end
		end
	else
		insidePad = false
	end
end)

print("[RankRewardPanel] V306KE ready | recursive reward binding + reliable Pad touch + responsive stud UI")

