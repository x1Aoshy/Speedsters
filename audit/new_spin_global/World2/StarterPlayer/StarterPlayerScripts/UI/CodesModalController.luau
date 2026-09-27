--!strict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CodesRequest = Remotes:WaitForChild("CodesRequest")
local CodesUpdate = Remotes:WaitForChild("CodesUpdate")

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("Codes Modal")

-- Parked panel: keep it off the screen entirely rather than half-wired, and do
-- not listen for open requests, so nothing can surface it by accident.
if Config.PromoCodesModalEnabled ~= true then
	gui.Enabled = false
	local parkedTitle = gui:FindFirstChild("Title")
	if parkedTitle and parkedTitle:IsA("GuiObject") then
		parkedTitle.Visible = false
	end
	print("[CodesModalController] Card list parked; redeeming lives in the Shop Codes section.")
	return
end

local titleFrame = gui:WaitForChild("Title")
local closeButton = titleFrame:WaitForChild("Close")
local codesScroll = titleFrame:WaitForChild("CodesScroll")

local isConsole = GuiService:IsTenFootInterface()

print("[CodesModalController] Loaded successfully and waiting for events.")

-- Ensure Title styling matches Update Logs and standard menus
titleFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
titleFrame.BackgroundTransparency = 0.15

local stroke = titleFrame:FindFirstChildOfClass("UIStroke")
if not stroke then
	stroke = Instance.new("UIStroke")
	stroke.Parent = titleFrame
end
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 2
stroke.Transparency = 0
stroke.Enabled = true

local bgImage = titleFrame:FindFirstChild("Background")
if bgImage and bgImage:IsA("ImageLabel") then
	bgImage.ImageTransparency = 0.15
	bgImage.BackgroundTransparency = 1
end

closeButton.Active = true
closeButton.Selectable = true
closeButton.ZIndex = math.max(closeButton.ZIndex, 15)

local OPEN_POS = titleFrame.Position
local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.35, 0)

local OPEN_TWEEN_INFO = TweenInfo.new(
	0.24,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local CLOSE_TWEEN_INFO = TweenInfo.new(
	0.18,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.In
)

local isOpen = false
local currentTween: Tween? = nil
local ACTION_CLOSE_CODES = "CloseCodesModal_Gamepad"

local function onGamepadB(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		closePanel()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function closePanel()
	if not isOpen then
		return
	end
	isOpen = false

	pcall(function()
		ContextActionService:UnbindAction(ACTION_CLOSE_CODES)
	end)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	currentTween = TweenService:Create(titleFrame, CLOSE_TWEEN_INFO, { Position = CLOSED_POS })
	currentTween:Play()

	task.spawn(function()
		currentTween.Completed:Wait()
		if not isOpen then
			gui.Enabled = false
			titleFrame.Visible = false
			titleFrame.Position = CLOSED_POS
		end
	end)
end

function openPanel()
	if isOpen then
		return
	end
	isOpen = true
	print("[CodesModalController] Subiendo Codes Modal a pantalla...")

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	gui.Enabled = true
	titleFrame.Visible = true
	titleFrame.Position = CLOSED_POS

	if codesScroll and codesScroll:IsA("ScrollingFrame") then
		codesScroll.CanvasPosition = Vector2.new(0, 0)
	end

	currentTween = TweenService:Create(titleFrame, OPEN_TWEEN_INFO, { Position = OPEN_POS })
	currentTween:Play()

	pcall(function()
		local playerScripts = player:FindFirstChild("PlayerScripts")
		if playerScripts then
			local shiftLockEvent = playerScripts:FindFirstChild("ShiftLockControlEvent")
			if shiftLockEvent then
				shiftLockEvent:Fire("Disable")
			end
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)

	pcall(function()
		ContextActionService:BindActionAtPriority(
			ACTION_CLOSE_CODES,
			onGamepadB,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonB
		)
	end)

	if isConsole or UserInputService.GamepadEnabled then
		task.defer(function()
			if isOpen then
				closeButton.Selectable = true
				GuiService.SelectedObject = closeButton
			end
		end)
	end
end

closeButton.Activated:Connect(function()
	closePanel()
end)

-- Code claiming and tracking
local function getOwnedUpgradesFolder(): Folder?
	local data = player:FindFirstChild("SpeedsterData")
	if not data then return nil end
	return data:FindFirstChild("OwnedUpgrades") :: Folder?
end

local function isClaimed(markerName: string?): boolean
	if not markerName or markerName == "" then return false end
	local owned = getOwnedUpgradesFolder()
	if not owned then return false end
	local item = owned:FindFirstChild(markerName)
	return item ~= nil and item:IsA("BoolValue") and item.Value == true
end

local function updateCard(card: Instance)
	if not card:IsA("Frame") then return end
	local claimBtn = card:FindFirstChild("ClaimBtn")
	if not claimBtn or not claimBtn:IsA("TextButton") then return end

	local marker = claimBtn:GetAttribute("Marker") :: string?
	local claimed = isClaimed(marker)

	if claimed then
		claimBtn.Text = "CLAIMED"
		claimBtn.BackgroundColor3 = Color3.fromRGB(50, 56, 70)
		claimBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
		claimBtn.AutoButtonColor = false
		local btnStroke = claimBtn:FindFirstChildOfClass("UIStroke")
		if btnStroke then
			btnStroke.Color = Color3.fromRGB(70, 78, 95)
		end
	else
		claimBtn.Text = "CLAIM"
		claimBtn.BackgroundColor3 = Color3.fromRGB(35, 145, 75)
		claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		claimBtn.AutoButtonColor = true
		local btnStroke = claimBtn:FindFirstChildOfClass("UIStroke")
		if btnStroke then
			btnStroke.Color = Color3.fromRGB(70, 210, 120)
		end
	end
end

local function updateAllCards()
	for _, child in ipairs(codesScroll:GetChildren()) do
		updateCard(child)
	end
end

-- Wire Claim buttons
for _, child in ipairs(codesScroll:GetChildren()) do
	if child:IsA("Frame") then
		local claimBtn = child:FindFirstChild("ClaimBtn")
		if claimBtn and claimBtn:IsA("TextButton") then
			local codeName = claimBtn:GetAttribute("Code") :: string?
			local marker = claimBtn:GetAttribute("Marker") :: string?
			claimBtn.Activated:Connect(function()
				if isClaimed(marker) then
					return
				end
				claimBtn.Text = "..."
				claimBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
				CodesRequest:FireServer("Redeem", codeName or "")
			end)
		end
	end
end

-- Refresh claim status on data changes
task.spawn(function()
	local data = player:WaitForChild("SpeedsterData", 10)
	if data then
		local owned = data:WaitForChild("OwnedUpgrades", 10)
		if owned then
			owned.ChildAdded:Connect(function()
				task.wait(0.1)
				updateAllCards()
			end)
		end
	end
	updateAllCards()
end)

CodesUpdate.OnClientEvent:Connect(function()
	task.wait(0.1)
	updateAllCards()
end)

-- Menu Events
MenuEvents.Get("OpenCodesModal").Event:Connect(function(action)
	print("[CodesModalController] Evento OpenCodesModal recibido:", tostring(action))
	if action == "Close" then
		closePanel()
	elseif action == "Open" then
		openPanel()
	else
		if isOpen then
			closePanel()
		else
			openPanel()
		end
	end
end)

MenuEvents.CloseAll.Event:Connect(function()
	closePanel()
end)

MenuEvents.MarkReady("CodesModal", function()
	return isOpen
end)
