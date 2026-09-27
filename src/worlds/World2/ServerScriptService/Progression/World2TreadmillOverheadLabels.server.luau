         
                                                                              
                                                                               
                                                                             
                                                                             
                                                                

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local COLLISION_FOLDER_NAME = "VortexTreadmillCollisionFix_V255"
local SIGN_PART_NAME = "V306IJ_World2TreadmillSign"
local GUI_NAME = "V306IJ_World2TreadmillSurface"
local LEGACY_SIGN_PART_NAMES = {
	V306HN_TreadmillSign = true,
	V306HO_TreadmillSign = true,
}
local CONTENT_ROOT_NAME = "ContentRoot"
local LEGACY_GUI_PREFIX = "V306H"
local LEGACY_SCALER_NAMES = {
	TreadmillRebirthBillboardScale = true,
	TreadmillOverheadPerspective = true,
}
local REBIRTH_ICON = "rbxassetid://98204886250993"
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local BLUE_REFERENCE_TREADMILL_NAME = "Diamond"
local LABEL_WIDTH_TO_DECK = 0.92
local MIN_LABEL_WORLD_WIDTH = 8
local MAX_LABEL_WORLD_WIDTH = 24
local LABEL_CANVAS_WIDTH = 360
local LABEL_CANVAS_HEIGHT = 144
local LABEL_HEIGHT_TO_WIDTH = LABEL_CANVAS_HEIGHT / LABEL_CANVAS_WIDTH
local LABEL_WORLD_OFFSET_Y = 8.75
local LABEL_WORLD_BACK_OFFSET = 5
local SIGN_DEPTH = 0.05
local TITLE_TEXT_SIZE = 46
local STARTER_TEXT_SIZE = TITLE_TEXT_SIZE
local REQUIREMENT_TEXT_SIZE = 22
local PAID_PRICE_TEXT_SIZE = 30
local REQUIREMENT_ICON_SIZE = 60
local PAID_ICON_SIZE = 44
local ROW_ICON_GAP = 8
local TEXT_OUTLINE_THICKNESS = 3

local PROFILES = {
	Golden = {
		StepsText = "Starter\nx10 Speed",
		StepsColor = Color3.fromRGB(255, 190, 0),
		StarterOnly = true,
		TwoLineStarter = true,
	},
	Candy = {
		StepsText = "x15 Speed",
		StepsColor = Color3.fromRGB(255, 92, 202),
		RequirementText = "9 Rebirths\nRequired",
		RequirementIcon = REBIRTH_ICON,
	},
	Diamond = {
		StepsText = "x30 Speed",
		StepsColor = Color3.fromRGB(30, 180, 255),
		RequirementText = "11 Rebirths\nRequired",
		RequirementIcon = REBIRTH_ICON,
	},
	Needoh = {
		-- From Config (x40 since 2026-09-22), so the sign always matches the gain.
		StepsText = tostring((Config.World2TreadmillProfiles and Config.World2TreadmillProfiles.Needoh
			and Config.World2TreadmillProfiles.Needoh.DisplayText) or "x40 Speed"),
		StepsColor = Color3.fromRGB(255, 55, 190),
		RequirementIcon = ROBUX_ICON,
		GamePassId = 1941090466,
	},
	Admin = {
		StepsText = "x100 Speed",
		StepsColor = Color3.fromRGB(255, 55, 55),
		RequirementIcon = ROBUX_ICON,
		GamePassId = 1941342451,
	},
	Hacker = {
		StepsText = "x300 Speed",
		StepsColor = Color3.fromRGB(65, 255, 115),
		RequirementIcon = ROBUX_ICON,
		GamePassId = 1954325260,
	},
}

local ANCHOR_OVERRIDES = {
	Golden = Vector3.new(-822.52, 36638.2, -1054.0),
	Candy = Vector3.new(-808.74, 36638.2, -1053.5),
	Diamond = Vector3.new(-796.75, 36638.2, -1053.5),
	Needoh = Vector3.new(-780.00, 36638.2, -1056.0),
	Admin = Vector3.new(-761.36, 36638.2, -1054.5),
	Hacker = Vector3.new(-739.40, 36638.2, -1055.5),
}
local UNIFORM_SIGN_WIDTH = 11.5
local UNIFORM_SIGN_HEIGHT = UNIFORM_SIGN_WIDTH * LABEL_HEIGHT_TO_WIDTH

