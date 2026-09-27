-- Services/Titles/TitleService.luau (Update 4, 2026-09-25)
-- Who owns which overhead title, and which one each player wears.
--   owned = staff (Update4Config.Titles lists by UserId / player.Name, and the game creator;
--           checked on join, never the DisplayName) + live board ranks (Speed/Wins/Race top
--           1/5/10, fed by GlobalLeaderboards) + earned markers (profile U4.Titles.Owned) + VIP.
--   worn  = TitleCatalog.Resolve(preference, owned): "" = the best staff title (today's automatic
--           DEV/Tester), "none" = nothing, an id = that title while owned. The preference is kept
--           when a rank title is lost, so it comes back with the rank.
-- Publishes the player attributes EquippedTitle / TitlePreference / TitlesNewCount (Bootstrap
-- re-attaches the head title on EquippedTitle) and pushes TitlesUpdate only when something the
-- panel shows changed. The preference is a volatile profile write (DataService.ApplyVolatile):
-- no DataStore request per click; the autosave and the release keep it.
--
-- The module never touches `game` until Configure/Start (Lune tests inject stubs); SetBoardRanks
-- works before Start (GlobalLeaderboards may report first) and only refreshes started players.
local TitleService = {}

local BOARDS = { Speed = true, Wins = true, Race = true }
local RANK_KEEP = 100 -- ranks kept per board for the "you are #57" hints (the boards show 100)
local GRANT_PENDING_RETRIES = 5

local deps = nil -- { Players, DataService, FunnelAnalytics, U4, Catalog, UpdateRemote, ToastRemote,
--                   IsGameOwner(player) -> bool, Color3, wait(seconds), spawn(fn, ...),
--                   clock() (optional, os.clock), delay(seconds, fn) (optional, task.delay) }
local started = false

local boardRanks = { Speed = {}, Wins = {}, Race = {} } -- [boardId][userId] = rank
-- Per-player state in plain tables, emptied by PlayerRemoving (2026-09-25 review: weak Instance
-- keys can drop an entry while the player is still in game, which lost the notice count).
-- Writes after a yield check inGame first, so a player who left mid-call is not kept.
local staffByPlayer = {} -- [player] = { [id] = true }
local prefByPlayer = {} -- [player] = pref (latest known)
local newCountByPlayer = {}
local sentKeyByPlayer = {} -- last TitlesUpdate signature
local openedByPlayer = {} -- asked "Get" this session
local openedAtByPlayer = {} -- os.clock() of the last Titles_Opened funnel session
local OPEN_FUNNEL_COOLDOWN = 10 -- a "Get" spammed through the 0.3 s guard is one funnel session
-- Earned titles seen at the last refresh. A marker that appears later (granted here, or by the
-- race / streak / community Commit that then calls Refresh) counts for the notice and toasts once.
local knownMarkersByPlayer = {}
local equippedAtByPlayer = {} -- clock of the last accepted Equip
local EQUIP_COOLDOWN = 1
-- 2026-09-26 (owner): a choice made inside the cooldown is kept and applied when it ends (the
-- latest one wins) instead of being dropped, which left the old title on (DEV -> OWNER -> DEV
-- tapped quickly used to stay on whatever was accepted first).
local pendingPrefByPlayer = {}

local function isOn(): boolean
	local U4 = deps and deps.U4
	if not U4 or type(U4.IsOn) ~= "function" then
		return false
	end
	local ok, on = pcall(U4.IsOn, "Titles")
	return ok and on == true
end

local function inGame(player): boolean
	if not deps or typeof(player) ~= "Instance" and type(player) ~= "table" then
		return false
	end
	local ok, parent = pcall(function()
		return player.Parent
	end)
	return ok and parent ~= nil
end

local function setAttribute(player, name: string, value: any)
	pcall(function()
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end)
end

-- The live profile's U4 field (nil when the data is not loaded).
local function profileOf(player): any
	if not deps or not deps.DataService then
		return nil, nil
	end
	local ok, handle = pcall(deps.DataService.GetHandle, player.UserId)
	if not ok or not handle then
		return nil, nil
	end
	local okInspect, result = pcall(deps.DataService.Inspect, handle)
	if not okInspect or type(result) ~= "table" or not result.ok or type(result.value) ~= "table" then
		return nil, handle
	end
	return result.value.profile, handle
