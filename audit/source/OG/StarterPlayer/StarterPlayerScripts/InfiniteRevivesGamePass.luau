         
                                                                               
                                       

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PurchaseButtonSound = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PurchaseButtonSound"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local passId = tonumber(Config.InfiniteRevivesGamePassId) or 0
local GREEN = Color3.fromRGB(91, 238, 53)
local promptBusy = false

local old = playerGui:FindFirstChild("InfiniteRevivesGamePassHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "InfiniteRevivesGamePassHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 44
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "InfiniteRevivesHolder"
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.new(1, -24, 0.58, 95)
                                                                 
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
button.Name = "InfiniteRevivesButton"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundColor3 = GREEN
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

StudUi.AddSurface(button, 2, 14, 8, 2)

local heart = Instance.new("ImageLabel")
heart.Name = "HeartBackgroundIcon"
heart.BackgroundTransparency = 1
heart.AnchorPoint = Vector2.new(0.5, 0.5)
heart.Position = UDim2.new(0.5, 0, 0.52, 0)
heart.Size = UserInputService.TouchEnabled and UDim2.fromOffset(66, 66) or UDim2.fromOffset(94, 94)
heart.Image = tostring(Config.InfiniteRevivesIconImage or Config.ReviveIconImage or "rbxthumb://type=Asset&id=12492678216&w=420&h=420")
heart.ImageColor3 = Color3.fromRGB(255, 255, 255)
heart.ImageTransparency = 0.10
heart.ScaleType = Enum.ScaleType.Fit
heart.ZIndex = 3
heart.Parent = button

local titleGroup = Instance.new("Frame")
titleGroup.Name = "InfiniteRevivesTextGroup"
titleGroup.BackgroundTransparency = 1
titleGroup.AnchorPoint = Vector2.new(0.5, 0.5)
titleGroup.Position = UDim2.new(0.5, 0, 0.57, -5)
titleGroup.Size = UDim2.new(0.72, 0, 0.62, 0)
titleGroup.ZIndex = 5
titleGroup.Parent = button

local function createTitleLine(name, textValue, yScale)
	local line = Instance.new("TextLabel")
	line.Name = name
	line.BackgroundTransparency = 1
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, yScale, 0)
	line.Size = UDim2.new(1, 0, 0.48, 0)
	line.Font = Enum.Font.FredokaOne
	line.Text = textValue
	line.TextColor3 = Color3.fromRGB(255, 255, 255)
	line.TextScaled = true
	line.TextWrapped = false
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextYAlignment = Enum.TextYAlignment.Center
	line.ZIndex = 5
	line.Parent = titleGroup

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = UserInputService.TouchEnabled and 8 or 22
	constraint.MaxTextSize = UserInputService.TouchEnabled and 17 or 38
	constraint.Parent = line

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = line

	return line
end

createTitleLine("InfiniteLine", "Infinite", 0.28)
createTitleLine("RevivesLine", "Revives", 0.74)

local priceLabel = Instance.new("TextLabel")
priceLabel.Name = "PriceLabel"
priceLabel.BackgroundTransparency = 1
priceLabel.Position = UDim2.fromOffset(3, -8)
priceLabel.Size = UDim2.fromOffset(128, 46)
priceLabel.Rotation = -11
priceLabel.Font = Enum.Font.FredokaOne
priceLabel.Text = "R$ ..."
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

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({heart})
	end)
end)

local function refreshVisibility()
	local ownershipChecked = player:GetAttribute("InfiniteRevivesOwnershipChecked") == true
	local owned = player:GetAttribute("InfiniteRevivesOwned") == true
	holder.Visible = passId > 0 and not owned and (ownershipChecked or RunService:IsStudio())
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

	                                                                           
	                                                
	local renderedButtonHeight = holder.Size.Y.Offset * responsiveScale.Scale
	holder.Position = UDim2.new(1, xOffset, yScale, renderedButtonHeight + 7)
end

button.Activated:Connect(function()
	if promptBusy or not holder.Visible or passId <= 0 then
		return
	end
	promptBusy = true
	PurchaseButtonSound.Play()
	animatePress()
	task.wait(0.08)

	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	if not ok then
		warn("[InfiniteRevivesGamePass] Could not open Game Pass prompt: " .. tostring(err))
	end
	task.delay(0.8, function()
		promptBusy = false
	end)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasedPlayer, purchasedPassId, purchaseSuccess)
	if purchasedPlayer == player
		and tonumber(purchasedPassId) == passId
		and purchaseSuccess == true
	then
		holder.Visible = false
	end
end)

player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(refreshVisibility)
player:GetAttributeChangedSignal("InfiniteRevivesOwnershipChecked"):Connect(refreshVisibility)

task.spawn(function()
	if passId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		priceLabel.Text = "R$ " .. tostring(math.floor(info.PriceInRobux))
	end
end)

updateResponsiveLayout()
refreshVisibility()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateResponsiveLayout()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
end)

print("[InfiniteRevivesGamePass] V306DV loaded with a fixed two-line Infinite Revives label on every screen size.")
