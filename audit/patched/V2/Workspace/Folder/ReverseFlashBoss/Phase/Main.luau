local Phase = script.Parent

Phase.Equipped:Connect(function()
	for _, v in pairs(workspace.Buildings:GetChildren()) do
		if v.Name == "Building" then
			v.CanCollide = false
		end
	end
end)

Phase.Unequipped:Connect(function()
	for _, v in pairs(workspace.Buildings:GetChildren()) do
		if v.Name == "Building" then
			v.CanCollide = true
		end
	end
end)