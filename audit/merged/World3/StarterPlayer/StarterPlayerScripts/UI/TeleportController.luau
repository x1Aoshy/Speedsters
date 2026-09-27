local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))

local TeleportAction = ReplicatedStorage.Remotes:WaitForChild("TeleportAction")
local TeleportUpdate = ReplicatedStorage.Remotes:WaitForChild("TeleportUpdate")

local STAGE_COUNT = Config.StageCount or 10

local requirementFailSound = Instance.new("Sound")
requirementFailSound.SoundId = "rbxassetid://132281440773764"
requirementFailSound.Parent = SoundService

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://72264591133889"
clickSound.Parent = SoundService

local screenGui = playerGui:WaitForChild("StageTeleport")
local mainFrame = screenGui:WaitForChild("StageTeleport")

local dim = Instance.new("Frame")
dim.Name = "DimOverlay"
dim.AnchorPoint = Vector2.new(0.5, 0.5)
dim.Position = UDim2.fromScale(0.5, 0.5)
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel = 0
dim.ZIndex = 1
dim.Active = true
dim.Visible = false
dim.Parent = screenGui
mainFrame.ZIndex = math.max(mainFrame.ZIndex, 2)
local closeButton = mainFrame:WaitForChild("Close")
local title = mainFrame:WaitForChild("Title")
local scrollingFrame = mainFrame:WaitForChild("ScrollingFrame")

local isOpen = false

local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

local optionsByStage = {}
for _, option in ipairs(Config.TeleportStageOptions or {}) do
	local stage = math.floor(tonumber(option.Stage) or 0)
	if stage >= 1 then
		optionsByStage[stage] = option
	end
end

local quotedCosts = {}
local buyButtonsByStage = {}
local teleportProductPriceCache = {}

local function getWins()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local wins = leaderstats:FindFirstChild("Wins")
		if wins then
			return wins.Value
		end
	end
	return 0
end

local function updateColors()
	local wins = getWins()
	for stageNum, option in pairs(optionsByStage) do
		local buyBtn = buyButtonsByStage[stageNum]
		if option and buyBtn then
			local cost=quotedCosts[stageNum]
			local label=buyBtn:FindFirstChildOfClass("TextLabel")
			if label then label.Text=cost and (formatNumber(cost).." Wins") or "Loading price..." end
			local canAfford = cost~=nil and wins>=cost
			if canAfford then
				buyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
			else
				buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			end
		end
	end
end

local function setupStageButtons()
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") and string.sub(child.Name, 1, 5) == "Stage" then
			local stageNum = tonumber(string.sub(child.Name, 6))
			if stageNum then
				local option = optionsByStage[stageNum]
				local frameContainer = child:FindFirstChild("Frame")
				if frameContainer then
					local buyBtn = frameContainer:FindFirstChild("Buy")
					local robuxBtn = frameContainer:FindFirstChild("BuyRobux") or frameContainer:FindFirstChild("Buyrobux")
					buyButtonsByStage[stageNum] = buyBtn

					local nameLabel = child:FindFirstChild("Name")
					if nameLabel and nameLabel:IsA("TextLabel") then
						nameLabel.Text = (option and option.Name) or ("Stage " .. tostring(stageNum))
					end

					if buyBtn and option then
						local costLabel = buyBtn:FindFirstChildOfClass("TextLabel")
						if costLabel then
							costLabel.Text = "Loading price..."
						end

						buyBtn.Activated:Connect(function()
							clickSound:Play()
							local wins = getWins()
							if quotedCosts[stageNum] and wins >= quotedCosts[stageNum] then
								TeleportAction:FireServer("Wins", stageNum, quotedCosts[stageNum])
							else
								requirementFailSound:Play()
							end
						end)
					end

					if robuxBtn and option then
						local robuxLabel = robuxBtn:FindFirstChildOfClass("TextLabel")
						local robuxPrice = tonumber(option.PriceRobux) or 0
						local pid = tonumber(option.ProductId) or 0
						if robuxLabel then
							if option.WinsOnly then
								robuxLabel.Text = "Wins Only"
								robuxBtn.Visible = false
							elseif pid > 0 then
								if teleportProductPriceCache[pid] then
									robuxLabel.Text = tostring(teleportProductPriceCache[pid])
								else
									if robuxPrice > 0 then
										robuxLabel.Text = tostring(robuxPrice)
									end
									task.spawn(function()
										local ok, info = pcall(function()
											return MarketplaceService:GetProductInfo(pid, Enum.InfoType.Product)
										end)
										if ok and type(info) == "table" and info.PriceInRobux then
											teleportProductPriceCache[pid] = info.PriceInRobux
											if robuxLabel and robuxLabel.Parent then
												robuxLabel.Text = tostring(info.PriceInRobux)
											end
										end
									end)
								end
								robuxBtn.Visible = true
							else
								robuxBtn.Visible = false
							end
						end

						robuxBtn.Activated:Connect(function()
							clickSound:Play()
							if option.ProductId and option.ProductId > 0 then
								MarketplaceService:PromptProductPurchase(player, option.ProductId)
							end
						end)
					elseif robuxBtn and not option then
						robuxBtn.Visible = false
					end
				end
			end
		end
	end
