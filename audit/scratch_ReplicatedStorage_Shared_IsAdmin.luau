local AdminConfig = require(script.Parent.AdminConfig)
local ADMIN_IDS = AdminConfig.AdminIds

local RunService = game:GetService("RunService")

local function IsAdmin(userId: number?): boolean
	if userId == nil then
		if RunService:IsClient() then
			userId = game:GetService("Players").LocalPlayer.UserId
		else
			error("IsAdmin requires a userId on the server")
		end
	end
	return ADMIN_IDS[userId] == true
end

return IsAdmin