-- StaminaSyncClient.client.luau
-- The sprint bar's value arrives here, for this player only (Bootstrap fires StaminaSync to
-- the owner). A Player attribute set on the server replicates to every client, and nobody
-- else draws this bar. Writing the same attribute names locally keeps every reader (the HUD,
-- SpeedsterClient, Sonic Burst, the flight scripts) exactly as it was: a client-side
-- SetAttribute does not replicate. The two ends of the bar still come as real attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StaminaSync", 30)
if not remote then
	return
end
remote.OnClientEvent:Connect(function(stamina, maximum)
	if type(stamina) ~= "number" or type(maximum) ~= "number" or stamina ~= stamina then
		return
	end
	stamina = math.clamp(stamina, 0, math.max(0, maximum))
	player:SetAttribute("TrueBoostStamina", stamina)
	player:SetAttribute("BoostStamina", stamina)
end)
