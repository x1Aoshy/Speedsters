          
                                                                            
                                                                 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ServerScriptService = game:GetService("ServerScriptService")
local StageTeleportService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("StageTeleportService"))
local STAGE_COUNT = math.max(11, math.floor(tonumber(Config.StageCount) or 11))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TeleportAction = Remotes:FindFirstChild("TeleportAction")
if not TeleportAction then
    TeleportAction = Instance.new("RemoteEvent")
    TeleportAction.Name = "TeleportAction"
    TeleportAction.Parent = Remotes
end

local TeleportUpdate = Remotes:FindFirstChild("TeleportUpdate")
if not TeleportUpdate then
    TeleportUpdate = Instance.new("RemoteEvent")
    TeleportUpdate.Name = "TeleportUpdate"
    TeleportUpdate.Parent = Remotes
end

local optionsByStage = {}
for _, option in ipairs(Config.TeleportStageOptions or {}) do
    local stage = math.floor(tonumber(option.Stage) or 0)
    if stage >= 1 then
        optionsByStage[stage] = option
    end
end

local function getStageOption(stage)
    local option = optionsByStage[stage]
    if option then return option end
    for _, opt in ipairs(Config.TeleportStageOptions or {}) do
        if math.floor(tonumber(opt.Stage) or 0) == stage then
            optionsByStage[stage] = opt
            return opt
        end
    end
    return nil
end

local lastActionAt = {}

local function getWinsValue(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    local wins = leaderstats and leaderstats:FindFirstChild("Wins")
    if wins and wins:IsA("ValueBase") then
        return wins
    end
    return nil
end

local function currentWins(player)
    local wins = getWinsValue(player)
    return wins and math.max(0, math.floor(tonumber(wins.Value) or 0)) or 0
end

local function sendUpdate(player, message, success, stage)
    TeleportUpdate:FireClient(player, {
        Wins = currentWins(player),
        Message = tostring(message or ""),
        Success = success == true,
        Stage = tonumber(stage) or 0,
    })
end

local function waitForData(player)
    local deadline = os.clock() + 8
    while player.Parent and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
        task.wait(0.1)
    end
    return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true
end

local function handleWinsTeleport(player, stage)
    local option = getStageOption(stage)
    if not option then
        sendUpdate(player, "That stage is not available yet", false, stage)
        return
    end

    if not waitForData(player) then
        sendUpdate(player, "Your data is still loading", false, stage)
        return
    end

    local winsValue = getWinsValue(player)
    if not winsValue then
        sendUpdate(player, "Wins are still loading", false, stage)
        return
    end

    local cost = math.max(0, math.floor(tonumber(option.WinsCost) or 0))
    local wins = math.max(0, math.floor(tonumber(winsValue.Value) or 0))
    if wins < cost then
        sendUpdate(player, "Not Enough Wins (Need " .. tostring(cost) .. " Wins)", false, stage)
        return
    end

                                                             
    local canTeleport, reason = StageTeleportService.TeleportPlayer(player, stage)
    if not canTeleport then
        sendUpdate(player, reason or "Stage is not ready", false, stage)
        return
    end

    if cost > 0 then
        winsValue.Value = wins - cost
        if _G.SpeedsterSavePlayer then
            task.defer(_G.SpeedsterSavePlayer, player, "stage_teleport_wins")
        end
    end

    sendUpdate(player, "Teleported to Stage " .. tostring(stage), true, stage)
end

TeleportAction.OnServerEvent:Connect(function(player, action, requestedStage)
    if action ~= "Wins" then
        return
    end

    local now = os.clock()
    if now - (lastActionAt[player] or 0) < 0.35 then
        return
    end
    lastActionAt[player] = now

    local stage = math.floor(tonumber(requestedStage) or 0)
    local option = optionsByStage[stage]
    if not option then
        sendUpdate(player, "That stage is not available yet", false, stage)
        return
    end

    handleWinsTeleport(player, stage)
end)

Players.PlayerRemoving:Connect(function(player)
    lastActionAt[player] = nil
end)

print(
	Config.IsNewWorld1Map == true
		and "[TeleportSystem] V306KBU loaded. New World 1 Stage 1-11 Wins teleport prices are exactly 2x each numbered stage reward."
		or "[TeleportSystem] V306EO loaded. Stage 2-10 Wins teleporting uses clear checkpoint arrivals."
)
