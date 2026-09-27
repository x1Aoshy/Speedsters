-- StarterPackOffer.client.luau
-- Ported from +1 Speedster Escape (OG). The server side of the Starter Pack was
-- already here - the remote, the versioned grant and the Config rewards - but the
-- offer itself was never brought across, so nothing ever showed it to a player.
--
-- Differences from the OG script: it uses the shared purchase click sound, and it
-- checks ownership. The OG had that check commented out and kept pitching the pack
-- to players who had already bought it.

         
                                                                             
                                                                        
                                                                      

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StarterPackClaim = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StarterPackClaim")
local PurchaseButtonSound = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PurchaseButtonSound"))
local HudErgonomics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudErgonomics"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
local GuiService = game:GetService("GuiService")

-- Creator Hub funnel "Monetization_StarterPack": steps 1 (icon clicked) and 2 (prompt
-- shown) are only seen here; the server logs them (Services.FunnelAnalytics).
local function reportFunnelStep(step)
	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local report = remotes and remotes:WaitForChild("FunnelReport", 10)
		if report and report:IsA("RemoteEvent") then
			pcall(report.FireServer, report, "Monetization_StarterPack", step)
		end
	end)
end

local passId = tonumber(Config.StarterPackGamePassId) or 0
local visibleSeconds = math.max(1, tonumber(Config.StarterPackVisibleSeconds) or 17 * 60)
local expiresAt = os.clock() + visibleSeconds
local promptBusy = false
local dismissedThisSession = false

local old = playerGui:FindFirstChild("StarterPackOfferHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StarterPackOfferHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 70
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "StarterPackOfferHolder"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -28, 0, 64)
holder.Size = UDim2.fromOffset(190, 202)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.ClipsDescendants = false
holder.Visible = false
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 0.90
responsiveScale.Parent = holder

local button = Instance.new("ImageButton")
button.Name = "StarterPackButton"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundTransparency = 1
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.ZIndex = 1
button.Parent = holder

local pressScale = Instance.new("UIScale")
pressScale.Name = "PressScale"
pressScale.Scale = 1
pressScale.Parent = button

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.new(0.5, 0, 0, 0)
timer.Size = UDim2.fromOffset(118, 43)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.FredokaOne
timer.Text = "17:00"
timer.TextColor3 = Color3.fromRGB(255, 237, 35)
timer.TextScaled = true
timer.TextXAlignment = Enum.TextXAlignment.Center
timer.ZIndex = 6
timer.Parent = button

local timerConstraint = Instance.new("UITextSizeConstraint")
timerConstraint.MinTextSize = UserInputService.TouchEnabled and 9 or 25
timerConstraint.MaxTextSize = UserInputService.TouchEnabled and 18 or 39
timerConstraint.Parent = timer

local timerStroke = Instance.new("UIStroke")
timerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
timerStroke.Color = Color3.fromRGB(0, 0, 0)
timerStroke.Thickness = 4
timerStroke.LineJoinMode = Enum.LineJoinMode.Round
timerStroke.Parent = timer

local icon = Instance.new("ImageLabel")
icon.Name = "StarterPackIcon"
icon.AnchorPoint = Vector2.new(0.5, 0)
icon.Position = UDim2.new(0.56, 0, 0, 40)
icon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(96, 96) or UDim2.fromOffset(122, 122)
icon.BackgroundTransparency = 1
icon.Image = tostring(Config.StarterPackIconImage or "rbxthumb://type=Asset&id=120522986837915&w=420&h=420")
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = 3
icon.Parent = button

local priceRow = Instance.new("Frame")
priceRow.Name = "RobuxPriceRow"
priceRow.Position = UDim2.fromOffset(0, 59)
priceRow.Size = UDim2.fromOffset(89, 45)
priceRow.BackgroundTransparency = 1
priceRow.ZIndex = 7
priceRow.Parent = button

local robuxIcon = Instance.new("ImageLabel")
robuxIcon.Name = "RobuxIcon"
robuxIcon.AnchorPoint = Vector2.new(0, 0.5)
robuxIcon.Position = UDim2.new(0, 0, 0.5, 0)
robuxIcon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(31, 31) or UDim2.fromOffset(42, 42)
robuxIcon.BackgroundTransparency = 1
robuxIcon.Image = "rbxasset://textures/ui/common/robux.png"
robuxIcon.ImageColor3 = Color3.fromRGB(123, 255, 50)
robuxIcon.ScaleType = Enum.ScaleType.Fit
robuxIcon.ZIndex = 8
robuxIcon.Parent = priceRow

local price = Instance.new("TextLabel")
price.Name = "Price"
price.Position = UDim2.fromOffset(37, 0)
price.Size = UDim2.fromOffset(52, 45)
price.BackgroundTransparency = 1
price.Font = Enum.Font.FredokaOne
price.Text = tostring(tonumber(Config.StarterPackPriceRobux) or 7)
price.TextColor3 = Color3.fromRGB(255, 255, 255)
price.TextScaled = true
price.TextXAlignment = Enum.TextXAlignment.Left
price.ZIndex = 8
price.Parent = priceRow

