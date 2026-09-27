--!strict
-- QuestCatalog.luau
-- Choose Your Destiny: every day three quests to pick from, each three tasks and a bundle
-- of rewards. A player picks one; its tasks count from that moment; finishing all three
-- pays every reward. A new day brings a new choice.
--
-- The server (Social/QuestService) and the panel (UI/QuestController) read the same
-- quests, so the panel always shows what the server will ask for and pay.
--
-- Metrics are counted on the profile (Data/ProfileReducers.AddQuestProgress):
--   speed     Speed earned running and on treadmills
--   stages    stages cleared
--   wins      Win pads claimed (any stage's Win or x2 pad, and the finish)
--   playtime  seconds played
--   rebirth   rebirths
--
-- The DailyQuests / WeeklyQuests lists below are the first quests. Their claims still
-- work on the profile (ClaimQuest), but the panel offers the destiny quests.

export type Task = { Metric: string, Base: number, SpeedShare: number? }
export type Reward = { Kind: string, Multiple: number?, Amount: number?, Minutes: number?, Share: number? }
export type Path = { Id: string, Title: string, Tasks: { Task }, Rewards: { Reward } }

local QuestCatalog = {}

QuestCatalog.PeriodSeconds = 86400
QuestCatalog.PathsPerDay = 3

-- Image is the game's own cartoon art for the task row (the lightning bolt, the Stage
-- Teleport portal, the Wins trophy, the Time Gifts present, the Rebirth arrows).
QuestCatalog.Metrics = {
	speed = { Icon = "⚡", Image = "rbxassetid://123961542220277", Singular = "Speed", Plural = "Speed", Verb = "Earn" },
	stages = { Icon = "🏁", Image = "rbxassetid://134300317257422", Singular = "Stage", Plural = "Stages", Verb = "Clear" },
	wins = { Icon = "🏆", Image = "rbxassetid://15540211845", Singular = "Win Pad", Plural = "Win Pads", Verb = "Claim" },
	playtime = { Icon = "⏱️", Image = "rbxassetid://127191998618608", Singular = "Minute", Plural = "Minutes", Verb = "Play" },
	rebirth = { Icon = "🔄", Image = "rbxassetid://129578402198506", Singular = "Time", Plural = "Times", Verb = "Rebirth" },
}

QuestCatalog.RewardIcons = {
	Wins = "rbxassetid://15540211845",
	Speed = "rbxassetid://123961542220277",
	SpinTicket = "rbxassetid://81673014203919",
	PotionSpeed = "rbxassetid://71111471194517",
	PotionWins = "rbxassetid://89981527304241",
}

-- The quests a day can offer. Targets grow with the player when they choose: Speed
-- targets with their Speed (SpeedShare of it, never below Base), because Speed grows by
-- orders of magnitude over a playthrough; stages, Win pads and time played with their level
-- (QuestCatalog.LevelFactor). Rewards grow with the level, and Speed rewards with Speed.
QuestCatalog.Paths = {
	{
		Id = "sprinter",
		Title = "Sprinter",
		Tasks = {
			{ Metric = "speed", Base = 250, SpeedShare = 0.5 },
			{ Metric = "stages", Base = 3 },
			{ Metric = "playtime", Base = 180 },
		},
		Rewards = {
			{ Kind = "Wins", Multiple = 3 },
			{ Kind = "Speed", Share = 0.1 },
			{ Kind = "PotionSpeed", Minutes = 15 },
			{ Kind = "SpinTicket", Amount = 1 },
		},
	},
	{
		Id = "champion",
		Title = "Champion",
		Tasks = {
			{ Metric = "wins", Base = 6 },
			{ Metric = "stages", Base = 15 },
			{ Metric = "speed", Base = 200, SpeedShare = 0.3 },
		},
		Rewards = {
			{ Kind = "Wins", Multiple = 8 },
			{ Kind = "Speed", Share = 0.05 },
			{ Kind = "PotionWins", Minutes = 15 },
		},
	},
	{
		Id = "grinder",
		Title = "Grinder",
		Tasks = {
			{ Metric = "playtime", Base = 1200 },
			{ Metric = "speed", Base = 500, SpeedShare = 1 },
			{ Metric = "wins", Base = 3 },
		},
		Rewards = {
			{ Kind = "SpinTicket", Amount = 2 },
			{ Kind = "Speed", Share = 0.15 },
			{ Kind = "PotionSpeed", Minutes = 20 },
			{ Kind = "Wins", Multiple = 4 },
		},
	},
	{
		Id = "reborn",
		Title = "Reborn",
		Tasks = {
			{ Metric = "rebirth", Base = 1 },
			{ Metric = "stages", Base = 20 },
			{ Metric = "playtime", Base = 900 },
		},
		Rewards = {
			{ Kind = "Wins", Multiple = 12 },
			{ Kind = "Speed", Share = 0.2 },
			{ Kind = "SpinTicket", Amount = 2 },
		},
	},
	{
		Id = "explorer",
		Title = "Explorer",
		Tasks = {
			{ Metric = "stages", Base = 25 },
			{ Metric = "wins", Base = 9 },
			{ Metric = "playtime", Base = 900 },
		},
		Rewards = {
			{ Kind = "Wins", Multiple = 10 },
			{ Kind = "PotionWins", Minutes = 20 },
			{ Kind = "SpinTicket", Amount = 1 },
		},
	},
	{
		Id = "marathon",
		Title = "Marathon",
		Tasks = {
			{ Metric = "playtime", Base = 1800 },
			{ Metric = "stages", Base = 30 },
			{ Metric = "speed", Base = 400, SpeedShare = 0.75 },
		},
		Rewards = {
			{ Kind = "Wins", Multiple = 6 },
			{ Kind = "SpinTicket", Amount = 3 },
			{ Kind = "PotionSpeed", Minutes = 15 },
			{ Kind = "PotionWins", Minutes = 15 },
		},
	},
} :: { Path }