local boundTreadmills = {}
local knownTreadmillsByFullName = {}
local liveGamePassPrices = {}
local gamePassPriceResolutionActive = {}
local startupDescendants = Workspace:GetDescendants()
local startupPresentationGuis = {}
local spawnReferencePositions = {}
for _, instance in ipairs(startupDescendants) do
	if instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
		table.insert(startupPresentationGuis, instance)
	end

	local lowerName = string.lower(instance.Name)
	local isSpawnReference = instance:IsA("SpawnLocation")
		or lowerName == "spawn"
		or lowerName == "spawn1"
		or lowerName == "safezone1.2"
	if isSpawnReference then
		if instance:IsA("BasePart") then
			table.insert(spawnReferencePositions, instance.Position)
		elseif instance:IsA("Model") then
			table.insert(spawnReferencePositions, instance:GetPivot().Position)
		end
	end
end

                                                                              
                                                                                 
                                       
local function isInsideStageDecor(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == "StageDecor_Runtime"
			or current:GetAttribute("StageDecorClone") == true
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getTreadmillProfileName(instance)
	if not instance or not (instance:IsA("Model") or instance:IsA("BasePart")) then
		return nil
	end
	if instance:GetAttribute("OwnerAdminSpawned") == true or isInsideStageDecor(instance) then
		return nil
	end
	-- Ignore parent container "Admin" containing multiple treadmill models
	if instance:IsA("Model") and instance.Name == "Admin" then
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("Model") and (PROFILES[child.Name] ~= nil or child:FindFirstChild("Treadmil", true)) then
				return nil
			end
		end
	end
	-- Inner Admin treadmill inside container
	if instance:IsA("Model") and instance.Name == "Model" and instance.Parent and instance.Parent.Name == "Admin" and instance:FindFirstChild("Treadmil", true) then
		return "Admin"
	end
	if PROFILES[instance.Name] ~= nil then
		return instance.Name
	end
	return nil
end

local function findOwnedNestedTreadmil(container)
	if not container or not (container:IsA("Model") or container:IsA("BasePart")) then
		return nil
	end
	local profileName = getTreadmillProfileName(container)
	if not profileName then
		return nil
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant.Name == "Treadmil" and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
			local current = descendant.Parent
			local ownedByContainer = true
			while current and current ~= container do
				if (current:IsA("Model") or current:IsA("BasePart"))
					and getTreadmillProfileName(current) ~= nil
				then
					ownedByContainer = false
					break
				end
				current = current.Parent
			end
			if ownedByContainer and current == container then
				return descendant
			end
		end
	end
	return nil
end

local function isMainTreadmill(instance)
	local profileName = getTreadmillProfileName(instance)
	return profileName ~= nil and PROFILES[profileName] ~= nil
end

local function getPhysicalTreadmill(treadmill)
	return findOwnedNestedTreadmil(treadmill) or treadmill
end

local function findCollisionDeck(treadmill)
	local collisionFolder = Workspace:FindFirstChild(COLLISION_FOLDER_NAME)
	local physical = getPhysicalTreadmill(treadmill)
	if collisionFolder then
		local wantedSources = {
			[treadmill:GetFullName()] = true,
			[physical:GetFullName()] = true,
		}
		for _, treadmillFolder in ipairs(collisionFolder:GetChildren()) do
			local source = treadmillFolder:GetAttribute("SourceTreadmill")
			if source and wantedSources[source] then
				local deck = treadmillFolder:FindFirstChild("SmoothDeck")
				if deck and deck:IsA("BasePart") then
					return deck
				end
			end
		end
	end
	-- Fallback: return physical treadmill primary part or child part so overhead labels always render
	if physical:IsA("BasePart") then return physical end
	if physical:IsA("Model") then
		local primary = physical.PrimaryPart or physical:FindFirstChildWhichIsA("BasePart", true)
		if primary then return primary end
	end
	return nil
end

local function normalizeText(value)
	return string.upper(tostring(value or ""))
		:gsub("%s+", " ")
		:match("^%s*(.-)%s*$")
end

local function guiContainsOldTreadmillText(gui)
	local sawTrain = false
	local sawSpeed = false
	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local text = normalizeText(descendant.Text)
			sawTrain = sawTrain or text == "TRAIN"
			sawSpeed = sawSpeed or text == "SPEED"
			if text == "TRAIN SPEED"
				or text == "STARTER"
				or text:match("^X[%d%.]+[KM]? STEPS$")
				or text:match("^X[%d%.]+[KM]? SPEED$")
				or text:match("^%+[%d%.]+[KM]? SPEED$")
				or text:match("^%d+ REBIRTHS? REQUIRED$")
				or text:match("^R?%$?%s*%d+ ROBUX$")
			then
				return true
			end
		end
	end
	return sawTrain and sawSpeed
end

local function instanceWorldPosition(instance)
	if not instance then
		return nil
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function guiWorldPosition(gui)
	local adornee = gui.Adornee
	local position = instanceWorldPosition(adornee)
	if position then
		return position
	end

	local current = gui.Parent
	while current and current ~= Workspace do
		position = instanceWorldPosition(current)
		if position then
			return position
		end
		current = current.Parent
	end
	return nil
end

local function guiBelongsToTreadmill(gui, treadmill, deck)
	if gui:IsDescendantOf(treadmill) or gui:IsDescendantOf(deck) then
		return true
	end

	local adornee = gui.Adornee
	if adornee then
		if adornee == treadmill or adornee == deck then
			return true
		end
		if adornee:IsDescendantOf(treadmill) or adornee:IsDescendantOf(deck) then
			return true
		end
	end

	local guiPosition = guiWorldPosition(gui)
	if not guiPosition then
		return false
	end
	local cleanupRadius = math.max(deck.Size.X, deck.Size.Z, 12) * 1.25 + 8
	return (guiPosition - deck.Position).Magnitude <= cleanupRadius
end

local function removeOldPresentation(treadmill, deck)
	local toDestroy = {}
	local function consider(gui)
		if gui.Parent
			and gui.Name ~= GUI_NAME
			and (gui:IsA("BillboardGui") or gui:IsA("SurfaceGui"))
			and guiContainsOldTreadmillText(gui)
			and guiBelongsToTreadmill(gui, treadmill, deck)
		then
			toDestroy[gui] = true
		end
	end

	for _, descendant in ipairs(treadmill:GetDescendants()) do
		if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			consider(descendant)
		end
	end
	for _, descendant in ipairs(startupPresentationGuis) do
		consider(descendant)
	end
	for _, descendant in ipairs(deck:GetDescendants()) do
		if descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			consider(descendant)
		end
	end

	for gui in pairs(toDestroy) do
		if gui.Parent then
			gui:Destroy()
		end
	end

	                                                                            
	                                                                            
	for _, descendant in ipairs(deck:GetChildren()) do
		if descendant:IsA("BillboardGui")
			and descendant.Name ~= GUI_NAME
			and descendant.Name:sub(1, #LEGACY_GUI_PREFIX) == LEGACY_GUI_PREFIX
			and descendant.Name:find("_TreadmillOverhead", 1, true)
		then
			descendant:Destroy()
		end
	end
end

local function removeLegacyScaler(instance)
	if instance and LEGACY_SCALER_NAMES[instance.Name] then
		pcall(function()
			instance.Enabled = false
		end)
		pcall(function()
			instance.Disabled = true
		end)
		instance:Destroy()
		return true
	end
	return false
end

local function guardAgainstLegacyScaler(container)
	if not container then
		return
	end
	for scalerName in pairs(LEGACY_SCALER_NAMES) do
		local old = container:FindFirstChild(scalerName, true)
		if old then
			removeLegacyScaler(old)
		end
	end
	container.DescendantAdded:Connect(removeLegacyScaler)
end

                                                                              
                                                                              
                                                     
guardAgainstLegacyScaler(StarterPlayer:FindFirstChild("StarterPlayerScripts"))
local function guardPlayerScripts(player)
	task.spawn(function()
		guardAgainstLegacyScaler(player:WaitForChild("PlayerScripts", 15))
	end)
end
for _, player in ipairs(Players:GetPlayers()) do
	guardPlayerScripts(player)
end
Players.PlayerAdded:Connect(guardPlayerScripts)

local function addTextStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BlackOutline"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness
	stroke.Transparency = 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

local function createTextLabel(parent, name, position, size, text, color, textSize, automaticWidth)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.AutomaticSize = automaticWidth and Enum.AutomaticSize.X or Enum.AutomaticSize.None
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextScaled = false
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2
	label.Parent = parent
	addTextStroke(label, TEXT_OUTLINE_THICKNESS)
	return label
end

local function computeModelBounds(model)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local count = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local sz = part.Size * 0.5
			minX = math.min(minX, cf.Position.X - sz.X)
			maxX = math.max(maxX, cf.Position.X + sz.X)
			minY = math.min(minY, cf.Position.Y - sz.Y)
			maxY = math.max(maxY, cf.Position.Y + sz.Y)
			minZ = math.min(minZ, cf.Position.Z - sz.Z)
			maxZ = math.max(maxZ, cf.Position.Z + sz.Z)
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return {
		Center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5),
		Min = Vector3.new(minX, minY, minZ),
		Max = Vector3.new(maxX, maxY, maxZ),
	}
end

local function getSignWorldPosition(treadmill, profileName)
	if profileName and ANCHOR_OVERRIDES[profileName] then
		return ANCHOR_OVERRIDES[profileName]
	end
	local bounds = computeModelBounds(treadmill)
	if bounds then
		return Vector3.new(bounds.Center.X, 36638.2, bounds.Min.Z + 2.0)
	end
	return treadmill:GetPivot().Position + Vector3.new(0, 8.75, -5)
end

local function getUprightSignCFrame(targetPosition)
	-- LookVector pointing in +Z direction directly towards players approaching from spawn
	return CFrame.lookAt(targetPosition, targetPosition + Vector3.new(0, 0, 1), Vector3.yAxis)
end

local function getSignWorldSize(treadmill, deck)
	return UNIFORM_SIGN_WIDTH, UNIFORM_SIGN_HEIGHT
end

local function getRequirementText(profile)
	local gamePassId = math.floor(tonumber(profile.GamePassId) or 0)
	if gamePassId > 0 then
		local price = liveGamePassPrices[gamePassId]
		return price and tostring(price) or "..."
	end
	return profile.RequirementText or ""
end

local function createFixedComposition(surface, profile)
	local contentRoot = Instance.new("Frame")
	contentRoot.Name = CONTENT_ROOT_NAME
	contentRoot.Position = UDim2.fromOffset(0, 0)
	contentRoot.Size = UDim2.fromOffset(LABEL_CANVAS_WIDTH, LABEL_CANVAS_HEIGHT)
	contentRoot.BackgroundTransparency = 1
	contentRoot.ClipsDescendants = false
	contentRoot.Parent = surface

	if profile.StarterOnly then
		local starterLabel = createTextLabel(
			contentRoot,
			"Starter",
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(LABEL_CANVAS_WIDTH, profile.TwoLineStarter and 126 or 58),
			profile.StepsText,
			profile.StepsColor,
			profile.TwoLineStarter and 39 or STARTER_TEXT_SIZE,
			false
		)
		starterLabel.TextWrapped = profile.TwoLineStarter == true
		return nil
	end

	createTextLabel(
		contentRoot,
		"Steps",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(LABEL_CANVAS_WIDTH, 58),
		profile.StepsText,
		profile.StepsColor,
		TITLE_TEXT_SIZE,
		false
	)

	local isPaid = profile.GamePassId ~= nil
	local row = Instance.new("Frame")
	row.Name = "RequirementRow"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 60)
	row.Size = UDim2.fromOffset(LABEL_CANVAS_WIDTH, 76)
	row.ClipsDescendants = false
	row.Parent = contentRoot

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Name = "CenteredRequirementLayout"
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, ROW_ICON_GAP)
	rowLayout.Parent = row

	local iconSize = isPaid and PAID_ICON_SIZE or REQUIREMENT_ICON_SIZE
	local icon = Instance.new("ImageLabel")
	icon.Name = isPaid and "RobuxIcon" or "RebirthIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	icon.Image = profile.RequirementIcon
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.LayoutOrder = 1
	icon.ZIndex = 2
	icon.Parent = row

	local requirementLabel = createTextLabel(
		row,
		"Requirement",
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(0, 76),
		getRequirementText(profile),
		Color3.fromRGB(255, 255, 255),
		isPaid and PAID_PRICE_TEXT_SIZE or REQUIREMENT_TEXT_SIZE,
		true
	)
	requirementLabel.LayoutOrder = 2
	requirementLabel.TextXAlignment = Enum.TextXAlignment.Center
	return requirementLabel
