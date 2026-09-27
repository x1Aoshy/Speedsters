-- The guided steps over the HUD ("your first aura", "ready to evolve", "ready to rebirth").
-- The card is a small window in the game's own look (the authored Backpack/Evolve panels):
-- the light block sheet with a navy edge, a cartoon icon and a Fredoka title on its top
-- edge, the words on a navy plate, a red stud Skip button, and the game's arrow pointing at
-- the button to press. It is sized from the HUD button it points at (TutorialGuideLayout).
-- Every word on it comes from Shared/TutorialText in the player's own language (2026-09-22).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Layout = require(script.Parent:WaitForChild("TutorialGuideLayout"))
local Text = require(script.Parent:WaitForChild("TutorialText"))
local Guide = {}
local stopCurrent
local activeGui
local activeSeenKey -- the open guide's saved flag (EvolveTutorialSeen / BackpackTutorialSeen / RebirthTutorialSeen)

local INK = Color3.fromRGB(11, 27, 61) -- the HUD's outline navy
local PLATE = Color3.fromRGB(50, 78, 111)
local GOLD = Color3.fromRGB(255, 220, 60)
local WHITE = Color3.new(1, 1, 1)
local ART = {
	Blocks = "rbxassetid://106477372921851", -- the panels' block sheet
	Studs = "rbxassetid://135496826236732", -- the buttons' stud strip
	Arrow = "rbxassetid://74885007861450", -- the Evolve panel's arrow; points up
	Backpack = "rbxassetid://139874655682754",
	Evolve = "rbxassetid://92164600998462",
	Rebirth = "rbxassetid://129578402198506", -- the sidebar Rebirth button's icon (and the panel's header Icon)
}
local GREEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 255, 65)),
	ColorSequenceKeypoint.new(0.46, Color3.fromRGB(54, 248, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 165, 44)),
})
local RED = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 119, 121)),
	ColorSequenceKeypoint.new(0.46, Color3.fromRGB(255, 34, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 14, 50)),
})
local NAVY = ColorSequence.new(PLATE, Color3.fromRGB(28, 46, 78))
-- Which way the arrow turns to point at the button, by the side the card sits on.
local ARROW_ROTATION = { right = 270, left = 90, top = 180, bottom = 0 }

local function create(class, props, parent)
	local item = Instance.new(class)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end

local function round(item, scale, offset)
	return create("UICorner", {CornerRadius = UDim.new(scale or 0, offset or 0)}, item)
end

local function outline(item, thickness, color)
	return create("UIStroke", {Name = "Outline", Color = color or INK, Thickness = thickness}, item)
end

local function words(parent, props, maxSize, stroke, lang)
	local label = create("TextLabel", {BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE, TextScaled = true, TextWrapped = true, Active = false}, parent)
	for key, value in props do label[key] = value end
	create("UITextSizeConstraint", {MaxTextSize = maxSize, MinTextSize = 7}, label)
	outline(label, stroke)
	Text.Style(label, lang) -- already in the player's language: no automatic translation on top
	return label
end