local function finite(value: any, fallback: number): number
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return fallback
	end
	return number
end

-- 1, 2 or 5 times a power of ten, rounded up: targets and amounts that read well.
function QuestCatalog.RoundNice(value: number): number
	value = math.max(1, finite(value, 1))
	if value < 10 then
		return math.ceil(value)
	end
	local power = 10 ^ math.floor(math.log10(value))
	for _, step in { 1, 2, 5, 10 } do
		if value <= step * power then
			return step * power
		end
	end
	return 10 * power
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
function QuestCatalog.FormatNumber(value: number): string
	value = math.max(0, finite(value, 0))
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(value) / 3) + 1
	local scaled = value / (1000 ^ (tier - 1))
	-- 999.96K prints as 1000K; carry it into the next suffix instead.
	if scaled >= 999.95 then
		tier += 1
		scaled /= 1000
	end
	if tier > #SUFFIXES then
		return string.format("%.2e", value)
	end
	local text = if scaled >= 100 then string.format("%.0f", scaled) elseif scaled >= 10 then string.format("%.1f", scaled) else string.format("%.2f", scaled)
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. SUFFIXES[tier]
end

-- The three quests of a day, the same for every player and server: a shuffle of the
-- pool seeded by the day (MINSTD, exact in doubles).
function QuestCatalog.PathsFor(period: number): { Path }
	local order = {}
	for index = 1, #QuestCatalog.Paths do
		order[index] = index
	end
	local seed = math.floor(finite(period, 0)) % 2147483646 + 1
	for index = #order, 2, -1 do
		seed = seed * 48271 % 2147483647
		local swap = seed % index + 1
		order[index], order[swap] = order[swap], order[index]
	end
	local paths = {}
	for index = 1, QuestCatalog.PathsPerDay do
		paths[index] = QuestCatalog.Paths[order[index]]
	end
	-- From the next full UTC quest day, always show one short, active path. Keep the
	-- earlier order intact so a saved choice cannot switch to another quest mid-day.
	if period >= 20717 then
		local hasSprinter = false
		for _, path in paths do
			if path.Id == "sprinter" then hasSprinter = true end
		end
		if not hasSprinter then paths[QuestCatalog.PathsPerDay] = QuestCatalog.Paths[1] end
	end
	return paths
end

-- M33 (2026-09-25): the quest day is Shared/QuestPeriod's (08:00 UTC from its cutover, the
-- Daily reward's day), the same function the reducers judge with. The fallback is the same
-- math, only for harnesses that load this file on its own.
local QuestPeriod: any = nil
do
	local ok, mod = pcall(function(): any
		if typeof(script) == "Instance" then
			local module = script.Parent and script.Parent:FindFirstChild("QuestPeriod")
			return if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
		end
		return (require :: any)("./QuestPeriod")
	end)
	if ok and type(mod) == "table" and type(mod.DailyPeriod) == "function" and type(mod.PeriodEnd) == "function" then
		QuestPeriod = mod
	end
end

if QuestPeriod then
	QuestCatalog.PeriodOf = QuestPeriod.DailyPeriod
	QuestCatalog.PeriodEnd = QuestPeriod.PeriodEnd
