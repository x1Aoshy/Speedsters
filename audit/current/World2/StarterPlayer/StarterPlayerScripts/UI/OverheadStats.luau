local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if not Config.OverheadEnabled then
	return
end

local OVERHEAD_MAX_DISTANCE = Config.OverheadMaxDistance or 10

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
}

local overheads = {}

local function formatSpeed(value)
	value = tonumber(value) or 1

	if value < 1000 then
		return tostring(math.floor(value))
	end

	local tier = math.floor(math.log10(value) / 3) + 1
	if tier <= #SUFFIXES then
		local scaled = value / (1000 ^ (tier - 1))
		if scaled >= 100 then
			return string.format("%.0f%s", scaled, SUFFIXES[tier])
		elseif scaled >= 10 then
			return string.format("%.1f%s", scaled, SUFFIXES[tier])
		else
			return string.format("%.2f%s", scaled, SUFFIXES[tier])
		end
	end

	return string.format("%.2e", value)
end

local function addStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

local function cleanupCharacter(character)
	local existing = character:FindFirstChild("SpeedsterOverhead")
	if existing then
		existing:Destroy()
	end
	overheads[character] = nil
end

local function getSpeedDisplayText(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return "1"
	end

	local speed = leaderstats:FindFirstChild("Speed")
	if not speed then
		return "1"
	end

	return formatSpeed(speed.Value)
end

local function getDisplayNameText(player)
	local name = player.DisplayName
	if type(name) ~= "string" or name == "" then
		name = player.Name
	end
	return name
end

local function updateOverhead(player, character)
	local data = overheads[character]
	if not data then
		return
	end

	local camera = workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart")
	if camera and root then
		local distance = (camera.CFrame.Position - root.Position).Magnitude
		data.Billboard.Enabled = distance <= OVERHEAD_MAX_DISTANCE
	end

	data.NameLabel.Text = getDisplayNameText(player)
	data.SpeedLabel.Text = getSpeedDisplayText(player) .. " Speed"
end

local function attachOverhead(player, character)
	                          
	                                                                     
	if player == localPlayer then
		cleanupCharacter(character)
		return
	end

	cleanupCharacter(character)

	local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpeedsterOverhead"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(260, 70)
	billboard.StudsOffsetWorldSpace = Config.OverheadStudsOffset
	billboard.MaxDistance = OVERHEAD_MAX_DISTANCE
	billboard.ResetOnSpawn = false
	billboard.Parent = character

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.fromScale(0.5, 0)
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = getDisplayNameText(player)
	nameLabel.TextColor3 = Config.OverheadNameColor
	nameLabel.TextScaled = false
	nameLabel.TextSize = Config.OverheadNameTextSize
	nameLabel.TextWrapped = false
	nameLabel.Parent = holder
	addStroke(nameLabel, 4)

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedLabel"
	speedLabel.BackgroundTransparency = 1
	speedLabel.AnchorPoint = Vector2.new(0.5, 0)
	speedLabel.Position = UDim2.fromScale(0.5, 0.43)
	speedLabel.Size = UDim2.new(1, 0, 0.5, 0)
	speedLabel.Font = Enum.Font.GothamBlack
	speedLabel.Text = getSpeedDisplayText(player) .. " Speed"
	speedLabel.TextColor3 = Config.OverheadSpeedColor
	speedLabel.TextScaled = false
	speedLabel.TextSize = Config.OverheadSpeedTextSize
	speedLabel.TextWrapped = false
	speedLabel.Parent = holder
	addStroke(speedLabel, 4)

	overheads[character] = {
		Player = player,
		Billboard = billboard,
		NameLabel = nameLabel,
		SpeedLabel = speedLabel,
	}

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local speed = leaderstats:FindFirstChild("Speed")
		if speed then
			speed.Changed:Connect(function()
				if character.Parent then
					updateOverhead(player, character)
				end
			end)
		end
	end

	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			task.wait(0.1)
			if character.Parent then
				updateOverhead(player, character)
			end
		end
	end)

	updateOverhead(player, character)
end


local function ensureOverheadAttached(player, character)
	if not player or not player.Parent or not character or not character.Parent then
		return
	end

	if player == localPlayer then
		cleanupCharacter(character)
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local billboard = character:FindFirstChild("SpeedsterOverhead")
	local data = overheads[character]

	if not data or not billboard or billboard ~= data.Billboard or billboard.Parent ~= character or billboard.Adornee ~= head then
		attachOverhead(player, character)
	end
end

local function queueOverheadRepair(player)
	for _, delayTime in ipairs({0.05, 0.25, 0.65, 1.25}) do
		task.delay(delayTime, function()
			if player.Parent and player.Character then
				ensureOverheadAttached(player, player.Character)
			end
		end)
	end
end

local function setupPlayer(player)
	local function onCharacter(character)
		if player == localPlayer then
			cleanupCharacter(character)
			return
		end

		attachOverhead(player, character)
		queueOverheadRepair(player)
	end

	if player.Character then
		task.defer(onCharacter, player.Character)
	end

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function(character)
		cleanupCharacter(character)
	end)

	        
	                                                                                                      
	                                          
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		queueOverheadRepair(player)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		cleanupCharacter(player.Character)
	end
end)

task.spawn(function()
	while true do
		for character, data in pairs(overheads) do
			if not character.Parent or not data.Player.Parent then
				cleanupCharacter(character)
			else
				updateOverhead(data.Player, character)
			end
		end

		        
		                                                             
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
				ensureOverheadAttached(player, player.Character)
			elseif player == localPlayer and player.Character then
				cleanupCharacter(player.Character)
			end
		end

		task.wait(0.2)
	end
end)

print("[OverheadStats] V178 loaded. Overhead shows within " .. tostring(OVERHEAD_MAX_DISTANCE) .. " studs and hides your own overhead.")
