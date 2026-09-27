-- MessageHandler.client.luau
-- Global announcements (Social/GlobalAnnouncementService, Admin/AdminAbusePanelService):
-- a slim ticker that slides in just under Roblox's top bar, one at a time. It is drawn in
-- the announcement's theme (Gold, Rainbow, Alert, Ice or Party): a thin coloured strip with
-- the sender's avatar, the title and sender on a small line, the message typed out under
-- it, a shine sweeping across, a bar that runs down while it shows, and a sound on arrival.
-- (2026-09-18, Sung: "global announcements could be much smaller"; the old banner was 150
-- px tall, flashed the whole screen and covered the run.)
--
-- Admins announce from the admin panel's Announcements tab (Admin/AdminAbusePanelController),
-- or with /g <message> in chat.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage
local DisplayRemote = Remotes:WaitForChild("DisplayGlobalAnnouncement")

gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local sound = script:FindFirstChild("Sound") or Instance.new("Sound", script)
sound.SoundId = "rbxassetid://72264591133889"
sound.Volume = 0.8

-- The banners live in their own ScreenGui, drawn sibling by sibling above the HUD.
local stage = Instance.new("ScreenGui")
stage.Name = "AnnouncementsGui"
stage.ResetOnSpawn = false
stage.IgnoreGuiInset = true
stage.DisplayOrder = 150
stage.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
stage.Parent = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(11, 27, 45)
local STUDS = "rbxassetid://6927295847"
-- Icon is drawn on its own, beside the title: an emoji inside outlined, scaled text sits
-- off its line and picks up the outline.
local THEMES = {
	Gold = { Top = Color3.fromRGB(255, 226, 90), Bottom = Color3.fromRGB(255, 140, 20), Stroke = Color3.fromRGB(120, 60, 0), Icon = "📢", Title = "GLOBAL ANNOUNCEMENT" },
	Rainbow = { Top = Color3.fromRGB(255, 255, 255), Bottom = Color3.fromRGB(230, 230, 230), Stroke = INK, Icon = "🌈", Title = "GLOBAL ANNOUNCEMENT", Rainbow = true },
	Alert = { Top = Color3.fromRGB(255, 90, 90), Bottom = Color3.fromRGB(170, 20, 30), Stroke = Color3.fromRGB(70, 0, 5), Icon = "🚨", Title = "ATTENTION!", Pulse = true },
	Ice = { Top = Color3.fromRGB(170, 235, 255), Bottom = Color3.fromRGB(40, 140, 230), Stroke = Color3.fromRGB(10, 50, 110), Icon = "❄️", Title = "GLOBAL ANNOUNCEMENT" },
	Party = { Top = Color3.fromRGB(255, 120, 220), Bottom = Color3.fromRGB(130, 60, 240), Stroke = Color3.fromRGB(50, 10, 90), Icon = "🎉", Title = "PARTY TIME!", Confetti = true },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 235, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 170)),
})
local TYPE_SECONDS_PER_CHARACTER = 0.025
local CARD_HEIGHT = 46
local CARD_WIDTH_SHARE = 0.50 -- of the screen, between CARD_MIN_WIDTH and CARD_MAX_WIDTH
local CARD_MIN_WIDTH = 340
local CARD_MAX_WIDTH = 580
local CORNER = 10
local BADGE = 34
local STICKER = 14 -- the megaphone sticker on the avatar
local STICKER_INSET = 6 -- its middle, in from the badge's corner
local EDGE = 6 -- the card's inner margin
local BODY_LEFT = EDGE + BADGE + 8
local TITLE_HEIGHT = 14
local BAR_HEIGHT = 3
local SHINE_SECONDS = 2.8 -- one sweep and a short rest

-- Just under Roblox's top bar (the ticker's gui ignores the inset).
local function topInset(): number
	local ok, inset = pcall(function()
		return game:GetService("GuiService"):GetGuiInset().Y
	end)
	return if ok and type(inset) == "number" then inset else 40
