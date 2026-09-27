-- StarterPlayer/StarterPlayerScripts/Gameplay/FlashGateClient.client.luau — 2026-09-26 (owner):
-- The Flash's race gate comes alive on each client (Shared/FlashGate has the numbers, the words and
-- the board's UI; Services/Race/RaceArenaBuilder built the parts):
--   * the sign-up ring pad: two rings of Neon dashes turning opposite ways over its dark bands,
--     pulsing (turning faster while a race gathers), and a cyan scan ring rising off it;
--   * the medallion's glow ring breathing;
--   * The Flash's electricity: short jagged Beams (three segments each) flickering around his
--     body a few times a second, a burst when the player talks to him and when he pumps his fist
--     (LobbyNpcPose.FlashFist). No sparkles and no particle emitters (owner: "NO sparkles");
--   * the holo board past him (dark glass, a cyan Neon frame, a SurfaceGui): collapsed to its
--     header (MULTIPLAYER RACE / STATUS / a hint) until the player talks to Flash (his prompt, or
--     WEEKLY RECORDS in his window), then it opens downward: the weekly top 5 (RaceRequest
--     "Board", the answer the Race panel gets too), the player's best and the phase bar. It
--     closes when the player walks away or races;
--   * RaceGateSign (the billboard for players far away) hides near the gate, where the board
--     says the same.
-- Budget: everything moves only within AnimateRadius of the camera and the board's parts exist
-- only within BoardRadius; tiers from Shared/RaceFeelTier (Low: phones under 30 FPS keep the
-- board and one crackle, no dashes or scan ring). A gate without the builder's markers (an
-- owner-made one) still gets the board and the crackles, placed from Update4Config and
-- LobbyNpcConfig. The client's parts live in Workspace.FlashGateLocal (never replicated).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local Config = require(Shared:WaitForChild("Config"))
local FlashGate = require(Shared:WaitForChild("FlashGate"))
local LobbyNpcConfig = require(Shared:WaitForChild("LobbyNpcConfig"))
local LobbyNpcPose = require(Shared:WaitForChild("LobbyNpcPose"))
local RaceFeelTier = require(Shared:WaitForChild("RaceFeelTier"))
local RaceText = require(Shared:WaitForChild("RaceText"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local CLIENT = FlashGate.Client
local BOARD = FlashGate.Board
local PAD = FlashGate.Pad
local NAMES = FlashGate.Names
local CRACKLE = CLIENT.Crackle
local WORLD = LobbyNpcConfig.WorldKey(Config)
local BESIDE = LobbyNpcConfig.FlashBesideGate[WORLD]
local lang = RaceText.ForPlayer(player)
local rng = Random.new()
local ENV = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, UDim = UDim, UDim2 = UDim2, Vector2 = Vector2,
	Enum = Enum, Font = Font, ColorSequence = ColorSequence, NumberSequence = NumberSequence,
}

local function color(name: string): Color3
	return FlashGate.Rgb(ENV, name)
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function characterRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

----------------------------------------------------------------------
-- Remotes (the race server's; the board rows come back as RaceEvent { kind = "Board" })
----------------------------------------------------------------------
local RaceRequest: RemoteEvent? = nil
local boardData: any = nil
local boardAskedAt = -math.huge
local boardAnsweredAt = -math.huge
local renderRows: () -> () = function() end

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 60)
	local request = remotes and remotes:WaitForChild("RaceRequest", 60)
	local event = remotes and remotes:WaitForChild("RaceEvent", 60)
	if request and request:IsA("RemoteEvent") then
		RaceRequest = request
	end
	if event and event:IsA("RemoteEvent") then
		event.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and payload.kind == "Board" and type(payload.weekly) == "table" then
				boardData = payload
				boardAnsweredAt = os.clock()
				renderRows()
			end
		end)
	end
end)

-- The server answers one "Board" every BoardRequestSeconds per player; the Race panel may have
-- asked a moment ago (its answer reaches this listener too).
local function askBoard()
	local remote = RaceRequest
	if not remote or os.clock() - boardAskedAt < U4.Race.Leaderboard.BoardRequestSeconds then
		return
	end
	boardAskedAt = os.clock()
	remote:FireServer("Board")
end

----------------------------------------------------------------------
-- Tier (Shared/RaceFeelTier: High / Mid / Low)
----------------------------------------------------------------------
local meter = RaceFeelTier.NewMeter()
local tier = RaceFeelTier.Detect(nil)
local tierClock = 0
local function budget(): any
	return CLIENT.Tiers[tier] or CLIENT.Tiers.Low
