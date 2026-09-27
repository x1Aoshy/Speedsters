-- CommunityRewardsController.client.luau (Update 4, 2026-09-25)
-- The designer's "Community rewards" panel (uineww.rbxm, put in StarterGui by the build), used
-- as it is: root frame "Community rewards" with Title, Icon, Close, the Redeem button, Frame
-- (steps 1/2/3 and InsertCode's TextBox) and Itemsframe (Unlock and two frames named Item1).
-- Opens through MenuEvents "Community" (the topbar icon); Social/CommunityRewardService answers.
--
-- What the steps say depends on the server's policy answer (never decided here):
--   DiscordAllowed   join the Discord server (the link is on the game page, never here),
--                    /getcode, type the code, Redeem.
--   otherwise        the word "Discord" is never shown: step 1 joins our Roblox group (tap it:
--                    GroupService:PromptJoinAsync), the code box is hidden and Redeem asks the
--                    server to check the membership.
-- Until the first answer arrives the panel is in the group form, which is safe for everyone.
-- Texts in English, Spanish and Portuguese (TutorialText's language), English otherwise.
--
-- 2026-09-26 (owner, phone playtest: "it's HUGE, the text overlaps" and "it doesn't work"):
--   * phones: MenuPanelLayout.PhoneBlock (window and header 80% of the room, raised), not 84% of
--     the room for the window alone with the gift and title on top of it;
--   * the reward texts sit beside their pictures, above them, sized to the free part of their
--     band (fitRewardTexts); the Member line spans its band;
--   * every answer shows in a pill above Redeem, in the player's language (the server's Reason),
--     where the old one-line status sat at the window's bottom edge, off screen on phones;
--   * a tap inside the server's 1 s guard is sent when the second is up, not dropped; Redeem
--     says "Checking..." at once; the group prompt's outcome (joined, request pending, closed,
--     failed) is told; the join button works before the server's first answer (GroupId from
--     Update4Config), and a fresh join is re-checked by the server (VerifyGroup "Joined").

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local gui = playerGui:WaitForChild("Community rewards", 8)
local window = gui and gui:WaitForChild("Community rewards", 5)
if not gui or not gui:IsA("ScreenGui") or not window or not window:IsA("GuiObject") then
	-- The designer's panel is not in this place yet (the build puts it there).
	warn("[CommunityRewardsController] 'Community rewards' panel not found; the Community reward has no window")
	return
end

