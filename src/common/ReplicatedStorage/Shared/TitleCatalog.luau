--!strict
-- ReplicatedStorage/Shared/TitleCatalog.luau (Update 4, 2026-09-25) — every overhead title, pure data.
-- TitleService (server) decides what a player owns and wears; TitlesController (client) draws
-- the designer's "Titles" panel from the same entries; Bootstrap clones the entry's Template
-- from ReplicatedStorage.Titles (Owner/Dev/Tester authored or made by audit/u4_title_templates).
-- Colours are RGB triples (no Color3 here, so Lune tests and the server read the same file).
--
-- Source: "staff" (config ids/usernames, checked on join, never DisplayName), "rank" (live board
-- rank, Board + Top), "marker" (earned once and kept in the profile, U4.Titles.Owned), "vip"
-- (the VIPGamepassOwned attribute). Grantable markers may also be given from the admin panel.
-- Only Staff and #1 titles animate (Style typewriter/shine); everything else is "static" with
-- the Plain template (no particles): phones are render-bound.
local TitleCatalog = {}

export type Entry = {
	Id: string,
	Text: string,
	Tab: string,
	Priority: number,
	Style: string,
	Template: string,
	Colors: { { number } },
	Unlock: { [string]: string },
	Source: string,
	Board: string?,
	Top: number?,
	Need: number?,
	Grantable: boolean?,
	Chat: string?, -- 2026-09-26 (owner): the chat tag colour ("#RRGGBB"); else Colors[1]
}

TitleCatalog.Tabs = { "All", "Staff", "Leaderboards", "Ranked" }
TitleCatalog.Styles = { typewriter = true, shine = true, static = true }
TitleCatalog.Templates = { Owner = true, Dev = true, Tester = true, Gold = true, Plain = true }
TitleCatalog.Boards = { "Speed", "Wins", "Race" }
TitleCatalog.RankTiers = { 1, 5, 10 }
TitleCatalog.MaxIdLength = 32
TitleCatalog.None = "none" -- a preference: wear nothing
TitleCatalog.Auto = "" -- a preference: the best staff title, else nothing

local GOLD = { { 255, 211, 33 }, { 255, 150, 20 } }