end

----------------------------------------------------------------------
-- The gate (streamed in and out as a whole: Atomic)
----------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = NAMES.LocalFolder

type GateState = {
	model: Model?,
	frame: CFrame, -- the gate frame (floor point, -Z toward the players)
	boardFrame: CFrame, -- the open board's centre
	glow: BasePart?,
	sign: BillboardGui?,
}
local configFrame = FlashGate.GateFrame(U4.Race.Gate[WORLD], CFrame)
local gate: GateState? = if configFrame
	then { model = nil, frame = configFrame, boardFrame = configFrame * FlashGate.BoardLocal(BESIDE, CFrame), glow = nil, sign = nil }
	else nil

-- The gate's frames from its markers when it has them (the owner may move them), else from the
-- config (an owner-made gate, or one not streamed in yet).
local function refreshGate()
	if not configFrame then
		return
	end
	local model = Workspace:FindFirstChild(NAMES.Gate)
	local state = gate :: GateState
	if model == state.model and (model == nil or model.Parent == Workspace) then
		return
	end
	state.model = if model and model:IsA("Model") then model else nil
	state.frame, state.glow, state.sign = configFrame, nil, nil
	state.boardFrame = configFrame * FlashGate.BoardLocal(BESIDE, CFrame)
	if state.model then
		local pad = state.model:FindFirstChild(NAMES.Pad)
		if pad and pad:IsA("BasePart") then
			state.frame = pad.CFrame * CFrame.new(0, -pad.Size.Y / 2, 0)
		end
		local anchor = state.model:FindFirstChild(NAMES.Anchor)
		state.boardFrame = if anchor and anchor:IsA("BasePart") then anchor.CFrame else state.frame * FlashGate.BoardLocal(BESIDE, CFrame)
		local glow = state.model:FindFirstChild(NAMES.MedallionGlow, true)
		state.glow = if glow and glow:IsA("BasePart") then glow else nil
		local sign = state.model:FindFirstChild(NAMES.Sign)
		state.sign = if sign and sign:IsA("BillboardGui") then sign else nil
	end
end

----------------------------------------------------------------------
-- The ring pad: dashes and the scan ring
----------------------------------------------------------------------
local function localPart(name: string, size: Vector3, colorName: string, material: Enum.Material, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.Color = color(colorName)
	part.Material = material
	part.Transparency = transparency
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

type Ring = { parts: { BasePart }, radius: number, speed: number, angle: number, frames: { CFrame } }
local rings: { Ring }? = nil
local function ensureRings(): { Ring }
	if rings then
		return rings
	end
	local list = {}
	for index, spec in PAD.Dashes do
		local ring = { parts = {}, radius = spec[2], speed = math.rad(spec[5]), angle = index * 0.5, frames = {} }
		for dash = 1, spec[3] do
			table.insert(ring.parts, localPart("Dash" .. index .. "_" .. dash, Vector3.new(PAD.DashWidth, PAD.DashThickness, spec[4]),
				spec[1], Enum.Material.Neon, 0.15))
		end
		table.insert(list, ring)
	end
	rings = list
	return list
end

local function dropRings()
	if rings then
		for _, ring in rings do
			for _, part in ring.parts do
				part:Destroy()
			end
		end
		rings = nil
	end
end

local scan: { part: BasePart, stroke: UIStroke, scale: UIScale }? = nil
local function ensureScan(): any
	if scan then
		return scan
	end
	local size = PAD.Radius * 2
	local part = localPart("ScanRing", Vector3.new(size, 0.05, size), "Cyan", Enum.Material.SmoothPlastic, 1)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Scan"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	pcall(function()
		gui.Brightness = 2
	end)
	gui.Parent = part
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(0.96, 0.96)
	circle.BackgroundTransparency = 1
	circle.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Color = color("Cyan")
	stroke.Thickness = 5
	stroke.Parent = circle
	local scale = Instance.new("UIScale")
	scale.Parent = circle
	scan = { part = part, stroke = stroke, scale = scale }
	return scan
end

local function dropScan()
	if scan then
		scan.part:Destroy()
		scan = nil
	end
end

local function gathering(): boolean
	return Workspace:GetAttribute("RacePhase") == "Gathering"
end

