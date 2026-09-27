local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
	local isNearby = true
	if camera and root then
		local distance = (camera.CFrame.Position - root.Position).Magnitude
		isNearby = distance <= OVERHEAD_MAX_DISTANCE
		if data.Billboard.Enabled ~= isNearby then
			data.Billboard.Enabled = isNearby
		end
	end

	if not isNearby then
		return
	end

	local speedText = getSpeedDisplayText(player) .. " Speed"
	if data.SpeedLabel.Text ~= speedText then
		data.SpeedLabel.Text = speedText
	end
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

-- "[AFK]" over a player in AFK Mode. The server publishes the player attribute AfkModeActive
-- (Social/AfkZoneService), which every client sees; each client draws the tag from it, over
-- the player's own head too. It shares the name board's anchor and is stacked over it in
-- pixels (over the Dev / Tester title when the character carries one), so they never run
-- into each other at any distance. It lives in the character: a reset or leaving takes it
-- along, and the new character gets it back while AFK Mode is still on.
local AFK_TAG_NAME = "SpeedsterAfkTag"
local AFK_TAG_HEIGHT = tonumber(Config.OverheadAfkTagHeight) or 26

local function updateAfkTag(player, character)
	local tag = character:FindFirstChild(AFK_TAG_NAME)
	local head = character:FindFirstChild("Head")
	if player:GetAttribute("AfkModeActive") ~= true or not head or not head:IsA("BasePart") then
		if tag then
			tag:Destroy()
		end
		return
	end

	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = AFK_TAG_NAME
		tag.AlwaysOnTop = true
		tag.StudsOffsetWorldSpace = Config.OverheadStudsOffset
		tag.MaxDistance = tonumber(Config.OverheadAfkTagMaxDistance) or OVERHEAD_MAX_DISTANCE
		tag.ResetOnSpawn = false

		local label = Instance.new("TextLabel")
		label.Name = "AfkLabel"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, 0)
		label.Size = UDim2.new(1, 0, 0, AFK_TAG_HEIGHT)
		label.Font = Enum.Font.GothamBlack
		label.Text = "[AFK]"
		label.TextColor3 = Config.OverheadAfkTagColor or Color3.fromRGB(120, 205, 255)
		label.TextScaled = false
		label.TextSize = Config.OverheadNameTextSize
		label.TextWrapped = false
		label.Parent = tag
		addStroke(label, 4)

		tag.Parent = character
	end

	-- The name board is 70 px tall and centred on the anchor; a title's strip sits over it.
	local gap = tonumber(Config.OverheadTitleGap) or 5
	local below = 35 + gap
	if character:FindFirstChild("PlayerTitlePart") then
		below += (tonumber(Config.OverheadTitleHeight) or 34) + gap
	end
	local size = UDim2.fromOffset(260, 2 * (below + AFK_TAG_HEIGHT))
	if tag.Size ~= size then
		tag.Size = size
	end
	if tag.Adornee ~= head then
		tag.Adornee = head
	end
end

local function layoutTitleBoard(billboard, titleLabel, head)
	local titleHeight = tonumber(Config.OverheadTitleHeight) or 34
	local gap = tonumber(Config.OverheadTitleGap) or 5
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(260, 2 * (35 + gap + titleHeight))
	billboard.SizeOffset = Vector2.zero
	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Config.OverheadStudsOffset
	billboard.ExtentsOffset = Vector3.zero
	billboard.ExtentsOffsetWorldSpace = Vector3.zero
	billboard.MaxDistance = OVERHEAD_MAX_DISTANCE
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Position = UDim2.fromScale(0.5, 0)
	titleLabel.Size = UDim2.new(1, 0, 0, titleHeight)
	titleLabel.TextScaled = true
end

local function titleParticleLift(depth, fieldOfView, viewportHeight)
	local titleHeight = tonumber(Config.OverheadTitleHeight) or 34
	local pixels = 35 + (tonumber(Config.OverheadTitleGap) or 5) + titleHeight / 2
	local studsPerPixel = 2 * depth * math.tan(math.rad(fieldOfView) / 2) / viewportHeight
	return pixels * studsPerPixel - (tonumber(Config.TitleParticleDrop) or 0.2)
end

local activeTitleAnimations = {}
local titleSetupGeneration = setmetatable({}, { __mode = "k" })

local function cleanupTitleAnimation(character)
	titleSetupGeneration[character] = (titleSetupGeneration[character] or 0) + 1
	local anim = activeTitleAnimations[character]
	if anim then
		if anim.Tweens then
			for _, t in ipairs(anim.Tweens) do
				pcall(function() t:Cancel() end)
			end
		end
		if anim.Thread then
			pcall(task.cancel, anim.Thread)
		end
		activeTitleAnimations[character] = nil
	end
end