local entries: { Entry } = {
	-- Staff: shown automatically (the "" preference picks the highest one).
	{ Id = "owner", Text = "OWNER", Tab = "Staff", Priority = 100, Style = "typewriter", Template = "Owner",
		Colors = GOLD, Source = "staff", Chat = "#FFD700",
		Unlock = { en = "Game owner only", es = "Solo el dueño del juego", pt = "Só o dono do jogo" } },
	{ Id = "developer", Text = "DEV", Tab = "Staff", Priority = 90, Style = "typewriter", Template = "Dev",
		Colors = { { 255, 114, 71 }, { 255, 66, 33 } }, Source = "staff", Chat = "#FF4500",
		Unlock = { en = "Game developers only", es = "Solo desarrolladores", pt = "Só desenvolvedores" } },
	{ Id = "content_creator", Text = "Content Creator", Tab = "Staff", Priority = 80, Style = "shine", Template = "Plain",
		Colors = { { 190, 95, 255 }, { 255, 95, 200 } }, Source = "staff", Grantable = true,
		Unlock = { en = "For our content creators", es = "Para nuestros creadores", pt = "Para nossos criadores" } },
	{ Id = "tester", Text = "Tester", Tab = "Staff", Priority = 70, Style = "shine", Template = "Tester",
		Colors = { { 242, 255, 252 }, { 150, 160, 158 } }, Source = "staff", Chat = "#00E5FF",
		Unlock = { en = "Game testers only", es = "Solo testers", pt = "Só testers" } },

	-- Leaderboards: live, while the rank lasts (rank r owns every tier with Top >= r).
	{ Id = "speed_top1", Text = "#1 SPEEDSTER", Tab = "Leaderboards", Priority = 62, Style = "shine", Template = "Gold",
		Colors = GOLD, Source = "rank", Board = "Speed", Top = 1,
		Unlock = { en = "Be #1 on the Speed board", es = "Sé #1 en el tablero de Velocidad", pt = "Seja #1 no placar de Velocidade" } },
	{ Id = "wins_top1", Text = "#1 WINNER", Tab = "Leaderboards", Priority = 61, Style = "shine", Template = "Gold",
		Colors = GOLD, Source = "rank", Board = "Wins", Top = 1,
		Unlock = { en = "Be #1 on the Wins board", es = "Sé #1 en el tablero de Victorias", pt = "Seja #1 no placar de Vitórias" } },
	{ Id = "race_top1", Text = "FASTEST RACER", Tab = "Leaderboards", Priority = 60, Style = "shine", Template = "Gold",
		Colors = GOLD, Source = "rank", Board = "Race", Top = 1,
		Unlock = { en = "Be #1 on the Fastest Racers board", es = "Sé #1 en Corredores más rápidos", pt = "Seja #1 em Corredores mais rápidos" } },
	{ Id = "speed_top5", Text = "Top 5 Speed", Tab = "Leaderboards", Priority = 52, Style = "static", Template = "Plain",
		Colors = { { 0, 210, 255 }, { 5, 92, 250 } }, Source = "rank", Board = "Speed", Top = 5,
		Unlock = { en = "Reach Top 5 Speed", es = "Llega al Top 5 de Velocidad", pt = "Chegue ao Top 5 de Velocidade" } },
	{ Id = "wins_top5", Text = "Top 5 Wins", Tab = "Leaderboards", Priority = 51, Style = "static", Template = "Plain",
		Colors = { { 255, 224, 38 }, { 255, 158, 4 } }, Source = "rank", Board = "Wins", Top = 5,
		Unlock = { en = "Reach Top 5 Wins", es = "Llega al Top 5 de Victorias", pt = "Chegue ao Top 5 de Vitórias" } },
	{ Id = "race_top5", Text = "Top 5 Racer", Tab = "Leaderboards", Priority = 50, Style = "static", Template = "Plain",
		Colors = { { 0, 190, 235 }, { 190, 95, 255 } }, Source = "rank", Board = "Race", Top = 5,
		Unlock = { en = "Reach Top 5 Fastest Racers", es = "Llega al Top 5 de Corredores", pt = "Chegue ao Top 5 de Corredores" } },
	{ Id = "speed_top10", Text = "Top 10 Speed", Tab = "Leaderboards", Priority = 42, Style = "static", Template = "Plain",
		Colors = { { 0, 210, 255 }, { 5, 92, 250 } }, Source = "rank", Board = "Speed", Top = 10,
		Unlock = { en = "Reach Top 10 Speed", es = "Llega al Top 10 de Velocidad", pt = "Chegue ao Top 10 de Velocidade" } },
	{ Id = "wins_top10", Text = "Top 10 Wins", Tab = "Leaderboards", Priority = 41, Style = "static", Template = "Plain",
		Colors = { { 255, 224, 38 }, { 255, 158, 4 } }, Source = "rank", Board = "Wins", Top = 10,
		Unlock = { en = "Reach Top 10 Wins", es = "Llega al Top 10 de Victorias", pt = "Chegue ao Top 10 de Vitórias" } },
	{ Id = "race_top10", Text = "Top 10 Racer", Tab = "Leaderboards", Priority = 40, Style = "static", Template = "Plain",
		Colors = { { 0, 190, 235 }, { 190, 95, 255 } }, Source = "rank", Board = "Race", Top = 10,
		Unlock = { en = "Reach Top 10 Fastest Racers", es = "Llega al Top 10 de Corredores", pt = "Chegue ao Top 10 de Corredores" } },

	-- Ranked: earned in races, kept forever (the race server grants them in its reward Commit).
	-- The legend keeps the Gold template but stays static: only Staff and #1 titles animate.
	{ Id = "race_legend", Text = "Speed Legend", Tab = "Ranked", Priority = 35, Style = "static", Template = "Gold",
		Colors = GOLD, Source = "marker", Need = 100,
		Unlock = { en = "Win 100 races", es = "Gana 100 carreras", pt = "Vença 100 corridas" } },
	{ Id = "race_champion", Text = "Race Champion", Tab = "Ranked", Priority = 30, Style = "static", Template = "Plain",
		Colors = { { 190, 95, 255 }, { 120, 60, 255 } }, Source = "marker", Need = 25,
		Unlock = { en = "Win 25 races", es = "Gana 25 carreras", pt = "Vença 25 corridas" } },
	{ Id = "race_winner", Text = "Race Winner", Tab = "Ranked", Priority = 25, Style = "static", Template = "Plain",
		Colors = { { 120, 230, 255 }, { 0, 160, 255 } }, Source = "marker", Need = 1,
		Unlock = { en = "Win a race", es = "Gana una carrera", pt = "Vença uma corrida" } },
	{ Id = "lightning_start", Text = "Lightning Start", Tab = "Ranked", Priority = 20, Style = "static", Template = "Plain",
		Colors = { { 255, 240, 140 }, { 255, 200, 40 } }, Source = "marker", Need = 10,
		Unlock = { en = "Get 10 perfect race starts", es = "Consigue 10 salidas perfectas", pt = "Faça 10 largadas perfeitas" } },

	-- All: streak, community and VIP.
	{ Id = "streak_21", Text = "Streak Legend", Tab = "All", Priority = 33, Style = "static", Template = "Gold",
		Colors = GOLD, Source = "marker", Need = 21,
		Unlock = { en = "Reach a 21-day streak", es = "Llega a una racha de 21 días", pt = "Alcance uma sequência de 21 dias" } },
	{ Id = "streak_7", Text = "Loyal Runner", Tab = "All", Priority = 15, Style = "static", Template = "Plain",
		Colors = { { 255, 150, 60 }, { 255, 80, 40 } }, Source = "marker", Need = 7,
		Unlock = { en = "Reach a 7-day streak", es = "Llega a una racha de 7 días", pt = "Alcance uma sequência de 7 dias" } },
	{ Id = "vip", Text = "VIP", Tab = "All", Priority = 12, Style = "static", Template = "Plain",
		Colors = { { 255, 211, 33 }, { 255, 170, 0 } }, Source = "vip", Need = 1, Chat = "#FFD700",
		Unlock = { en = "Own the VIP pass", es = "Ten el pase VIP", pt = "Tenha o passe VIP" } },
	{ Id = "member", Text = "Member", Tab = "All", Priority = 10, Style = "static", Template = "Plain",
		Colors = { { 90, 255, 120 }, { 30, 190, 80 } }, Source = "marker", Grantable = true, Need = 1,
		Unlock = { en = "Claim the Community reward", es = "Reclama la recompensa de Comunidad", pt = "Resgate a recompensa da Comunidade" } },
}