local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))
local ModalJuice = require(Shared:WaitForChild("ModalJuice"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))
local U4 = require(Shared:WaitForChild("Update4Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("CommunityRewardRequest", 30)
local Update = Remotes:WaitForChild("CommunityRewardUpdate", 30)

local TEXT = {
	en = {
		Title = "Community Rewards",
		DiscordSteps = {
			{ "Join our Discord server.", "(Link on our game page.)" },
			{ "Type /getcode in the #reward-code channel." },
			{ "Enter your code and tap Redeem!" },
		},
		GroupSteps = {
			{ "Join our Roblox group.", "(Tap here to join.)" },
			{ "Come back to this window." },
			{ "Tap Redeem to get your reward!" },
		},
		Placeholder = "Insert Code...",
		Redeem = "Redeem",
		Claimed = "CLAIMED ✓",
		Unavailable = "Soon",
		Member = "Unlock the \"Member\" tag",
		Potion = "x2 Speed %dm",
		Spins = "%d Spins",
		EnterCode = "Enter a code first.",
		-- 2026-09-26: the server's answers (its Reason) and the join prompt's outcomes.
		Reasons = {
			Success = "Reward claimed! x2 Speed for %d min, %d Spins and the Member tag!",
			AlreadyClaimed = "You already claimed this reward.",
			NotMember = "Join our Roblox group first, then tap Redeem.",
			TooMany = "Too many tries. Wait a minute.",
			InvalidCode = "Invalid code.",
			UseCode = "Enter the code and tap Redeem.",
			Loading = "Your data is still loading. Try again.",
			Pending = "Saving your reward... tap Redeem again in a moment.",
			Failed = "The reward could not be given. Try again later.",
			Off = "The Community reward is not available right now.",
			Busy = "Please wait...",
		},
		CheckingGroup = "Checking your group membership...",
		CheckingCode = "Checking your code...",
		Joined = "Welcome to the group! Checking...",
		JoinPending = "Join request sent! Tap Redeem once it is accepted.",
		JoinFailed = "The group page could not open. Join our group from the game page, then tap Redeem.",
	},
	es = {
		Title = "Premios de la Comunidad",
		DiscordSteps = {
			{ "Únete a nuestro servidor de Discord.", "(Enlace en la página del juego.)" },
			{ "Escribe /getcode en el canal #reward-code." },
			{ "¡Escribe tu código y pulsa Canjear!" },
		},
		GroupSteps = {
			{ "Únete a nuestro grupo de Roblox.", "(Toca aquí para unirte.)" },
			{ "Vuelve a esta ventana." },
			{ "¡Pulsa Canjear para recibir tu premio!" },
		},
		Placeholder = "Escribe el código...",
		Redeem = "Canjear",
		Claimed = "RECLAMADO ✓",
		Unavailable = "Pronto",
		Member = "Desbloquea el título \"Member\"",
		Potion = "x2 Velocidad %dm",
		Spins = "%d Giros",
		EnterCode = "Escribe un código primero.",
		Reasons = {
			Success = "¡Premio reclamado! x2 Velocidad por %d min, %d Giros y el título Member!",
			AlreadyClaimed = "Ya reclamaste este premio.",
			NotMember = "Primero únete a nuestro grupo de Roblox y luego pulsa Canjear.",
			TooMany = "Demasiados intentos. Espera un minuto.",
			InvalidCode = "Código inválido.",
			UseCode = "Escribe el código y pulsa Canjear.",
			Loading = "Tus datos aún se están cargando. Inténtalo de nuevo.",
			Pending = "Guardando tu premio... pulsa Canjear otra vez en un momento.",
			Failed = "No se pudo dar el premio. Inténtalo más tarde.",
			Off = "El premio de la Comunidad no está disponible ahora.",
			Busy = "Espera un momento...",
		},
		CheckingGroup = "Comprobando que estás en el grupo...",
		CheckingCode = "Comprobando tu código...",
		Joined = "¡Bienvenido al grupo! Comprobando...",
		JoinPending = "¡Solicitud enviada! Pulsa Canjear cuando la acepten.",
		JoinFailed = "No se pudo abrir el grupo. Únete desde la página del juego y pulsa Canjear.",
	},
	pt = {
		Title = "Prêmios da Comunidade",
		DiscordSteps = {
			{ "Entre no nosso servidor do Discord.", "(Link na página do jogo.)" },
			{ "Digite /getcode no canal #reward-code." },
			{ "Digite seu código e toque em Resgatar!" },
		},
		GroupSteps = {
			{ "Entre no nosso grupo do Roblox.", "(Toque aqui para entrar.)" },
			{ "Volte para esta janela." },
			{ "Toque em Resgatar para ganhar seu prêmio!" },
		},
		Placeholder = "Digite o código...",
		Redeem = "Resgatar",
		Claimed = "RESGATADO ✓",
		Unavailable = "Em breve",
		Member = "Desbloqueie o título \"Member\"",
		Potion = "x2 Velocidade %dm",
		Spins = "%d Giros",
		EnterCode = "Digite um código primeiro.",
		Reasons = {
			Success = "Prêmio resgatado! x2 Velocidade por %d min, %d Giros e o título Member!",
			AlreadyClaimed = "Você já resgatou este prêmio.",
			NotMember = "Entre no nosso grupo do Roblox primeiro e toque em Resgatar.",
			TooMany = "Tentativas demais. Espere um minuto.",
			InvalidCode = "Código inválido.",
			UseCode = "Digite o código e toque em Resgatar.",
			Loading = "Seus dados ainda estão carregando. Tente de novo.",
			Pending = "Salvando seu prêmio... toque em Resgatar de novo em instantes.",
			Failed = "Não foi possível dar o prêmio. Tente mais tarde.",
			Off = "O prêmio da Comunidade não está disponível agora.",
			Busy = "Espere um momento...",
		},
		CheckingGroup = "Verificando se você está no grupo...",
		CheckingCode = "Verificando seu código...",
		Joined = "Bem-vindo ao grupo! Verificando...",
		JoinPending = "Pedido enviado! Toque em Resgatar quando for aceito.",
		JoinFailed = "Não foi possível abrir o grupo. Entre pela página do jogo e toque em Resgatar.",
	},
}
local lang = TutorialText.ForPlayer(player)
local L = TEXT[lang] or TEXT.en

-- The designer's pieces, found once (FindFirstChild: a renamed piece is skipped, not fatal).
local closeButton = window:FindFirstChild("Close")
local redeemButton = window:FindFirstChild("Redeem")
local redeemLabel = redeemButton and redeemButton:FindFirstChild("Name")
local titleLabel = window:FindFirstChild("Title")
local steps = window:FindFirstChild("Frame")
local codeFrame = steps and steps:FindFirstChild("InsertCode")
local codeBox = codeFrame and codeFrame:FindFirstChildWhichIsA("TextBox", true)
local items = window:FindFirstChild("Itemsframe")

-- A step's labels: the number ("1.") and its lines, top to bottom.
local function stepLines(step)
	local lines = {}
	for _, child in step:GetChildren() do
		if child:IsA("TextLabel") and not string.match(child.Text, "^%s*%d+%.%s*$") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	return lines
end
local stepLabels = {}
for index = 1, 3 do
	local step = steps and steps:FindFirstChild(tostring(index))
	stepLabels[index] = if step then stepLines(step) else {}
end

-- The designer left the hint in .Text; it belongs in the placeholder.
if codeBox then
	codeBox.Text = ""
	codeBox.PlaceholderText = L.Placeholder
	codeBox.ClearTextOnFocus = false
	codeBox.Selectable = true
end
if titleLabel and titleLabel:IsA("TextLabel") then
	titleLabel.Text = L.Title
end

-- BEGIN fitRewardTexts (audit/test_u4_community runs this block on the designer's panel)
-- 2026-09-26 (owner, phone screenshot): "the text overlaps and it's HUGE". The designer's reward
-- texts stood half under the potion pictures (the top card's "x2 Speed 30m" behind its potion,
-- "3 Spins" over the other one) at the pictures' own depth, TextScaled as big as their boxes.
-- Each card's picture (and its glow) is drawn at PictureScale, against the frame's edge on its
-- side and centred in its band (above or below the Member line); its text fills the rest of the
-- band beside it, a margin from the picture and the edges, drawn above it. The Member line spans
-- its band, centred. All in scale: every screen follows the same shapes.
local REWARD_TEXT = {
	Margin = 0.04, -- of the Itemsframe's width, kept from the picture and from the edges
	PictureScale = 0.8, -- the potions were wider than half the column: the text got 36% of it
	MaxTextSize = 40,
	MinTextSize = 8,
	MemberBox = { 0.04, 0.1, 0.92, 0.8 }, -- left, top, width, height in the Member line's scale
}

-- `object`'s box in its parent's scale: left, top, width, height.
local function scaleBox(object)
	local size, position, anchor = object.Size, object.Position, object.AnchorPoint
	return position.X.Scale - anchor.X * size.X.Scale, position.Y.Scale - anchor.Y * size.Y.Scale, size.X.Scale, size.Y.Scale
end

-- Puts `label` in the box (its parent's scale), `parentAspect` being the parent's width / height
-- in pixels, so its own shape constraint (if any) keeps that box.
local function setTextBox(label, left, top, width, height, parentAspect)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(left + width / 2, top + height / 2)
	label.Size = UDim2.fromScale(width, height)
	local shape = label:FindFirstChildOfClass("UIAspectRatioConstraint")
	if shape and height > 0 then
		shape.AspectRatio = width * parentAspect / height
	end
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	local cap = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not cap then
		cap = Instance.new("UITextSizeConstraint")
		cap.Parent = label
	end
	cap.MaxTextSize = REWARD_TEXT.MaxTextSize
	cap.MinTextSize = REWARD_TEXT.MinTextSize
end

local function fitRewardTexts(frame)
	local unlock = frame and frame:FindFirstChild("Unlock")
	local frameShape = frame and frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not unlock or not unlock:IsA("GuiObject") then
		return
	end
	-- The Itemsframe's width / height in pixels (its shape, else its Size on a square).
	local aspect = if frameShape and frameShape.AspectRatio > 0 then frameShape.AspectRatio else frame.Size.X.Scale / math.max(frame.Size.Y.Scale, 1e-6)
	local uLeft, uTop, uWidth, uHeight = scaleBox(unlock)
	local memberLabel = unlock:FindFirstChild("Title")
	if memberLabel and memberLabel:IsA("TextLabel") then
		local box = REWARD_TEXT.MemberBox
		setTextBox(memberLabel, box[1], box[2], box[3], box[4], uWidth * aspect / math.max(uHeight, 1e-6))
	end
	for _, card in frame:GetChildren() do
		local icon = card:IsA("GuiObject") and card:FindFirstChild("Icon")
		local label = card:IsA("GuiObject") and card:FindFirstChild("Title")
		if card.Name == "Item1" and icon and icon:IsA("GuiObject") and label and label:IsA("TextLabel") then
			local cLeft, cTop, cWidth, cHeight = scaleBox(card)
			local iLeft, iTop, iWidth, iHeight = scaleBox(icon)
			-- The card's band: above the Member line or below it, whichever holds its middle.
			local middle = cTop + cHeight / 2
			local bandTop, bandBottom = 0, uTop
			if middle > uTop + uHeight / 2 then
				bandTop, bandBottom = uTop + uHeight, 1
			end
			-- In the card's scale: the frame's edges, the band and the margins.
			local frameLeft, frameRight = -cLeft / cWidth, (1 - cLeft) / cWidth
			local marginX = REWARD_TEXT.Margin / cWidth
			local marginY = REWARD_TEXT.Margin * aspect / cHeight
			local top = (bandTop - cTop) / cHeight
			local bottom = (bandBottom - cTop) / cHeight
			-- The picture: smaller, against the edge on its side, centred in the band.
			local onLeft = (iLeft + iWidth / 2) - frameLeft <= frameRight - (iLeft + iWidth / 2)
			local pictureScale = REWARD_TEXT.PictureScale
			local width, height = iWidth * pictureScale, iHeight * pictureScale
			local pictureLeft = if onLeft then frameLeft + marginX else frameRight - marginX - width
			local centreX, centreY = pictureLeft + width / 2, (top + bottom) / 2
			local light = card:FindFirstChild("Light")
			if light and light:IsA("GuiObject") then
				-- Its glow keeps its place around it, at the same scale.
				local lLeft, lTop, lWidth, lHeight = scaleBox(light)
				local dx = lLeft + lWidth / 2 - (iLeft + iWidth / 2)
				local dy = lTop + lHeight / 2 - (iTop + iHeight / 2)
				light.AnchorPoint = Vector2.new(0.5, 0.5)
				light.Position = UDim2.fromScale(centreX + dx * pictureScale, centreY + dy * pictureScale)
				light.Size = UDim2.fromScale(lWidth * pictureScale, lHeight * pictureScale)
			end
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(centreX, centreY)
			icon.Size = UDim2.fromScale(width, height)
			-- The text: the rest of the band.
			local left, right
			if onLeft then
				left, right = pictureLeft + width + marginX, frameRight - marginX
			else
				left, right = frameLeft + marginX, pictureLeft - marginX
			end
			if right > left and bottom - top > 2 * marginY then
				setTextBox(label, left, top + marginY, right - left, bottom - top - 2 * marginY, cWidth * aspect / cHeight)
			end
			-- Above the picture and its glow, whatever their depth.
			local depth = label.ZIndex
			for _, other in card:GetChildren() do
				if other ~= label and other:IsA("GuiObject") then
					depth = math.max(depth, other.ZIndex + 1)
				end
			end
			label.ZIndex = depth
		end
	end
end
-- END fitRewardTexts
fitRewardTexts(items)

-- Rewards: Unlock = the Member title; the two "Item1" frames, top to bottom, = potion, spins.
local function paintRewards(rewards)
	if not items then
		return
	end
	local unlock = items:FindFirstChild("Unlock")
	local unlockTitle = unlock and unlock:FindFirstChild("Title")
	if unlockTitle and unlockTitle:IsA("TextLabel") then
		unlockTitle.Text = L.Member
	end
	local cards = {}
	for _, child in items:GetChildren() do
		if child.Name == "Item1" and child:IsA("GuiObject") then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	local texts = {
		string.format(L.Potion, tonumber(rewards and rewards.SpeedPotionMinutes) or 30),
		string.format(L.Spins, tonumber(rewards and rewards.SpinTickets) or 3),
	}
	for index, card in cards do
		local label = card:FindFirstChild("Title")
		if label and label:IsA("TextLabel") and texts[index] then
			label.Text = texts[index]
		end
	end
end
paintRewards(nil)

-- 2026-09-26: the answers, in a pill just above Redeem (over the free slot under step 3 in the
-- group form, over the code box for a moment in the Discord form). Tap it to hide it.
local STATUS_SECONDS = 6
local status = Instance.new("TextButton")
status.Name = "CommunityStatus"
status.AutoButtonColor = false
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.fromScale(0.727, 0.81)
status.Size = UDim2.fromScale(0.5, 0.16)
status.BackgroundColor3 = Color3.fromRGB(50, 78, 111)
status.BackgroundTransparency = 0.12
status.Font = Enum.Font.FredokaOne
status.TextScaled = true
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.TextStrokeTransparency = 0.35
status.Text = ""
status.ZIndex = 40
status.Visible = false
status.Selectable = false
status.Parent = window
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = status
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = status
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 26
	cap.MinTextSize = 9
	cap.Parent = status
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.fromRGB(20, 32, 48)
	edge.Thickness = 2
	edge.Parent = status
end

-- The group form's step 1 is a button (created once, shown only in that form).
local joinButton = nil
local step1 = steps and steps:FindFirstChild("1")
if step1 and step1:IsA("GuiObject") then
	joinButton = Instance.new("TextButton")
	joinButton.Name = "JoinGroup"
	joinButton.BackgroundTransparency = 1
	joinButton.Text = ""
	joinButton.Size = UDim2.fromScale(1, 1)
	joinButton.ZIndex = 30
	joinButton.Selectable = true
	joinButton.Visible = false
	joinButton.Parent = step1
end

local state = {
	DiscordAllowed = player:GetAttribute("CommunityDiscordAllowed") == true,
	Claimed = player:GetAttribute("CommunityRewardClaimed") == true,
	-- 2026-09-26: the group is known before the server's first answer (the join button was
	-- hidden until then, so a quick tap on "Tap here to join" did nothing).
	GroupId = tonumber(U4.Community and U4.Community.GroupId) or 0,
	Enabled = true,
	Rewards = nil,
}
local isOpen = false
local sentAt = -math.huge

local function setLines(index, lines)
	local labels = stepLabels[index]
	for position, label in labels do
		local text = lines[position]
		label.Visible = text ~= nil
		if text then
			label.Text = text
		end
	end
end

local function paint()
	local discord = state.DiscordAllowed == true
	local list = if discord then L.DiscordSteps else L.GroupSteps
	for index = 1, 3 do
		setLines(index, list[index])
	end
	if codeFrame and codeFrame:IsA("GuiObject") then
		codeFrame.Visible = discord and not state.Claimed
	end
	if joinButton then
		joinButton.Visible = not discord and not state.Claimed and (tonumber(state.GroupId) or 0) > 0
	end
	if redeemLabel and redeemLabel:IsA("TextLabel") then
		redeemLabel.Text = if state.Claimed then L.Claimed elseif state.Enabled == false then L.Unavailable else L.Redeem
	end
	if redeemButton and redeemButton:IsA("GuiButton") then
		redeemButton.Active = not state.Claimed and state.Enabled ~= false
		redeemButton.AutoButtonColor = redeemButton.Active
	end
end
paint()

local statusSerial = 0
local function say(text, good)
	statusSerial += 1
	local serial = statusSerial
	text = tostring(text or "")
	status.Text = text
	status.TextColor3 = if good then Color3.fromRGB(150, 255, 150) else Color3.fromRGB(255, 255, 255)
	status.Visible = text ~= ""
	if text ~= "" then
		task.delay(STATUS_SECONDS, function()
			if statusSerial == serial then
				status.Visible = false
			end
		end)
	end
end
status.Activated:Connect(function()
	say("", false)
end)

-- The server's answer in the player's language: its Reason, else its (English) Message.
local function answerText(payload)
	local reason = payload.Reason
	local text = type(reason) == "string" and L.Reasons[reason]
	if text and reason == "Success" then
		local rewards = type(payload.Rewards) == "table" and payload.Rewards or {}
		return string.format(text, tonumber(rewards.SpeedPotionMinutes) or 30, tonumber(rewards.SpinTickets) or 3)
	end
	if text then
		return text
	end
	return if type(payload.Message) == "string" then payload.Message else ""
end

-- The server takes one request a second per player (RemoteGuard). A second tap inside that
-- second used to vanish; now the latest one goes when the second is up.
local queued = nil
local queuedTimer = false
local function fire(...)
	if not Request then
		return false
	end
	local waitFor = 1.05 - (os.clock() - sentAt)
	if waitFor > 0 then
		queued = table.pack(...)
		if not queuedTimer then
			queuedTimer = true
			task.delay(waitFor, function()
				queuedTimer = false
				local args = queued
				queued = nil
				if args then
					sentAt = os.clock()
					Request:FireServer(table.unpack(args, 1, args.n))
				end
			end)
		end
		return true
	end
	sentAt = os.clock()
	Request:FireServer(...)
	return true
end

local function redeem()
	if state.Claimed or state.Enabled == false then
		return
	end
	if state.DiscordAllowed then
		local code = if codeBox then (string.match(codeBox.Text, "^%s*(.-)%s*$") or "") else ""
		if code == "" then
			say(L.EnterCode, false)
			return
		end
		if fire("Redeem", string.sub(code, 1, 64)) then
			say(L.CheckingCode, false)
		end
	else
		if fire("VerifyGroup") then
			say(L.CheckingGroup, false)
		end
	end
end

local joining = false
local function joinGroup()
	local groupId = tonumber(state.GroupId) or 0
	if joining or groupId <= 0 or state.DiscordAllowed or state.Claimed then
		return
	end
	joining = true
	task.spawn(function()
		local ok, result = pcall(function()
			return GroupService:PromptJoinAsync(groupId)
		end)
		joining = false
		if not ok then
			say(L.JoinFailed, false)
		elseif result == Enum.GroupMembershipStatus.Joined or result == Enum.GroupMembershipStatus.AlreadyMember then
			-- "Joined": the server checks again for a few seconds (a fresh membership can take
			-- a moment to show); the payment still waits for the server's own check.
			say(L.Joined, true)
			fire("VerifyGroup", if result == Enum.GroupMembershipStatus.Joined then "Joined" else nil)
		elseif result == Enum.GroupMembershipStatus.JoinRequestPending then
			say(L.JoinPending, false)
		end
	end)
end

local OPEN_POS = window.Position
-- 2026-09-26 (owner): "HUGE": PhoneBlock, window and header 80% of the room (was 98%), raised.
MenuPanelLayout.BindPhoneFit(gui, window, OPEN_POS, OPEN_POS, function(fit)
	OPEN_POS = fit.Open
	if isOpen then
		window.Position = OPEN_POS
	end
end, nil, MenuPanelLayout.PhoneBlock)
ModalJuice.WatchGui(gui)

local function open()
	if isOpen then
		return
	end
	isOpen = true
	window.Position = OPEN_POS
	window.Visible = true
	gui.Enabled = true
	say("", false)
	paint()
	if Request then
		fire("Get")
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	say("", false)
	if codeBox and codeBox:IsFocused() then
		codeBox:ReleaseFocus()
	end
end

if redeemButton and redeemButton:IsA("GuiButton") then
	redeemButton.Activated:Connect(redeem)
end
if codeBox then
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	codeBox.Focused:Connect(function()
		say("", false)
	end)
end
if joinButton then
	joinButton.Activated:Connect(joinGroup)
end
if closeButton and closeButton:IsA("GuiButton") then
	closeButton.Activated:Connect(function()
		if isOpen then
			MenuEvents.Request("Community")
		end
	end)
end
ConsolePanelSupport.Bind(gui, window, if redeemButton and redeemButton:IsA("GuiButton") then redeemButton else nil,
	if closeButton and closeButton:IsA("GuiButton") then closeButton else nil, function()
		if isOpen then
			MenuEvents.Request("Community")
		end
	end)

if Update then
	Update.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		state.DiscordAllowed = payload.DiscordAllowed == true
		state.Claimed = payload.Claimed == true
		state.GroupId = tonumber(payload.GroupId) or state.GroupId
		state.Enabled = payload.Enabled ~= false
		if type(payload.Rewards) == "table" then
			state.Rewards = payload.Rewards
			paintRewards(payload.Rewards)
		end
		paint()
		if isOpen and (payload.Reason ~= nil or (type(payload.Message) == "string" and payload.Message ~= "")) then
			say(answerText(payload), payload.Success == true)
		end
		if payload.Success == true and codeBox then
			codeBox.Text = ""
		end
	end)
end
for _, attribute in { "CommunityDiscordAllowed", "CommunityRewardClaimed" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		state.DiscordAllowed = player:GetAttribute("CommunityDiscordAllowed") == true
		state.Claimed = player:GetAttribute("CommunityRewardClaimed") == true
		paint()
	end)
end

MenuEvents.Get("OpenCommunityPanel").Event:Connect(function(action)
	if action == "Close" then
		close()
	elseif action == "Open" then
		open()
	elseif isOpen then
		close()
	else
		open()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "Community" then
		close()
	end
end)
MenuEvents.MarkReady("Community", function()
	return isOpen
end)