end

local function titlesStateOf(profile: any): any
	local u4 = type(profile) == "table" and profile.U4 or nil
	local titles = type(u4) == "table" and u4.Titles or nil
	return if type(titles) == "table" then titles else nil
end

-- 2026-09-26 (owner): the profile list (U4.Titles.Owned) holds earned markers and, since the
-- admin panel can give ANY title (AdminGrant), staff and rank ids too: every catalog id in it counts.
local function keptInProfile(id: any): boolean
	return type(id) == "string" and deps.Catalog.ById[id] ~= nil
end

-- Staff titles, worked out once per join (the group rank check may yield).
function TitleService.ComputeStaff(player): { [string]: boolean }
	local isOwner = false
	if deps and type(deps.IsGameOwner) == "function" then
		local ok, result = pcall(deps.IsGameOwner, player)
		isOwner = ok and result == true
	end
	local staff = deps.Catalog.StaffTitles({ UserId = player.UserId, Name = player.Name, IsGameOwner = isOwner },
		deps.U4 and deps.U4.Titles)
	if inGame(player) then -- the group rank check yields; the player may have left meanwhile
		staffByPlayer[player] = staff
	end
	return staff
end

function TitleService.GetRank(boardId: string, userId: number): number?
	local ranks = boardRanks[boardId]
	return ranks and ranks[userId] or nil
end

-- Everything the player owns right now: { [id] = true }. `profile` saves a second Inspect.
function TitleService.GetOwned(player, profile: any?): { [string]: boolean }
	local owned = {}
	if not deps then
		return owned
	end
	local Catalog = deps.Catalog
	for id in staffByPlayer[player] or {} do
		owned[id] = true
	end
	for boardId in BOARDS do
		for _, id in Catalog.RankTitles(boardId, TitleService.GetRank(boardId, player.UserId)) do
			owned[id] = true
		end
	end
	local titles = titlesStateOf(profile or (profileOf(player)))
	if titles and type(titles.Owned) == "table" then
		for _, id in ipairs(titles.Owned) do
			if keptInProfile(id) then
				owned[id] = true
			end
		end
	end
	local okVip, vip = pcall(function()
		return player:GetAttribute("VIPGamepassOwned")
	end)
	if okVip and vip == true then
		owned.vip = true
	end
	return owned
end

-- The saved preference, read once from the profile (then kept here: Equip updates both).
local function preferenceOf(player, profile: any): string
	local cached = prefByPlayer[player]
	if type(cached) == "string" then
		return cached
	end
	local titles = titlesStateOf(profile)
	if not titles then
		return "" -- not loaded yet: auto, and read again next time
	end
	local pref = if deps.Catalog.IsValidPreference(titles.Pref) then titles.Pref else ""
	prefByPlayer[player] = pref
	return pref
end

-- { [id] = { Have, Need } } for the unlock hints.
local function progressOf(player, profile: any): { [string]: { Have: number, Need: number } }
	local progress = {}
	local u4 = type(profile) == "table" and type(profile.U4) == "table" and profile.U4 or {}
	local race = type(u4.Race) == "table" and u4.Race or {}
	local retention = type(u4.Retention) == "table" and u4.Retention or {}
	local function attribute(name: string): number
		local ok, value = pcall(function()
			return player:GetAttribute(name)
		end)
		return if ok then tonumber(value) or 0 else 0
	end
	local wins = math.max(tonumber(race.Wins) or 0, attribute("RaceWins"))
	local perfects = tonumber(race.Perfects) or 0
	local streak = math.max(tonumber(retention.StreakBest) or 0, tonumber(retention.StreakDays) or 0, attribute("StreakDays"))
	for _, entry in deps.Catalog.Entries do
		if entry.Source == "rank" then
			progress[entry.Id] = { Have = TitleService.GetRank(entry.Board, player.UserId) or 0, Need = entry.Top }
		elseif entry.Id == "race_winner" or entry.Id == "race_champion" or entry.Id == "race_legend" then
			progress[entry.Id] = { Have = wins, Need = entry.Need }
		elseif entry.Id == "lightning_start" then
			progress[entry.Id] = { Have = perfects, Need = entry.Need }
		elseif entry.Id == "streak_7" or entry.Id == "streak_21" then
			progress[entry.Id] = { Have = streak, Need = entry.Need }
		end
	end
	return progress
