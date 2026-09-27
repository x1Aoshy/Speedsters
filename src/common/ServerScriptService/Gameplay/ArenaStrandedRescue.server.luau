-- ServerScriptService/Gameplay/ArenaStrandedRescue.server.luau
-- 2026-09-26 (owner, critical: "sometimes players stay in the boss fight's place"): a safety net that does not
-- depend on the race or on the Super Sonic event. A player standing on the race map (Shared/RaceNoFlight's zone:
-- the whole Green Hill arena and its water) who is in no race (RaceActive / RaceState) while no event is live
-- (SSE_Phase empty, or stuck: its phase started StaleSeconds ago) is sent back to the lobby after GraceSeconds:
-- LoadCharacter puts them on the world's spawn with a fresh body (no leftover anchor, ragdoll or freeze).
-- Workspace attribute U4Off_ArenaRescue = true turns it off live (e.g. to walk the arena in Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceNoFlight = require(Shared:WaitForChild("RaceNoFlight"))
local SSE = require(Shared:WaitForChild("SuperSonicEvent"))

local CHECK_SECONDS = 2
local GRACE_SECONDS = 6 -- the race's own moves (staging, results → lobby) finish well inside this
local STALE_SECONDS = 240 -- longer than any event phase (the Battle: 150 s): a phase this old is a stuck event
local RACE_STATES = { Staged = true, Racing = true, Finished = true }

local strandedSince: { [Player]: number } = {}

local function eventLive(now: number): boolean
	local phase = Workspace:GetAttribute(SSE.Attributes.Phase)
	if type(phase) ~= "string" or phase == "" then
		return false
	end
	local start = tonumber(Workspace:GetAttribute(SSE.Attributes.PhaseStart))
	return start == nil or now - start < STALE_SECONDS
end

local function inRace(player: Player): boolean
	if player:GetAttribute("RaceActive") == true then
		return true
	end
	local state = player:GetAttribute("RaceState")
	return type(state) == "string" and RACE_STATES[state] == true
end

local function sweep()
	if Workspace:GetAttribute("U4Off_ArenaRescue") == true then
		table.clear(strandedSince)
		return
	end
	local now = Workspace:GetServerTimeNow()
	local live = eventLive(now)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local stranded = root ~= nil and root:IsA("BasePart") and not live and not inRace(player)
			and RaceNoFlight.InArena(root.Position)
		if not stranded then
			strandedSince[player] = nil
		else
			local since = strandedSince[player]
			if not since then
				strandedSince[player] = now
			elseif now - since >= GRACE_SECONDS then
				strandedSince[player] = nil
				warn(("[ArenaRescue] %s was stranded on the race map with no race or event: back to the lobby"):format(player.Name))
				local ok, err = pcall(function()
					player:LoadCharacter()
				end)
				if not ok then
					warn("[ArenaRescue] LoadCharacter failed: " .. tostring(err))
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	strandedSince[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(CHECK_SECONDS)
		local ok, err = pcall(sweep)
		if not ok then
			warn("[ArenaRescue] " .. tostring(err))
		end
	end
end)