end

local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)
local openTween = nil
local dimTween = nil
local isClosing = false

local function closePanel(instant)
	if not isOpen and not screenGui.Enabled then return end

	if instant then
		isClosing = false
		isOpen = false
		if openTween then openTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		screenGui.Enabled = false
		mainFrame.Visible = false
		mainFrame.Position = CLOSED_POS
		dim.Visible = false
		dim.Active = false
		dim.BackgroundTransparency = 1
		return
	end

	if isClosing then return end
	isClosing = true

	if dimTween then dimTween:Cancel() end
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	dimTween:Play()

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	openTween:Play()

	task.delay(0.18, function()
		if not isClosing then return end
		isClosing = false
		isOpen = false
		screenGui.Enabled = false
		mainFrame.Visible = false
		mainFrame.Position = CLOSED_POS
		dim.Visible = false
		dim.Active = false
	end)
end

local function openPanel()
	TeleportAction:FireServer("Quote")
	if isOpen and screenGui.Enabled and not isClosing then return end
	isClosing = false
	isOpen = true
	updateColors()
	screenGui.Enabled = true
	mainFrame.Visible = true
	mainFrame.Position = CLOSED_POS

	dim.Visible = true
	dim.Active = true
	dim.BackgroundTransparency = 1
	if dimTween then dimTween:Cancel() end
	dimTween = TweenService:Create(dim, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
	dimTween:Play()

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	openTween:Play()
end

local function togglePanel()
	if isOpen then
		closePanel()
	else
		openPanel()
	end
end

dim.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		clickSound:Play()
		closePanel()
	end
end)

closeButton.Activated:Connect(function()
	clickSound:Play()
	closePanel()
end)

local openTeleportPanel = MenuEvents.Get("OpenTeleportPanel")
openTeleportPanel.Event:Connect(function(action)
	if action == "Open" or action == "LeftButtonSwitch" then
		openPanel()
	elseif action == "Close" then
		closePanel()
	else
		togglePanel()
	end
end)

MenuEvents.CloseAll.Event:Connect(closePanel)
-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Teleport", function() return isOpen and not isClosing end)

TeleportUpdate.OnClientEvent:Connect(function(message, messageType)
	if type(message)=="table" then
		if type(message.Costs)=="table" then
			quotedCosts={}
			for stage,cost in pairs(message.Costs) do
				local n=tonumber(stage)
				if n and type(cost)=="number" and cost==cost and cost>=0 and cost<math.huge then quotedCosts[n]=cost end
			end
			updateColors()
		end
		if message.Success==true then closePanel()
		elseif message.Message and message.Message~="" then requirementFailSound:Play() end
		return
	end
	if messageType == "success" then
		closePanel()
	elseif messageType == "fail" then
		requirementFailSound:Play()
	end
end)

-- leaderstats/Wins can take a moment to replicate; yield with a timeout so
-- this script never hangs on a missing folder.
local leaderstats = player:WaitForChild("leaderstats", 15)
local wins = leaderstats and leaderstats:WaitForChild("Wins", 15) or nil
if wins then
	wins.Changed:Connect(updateColors)
end

task.spawn(function() pcall(function() ContentProvider:PreloadAsync({requirementFailSound, clickSound}) end) end)

setupStageButtons()
updateColors()
closePanel()

player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(function()
	quotedCosts={}
	updateColors()
	if isOpen then TeleportAction:FireServer("Quote") end
end)
