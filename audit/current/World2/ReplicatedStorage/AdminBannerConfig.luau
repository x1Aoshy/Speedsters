local AdminBannerConfig = {}

AdminBannerConfig.Admins = {
	[1051594227] = {
		DisplayName = "ttxxjj",
		HasBadge = true,
		RainbowUnlocked = true,
		DefaultColor = Color3.fromRGB(255, 0, 0),
	},
	[111827288] = {
		DisplayName = "Pxuto",
		HasBadge = true,
		RainbowUnlocked = true,
		DefaultColor = Color3.fromRGB(170, 0, 255),
	},
	[2723660087] = {
		DisplayName = "Sung",
		HasBadge = true,
		RainbowUnlocked = true,
		DefaultColor = Color3.fromRGB(85, 255, 0),
	},
	[116298455] = {
		DisplayName = "Junior",
		HasBadge = true,
		RainbowUnlocked = true,
		DefaultColor = Color3.fromRGB(255, 255, 0),
	},
	[767108248] = {
		DisplayName = "Admin",
		HasBadge = true,
		RainbowUnlocked = true,
		DefaultColor = Color3.fromRGB(255, 215, 0),
	},
}

function AdminBannerConfig.IsAdmin(userId)
	return AdminBannerConfig.Admins[userId] ~= nil
end

function AdminBannerConfig.GetConfig(userId)
	return AdminBannerConfig.Admins[userId]
end

return AdminBannerConfig