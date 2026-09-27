                                    
                                                                                
                                                                                
                                                                             
                                          

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("PlaytimeRewards"))


local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function ensureRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local Request = ensureRemote("PlaytimeRewardsRequest")
local Update = ensureRemote("PlaytimeRewardsUpdate")

local sessions = {}
local lastRequestAt = {}

local function newSession()
	return {
		StartedAt = Workspace:GetServerTimeNow(),
		Claimed = {},
		Busy = false,
	}
end

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = newSession()
		sessions[player] = session
	end
	return session
end

local function claimedArray(session)
	local result = {}
	for index = 1, Catalog.TotalRewards do
		if session.Claimed[index] == true then
			table.insert(result, index)
		end
	end
	return result
end

local function allRewardsClaimed(session)
	for index = 1, Catalog.TotalRewards do
		if session.Claimed[index] ~= true then
			return false
		end
	end
	return true
end

local function fireState(player, message, claimSucceeded)
	if player.Parent ~= Players then
		return
	end
	local session = getSession(player)
	Update:FireClient(player, {
		SessionStartedAt = session.StartedAt,
		Claimed = claimedArray(session),
		Completed = allRewardsClaimed(session),
		ServerNow = Workspace:GetServerTimeNow(),
		Message = tostring(message or ""),
		ClaimSucceeded = claimSucceeded == true,
	})
end

-- The claim path commits through DataService; the old direct-leaderstats grant,
-- its snapshot and its rollback were left behind unused and have been removed.

local function claim(player, index)
	index = math.floor(tonumber(index) or 0)
	local reward = Catalog.GetReward(index)
	local session = getSession(player)

	if not reward or session.Busy then
		return
	end
	session.Busy = true

	local function finish(message, succeeded)
		session.Busy = false
		fireState(player, message, succeeded)
	end

	if player:GetAttribute("DataLoaded") ~= true then
		finish("Your data is still loading. Try again.", false)
		return
	end
	if session.Claimed[index] == true then
		finish("Reward already claimed!", false)
		return
	end

	local elapsed = Workspace:GetServerTimeNow() - session.StartedAt
	if elapsed + 0.05 < Catalog.GetUnlockSeconds(index) then
		finish("That reward is not ready yet.", false)
		return
	end

	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then finish("Your data is not ready.",false);return end
	-- operationId doubles as the receipt id, so a retry of the same reward in the
	-- same session is answered with AlreadyCommitted instead of granting twice.
	local id="playtime:"..handle.sessionId..":"..index
	-- Commit was the one unguarded call here. If it threw, every finish() below was
	-- skipped and session.Busy stayed true, locking the player out of Time Gifts for
	-- the rest of the session.
	local ok,result=pcall(DataService.Commit,handle,{operationId=id,receiptId=id,fingerprint=id,commands={{kind="GrantExact",stat=reward.Type,amount=reward.Amount}}})
	if not ok then
		warn("[PlaytimeRewards] Claim commit failed for "..player.Name..": "..tostring(result))
		finish("Something went wrong. Try again shortly.",false);return
	end
	if type(result)~="table" or (result.kind~="Committed" and result.kind~="AlreadyCommitted") then
		finish("Your reward is awaiting save confirmation. Try again shortly.",false);return
	end
	session.Claimed[index]=true

	finish("Claimed " .. Catalog.GetRewardText(reward) .. "!", true)
end

Request.OnServerEvent:Connect(function(player, action, payload)
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < 0.12 then
		return
	end
	lastRequestAt[player] = now

	if action == "Refresh" then
		fireState(player)
	elseif action == "Claim" then
		claim(player, payload)
	end
end)

Players.PlayerAdded:Connect(function(player)
	sessions[player] = newSession()
	task.defer(fireState, player)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	lastRequestAt[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	sessions[player] = newSession()
	task.defer(fireState, player)
end

print("[PlaytimeRewards] V306KAC loaded. 15 exact session rewards unlock every 180 seconds with no server polling loop.")