end

-- `profile` (optional) saves an Inspect: each one deep-copies the whole profile.
function TitleService.BuildPayload(player, profile: any?): { [string]: any }
	if profile == nil then
		profile = profileOf(player)
	end
	local owned = TitleService.GetOwned(player, profile or {})
	local pref = preferenceOf(player, profile)
	local equipped = deps.Catalog.Resolve(pref, owned) or ""
	local ownedList = {}
	for id in owned do
		table.insert(ownedList, id)
	end
	table.sort(ownedList)
	return {
		Owned = ownedList,
		Equipped = equipped,
		Preference = pref,
		Ranks = {
			Speed = TitleService.GetRank("Speed", player.UserId) or 0,
			Wins = TitleService.GetRank("Wins", player.UserId) or 0,
			Race = TitleService.GetRank("Race", player.UserId) or 0,
		},
		Progress = progressOf(player, profile),
		New = newCountByPlayer[player] or 0,
	}
end

local function signature(payload: any): string
	local ranks = payload.Ranks
	return table.concat(payload.Owned, ",") .. "|" .. payload.Equipped .. "|" .. payload.Preference .. "|"
		.. ranks.Speed .. "," .. ranks.Wins .. "," .. ranks.Race .. "|" .. payload.New
end

local function send(player, payload, force: boolean?)
	local key = signature(payload)
	if not force and sentKeyByPlayer[player] == key then
		return false
	end
	sentKeyByPlayer[player] = key
	if deps.UpdateRemote then
		pcall(function()
			deps.UpdateRemote:FireClient(player, payload)
		end)
	end
	return true
end

-- Recomputes and publishes the player's titles. Safe to call any time (a leaving player or one
-- whose data is not loaded yet is skipped); `force` resends the panel payload, `quiet` sends none
-- (the caller answers the panel itself). `knownProfile` (optional) is a profile the caller just
-- read, which saves an Inspect (each one deep-copies the whole profile).
function TitleService.Refresh(player, force: boolean?, quiet: boolean?, knownProfile: any?)
	if not deps or not inGame(player) then
		return nil
	end
	if not isOn() then
		-- Feature off: empty attributes, Bootstrap falls back to its Dev/Tester parts.
		setAttribute(player, "EquippedTitle", nil)
		setAttribute(player, "TitlePreference", nil)
		setAttribute(player, "TitlesNewCount", nil)
		return nil
	end
	if staffByPlayer[player] == nil then
		TitleService.ComputeStaff(player)
		if not inGame(player) then
			return nil -- left during the group rank check
		end
	end
	local profile = knownProfile or profileOf(player)
	local titles = titlesStateOf(profile)
	if titles and type(titles.Owned) == "table" then
		local current = {}
		for _, id in ipairs(titles.Owned) do
			if keptInProfile(id) then
				current[id] = true
			end
		end
		local known = knownMarkersByPlayer[player]
		if known then
			for id in current do
				if not known[id] then
					newCountByPlayer[player] = (newCountByPlayer[player] or 0) + 1
					local entry = deps.Catalog.ById[id]
					if deps.ToastRemote and entry then
						pcall(function()
							deps.ToastRemote:FireClient(player, {
								Type = "Retention",
								Message = "New title: " .. entry.Text .. "! Equip it in Titles",
							})
						end)
					end
				end
			end
		end
		knownMarkersByPlayer[player] = current
	end
	local payload = TitleService.BuildPayload(player, profile)
	setAttribute(player, "TitlePreference", payload.Preference)
	setAttribute(player, "TitlesNewCount", payload.New)
	setAttribute(player, "EquippedTitle", payload.Equipped)
	if (openedByPlayer[player] or force) and not quiet then
		send(player, payload, force)
	end
	return payload
end