local dashClock = 0
local function animatePad(dt: number, t: number)
	local state = gate :: GateState
	local plan = budget()
	if not plan.Dashes then
		dropRings()
	else
		dashClock += dt
		if dashClock >= 1 / plan.DashHz then
			local step = dashClock
			dashClock = 0
			local spin = if gathering() then CLIENT.GatherSpin else 1
			local pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2 * (if gathering() then 2.4 else 1.2))
			for index, ring in ensureRings() do
				ring.angle += ring.speed * spin * step
				for k, cf in FlashGate.DashFrames(ring.radius, #ring.parts, ring.angle, PAD.DashHeight, CFrame) do
					ring.frames[k] = state.frame * cf
				end
				Workspace:BulkMoveTo(ring.parts, ring.frames, Enum.BulkMoveMode.FireCFrameChanged)
				local transparency = 0.08 + 0.35 * (if index == 1 then pulse else 1 - pulse)
				for _, part in ring.parts do
					part.Transparency = transparency
				end
			end
		end
	end
	if not plan.Scan then
		dropScan()
	else
		local ring = ensureScan()
		local phase = (t % CLIENT.ScanSeconds) / CLIENT.ScanSeconds
		local eased = 1 - (1 - phase) * (1 - phase)
		ring.part.CFrame = state.frame * CFrame.new(0, 0.3 + CLIENT.ScanRise * eased, 0)
		ring.stroke.Transparency = 0.15 + 0.85 * phase
		ring.scale.Scale = 1 - 0.18 * eased
	end
	local glow = state.glow
	if glow and glow.Parent then
		glow.Transparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * CLIENT.GlowHz))
	end
end

----------------------------------------------------------------------
-- The Flash's crackles (segmented Beams on attachments of one local host part)
----------------------------------------------------------------------
local flashModel: Model? = nil
local bodyParts: { BasePart } = {}
local burstUntil = 0

local function findFlash()
	if flashModel and flashModel:IsDescendantOf(Workspace) and flashModel:GetAttribute(LobbyNpcConfig.KindAttribute) == "Flash" then
		return
	end
	flashModel, bodyParts = nil, {}
	for _, model in CollectionService:GetTagged(LobbyNpcConfig.Tags.Flash) do
		if model:IsA("Model") and model:IsDescendantOf(Workspace) and model:GetAttribute(LobbyNpcConfig.KindAttribute) == "Flash" then
			flashModel = model
			break
		end
	end
	if not flashModel then
		return
	end
	-- His body: the visible limbs, torso and head (not the root, a base disc or accessories).
	for _, child in flashModel:GetChildren() do
		if child:IsA("BasePart") and child.Transparency < 0.5 and child.Name ~= "HumanoidRootPart" then
			local size = child.Size
			if size.Magnitude >= 0.8 and size.Magnitude <= 4.5 and size.Y >= 0.8 then
				table.insert(bodyParts, child)
			end
		end
	end
end

type Arc = { attachments: { Attachment }, beams: { Beam }, shown: boolean, nextAt: number, serial: number }
local host: BasePart? = nil
local arcs: { Arc } = {}
local arcSerial = 0

local function ensureArcs(count: number)
	if not host then
		host = localPart("CrackleHost", Vector3.new(0.2, 0.2, 0.2), "Crackle", Enum.Material.SmoothPlastic, 1)
	end
	while #arcs < count do
		arcSerial += 1
		local arc: Arc = { attachments = {}, beams = {}, shown = false, nextAt = 0, serial = arcSerial }
		for index = 1, CRACKLE.Segments + 1 do
			local attachment = Instance.new("Attachment")
			attachment.Name = "Crackle" .. arcSerial .. "_" .. index
			attachment.Parent = host
			arc.attachments[index] = attachment
		end
		local cyan = arcSerial % CRACKLE.CyanEvery == 0
		for index = 1, CRACKLE.Segments do
			local beam = Instance.new("Beam")
			beam.Name = "Crackle" .. arcSerial .. "_" .. index
			beam.Attachment0 = arc.attachments[index]
			beam.Attachment1 = arc.attachments[index + 1]
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Texture = ""
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Color = ColorSequence.new(color("CrackleCore"), color(if cyan then "CrackleCyan" else "Crackle"))
			beam.Transparency = NumberSequence.new(0)
			-- Thick at the root of the crackle, thin at its tip.
			local a = (index - 1) / CRACKLE.Segments
			local b = index / CRACKLE.Segments
			beam.Width0 = CRACKLE.Width[1] + (CRACKLE.Width[2] - CRACKLE.Width[1]) * a
			beam.Width1 = CRACKLE.Width[1] + (CRACKLE.Width[2] - CRACKLE.Width[1]) * b
			pcall(function()
				(beam :: any).Brightness = 2
			end)
			beam.Enabled = false
			beam.Parent = host
			arc.beams[index] = beam
		end
		table.insert(arcs, arc)
	end
