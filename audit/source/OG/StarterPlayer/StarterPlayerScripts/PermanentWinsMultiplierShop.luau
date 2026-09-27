         
                                                                               
                                                 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DailyRewards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewards"))
local PurchaseButtonSound = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PurchaseButtonSound"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local GOLD = Color3.fromRGB(255, 187, 38)
local products = Config.PermanentWinsMultiplierProducts or {}

local old = playerGui:FindFirstChild("PermanentWinsMultiplierHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PermanentWinsMultiplierHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 44
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "PermanentWinsMultiplierHolder"
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -24, 0.58, 0)
holder.Size = UDim2.fromOffset(330, 88)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Visible = false
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 0.82
responsiveScale.Parent = holder

local button = Instance.new("ImageButton")
button.Name = "PermanentWinsMultiplierButton"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundColor3 = GOLD
button.BackgroundTransparency = 0
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.ZIndex = 1
button.Parent = holder

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = button

local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(0, 0, 0)
border.Thickness = 3
border.LineJoinMode = Enum.LineJoinMode.Round
border.Parent = button

local studSurface = StudUi.AddSurface(button, 2, 14, 8, 2)
local studGradient = studSurface:FindFirstChild("StudSurfaceGradient")

local winsIcon = Instance.new("ImageLabel")
winsIcon.Name = "WinsTrophyIcon"
winsIcon.BackgroundTransparency = 1
winsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
winsIcon.Position = UDim2.new(0.5, 0, 0.52, 0)
winsIcon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(68, 68) or UDim2.fromOffset(94, 94)
winsIcon.Image = DailyRewards.WinsIconImage
winsIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
winsIcon.ImageTransparency = 0.10
winsIcon.ZIndex = 3
winsIcon.Parent = button

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "MultiplierText"
amountLabel.BackgroundTransparency = 1
amountLabel.AnchorPoint = Vector2.new(0.5, 0.5)
amountLabel.Position = UDim2.new(0.5, 0, 0.56, -7)
amountLabel.Size = UDim2.new(0.94, 0, 0.88, 0)
amountLabel.Font = Enum.Font.FredokaOne
amountLabel.Text = "x2 Wins"
amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
amountLabel.TextScaled = true
amountLabel.TextWrapped = false
amountLabel.TextXAlignment = Enum.TextXAlignment.Center
amountLabel.TextYAlignment = Enum.TextYAlignment.Center
amountLabel.ZIndex = 5
amountLabel.Parent = button

local amountConstraint = Instance.new("UITextSizeConstraint")
amountConstraint.MinTextSize = UserInputService.TouchEnabled and 16 or 60
amountConstraint.MaxTextSize = UserInputService.TouchEnabled and 42 or 133
amountConstraint.Parent = amountLabel

local amountStroke = Instance.new("UIStroke")
amountStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
amountStroke.Color = Color3.fromRGB(0, 0, 0)
amountStroke.Thickness = 4
amountStroke.LineJoinMode = Enum.LineJoinMode.Round
amountStroke.Parent = amountLabel

local priceLabel = Instance.new("TextLabel")
priceLabel.Name = "PriceLabel"
priceLabel.BackgroundTransparency = 1
priceLabel.Position = UDim2.fromOffset(3, -8)
priceLabel.Size = UDim2.fromOffset(128, 46)
priceLabel.Rotation = -11
priceLabel.Font = Enum.Font.FredokaOne
priceLabel.Text = "R$ 3"
priceLabel.TextColor3 = Color3.fromRGB(124, 255, 65)
priceLabel.TextScaled = true
priceLabel.TextXAlignment = Enum.TextXAlignment.Left
priceLabel.TextYAlignment = Enum.TextYAlignment.Center
priceLabel.ZIndex = 6
priceLabel.Parent = button

local priceConstraint = Instance.new("UITextSizeConstraint")
priceConstraint.MinTextSize = UserInputService.TouchEnabled and 6 or 19
priceConstraint.MaxTextSize = UserInputService.TouchEnabled and 14 or 32
priceConstraint.Parent = priceLabel

local priceStroke = Instance.new("UIStroke")
priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 3
priceStroke.LineJoinMode = Enum.LineJoinMode.Round
priceStroke.Parent = priceLabel

local pressScale = Instance.new("UIScale")
pressScale.Name = "PressScale"
pressScale.Scale = 1
pressScale.Parent = button

local currentProduct = nil
local promptBusy = false
local themeMode = "Gold"

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 180, 45)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 65)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(65, 235, 115)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 210, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(105, 90, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(235, 65, 255)),
})