end

local function createSurface(sign, face, profile)
	local surface = Instance.new("SurfaceGui")
	surface.Name = GUI_NAME
	surface.Adornee = sign
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(LABEL_CANVAS_WIDTH, LABEL_CANVAS_HEIGHT)
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0
	surface.MaxDistance = 0
	surface.ZOffset = 0.01
	surface.Parent = sign
	return createFixedComposition(surface, profile)
end

local function createOverhead(treadmill, deck, profile, profileName)
	profileName = profileName or getTreadmillProfileName(treadmill) or treadmill.Name
	local previous = deck:FindFirstChild(SIGN_PART_NAME)
	if previous then
		previous:Destroy()
	end
	if treadmill ~= deck then
		local treadmillPrev = treadmill:FindFirstChild(SIGN_PART_NAME, true)
		if treadmillPrev then
			treadmillPrev:Destroy()
		end
	end
	for legacyName in pairs(LEGACY_SIGN_PART_NAMES) do
		local legacySign = deck:FindFirstChild(legacyName)
		if legacySign then
			legacySign:Destroy()
		end
	end

	local worldWidth, worldHeight = getSignWorldSize(treadmill, deck)
	local signPos = getSignWorldPosition(treadmill, profileName)
	local sign = Instance.new("Part")
	sign.Name = SIGN_PART_NAME
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.CastShadow = false
	sign.Massless = true
	sign.Transparency = 1
	sign.Size = Vector3.new(worldWidth, worldHeight, SIGN_DEPTH)
	sign.CFrame = getUprightSignCFrame(signPos)
	sign:SetAttribute("World2TreadmillPresentationV306IJ", true)

	local requirementLabels = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local requirementLabel = createSurface(sign, face, profile)
		if requirementLabel then
			table.insert(requirementLabels, requirementLabel)
		end
	end
	sign.Parent = deck

	return sign, requirementLabels
