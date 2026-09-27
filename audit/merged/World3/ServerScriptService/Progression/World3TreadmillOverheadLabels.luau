-- World3TreadmillOverheadLabels.server.luau
-- Signs over the treadmills in World 3's lobby, in World 2's style: the Speed multiplier
-- on top and, under it, what unlocks the treadmill (Rebirths, or the game pass with its
-- live Robux price). The Basic treadmill is the starter: its sign just says so.
--
-- Everything shown comes from Config.World3TreadmillProfiles, the same table
-- Progression.TreadmillTraining enforces, so a sign can never promise a different gain or
-- requirement than the treadmill applies. The signs hang over each treadmill's belt
-- (its nested "Treadmil" model) and face the lobby spawn.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld3Place ~= true then
	return
end

local PROFILES = Config.World3TreadmillProfiles
local LOBBY_NAME = "Lobby"
local RUNTIME_FOLDER_NAME = "World3TreadmillSigns_Runtime"
local REBIRTH_ICON = "rbxassetid://98204886250993"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
-- World 2's sign: a 360 x 144 canvas on an 11.5 stud wide board.
local CANVAS_WIDTH = 360
local CANVAS_HEIGHT = 144
local SIGN_WIDTH = 11.5
local SIGN_HEIGHT = SIGN_WIDTH * CANVAS_HEIGHT / CANVAS_WIDTH
local SIGN_DEPTH = 0.05
local SIGN_GAP_ABOVE_BELT = 3.5
local TITLE_TEXT_SIZE = 46
local STARTER_TEXT_SIZE = 39
local REQUIREMENT_TEXT_SIZE = 22
local PRICE_TEXT_SIZE = 30
local REBIRTH_ICON_SIZE = 60
local ROBUX_ICON_SIZE = 44
local TEXT_OUTLINE_THICKNESS = 3

local Service = {}

-- What a sign says for a profile: { Title, TitleColor, Requirement, Icon, GamePassId }.
function Service.SignContent(profile)
	local gamePassId = math.max(0, math.floor(tonumber(profile.GamePassId) or 0))
	local rebirths = math.max(0, math.floor(tonumber(profile.RequiredRebirths) or 0))
	local content = {
		Title = tostring(profile.DisplayText or ""),
		TitleColor = profile.PopupColor or Color3.fromRGB(255, 255, 255),
		GamePassId = if gamePassId > 0 then gamePassId else nil,
	}
	if gamePassId > 0 then
		content.Requirement = "..."
		content.Icon = ROBUX_ICON
	elseif rebirths > 0 then
		content.Requirement = rebirths .. " Rebirths\nRequired"
		content.Icon = REBIRTH_ICON
	end
	return content
end

local function partsBounds(root)
	local minimum, maximum = nil, nil
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size * 0.5
			local centre = part.CFrame.Position
			local low = centre - half
			local high = centre + half
			minimum = if minimum then Vector3.new(math.min(minimum.X, low.X), math.min(minimum.Y, low.Y), math.min(minimum.Z, low.Z)) else low
			maximum = if maximum then Vector3.new(math.max(maximum.X, high.X), math.max(maximum.Y, high.Y), math.max(maximum.Z, high.Z)) else high
		end
	end
	return minimum, maximum
end

-- Where the sign for `treadmill` goes: over the middle of its belt, facing `lookAt`.
function Service.SignCFrame(treadmill, lookAt)
	local belt = treadmill:FindFirstChild("Treadmil", true) or treadmill
	local minimum, maximum = partsBounds(belt)
	if not minimum then
		return nil
	end
	local position = Vector3.new((minimum.X + maximum.X) / 2, maximum.Y + SIGN_GAP_ABOVE_BELT + SIGN_HEIGHT / 2, (minimum.Z + maximum.Z) / 2)
	local toward = Vector3.new(lookAt.X - position.X, 0, lookAt.Z - position.Z)
	if toward.Magnitude < 0.01 then
		toward = Vector3.new(0, 0, 1)
	end
	-- Built from its axes: level, looking at the spawn.
	local look = toward.Unit
	return CFrame.fromMatrix(position, look:Cross(Vector3.yAxis).Unit, Vector3.yAxis, -look)
