--!strict
-- ReplicatedStorage/Shared/RetentionMath.luau — Update 4 Playtime Boost and Streak Rewards
-- (output/Update4/PLAN.md §7.7), pure: no service, no instance, no clock of its own. The same
-- code runs in the profile section (Services/Data/U4/RetentionSection), the server service
-- (Social/RetentionService), both panels and the topbar, and in the Lune tests.
-- Every function takes the Update4Config tables it needs (`cfg` = U4.Playtime or U4.Streak);
-- left out, the shipped defaults below are used.
local RetentionMath = {}

local DEFAULT_PLAYTIME = {
	StepSeconds = 600, StepPercent = 10, MaxPercent = 100, ResumeGraceSeconds = 900,
	Markers = { 600, 1800, 3600, 6000 },
}
local DEFAULT_STREAK = {
	PercentPerDay = 10, MaxPercent = 100, GraceEveryDays = 7, CycleDays = 21, MaxPending = 6, MaxClaimedKept = 64,
	Milestones = {
		First = { [7] = { Perk = 0.2, TitleId = "streak_7" }, [14] = { Perk = 0.4 },
			[21] = { SpinTickets = 5, SpeedPotionMinutes = 60, WinsPotionMinutes = 60, TitleId = "streak_21" } },
		Repeat = { [7] = { SpinTickets = 2, SpeedPotionMinutes = 30 }, [14] = { SpinTickets = 2, SpeedPotionMinutes = 30 },
			[21] = { SpinTickets = 5, SpeedPotionMinutes = 60, WinsPotionMinutes = 60 } },
	},
}
RetentionMath.DefaultPlaytime = DEFAULT_PLAYTIME
RetentionMath.DefaultStreak = DEFAULT_STREAK
RetentionMath.MilestoneDays = { 7, 14, 21 }
RetentionMath.MaxPerk = 0.4
RetentionMath.KeyPattern = "^c(%d+)_d(%d+)$"