TitleCatalog.Entries = entries
TitleCatalog.ById = {} :: { [string]: Entry }
for _, entry in entries do
	TitleCatalog.ById[entry.Id] = entry
end

-- "you are #57" and friends, per language (fallback en).
TitleCatalog.Words = {
	en = { YouAre = "you are #%d", Unranked = "not ranked yet", Progress = "%d/%d", Equipped = "Equipped",
		Equip = "Equip", Locked = "Locked", None = "None", NoTitle = "No title above your head", Header = "Titles",
		Tabs = { All = "All", Staff = "Staff", Leaderboards = "Leaderboards", Ranked = "Ranked" } },
	es = { YouAre = "eres #%d", Unranked = "aún sin puesto", Progress = "%d/%d", Equipped = "Puesto",
		Equip = "Equipar", Locked = "Bloqueado", None = "Ninguno", NoTitle = "Sin título sobre tu cabeza", Header = "Títulos",
		Tabs = { All = "Todos", Staff = "Staff", Leaderboards = "Tableros", Ranked = "Carreras" } },
	pt = { YouAre = "você é #%d", Unranked = "ainda sem posição", Progress = "%d/%d", Equipped = "Usando",
		Equip = "Equipar", Locked = "Bloqueado", None = "Nenhum", NoTitle = "Sem título sobre a cabeça", Header = "Títulos",
		Tabs = { All = "Todos", Staff = "Equipe", Leaderboards = "Placares", Ranked = "Corridas" } },
}