end

local function outlinedLabel(parent, name, position, size, text, color, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = false
	label.ZIndex = 2
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = TEXT_OUTLINE_THICKNESS
	stroke.Parent = label
	return label
end

local function buildFace(sign, face, content)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TreadmillSign"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(CANVAS_WIDTH, CANVAS_HEIGHT)
	surface.LightInfluence = 0
	surface.Parent = sign

	if not content.Requirement then
		-- The starter: two lines ("Starter" / "x3 Speed") filling the sign.
		outlinedLabel(surface, "Steps", UDim2.fromOffset(0, 0), UDim2.fromOffset(CANVAS_WIDTH, 126), content.Title, content.TitleColor, STARTER_TEXT_SIZE)
		return nil
	end
	outlinedLabel(surface, "Steps", UDim2.fromOffset(0, 0), UDim2.fromOffset(CANVAS_WIDTH, 58), content.Title, content.TitleColor, TITLE_TEXT_SIZE)

	local row = Instance.new("Frame")
	row.Name = "RequirementRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 60)
	row.Size = UDim2.fromOffset(CANVAS_WIDTH, 76)
	row.Parent = surface
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local paid = content.GamePassId ~= nil
	local iconSize = if paid then ROBUX_ICON_SIZE else REBIRTH_ICON_SIZE
	local icon = Instance.new("ImageLabel")
	icon.Name = if paid then "RobuxIcon" else "RebirthIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	icon.Image = content.Icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.LayoutOrder = 1
	icon.ZIndex = 2
	icon.Parent = row

	local requirement = outlinedLabel(row, "Requirement", UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 76), content.Requirement,
		Color3.fromRGB(255, 255, 255), if paid then PRICE_TEXT_SIZE else REQUIREMENT_TEXT_SIZE)
	requirement.AutomaticSize = Enum.AutomaticSize.X
	requirement.LayoutOrder = 2
	return requirement
end

local function showPrice(labels, gamePassId)
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
			end)
			local price = ok and type(info) == "table" and tonumber(info.PriceInRobux)
			if price and price > 0 then
				for _, label in labels do
					label.Text = tostring(math.floor(price))
				end
				return
			end
			task.wait(attempt * 1.25)
		end
		warn("[World3TreadmillOverheadLabels] Could not read the price of game pass " .. gamePassId)
	end)
end

local lobby = Workspace:FindFirstChild(LOBBY_NAME)
local spawn = lobby and lobby:FindFirstChildOfClass("SpawnLocation")
local folder = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = RUNTIME_FOLDER_NAME

local signs = {}
Service.Signs = signs
for _, name in { "Basic", "Diamond", "Needoh", "Admin", "Hacker" } do
	local profile = PROFILES[name]
	local treadmill = lobby and lobby:FindFirstChild(name)
	local cframe = profile and treadmill and spawn and Service.SignCFrame(treadmill, spawn.CFrame.Position)
	if cframe then
		local content = Service.SignContent(profile)
		local sign = Instance.new("Part")
		sign.Name = name .. "Sign"
		sign.Anchored = true
		sign.CanCollide = false
		sign.CanTouch = false
		sign.CanQuery = false
		sign.CastShadow = false
		sign.Transparency = 1
		sign.Size = Vector3.new(SIGN_WIDTH, SIGN_HEIGHT, SIGN_DEPTH)
		sign.CFrame = cframe
		sign:SetAttribute("TreadmillProfile", name)
		sign.Parent = folder
		local requirements = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local requirement = buildFace(sign, face, content)
			if requirement then
				table.insert(requirements, requirement)
			end
		end
		if content.GamePassId then
			showPrice(requirements, content.GamePassId)
		end
		signs[name] = sign
	else
		warn("[World3TreadmillOverheadLabels] No sign for " .. name .. ": the treadmill, its profile or the lobby spawn is missing")
	end
end
folder.Parent = Workspace

print("[World3TreadmillOverheadLabels] signs over Basic, Diamond, Needoh, Admin and Hacker from Config.World3TreadmillProfiles")
return Service
