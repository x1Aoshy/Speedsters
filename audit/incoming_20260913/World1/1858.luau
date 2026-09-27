local Players = game:GetService("Players")

script.Parent.Touched:Connect(function(hit)
	if hit and hit.Parent then
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and (player:GetAttribute("StageTeleportInvulnerable") == true 
				or (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0) > os.clock()) then
				return
			end
			humanoid.Health = 0
		end
	end
end)