else
	local CUTOVER, OFFSET = 1790582400, 57600
	function QuestCatalog.PeriodOf(unixTime: number): number
		local t = finite(unixTime, 0)
		return if t >= CUTOVER then math.floor((t + OFFSET) / 86400) else math.floor(t / 86400)
	end
	function QuestCatalog.PeriodEnd(unixTime: number): number
		local t = finite(unixTime, 0)
		if t >= CUTOVER then
			return (math.floor((t + OFFSET) / 86400) + 1) * 86400 - OFFSET
		end
		return math.min((math.floor(t / 86400) + 1) * 86400, CUTOVER)
	end
end

-- How much a day's counts grow with the player's level: 0.6 for a new player (level 1),
-- 1 at level 20, 2 at level 100 and 3 from level 180 on. A missing level counts as 1x.
function QuestCatalog.LevelFactor(level: number?): number
	if level == nil then
		return 1
	end
	local l = math.max(1, math.floor(finite(level, 1)))
	if l <= 20 then
		return 0.6 + 0.4 * (l - 1) / 19
	end
	return math.min(3, 1 + (l - 20) / 80)
end

-- A task's target for a player with `speed` Speed at `level`. Playtime targets are in
-- seconds. Speed targets follow Speed; stages and Win pads follow the level; time played
-- follows it at half the rate (whole minutes); rebirths stay one, since every rebirth
-- asks for more levels than the last.
function QuestCatalog.TargetFor(task: Task, speed: number, level: number?): number
	if task.SpeedShare then
		return math.max(task.Base, QuestCatalog.RoundNice(finite(speed, 0) * task.SpeedShare))
	end
	local factor = QuestCatalog.LevelFactor(level)
	if task.Metric == "stages" then
		return math.max(3, math.floor(task.Base * factor + 0.5))
	elseif task.Metric == "wins" then
		return math.max(1, math.floor(task.Base * factor + 0.5))
	elseif task.Metric == "playtime" then
		return math.max(180, math.floor(task.Base * (1 + (factor - 1) / 2) / 60 + 0.5) * 60)
	end
	return task.Base
end

-- "Earn 5K Speed", "Clear 10 Stages", "Claim 1 Win Pad", "Play 15 Minutes", "Rebirth 1 Time".
function QuestCatalog.TaskText(metric: string, target: number): string
	local info = QuestCatalog.Metrics[metric]
	if not info then
		return ""
	end
	local count = if metric == "playtime" then math.floor(target / 60) else target
	local amount = if metric == "speed" then QuestCatalog.FormatNumber(count) else tostring(math.floor(count))
	local noun = if count == 1 then info.Singular else info.Plural
	return info.Verb .. " " .. amount .. " " .. noun
end

-- "3/10", "1.2K/5K", "4/15 min".
function QuestCatalog.ProgressText(metric: string, progress: number, target: number): string
	if metric == "playtime" then
		return string.format("%d/%d min", math.floor(finite(progress, 0) / 60), math.floor(target / 60))
	end
	return QuestCatalog.FormatNumber(progress) .. "/" .. QuestCatalog.FormatNumber(target)
end

-- What a reward pays a player at `level` with `speed` Speed:
--   Wins        grow with the level, like the Spin Wheel's (1,000 at level 4 and below,
--               250 per level, up to 250,000), times Multiple
--   Speed       Share of the player's Speed, never below 500 per level
--   SpinTicket  1 to 3: Amount, one more from level 75
--   potions     15 to 30 minutes: Minutes, 5 more for every 50 levels
function QuestCatalog.RewardAmount(reward: Reward, level: number, speed: number?): number
	local l = math.max(1, math.floor(finite(level, 1)))
	if reward.Kind == "Wins" then
		local base = math.clamp(l * 250, 1000, 250000)
		return QuestCatalog.RoundNice(base * (reward.Multiple or 1))
	elseif reward.Kind == "Speed" then
		return QuestCatalog.RoundNice(math.max(l * 500, finite(speed, 0) * (reward.Share or 0.1)))
	elseif reward.Kind == "SpinTicket" then
		return math.clamp((reward.Amount or 1) + (if l >= 75 then 1 else 0), 1, 3)
	end
	return math.clamp((reward.Minutes or 15) + 5 * math.floor(l / 50), 15, 30)
end

-- The line under a reward's icon: "26.6K", "x2", "15m".
function QuestCatalog.RewardText(reward: Reward, level: number, speed: number?): string
	local amount = QuestCatalog.RewardAmount(reward, level, speed)
	if reward.Kind == "Wins" or reward.Kind == "Speed" then
		return QuestCatalog.FormatNumber(amount)
	elseif reward.Kind == "SpinTicket" then
		return "x" .. tostring(amount)
	end
	return tostring(amount) .. "m"
end

