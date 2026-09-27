                                                                                     
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local UI_CLICK_SOUND_ID = "rbxassetid://72264591133889"

local uiClickSound = SoundService:FindFirstChild("SpeedsterUiClickSound")
if not uiClickSound then
	uiClickSound = Instance.new("Sound")
	uiClickSound.Name = "SpeedsterUiClickSound"
	uiClickSound.Parent = SoundService
end

                                                 
uiClickSound.SoundId = UI_CLICK_SOUND_ID
uiClickSound.Volume = 0.65
uiClickSound.PlaybackSpeed = 1

local function playUiClickSound()
	if not uiClickSound then
		return
	end

	uiClickSound.TimePosition = 0
	uiClickSound:Play()
end


                                                                            
                                                                          
                           
                                   
                                                                              
                                                           
local Buttons = {
	{
		Name = "Abilities",
		Color = Color3.fromRGB(255, 88, 35),
		Icon = "rbxassetid://106467618023890",
		IconSize = UDim2.fromOffset(72, 72),
	},
	{
		Name = "Index",
		Color = Color3.fromRGB(20, 212, 255),
		Icon = "rbxassetid://72509882071188",
		IconSize = UDim2.fromOffset(72, 72),
	},
	{
		Name = "Daily",
		Color = Color3.fromRGB(20, 212, 255),
		Icon = "rbxassetid://114179507617053",
		IconSize = UDim2.fromOffset(70, 70),
	},
	{
		Name = "Rebirth",
		Color = Color3.fromRGB(255, 70, 225),
		Icon = "rbxassetid://98204886250993",
		IconSize = UDim2.fromOffset(72, 72),
		IconOffset = Vector2.new(-2, 5),
	},
	{
		Name = "Trails",
		Color = Color3.fromRGB(205, 45, 255),
		Icon = "rbxassetid://98588181351416",
		IconSize = UDim2.fromOffset(78, 74),
	},
	{
		Name = "Auras",
		Color = Color3.fromRGB(20, 212, 255),
		Icon = "rbxassetid://94918281415437",
		IconSize = UDim2.fromOffset(72, 72),
	},
	{
		Name = "Evolve",
		Color = Color3.fromRGB(95, 255, 24),
		Icon = "rbxassetid://82889820923485",
		IconSize = UDim2.fromOffset(80, 80),
		IconOffset = Vector2.new(-1, 5),
	},
	{
		Name = "Teleport",
		Color = Color3.fromRGB(255, 215, 25),
		Icon = "rbxassetid://72658080659794",
		IconSize = UDim2.fromOffset(72, 72),
	},
}

local old = playerGui:FindFirstChild("LeftButtonMenu")
if old then
	old:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeftButtonMenu"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
                                                                          
                                                                          
                     
screenGui.DisplayOrder = 89
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "ButtonContainer"
container.BackgroundTransparency = 1
container.AnchorPoint = Vector2.new(0, 0.5)
container.Size = UDim2.fromOffset(198, 410)
container.Position = UDim2.new(0, 14, 0.5, 0)
container.Parent = screenGui

local scale = Instance.new("UIScale")
scale.Parent = container

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(92, 92)
grid.CellPadding = UDim2.fromOffset(14, 14)
grid.FillDirection = Enum.FillDirection.Horizontal
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
grid.VerticalAlignment = Enum.VerticalAlignment.Top
grid.Parent = container

local toast = Instance.new("TextLabel")
toast.Name = "MenuToast"
toast.AnchorPoint = Vector2.new(0, 0.5)
toast.Position = UDim2.new(0, 226, 0.5, 0)
toast.Size = UDim2.fromOffset(230, 42)
toast.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBlack
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
toast.TextStrokeTransparency = 1
toast.TextScaled = true
toast.TextTransparency = 1
toast.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = toast

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(0, 0, 0)
toastStroke.Thickness = 3
toastStroke.Transparency = 1
toastStroke.Parent = toast

local function showToast(message)
	toast.Text = message
	TweenService:Create(toast, TweenInfo.new(0.12), {
		BackgroundTransparency = 0.15,
		TextTransparency = 0,
		TextStrokeTransparency = 0,
	}):Play()
	TweenService:Create(toastStroke, TweenInfo.new(0.12), {
		Transparency = 0,
	}):Play()

	task.delay(1.25, function()
		if toast.Text == message then
			TweenService:Create(toast, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.2), {
				Transparency = 1,
			}):Play()
		end
	end)
end

