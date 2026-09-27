--!strict
-- ReplicatedStorage/Shared/SuperSonicDialogue.luau — Dr. Eggman's lines during the "Super Sonic vs
-- Dr. Eggman" live event and where his dialogue box goes on screen (2026-09-26, owner: "a clean
-- dialogue box, bottom-centre on desktop, phone-sized on phones, his portrait, typewriter text,
-- en / es / pt; make him feel AGGRESSIVE and chaotic"). Pure data and numbers (Lune tests it):
--   Lines        key -> { en, es, pt, Voice (a SuperSonicEventFx.Sounds key or nil), Mood }. The keys the
--                contract names (Shared/SuperSonicEvent: Dialogue cues and Taunts) all have a line; the
--                client plays the others on its own triggers (a parallel salvo, a hit, the emeralds...)
--   Groups       one moment, several lines: Resolve picks one (never the same twice in a row)
--   Line         the text of a key in a language (anything else reads English)
--   Graphemes    how many characters a line types out (UTF-8: accents count once)
--   Typed        how many are showing `elapsed` seconds in (TextLabel.MaxVisibleGraphemes)
--   Hold         how long a line stays on screen
--   Layout       the box on a screen of a given size: the letterbox band during a cinematic, the
--                bottom centre over the level / stamina bars on a computer, and on a phone a compact
--                box under the boss bar, inside the notch / home-indicator insets (CinematicFit, the
--                rules the race windows follow: RaceHudLayout.WindowFit), scaled so every word is
--                11 px or more
-- 2026-09-26 (owner, v3): "don't fill the screen with UI and text: the dialogue must be SIMPLE and basic":
-- plain typewriter text (white, the game's navy outline) beside a SMALL round portrait of his face; no box, no
-- name tab, no banner (Designs below: a strip, Header 0); the phone strip sits under the new, smaller boss bar.
-- Used by Gameplay/SuperSonicEventClient (the voices and when each line plays).
local CinematicFit: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("CinematicFit", 10))
	else require("./CinematicFit")
local HudErgonomics: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("HudErgonomics", 10))
	else require("./HudErgonomics")

local Dialogue = {}

Dialogue.Version = 3
Dialogue.Speaker = "DR. EGGMAN"
Dialogue.CharsPerSecond = 42 -- he talks fast (angry)
Dialogue.PunctuationPause = 0.09 -- a beat after ! ? . , (seconds)
Dialogue.HoldMin = 1.9
Dialogue.HoldMax = 4.6
Dialogue.ReadPerChar = 0.028 -- reading time after the line is out
Dialogue.MinText = 11

-- Moods: how the portrait and the box react (Shake: px of the box's jolt; Tint: the name tab's colour).
Dialogue.Moods = {
	Angry = { Shake = 6, Tint = { 230, 40, 30 } },
	Laugh = { Shake = 3, Tint = { 255, 170, 30 } },
	Panic = { Shake = 8, Tint = { 255, 110, 20 } },
	Hurt = { Shake = 10, Tint = { 255, 60, 60 } },
	Smug = { Shake = 2, Tint = { 200, 60, 200 } },
}