end
local HIDDEN_Y = -(CARD_HEIGHT + 20)

local queue = {}
local showing = false

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- An emoji on its own: a fixed size, centred, never outlined.
local function emoji(name, text, size, parent)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = false,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text,
		ZIndex = 4,
	}, parent)
end

local function escapeAnnouncementText(value)
	return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end

local function displayAnnouncement(payload: any, legacyDuration: number?)
	local messageText = ""
	local senderName = "ADMIN"
	local senderId = 0
	local duration = legacyDuration or 8
	local themeName = "Gold"
	local soundId = "rbxassetid://72264591133889"

	if type(payload) == "table" then
		messageText = tostring(payload.Message or "")
		senderName = tostring(payload.SenderName or "ADMIN")
		senderId = tonumber(payload.SenderId) or 0
		duration = tonumber(payload.Duration) or 8
		themeName = tostring(payload.Theme or "Gold")
		local customSound = payload.SoundId or payload.soundId
		if type(customSound) == "string" and customSound ~= "" then
			soundId = customSound
		end
	elseif type(payload) == "string" then
		messageText = payload
	end
	if #messageText == 0 then
		return
	end
	duration = math.clamp(duration, 4, 30)
	local theme = THEMES[themeName] or THEMES.Gold

	-- Clean up any existing announcement cards so banners never physically overlap
	for _, child in stage:GetChildren() do
		if child.Name == "Announcement" then
			child:Destroy()
		end
	end

	-- The card.
	local card = make("Frame", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
		Size = UDim2.new(CARD_WIDTH_SHARE, 0, 0, CARD_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, stage)
	make("UISizeConstraint", { MaxSize = Vector2.new(CARD_MAX_WIDTH, CARD_HEIGHT), MinSize = Vector2.new(CARD_MIN_WIDTH, CARD_HEIGHT) }, card)
	make("UICorner", { CornerRadius = UDim.new(0, CORNER) }, card)
	local stroke = make("UIStroke", { Color = theme.Stroke, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	local fill = make("UIGradient", {
		Color = if theme.Rainbow then RAINBOW else ColorSequence.new(theme.Top, theme.Bottom),
		Rotation = if theme.Rainbow then 0 else 90,
	}, card)
	local studs = make("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = STUDS,
		ImageTransparency = 0.82,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(24, 24),
		ZIndex = 0,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, CORNER) }, studs)
	local scale = make("UIScale", { Scale = 0.85 }, card)

	-- The shine: a bright band of a gradient over the whole card, slid across it. The band
	-- lives inside the card's own rounded shape, so it can never show outside the card.
	local shine = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, CORNER) }, shine)
	local shineBand = make("UIGradient", {
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)

	-- The sender's badge, with the megaphone sticker on its corner.
	local badge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, EDGE, 0.5, 0),
		Size = UDim2.fromOffset(BADGE, BADGE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		ZIndex = 2,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	make("UIStroke", { Color = theme.Stroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	local avatar = make("ImageLabel", {
		Name = "Avatar",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = "",
		ZIndex = 3,
	}, badge)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
	local megaphone
	if senderId > 0 then
		megaphone = make("Frame", {
			Name = "Megaphone",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -STICKER_INSET, 1, -STICKER_INSET),
			Size = UDim2.fromOffset(STICKER, STICKER),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 4,
		}, badge)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, megaphone)
		make("UIStroke", { Color = theme.Stroke, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, megaphone)
		emoji("Icon", "📢", 11, megaphone)
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(senderId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and avatar.Parent then
				avatar.Image = image
			end
		end)
	else
		-- No avatar: the megaphone fills the badge.
		megaphone = make("Frame", {
			Name = "Megaphone",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, badge)
		emoji("Icon", "📢", 24, megaphone)
	end

	-- The words, in a column right of the badge: the small title line, then the message.
	local body = make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(BODY_LEFT, 5),
		Size = UDim2.new(1, -(BODY_LEFT + EDGE), 1, -(5 + BAR_HEIGHT + 7)),
		ZIndex = 2,
	}, card)
	local header = make("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		ZIndex = 2,
	}, body)
	local iconHolder = make("Frame", {
		Name = "ThemeIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(TITLE_HEIGHT, TITLE_HEIGHT),
		ZIndex = 2,
	}, header)
	emoji("Icon", theme.Icon, 13, iconHolder)
	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(TITLE_HEIGHT + 4, 0),
		Size = UDim2.new(1, -(TITLE_HEIGHT + 4), 1, 0),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		RichText = true,
		Text = theme.Title .. '  <font transparency="0.25">from ' .. escapeAnnouncementText(senderName) .. "</font>",
		ZIndex = 3,
	}, header)
	make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, title)
	make("UIStroke", { Color = theme.Stroke, Thickness = 1.5 }, title)
	local message = make("TextLabel", {
		Name = "Message",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TITLE_HEIGHT + 1),
		Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + 1)),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Color3.new(1, 1, 1),
		Text = messageText,
		MaxVisibleGraphemes = 0,
		ZIndex = 3,
	}, body)
	make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 10 }, message)
	make("UIStroke", { Color = INK, Thickness = 2 }, message)

	-- The bar that runs down while it shows.
	local barBack = make("Frame", {
		Name = "TimeBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, BODY_LEFT, 1, -4),
		Size = UDim2.new(1, -(BODY_LEFT + EDGE), 0, BAR_HEIGHT),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.5,
		ZIndex = 2,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
	local bar = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, barBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

	-- A flash of the ticker itself on arrival (never the whole screen: it hid the run).
	local flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, CORNER) }, flash)
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()

	pcall(function()
		sound.SoundId = soundId
		sound.TimePosition = 0
		sound:Play()
	end)

	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, topInset() + 6) }):Play()
	TweenService:Create(scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local started = os.clock()
	local graphemes = utf8.len(messageText) or #messageText
	local connection = RunService.RenderStepped:Connect(function(dt)
		local elapsed = os.clock() - started
		message.MaxVisibleGraphemes = math.min(graphemes, math.floor(elapsed / TYPE_SECONDS_PER_CHARACTER))
		bar.Size = UDim2.fromScale(math.clamp(1 - elapsed / duration, 0, 1), 1)
		-- The band crosses in the first 70% of each sweep, then the card rests.
		local sweep = math.min((elapsed % SHINE_SECONDS) / (SHINE_SECONDS * 0.7), 1)
		shineBand.Offset = Vector2.new(-1 + sweep * 2, 0)
		megaphone.Rotation = math.sin(elapsed * 9) * 12
		if theme.Rainbow then
			fill.Offset = Vector2.new((elapsed * 0.4) % 2 - 1, 0)
			stroke.Color = Color3.fromHSV(elapsed * 0.3 % 1, 0.8, 0.55)
		end
		if theme.Pulse then
			stroke.Thickness = 3 + math.abs(math.sin(elapsed * 6)) * 2
		end
	end)

	task.wait(duration)
	message.MaxVisibleGraphemes = -1
	local out = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) })
	out:Play()
	pcall(function()
		out.Completed:Wait()
	end)
	connection:Disconnect()
	if card.Parent then
		card:Destroy()
	end
end

-- One banner at a time; the next waits for the one on screen.
DisplayRemote.OnClientEvent:Connect(function(payload, legacyDuration)
	-- Discard any automated Spin Wheel announcements so screen banners remain strictly for Admin announcements
	if type(payload) == "table" and payload.SenderName == "SPIN WHEEL" then
		return
	end

	table.insert(queue, { payload, legacyDuration })
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local ok, problem = pcall(displayAnnouncement, item[1], item[2])
		if not ok then
			warn("[MessageHandler] " .. tostring(problem))
		end
	end
	showing = false
end)