local function num(value: any, fallback: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return fallback
	end
	return n
end

local function int(value: any): number
	return math.max(0, math.floor(num(value, 0)))
end

-- ---------------------------------------------------------------- days and clocks

function RetentionMath.UtcDay(unix: number): number
	return math.floor(num(unix, 0) / 86400)
end

function RetentionMath.NextUtcMidnight(unix: number): number
	return (RetentionMath.UtcDay(unix) + 1) * 86400
end

-- "04:07" under an hour, "2:04:07" above (the panels' countdowns).
function RetentionMath.FormatClock(seconds: number): string
	local s = math.max(0, math.floor(num(seconds, 0)))
	local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%02d:%02d", m, s % 60)
end

-- ---------------------------------------------------------------- Playtime Boost

function RetentionMath.PlaytimeMaxSeconds(cfg: any?): number
	local c = cfg or DEFAULT_PLAYTIME
	return math.ceil(num(c.MaxPercent, 100) / math.max(1, num(c.StepPercent, 10))) * math.max(1, num(c.StepSeconds, 600))
end

-- +10 % per full 10 minutes, at most +100 %: 10m 10, 30m 30, 1h 60, 100 min 100.
function RetentionMath.PlaytimePercent(seconds: number, cfg: any?): number
	local c = cfg or DEFAULT_PLAYTIME
	local steps = math.floor(math.max(0, num(seconds, 0)) / math.max(1, num(c.StepSeconds, 600)))
	return math.min(num(c.MaxPercent, 100), num(c.StepPercent, 10) * steps)
end

-- Seconds to the next +10 %, or nil at the maximum.
function RetentionMath.PlaytimeNextStepIn(seconds: number, cfg: any?): number?
	local c = cfg or DEFAULT_PLAYTIME
	if RetentionMath.PlaytimePercent(seconds, c) >= num(c.MaxPercent, 100) then
		return nil
	end
	local step = math.max(1, num(c.StepSeconds, 600))
	local s = math.max(0, num(seconds, 0))
	return step - (s % step)
end

-- How many funnel markers (10m/30m/60m/Max) `seconds` has reached: 0..#Markers.
function RetentionMath.PlaytimeMarkersReached(seconds: number, cfg: any?): number
	local c = cfg or DEFAULT_PLAYTIME
	local reached = 0
	for index, marker in c.Markers or DEFAULT_PLAYTIME.Markers do
		if num(seconds, 0) >= num(marker, math.huge) then
			reached = index
		end
	end
	return reached
end

-- The saved counter after a join: a player back within ResumeGraceSeconds (a world teleport, a
-- crash, an AFK rejoin) keeps their seconds and session; anyone else starts over at `now`.
-- Returns seconds, sessionStart, resumed.
function RetentionMath.ResumePlaytime(saved: any, now: number, cfg: any?): (number, number, boolean)
	local c = cfg or DEFAULT_PLAYTIME
	local state = if type(saved) == "table" then saved else {}
	local lastSeen = int(state.PlaytimeLastSeen)
	local start = int(state.PlaytimeSessionStart)
	local seconds = math.clamp(num(state.PlaytimeSeconds, 0), 0, RetentionMath.PlaytimeMaxSeconds(c))
	local away = num(now, 0) - lastSeen
	if lastSeen > 0 and start > 0 and away >= -60 and away <= num(c.ResumeGraceSeconds, 900) then
		return seconds, start, true
	end
	return 0, math.floor(num(now, 0)), false
end

-- ---------------------------------------------------------------- Streak

function RetentionMath.CycleDay(days: number, cfg: any?): number
	local cycle = math.max(1, num((cfg or DEFAULT_STREAK).CycleDays, 21))
	local d = int(days)
	return if d <= 0 then 0 else ((d - 1) % cycle) + 1
end

function RetentionMath.Cycle(days: number, cfg: any?): number
	local cycle = math.max(1, num((cfg or DEFAULT_STREAK).CycleDays, 21))
	local d = int(days)
	return if d <= 0 then 1 else math.floor((d - 1) / cycle) + 1
end

-- +10 % per streak day, at most +100 %, as a fraction (day 1 = 0.1: a newcomer sees x1.1 at once).
function RetentionMath.StreakBonus(days: number, cfg: any?): number
	local c = cfg or DEFAULT_STREAK
	return math.min(num(c.MaxPercent, 100), num(c.PercentPerDay, 10) * int(days)) / 100
end

-- The streak that still counts on `today` before today's check-in: yesterday's (or the day
-- before, when the weekly grace is free) keeps its days; an older one is already broken.
function RetentionMath.LiveStreakDays(state: any, today: number, cfg: any?): number
	local c = cfg or DEFAULT_STREAK
	if type(state) ~= "table" then
		return 0
	end
	local days, last = int(state.StreakDays), int(state.StreakLastDay)
	local gap = today - last
	if days <= 0 or last <= 0 then
		return 0
	end
	if gap <= 1 then
		return days
	end
	if gap == 2 and today - int(state.StreakGraceDay) >= num(c.GraceEveryDays, 7) then
		return days
	end
	return 0
end

function RetentionMath.ParseKey(key: any): (number?, number?)
	if type(key) ~= "string" or #key > 16 then
		return nil, nil
	end
	local cycle, day = string.match(key, RetentionMath.KeyPattern)
	local c, d = tonumber(cycle), tonumber(day)
	if not c or not d or c < 1 or (d ~= 7 and d ~= 14 and d ~= 21) then
		return nil, nil
	end
	return c, d
end

local function listHas(list: any, value: string): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, v in list do
		if v == value then
			return true
		end
	end
	return false
end

-- The key a milestone reached now is filed under. A cycle's rewards come once per account:
-- after a reset, reaching day 7 of cycle 1 again (its key already claimed or waiting) files
-- it under the next free cycle, so it pays the Repeat reward (never the title/perk twice).
function RetentionMath.KeyFor(state: any, cycle: number, day: number): string
	local c = math.max(1, math.floor(cycle))
	for _ = 1, 1000 do
		local key = string.format("c%d_d%d", c, day)
		if not listHas(state and state.StreakPending, key) and not listHas(state and state.StreakClaimed, key) then
			return key
		end
		c += 1
	end
	return string.format("c%d_d%d", c, day)
end

local function copyList(list: any): { string }
	local out = {}
	if type(list) == "table" then
		for _, v in ipairs(list) do
			table.insert(out, v)
		end
	end
	return out
end

function RetentionMath.CopyStreak(state: any): { [string]: any }
	local s = if type(state) == "table" then state else {}
	return {
		StreakDays = int(s.StreakDays), StreakLastDay = int(s.StreakLastDay), StreakBest = int(s.StreakBest),
		StreakGraceDay = int(s.StreakGraceDay), StreakPerk = math.clamp(num(s.StreakPerk, 0), 0, RetentionMath.MaxPerk),
		StreakPending = copyList(s.StreakPending), StreakClaimed = copyList(s.StreakClaimed),
	}
end

-- One check-in on UTC `day`. Returns the new streak fields (a copy; the input is untouched),
-- the event ("same" | "start" | "next" | "grace" | "reset") and the milestone keys it crossed.
-- gap 1: +1 day; gap 2 with the weekly grace free: +1 day and the grace is used; anything
-- else starts again at day 1. Pending rewards survive a reset (they were earned).
function RetentionMath.StreakCheckIn(state: any, day: number, cfg: any?): ({ [string]: any }, string, { string })
	local c = cfg or DEFAULT_STREAK
	local out = RetentionMath.CopyStreak(state)
	local crossed = {}
	local today = int(day)
	local days, last = out.StreakDays, out.StreakLastDay
	local gap = today - last
	if last > 0 and gap <= 0 then
		-- Already in for today (or a clock that went back): nothing changes.
		return out, "same", crossed
	end
	local event
	if days > 0 and last > 0 and gap == 1 then
		out.StreakDays = days + 1
		event = "next"
	elseif days > 0 and last > 0 and gap == 2 and today - out.StreakGraceDay >= num(c.GraceEveryDays, 7) then
		out.StreakDays = days + 1
		out.StreakGraceDay = today
		event = "grace"
	else
		out.StreakDays = 1
		event = if days > 0 then "reset" else "start"
	end
	out.StreakLastDay = today
	out.StreakBest = math.max(out.StreakBest, out.StreakDays)
	if event == "next" or event == "grace" then
		local cycleDay = RetentionMath.CycleDay(out.StreakDays, c)
		if cycleDay == 7 or cycleDay == 14 or cycleDay == 21 then
			local key = RetentionMath.KeyFor(out, RetentionMath.Cycle(out.StreakDays, c), cycleDay)
			table.insert(out.StreakPending, key)
			table.insert(crossed, key)
			-- At most MaxPending waiting: the oldest one goes (6 unclaimed milestones = 6 weeks).
			while #out.StreakPending > math.max(1, num(c.MaxPending, 6)) do
				table.remove(out.StreakPending, 1)
			end
		end
	end
	return out, event, crossed
end

-- What a milestone key pays: cycle 1 the First table (7: perk 0.2 + title, 14: perk 0.4, 21:
-- the Skull Chest + title), later cycles the Repeat table. Nil for a malformed key.
function RetentionMath.MilestoneReward(key: any, cfg: any?): { [string]: any }?
	local c = cfg or DEFAULT_STREAK
	local cycle, day = RetentionMath.ParseKey(key)
	if not cycle or not day then
		return nil
	end
	local milestones = c.Milestones or DEFAULT_STREAK.Milestones
	local source = if cycle == 1 then milestones.First else milestones.Repeat
	local row = source and source[day]
	if type(row) ~= "table" then
		return nil
	end
	return {
		Key = key, Cycle = cycle, Day = day,
		Perk = math.clamp(num(row.Perk, 0), 0, RetentionMath.MaxPerk),
		TitleId = if type(row.TitleId) == "string" then row.TitleId else nil,
		SpinTickets = int(row.SpinTickets),
		SpeedPotionMinutes = int(row.SpeedPotionMinutes),
		WinsPotionMinutes = int(row.WinsPotionMinutes),
	}
end

-- The oldest pending key that still pays something (claims go in the order they were earned).
function RetentionMath.OldestPending(state: any, cfg: any?): string?
	if type(state) ~= "table" or type(state.StreakPending) ~= "table" then
		return nil
	end
	for _, key in ipairs(state.StreakPending) do
		if RetentionMath.MilestoneReward(key, cfg) then
			return key
		end
	end
	return nil
end

-- ---------------------------------------------------------------- multiplier and bars

-- Additive (PLAN §1): 1 + playtime + streak + permanent perk, at most `cap` (3.4 with the perk 0.4).
function RetentionMath.Multiplier(playtime: number, streak: number, perk: number, cap: number?): number
	local total = 1 + math.max(0, num(playtime, 0)) + math.max(0, num(streak, 0)) + math.max(0, num(perk, 0))
	return math.clamp(total, 1, math.max(1, num(cap, 3.4)))
end

-- "x1.4" (one decimal; "x2" never, always "x2.0" so the label does not jump).
function RetentionMath.FormatMultiplier(value: number): string
	return string.format("x%.1f", math.floor(num(value, 1) * 10 + 0.5) / 10)
end

-- The bars fill between the designer's markers, not linearly: `points` = {{value, xScale}, ...}
-- ascending by value; below the first point its x, past the last its x.
function RetentionMath.PiecewiseFill(value: number, points: { { number } }): number
	local v = num(value, 0)
	if #points == 0 then
		return 0
	end
	if v <= points[1][1] then
		return points[1][2]
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if v <= b[1] then
			local span = b[1] - a[1]
			local t = if span > 0 then (v - a[1]) / span else 1
			return a[2] + (b[2] - a[2]) * t
		end
	end
	return points[#points][2]
end

-- ---------------------------------------------------------------- topbar (right side)

-- 2026-09-25 (owner): every game icon sits on the RIGHT of the topbar; the left is Roblox's
-- own (menu, chat, the unibar), which the retention icons ran into. TopbarPlus lays right
-- icons out from the right edge, 48 px in (the player list's button), each icon followed by
-- the gap, in `order` from the left. The group must start after 55 % of the screen so the
-- top centre stays clear. Tried in order: 44 px icons with their labels, without labels, 40
-- px icons with a 4 px gap, then the items that have a fold rank go, lowest rank first and
-- two at least, into one "more" dropdown icon at the group's left end.
RetentionMath.Topbar = { RobloxRight = 48, Share = 0.45, Full = { Size = 44, Gap = 12 }, Compact = { Size = 40, Gap = 4 } }

local function iconWidth(size: number, label: string?): number
	if type(label) ~= "string" or label == "" then
		return size
	end
	-- TopbarPlus: 12 margin + image (0.85 of the height) + 8 gap + text + 12 margin; the text is
	-- 0.45 of the height tall and about 0.6 of that wide per character (Gotham-like).
	return 12 + size * 0.85 + 8 + (utf8.len(label) or #label) * size * 0.45 * 0.6 + 12
end

-- `items` = {{key=..., label=...?, fold=rank?}, ...} in screen order, left to right. Returns
-- {Size, Gap, Labels, Shown = {keys, screen order}, Folded = {keys}, StartX (the group's left
-- edge), Width (the px it takes from the right edge, the 48 included)} for a `viewportX` px
-- wide screen.
function RetentionMath.TopbarRightLayout(viewportX: number, items: { any }): { [string]: any }
	local bar = RetentionMath.Topbar
	local screen = num(viewportX, 0)
	local limit = screen * bar.Share
	local foldable = {}
	for _, item in items do
		if type(item.fold) == "number" then
			table.insert(foldable, item)
		end
	end
	table.sort(foldable, function(a, b)
		return a.fold < b.fold
	end)
	local function layout(mode: any, labels: boolean, foldCount: number): { [string]: any }
		local folding = {}
		for i = 1, foldCount do
			folding[foldable[i].key] = true
		end
		local shown, folded = {}, {}
		local used = bar.RobloxRight
		for _, item in items do
			if folding[item.key] then
				table.insert(folded, item.key)
			else
				table.insert(shown, item.key)
				used += iconWidth(mode.Size, if labels then item.label else nil) + mode.Gap
			end
		end
		if #folded > 0 then
			used += mode.Size + mode.Gap
		end
		return { Size = mode.Size, Gap = mode.Gap, Labels = labels, Shown = shown, Folded = folded, Width = used, StartX = screen - used }
	end
	for _, try in { { bar.Full, true }, { bar.Full, false }, { bar.Compact, false } } do
		local candidate = layout(try[1], try[2], 0)
		if candidate.Width <= limit then
			return candidate
		end
	end
	-- One item alone in the dropdown saves nothing: the "more" icon takes its place.
	if #foldable < 2 then
		return layout(bar.Compact, false, 0)
	end
	for count = 2, #foldable do
		local candidate = layout(bar.Compact, false, count)
		if candidate.Width <= limit then
			return candidate
		end
	end
	return layout(bar.Compact, false, #foldable)
end

-- ---------------------------------------------------------------- words (en/es/pt, else en)

local TEXT = {
	en = {
		StreakDay = "🔥 Day %d streak! %s Speed",
		StreakSaved = "🔥 Streak saved! Day %d, %s Speed",
		StreakRestarted = "Streak restarted: Day 1, %s Speed",
		StreakMilestone = "🎁 Day %d streak reward ready!",
		Playtime10 = "⏱ Playtime Boost: +10% Speed!",
		PlaytimeMax = "⏱ Playtime Boost MAX: +100% Speed!",
		Claimed = "Streak reward claimed!",
		NothingToClaim = "No streak reward to claim yet.",
		ClaimFailed = "Could not claim right now. Try again.",
		Claim = "CLAIM",
		NextDay = "Next day in %s",
		StatusClaimed = "CLAIMED",
		StatusReady = "READY!",
		StatusLocked = "Day %d",
		SpeedBoost = "+%d%% Speed",
		SpeedTimes = "%s Speed",
		Spins = "%d Spins",
		Chest = "Skull Chest",
		Max = "MAX",
	},
	es = {
		StreakDay = "🔥 ¡Racha de %d días! %s Velocidad",
		StreakSaved = "🔥 ¡Racha salvada! Día %d, %s Velocidad",
		StreakRestarted = "Racha reiniciada: Día 1, %s Velocidad",
		StreakMilestone = "🎁 ¡Premio de racha del día %d listo!",
		Playtime10 = "⏱ Bonus de juego: ¡+10% Velocidad!",
		PlaytimeMax = "⏱ Bonus de juego MÁX: ¡+100% Velocidad!",
		Claimed = "¡Premio de racha reclamado!",
		NothingToClaim = "Aún no hay premio de racha.",
		ClaimFailed = "No se pudo reclamar. Inténtalo otra vez.",
		Claim = "RECLAMAR",
		NextDay = "Siguiente día en %s",
		StatusClaimed = "RECLAMADO",
		StatusReady = "¡LISTO!",
		StatusLocked = "Día %d",
		SpeedBoost = "+%d%% Velocidad",
		SpeedTimes = "%s Velocidad",
		Spins = "%d Giros",
		Chest = "Cofre Calavera",
		Max = "MÁX",
	},
	pt = {
		StreakDay = "🔥 Sequência de %d dias! %s Velocidade",
		StreakSaved = "🔥 Sequência salva! Dia %d, %s Velocidade",
		StreakRestarted = "Sequência reiniciada: Dia 1, %s Velocidade",
		StreakMilestone = "🎁 Prêmio da sequência do dia %d pronto!",
		Playtime10 = "⏱ Bônus de jogo: +10% Velocidade!",
		PlaytimeMax = "⏱ Bônus de jogo MÁX: +100% Velocidade!",
		Claimed = "Prêmio da sequência resgatado!",
		NothingToClaim = "Ainda não há prêmio da sequência.",
		ClaimFailed = "Não foi possível resgatar. Tente de novo.",
		Claim = "RESGATAR",
		NextDay = "Próximo dia em %s",
		StatusClaimed = "RESGATADO",
		StatusReady = "PRONTO!",
		StatusLocked = "Dia %d",
		SpeedBoost = "+%d%% Velocidade",
		SpeedTimes = "%s Velocidade",
		Spins = "%d Giros",
		Chest = "Baú Caveira",
		Max = "MÁX",
	},
}
RetentionMath.TextTable = TEXT

function RetentionMath.Text(key: string, lang: string?, ...: any): string
	local words = TEXT[lang or "en"] or TEXT.en
	local pattern = words[key] or TEXT.en[key] or key
	if select("#", ...) == 0 then
		return pattern
	end
	local ok, text = pcall(string.format, pattern, ...)
	return if ok then text else pattern
end

return RetentionMath
