--add admins here , add your asset id 
-- if u dont know what is asset id find on youtube
local AdminConfig = {
	AdminIds = {
		[game.CreatorId] = true
	},
	AdminIdList = {
		game.CreatorId,
	},
	TesterIds = {
		game.CreatorId
	},
	ChatRoles = {
		Lead = {1580586066},
		Dev = {},
		Tester = {1580586066},
	},
}

function AdminConfig.IsAdmin(userId: number): boolean
	return AdminConfig.AdminIds[userId] == true
end

return AdminConfig