end

local function applyBlueReferenceSizeToAllSigns()
	local sharedSize = Vector3.new(
		UNIFORM_SIGN_WIDTH,
		UNIFORM_SIGN_HEIGHT,
		SIGN_DEPTH
	)
	for treadmill, record in pairs(boundTreadmills) do
		if not treadmill.Parent then
			boundTreadmills[treadmill] = nil
		elseif record.Gui and record.Gui:IsA("BasePart") and record.Gui.Parent then
			record.Gui.Size = sharedSize
		end
	end
end

local function applyResolvedPrice(gamePassId, price)
	price = math.max(0, math.floor(tonumber(price) or 0))
	if price <= 0 then
		return false
	end

	liveGamePassPrices[gamePassId] = price
	for treadmill, record in pairs(boundTreadmills) do
		if not treadmill.Parent then
			boundTreadmills[treadmill] = nil
		elseif record.GamePassId == gamePassId then
			for _, requirementLabel in ipairs(record.RequirementLabels or {}) do
				if requirementLabel.Parent then
					requirementLabel.Text = tostring(price)
				end
			end
		end
	end
	return true
end

local function resolveGamePassPrice(gamePassId)
	gamePassId = math.max(0, math.floor(tonumber(gamePassId) or 0))
	if gamePassId <= 0
		or liveGamePassPrices[gamePassId]
		or gamePassPriceResolutionActive[gamePassId]
	then
		return
	end

	gamePassPriceResolutionActive[gamePassId] = true
	task.spawn(function()
		local lastError = "missing PriceInRobux"
		for attempt = 1, 3 do
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
			end)
			if ok and type(info) == "table" then
				if applyResolvedPrice(gamePassId, info.PriceInRobux) then
					gamePassPriceResolutionActive[gamePassId] = nil
					return
				end
				if info.IsForSale == false then
					lastError = "Pass is not for sale"
				else
					lastError = "missing PriceInRobux"
				end
			else
				lastError = tostring(info)
			end

			if attempt < 3 then
				task.wait(attempt * 1.25)
			end
		end

		gamePassPriceResolutionActive[gamePassId] = nil
		warn(string.format(
			"[World2TreadmillOverheadLabels] Could not resolve live price for Pass %d: %s",
			gamePassId,
			lastError
		))
	end)