function TitleCatalog.IsValidId(id: any): boolean
	return type(id) == "string" and #id <= TitleCatalog.MaxIdLength and string.match(id, "^[a-z0-9_]*$") ~= nil
end

-- A preference is "" (auto), "none", or any well-formed id (it may name a title not owned now).
function TitleCatalog.IsValidPreference(pref: any): boolean
	return TitleCatalog.IsValidId(pref)
end

-- Ids kept in the profile (U4.Titles.Owned): earned once, kept.
function TitleCatalog.IsMarker(id: any): boolean
	local entry = type(id) == "string" and TitleCatalog.ById[id] or nil
	return entry ~= nil and (entry.Source == "marker" or entry.Grantable == true)
end

function TitleCatalog.IsGrantable(id: any): boolean
	local entry = type(id) == "string" and TitleCatalog.ById[id] or nil
	return entry ~= nil and entry.Grantable == true
end

-- 2026-09-26 (owner): an admin may give ANY catalog title (staff and rank ones included) from the
-- admin panel (TitleService.AdminGrant, profile command U4.Titles.AdminGrant). Normal grants
-- (races, streaks, community) stay limited to IsMarker.
function TitleCatalog.IsAdminGrantable(id: any): boolean
	return type(id) == "string" and TitleCatalog.ById[id] ~= nil
end

-- Chat tags ------------------------------------------------------------------------------------
-- 2026-09-26 (owner): the chat shows the title the player WEARS (EquippedTitle, the Titles
-- panel's choice), never a guess from the staff lists: an owner who is also DEV and picks OWNER
-- shows [OWNER]. UI/VipChatTag (TextChatService.OnIncomingMessage) builds the prefix from here.
local RICH_ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }

function TitleCatalog.EscapeRichText(text: any): string
	return (string.gsub(tostring(text or ""), "[&<>\"']", RICH_ESCAPES))
end

local function channel(value: any): number
	local n = tonumber(value) or 255
	if n ~= n then
		n = 255
	end
	return math.clamp(math.floor(n + 0.5), 0, 255)
end

-- "#RRGGBB" for an entry's chat tag: its Chat colour, else its first catalog colour.
function TitleCatalog.ChatHex(entry: Entry): string
	if type(entry.Chat) == "string" and string.match(entry.Chat, "^#%x%x%x%x%x%x$") then
		return string.upper(entry.Chat)
	end
	local c = entry.Colors[1] or { 255, 255, 255 }
	return string.format("#%02X%02X%02X", channel(c[1]), channel(c[2]), channel(c[3]))
end

-- '<font color="#FFD700"><b>[OWNER]</b></font>' for a catalog id, nil for anything else.
function TitleCatalog.ChatTag(id: any): string?
	local entry = type(id) == "string" and TitleCatalog.ById[id] or nil
	if not entry then
		return nil
	end
	return '<font color="' .. TitleCatalog.ChatHex(entry) .. '"><b>[' .. TitleCatalog.EscapeRichText(entry.Text) .. ']</b></font>'
end

-- The whole chat prefix for a speaker (with its trailing space, or ""): the worn title; with
-- nothing worn, "none" chosen shows nothing and auto ("" / a title not owned now) keeps the old
-- [VIP] tag of VIP pass owners.
function TitleCatalog.ChatPrefix(equipped: any, preference: any, isVip: any): string
	if type(equipped) == "string" and equipped ~= "" then
		local tag = TitleCatalog.ChatTag(equipped)
		if tag then
			return tag .. " "
		end
	end
	if preference == TitleCatalog.None then
		return ""
	end
	if isVip == true then
		local tag = TitleCatalog.ChatTag("vip")
		return if tag then tag .. " " else ""
	end
	return ""
end

-- The smallest tier a rank reaches (1, 5, 10), or nil when it reaches none.
function TitleCatalog.TierFor(rank: any): number?
	local r = tonumber(rank)
	if not r or r < 1 or r ~= r then
		return nil
	end
	for _, top in TitleCatalog.RankTiers do
		if r <= top then
			return top
		end
	end
	return nil
