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
-- screen's width by 0.586 of its height, kept at 1.28 to 1, its icon standing 0.09 of its
-- height above it. The designer drew Earnings wider and bigger (its buttons are about 264 px
-- wide where Rebirth's are 171, its Close 121 px where theirs is 65), so it stood out next to
-- them.
AfkEarningsLayout.StandardPanel = { WidthScale = 0.32, HeightScale = 0.586, AspectRatio = 1.28, Header = 0.09 }

local function fittedWidth(size: any, ratio: number?, screenWidth: number, screenHeight: number): number
	local width = size.WidthScale * screenWidth + (size.WidthOffset or 0)
	if ratio and ratio > 0 then
		width = math.min(width, (size.HeightScale * screenHeight + (size.HeightOffset or 0)) * ratio)
	end
	return width
end

-- A piece's pixel size inside a `width` x `height` box, as its UIAspectRatioConstraint (if
-- any) leaves it.
local function drawnSize(piece: any, width: number, height: number): (number, number)
	local w = piece.Size.X.Scale * width + piece.Size.X.Offset
	local h = piece.Size.Y.Scale * height + piece.Size.Y.Offset
	local shape = piece:FindFirstChildOfClass("UIAspectRatioConstraint") :: any
	if shape and shape.AspectRatio > 0 then
		if shape.AspectType == Enum.AspectType.ScaleWithParentSize then
			if shape.DominantAxis == Enum.DominantAxis.Height then
				w = h * shape.AspectRatio
			else
				h = w / shape.AspectRatio
			end
		else
			w = math.min(w, h * shape.AspectRatio)
			h = w / shape.AspectRatio
		end
	end
	return w, h
end

-- How far the panel's pieces stand past its edges when it is drawn `width` x `height`, in
-- pixels: above, below, left and right of it (its Close past its right edge and its icon past
-- its left one, both above it).
local function overhang(panel: Instance, width: number, height: number): (number, number, number, number)
	local above, below, left, right = 0, 0, 0, 0
	for _, child in panel:GetChildren() do
		local piece = child :: any
		if child:IsA("GuiObject") and piece.Visible then
			local w, h = drawnSize(piece, width, height)
			local x = piece.Position.X.Scale * width + piece.Position.X.Offset - piece.AnchorPoint.X * w
			local y = piece.Position.Y.Scale * height + piece.Position.Y.Offset - piece.AnchorPoint.Y * h
			above, below = math.max(above, -y), math.max(below, y + h - height)
			left, right = math.max(left, -x), math.max(right, x + w - width)
		end
	end
	return above, below, left, right
end

-- How many times `reach` fits in `room` (no limit when nothing reaches that way).
local function fitsIn(room: number, reach: number): number
	if reach <= 0 then
		return math.huge
	end
	return room / reach
end

-- The UIScale that gives the Earnings panel the other panels' width on a screenWidth x
-- screenHeight screen, which brings its buttons, icons and Close to their sizes too. Never
-- above `grow` (1 when nil): it only ever shrinks the designer's panel, except on phones, where
-- the other panels are drawn `grow` times bigger (MenuPanelLayout.BindPhoneFit) and it follows.
-- With `margin` (pixels: X from the screen's sides, Y from its top and bottom) that growth
-- also stops where the panel, its pieces included, would come closer to an edge: `grow` is the
-- shared window's, centred with nothing past its sides, but the designer put this panel right
-- of the middle with its Close past its right edge, so on a portrait phone (Worlds 2 and 3 turn
-- with the phone) that growth alone pushes the Close off the screen. Never below the desktop
-- rule.
function AfkEarningsLayout.PanelScale(panel: Instance, screenWidth: number, screenHeight: number, grow: number?, margin: Vector2?): number
	local frame = panel :: any
	local constraint = panel:FindFirstChildOfClass("UIAspectRatioConstraint") :: any
	local ratio = if constraint then constraint.AspectRatio else nil
	local own = fittedWidth({
		WidthScale = frame.Size.X.Scale,
		WidthOffset = frame.Size.X.Offset,
		HeightScale = frame.Size.Y.Scale,
		HeightOffset = frame.Size.Y.Offset,
	}, ratio, screenWidth, screenHeight)
	local standard = AfkEarningsLayout.StandardPanel
	local target = fittedWidth(standard, standard.AspectRatio, screenWidth, screenHeight)
	if own <= 0 or target <= 0 then
		return 1
	end
	local scale = math.min(1, target / own)
	local grown = scale * math.max(1, grow or 1)
	if grown <= scale or not margin then
		return grown
	end
	-- The panel at UIScale 1, and how far each of its sides (pieces included) lies from the
	-- point its Position places, which a UIScale leaves where it is.
	local width = own
	local height = if ratio and ratio > 0 then own / ratio else frame.Size.Y.Scale * screenHeight + frame.Size.Y.Offset
	local above, below, left, right = overhang(panel, width, height)
	local x = frame.Position.X.Scale * screenWidth + frame.Position.X.Offset
	local y = frame.Position.Y.Scale * screenHeight + frame.Position.Y.Offset
	local anchor = frame.AnchorPoint
	local whole = math.min(
		fitsIn(x - margin.X, anchor.X * width + left),
		fitsIn(screenWidth - margin.X - x, (1 - anchor.X) * width + right),
		fitsIn(y - margin.Y, anchor.Y * height + above),
		fitsIn(screenHeight - margin.Y - y, (1 - anchor.Y) * height + below)
	)
	return math.max(scale, math.min(grown, whole))
end

return AfkEarningsLayout