-- Answers the panel after an action, with its message. `built` is a payload the action already
-- computed (Equip returns its Refresh), so the answer needs no second profile read.
function TitleService.Push(player, message: string?, success: boolean?, built: any?)
	if not deps or not inGame(player) or not isOn() then
		return nil
	end
	local payload = if type(built) == "table" then built else TitleService.BuildPayload(player)
	payload.Message = message
	payload.Success = success
	send(player, payload, true)
	return payload
end

function TitleService.SetToastRemote(remote)
	if deps then
		deps.ToastRemote = remote
	end
end

-- Board ranks from GlobalLeaderboards ("Speed" | "Wins" | "Race", user ids best first). Only the
-- players whose tier (1/5/10/none) changed on this server are refreshed.
function TitleService.SetBoardRanks(boardId: any, orderedUserIds: any)
	if not BOARDS[boardId] or type(orderedUserIds) ~= "table" then
		return false
	end
	local before = boardRanks[boardId]
	local after = {}
	for index, userId in ipairs(orderedUserIds) do
		if index > RANK_KEEP then
			break
		end
		local id = tonumber(userId)
		if id and after[id] == nil then
			after[id] = index
		end
	end
	boardRanks[boardId] = after
	if not started or not deps then
		return true
	end
	local Catalog = deps.Catalog
	for _, player in deps.Players:GetPlayers() do
		local old, new = before[player.UserId], after[player.UserId]
		if Catalog.TierFor(old) ~= Catalog.TierFor(new) then
			TitleService.Refresh(player)
		elseif old ~= new and openedByPlayer[player] then
			TitleService.Refresh(player) -- the open panel's "you are #N" hint
		end
	end
	return true
end

local function commit(player, operationId: string, commands: { any }): string
	local _, handle = profileOf(player)
	if not handle then
		return "NoSession"
	end
	for _ = 1, GRANT_PENDING_RETRIES do
		local ok, result = pcall(deps.DataService.Commit, handle, {
			operationId = operationId,
			fingerprint = operationId,
			commands = commands,
		})
		local kind = if ok and type(result) == "table" then result.kind else "Error"
		if kind ~= "Pending" then
			return kind
		end
		if deps.wait then
			deps.wait(1)
		end
	end
	return "Pending"
end

local function ownsMarker(player, id: string): boolean
	local titles = titlesStateOf((profileOf(player)))
	return titles ~= nil and type(titles.Owned) == "table" and table.find(titles.Owned, id) ~= nil
end

-- Grants an earned title (catalog markers only): one Commit, operation "u4title:<id>". Returns
-- true when the title is owned afterwards.
function TitleService.Grant(player, id: any, source: any): boolean
	if not deps or not inGame(player) or not isOn() or not deps.Catalog.IsMarker(id) then
		return false
	end
	if knownMarkersByPlayer[player] == nil then
		TitleService.Refresh(player) -- what is already owned is not "new"
	end
	if ownsMarker(player, id) then
		TitleService.Refresh(player)
		return true
	end
	local kind = commit(player, "u4title:" .. id, { { kind = "U4.Titles.Grant", id = id } })
	if kind == "AlreadyCommitted" and not ownsMarker(player, id) then
		-- Granted, revoked by an admin, granted again: the old operation id is spent.
		kind = commit(player, "u4title:" .. id .. ":" .. tostring(os.time()), { { kind = "U4.Titles.Grant", id = id } })
	end
	if kind ~= "Committed" and kind ~= "AlreadyCommitted" then
		return false
	end
	TitleService.Refresh(player) -- counts the notice and sends the toast
	return true
end