-- The designer's button recipe: studs over a bright fill, a light rim inside a dark edge.
local function studFill(item, colors, rimColor, edgeColor, radius)
	item.BackgroundColor3 = WHITE
	item.BorderSizePixel = 0
	round(item, 0, radius)
	create("UIGradient", {Name = "Fill", Rotation = 90, Color = colors}, item)
	local studs = create("ImageLabel", {Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = ART.Studs, ImageTransparency = 0.2, Active = false, ZIndex = item.ZIndex}, item)
	round(studs, 0, radius)
	local rim = create("UIStroke", {Name = "Rim", Color = rimColor, Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, item)
	pcall(function() rim.BorderOffset = UDim.new(0, -2) end)
	local edge = create("UIStroke", {Name = "Edge", Color = edgeColor, Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, item)
	pcall(function() edge.ZIndex = 2 end)
end

-- Builds the card. Everything inside is scale-sized, so it follows Layout.CardSize.
-- icon: the image on its top edge (true/false still mean the Evolve/Backpack art).
local function buildCard(canvas, icon, stepCount, lang)
	if type(icon) == "boolean" then icon = if icon then ART.Evolve else ART.Backpack end
	local card = create("Frame", {Name = "InstructionCard", BackgroundTransparency = 1, Visible = false, ZIndex = 10,
		AnchorPoint = Vector2.new(0.5, 0.5)}, canvas) -- centred, so the pop grows from its middle
	local pop = create("UIScale", {Name = "Pop", Scale = 0.6}, card)
	-- The window leaves the top band of the card to the icon and the title, which sit on
	-- its top edge as they do on the authored panels.
	local window = create("Frame", {Name = "Window", Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(1, 0.85),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 10}, card)
	round(window, 0, 14)
	create("UIStroke", {Name = "Edge", Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, window)
	local blocks = create("ImageLabel", {Name = "Background", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = ART.Blocks, ImageTransparency = 0.15, ScaleType = Enum.ScaleType.Crop, ZIndex = 10}, window)
	round(blocks, 0, 14)
	local iconLabel = create("ImageLabel", {Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0.015, 0), Size = UDim2.fromScale(0.4, 0.4), SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = icon or ART.Backpack, Rotation = -8, ZIndex = 13}, card)
	local title = words(card, {Name = "Title", Position = UDim2.fromScale(0.2, 0), Size = UDim2.fromScale(0.78, 0.3),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ZIndex = 13}, 34, 3, lang)
	local plate = create("Frame", {Name = "Plate", Position = UDim2.fromScale(0.04, 0.34), Size = UDim2.fromScale(0.92, 0.4),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 11}, card)
	round(plate, 0, 10)
	local plateFill = create("UIGradient", {Name = "Fill", Rotation = 90, Color = NAVY}, plate)
	local message = words(plate, {Name = "Message", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.84), ZIndex = 12}, 30, 2.5, lang)
	local pills = {}
	for i = 1, stepCount do
		local pill = create("Frame", {Name = "Step" .. i, Position = UDim2.fromScale(0.05 + (i - 1) * 0.1, 0.835),
			Size = UDim2.fromScale(0.08, 0.075), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 11}, card)
		round(pill, 1, 0)
		create("UIStroke", {Name = "Edge", Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, pill)
		pills[i] = {Frame = pill, Fill = create("UIGradient", {Name = "Fill", Rotation = 90, Color = NAVY}, pill)}
	end
	local skip = create("TextButton", {Name = "Skip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0.96, 0.87),
		Size = UDim2.fromScale(0.3, 0.17), AutoButtonColor = false, Text = "", ZIndex = 12}, card)
	pcall(function() skip.AutoLocalize = false end)
	studFill(skip, RED, Color3.fromRGB(255, 190, 195), Color3.fromRGB(84, 11, 12), 9)
	words(skip, {Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.88, 0.78), Text = Text.Get("Skip", lang), TextWrapped = false, ZIndex = 13}, 20, 1.5, lang).Outline.Color = Color3.fromRGB(84, 11, 12)
	return {Card = card, Pop = pop, Icon = iconLabel, Title = title, Message = message, PlateFill = plateFill, Pills = pills, Skip = skip}
end

Guide._BuildCard = buildCard -- for audit/test_fable_tutorial_portal

function Guide.IsOpen()
	return activeGui ~= nil
end

-- How long the guide has to be on screen before it counts as seen: the runner has been shown
-- the button, and one who ignores it or leaves is not shown it again on every server.
Guide.SEEN_AFTER_SECONDS = 10

-- A rebirth guide whose runner can no longer rebirth closes (not saved) once that has lasted
-- this long: the server resets Level a moment before it raises Rebirths, and that moment is a
-- rebirth being done, not one taken away.
Guide.REBIRTH_LOST_AFTER_SECONDS = 1

----------------------------------------------------------------------
-- The guides. Each mode names its saved flag, its card (icon, step pills, texts), where its
-- panel lives, when it is done, when it has nothing left to teach, and its step for this frame.
----------------------------------------------------------------------
local function rebirthCount(player)
	local count = tonumber(player:GetAttribute("Rebirths")) or 0
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Rebirths")
	if value and tonumber(value.Value) then
		count = math.max(count, tonumber(value.Value))
	end
	return count
end

-- What RebirthController reads: Level against the next rebirth's required level.
local function canRebirth(player)
	local level = tonumber(player:GetAttribute("Level"))
	if not level then
		local data = player:FindFirstChild("SpeedsterData")
		local value = data and data:FindFirstChild("Level")
		level = value and tonumber(value.Value) or 1
	end
	local required = tonumber(player:GetAttribute("NextRebirthLevelRequired"))
		or tonumber(player:GetAttribute("NextRebirthSpeedRequired")) or 5
	return level >= required
end
-- Exposed for audit/test_i18n_rebirth_guide. UI/RebirthController's gate applies the same rule
-- (Level >= NextRebirthLevelRequired) with its own authoritative getters; if the two ever
-- disagree the guide still cannot flicker: Start refuses (returns false, nothing shown) when this
-- says no, and once started it only closes when this rule changes its answer.
Guide._CanRebirth = canRebirth
Guide._RebirthCount = rebirthCount

local function panelOpen(ctx)
	return ctx.visible(ctx.main) and ctx.main.Position.Y.Scale < 0.9
end

local MODES = {}

-- "Your first aura": backpack -> Auras tab -> buy/equip the Orange Aura (Aura05).
MODES.Backpack = {
	SeenKey = "BackpackTutorialSeen", Icon = ART.Backpack, Steps = 3, Button = "Backpack",
	OpenKey = "AuraOpen", DoneKey = "AuraDone",
	Resolve = function(_player, pg, backpack)
		return { gui = backpack, main = backpack:FindFirstChild("MainFrame") }
	end,
	Complete = function(ctx, player, data)
		local equippedValue = data and data:FindFirstChild("EquippedAura")
		return player:GetAttribute("EquippedAuraId") == "Aura05" or (equippedValue and equippedValue.Value == "Aura05")
	end,
	OnComplete = function(player)
		player:SetAttribute("SpeedsterTutorialEquipDone", true)
	end,
	Step = function(ctx, player, data)
		local target, message, title, step = ctx.openButton, "AuraMsg1", "AuraTitle1", 1
		if panelOpen(ctx) then
			if not ctx.auraScroll.Visible then
				target, message, title, step = ctx.auraTab, "AuraMsg2", "AuraTitle2", 2
				ctx.scrolled = false
			else
				local orange = ctx.auraScroll:FindFirstChild("Orange")
				target = orange and orange:FindFirstChild("WinsPurchase", true)
				local owned = data and data:FindFirstChild("OwnedAuras")
				local entry = owned and owned:FindFirstChild("Aura05")
				local hasAura = entry and (not entry:IsA("BoolValue") or entry.Value)
				message = if hasAura then "AuraMsgEquip" else "AuraMsgGet"
				title, step = "AuraTitle3", 3
				if target and not ctx.scrolled then
					local auraScroll = ctx.auraScroll
					local y = target.AbsolutePosition.Y - auraScroll.AbsolutePosition.Y + auraScroll.CanvasPosition.Y
					auraScroll.CanvasPosition = Vector2.new(0, math.clamp(y - 60, 0,
						math.max(0, auraScroll.AbsoluteCanvasSize.Y - auraScroll.AbsoluteWindowSize.Y)))
					ctx.scrolled = true
				end
			end
		else
			ctx.scrolled = false
		end
		return target, message, title, step
	end,
}

-- "Ready to evolve": sidebar Evolve -> the panel's EvolveButton; done when the target suit is owned.
MODES.Evolve = {
	SeenKey = "EvolveTutorialSeen", Icon = ART.Evolve, Steps = 2, Button = "Evolve",
	OpenKey = "EvolveOpen", DoneKey = "EvolveDone",
	Resolve = function(player, pg)
		local targetId = player:GetAttribute("EvolveGuideTarget")
		if not targetId then return nil end
		local evolveGui = pg:FindFirstChild("Evolve")
		return { gui = evolveGui, main = evolveGui and evolveGui:FindFirstChild("Evolve"), targetId = targetId }
	end,
	Complete = function(ctx, player, data)
		local ownedSkins = data and data:FindFirstChild("OwnedSkins")
		local evolved = ctx.targetId and ownedSkins and ownedSkins:FindFirstChild(ctx.targetId)
		return (evolved and evolved.Value == true) or player:GetAttribute("EquippedSkin") == ctx.targetId
	end,
	Gone = function(ctx, player)
		return (tonumber(player:GetAttribute("EvolveAvailableCount")) or 0) <= 0
	end,
	Step = function(ctx)
		if panelOpen(ctx) then
			return ctx.main:FindFirstChild("EvolveButton"), "EvolveMsg2", "EvolveTitle2", 2
		end
		return ctx.openButton, "EvolveMsg1", "EvolveTitle1", 1
	end,
}

-- "Ready to rebirth" (2026-09-22): sidebar Rebirth -> the panel's free Rebirth button (not the
-- Robux RebirthBuy); done when the rebirth count rises past its value at Start.
MODES.Rebirth = {
	SeenKey = "RebirthTutorialSeen", Icon = ART.Rebirth, Steps = 2, Button = "Rebirth",
	OpenKey = "RebirthOpen", DoneKey = "RebirthDone",
	Resolve = function(player, pg)
		if not canRebirth(player) then return nil end
		local rebirthGui = pg:FindFirstChild("Rebirth")
		local main = rebirthGui and rebirthGui:FindFirstChild("Rebirth")
		local button = nil
		for _, child in (if main then main:GetChildren() else {}) do
			if child.Name == "Rebirth" and child:IsA("GuiButton") then button = child end
		end
		if not button then return nil end
		return { gui = rebirthGui, main = main, rebirthButton = button, startCount = rebirthCount(player), lostFor = 0 }
	end,
	Complete = function(ctx, player)
		return rebirthCount(player) > ctx.startCount
	end,
	Gone = function(ctx, player, dt)
		if canRebirth(player) then
			ctx.lostFor = 0
			return false
		end
		ctx.lostFor += dt or 0
		return ctx.lostFor >= Guide.REBIRTH_LOST_AFTER_SECONDS
	end,
	Step = function(ctx)
		if panelOpen(ctx) then
			return ctx.rebirthButton, "RebirthMsg2", "RebirthTitle2", 2
		end
		return ctx.openButton, "RebirthMsg1", "RebirthTitle1", 1
	end,
}
Guide._Modes = MODES