local function setupTitleAnimation(character)
	if activeTitleAnimations[character] then
		return
	end

	local generation = (titleSetupGeneration[character] or 0) + 1
	titleSetupGeneration[character] = generation
	activeTitleAnimations[character] = { Part = character:FindFirstChild("PlayerTitlePart") }
	task.spawn(function()
		local titlePart = character:WaitForChild("PlayerTitlePart", 4)
		if titleSetupGeneration[character] ~= generation then return end
		if not titlePart or not character.Parent then
			return
		end

		local titleAtt = titlePart:WaitForChild("Title", 3)
		if titleSetupGeneration[character] ~= generation then return end
		if not titleAtt then return end

		local billboard = titleAtt:WaitForChild("BillboardGui", 3)
		if titleSetupGeneration[character] ~= generation then return end
		if not billboard then return end

		billboard.AlwaysOnTop = true

		local titleLabel = billboard:WaitForChild("Title", 3)
		if titleSetupGeneration[character] ~= generation or titlePart.Parent ~= character then return end
		if not titleLabel or not titleLabel:IsA("TextLabel") then return end

		-- Stacked in pixels over the name and speed (their board is 70 px tall, centred on
		-- the same point): the title's own board is centred there too and twice as tall as
		-- the room it needs, its text in the top strip, so it stays just above them at any
		-- distance instead of running into them (it used to sit 1.7 studs up, on the name).
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			layoutTitleBoard(billboard, titleLabel, head)
		end

		local tweens = {}
		local thread = nil

		-- Update 4 (2026-09-25): the server says how the title looks (Bootstrap stamps TitleStyle,
		-- TitleText and TitleId from TitleService.Visual): "typewriter" = the DEV typing loop,
		-- "shine" = the Tester gradient swing, "static" = its text and nothing else (no tween, no
		-- thread: most titles, and phones are render-bound). Without the attributes (an older
		-- server) the look is guessed from the part as before and its own text is kept.
		local style = titlePart:GetAttribute("TitleStyle")
		local titleId = titlePart:GetAttribute("TitleId")
		local attributeText = titlePart:GetAttribute("TitleText")
		local titleText = if type(attributeText) == "string" and attributeText ~= "" then attributeText else titleLabel.Text
		if style ~= "typewriter" and style ~= "shine" and style ~= "static" then
			local looksDev = (titlePart:FindFirstChild("Smokes") ~= nil) or (string.find(string.upper(titleLabel.Text), "DEV") ~= nil)
			style = if looksDev then "typewriter" else "shine"
			titleId = if looksDev then "developer" else nil
		end
		-- The DEV fire colours belong to the developer title; OWNER keeps the gold Bootstrap set.
		local fireColours = titleId == nil or titleId == "developer"
		local uigradient = titleLabel:FindFirstChildOfClass("UIGradient")

		if style == "static" then
			titleLabel.Text = titleText
		elseif style == "typewriter" then
			if not uigradient then
				uigradient = Instance.new("UIGradient")
				uigradient.Parent = titleLabel
			end

			if fireColours then
				uigradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 0)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200, 70, 0)),
					ColorSequenceKeypoint.new(0.7, Color3.fromRGB(150, 30, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 0))
				})
			end

			uigradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.3, 0.5),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 0.7)
			})

			local waveTweenInfo = TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			local rotationTweenInfo = TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)

			local waveTween = TweenService:Create(uigradient, waveTweenInfo, {Offset = Vector2.new(0, 0.5)})
			local rotationTween = TweenService:Create(uigradient, rotationTweenInfo, {Rotation = 360})
			table.insert(tweens, waveTween)
			table.insert(tweens, rotationTween)
			waveTween:Play()
			rotationTween:Play()

			-- The second, darker layer is part of the DEV fire only.
			if fireColours then
				local secondGradient = titleLabel:FindFirstChild("SecondGradient") or Instance.new("UIGradient")
				secondGradient.Name = "SecondGradient"
				secondGradient.Parent = titleLabel

				secondGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 0)),
					ColorSequenceKeypoint.new(0.3, Color3.fromRGB(200, 50, 0)),
					ColorSequenceKeypoint.new(0.6, Color3.fromRGB(150, 20, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 0, 0))
				})

				secondGradient.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.95),
					NumberSequenceKeypoint.new(0.5, 0.8),
					NumberSequenceKeypoint.new(1, 0.95)
				})

				local secondWaveTweenInfo = TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local secondRotationTweenInfo = TweenInfo.new(13, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false)

				local secondWaveTween = TweenService:Create(secondGradient, secondWaveTweenInfo, {Offset = Vector2.new(0, -0.4)})
				local secondRotationTween = TweenService:Create(secondGradient, secondRotationTweenInfo, {Rotation = -360})
				table.insert(tweens, secondWaveTween)
				table.insert(tweens, secondRotationTween)
				secondWaveTween:Play()
				secondRotationTween:Play()
			end

			local devText = titleText
			thread = task.spawn(function()
				while character.Parent and titleLabel.Parent do
					titleLabel.Text = ""
					for i = 1, #devText do
						local currentText = string.sub(devText, 1, i)
						titleLabel.Text = currentText

						if i == #devText then
							for _ = 1, 4 do
								if not character.Parent or not titleLabel.Parent then return end
								titleLabel.Text = currentText .. "|"
								task.wait(0.3)
								if not character.Parent or not titleLabel.Parent then return end
								titleLabel.Text = currentText
								task.wait(0.3)
							end
						else
							task.wait(0.15)
						end
					end

					task.wait(1.5)

					for i = #devText, 1, -1 do
						if not character.Parent or not titleLabel.Parent then return end
						titleLabel.Text = string.sub(devText, 1, i) .. "|"
						task.wait(0.1)
					end

					if not character.Parent or not titleLabel.Parent then return end
					titleLabel.Text = "|"
					task.wait(0.3)
					titleLabel.Text = ""
					task.wait(0.8)
				end
			end)
		else
			-- shine: the Tester gradient swing, on the title's own text
			titleLabel.Text = titleText
			if uigradient then
				local rotationTweenInfo = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
				local rotationTween1 = TweenService:Create(uigradient, rotationTweenInfo, {Rotation = 360})
				local rotationTween2 = TweenService:Create(uigradient, rotationTweenInfo, {Rotation = 0})
				table.insert(tweens, rotationTween1)
				table.insert(tweens, rotationTween2)
				rotationTween1.Completed:Connect(function() rotationTween2:Play() end)
				rotationTween2.Completed:Connect(function() rotationTween1:Play() end)
				rotationTween1:Play()
			end
		end

		local weld = titlePart:FindFirstChild("TitleWeld")
		activeTitleAnimations[character] = {
			Tweens = tweens,
			Thread = thread,
			Part = titlePart,
			Head = if head and head:IsA("BasePart") then head else nil,
			Weld = if weld and weld:IsA("Weld") then weld else nil,
		}
	end)