----------------------------------------------------------------------
-- The first quests (kept for profiles that still hold them)
----------------------------------------------------------------------
export type QuestDefinition = {
	Id: string,
	Title: string,
	Description: string,
	Target: number,
	DisplayTarget: string,
	Unit: string,
	Category: "Daily" | "Weekly",
	RewardType: "Wins" | "PotionSpeed" | "PotionWins" | "PotionBundle" | "SpinTicket",
	RewardValue: number,
	RewardText: string,
	Icon: string,
}

QuestCatalog.DailyQuests = {
	{ Id = "daily_speed", Title = "Speed Grind", Description = "Earn 50,000 Speed in running or treadmills", Target = 50000, DisplayTarget = "50K", Unit = "Speed", Category = "Daily", RewardType = "Wins", RewardValue = 10000, RewardText = "+10,000 Wins", Icon = "rbxassetid://131657973400525" },
	{ Id = "daily_stages", Title = "Stage Runner", Description = "Clear or advance through 20 stages", Target = 20, DisplayTarget = "20", Unit = "Stages", Category = "Daily", RewardType = "Wins", RewardValue = 15000, RewardText = "+15,000 Wins", Icon = "rbxassetid://10734948834" },
	{ Id = "daily_wins", Title = "Winner", Description = "Claim 3 Win pads in any world", Target = 3, DisplayTarget = "3", Unit = "Wins", Category = "Daily", RewardType = "PotionWins", RewardValue = 15, RewardText = "2x Wins Potion (15m)", Icon = "rbxassetid://114699417085635" },
	{ Id = "daily_playtime", Title = "Active Playtime", Description = "Play for 15 minutes in total today", Target = 900, DisplayTarget = "15 min", Unit = "Time", Category = "Daily", RewardType = "PotionSpeed", RewardValue = 15, RewardText = "2x Speed Potion (15m)", Icon = "rbxassetid://10709791437" },
	{ Id = "daily_rebirth", Title = "Rebirth Push", Description = "Perform at least 1 Rebirth", Target = 1, DisplayTarget = "1", Unit = "Rebirths", Category = "Daily", RewardType = "SpinTicket", RewardValue = 1, RewardText = "+1 Spin Ticket", Icon = "rbxassetid://10723374641" },
} :: { QuestDefinition }

QuestCatalog.WeeklyQuests = {
	{ Id = "weekly_speed", Title = "Weekly Speedster", Description = "Accumulate 500,000 total Speed this week", Target = 500000, DisplayTarget = "500K", Unit = "Speed", Category = "Weekly", RewardType = "Wins", RewardValue = 100000, RewardText = "+100,000 Wins", Icon = "rbxassetid://131657973400525" },
	{ Id = "weekly_stages", Title = "Stage Master", Description = "Clear 100 course stages this week", Target = 100, DisplayTarget = "100", Unit = "Stages", Category = "Weekly", RewardType = "PotionBundle", RewardValue = 15, RewardText = "Bundle (2x Speed + 2x Wins 15m)", Icon = "rbxassetid://10734948834" },
	{ Id = "weekly_wins", Title = "Champion", Description = "Claim 25 Win pads in any world", Target = 25, DisplayTarget = "25", Unit = "Wins", Category = "Weekly", RewardType = "SpinTicket", RewardValue = 3, RewardText = "+3 Spin Tickets", Icon = "rbxassetid://10723374641" },
	{ Id = "weekly_playtime", Title = "Dedicated Player", Description = "Play 2 hours total during this week", Target = 7200, DisplayTarget = "2 hours", Unit = "Time", Category = "Weekly", RewardType = "Wins", RewardValue = 250000, RewardText = "+250,000 Wins + Potion", Icon = "rbxassetid://10709791437" },
	{ Id = "weekly_rebirth", Title = "Rebirth Master", Description = "Perform 5 Rebirths this week", Target = 5, DisplayTarget = "5", Unit = "Rebirths", Category = "Weekly", RewardType = "SpinTicket", RewardValue = 5, RewardText = "+5 Spin Tickets & +500K Wins", Icon = "rbxassetid://10723374641" },
} :: { QuestDefinition }

function QuestCatalog.GetDaily(): { QuestDefinition }
	return QuestCatalog.DailyQuests
end

function QuestCatalog.GetWeekly(): { QuestDefinition }
	return QuestCatalog.WeeklyQuests
end

function QuestCatalog.FindQuest(questId: string): QuestDefinition?
	for _, quest in QuestCatalog.DailyQuests do
		if quest.Id == questId then
			return quest
		end
	end
	for _, quest in QuestCatalog.WeeklyQuests do
		if quest.Id == questId then
			return quest
		end
	end
	return nil
end

return QuestCatalog