local function pressButton(inner)
	TweenService:Create(inner, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.92, 0.92),
	}):Play()

	task.delay(0.08, function()
		if inner then
			TweenService:Create(inner, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
		end
	end)
end

                                                                            
                                                                                  
                                                                            
                      
local notificationBadges = {}
local NOTIFICATION_BADGE_IMAGE = "rbxassetid://76373998613283"

local function createNotificationBadge(parent, buttonName)
	local badge = Instance.new("ImageLabel")
	badge.Name = buttonName .. "NotificationBadge"
	badge.BackgroundTransparency = 1
	badge.BorderSizePixel = 0
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	                                                                                      
	                                                                                           
	badge.Position = UDim2.new(1, -5, 0, 5)
	badge.Size = UDim2.fromOffset(77, 77)
	badge.Image = NOTIFICATION_BADGE_IMAGE
	badge.ImageTransparency = 0
	badge.ScaleType = Enum.ScaleType.Fit
	badge.Visible = false
	badge.ZIndex = 50
	badge.ClipsDescendants = false
	badge.Parent = parent

	local pulseScale = Instance.new("UIScale")
	pulseScale.Name = "PulseScale"
	pulseScale.Scale = 1
	pulseScale.Parent = badge

	                                                                                
	local pulseInfo = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true, 0.12)
	TweenService:Create(pulseScale, pulseInfo, { Scale = 1.08 }):Play()

	notificationBadges[buttonName] = badge
	return badge
end

local function setNotification(buttonName, available)
	local badge = notificationBadges[buttonName]
	if badge then
		badge.Visible = available == true
	end
end

                                                   
                                                                         
                                                                 
local buttonLabels = {}
local buttonLabelConstraints = {}

for index, button in ipairs(Buttons) do
	local imageButton = Instance.new("ImageButton")
	imageButton.Name = button.Name .. "Button"
	imageButton.LayoutOrder = index
	imageButton.BackgroundTransparency = 1
	imageButton.BorderSizePixel = 0
	imageButton.AutoButtonColor = false
	imageButton.Size = UDim2.fromScale(1, 1)
	imageButton.Parent = container

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(1, 1)
	inner.BackgroundTransparency = 1
	inner.Parent = imageButton

	local background = Instance.new("Frame")
	background.Name = "StudBackground"
	background.BackgroundColor3 = button.Color
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.ZIndex = 1
	background.Parent = inner

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 10)
	backgroundCorner.Parent = background

	local backgroundStroke = Instance.new("UIStroke")
	backgroundStroke.Name = "BlackOutline"
	backgroundStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	backgroundStroke.Color = Color3.fromRGB(0, 0, 0)
	backgroundStroke.Thickness = 3
	backgroundStroke.LineJoinMode = Enum.LineJoinMode.Round
	backgroundStroke.Parent = background

	                                                                       
	                                                                 
	local studSurface = StudUi.AddSurface(background, 2, 10, 4, 4)

	                                                
	                                                                          
	                                                                         
	                                                                            
	                                                                          
	                                  
	studSurface.TileSize = UDim2.new(1, 0, 3.75 / 4, 0)

	local iconOffset = button.IconOffset or Vector2.new(0, 0)

	local iconShadow = Instance.new("ImageLabel")
	iconShadow.Name = "IconShadow"
	iconShadow.BackgroundTransparency = 1
	iconShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	iconShadow.Position = UDim2.new(0.5, iconOffset.X + 2, 0.5, iconOffset.Y + 2)
	local iconSize = button.IconSize
	if UserInputService.TouchEnabled then
		iconSize = UDim2.fromOffset(
			math.floor(button.IconSize.X.Offset * 0.70 + 0.5),
			math.floor(button.IconSize.Y.Offset * 0.70 + 0.5)
		)
	end
	iconShadow.Size = iconSize
	iconShadow.Image = button.Icon
	iconShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	iconShadow.ImageTransparency = 0.18
	iconShadow.ScaleType = Enum.ScaleType.Fit
	iconShadow.Visible = button.Icon ~= ""
	iconShadow.ZIndex = 3
	iconShadow.Parent = background

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, iconOffset.X, 0.5, iconOffset.Y)
	icon.Size = iconSize
	icon.Image = button.Icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = button.Icon ~= ""
	icon.ZIndex = 4
	icon.Parent = background

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	                                                                       
	                                                                
	label.Position = UDim2.new(0, 2, 1, -54)
	label.Size = UDim2.new(1, -4, 0, 54)
	label.Font = Enum.Font.FredokaOne
	label.Text = button.Name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = false
	label.TextYAlignment = Enum.TextYAlignment.Bottom
	label.ZIndex = 5
	label.Parent = background

	local labelSizeConstraint = Instance.new("UITextSizeConstraint")
	labelSizeConstraint.MinTextSize = UserInputService.TouchEnabled and 10 or 24
	labelSizeConstraint.MaxTextSize = UserInputService.TouchEnabled and 30 or 62
	labelSizeConstraint.Parent = label

	buttonLabels[button.Name] = label
	buttonLabelConstraints[button.Name] = labelSizeConstraint

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Name = "BlackTextOutline"
	labelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	labelStroke.Color = Color3.fromRGB(0, 0, 0)
	labelStroke.Thickness = 2.5
	labelStroke.LineJoinMode = Enum.LineJoinMode.Round
	labelStroke.Parent = label

	createNotificationBadge(imageButton, button.Name)

	imageButton.MouseEnter:Connect(function()
		TweenService:Create(inner, TweenInfo.new(0.12), {
			Size = UDim2.fromScale(1.06, 1.06),
		}):Play()
		TweenService:Create(icon, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 17,
		}):Play()
		TweenService:Create(iconShadow, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 17,
		}):Play()
	end)

	imageButton.MouseLeave:Connect(function()
		TweenService:Create(inner, TweenInfo.new(0.12), {
			Size = UDim2.fromScale(1, 1),
		}):Play()
		TweenService:Create(icon, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0,
		}):Play()
		TweenService:Create(iconShadow, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = 0,
		}):Play()
	end)

	imageButton.Activated:Connect(function()
		playUiClickSound()
		pressButton(inner)

		if MenuEvents.Request(button.Name) then
			return
		end

		showToast(button.Name .. " menu is not available yet")
	end)
