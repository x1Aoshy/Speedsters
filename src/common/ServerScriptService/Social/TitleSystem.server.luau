-- Social/TitleSystem.server.luau (Update 4, 2026-09-25)
-- Wires Services/Titles/TitleService to the game: the TitlesRequest/TitlesUpdate remotes of the
-- designer "Titles" panel ("Get", "Equip" pref, "Seen"; RemoteGuard 0.3 s), staff checks on join,
-- a refresh once the player's data is loaded and when VIP changes. Everything is skipped while
-- Update4Config.IsOn("Titles") is false: the title attributes stay empty and Bootstrap draws its
-- Dev/Tester parts as before.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local TitleCatalog = require(Shared:WaitForChild("TitleCatalog"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local RemoteGuard = require(Services:WaitForChild("RemoteGuard"))
local TitleService = require(Services:WaitForChild("Titles"):WaitForChild("TitleService"))
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ensureRemote(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remotes
	return remote
end
local TitlesRequest = ensureRemote("TitlesRequest")
local TitlesUpdate = ensureRemote("TitlesUpdate")

local DATA_WAIT_SECONDS = 120

-- The game's creator owns OWNER: the user, or rank >= OwnerGroupRank (255) in the owning group.
local function isGameOwner(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId ~= 0 and player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId ~= 0 then
		local ok, rank = pcall(function()
			return player:GetRankInGroupAsync(game.CreatorId)
		end)
		return ok and type(rank) == "number" and rank >= (tonumber(U4.Titles.OwnerGroupRank) or 255)
	end
	return false
end

TitleService.Configure({
	Players = Players,
	DataService = DataService,
	FunnelAnalytics = FunnelAnalytics,
	U4 = U4,
	Catalog = TitleCatalog,
	UpdateRemote = TitlesUpdate,
	-- Bootstrap makes the toast remote; found lazily so a slow Bootstrap costs only the toast.
	ToastRemote = Remotes:FindFirstChild("TemporaryBoostUpdate"),
	IsGameOwner = isGameOwner,
	Color3 = Color3,
	wait = task.wait,
	-- 2026-09-26 (owner): a title picked inside the 1 s Equip cooldown is applied when it ends.
	delay = task.delay,
})
TitleService.Start()

RemoteGuard.Connect(TitlesRequest, 0.3, function(player: Player, action: any, pref: any)
	if not U4.IsOn("Titles") or type(action) ~= "string" then
		return
	end
	-- "Get" answers even before the data is in (staff and board titles are known; earned ones
	-- follow on the DataLoaded refresh); Equip needs the profile and refuses without it.
	if action == "Get" then
		TitleService.Open(player)
	elseif action == "Equip" then
		if type(pref) ~= "string" or #pref > TitleCatalog.MaxIdLength then
			return
		end
		-- Equip's own refreshed payload answers the panel (no second profile read).
		local ok, message, payload = TitleService.Equip(player, pref)
		TitleService.Push(player, message, ok, payload)
	elseif action == "Seen" then
		TitleService.Seen(player)
	end
end)

local function onPlayer(player: Player)
	task.spawn(function()
		local deadline = os.clock() + DATA_WAIT_SECONDS
		while player.Parent == Players and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(0.5)
		end
		if player.Parent ~= Players or not U4.IsOn("Titles") then
			return
		end
		TitleService.ComputeStaff(player)
		TitleService.Refresh(player)
	end)
	player:GetAttributeChangedSignal("VIPGamepassOwned"):Connect(function()
		TitleService.Refresh(player)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(TitleService.PlayerRemoving)

-- The live kill switch (Workspace U4Off_Titles, 2026-09-25): every player is recomputed at once,
-- so the attributes empty (Bootstrap draws its Dev/Tester parts) or come back without a rejoin.
workspace:GetAttributeChangedSignal(U4.KillAttributePrefix .. "Titles"):Connect(function()
	for _, player in Players:GetPlayers() do
		task.spawn(TitleService.Refresh, player)
	end
end)

-- The toast remote may appear after this script started (Bootstrap order).
task.spawn(function()
	local toast = Remotes:WaitForChild("TemporaryBoostUpdate", 30)
	if toast then
		TitleService.SetToastRemote(toast)
	end
end)