end

local function placeTitleParticles()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraCFrame = camera.CFrame
	local viewportHeight = camera.ViewportSize.Y
	for _, anim in pairs(activeTitleAnimations) do
		local weld, head = anim.Weld, anim.Head
		if weld and weld.Parent and head and head.Parent then
			local anchor = head.Position + Config.OverheadStudsOffset
			local toAnchor = anchor - cameraCFrame.Position
			local depth = toAnchor:Dot(cameraCFrame.LookVector)
			local target
			if depth > 0.5 and viewportHeight > 0 and toAnchor.Magnitude <= OVERHEAD_MAX_DISTANCE then
				target = anchor + cameraCFrame.UpVector * titleParticleLift(depth, camera.FieldOfView, viewportHeight)
			else
				-- No text to ride on (out of its range, or behind the camera): the server's spot.
				target = head.Position + Vector3.new(0, tonumber(Config.TitleParticleHeight) or 4, 0)
			end
			weld.C0 = head.CFrame:ToObjectSpace(CFrame.new(target))
		end
	end
end
-- After every camera writer (the punches and the portal flight bind at Camera + 2 / + 3).
RunService:BindToRenderStep("SpeedsterTitleParticles", Enum.RenderPriority.Last.Value, placeTitleParticles)

local function setupPlayer(player)
	local function onCharacter(character)
		setupTitleAnimation(character)
		updateAfkTag(player, character)

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
		cleanupTitleAnimation(character)
	end)

	player:GetAttributeChangedSignal("AfkModeActive"):Connect(function()
		if player.Character then
			updateAfkTag(player, player.Character)
		end
	end)

	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		queueOverheadRepair(player)
		if player.Character then
			cleanupTitleAnimation(player.Character)
			setupTitleAnimation(player.Character)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		cleanupCharacter(player.Character)
		cleanupTitleAnimation(player.Character)
	end
end)

task.spawn(function()
	while true do
		for character, data in pairs(overheads) do
			if not character.Parent or not data.Player.Parent then
				cleanupCharacter(character)
				cleanupTitleAnimation(character)
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
			if player.Character then
				updateAfkTag(player, player.Character)
			end
			local titlePart = player.Character and player.Character:FindFirstChild("PlayerTitlePart")
			local anim = titlePart and activeTitleAnimations[player.Character]
			if titlePart and (not anim or anim.Part ~= titlePart) then
				cleanupTitleAnimation(player.Character)
				setupTitleAnimation(player.Character)
			elseif not titlePart and player.Character then
				cleanupTitleAnimation(player.Character)
			end
		end

		task.wait(0.2)
	end
end)

print("[OverheadStats] V178 loaded. Overhead shows within " .. tostring(OVERHEAD_MAX_DISTANCE) .. " studs and hides your own overhead.")