end

                           
                                                                          
                                                                     
                                                        
                                                                                  
                                                        
local function hasAffordableShopItem(state, entriesKey)
	if type(state) ~= "table" then
		return false
	end

	local wins = tonumber(state.Wins) or 0
	local owned = type(state.Owned) == "table" and state.Owned or {}
	local entries = type(state[entriesKey]) == "table" and state[entriesKey] or {}

	for _, entry in ipairs(entries) do
		if type(entry) == "table"
			and type(entry.Id) == "string"
			and entry.ShopEnabled ~= false
			and owned[entry.Id] ~= true
			and wins >= (tonumber(entry.WinsCost) or math.huge)
		then
			return true
		end
	end

	return false
end

local function updateRebirthNotification()
	local level = tonumber(player:GetAttribute("Level")) or 0
	local required = tonumber(player:GetAttribute("NextRebirthLevelRequired"))

	setNotification("Rebirth", required ~= nil and required > 0 and level >= required)
end

local EVOLVE_NOTIFICATION_CHAIN = SuitCatalog.Ordered

local evolveOwned = {}
local evolveStateReady = false

local function updateEvolveNotification()
	if not evolveStateReady then
		setNotification("Evolve", false)
		return
	end

	local level = tonumber(player:GetAttribute("Level")) or 0
	local nextEntry = nil
	for _, entry in ipairs(EVOLVE_NOTIFICATION_CHAIN) do
		if evolveOwned[entry.Id] ~= true then
			nextEntry = entry
			break
		end
	end

	setNotification(
		"Evolve",
		nextEntry ~= nil and level >= (tonumber(nextEntry.RequiredLevel) or math.huge)
	)
end

player:GetAttributeChangedSignal("Level"):Connect(function()
	updateRebirthNotification()
	updateEvolveNotification()
end)
player:GetAttributeChangedSignal("NextRebirthLevelRequired"):Connect(updateRebirthNotification)