-- 2026-09-26 (owner): his lines. Voice = the owner's uploaded clips (SuperSonicEventFx.Sounds keys).
Dialogue.Lines = {
	-- The contract's cinematic cues (SSE.Dialogue).
	EggmanSonic = { -- the opening, as he lifts off: "Sonic! ..."
		Mood = "Angry",
		en = "SONIC! ...So you brought ALL your little friends?!",
		es = "¡SONIC! ...¿Así que trajiste a TODOS tus amiguitos?",
		pt = "SONIC! ...Então você trouxe TODOS os seus amiguinhos?!",
	},
	EggmanRevenge = { -- "I'll have my revenge!"
		Mood = "Angry",
		en = "I'll have my REVENGE! Egg Mobile, BATTLE MODE!",
		es = "¡Tendré mi VENGANZA! ¡Egg Mobile, MODO BATALLA!",
		pt = "Eu terei minha VINGANÇA! Egg Mobile, MODO BATALHA!",
	},
	EggmanDefeat = {
		Mood = "Hurt",
		en = "NOOO! My beautiful Egg Mobile!",
		es = "¡NOOO! ¡Mi hermoso Egg Mobile!",
		pt = "NÃÃÃO! Meu lindo Egg Mobile!",
	},
	EggmanEscape = {
		Mood = "Laugh",
		Voice = "VoiceCatch",
		en = "HAHAHA! Catch me if you can!",
		es = "¡JAJAJA! ¡Atrápenme si pueden!",
		pt = "HAHAHA! Me peguem se puderem!",
	},
	-- "I'll be back!" (the defeat and the escape, as he flies off into the horizon): 2026-09-26 (owner) his
	-- uploaded goodbye line, and the box shows the same words.
	EggmanBeBack = {
		Mood = "Angry",
		Voice = "VoiceBeBack",
		en = "This is not the end. I will be back... I promise.",
		es = "Este no es el final. Volveré... Te lo prometo.",
		pt = "Este não é o fim. Eu voltarei... Eu prometo.",
	},
	-- The contract's taunts (SSE.Taunts): a refused attack, his windows.
	EggmanShielded = {
		Mood = "Smug",
		Voice = "VoiceShielded",
		en = "What are you doing? I'm right here!",
		es = "¿Qué estás haciendo? ¡Estoy justo aquí!",
		pt = "O que você está fazendo? Eu estou bem aqui!",
	},
	EggmanReload = {
		Mood = "Panic",
		en = "Reloading?! NOW?! Hurry up, you useless bucket of bolts!",
		es = "¿¡Recargando?! ¿¡AHORA?! ¡Apúrate, montón de chatarra inútil!",
		pt = "Recarregando?! AGORA?! Anda logo, lata velha inútil!",
	},
	EggmanAttack = {
		Mood = "Angry",
		en = "Cannon READY! Eat THIS!",
		es = "¡Cañón LISTO! ¡Tomen ESTO!",
		pt = "Canhão PRONTO! Tomem ISSO!",
	},
	EggmanCatch = {
		Mood = "Laugh",
		Voice = "VoiceCatch",
		en = "HAHAHA! Catch me if you can!",
		es = "¡JAJAJA! ¡Atrápenme si pueden!",
		pt = "HAHAHA! Me peguem se puderem!",
	},
	EggmanEmpire = {
		Mood = "Angry",
		en = "Feel the power of the EGGMAN EMPIRE!",
		es = "¡Sientan el poder del IMPERIO EGGMAN!",
		pt = "Sintam o poder do IMPÉRIO EGGMAN!",
	},
	-- The client's own triggers.
	EggmanParallel = { -- a Parallel salvo leaves the cannon
		Mood = "Angry",
		Voice = "VoiceParallel",
		en = "PARALLEL ATTACK!",
		es = "¡ATAQUE PARALELO!",
		pt = "ATAQUE PARALELO!",
	},
	EggmanBombard = { -- the Bombard begins
		Mood = "Laugh",
		en = "Rain fire on them! Run, little hedgehogs, RUN!",
		es = "¡Que llueva fuego! ¡Corran, erizitos, CORRAN!",
		pt = "Chuva de fogo neles! Corram, ouriçinhos, CORRAM!",
	},
	EggmanEmeralds = { -- the Chaos Emeralds appear
		Mood = "Panic",
		en = "WHAT?! The Chaos Emeralds?! NO, NO, NOOO!",
		es = "¿¡QUÉ?! ¿¡Las Esmeraldas del Caos?! ¡NO, NO, NOOO!",
		pt = "O QUÊ?! As Esmeraldas do Caos?! NÃO, NÃO, NÃÃÃO!",
	},
	EggmanSuper = { -- the Battle begins: they are Super
		Mood = "Panic",
		en = "S-SUPER SONIC?! Impossible! Shields UP!",
		es = "¿¡S-SUPER SONIC?! ¡Imposible! ¡ESCUDOS ARRIBA!",
		pt = "S-SUPER SONIC?! Impossível! ESCUDOS ATIVADOS!",
	},
	EggmanHit1 = {
		Mood = "Hurt",
		en = "OUCH! My beautiful Egg Mobile!",
		es = "¡AY! ¡Mi hermoso Egg Mobile!",
		pt = "AI! Meu lindo Egg Mobile!",
	},
	EggmanHit2 = {
		Mood = "Angry",
		en = "Grrr... You'll PAY for that!",
		es = "Grrr... ¡Me las vas a PAGAR!",
		pt = "Grrr... Você vai PAGAR por isso!",
	},
	EggmanHit3 = {
		Mood = "Hurt",
		en = "Stop that! STOP IT RIGHT NOW!",
		es = "¡Basta! ¡BASTA YA MISMO!",
		pt = "Pare com isso! PARE AGORA MESMO!",
	},
	EggmanHitBig = { -- a fully charged hit
		Mood = "Hurt",
		en = "AAARGH! That one really HURT!",
		es = "¡AAARGH! ¡Ese sí me DOLIÓ!",
		pt = "AAARGH! Essa DOEU de verdade!",
	},
	EggmanLowHp = { -- the hull under a quarter
		Mood = "Panic",
		en = "Hull CRITICAL?! This can't be happening!",
		es = "¿¡Casco CRÍTICO?! ¡Esto no puede estar pasando!",
		pt = "Casco CRÍTICO?! Isso não pode estar acontecendo!",
	},
}
-- One moment, several lines (Resolve picks one; never the same twice in a row).
Dialogue.Groups = {
	EggmanAttack = { "EggmanAttack", "EggmanCatch", "EggmanEmpire" },
	EggmanHit = { "EggmanHit1", "EggmanHit2", "EggmanHit3" },
}
-- How much a line matters: a lower one never cuts a higher one short (a cinematic line is never cut by a taunt).
Dialogue.Priority = {
	EggmanSonic = 3, EggmanRevenge = 3, EggmanDefeat = 3, EggmanBeBack = 3, EggmanEscape = 3,
	EggmanShielded = 2, EggmanParallel = 2, EggmanEmeralds = 2, EggmanSuper = 2, EggmanReload = 2, EggmanLowHp = 2,
}