local SEEN_KEYS = {}
for kind, mode in MODES do SEEN_KEYS[kind] = mode.SeenKey end

-- The flag is sent again a little later: the server drops a SettingsUpdate that lands within
-- 0.05 s of another one (RemoteGuard, e.g. while a volume slider is dragged), and the client
-- cannot tell whether its own copy was kept. Saving true again is harmless.
Guide.SEEN_RESEND_AFTER = { 2, 6 }

-- 2026-09-21: "seen" used to be only a client attribute, gone on the next server, so the Evolve
-- guide came back on every join while an evolution was waiting. The profile now keeps it
-- (Settings, projected back as the same attribute); this is the one place the client asks
-- for it, and only once. kind: "Evolve", "Backpack" (the aura guide) or "Rebirth".
function Guide.MarkSeen(player, kind)
	local key = SEEN_KEYS[kind]
	if not key or player:GetAttribute(key) == true then return false end
	player:SetAttribute(key, true)
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local settingsUpdate = remotes and remotes:FindFirstChild("SettingsUpdate")
	if settingsUpdate then
		settingsUpdate:FireServer(key, true)
		for _, seconds in Guide.SEEN_RESEND_AFTER do
			task.delay(seconds, function()
				if player.Parent then settingsUpdate:FireServer(key, true) end
			end)
		end
	end
	return true
