--!strict
-- AfkEarningsLayout.luau
-- Finds the parts of the designer's "Earnings!" panel by what they are rather than by
-- name (two labels are both called "Name", two frames are both called "Fire"). Plain numbers
-- only, so offline tests and previews read exactly what the client builds.

local AfkEarningsLayout = {}

export type Parts = {
	Panel: Instance,
	Title: Instance?,
	Subtitle: Instance?,
	SpeedCard: Instance?,
	SpeedText: Instance?,
	SpeedIcon: Instance?,
	WinsCard: Instance?,
	WinsText: Instance?,
	WinsIcon: Instance?,
	Badge: Instance?,
	Claim: Instance?,
	ClaimGradient: Instance?,
	ClaimText: Instance?,
	FiveX: Instance?,
	FiveXGradient: Instance?,
	FiveXText: Instance?,
	Close: Instance?,
	Timer: Instance?,
}

function AfkEarningsLayout.Find(panel: Instance): Parts
	local title, subtitle, speedCard, winsCard
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "Name" then
			local y = (child :: any).Position.Y.Scale
			if not title or y < (title :: any).Position.Y.Scale then
				subtitle = subtitle or title
				title = child
			elseif not subtitle or y > (subtitle :: any).Position.Y.Scale then
				subtitle = child
			end
		elseif child:IsA("Frame") and child.Name == "Speed" then
			speedCard = child
		elseif child:IsA("Frame") and child.Name == "Fire" and child:FindFirstChild("Icon") then
			winsCard = child
		end
	end
	local claim = panel:FindFirstChild("Claim")
	local fiveX = panel:FindFirstChild("GetX5")
	return {
		Panel = panel,
		Title = title,
		Subtitle = subtitle,
		SpeedCard = speedCard,
		SpeedText = speedCard and (speedCard:FindFirstChild("Speed") or speedCard:FindFirstChildOfClass("TextLabel")),
		SpeedIcon = speedCard and (speedCard:FindFirstChildOfClass("ImageButton") or speedCard:FindFirstChildOfClass("ImageLabel")),
		WinsCard = winsCard,
		WinsText = winsCard and (winsCard:FindFirstChild("Speed") or winsCard:FindFirstChildOfClass("TextLabel")),
		WinsIcon = winsCard and winsCard:FindFirstChild("Icon"),
		Badge = winsCard and winsCard:FindFirstChild("!"),
		Claim = claim,
		ClaimGradient = claim and claim:FindFirstChildOfClass("UIGradient"),
		ClaimText = claim and claim:FindFirstChild("Name"),
		FiveX = fiveX,
		FiveXGradient = fiveX and fiveX:FindFirstChildOfClass("UIGradient"),
		FiveXText = fiveX and fiveX:FindFirstChild("Name"),
		Close = panel:FindFirstChild("Close"),
		Timer = panel:FindFirstChild("AfkTimer") or panel:FindFirstChild("Timer"),
	}
end

-- Styling color palettes as plain RGB tables (Lune + Roblox compatible)
AfkEarningsLayout.GreyButtonColor = { 130, 135, 140 }
AfkEarningsLayout.GreyTextColor = { 220, 225, 230 }
AfkEarningsLayout.WhiteColor = { 255, 255, 255 }
AfkEarningsLayout.StrokeNavyColor = { 11, 27, 61 }
AfkEarningsLayout.GreenReadyColor = { 100, 255, 120 }

-- The game's other panels (Shop, Index, Rebirth, Settings...) share one frame: 0.32 of the
-- screen's width by 0.586 of its height, kept at 1.28 to 1. The designer drew Earnings wider
-- and bigger (its buttons are about 264 px wide where Rebirth's are 171, its Close 121 px
-- where theirs is 65), so it stood out next to them.
AfkEarningsLayout.StandardPanel = { WidthScale = 0.32, HeightScale = 0.586, AspectRatio = 1.28 }

local function fittedWidth(size: any, ratio: number?, screenWidth: number, screenHeight: number): number
	local width = size.WidthScale * screenWidth + (size.WidthOffset or 0)
	if ratio and ratio > 0 then
		width = math.min(width, (size.HeightScale * screenHeight + (size.HeightOffset or 0)) * ratio)
	end
	return width
end

-- The UIScale that gives the Earnings panel the other panels' width on a screenWidth x
-- screenHeight screen, which brings its buttons, icons and Close to their sizes too. Never
-- above 1: it only ever shrinks the designer's panel.
function AfkEarningsLayout.PanelScale(panel: Instance, screenWidth: number, screenHeight: number): number
	local frame = panel :: any
	local constraint = panel:FindFirstChildOfClass("UIAspectRatioConstraint") :: any
	local own = fittedWidth({
		WidthScale = frame.Size.X.Scale,
		WidthOffset = frame.Size.X.Offset,
		HeightScale = frame.Size.Y.Scale,
		HeightOffset = frame.Size.Y.Offset,
	}, if constraint then constraint.AspectRatio else nil, screenWidth, screenHeight)
	local standard = AfkEarningsLayout.StandardPanel
	local target = fittedWidth(standard, standard.AspectRatio, screenWidth, screenHeight)
	if own <= 0 or target <= 0 then
		return 1
	end
	return math.min(1, target / own)
end

return AfkEarningsLayout