function Dialogue.Line(lang: string?, key: string): string
	local line = (Dialogue.Lines :: any)[key]
	if not line then
		return ""
	end
	return line[lang or "en"] or line.en or ""
end

function Dialogue.Mood(key: string): any
	local line = (Dialogue.Lines :: any)[key]
	return Dialogue.Moods[line and line.Mood or "Angry"] or Dialogue.Moods.Angry
end

function Dialogue.PriorityOf(key: string): number
	return (Dialogue.Priority :: any)[key] or 1
end

-- The line to play for `key`: itself, or one of its group (not `last` when there is a choice); `seed` picks.
function Dialogue.Resolve(key: string, last: string?, seed: number?): string?
	local list = (Dialogue.Groups :: any)[key]
	if not list or #list == 0 then
		return if (Dialogue.Lines :: any)[key] then key else nil
	end
	local n = #list
	local index = (math.floor(math.abs(tonumber(seed) or 0)) % n) + 1
	if list[index] == last and n > 1 then
		index = index % n + 1
	end
	return list[index]
end

-- The line's UTF-8 characters ("¡Volveré!" is 9).
function Dialogue.Graphemes(text: string): number
	local ok, n = pcall(utf8.len, text)
	if ok and type(n) == "number" then
		return n
	end
	return #text
end

local PAUSES = { ["!"] = true, ["?"] = true, ["."] = true, [","] = true }