end

local function hideArc(arc: Arc)
	arc.shown = false
	for _, beam in arc.beams do
		beam.Enabled = false
	end
end

local function dropArcs()
	for _, arc in arcs do
		hideArc(arc)
	end
end

-- A fresh crackle on a random body part: from a point just off its surface, outward and along.
local function strike(arc: Arc): boolean
	local part = bodyParts[rng:NextInteger(1, #bodyParts)]
	if not part or not part.Parent or not host then
		return false
	end
	local cf, size = part.CFrame, part.Size
	-- A random point on the part's surface (pushed out along its largest share of the box).
	local u = Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5))
	local reach = math.max(math.abs(u.X), math.abs(u.Y), math.abs(u.Z), 1e-3)
	u *= 0.5 / reach
	local start = cf * Vector3.new(u.X * size.X, u.Y * size.Y, u.Z * size.Z)
	local outward = start - cf.Position
	outward = if outward.Magnitude > 0.05 then outward.Unit else cf.RightVector
	start += outward * CRACKLE.Offset
	local wander = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local direction = outward + wander * 0.8
	direction = if direction.Magnitude > 0.05 then direction.Unit else outward
	local points = FlashGate.CracklePoints(rng, start, direction, rng:NextNumber(CRACKLE.MinLength, CRACKLE.MaxLength),
		CRACKLE.Jitter, CRACKLE.Segments, Vector3)
	local origin = (host :: BasePart).CFrame
	for index, point in points do
		arc.attachments[index].CFrame = CFrame.new(origin:PointToObjectSpace(point))
	end
	for _, beam in arc.beams do
		beam.Enabled = true
	end
	arc.shown = true
	return true
end

local function fistNow(t: number): boolean
	local window = LobbyNpcPose.FlashFist
	local def = LobbyNpcPose.Defs.Flash
	if type(window) ~= "table" or not def then
		return false
	end
	local loopT = t % def.Loop
	return loopT >= window[1] and loopT <= window[2]
end

local function animateCrackles(t: number)
	if not flashModel or #bodyParts == 0 then
		dropArcs()
		return
	end
	local now = os.clock()
	local bursting = now < burstUntil or fistNow(t)
	local count = budget().Arcs + (if bursting then 1 else 0)
	ensureArcs(count)
	if host then
		host.CFrame = CFrame.new((bodyParts[1] :: BasePart).Position)
	end
	for index, arc in arcs do
		if index > count then
			if arc.shown then
				hideArc(arc)
			end
		elseif now >= arc.nextAt then
			if arc.shown then
				hideArc(arc)
				local gap = rng:NextNumber(CRACKLE.Gap[1], CRACKLE.Gap[2])
				arc.nextAt = now + (if bursting then gap / CRACKLE.BurstGapDivisor else gap)
			elseif strike(arc) then
				arc.nextAt = now + rng:NextNumber(CRACKLE.Life[1], CRACKLE.Life[2])
			else
				arc.nextAt = now + 0.5
			end
		end
	end
end

----------------------------------------------------------------------
-- The holo board
----------------------------------------------------------------------
type Board = { model: Model, glass: BasePart, edges: { [string]: BasePart }, screen: SurfaceGui }
local board: Board? = nil
local boardOpen = false -- asked for (the player talked to Flash)
local shown = BOARD.Header -- studs of its height showing now
local phaseSeen: { phase: any, at: number } = { phase = nil, at = serverNow() }

local function style(label: TextLabel)
	RaceText.Style(label, lang)
end

local function ensureBoard(): Board
	if board then
		return board
	end
	local model = FlashGate.BuildBoard(ENV)
	for _, d in model:GetDescendants() do
		if d:IsA("TextLabel") then
			style(d)
		end
	end
	local screen = (model :: any).Glass:FindFirstChild(NAMES.Screen) :: SurfaceGui
	screen.Title.Text = FlashGate.Get("Title", lang)
	local edges = {}
	for _, name in { "EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight" } do
		edges[name] = (model :: any)[name]
	end
	model.Parent = folder
	board = { model = model, glass = (model :: any).Glass, edges = edges, screen = screen }
	renderRows()
	return board :: Board
