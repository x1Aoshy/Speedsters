script.Parent.Touched:connect(function(hit)
	-- Frozen by the admin Snow event: ice does not burn.
	if workspace:GetAttribute("AdminWorldFrozen") == true then return end
	if hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
		hit.Parent.Humanoid.Health = 0
	end
end)
-- this script will kill players that touch the block