-- How many characters are showing `elapsed` seconds after the line began (typewriter, a beat after
-- every ! ? . ,): 0 before, all of them once it is out.
function Dialogue.Typed(text: string, elapsed: number): number
	local total = Dialogue.Graphemes(text)
	local t = tonumber(elapsed) or 0
	if t <= 0 then
		return 0
	end
	local step = 1 / Dialogue.CharsPerSecond
	local clock = 0
	local count = 0
	local ok = pcall(function()
		for _, code in utf8.codes(text) do
			clock += step
			if clock > t then
				return
			end
			count += 1
			if PAUSES[utf8.char(code)] then
				clock += Dialogue.PunctuationPause
			end
		end
	end)
	if not ok then
		return math.clamp(math.floor(t * Dialogue.CharsPerSecond), 0, total)
	end
	return math.min(count, total)
end

-- Seconds until the whole line is out.
function Dialogue.TypeSeconds(text: string): number
	local seconds = 0
	local ok = pcall(function()
		for _, code in utf8.codes(text) do
			seconds += 1 / Dialogue.CharsPerSecond
			if PAUSES[utf8.char(code)] then
				seconds += Dialogue.PunctuationPause
			end
		end
	end)
	if not ok then
		seconds = #text / Dialogue.CharsPerSecond
	end
	return seconds
end

-- How long a line stays up (typing it, then reading it).
function Dialogue.Hold(text: string): number
	local n = Dialogue.Graphemes(text)
	return math.clamp(Dialogue.TypeSeconds(text) + 1.1 + n * Dialogue.ReadPerChar, Dialogue.HoldMin, Dialogue.HoldMax)
end

----------------------------------------------------------------------
-- The box
----------------------------------------------------------------------
-- The two arrangements, in design pixels: Wide (computers, and every cinematic), Compact (a phone
-- during play: under the boss bar, the portrait smaller). 2026-09-26 (owner, v3): a slim strip (a small round
-- portrait + the text), no name tab (Header 0, NameSize 0: nothing drawn over the strip).
Dialogue.Designs = {
	Wide = { Width = 560, Height = 60, Header = 0, Portrait = 48, Pad = 6, TextSize = 21, NameSize = 0 },
	Compact = { Width = 460, Height = 50, Header = 0, Portrait = 40, Pad = 5, TextSize = 19, NameSize = 0 },
}
Dialogue.Margin = 8
Dialogue.MaxScale = { Desktop = 1, Phone = 0.9 }
Dialogue.PhoneHeightShare = 0.3 -- the box and its tab, of the whole screen's height, on a phone during play
Dialogue.PhoneWidthShare = 0.64 -- of the width during play: the phone column and the side bar keep their corners
Dialogue.PortraitWidthShare = 0.94 -- a phone held upright
Dialogue.CinematicHeightShare = 0.42 -- of the letterbox band
-- Gameplay/SuperSonicEventClient's HP bar (HUD pixels): 2026-09-26 (owner, v3) the small bar in the game's style,
-- its name over it and the tiny "ATTACK NOW!" under it: SuperSonicEventFx.BossBar / BossBarHeight / BossBarWidth.
Dialogue.BossBar = { Top = 6, Height = 52, Gap = 6, WidthShare = 0.3, MinWidth = 200, MaxWidth = 340 }
Dialogue.BarGap = 10 -- over the level bar on a computer

export type Options = {
	topBar: number?, -- Roblox's top bar (GuiService:GetGuiInset().Y)
	touch: boolean?, -- a touch-only device (LOW_POWER / no keyboard)
	cinematic: boolean?, -- the letterbox is up
	bars: number?, -- the letterbox bar share (CinematicFit.Bars)
	hudInset: boolean?, -- the Main HUD sits under the top bar (its IgnoreGuiInset is false)
}

local function rect(left: number, top: number, width: number, height: number): any
	return { Left = left, Top = top, Right = left + width, Bottom = top + height }
end

