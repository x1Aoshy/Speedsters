          
                                                                              
                                                                              
                                                                               
                                                                            
                                                                           
                                                                              
                                                                               
        
                                                                        
                                                                      

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	print("[TreadmillOverheadLabels] V306HP inactive in World 2.")
	return
end
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local NEW_WORLD1_ROOT = IS_NEW_WORLD1
	and Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
local NEW_WORLD1_TREADMILL_PROFILES = Config.NewWorld1TreadmillProfiles or {}

local COLLISION_FOLDER_NAME = "VortexTreadmillCollisionFix_V255"
local SIGN_PART_NAME = "V306HP_TreadmillSign"
local GUI_NAME = "V306HP_TreadmillSurface"
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
local BLUE_REFERENCE_TREADMILL_NAME = IS_NEW_WORLD1 and "Diamond" or "Treadmill3_superfast"
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
	Treadmill1_basic = {
		StepsText = "Starter",
		StepsColor = Color3.fromRGB(255, 255, 255),
		StarterOnly = true,
	},
	Treadmill2_fast = {
		StepsText = "x5 Steps",
		StepsColor = Color3.fromRGB(255, 184, 40),
		RequirementText = "1 Rebirth\nRequired",
		RequirementIcon = REBIRTH_ICON,
	},
	Treadmill3_superfast = {
		StepsText = "x10 Steps",
		StepsColor = Color3.fromRGB(75, 185, 255),
		RequirementText = "7 Rebirths\nRequired",
		RequirementIcon = REBIRTH_ICON,
	},
	Treadmill4_hyperspeed = {
		StepsText = "x25 Steps",
		StepsColor = Color3.fromRGB(255, 80, 235),
		RequirementIcon = ROBUX_ICON,
		GamePassId = 1941090466,
	},
	Treadmill5_insanespeed = {
		StepsText = "x50M Steps",
		StepsColor = Color3.fromRGB(255, 55, 55),
		RequirementIcon = ROBUX_ICON,
		GamePassId = 1941342451,
	},
}

if IS_NEW_WORLD1 then
	for treadmillName, sourceProfile in pairs(NEW_WORLD1_TREADMILL_PROFILES) do
		local requiredRebirths = math.max(0, math.floor(tonumber(sourceProfile.RequiredRebirths) or 0))
		local gamePassId = math.max(0, math.floor(tonumber(sourceProfile.GamePassId) or 0))
		local profile = {
			StepsText = tostring(sourceProfile.DisplayText or ("x" .. tostring(sourceProfile.BaseGain or 1) .. " Speed")),
			StepsColor = sourceProfile.PopupColor or Color3.fromRGB(255, 255, 255),
		}
		if treadmillName == "Basic" then
			profile.StarterOnly = true
			profile.TwoLineStarter = true
		elseif requiredRebirths > 0 then
			local noun = requiredRebirths == 1 and "Rebirth" or "Rebirths"
			profile.RequirementText = tostring(requiredRebirths) .. " " .. noun .. "\nRequired"
			profile.RequirementIcon = REBIRTH_ICON
		elseif gamePassId > 0 then
			profile.RequirementIcon = ROBUX_ICON
			profile.GamePassId = gamePassId
		end
		PROFILES[treadmillName] = profile
	end
end

local boundTreadmills = {}
local knownTreadmillsByFullName = {}
local liveGamePassPrices = {}
local gamePassPriceResolutionActive = {}
local blueReferenceWorldWidth = nil
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
		or lowerName == "safezone1"
		or (IS_NEW_WORLD1 and lowerName == "stage1")
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

local function isMainTreadmill(instance)
	local supported = (instance:IsA("Model") or instance:IsA("BasePart"))
		and PROFILES[instance.Name] ~= nil
		and instance:GetAttribute("OwnerAdminSpawned") ~= true
		and not isInsideStageDecor(instance)
	if not supported then
		return false
	end
	if NEW_WORLD1_TREADMILL_PROFILES[instance.Name] then
		return NEW_WORLD1_ROOT ~= nil and instance:IsDescendantOf(NEW_WORLD1_ROOT)
	end
	return true
end

local function getPhysicalTreadmill(treadmill)
	if IS_NEW_WORLD1 and NEW_WORLD1_TREADMILL_PROFILES[treadmill.Name] then
		local nestedBelt = treadmill:FindFirstChild("Treadmil", true)
		if nestedBelt and (nestedBelt:IsA("Model") or nestedBelt:IsA("BasePart")) then
			return nestedBelt
		end
	end
	return treadmill
end

local function findCollisionDeck(treadmill)
	local collisionFolder = Workspace:FindFirstChild(COLLISION_FOLDER_NAME)
	if not collisionFolder then
		return nil
	end

	local wantedSource = getPhysicalTreadmill(treadmill):GetFullName()
	for _, treadmillFolder in ipairs(collisionFolder:GetChildren()) do
		if treadmillFolder:GetAttribute("SourceTreadmill") == wantedSource then
			local deck = treadmillFolder:FindFirstChild("SmoothDeck")
			if deck and deck:IsA("BasePart") then
				return deck
			end
		end
	end
	-- Fallback: return physical treadmill primary part or child part so overhead labels always render
	local physical = getPhysicalTreadmill(treadmill)
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