end

local function dropBoard()
	if board then
		board.model:Destroy()
		board = nil
	end
end

local function placeBoard()
	local state = gate :: GateState
	local b = board
	if not b then
		return
	end
	local pieces = FlashGate.BoardPieces(shown, Vector3, CFrame)
	local parts, frames = {}, {}
	for name, piece in pieces do
		local part = if name == "Glass" then b.glass else b.edges[name]
		if part.Size ~= piece[2] then
			part.Size = piece[2]
		end
		table.insert(parts, part)
		table.insert(frames, state.boardFrame * piece[1])
	end
	Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local MEDAL_COLORS = { "Amber", "Silver", "Bronze" }
renderRows = function()
	local b = board
	if not b then
		return
	end
	local list = (b.screen :: any).List
	local rows = FlashGate.Rows(boardData and boardData.weekly, BOARD.Rows)
	for index = 1, BOARD.Rows do
		local row = list:FindFirstChild("Row" .. index)
		local entry = rows[index]
		if row then
			row.Visible = entry ~= nil
			if entry then
				row.Rank.Text = entry.Rank .. "."
				row.PlayerName.Text = entry.Name
				row.Time.Text = entry.Time
				local tint = color(MEDAL_COLORS[index] or "Text")
				row.Rank.TextColor3, row.PlayerName.TextColor3 = tint, if index <= 3 then tint else color("Text")
				row.Mine.Visible = entry.UserId == player.UserId
			end
		end
	end
	list.Empty.Visible = #rows == 0
	list.Empty.Text = FlashGate.Get(if boardData then "Empty" else "Loading", lang)
end

local function footerLine(): string
	if player:GetAttribute("RaceState") == "Queued" then
		return FlashGate.Get("InQueue", lang)
	end
	local you = boardData and type(boardData.you) == "table" and boardData.you or {}
	local best = tonumber(you.weekBestMs) or tonumber(player:GetAttribute("RaceWeekBestMs")) or 0
	if best <= 0 then
		return FlashGate.Get("NoTime", lang)
	end
	local rank = tonumber(you.weeklyRank)
	if rank then
		return FlashGate.Format("YourBest", lang, FlashGate.FormatTime(best), rank)
	end
	return FlashGate.Format("YourBestNoRank", lang, FlashGate.FormatTime(best))
end

-- 2026-09-26 (owner): a live event (Super Sonic vs Eggman) closes the races meanwhile (the Workspace attribute
-- RaceClosedBy, Shared/SuperSonicEvent RaceClosed.Attribute): the board reads CLOSED and says why.
local RACE_CLOSED_ATTRIBUTE = "RaceClosedBy"

local function refreshBoardText()
	local b = board
	if not b then
		return
	end
	local screen = b.screen :: any
	local now = serverNow()
	local phase = Workspace:GetAttribute("RacePhase")
	if phase ~= phaseSeen.phase then
		phaseSeen.phase, phaseSeen.at = phase, now
	end
	local endsAt = Workspace:GetAttribute("RacePhaseEndsAt")
	local mega = (tonumber(Workspace:GetAttribute("RaceEventUntil")) or 0) > os.time()
	local closedByEvent = Workspace:GetAttribute(RACE_CLOSED_ATTRIBUTE) ~= nil
	local line, colorName = FlashGate.StatusLine(phase, endsAt, now, U4.IsOn("Race") and not closedByEvent, mega, lang)
	if screen.Status.Text ~= line then
		screen.Status.Text = line
		screen.Status.TextColor3 = color(colorName)
	end
	local caption = if boardOpen then FlashGate.Format("Weekly", lang, BOARD.Rows) else FlashGate.Get("Hint", lang)
	if screen.Caption.Text ~= caption then
		screen.Caption.Text = caption
		screen.Caption.TextColor3 = color(if boardOpen then "Cyan" else "Muted")
	end
	local footer = if closedByEvent then RaceText.Get("RaceEventClosed", lang) else footerLine()
	if screen.Footer.Text ~= footer then
		screen.Footer.Text = footer
	end
	-- The bar: how much of the current phase has gone by (hidden when the phase has no timer).
	local progress = FlashGate.PhaseProgress(phaseSeen.at, endsAt, now)
	screen.Bar.Visible = progress ~= nil and U4.IsOn("Race") and not closedByEvent
	if progress then
		screen.Bar.Fill.Size = UDim2.fromScale(math.max(0.02, progress), 1)
	end
	screen.Divider.Visible = shown > BOARD.Header + 0.2