-- The box on a viewW x viewH screen, in whole-screen pixels (a ScreenGui with IgnoreGuiInset):
-- { Left, Top, Right, Bottom (the box), HeaderTop, Scale, Design ("Wide" / "Compact"), TextSize,
--   NameSize, PortraitSize, Phone, Safe (the safe rect it stays in), Cinematic }.
function Dialogue.Layout(viewW: number, viewH: number, options: Options?): any
	local o = options or {}
	local topBar = math.max(0, tonumber(o.topBar) or 0)
	local phone = CinematicFit.IsPhone(viewW, viewH, o.touch == true)
	local insets = CinematicFit.Insets(viewW, viewH, phone, topBar)
	local m = Dialogue.Margin
	local cinematic = o.cinematic == true
	local designName = if phone and not cinematic then "Compact" else "Wide"
	local design = (Dialogue.Designs :: any)[designName]
	local w, h, over = design.Width, design.Height, design.Header
	local maxScale = if phone then Dialogue.MaxScale.Phone else Dialogue.MaxScale.Desktop
	local safe = rect(insets.Left, insets.Top, viewW - insets.Left - insets.Right, viewH - insets.Top - insets.Bottom)
	local left, top, scale
	if cinematic then
		local bars = tonumber(o.bars) or CinematicFit.Bars(viewW, viewH, phone)
		local band = CinematicFit.Band(viewW, viewH, bars, insets)
		scale = math.min(maxScale, (band.W - 2 * m) / w, (band.H * Dialogue.CinematicHeightShare) / (h + over))
		local bh = h * scale
		left = band.X + band.W / 2 - w * scale / 2
		top = band.Y + band.H - m - bh
		safe = rect(band.X, band.Y, band.W, band.H)
	elseif phone then
		-- Under the boss bar (HUD pixels start under the top bar when the HUD keeps the inset).
		local hudTop = if o.hudInset == false then 0 else topBar
		local b = Dialogue.BossBar
		local below = math.max(insets.Top, hudTop + b.Top + b.Height + b.Gap)
		-- (a phone held upright: the whole width, the corners hold nothing there)
		local widthShare = if viewW >= viewH then Dialogue.PhoneWidthShare else Dialogue.PortraitWidthShare
		scale = math.min(
			maxScale,
			(viewW * widthShare) / w,
			(safe.Right - safe.Left - 2 * m) / w,
			(viewH * Dialogue.PhoneHeightShare) / (h + over),
			(safe.Bottom - below - 2 * m) / (h + over)
		)
		left = viewW / 2 - w * scale / 2
		top = below + over * scale
	else
		-- A computer during play: bottom centre, over the level bar.
		local hudTop = if o.hudInset == false then 0 else topBar
		local bars = HudErgonomics.CentreBarRects(viewW, viewH - hudTop)
		local barTop = bars[1].Top + hudTop
		scale = math.min(maxScale, (safe.Right - safe.Left - 2 * m) / w, (barTop - Dialogue.BarGap - safe.Top - 2 * m) / (h + over))
		local bh = h * scale
		left = viewW / 2 - w * scale / 2
		top = barTop - Dialogue.BarGap - bh
	end
	scale = math.max(scale, 0.3)
	local box = rect(math.floor(left + 0.5), math.floor(top + 0.5), w * scale, h * scale)
	box.HeaderTop = box.Top - over * scale
	box.Scale = scale
	box.Design = designName
	box.TextSize = design.TextSize * scale
	box.NameSize = design.NameSize * scale
	box.PortraitSize = design.Portrait * scale
	box.Phone = phone
	box.Safe = safe
	box.Cinematic = cinematic
	return box
end

-- The boss bar's rect in whole-screen pixels (what a phone's box keeps under).
function Dialogue.BossBarRect(viewW: number, topBar: number?, hudInset: boolean?): any
	local b = Dialogue.BossBar
	local hudTop = if hudInset == false then 0 else math.max(0, tonumber(topBar) or 0)
	local width = math.clamp(math.floor(viewW * b.WidthShare + 0.5), b.MinWidth, b.MaxWidth)
	return rect(viewW / 2 - width / 2, hudTop + b.Top, width, b.Height)
end

return Dialogue