local priceConstraint = Instance.new("UITextSizeConstraint")
priceConstraint.MinTextSize = UserInputService.TouchEnabled and 9 or 26
priceConstraint.MaxTextSize = UserInputService.TouchEnabled and 18 or 41
priceConstraint.Parent = price

local priceStroke = Instance.new("UIStroke")
priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 4
priceStroke.LineJoinMode = Enum.LineJoinMode.Round
priceStroke.Parent = price

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 157)
title.Size = UDim2.fromOffset(190, 43)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "Starter Pack"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 6
title.Parent = button

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = UserInputService.TouchEnabled and 8 or 24
titleConstraint.MaxTextSize = UserInputService.TouchEnabled and 17 or 39
titleConstraint.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 4
titleStroke.LineJoinMode = Enum.LineJoinMode.Round
titleStroke.Parent = title

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({icon, robuxIcon})
	end)
end)

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The OG script had this check commented out, so it kept selling the pack to
-- players who already owned it. Ownership comes from the server attributes.
local function alreadyOwned()
	return player:GetAttribute("StarterPackOwned") == true
		or player:GetAttribute("StarterPackGranted") == true
end

local function isEligible()
	if alreadyOwned() then
		return false
	end
	return os.clock() < expiresAt and not dismissedThisSession
end

local hudVisible = true

local function refreshVisibility()
	holder.Visible = isEligible() and hudVisible
end

MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible, menuName)
	hudVisible = (visible == true)
	refreshVisibility()
end)

task.defer(function()
	if MenuEvents.AnyOpen and MenuEvents.AnyOpen() then
		hudVisible = false
		refreshVisibility()
	end
end)

for _, attribute in ipairs({ "StarterPackOwned", "StarterPackGranted" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshVisibility)
end

-- Its place and scale come from HudErgonomics, which places the x2 badges beside it too, so
-- the two never overlap. On a console it stays inside the TV's safe zone.
local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local topBar = GuiService:GetGuiInset()
	local box = HudErgonomics.StarterPack(viewport.X, viewport.Y, UserInputService.TouchEnabled, GuiService:IsTenFootInterface(), topBar.Y)
	responsiveScale.Scale = box.Scale
	holder.AnchorPoint = Vector2.new(1, 0)
	title.Position = UDim2.new(0.5, 0, 0, if box.Phone then 140 else 157)
	-- MainHUDController slides the pack away while a menu is open and back to this spot,
	-- so it always reads it here (a copy it kept once went stale: the desktop spot on a
	-- phone, over the x2 Speed badge).
	local base = UDim2.fromOffset(box.Right, box.Top)
	holder:SetAttribute("HudBasePosition", base)
	if hudVisible then
		holder.Position = base
	end
end

-- Attention shake: every few seconds, while the offer is on screen, the pack wiggles
-- (the same Shared.UiShake the Level Up banner uses) and the box gives a small hop.
local UiShake = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiShake"))
local ATTENTION_EVERY_SECONDS = 3.2

local attentionScale = Instance.new("UIScale")
attentionScale.Name = "AttentionScale"
attentionScale.Scale = 1
attentionScale.Parent = icon

task.spawn(function()
	while gui.Parent do
		task.wait(ATTENTION_EVERY_SECONDS)
		if holder.Visible and not promptBusy then
			UiShake.Wiggle(button, 11, 0.65, 8)
			TweenService:Create(attentionScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.15,
			}):Play()
			task.delay(0.12, function()
				if attentionScale.Parent then
					TweenService:Create(attentionScale, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
						Scale = 1,
					}):Play()
				end
			end)
		end
	end
end)

button.Activated:Connect(function()
	if promptBusy or not isEligible() or passId <= 0 then
		return
	end
	reportFunnelStep(1)
	PurchaseButtonSound.Play()
	promptBusy = true
	TweenService:Create(pressScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.92,
	}):Play()
	task.delay(0.08, function()
		if pressScale.Parent then
			TweenService:Create(pressScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)

	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	if not ok then
		warn("[StarterPackOffer] Could not open Game Pass prompt: " .. tostring(err))
	else
		reportFunnelStep(2)
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
		dismissedThisSession = true
		refreshVisibility()

		                                                                    
		                                                                             
		task.spawn(function()
			for attempt = 1, 6 do
				if not gui.Parent then
					return
				end
				StarterPackClaim:FireServer()
				if attempt < 6 then
					task.wait(attempt)
				end
			end
		end)
	end
end)

task.spawn(function()
	if passId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		price.Text = tostring(math.floor(info.PriceInRobux))
	end
end)

task.spawn(function()
	while gui.Parent and os.clock() < expiresAt do
		timer.Text = formatTime(expiresAt - os.clock())
		refreshVisibility()
		task.wait(0.2)
	end
	holder.Visible = false
end)

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

refreshVisibility()
print("[StarterPackOffer] Loaded: timed offer, ownership-aware, verified claim retries.")
