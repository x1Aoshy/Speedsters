--!strict
-- ReplicatedStorage/Shared/FlashGate.luau — 2026-09-26 (owner): The Flash's race gate and the holo
-- board beside him, after the owner's reference: a big red arch with a gold band inlaid on its
-- faces and a round gold medallion with the lightning bolt at the top, a glowing sign-up ring pad
-- under it (concentric cyan / gold rings), The Flash (the animated R6) beside it with small
-- electric crackles, and a holographic cyan-framed "MULTIPLAYER RACE" panel floating past him.
-- Shared by
--   Services/Race/RaceArenaBuilder  the parts (BuildGate: arch, medallion, ring pad, markers)
--   Gameplay/FlashGateClient        the motion (turning ring dashes, the scan ring, the medallion's
--                                   glow, Flash's crackles) and the holo board: collapsed to its
--                                   header until the player talks to Flash, open (weekly top 5)
--                                   until he walks away
--   audit/test_u4_flash_gate        everything below, in Lune
-- Owner rules: no sparkles, no default particles (the electricity is short segmented Beams), and
-- everything in the game's look (FredokaOne words, the race UI's colours).
-- Pure data and maths plus BuildBoard(env) (plain Instances from `env`): nothing here touches a
-- service when it is required. Gate frame: x across (the gate's right), y up from the floor, -z
-- toward the players (the gate's LookVector), as RaceArenaBuilder.GateCFrame.
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end

local FlashGate = {}

-- The builder stamps its gate (RaceGate attribute RaceGateVersion); audit/build_update4 rebuilds a
-- gate it made (U4Asset "RaceGate") whose version is older, never a gate without that stamp.
-- Version 1 = the 2026-09-25 part frame (pillars and a lintel), which carries no attribute.
FlashGate.Version = 2
FlashGate.VersionAttribute = "RaceGateVersion"

FlashGate.Names = {
	Gate = "RaceGate",
	Pad = "RaceGatePad", -- the sign-up trigger (PadTouchService), invisible
	Sign = "RaceGateSign", -- the BillboardGui seen from afar (Title / Status / Record)
	SignAnchor = "SignAnchor",
	FlashSpot = "FlashSpot",
	Anchor = "HoloBoardAnchor", -- invisible: the open board's centre and size
	Arch = "Arch",
	Medallion = "Medallion",
	MedallionGlow = "MedallionGlow",
	RingPad = "RingPad",
	LocalFolder = "FlashGateLocal", -- the client's own parts
	Board = "FlashHoloBoard",
	Screen = "Screen",
}

----------------------------------------------------------------------
-- The parts (studs, gate frame)
----------------------------------------------------------------------
-- A half circle of box segments centred Leg studs over the floor, on two short straight legs;
-- the gold band is thicker than the red body, so it shows on both faces, and stops BandGapDegrees
-- short of the top (the medallion sits there, with red around it as in the reference).
FlashGate.Arch = {
	Inner = 9.3, Outer = 12.5, Depth = 2.6, Leg = 1.0, Segments = 24,
	BandInner = 10.3, BandOuter = 11.5, BandDepth = 2.9, BandGapDegrees = 20,
	-- The medallion (discs facing the players and the back), centred on the band at the top.
	Rim = 2.7, RimDepth = 3.0, Face = 2.2, FaceDepth = 3.2, Glow = 3.0, GlowDepth = 2.0, BoltDepth = 3.4,
	SignHeight = 18.4, -- RaceGateSign hangs here, over the medallion
}
-- The lightning bolt on the medallion: strokes { from, to, width } in the viewer's frame (u = the
-- viewer's right as he faces the gate, v = up, from the medallion's centre): from the upper right
-- down to the lower left with the jog in the middle, as on The Flash's chest.
FlashGate.Bolt = {
	{ { 0.8, 1.7 }, { -0.35, 0.02 }, 0.62 },
	{ { -0.62, 0.06 }, { 0.62, 0.06 }, 0.5 },
	{ { 0.35, 0.1 }, { -0.8, -1.7 }, 0.62 },
}
-- The ring pad: a dark disc (Radius, Base thick) with Neon rings, each a glow disc under a dark
-- cover disc Step higher: { colour, outer radius, inner radius }. The client's dashes turn over
-- the dark bands between them: { colour, radius, count, length, degrees per second }.
FlashGate.Pad = {
	Radius = 6.6, Base = 0.12, Step = 0.02,
	Rings = { { "Cyan", 6.3, 5.9 }, { "Gold", 4.8, 4.3 }, { "Cyan", 2.9, 2.5 } },
	Dashes = { { "Gold", 5.35, 10, 1.55, 24 }, { "Cyan", 3.6, 8, 1.2, -34 } },
	DashHeight = 0.32, DashWidth = 0.22, DashThickness = 0.06,
}

-- { r, g, b }: the gate's red and gold are the race art's (RaceArenaBuilder.AssetRoles), the
-- board's cyan and gold the race UI's (RaceUiKit.Colors).
FlashGate.Colors = {
	Red = { 220, 34, 44 },
	Gold = { 255, 193, 37 },
	GoldGlow = { 255, 214, 70 },
	Cream = { 252, 244, 222 },
	Bolt = { 255, 205, 40 },
	Cyan = { 0, 225, 255 },
	PadDark = { 16, 26, 48 },
	Glass = { 6, 20, 42 },
	Text = { 235, 250, 255 },
	Green = { 90, 240, 120 },
	Amber = { 255, 211, 33 },
	Orange = { 255, 140, 60 },
	Muted = { 150, 185, 215 },
	Silver = { 205, 215, 230 },
	Bronze = { 230, 150, 80 },
	Ink = { 11, 27, 45 },
	Crackle = { 255, 226, 90 },
	CrackleCore = { 255, 252, 225 },
	CrackleCyan = { 140, 235, 255 },
}

-- 2026-09-26 (owner): the part look was rejected; the gate's art is Blender meshes now
-- (audit/flash_gate_bpy.py -> design/race/flashgate/FlashGateKit.fbx, imported once in Studio and
-- saved as FlashGateKit.rbxm, design/race/flashgate/IMPORTAR_ARCO.md). With that kit
-- RaceArenaBuilder.BuildGate places the meshes from FlashGate.Kit below (their Color / Material
-- from it, the import's turn undone: Shared/MeshKitImport) and stamps MeshVersion; without it
-- (or with a kit that does not fit) it builds the parts above and stamps Version.
FlashGate.MeshVersion = 3
FlashGate.KitAttribute = "RaceGateKit" -- true on a gate built from the meshes
FlashGate.KitName = "FlashGateKit" -- ServerStorage.FlashGateKit, when a server builds the gate at run time
FlashGate.KitStamp = "FlashGateKit" -- the RaceGate attribute RaceAsset names the kit, as the race art does
-- BEGIN GENERATED FlashGateKit (audit/flash_gate_bpy.py; do not edit by hand)
-- The Blender kit (design/race/flashgate/flashgate_manifest.json): per MeshPart its box (Size) and the
-- box centre's offset from the gate origin (Offset, gate frame, studs), its look and flags.
FlashGate.Kit = {
	Triangles = 23140,
	Pieces = {
		{ Name = "FG_ArchRed", Group = "Arch", Size = { 23.492, 9.319, 3 }, Offset = { 0, 8.84, 0 }, Color = { 210, 28, 46 }, Material = "SmoothPlastic", Reflectance = 0, CastShadow = true, CanCollide = false, Triangles = 5296 },
		{ Name = "FG_LegL", Group = "Arch", Size = { 3.761, 5.275, 2.6 }, Offset = { -10.62, 2.638, 0 }, Color = { 210, 28, 46 }, Material = "SmoothPlastic", Reflectance = 0, CastShadow = true, CanCollide = true, Triangles = 608 },
		{ Name = "FG_LegR", Group = "Arch", Size = { 3.761, 5.275, 2.6 }, Offset = { 10.62, 2.638, 0 }, Color = { 210, 28, 46 }, Material = "SmoothPlastic", Reflectance = 0, CastShadow = true, CanCollide = true, Triangles = 608 },
		{ Name = "FG_BandGold", Group = "Arch", Size = { 23, 11.957, 3.04 }, Offset = { 0, 5.978, 0 }, Color = { 234, 178, 52 }, Material = "SmoothPlastic", Reflectance = 0.2, CastShadow = true, CanCollide = false, Triangles = 3748 },
		{ Name = "FG_MedallionRim", Group = "Medallion", Size = { 3.9, 3.9, 3.3 }, Offset = { 0, 12.3, 0 }, Color = { 234, 178, 52 }, Material = "SmoothPlastic", Reflectance = 0.25, CastShadow = true, CanCollide = false, Triangles = 4032 },
		{ Name = "FG_MedallionFace", Group = "Medallion", Size = { 3.12, 3.12, 3.08 }, Offset = { 0, 12.3, 0 }, Color = { 255, 240, 200 }, Material = "SmoothPlastic", Reflectance = 0.05, CastShadow = true, CanCollide = false, Triangles = 1728 },
		{ Name = "FG_BoltEdge", Group = "Medallion", Size = { 2.2, 5.2, 3.44 }, Offset = { 0, 12.3, 0 }, Color = { 234, 178, 52 }, Material = "SmoothPlastic", Reflectance = 0.25, CastShadow = false, CanCollide = false, Triangles = 232 },
		{ Name = "FG_Bolt", Group = "Medallion", Size = { 1.857, 4.203, 3.6 }, Offset = { 0, 12.3, 0 }, Color = { 255, 205, 40 }, Material = "Neon", Reflectance = 0, CastShadow = false, CanCollide = false, Triangles = 232 },
		{ Name = "FG_PadDisc", Group = "RingPad", Size = { 13.2, 0.22, 13.2 }, Offset = { 0, 0.11, 0 }, Color = { 16, 26, 48 }, Material = "SmoothPlastic", Reflectance = 0.1, CastShadow = false, CanCollide = false, Triangles = 1536 },
		{ Name = "FG_PadRingCyan", Group = "RingPad", Size = { 12.6, 0.285, 12.6 }, Offset = { 0, 0.28, 0 }, Color = { 0, 225, 255 }, Material = "Neon", Reflectance = 0, CastShadow = false, CanCollide = false, Triangles = 3200 },
		{ Name = "FG_PadRingGold", Group = "RingPad", Size = { 9.6, 0.323, 9.6 }, Offset = { 0, 0.29, 0 }, Color = { 255, 193, 37 }, Material = "Neon", Reflectance = 0, CastShadow = false, CanCollide = false, Triangles = 1920 },
	},
	-- MedallionGlow (a Neon cylinder Part the client breathes) around the mesh medallion.
	Glow = { Centre = { 0, 12.3, 0 }, Radius = 2.25, Depth = 1.2 },
}
-- END GENERATED FlashGateKit

-- The holo board, past Flash on the side away from the arch: Beyond studs from his centre,
-- Forward studs toward the players from his line (negative: behind), its bottom Bottom studs
-- over the floor, Width x Height open, Header tall when collapsed (the top edge stays put; it
-- opens downward), turned Turn degrees toward the gate's centre line. PixelsPerStud for its
-- SurfaceGui; Rows records shown.
FlashGate.Board = {
	Beyond = 7.6, Forward = -0.5, Bottom = 2.2, Width = 8.4, Height = 6.6, Header = 2.08, Turn = 14,
	Border = 0.12, Depth = 0.08, PixelsPerStud = 50, Rows = 5,
	-- The screen's layout, pixels from the top.
	TitleY = 8, TitleH = 38, StatusY = 46, StatusH = 28, CaptionY = 78, CaptionH = 22,
	DividerY = 104, ListY = 110, RowH = 32, FooterY = 276, FooterH = 24, BarY = 306, BarH = 8,
}

-- The client's budget (Gameplay/FlashGateClient).
FlashGate.Client = {
	AnimateRadius = 110, -- rings, glow and crackles move within this many studs of the camera
	BoardRadius = 140, -- the board's parts exist within this
	BoardMaxDistance = 90, -- its words are drawn within this
	SignHideRadius = 45, -- RaceGateSign (the billboard for far away) hides inside this
	CollapseDistance = 26, -- the open board closes when the player is this far from it
	BoardAskSeconds = 30, -- a fresh top 5 while the board is open
	BoardRetrySeconds = 3, -- asked again when no answer came (the server answers every 2 s at most)
	OpenSeconds = 0.45,
	CloseSeconds = 0.3,
	LoopSeconds = 0.25,
	TierSeconds = 5,
	GlowHz = 0.8,
	ScanSeconds = 1.8,
	ScanRise = 3.2,
	BurstSeconds = 0.6,
	GatherSpin = 2, -- the dashes turn this much faster while a race gathers
	Tiers = {
		High = { Dashes = true, Scan = true, Arcs = 4, DashHz = 60 },
		Mid = { Dashes = true, Scan = true, Arcs = 3, DashHz = 30 },
		Low = { Dashes = false, Scan = false, Arcs = 1, DashHz = 0 },
	},
	-- A crackle: Segments Beams from a point Offset studs off a body part, Length studs long,
	-- pushed sideways up to Jitter; shown Life seconds, then off Gap seconds (a burst divides the
	-- gap by BurstGapDivisor); every CyanEvery-th one is cyan, the others Flash's yellow.
	Crackle = { Segments = 3, MinLength = 0.9, MaxLength = 2.0, Jitter = 0.35, Offset = 0.15,
		Life = { 0.06, 0.14 }, Gap = { 0.05, 0.35 }, BurstGapDivisor = 4, Width = { 0.16, 0.05 }, CyanEvery = 4 },
}

----------------------------------------------------------------------
-- Words (en / es / pt; any other language reads English)
----------------------------------------------------------------------
FlashGate.Required = { "en", "es", "pt" }
-- The longest a line may be (characters, each placeholder counted as its longest value: a clock
-- "9:59", a record "00:00.00", a rank "50"); the labels also scale down.
FlashGate.Caps = {
	Title = 22, Status = 16, Open = 12, OpenIn = 18, Starting = 18, StartingIn = 20, Racing = 22, NextIn = 22,
	Mega = 24, Closed = 12, Hint = 42, Weekly = 22, Empty = 38, Loading = 16, YourBest = 32, YourBestNoRank = 26,
	NoTime = 36, InQueue = 32,
}
FlashGate.Strings = {
	en = {
		Title = "MULTIPLAYER RACE", Status = "STATUS: {1}", Open = "OPEN", OpenIn = "OPEN · {1}",
		Starting = "STARTING!", StartingIn = "STARTING IN {1}", Racing = "RACING · {1}", NextIn = "NEXT RACE {1}",
		Mega = "MEGA RACE · {1}", Closed = "CLOSED", Hint = "Talk to The Flash for the top times",
		Weekly = "WEEKLY TOP {1}", Empty = "No times yet. Be the first!", Loading = "Loading...",
		YourBest = "YOUR BEST {1} · #{2}", YourBestNoRank = "YOUR BEST {1}", NoTime = "Step on the rings to race!",
		InQueue = "YOU'RE IN! GET READY",
	},
	es = {
		Title = "CARRERA MULTIJUGADOR", Status = "ESTADO: {1}", Open = "ABIERTA", OpenIn = "ABIERTA · {1}",
		Starting = "¡YA EMPIEZA!", StartingIn = "EMPIEZA EN {1}", Racing = "EN CARRERA · {1}", NextIn = "PRÓXIMA {1}",
		Mega = "MEGA CARRERA · {1}", Closed = "CERRADA", Hint = "Habla con Flash para ver los récords",
		Weekly = "TOP {1} SEMANAL", Empty = "Aún no hay tiempos. ¡Sé el primero!", Loading = "Cargando...",
		YourBest = "TU MEJOR {1} · #{2}", YourBestNoRank = "TU MEJOR {1}", NoTime = "¡Pisa los anillos para correr!",
		InQueue = "¡ESTÁS DENTRO! PREPÁRATE",
	},
	pt = {
		Title = "CORRIDA MULTIJOGADOR", Status = "STATUS: {1}", Open = "ABERTA", OpenIn = "ABERTA · {1}",
		Starting = "JÁ VAI COMEÇAR!", StartingIn = "COMEÇA EM {1}", Racing = "CORRENDO · {1}", NextIn = "PRÓXIMA {1}",
		Mega = "MEGA CORRIDA · {1}", Closed = "FECHADA", Hint = "Fale com o Flash para ver os recordes",
		Weekly = "TOP {1} DA SEMANA", Empty = "Ainda sem tempos. Seja o primeiro!", Loading = "Carregando...",
		YourBest = "SEU MELHOR {1} · #{2}", YourBestNoRank = "SEU MELHOR {1}", NoTime = "Pise nos anéis para correr!",
		InQueue = "VOCÊ ESTÁ DENTRO! PREPARE-SE",
	},
}

-- The text for `key` in `lang` (English when that language lacks it, the key itself when even
-- English does). Never errors.
function FlashGate.Get(key: string, lang: string?): string
	local strings = FlashGate.Strings[lang or "en"]
	local text = strings and strings[key]
	if type(text) == "string" and text ~= "" then
		return text
	end
	text = FlashGate.Strings.en[key]
	return if type(text) == "string" then text else tostring(key)
end

-- Get with {1}, {2}... filled from the arguments (a missing one stays empty).
function FlashGate.Format(key: string, lang: string?, ...: any): string
	local args = table.pack(...)
	return (string.gsub(FlashGate.Get(key, lang), "{(%d)}", function(index)
		local value = args[tonumber(index) :: number]
		return if value == nil then "" else tostring(value)
	end))
end

-- The length a line is checked against (FlashGate.Caps): characters, with {1} counted as 8.
function FlashGate.MeasuredLength(text: string): number
	local counted = string.gsub(text, "{%d}", "########")
	return utf8.len(counted) or #counted
end

----------------------------------------------------------------------
-- Status, times, rows
----------------------------------------------------------------------
-- 75 -> "1:15" (a countdown, rounded up).
function FlashGate.Clock(seconds: any): string
	local s = math.max(0, math.ceil(tonumber(seconds) or 0))
	if s ~= s or s == math.huge then
		s = 0
	end
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- 32450 -> "00:32.45" (a record: minutes, seconds, hundredths); nothing usable -> "--:--.--".
function FlashGate.FormatTime(ms: any): string
	local value = tonumber(ms)
	if value == nil or value ~= value or value <= 0 or value == math.huge then
		return "--:--.--"
	end
	local centis = math.floor(value / 10 + 0.5)
	local minutes = math.min(99, centis // 6000)
	return string.format("%02d:%02d.%02d", minutes, (centis // 100) % 60, centis % 100)
end

-- The gate's status from the race server's Workspace attributes (RacePhase, RacePhaseEndsAt):
-- the word key, its argument and the colour name. `raceOn` = U4.IsOn("Race"), `mega` = a Mega
-- Race event running (RaceEventUntil in the future).
function FlashGate.StatusOf(phase: any, endsAt: any, now: number, raceOn: boolean, mega: boolean): (string, string?, string)
	if not raceOn then
		return "Closed", nil, "Muted"
	end
	local remaining = math.max(0, (tonumber(endsAt) or 0) - now)
	if phase == "Gathering" then
		if mega then
			return "Mega", FlashGate.Clock(remaining), "Amber"
		end
		return "OpenIn", FlashGate.Clock(remaining), "Green"
	elseif phase == "Staging" then
		return "Starting", nil, "Amber"
	elseif phase == "Countdown" then
		return "StartingIn", tostring(math.max(1, math.ceil(remaining))), "Amber"
	elseif phase == "Running" then
		return "Racing", FlashGate.Clock(remaining), "Orange"
	elseif phase == "Results" or phase == "Cooldown" then
		return "NextIn", FlashGate.Clock(remaining), "Cyan"
	end
	return "Open", nil, "Green"
end

-- The status line in `lang` ("STATUS: OPEN · 0:15") and its colour name.
function FlashGate.StatusLine(phase: any, endsAt: any, now: number, raceOn: boolean, mega: boolean, lang: string?): (string, string)
	local key, argument, color = FlashGate.StatusOf(phase, endsAt, now, raceOn, mega)
	return FlashGate.Format("Status", lang, FlashGate.Format(key, lang, argument)), color
end

-- A board name in the digital look: upper case, at most `max` characters ("…" when cut).
function FlashGate.ShortName(name: any, max: number?): string
	local text = string.upper(if type(name) == "string" and name ~= "" then name else "?")
	local limit = max or 18
	local length = utf8.len(text) or #text
	if length <= limit then
		return text
	end
	local cut = utf8.offset(text, limit) or (limit + 1)
	return string.sub(text, 1, cut - 1) .. "…"
end

-- Up to `count` rows { Rank, Name, Time, UserId } from a RaceLeaderboard list ({ UserId, Name,
-- Ms }, fastest first); anything malformed is skipped.
function FlashGate.Rows(list: any, count: number): { any }
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, entry in ipairs(list) do
		if #out >= count then
			break
		end
		if type(entry) == "table" and (tonumber(entry.Ms) or 0) > 0 then
			table.insert(out, {
				Rank = #out + 1,
				Name = FlashGate.ShortName(entry.Name, 18),
				Time = FlashGate.FormatTime(entry.Ms),
				UserId = tonumber(entry.UserId) or 0,
			})
		end
	end
	return out
end

----------------------------------------------------------------------
-- Layout (the builder places its markers from these; the client falls back to them when a gate
-- has none, e.g. one the owner made)
----------------------------------------------------------------------
-- The gate frame of an Update4Config Race.Gate entry ({ Position, Face }): at the floor point,
-- -Z toward Face (no CFrame.lookAt: it is wrong in Lune). `C` = the CFrame constructors.
function FlashGate.GateFrame(gate: any, C: any?): any?
	if type(gate) ~= "table" or gate.Position == nil or gate.Face == nil then
		return nil
	end
	local c = C or CFrame
	local position, face = gate.Position, gate.Face
	local dx, dz = face.X - position.X, face.Z - position.Z
	local yaw = if dx * dx + dz * dz > 1e-6 then math.atan2(-dx, -dz) else 0
	return c.new(position.X, position.Y, position.Z) * c.Angles(0, yaw, 0)
end

-- Flash's feet in the gate frame from LobbyNpcConfig.FlashBesideGate[world] ({ Side, Along,
-- Forward }): x, z and the side (+1 = the gate's right).
function FlashGate.FlashLocal(beside: any): (number, number, number)
	local side = if type(beside) == "table" and beside.Side == -1 then -1 else 1
	local along = if type(beside) == "table" then tonumber(beside.Along) or 18 else 18
	local forward = if type(beside) == "table" then tonumber(beside.Forward) or 3 else 3
	return side * along, -forward, side
end

-- The open board's centre in the gate frame: past Flash, facing the players, turned toward the
-- gate's centre line.
function FlashGate.BoardLocal(beside: any, C: any?): any
	local c = C or CFrame
	local b = FlashGate.Board
	local x, z, side = FlashGate.FlashLocal(beside)
	return c.new(x + side * b.Beyond, b.Bottom + b.Height / 2, z - b.Forward) * c.Angles(0, math.rad(side * b.Turn), 0)
end

-- The glass and its four Neon edges when `shown` studs of the board's height show: frames
-- relative to the open board's centre, and sizes. The top edge stays put.
function FlashGate.BoardPieces(shown: number, V: any?, C: any?): { [string]: { any } }
	local v, c = V or Vector3, C or CFrame
	local b = FlashGate.Board
	local h = math.clamp(shown, 0.05, b.Height)
	local top = b.Height / 2
	local mid = top - h / 2
	local w, e = b.Width, b.Border
	return {
		Glass = { c.new(0, mid, 0), v.new(w, h, b.Depth) },
		EdgeTop = { c.new(0, top + e / 2, 0), v.new(w + 2 * e, e, b.Depth * 2) },
		EdgeBottom = { c.new(0, top - h - e / 2, 0), v.new(w + 2 * e, e, b.Depth * 2) },
		EdgeLeft = { c.new(-(w + e) / 2, mid, 0), v.new(e, h, b.Depth * 2) },
		EdgeRight = { c.new((w + e) / 2, mid, 0), v.new(e, h, b.Depth * 2) },
	}
end

-- The CFrames (gate frame) of `count` dashes on a circle of `radius` at `height`, turned by
-- `angle` radians: each one's long axis (Z) along the circle.
function FlashGate.DashFrames(radius: number, count: number, angle: number, height: number, C: any?): { any }
	local c = C or CFrame
	local out = {}
	for index = 0, count - 1 do
		local theta = angle + index * (2 * math.pi / count)
		table.insert(out, c.Angles(0, -theta, 0) * c.new(radius, height, 0))
	end
	return out
end

-- A jagged crackle: Segments + 1 points from `start` along `direction` (a unit Vector3) for
-- `length` studs, the inner ones pushed sideways up to `jitter` studs. `rng` has NextNumber().
function FlashGate.CracklePoints(rng: any, start: any, direction: any, length: number, jitter: number, segments: number, V: any?): { any }
	local v = V or Vector3
	local up = if math.abs(direction.Y) < 0.9 then v.new(0, 1, 0) else v.new(1, 0, 0)
	local side = direction:Cross(up).Unit
	local other = direction:Cross(side).Unit
	local points = { start }
	for index = 1, segments do
		local point = start + direction * (length * index / segments)
		if index < segments then
			point += side * ((rng:NextNumber() * 2 - 1) * jitter) + other * ((rng:NextNumber() * 2 - 1) * jitter)
		end
		table.insert(points, point)
	end
	return points
end

-- The fraction of the current phase gone by (for the board's bar), from when the client saw the
-- phase begin; nil when there is no timer.
function FlashGate.PhaseProgress(seenAt: any, endsAt: any, now: number): number?
	local from, to = tonumber(seenAt), tonumber(endsAt)
	if not from or not to or to <= from then
		return nil
	end
	return math.clamp((now - from) / (to - from), 0, 1)
end

----------------------------------------------------------------------
-- The holo board's parts and screen (plain Instances from `env`: { Instance, Vector3, CFrame,
-- Color3, UDim, UDim2, Enum, Font?, ColorSequence?, NumberSequence? })
----------------------------------------------------------------------
local function rgb(env: any, name: string): any
	local values = FlashGate.Colors[name] or FlashGate.Colors.Text
	return env.Color3.fromRGB(values[1], values[2], values[3])
end
FlashGate.Rgb = rgb

local function make(env: any, className: string, properties: { [string]: any }, parent: any?): any
	local object = env.Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function fontOf(env: any, fontName: string): any?
	if env.Font then
		local ok, face = pcall(function()
			return env.Font.fromEnum(env.Enum.Font[fontName])
		end)
		if ok then
			return face
		end
	end
	return nil
end

-- A label: FredokaOne (through FontFace when env has Font: a Lune `.Font =` cannot be
-- serialized), no automatic translation, a thin ink outline.
local function label(env: any, parent: any, name: string, x: number, y: number, w: number, h: number, colorName: string, xAlign: string?): any
	local Enum, UDim2 = env.Enum, env.UDim2
	local object = make(env, "TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = "",
		TextColor3 = rgb(env, colorName),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment[xAlign or "Center"],
		AutoLocalize = false,
		ZIndex = 3,
	}, nil)
	local face = fontOf(env, "FredokaOne")
	if face then
		object.FontFace = face
	else
		object.Font = Enum.Font.FredokaOne
	end
	make(env, "UIStroke", { Name = "Outline", Color = rgb(env, "Ink"), Thickness = 1.5, Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, object)
	object.Parent = parent
	return object
end

local function corner(env: any, parent: any, radius: number)
	local c = make(env, "UICorner", { CornerRadius = env.UDim.new(0, radius) }, nil)
	-- Lune keeps per-corner radii apart from CornerRadius; the game fills them from it.
	for _, key in { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" } do
		pcall(function()
			(c :: any)[key] = env.UDim.new(0, radius)
		end)
	end
	c.Parent = parent
	return c
end

-- The board: a Model FlashHoloBoard with Glass (transparent, carrying the SurfaceGui Screen on its
-- front) and four cyan Neon edges (EdgeTop / EdgeBottom / EdgeLeft / EdgeRight), all inert.
-- The client places them (BoardPieces), fills the words and animates. The screen, top to bottom:
-- Title, Status, Caption (the hint when collapsed, "WEEKLY TOP 5" when open), Divider, List
-- (Row1..RowN: Mine highlight, Rank, Name, Time; Empty), Footer, Bar (Fill), the corner brackets.
function FlashGate.BuildBoard(env: any): any
	local Enum, UDim2 = env.Enum, env.UDim2
	local b = FlashGate.Board
	local model = make(env, "Model", { Name = FlashGate.Names.Board }, nil)
	local function part(name: string, colorName: string, material: string, transparency: number): any
		return make(env, "Part", {
			Name = name,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			Color = rgb(env, colorName),
			Material = Enum.Material[material],
			Transparency = transparency,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Size = env.Vector3.new(1, 1, 1),
		}, model)
	end
	local glass = part("Glass", "Glass", "SmoothPlastic", 1)
	for _, name in { "EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight" } do
		part(name, "Cyan", "Neon", 0.05)
	end

	local width = math.floor(b.Width * b.PixelsPerStud + 0.5)
	local screen = make(env, "SurfaceGui", {
		Name = FlashGate.Names.Screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = b.PixelsPerStud,
		LightInfluence = 0,
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	for key, value in { ClipsDescendants = true, Brightness = 1.4, MaxDistance = FlashGate.Client.BoardMaxDistance } do
		pcall(function()
			(screen :: any)[key] = value
		end)
	end
	screen.Parent = glass

	-- The tinted glass (the part itself stays invisible: Glass material is too dear on phones).
	local back = make(env, "Frame", { Name = "Back", BackgroundColor3 = rgb(env, "Glass"), BackgroundTransparency = 0.22,
		BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, screen)
	if env.ColorSequence and env.NumberSequence then
		make(env, "UIGradient", {
			Rotation = 90,
			Color = env.ColorSequence.new(rgb(env, "Glass"), env.Color3.fromRGB(2, 8, 20)),
			Transparency = env.NumberSequence.new(0, 0.15),
		}, back)
	end
	-- Corner brackets (cyan L's), held to the corners by scale so they follow the opening.
	local brackets = make(env, "Frame", { Name = "Brackets", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, screen)
	for _, spot in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local sx, sy = spot[1], spot[2]
		local holder = make(env, "Frame", {
			Name = "Corner" .. sx .. sy,
			AnchorPoint = env.Vector2 and env.Vector2.new(sx, sy) or nil,
			BackgroundTransparency = 1,
			Position = UDim2.new(sx, if sx == 0 then 6 else -6, sy, if sy == 0 then 6 else -6),
			Size = UDim2.fromOffset(18, 18),
			ZIndex = 2,
		}, brackets)
		make(env, "Frame", { Name = "H", BackgroundColor3 = rgb(env, "Cyan"), BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, if sy == 0 then 0 else 15), Size = UDim2.fromOffset(18, 3), ZIndex = 2 }, holder)
		make(env, "Frame", { Name = "V", BackgroundColor3 = rgb(env, "Cyan"), BorderSizePixel = 0,
			Position = UDim2.fromOffset(if sx == 0 then 0 else 15, 0), Size = UDim2.fromOffset(3, 18), ZIndex = 2 }, holder)
	end

	local inner = width - 40
	label(env, screen, "Title", 20, b.TitleY, inner, b.TitleH, "Text")
	label(env, screen, "Status", 20, b.StatusY, inner, b.StatusH, "Green")
	label(env, screen, "Caption", 20, b.CaptionY, inner, b.CaptionH, "Muted")
	make(env, "Frame", { Name = "Divider", BackgroundColor3 = rgb(env, "Cyan"), BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, b.DividerY), Size = UDim2.fromOffset(inner, 2), ZIndex = 2 }, screen)
	local list = make(env, "Frame", { Name = "List", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.fromOffset(14, b.ListY), Size = UDim2.fromOffset(width - 28, b.RowH * b.Rows), ZIndex = 2 }, screen)
	for index = 1, b.Rows do
		local row = make(env, "Frame", { Name = "Row" .. index, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, (index - 1) * b.RowH), Size = UDim2.new(1, 0, 0, b.RowH), ZIndex = 2 }, list)
		local mine = make(env, "Frame", { Name = "Mine", BackgroundColor3 = rgb(env, "Cyan"), BackgroundTransparency = 0.78,
			BorderSizePixel = 0, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 1, -4), Visible = false, ZIndex = 2 }, row)
		corner(env, mine, 6)
		label(env, row, "Rank", 6, 2, 40, b.RowH - 4, "Text", "Left")
		-- 2026-09-26: "PlayerName", not "Name" (row.Name is the row's own Name property, a string).
		label(env, row, "PlayerName", 46, 3, width - 28 - 46 - 124, b.RowH - 6, "Text", "Left")
		label(env, row, "Time", width - 28 - 120, 3, 112, b.RowH - 6, "Text", "Right")
	end
	label(env, list, "Empty", 0, 40, width - 28, 34, "Muted")
	label(env, screen, "Footer", 20, b.FooterY, inner, b.FooterH, "Amber")
	local bar = make(env, "Frame", { Name = "Bar", BackgroundColor3 = rgb(env, "PadDark"), BackgroundTransparency = 0.1,
		BorderSizePixel = 0, Position = UDim2.fromOffset(40, b.BarY), Size = UDim2.fromOffset(width - 80, b.BarH), ZIndex = 2 }, screen)
	corner(env, bar, 4)
	local fill = make(env, "Frame", { Name = "Fill", BackgroundColor3 = rgb(env, "Cyan"), BorderSizePixel = 0,
		Size = UDim2.fromScale(0.35, 1), ZIndex = 3 }, bar)
	corner(env, fill, 4)
	return model
end

return FlashGate