end

local function openBoard()
	if not boardOpen then
		boardOpen = true
		refreshBoardText()
	end
	if not boardData or os.clock() - boardAnsweredAt > CLIENT.BoardAskSeconds then
		askBoard()
	end
end

local function closeBoard()
	if boardOpen then
		boardOpen = false
		refreshBoardText()
	end
end

-- Eased toward open (Height) or collapsed (Header).
local function animateBoard(dt: number)
	local target = if boardOpen then BOARD.Height else BOARD.Header
	if math.abs(shown - target) < 1e-3 then
		return false
	end
	local span = BOARD.Height - BOARD.Header
	local seconds = if boardOpen then CLIENT.OpenSeconds else CLIENT.CloseSeconds
	local step = span * dt / seconds
	shown = if shown < target then math.min(target, shown + step) else math.max(target, shown - step)
	return true
end

----------------------------------------------------------------------
-- Talking to Flash opens the board; WEEKLY RECORDS in his window too
----------------------------------------------------------------------
local function isFlashPrompt(prompt: ProximityPrompt): boolean
	local cursor: Instance? = prompt.Parent
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") and cursor:GetAttribute(LobbyNpcConfig.KindAttribute) ~= nil then
			return cursor:GetAttribute(LobbyNpcConfig.KindAttribute) == "Flash"
		end
		cursor = cursor.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and isFlashPrompt(prompt) then
		openBoard()
		burstUntil = os.clock() + CLIENT.BurstSeconds
	end
end)

MenuEvents.Listen("Race", function(action, detail)
	if action == "Weekly" or detail == "Weekly" then
		openBoard()
	end
end)

player:GetAttributeChangedSignal("RaceState"):Connect(function()
	local state = player:GetAttribute("RaceState")
	if state == "Staged" or state == "Racing" then
		closeBoard()
	end
end)

----------------------------------------------------------------------
-- The loops: a slow one (streaming, distances, words) and the per-frame motion near the gate
----------------------------------------------------------------------
local near = false -- within AnimateRadius of the camera
local present = false -- within BoardRadius

local function cameraDistance(): number
	local camera = Workspace.CurrentCamera
	if not camera or not gate then
		return math.huge
	end
	return (camera.CFrame.Position - (gate :: GateState).frame.Position).Magnitude
end

local function slowTick()
	if not gate then
		return
	end
	refreshGate()
	local state = gate :: GateState
	local distance = cameraDistance()
	present = distance <= CLIENT.BoardRadius
	near = distance <= CLIENT.AnimateRadius
	if present then
		if folder.Parent ~= Workspace then
			folder.Parent = Workspace
		end
		ensureBoard()
		placeBoard()
		refreshBoardText()
		findFlash()
	else
		closeBoard()
		shown = BOARD.Header
		dropBoard()
		dropRings()
		dropScan()
		dropArcs()
		folder.Parent = nil
	end
	if not near then
		dropArcs()
	end
	if state.sign and state.sign.Parent then
		local show = distance > CLIENT.SignHideRadius
		if state.sign.Enabled ~= show then
			state.sign.Enabled = show
		end
	end
	-- Walked away from the open board, or it went (streamed out, killed): it closes.
	if boardOpen then
		local root = characterRoot()
		if not root or (root.Position - state.boardFrame.Position).Magnitude > CLIENT.CollapseDistance then
			closeBoard()
		elseif os.clock() - boardAnsweredAt > CLIENT.BoardAskSeconds
			or (os.clock() - boardAskedAt > CLIENT.BoardRetrySeconds and boardAnsweredAt < boardAskedAt) then
			askBoard()
		end
	end
end

task.spawn(function()
	while true do
		local ok, problem = pcall(slowTick)
		if not ok then
			warn("[FlashGateClient] " .. tostring(problem))
		end
		task.wait(CLIENT.LoopSeconds)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	RaceFeelTier.Sample(meter, dt)
	tierClock += dt
	if tierClock >= CLIENT.TierSeconds then
		tierClock = 0
		tier = RaceFeelTier.Detect(meter)
	end
	if not present or not gate then
		return
	end
	if animateBoard(dt) then
		placeBoard()
		local b = board
		if b then
			(b.screen :: any).Divider.Visible = shown > BOARD.Header + 0.2
		end
	end
	if not near then
		return
	end
	local t = serverNow()
	animatePad(dt, t)
	animateCrackles(t)
end)
