       
                                                                         
                                                                                  

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REBIRTH_ICON_IMAGE = "rbxassetid://98204886250993"
local WINS_ICON_IMAGE = "rbxassetid://15540211845"

local old = playerGui:FindFirstChild("RebirthCounterHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "RebirthCounterHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 46
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "RebirthAndWinsHolder"
holder.AnchorPoint = Vector2.new(0, 1)
holder.Position = UDim2.new(0, 22, 1, -28)
holder.Size = UDim2.fromOffset(304, 164)
holder.BackgroundTransparency = 1
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Parent = holder

local function addTextStroke(label)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

local function formatAmount(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))

	while true do
		local changed
		text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then
			return text
		end
	end
end

local function makeRow(name, y, iconImage, textColor)
	local row = Instance.new("Frame")
	row.Name = name .. "Row"
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.fromOffset(304, 76)
	row.BackgroundTransparency = 1
	row.Parent = holder

	local pulse = Instance.new("UIScale")
	pulse.Name = "PulseScale"
	pulse.Scale = 1
	pulse.Parent = row

	local icon = Instance.new("ImageLabel")
	icon.Name = name .. "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromOffset(40, 38)
	icon.Size = UDim2.fromOffset(78, 78)
	icon.BackgroundTransparency = 1
	icon.Image = iconImage
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 2
	icon.Parent = row

	local amount = Instance.new("TextLabel")
	amount.Name = name .. "Amount"
	amount.AnchorPoint = Vector2.new(0, 0.5)
	amount.Position = UDim2.new(0, 88, 0.5, 0)
	amount.Size = UDim2.fromOffset(208, 70)
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.FredokaOne
	amount.Text = "0"
	amount.TextColor3 = textColor
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextYAlignment = Enum.TextYAlignment.Center
	amount.ZIndex = 2
	amount.Parent = row
	addTextStroke(amount)

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 24
	sizeConstraint.MaxTextSize = 53
	sizeConstraint.Parent = amount

	return {
		Row = row,
		Pulse = pulse,
		Icon = icon,
		Amount = amount,
		LastValue = nil,
	}
end

local rebirthRow = makeRow(
	"Rebirth",
	0,
	REBIRTH_ICON_IMAGE,
	Color3.fromRGB(255, 70, 225)
)
local winsRow = makeRow(
	"Wins",
	84,
	WINS_ICON_IMAGE,
	Color3.fromRGB(255, 205, 0)
)

local function readStat(name)
	if name == "Rebirths" then
		local attribute = player:GetAttribute("Rebirths")
		if typeof(attribute) == "number" then
			return attribute
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		return tonumber(value.Value) or 0
	end

	return 0
end

local function updateRow(row, value, animate)
	value = math.max(0, math.floor(tonumber(value) or 0))
	row.Amount.Text = formatAmount(value)

	if animate and row.LastValue ~= nil and value > row.LastValue then
		row.Pulse.Scale = 1.14
		TweenService:Create(
			row.Pulse,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Scale = 1}
		):Play()
	end

	row.LastValue = value
end

local function refresh(animateRebirths, animateWins)
	updateRow(rebirthRow, readStat("Rebirths"), animateRebirths)
	updateRow(winsRow, readStat("Wins"), animateWins)
end

local hookedValues = {}

local function hookValue(name, row)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if not value or not value:IsA("ValueBase") or hookedValues[name] == value then
		return
	end

	hookedValues[name] = value
	value:GetPropertyChangedSignal("Value"):Connect(function()
		if value.Parent then
			updateRow(row, value.Value, true)
		end
	end)
end

local function hookLeaderstats()
	hookValue("Rebirths", rebirthRow)
	hookValue("Wins", winsRow)
	refresh(false, false)
end

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local compactMobile = UserInputService.TouchEnabled and viewport.Y <= 700
	local compactDesktop = not UserInputService.TouchEnabled and viewport.Y <= 900
	local widthFit = viewport.X / 1600
	local heightFit = viewport.Y / 900

	if compactMobile then
		responsiveScale.Scale = math.clamp(math.min(widthFit, heightFit) * 0.90, 0.40, 0.56)
		                                                                         
		                                                                         
		local inset = game:GetService("GuiService"):GetGuiInset()
		local menuScale = math.clamp(math.min(math.max(220, viewport.Y - inset.Y - 16) / 410, viewport.X / 1700, 0.58), 0.44, 0.58)
		local renderedMenuHeight = 410 * menuScale
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.new(0, 10, 0, inset.Y + 42 + renderedMenuHeight + 10)
	else
		responsiveScale.Scale = math.clamp(math.min(widthFit, heightFit) * 1.08, 0.76, 1.15)
		holder.AnchorPoint = Vector2.new(0, 1)
		                                                                       
		                                                                         
		local bottomOffset = compactDesktop and 16 or 28
		holder.Position = UDim2.new(0, 22, 1, -bottomOffset)
	end
end

player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	updateRow(rebirthRow, readStat("Rebirths"), true)
end)

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.defer(hookLeaderstats)
	end
end)

updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

hookLeaderstats()
refresh(false, false)

task.spawn(function()
	for _ = 1, 40 do
		task.wait(0.25)
		hookLeaderstats()
	end
end)

print(
	"[RebirthCounterHUD] V306KAJ loaded. Compact-desktop trackers shifted down."
)