end

local function bindTreadmill(treadmill)
	if not treadmill.Parent or not isMainTreadmill(treadmill) then
		return false
	end

	local profileName = getTreadmillProfileName(treadmill)
	if not profileName or not PROFILES[profileName] then
		return false
	end

	knownTreadmillsByFullName[treadmill:GetFullName()] = treadmill
	knownTreadmillsByFullName[getPhysicalTreadmill(treadmill):GetFullName()] = treadmill
	local deck = findCollisionDeck(treadmill)
	if not deck then
		return false
	end

	local existing = boundTreadmills[treadmill]
	if existing and existing.Deck == deck and existing.Gui and existing.Gui.Parent then
		return true
	end
	if existing and existing.DeckConnection then
		existing.DeckConnection:Disconnect()
	end

	removeOldPresentation(treadmill, deck)
	local profile = PROFILES[profileName]
	local presentation, requirementLabels = createOverhead(treadmill, deck, profile, profileName)
	local deckConnection
	deckConnection = deck.AncestryChanged:Connect(function()
		if not deck:IsDescendantOf(Workspace) then
			deckConnection:Disconnect()
			if boundTreadmills[treadmill] and boundTreadmills[treadmill].Deck == deck then
				boundTreadmills[treadmill] = nil
			end
		end
	end)

	local gamePassId = math.max(0, math.floor(tonumber(profile.GamePassId) or 0))
	boundTreadmills[treadmill] = {
		Deck = deck,
		Gui = presentation,
		RequirementLabels = requirementLabels,
		GamePassId = gamePassId,
		DeckConnection = deckConnection,
	}
	applyBlueReferenceSizeToAllSigns()
	if gamePassId > 0 then
		resolveGamePassPrice(gamePassId)
	end

	print("[World2TreadmillOverheadLabels] V306KP bound " .. treadmill:GetFullName())
	return true