local GALACTIC = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(88, 42, 205)),
	ColorSequenceKeypoint.new(0.22, Color3.fromRGB(130, 58, 255)),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(35, 155, 255)),
	ColorSequenceKeypoint.new(0.72, Color3.fromRGB(155, 68, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(58, 82, 205)),
})

local function clearThemeGradient()
	local oldGradient = button:FindFirstChild("PermanentThemeGradient")
	if oldGradient then
		oldGradient:Destroy()
	end
end

local function applyTheme(theme)
	themeMode = theme or "Gold"
	clearThemeGradient()

	if themeMode == "Rainbow" then
		button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		studSurface.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		if studGradient then
			studGradient.Color = RAINBOW
			studGradient.Rotation = 0
		end
		local gradient = Instance.new("UIGradient")
		gradient.Name = "PermanentThemeGradient"
		gradient.Color = RAINBOW
		gradient.Parent = button
	elseif themeMode == "Galactic" then
		button.BackgroundColor3 = Color3.fromRGB(80, 42, 185)
		studSurface.BackgroundColor3 = Color3.fromRGB(80, 42, 185)
		if studGradient then
			studGradient.Color = GALACTIC
			studGradient.Rotation = 0
		end
		local gradient = Instance.new("UIGradient")
		gradient.Name = "PermanentThemeGradient"
		gradient.Color = GALACTIC
		gradient.Parent = button
	else
		button.BackgroundColor3 = GOLD
		studSurface.BackgroundColor3 = GOLD
		if studGradient then
			studGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 248, 248)),
			})
			studGradient.Rotation = -90
		end
	end
end

local function getCurrentMultiplier()
	local value = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
	if value ~= value or value == math.huge or value == -math.huge then
		return 1
	end
	return math.max(1, value)
end

local function chooseProduct()
	local current = getCurrentMultiplier()
	if current < 2 then
		return products[1]
	elseif current < 4 then
		return products[2]
	end
	return products[3]
end

local function refreshButton()
	currentProduct = chooseProduct()
	if not currentProduct then
		holder.Visible = false
		return
	end

	amountLabel.Text = tostring(currentProduct.Label or "x2 Wins")
	priceLabel.Text = "R$ " .. tostring(tonumber(currentProduct.PriceRobux) or 0)
	applyTheme(currentProduct.Theme)
	holder.Visible = player:GetAttribute("DataLoaded") == true
end

local function animatePress()
	TweenService:Create(pressScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.94,
	}):Play()
	task.delay(0.07, function()
		if pressScale.Parent then
			TweenService:Create(pressScale, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

button.Activated:Connect(function()
	if promptBusy then
		return
	end

	refreshButton()
	local productId = currentProduct and tonumber(currentProduct.ProductId)
	if not productId or productId <= 0 then
		return
	end

	promptBusy = true
	PurchaseButtonSound.Play()
	animatePress()
	task.wait(0.08)
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[PermanentWinsMultiplierShop] Could not open purchase prompt: " .. tostring(err))
	end
	task.delay(0.75, function()
		promptBusy = false
	end)
end)

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(viewport.X / 1920, viewport.Y / 1080)
	local isPhone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 600
	local xOffset
	local yScale

	if UserInputService.TouchEnabled then
		responsiveScale.Scale = math.clamp(fit * 0.58, 0.22, 0.52)
		xOffset = -8
		yScale = isPhone and 0.50 or 0.55
	else
		responsiveScale.Scale = math.clamp(viewport.X / 1920, 0.58, 0.82)
		xOffset = -24
		yScale = 0.58
	end

	                                                                             
	                                                                       
	holder.Position = UDim2.new(1, xOffset, yScale, 0)
end

RunService.RenderStepped:Connect(function()
	if studGradient and (themeMode == "Rainbow" or themeMode == "Galactic") then
		studGradient.Rotation = (os.clock() * (themeMode == "Rainbow" and 20 or 8)) % 360
	end
	local gradient = button:FindFirstChild("PermanentThemeGradient")
	if gradient and (themeMode == "Rainbow" or themeMode == "Galactic") then
		gradient.Rotation = (os.clock() * (themeMode == "Rainbow" and 20 or 8)) % 360
	end
end)

player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(refreshButton)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refreshButton)

updateResponsiveLayout()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateResponsiveLayout()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
end)

task.spawn(function()
	while player.Parent and player:GetAttribute("DataLoaded") ~= true do
		task.wait(0.05)
	end
	refreshButton()
end)

print("[PermanentWinsMultiplierShop] V306DS loaded with the shared Wins purchase-button sound.")