end

-- An open guide whose flag is already saved (10 s on screen) steps aside, e.g. for the one-time
-- world portal flight, which would otherwise wait out its 180 s behind an ignored guide
-- (2026-09-21). Its owner does not offer it again: the flag is saved.
function Guide.CloseIfSeen(player)
	if not activeGui or not activeSeenKey or player:GetAttribute(activeSeenKey) ~= true then
		return false
	end
	if stopCurrent then stopCurrent() end
	return true
end

-- mode: "Evolve", "Rebirth", or anything else for the aura guide ("Backpack").
function Guide.Start(player, onComplete, mode)
	if stopCurrent then stopCurrent() end
	local kind = if MODES[mode] then mode else "Backpack"
	local spec = MODES[kind]
	if kind == "Evolve" and not player:GetAttribute("EvolveGuideTarget") then return false end
	local pg = player:WaitForChild("PlayerGui")
	local hud = pg:WaitForChild("Mainhud", 5)
	local backpack = pg:WaitForChild("Backpack", 5)
	if not hud or not backpack then return false end
	local ctx = spec.Resolve(player, pg, backpack)
	if not ctx then return false end
	local main = ctx.main
	local sidebar = hud:FindFirstChild("LeftSideBar")
	local openButton = sidebar and sidebar:FindFirstChild(spec.Button)
	if not main or not openButton then return false end
	ctx.openButton = openButton
	local auraTab, auraScroll
	for _, child in main:GetChildren() do
		if child.Name == "Aura" then
			if child:IsA("GuiButton") then auraTab = child end
			if child:IsA("ScrollingFrame") then auraScroll = child end
		end
	end
	if kind == "Backpack" and (not auraTab or not auraScroll) then return false end
	ctx.auraTab, ctx.auraScroll = auraTab, auraScroll
	local lang = Text.ForPlayer(player)
	local order = math.max(hud.DisplayOrder, backpack.DisplayOrder, if ctx.gui then ctx.gui.DisplayOrder else 0) + 20
	-- Full-screen masks and a separate safe canvas use their own absolute origins.
	-- ClipToDeviceSafeArea is on by default: it would cut the shade off at a phone's notch
	-- and home-bar strips, which would stay lit.
	local dimGui = create("ScreenGui", {Name = "SpeedsterGuidedDimmer", ResetOnSpawn = false,
		DisplayOrder = order, ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
	local dimCanvas = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, dimGui)
	local shades = {}
	for _, name in {"Top", "Bottom", "Left", "Right"} do
		shades[name] = create("Frame", {Name = name, BackgroundColor3 = Color3.fromRGB(4, 10, 22),
			BorderSizePixel = 0, BackgroundTransparency = 1, Active = false}, dimCanvas)
		TweenService:Create(shades[name], TweenInfo.new(0.3), {BackgroundTransparency = 0.42}):Play()
	end
	local gui = create("ScreenGui", {Name = "SpeedsterGuidedSpotlight", ResetOnSpawn = false,
		DisplayOrder = order + 1, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, pg)
	activeGui = gui
	activeSeenKey = spec.SeenKey
	local canvas = create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, gui)
	-- The ring: gold with the HUD's navy line outside it.
	local ring = create("Frame", {Name = "HighlightRing", BackgroundTransparency = 1, Visible = false, ZIndex = 5}, canvas)
	round(ring, 0, 14)
	create("UIStroke", {Name = "Edge", Color = INK, Thickness = 7}, ring)
	local ringGold = create("Frame", {Name = "Gold", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6}, ring)
	round(ringGold, 0, 14)
	local stroke = create("UIStroke", {Name = "Glow", Color = GOLD, Thickness = 4}, ringGold)
	local arrow = create("ImageLabel", {Name = "Pointer", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40), Image = ART.Arrow, ImageColor3 = GOLD, Visible = false, ZIndex = 8}, canvas)
	local parts = buildCard(canvas, spec.Icon, spec.Steps, lang)
	local card, skip = parts.Card, parts.Skip

	local connections, finished, transition = {}, false, nil
	local function destroy()
		if activeGui == gui then
			activeGui = nil
			activeSeenKey = nil
			player:SetAttribute("GuidedTutorialOpen", false)
		end
		dimGui:Destroy()
		gui:Destroy()
	end
	-- celebrate: the step was done. immediate: torn down with no goodbye (another guide taking
	-- over, its GUIs removed, nothing left to evolve or to rebirth); the guide's owner may offer
	-- it again. Neither: the player skipped it. A respawn no longer closes it (2026-09-21):
	-- Mainhud, Evolve, Backpack and Rebirth keep ResetOnSpawn off in every place, so its targets
	-- survive, and closing it only made it pop up again after every obstacle death.
	local function stop(celebrate, immediate)
		if finished then
			if immediate then destroy() end
			return
		end
		finished = true
		for _, conn in connections do conn:Disconnect() end
		if transition then transition:Cancel() end
		if not immediate then
			Guide.MarkSeen(player, kind)
		end
		if immediate then destroy(); return end
		ring.Visible, arrow.Visible = false, false
		for _, shade in shades do TweenService:Create(shade, TweenInfo.new(0.22), {BackgroundTransparency = 1}):Play() end
		if celebrate then
			parts.Title.Text = Text.Get("NiceJob", lang)
			parts.Message.Text = Text.Get(spec.DoneKey, lang)
			parts.PlateFill.Color = GREEN
			skip.Visible = false
			for _, pill in parts.Pills do pill.Fill.Color = GREEN end
			parts.Pop.Scale = 0.9
			TweenService:Create(parts.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			TweenService:Create(parts.Icon, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 2, true), {Rotation = 10}):Play()
			if onComplete then onComplete() end
		end
		task.delay(if celebrate then 1.5 else 0, function()
			if card.Parent then
				TweenService:Create(parts.Pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
			end
			task.delay(0.2, destroy)
		end)
	end
	stopCurrent = function() stop(false, true) end
	player:SetAttribute("GuidedTutorialOpen", true)
	table.insert(connections, skip.Activated:Connect(function() stop(false) end))
	local currentKey, cardPosition = nil, nil
	local shownFor = 0 -- continuous seconds on screen (a cinematic hiding it starts it over)
	local function visible(target)
		local node = target
		while node and node ~= pg do
			if node:IsA("GuiObject") and not node.Visible then return false end
			if node:IsA("ScreenGui") and not node.Enabled then return false end
			node = node.Parent
		end
		return node == pg
	end
	ctx.visible = visible
	-- Layout.Shades answers in whole pixels with shared edges: no line between two shades,
	-- none along a screen edge. Returns the hole it left, in the dimmer's pixels.
	local function shadeAround(x, y, w, h)
		local full = dimCanvas.AbsoluteSize
		local rects = Layout.Shades(full.X, full.Y, x, y, w, h)
		for name, shade in shades do
			local rect = rects[name]
			shade.Position = UDim2.fromOffset(rect.x, rect.y)
			shade.Size = UDim2.fromOffset(rect.w, rect.h)
		end
		return rects.Hole
	end
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if not main.Parent or not hud.Parent or not gui.Parent then stop(false, true); return end
		-- UI/ConsoleUiScale gives every new ScreenGui the TV-safe insets on consoles.
		if dimGui.ScreenInsets ~= Enum.ScreenInsets.None then
			dimGui.ScreenInsets = Enum.ScreenInsets.None
			dimGui.ClipToDeviceSafeArea = false
		end
		local data = player:FindFirstChild("SpeedsterData")
		if spec.Complete(ctx, player, data) then
			if spec.OnComplete then spec.OnComplete(player) end
			stop(true)
			return
		end
		if spec.Gone and spec.Gone(ctx, player, dt) then stop(false, true); return end
		local target, messageKey, titleKey, step = spec.Step(ctx, player, data)
		local vp = canvas.AbsoluteSize
		if vp.X < 100 or vp.Y < 160 then return end
		local cw, ch = Layout.CardSize(vp.X, vp.Y, openButton.AbsoluteSize.Y)
		local ready = target and visible(target) and target.AbsoluteSize.X > 2
		local x, y, w, h = 0, 0, 0, 0
		if ready then
			local pos = target.AbsolutePosition - canvas.AbsolutePosition
			local size = target.AbsoluteSize
			x, y = math.max(0, pos.X - 6), math.max(0, pos.Y - 6)
			local right, bottom = math.min(vp.X, pos.X + size.X + 6), math.min(vp.Y, pos.Y + size.Y + 6)
			if auraScroll and target:IsDescendantOf(auraScroll) then
				local clip = auraScroll.AbsolutePosition - canvas.AbsolutePosition
				x, y = math.max(x, clip.X), math.max(y, clip.Y)
				right = math.min(right, clip.X + auraScroll.AbsoluteWindowSize.X)
				bottom = math.min(bottom, clip.Y + auraScroll.AbsoluteWindowSize.Y)
			end
			w, h = right - x, bottom - y
			ready = w > 0 and h > 0
		end
		ring.Visible, arrow.Visible = ready == true, ready == true
		local layout
		if ready then
			-- The ring, the arrow and the card use the same whole-pixel hole as the shade.
			local offset = canvas.AbsolutePosition - dimCanvas.AbsolutePosition
			local ox, oy = math.floor(offset.X + 0.5), math.floor(offset.Y + 0.5)
			local hole = shadeAround(x + ox, y + oy, w, h)
			x, y, w, h = hole.x - ox, hole.y - oy, hole.w, hole.h
			ring.Position, ring.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
			layout = Layout.Place(vp.X, vp.Y, x, y, w, h, cw, ch)
			local arrowSize = math.clamp(ch * 0.26, 24, 44)
			local reach = 15 + 3 * math.sin(os.clock() * 5)
			local positions = {right = {x + w + reach, y + h / 2}, left = {x - reach, y + h / 2},
				top = {x + w / 2, y - reach}, bottom = {x + w / 2, y + h + reach}}
			local pointer = positions[layout.side]
			arrow.Size = UDim2.fromOffset(arrowSize, arrowSize)
			arrow.Position = UDim2.fromOffset(math.clamp(pointer[1], 14, vp.X - 14), math.clamp(pointer[2], 14, vp.Y - 14))
			arrow.Rotation = ARROW_ROTATION[layout.side]
		else
			shadeAround(0, 0, 0, 0)
			layout = {x = math.max(10, (vp.X - cw) / 2), y = 10, w = cw, h = ch}
			messageKey = spec.OpenKey
		end
		local destination = Vector2.new(layout.x, layout.y)
		-- Follow small layout changes smoothly, but never animate across the target button.
		local nextPosition = if cardPosition then cardPosition:Lerp(destination, 1 - math.exp(-18 * dt)) else destination
		local overlaps = ready and nextPosition.X < x + w and nextPosition.X + layout.w > x
			and nextPosition.Y < y + h and nextPosition.Y + layout.h > y
		cardPosition = if overlaps then destination else nextPosition
		cardPosition = Vector2.new(math.clamp(cardPosition.X, 10, math.max(10, vp.X - layout.w - 10)),
			math.clamp(cardPosition.Y, 10, math.max(10, vp.Y - layout.h - 10)))
		card.Position = UDim2.fromOffset(cardPosition.X + layout.w / 2, cardPosition.Y + layout.h / 2)
		card.Size = UDim2.fromOffset(layout.w, layout.h)
		card.Visible = true
		if gui.Enabled and dimGui.Enabled then
			shownFor += dt
			if shownFor >= Guide.SEEN_AFTER_SECONDS then
				Guide.MarkSeen(player, kind)
			end
		else
			shownFor = 0
		end
		local key = tostring(step) .. messageKey
		if currentKey ~= key then
			local first = currentKey == nil
			currentKey = key
			if transition then transition:Cancel() end
			parts.Pop.Scale = if first then 0.6 else 0.9
			transition = TweenService:Create(parts.Pop, TweenInfo.new(if first then 0.32 else 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
			transition:Play()
			parts.Message.Text, parts.Title.Text = Text.Get(messageKey, lang), Text.Get(titleKey, lang)
			for i, pill in parts.Pills do
				pill.Fill.Color = if i <= step then GREEN else NAVY
			end
		end
		stroke.Transparency = 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 4))
	end))
	return true
end
return Guide