-- 2026-09-26 (owner): the admin panel gives ANY catalog title (OWNER, DEV, #1 SPEEDSTER, ...) to
-- anyone: one Commit of U4.Titles.AdminGrant (a fresh operation id each time, so a title given,
-- taken and given again saves again). Kept in the profile like an earned title, so it lasts
-- across servers; the target is refreshed at once (attributes -> overhead and chat, the toast,
-- an open Titles panel). Returns ok, message.
function TitleService.AdminGrant(player, id: any, _by: any): (boolean, string)
	if not deps or not inGame(player) or not isOn() then
		return false, "Titles are off"
	end
	if not deps.Catalog.IsAdminGrantable(id) then
		return false, "Unknown title"
	end
	if knownMarkersByPlayer[player] == nil then
		TitleService.Refresh(player) -- what is already owned is not "new"
	end
	if ownsMarker(player, id) then
		TitleService.Refresh(player)
		return true, "already had it"
	end
	local operation = "u4titleadmin:" .. id .. ":" .. tostring(os.time()) .. ":" .. tostring(math.random(1, 1e6))
	local kind = commit(player, operation, { { kind = "U4.Titles.AdminGrant", id = id } })
	if kind ~= "Committed" and kind ~= "AlreadyCommitted" then
		return false, if kind == "NoSession" then "data not loaded" else "could not save (" .. tostring(kind) .. ")"
	end
	TitleService.Refresh(player) -- counts the notice and sends the toast
	if not ownsMarker(player, id) then
		return false, "their title list is full"
	end
	return true, "granted"
end

-- Admin: removes a title kept in the profile (earned or given by an admin; any catalog id since
-- 2026-09-26). Returns ok, stillOwned: a staff title from the config lists, a live board rank or
-- the VIP pass still own the title after its profile copy is gone.
function TitleService.Revoke(player, id: any): (boolean, boolean)
	if not deps or not inGame(player) or not deps.Catalog.IsAdminGrantable(id) then
		return false, false
	end
	local operation = "u4titlerevoke:" .. id .. ":" .. tostring(os.time()) .. ":" .. tostring(math.random(1, 1e6))
	local kind = commit(player, operation, { { kind = "U4.Titles.Revoke", id = id } })
	TitleService.Refresh(player)
	local stillOwned = isOn() and TitleService.GetOwned(player)[id] == true
	return kind == "Committed" or kind == "AlreadyCommitted", stillOwned
end

-- The player's choice: "" (auto), "none" or a title they own now. Volatile write, no DataStore
-- request. Returns ok, message, payload (the refreshed panel payload when ok).
-- 2026-09-25 (final fix): one profile read per Equip (it used to take five full copies), and at
-- most one Equip per EQUIP_COOLDOWN: each change re-clones the head title for every client.
function TitleService.Equip(player, pref: any): (boolean, string, any?)
	if not deps or not inGame(player) or not isOn() then
		return false, "Titles are off"
	end
	local Catalog = deps.Catalog
	if not Catalog.IsValidPreference(pref) then
		return false, "Unknown title"
	end
	local clock = if deps.clock then deps.clock() else os.clock()
	local last = equippedAtByPlayer[player]
	if last and clock - last < EQUIP_COOLDOWN then
		-- 2026-09-26 (owner): the player's latest choice wins. It is kept and applied when the
		-- cooldown ends (one scheduled call per player; a newer choice replaces the kept one).
		if type(deps.delay) == "function" then
			local scheduled = pendingPrefByPlayer[player] ~= nil
			pendingPrefByPlayer[player] = pref
			if not scheduled then
				pcall(deps.delay, EQUIP_COOLDOWN - (clock - last) + 0.05, function()
					local kept = pendingPrefByPlayer[player]
					pendingPrefByPlayer[player] = nil
					if kept == nil or not inGame(player) then
						return
					end
					local ok, message, payload = TitleService.Equip(player, kept)
					TitleService.Push(player, message, ok, payload)
				end)
			end
			return false, "Saving your title..."
		end
		return false, "Wait a moment"
	end
	pendingPrefByPlayer[player] = nil -- an accepted choice replaces any kept one
	local profile, handle = profileOf(player)
	if not handle then
		return false, "Data not loaded"
	end
	if pref ~= Catalog.Auto and pref ~= Catalog.None then
		if not Catalog.ById[pref] or TitleService.GetOwned(player, profile or {})[pref] ~= true then
			return false, "Title locked"
		end
	end
	local applyVolatile = deps.DataService.ApplyVolatile
	if type(applyVolatile) == "function" then
		local ok, result = pcall(applyVolatile, handle, { kind = "U4.Titles.SetPref", pref = pref })
		if not ok or type(result) ~= "table" or result.ok ~= true then
			return false, "Could not save"
		end
	end
	-- Without ApplyVolatile (an older DataService) the choice lasts this session only.
	prefByPlayer[player] = pref
	equippedAtByPlayer[player] = clock
	-- Titles_Equipped belongs to the session the panel opened (a bare "Equip" remote call would
	-- otherwise start a funnel session holding only step 2).
	if deps.FunnelAnalytics and openedByPlayer[player] then
		pcall(deps.FunnelAnalytics.Step, player, "Engagement_Titles", 2)
	end
	-- The profile read above is still right for this: the preference comes from prefByPlayer.
	local payload = TitleService.Refresh(player, false, true, profile)
	return true, if pref == Catalog.None then "Title hidden" else "Title equipped", payload
end

-- The panel asked for its data ("Get").
function TitleService.Open(player)
	if not deps or not inGame(player) or not isOn() then
		return nil
	end
	openedByPlayer[player] = true
	local now = os.clock()
	local lastOpen = openedAtByPlayer[player]
	if deps.FunnelAnalytics and (lastOpen == nil or now - lastOpen >= OPEN_FUNNEL_COOLDOWN) then
		openedAtByPlayer[player] = now
		pcall(deps.FunnelAnalytics.NewSession, player, "Engagement_Titles")
		pcall(deps.FunnelAnalytics.Step, player, "Engagement_Titles", 1)
	end
	return TitleService.Refresh(player, true)
end

-- The panel was seen: the notice dot clears.
function TitleService.Seen(player)
	if not deps or not inGame(player) then
		return
	end
	newCountByPlayer[player] = 0
	TitleService.Refresh(player)
end

-- 2026-09-26 (owner): a catalog title's display text ("OWNER"), nil for anything else. The admin
-- panel checks ids with it (so it needs no catalog of its own).
function TitleService.Text(id: any): string?
	local entry = deps and type(id) == "string" and deps.Catalog.ById[id] or nil
	return if entry then entry.Text else nil
end

-- What Bootstrap draws above the head: { Id, Text, Template, Style, Color1, Color2 } or nil.
function TitleService.Visual(player): { [string]: any }?
	if not deps or not inGame(player) or not isOn() then
		return nil
	end
	local ok, id = pcall(function()
		return player:GetAttribute("EquippedTitle")
	end)
	local entry = ok and type(id) == "string" and deps.Catalog.ById[id] or nil
	if not entry then
		return nil
	end
	local color3 = deps.Color3
	local c1, c2 = entry.Colors[1], entry.Colors[2] or entry.Colors[1]
	return {
		Id = entry.Id,
		Text = entry.Text,
		Template = entry.Template,
		Style = entry.Style,
		Color1 = if color3 then color3.fromRGB(c1[1], c1[2], c1[3]) else nil,
		Color2 = if color3 then color3.fromRGB(c2[1], c2[2], c2[3]) else nil,
	}
end

function TitleService.PlayerRemoving(player)
	staffByPlayer[player] = nil
	prefByPlayer[player] = nil
	newCountByPlayer[player] = nil
	sentKeyByPlayer[player] = nil
	openedByPlayer[player] = nil
	openedAtByPlayer[player] = nil
	knownMarkersByPlayer[player] = nil
	equippedAtByPlayer[player] = nil
	pendingPrefByPlayer[player] = nil
end

function TitleService.Configure(injected: { [string]: any })
	deps = injected
end

function TitleService.IsStarted(): boolean
	return started
end

-- Start: the global hooks other systems call. Players are refreshed by TitleSystem on DataLoaded.
function TitleService.Start()
	assert(deps, "TitleService.Configure first")
	started = true
	_G.SpeedsterTitles = {
		Refresh = TitleService.Refresh,
		Grant = TitleService.Grant,
		AdminGrant = TitleService.AdminGrant, -- 2026-09-26 (owner): the admin panel, any title
		Text = TitleService.Text, -- 2026-09-26 (owner): the admin panel's id check and toast
		Revoke = TitleService.Revoke,
		Visual = TitleService.Visual,
	}
end

-- Tests only.
function TitleService._Reset()
	deps, started = nil, false
	boardRanks = { Speed = {}, Wins = {}, Race = {} }
	for _, map in { staffByPlayer, prefByPlayer, newCountByPlayer, sentKeyByPlayer, openedByPlayer, openedAtByPlayer, knownMarkersByPlayer, equippedAtByPlayer, pendingPrefByPlayer } do
		table.clear(map)
	end
end

return TitleService