local function getDeckBasedSignWorldWidth(deck)
	                                                                         
	                                                                            
	                              
	return math.clamp(
		deck.Size.X * LABEL_WIDTH_TO_DECK,
		MIN_LABEL_WORLD_WIDTH,
		MAX_LABEL_WORLD_WIDTH
	)
end

local function getSignWorldSize(treadmill, deck)
	local deckBasedWidth = getDeckBasedSignWorldWidth(deck)
	if treadmill.Name == BLUE_REFERENCE_TREADMILL_NAME then
		blueReferenceWorldWidth = deckBasedWidth
	end

	local width = blueReferenceWorldWidth or deckBasedWidth
	return width, width * LABEL_HEIGHT_TO_WIDTH
end

local function getHorizontalDeckLook(deck)
	local look = Vector3.new(deck.CFrame.LookVector.X, 0, deck.CFrame.LookVector.Z)
	if look.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return look.Unit
end

local function getRearDirectionFromSpawn(deck)
	local closestSpawnPosition = nil
	local closestDistance = math.huge
	for _, spawnPosition in ipairs(spawnReferencePositions) do
		local distance = (deck.Position - spawnPosition).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestSpawnPosition = spawnPosition
		end
	end

	local deckAxis = getHorizontalDeckLook(deck)
	if not closestSpawnPosition then
		return deckAxis
	end

	local directionAwayFromSpawn = Vector3.new(
		deck.Position.X - closestSpawnPosition.X,
		0,
		deck.Position.Z - closestSpawnPosition.Z
	)
	if directionAwayFromSpawn.Magnitude < 0.001 then
		return deckAxis
	end

	if deckAxis:Dot(directionAwayFromSpawn.Unit) >= 0 then
		return deckAxis
	end
	return -deckAxis
end

local function getUprightSignCFrame(deck, position)
	local look = getHorizontalDeckLook(deck)
	return CFrame.lookAt(position, position + look, Vector3.yAxis)
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

local function createOverhead(treadmill, deck, profile)
	local previous = deck:FindFirstChild(SIGN_PART_NAME)
	if previous then
		previous:Destroy()
	end
	for legacyName in pairs(LEGACY_SIGN_PART_NAMES) do
		local legacySign = deck:FindFirstChild(legacyName)
		if legacySign then
			legacySign:Destroy()
		end
	end

	local worldWidth, worldHeight = getSignWorldSize(treadmill, deck)
	local rearDirection = getRearDirectionFromSpawn(deck)
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
	sign.CFrame = getUprightSignCFrame(
		deck,
		deck.Position
			+ Vector3.new(0, LABEL_WORLD_OFFSET_Y, 0)
			+ rearDirection * LABEL_WORLD_BACK_OFFSET
	)
	sign:SetAttribute("TreadmillPresentationV306HP", true)

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
	if not blueReferenceWorldWidth then
		return
	end

	local sharedSize = Vector3.new(
		blueReferenceWorldWidth,
		blueReferenceWorldWidth * LABEL_HEIGHT_TO_WIDTH,
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
				return MarketplaceService:GetProductInfoAsync(gamePassId, Enum.InfoType.GamePass)
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
			"[TreadmillOverheadLabels] Could not resolve live price for Pass %d: %s",
			gamePassId,
			lastError
		))
	end)
end

local function bindTreadmill(treadmill)
	if not treadmill.Parent or not isMainTreadmill(treadmill) then
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
	local profile = PROFILES[treadmill.Name]
	local presentation, requirementLabels = createOverhead(treadmill, deck, profile)
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

	print("[TreadmillOverheadLabels] V306HP bound " .. treadmill:GetFullName())
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
	if isMainTreadmill(instance) and instance.Name == BLUE_REFERENCE_TREADMILL_NAME then
		local blueDeck = findCollisionDeck(instance)
		if blueDeck then
			blueReferenceWorldWidth = getDeckBasedSignWorldWidth(blueDeck)
			break
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
		knownTreadmillsByFullName[getPhysicalTreadmill(instance):GetFullName()] = nil
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

print(
	IS_NEW_WORLD1
		and "[TreadmillOverheadLabels] V306KBD ready | Basic x1, Golden x3/1R, Candy x5/3R, Diamond x10/7R, Needoh x25 Pass, Admin x100 Pass, Hacker x300 Pass | exact nested-belt signs | live paid-tier prices"
		or "[TreadmillOverheadLabels] V306KAV ready | Gold x5 and Blue x10 text | Blue requires 7 Rebirths | all 5 signs match Blue size | +1 stud raised | 5 studs rear from spawn | fixed-canvas SurfaceGui | no camera loop | wall occlusion | unlimited distance | live paid-tier prices"
)