end

local function findPresentationGui(instance)
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("BillboardGui") or current:IsA("SurfaceGui") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function removeLegacyPresentationGuiIfNeeded(gui)
	if not gui
		or not gui.Parent
		or gui.Name == GUI_NAME
		or not guiContainsOldTreadmillText(gui)
	then
		return
	end

	for treadmill, record in pairs(boundTreadmills) do
		if not treadmill.Parent then
			boundTreadmills[treadmill] = nil
		elseif record.Deck
			and record.Deck.Parent
			and guiBelongsToTreadmill(gui, treadmill, record.Deck)
		then
			gui:Destroy()
			return
		end
	end
end


for _, instance in ipairs(startupDescendants) do
	if isMainTreadmill(instance) then
		knownTreadmillsByFullName[instance:GetFullName()] = instance
		knownTreadmillsByFullName[getPhysicalTreadmill(instance):GetFullName()] = instance
		bindTreadmill(instance)
	end
end
table.clear(startupDescendants)

                                                                              
                                                                               
Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui")
		or instance:IsA("TextLabel")
		or instance:IsA("TextButton")
	then
		task.defer(function()
			removeLegacyPresentationGuiIfNeeded(findPresentationGui(instance))
		end)
	end

	if isMainTreadmill(instance) then
		task.defer(bindTreadmill, instance)
		return
	end

	if instance.Name == "SmoothDeck" and instance:IsA("BasePart") then
		task.defer(function()
			local sourceName = instance.Parent and instance.Parent:GetAttribute("SourceTreadmill")
			local treadmill = sourceName and knownTreadmillsByFullName[sourceName]
			if treadmill and treadmill.Parent then
				bindTreadmill(treadmill)
			end
		end)
	end
end)

Workspace.DescendantRemoving:Connect(function(instance)
	if isMainTreadmill(instance) then
		knownTreadmillsByFullName[instance:GetFullName()] = nil
	end
	local record = boundTreadmills[instance]
	if record then
		if record.DeckConnection then
			record.DeckConnection:Disconnect()
		end
		boundTreadmills[instance] = nil
	end
end)

                                                                               
task.delay(10, function()
	table.clear(startupPresentationGuis)
end)

print("[World2TreadmillOverheadLabels] V306KR ready | each copied treadmill binds only its OWN nested Treadmil | Golden Starter x10 | Candy x15/9R | Diamond x30/11R | Needoh/Admin/Hacker paid")