end

-- The rank titles a board rank owns: rank 3 on Speed owns speed_top5 and speed_top10.
function TitleCatalog.RankTitles(board: string, rank: any): { string }
	local out = {}
	local r = tonumber(rank)
	if not r or r < 1 then
		return out
	end
	for _, entry in entries do
		if entry.Source == "rank" and entry.Board == board and (entry.Top :: number) >= r then
			table.insert(out, entry.Id)
		end
	end
	return out
end

-- Staff titles from the Update4Config.Titles lists. `who` = { UserId, Name, IsGameOwner }; Name is
-- player.Name (unique), never the DisplayName, so nobody can pose as staff by renaming.
function TitleCatalog.StaffTitles(who: { UserId: number?, Name: string?, IsGameOwner: boolean? }, titlesConfig: any): { [string]: boolean }
	local out = {}
	local config = if type(titlesConfig) == "table" then titlesConfig else {}
	local userId = tonumber(who.UserId) or 0
	local name = if type(who.Name) == "string" then string.lower(who.Name) else ""
	local function listed(list: any, key: any): boolean
		return type(list) == "table" and key ~= nil and list[key] == true
	end
	if who.IsGameOwner == true or listed(config.OwnerUserIds, userId) then
		out.owner = true
	end
	if listed(config.DeveloperUserIds, userId) then
		out.developer = true
	end
	if listed(config.ContentCreatorUserIds, userId) then
		out.content_creator = true
	end
	if name ~= "" and listed(config.TesterUsernames, name) then
		out.tester = true
	end
	return out
end

-- The title to wear: "none" -> nothing; an owned id -> it; otherwise (auto, or an id not owned
-- now) the highest-priority owned Staff title, else nothing. The preference itself is kept, so
-- a rank title comes back on its own when the rank does.
function TitleCatalog.Resolve(pref: any, owned: { [string]: boolean }): string?
	if pref == TitleCatalog.None then
		return nil
	end
	if type(pref) == "string" and pref ~= "" and owned[pref] == true and TitleCatalog.ById[pref] then
		return pref
	end
	local best, bestPriority = nil, -math.huge
	for id in owned do
		local entry = TitleCatalog.ById[id]
		if entry and entry.Tab == "Staff" and entry.Priority > bestPriority then
			best, bestPriority = id, entry.Priority
		end
	end
	return best
end

-- Panel order: the equipped one, then owned by Priority, then locked by Priority.
function TitleCatalog.Sorted(owned: { [string]: boolean }, equipped: string?, tab: string?): { Entry }
	local list = {}
	for _, entry in entries do
		if tab == nil or tab == "All" or entry.Tab == tab then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local ea, eb = a.Id == equipped, b.Id == equipped
		if ea ~= eb then
			return ea
		end
		local oa, ob = owned[a.Id] == true, owned[b.Id] == true
		if oa ~= ob then
			return oa
		end
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.Id < b.Id
	end)
	return list
end

function TitleCatalog.Language(lang: any): string
	return if type(lang) == "string" and TitleCatalog.Words[lang] then lang else "en"
end

-- The unlock line with live numbers: "Reach Top 10 Speed (you are #57)", "Win 25 races (3/25)".
-- progress = { Have, Need } from TitlesUpdate (Have = the rank for rank titles, 0 = unranked).
function TitleCatalog.UnlockText(entry: Entry, lang: any, progress: any): string
	local language = TitleCatalog.Language(lang)
	local words = TitleCatalog.Words[language]
	local text = entry.Unlock[language] or entry.Unlock.en
	if type(progress) ~= "table" then
		return text
	end
	local have, need = tonumber(progress.Have), tonumber(progress.Need)
	if entry.Source == "rank" then
		if have and have >= 1 then
			return text .. " (" .. string.format(words.YouAre, math.floor(have)) .. ")"
		end
		return text .. " (" .. words.Unranked .. ")"
	end
	if have and need and need > 1 then
		return text .. " (" .. string.format(words.Progress, math.min(math.floor(have), math.floor(need)), math.floor(need)) .. ")"
	end
	return text
end

return TitleCatalog
