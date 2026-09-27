                              
                                                                              
                                                                            
                                                                     

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local GroupService = game:GetService("GroupService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RankRewardEvent = Remotes:WaitForChild("RankRewardEvent")

                                                                     
                                                                                           
local GROUP_ID = 771624731
local REWARD_MARKER = "RankReward_GroupLike_v1"
local SPEED_REWARD = 1000000
local WINS_REWARD = 1000

local touchDebounce = {}
local claimBusy = {}

local function getOwnedUpgrades(player)
	local data = player:FindFirstChild("SpeedsterData")
	return data and data:FindFirstChild("OwnedUpgrades")
end

local function hasClaimed(player)
	local owned = getOwnedUpgrades(player)
	local marker = owned and owned:FindFirstChild(REWARD_MARKER)
	return marker ~= nil and marker:IsA("BoolValue") and marker.Value == true
end

local function findPlayerFromHit(hit)
	local current = hit
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

local function fireOpen(player)
	if player.Parent ~= Players then
		return
	end
	RankRewardEvent:FireClient(player, {
		Type = "Open",
		Claimed = hasClaimed(player),
		GroupId = GROUP_ID,
		SpeedReward = SPEED_REWARD,
		WinsReward = WINS_REWARD,
	})
end

local function compactName(name)
	return string.lower((tostring(name or ""):gsub("[%s_%-]", "")))
end

local function candidateHasPad(candidate)
	if not candidate then
		return false
	end
	if candidate:FindFirstChild("Pad", true) then
		return true
	end
	for _, descendant in ipairs(candidate:GetDescendants()) do
		if compactName(descendant.Name) == "pad" then
			return true
		end
	end
	return false
end

local function resolveRewardRoot()
	                                                                   
	local exactPlural = Workspace:FindFirstChild("Rank Rewards", true)
	if exactPlural and candidateHasPad(exactPlural) then
		return exactPlural
	end

	                                                            
	local exactSingular = Workspace:FindFirstChild("Rank Reward", true)
	if exactSingular and candidateHasPad(exactSingular) then
		return exactSingular
	end

	                                                                        
	                                                                             
	                                                           
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		local key = compactName(descendant.Name)
		if (key == "rankrewards" or key == "rankreward" or key == "groupreward" or key == "grouprewards")
			and candidateHasPad(descendant)
		then
			return descendant
		end
	end
	return nil
end

local function resolvePadNode(rewardRoot)
	if not rewardRoot then
		return nil
	end
	local exact = rewardRoot:FindFirstChild("Pad", true)
	if exact then
		return exact
	end
	for _, descendant in ipairs(rewardRoot:GetDescendants()) do
		if compactName(descendant.Name) == "pad" then
			return descendant
		end
	end
	return nil
end

local rewardRoot = resolveRewardRoot()
local boundPads = {}

local function addPadPart(part)
	if not part or not part:IsA("BasePart") or boundPads[part] then
		return
	end
	boundPads[part] = true
	-- Client handles intentional stepping on pad. Server does not force-open
	-- on raw physics Touched to prevent auto-popups upon spawn or mobile physics glitches.
end

if not rewardRoot then
	warn('[RankReward] Could not find a reward container named Rank Rewards / Rank Reward / Group rewards anywhere under Workspace.')
else
	local padNode = resolvePadNode(rewardRoot)
	if not padNode then
		warn(('[RankReward] Reward container found at %s, but no descendant named Pad was found.'):format(rewardRoot:GetFullName()))
	elseif padNode:IsA("BasePart") then
		addPadPart(padNode)
	else
		for _, descendant in ipairs(padNode:GetDescendants()) do
			addPadPart(descendant)
		end
	end

	local count = 0
	for _ in pairs(boundPads) do count += 1 end
	if count == 0 then
		warn(('[RankReward] Pad node found at %s, but it contains no BasePart trigger.'):format(padNode and padNode:GetFullName() or "?"))
	else
		print(("[RankReward] V306KE ready | root=%s | pad=%s | bound BaseParts=%d | exact +1,000,000 Speed +1,000 Wins")
			:format(rewardRoot:GetFullName(), padNode:GetFullName(), count))
	end
end

                                                                                
                                                                                    
task.spawn(function()
	local ok, info = pcall(function()
		return GroupService:GetGroupInfoAsync(GROUP_ID)
	end)
	if ok and type(info) == "table" then
		print(("[RankReward] Group ID validated | %s | ID=%d"):format(tostring(info.Name or "Group"), GROUP_ID))
	else
		warn(("[RankReward] GROUP_ID %d could not be validated. If this came from /share/g/, send the direct /communities/<ID>/ or /groups/<ID>/ URL."):format(GROUP_ID))
	end
end)

local function getGrantFunctions()
	local deadline = os.clock() + 8
	while os.clock() < deadline do
		if type(_G.SpeedsterGrantExactStat) == "function"
			and type(_G.SpeedsterUnlockUpgrade) == "function"
			and type(_G.SpeedsterSavePlayer) == "function"
		then
			return _G.SpeedsterGrantExactStat, _G.SpeedsterUnlockUpgrade, _G.SpeedsterSavePlayer
		end
		task.wait(0.05)
	end
	return nil, nil, nil
end

RankRewardEvent.OnServerEvent:Connect(function(player, action)
	if action == "OpenRequest" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local padNode = resolvePadNode(rewardRoot)
		local padPart = padNode and (padNode:IsA("BasePart") and padNode or padNode:FindFirstChildWhichIsA("BasePart", true))
		if padPart and (root.Position - padPart.Position).Magnitude > 35 then
			return
		end
		local now = os.clock()
		if now - (touchDebounce[player] or 0) >= 0.5 then
			touchDebounce[player] = now
			fireOpen(player)
		end
		return
	end
	if action ~= "Claim" then
		return
	end
	if claimBusy[player] then
		return
	end
	claimBusy[player] = true

	local function finish(ok, message, claimed)
		if player.Parent == Players then
			RankRewardEvent:FireClient(player, {
				Type = "ClaimResult",
				Success = ok == true,
				Message = tostring(message or ""),
				Claimed = claimed == true,
			})
		end
		claimBusy[player] = nil
	end

	if player:GetAttribute("DataLoaded") ~= true then
		finish(false, "Your data is still loading. Try again in a moment.", false)
		return
	end

	if hasClaimed(player) then
		finish(true, "Reward already claimed!", true)
		return
	end

	                                                                          
	                                                                                 
	                                                                        
	local groupCheckOk, inGroup = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	if not groupCheckOk then
		finish(false, "Roblox couldn't verify the group yet. Try Claim again.", false)
		return
	end
	if not inGroup then
		finish(false, "Join the group first, then press Claim Reward.", false)
		return
	end

	local grantExactStat, unlockUpgrade, savePlayer = getGrantFunctions()
	if not grantExactStat then
		finish(false, "Reward system is still starting. Try again in a moment.", false)
		return
	end

	local speedOk = select(1, grantExactStat(player, "Speed", SPEED_REWARD))
	if not speedOk then
		finish(false, "Could not grant Speed. Try again.", false)
		return
	end

	local winsOk = select(1, grantExactStat(player, "Wins", WINS_REWARD))
	if not winsOk then
		                                                                             
		                                                               
		finish(false, "Could not grant Wins. Rejoin before trying again.", false)
		return
	end

	unlockUpgrade(player, REWARD_MARKER)
	local saved = savePlayer(player, "rank_reward_group_claim", true)
	if saved ~= true then
		warn("[RankReward] Reward applied but save did not confirm for " .. player.Name)
	end

	finish(true, "+1,000,000 Speed and +1,000 Wins claimed!", true)
end)

Players.PlayerRemoving:Connect(function(player)
	touchDebounce[player] = nil
	claimBusy[player] = nil
end)