updateRebirthNotification()
updateEvolveNotification()

                                                                             
                                                                            
                                                      
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local trailUpdate = remotes:WaitForChild("TrailShopUpdate", 20)
	local trailAction = remotes:WaitForChild("TrailShopAction", 20)
	if trailUpdate and trailUpdate:IsA("RemoteEvent") then
		trailUpdate.OnClientEvent:Connect(function(state)
			setNotification("Trails", hasAffordableShopItem(state, "Trails"))
		end)
	end
	if trailAction and trailAction:IsA("RemoteEvent") then
		trailAction:FireServer("RequestState")
	end

	local auraUpdate = remotes:WaitForChild("AuraShopUpdate", 20)
	local auraAction = remotes:WaitForChild("AuraShopAction", 20)
	if auraUpdate and auraUpdate:IsA("RemoteEvent") then
		auraUpdate.OnClientEvent:Connect(function(state)
			setNotification("Auras", hasAffordableShopItem(state, "Auras"))
		end)
	end
	if auraAction and auraAction:IsA("RemoteEvent") then
		auraAction:FireServer("RequestState")
	end

	local dailyGeneration = 0
	local dailyUpdate = remotes:WaitForChild("DailyLoginUpdate", 20)
	local dailyRequest = remotes:WaitForChild("DailyLoginRequest", 20)
	if dailyUpdate and dailyUpdate:IsA("RemoteEvent") then
		dailyUpdate.OnClientEvent:Connect(function(state)
			dailyGeneration += 1
			local generation = dailyGeneration
			local canClaim = type(state) == "table" and state.CanClaim == true
			setNotification("Daily", canClaim)

			                                                                      
			                                                                     
			if not canClaim and type(state) == "table" then
				local remaining = tonumber(state.SecondsRemaining) or 0
				if remaining > 0 then
					task.delay(remaining + 0.05, function()
						if generation == dailyGeneration then
							setNotification("Daily", true)
						end
					end)
				end
			end
		end)
	end
	if dailyRequest and dailyRequest:IsA("RemoteEvent") then
		dailyRequest:FireServer("Refresh")
	end

	local skinIndexUpdate = remotes:WaitForChild("SkinIndexUpdate", 20)
	local skinIndexRequest = remotes:WaitForChild("SkinIndexRequest", 20)
	if skinIndexUpdate and skinIndexUpdate:IsA("RemoteEvent") then
		skinIndexUpdate.OnClientEvent:Connect(function(state)
			if type(state) == "table" and type(state.Owned) == "table" then
				evolveOwned = state.Owned
				evolveStateReady = true
				updateEvolveNotification()
			end
		end)
	end
	if skinIndexRequest and skinIndexRequest:IsA("RemoteEvent") then
		skinIndexRequest:FireServer("RequestState")
	end
end)

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local availableHeight = math.max(220, viewport.Y - inset.Y - 16)
	local heightScale = availableHeight / container.Size.Y.Offset
	local leftMargin

	                                                                          
	                                                                         
	local isTouch = UserInputService.TouchEnabled
	local isTablet = isTouch and math.min(viewport.X, viewport.Y) >= 600
	local isPhone = isTouch and not isTablet

	                                                      
	                                                                      
	for name, label in pairs(buttonLabels) do
		label.Position = UDim2.new(0, (isPhone and name == "Teleport") and 0 or 2, 1, -54)

		local constraint = buttonLabelConstraints[name]
		if constraint then
			if isTablet then
				constraint.MinTextSize = 12
				constraint.MaxTextSize = 36
			elseif isPhone then
				constraint.MinTextSize = 10
				constraint.MaxTextSize = 30
			else
				constraint.MinTextSize = 24
				constraint.MaxTextSize = 62
			end
		end
	end

	if isTouch then
		                                                                 
		scale.Scale = math.clamp(math.min(heightScale, viewport.X / 1700, 0.58), 0.44, 0.58)
		leftMargin = 8
		toast.Size = UDim2.fromOffset(180, 34)

		container.AnchorPoint = Vector2.new(0, 0)
		                                                                    
		                                             
		local touchTopOffset = isTablet and 28 or 42
		container.Position = UDim2.new(0, leftMargin, 0, inset.Y + touchTopOffset)
		toast.AnchorPoint = Vector2.new(0, 0.5)
		toast.Position = UDim2.new(
			0,
			leftMargin + math.floor(container.Size.X.Offset * scale.Scale) + 14,
			0,
			inset.Y + 122
		)
	else
		scale.Scale = math.clamp(math.min(heightScale, viewport.X / 1500, 1.1), 0.72, 1.1)
		leftMargin = 14
		toast.Size = UDim2.fromOffset(230, 42)

		local usableCenterOffset = math.floor(inset.Y * 0.5)
		container.AnchorPoint = Vector2.new(0, 0.5)
		container.Position = UDim2.new(0, leftMargin, 0.5, usableCenterOffset)
		toast.AnchorPoint = Vector2.new(0, 0.5)
		toast.Position = UDim2.new(
			0,
			leftMargin + math.floor(container.Size.X.Offset * scale.Scale) + 14,
			0.5,
			usableCenterOffset
		)
	end
end

updateScale()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end


                                     
                                                                                                   
local function ensureLeftMenuAlive()
	if screenGui and screenGui.Parent ~= playerGui then
		screenGui.Parent = playerGui
	end
end

player.CharacterAdded:Connect(function()
	task.defer(ensureLeftMenuAlive)
	task.delay(0.5, ensureLeftMenuAlive)
end)

print("[LeftButtonMenu] V306DT loaded. Every left button closes first, then opens the selected ready menu.")
