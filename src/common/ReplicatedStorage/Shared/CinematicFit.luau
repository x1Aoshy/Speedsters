-- CinematicFit.luau
-- The geometry of the two cinematics' letterbox (Admin/AdminTreadmillReveal and
-- UI/WorldPortalCinematic), pure so it can be tested on real phone sizes.
--
-- 2026-09-22 (owner): the 0.11 bars took 22 % of the screen, and on wide phones (19.5:9) the
-- card, its words and the GO! button were cut off. On phones the bars are 0.05 of the height,
-- and the card is fitted with a scale <= 1 so all of it, GO! included, stays inside the band
-- between the bars and inside the device's safe area (top bar, notch, home indicator).
-- Desktop is unchanged: 0.11 bars, and the card there always fits at scale 1.

local CinematicFit = {}

CinematicFit.DesktopBar = 0.11
CinematicFit.PhoneBar = 0.05
-- A screen shorter than this is a phone's, whatever the device says (a small window, an emulator).
CinematicFit.ShortScreen = 500
-- The gap kept between the card and the band's edges, in pixels.
CinematicFit.Margin = 8
-- Notches and the home indicator on wide phones (19.5:9 and the like), in pixels. GuiInset gives
-- only the top bar; ScreenInsets.DeviceSafeInsets would need a second ScreenGui to be measured.
CinematicFit.WideAspect = 1.9
CinematicFit.NotchSide = 44
CinematicFit.NotchShare = 0.05 -- or 5 % of the width, whichever is more (HudErgonomics.SafeInset)
CinematicFit.HomeIndicator = 21
CinematicFit.PortraitTop = 47
CinematicFit.PortraitBottom = 34
-- How far a pop-in overshoots: the scripts' easeBack and TweenService's Back/Out both peak at
-- about x1.0999 on the way to 1, so a card fitted for this peak never pokes out mid-pop.
CinematicFit.PopPeak = 1.1
-- The smallest scale the fit ever gives (a card never shrinks to nothing).
CinematicFit.MinScale = 0.05

-- The share of the screen height each letterbox bar takes.
function CinematicFit.Bars(viewW: number, viewH: number, isPhone: boolean?): number
	if isPhone == true or viewH < CinematicFit.ShortScreen then
		return CinematicFit.PhoneBar
	end
	return CinematicFit.DesktopBar
end

-- Whether a screen counts as a phone's: a touch-only device (LOW_POWER) or a short screen.
function CinematicFit.IsPhone(viewW: number, viewH: number, touchOnly: boolean?): boolean
	return touchOnly == true or viewH < CinematicFit.ShortScreen
end

-- The screen's unsafe edges, in pixels: the top bar (GuiService:GetGuiInset().Y), and on phones
-- the notch and the home indicator.
function CinematicFit.Insets(viewW: number, viewH: number, isPhone: boolean?, topBar: number?)
	local insets = { Top = math.max(0, tonumber(topBar) or 0), Left = 0, Right = 0, Bottom = 0 }
	if isPhone ~= true then
		return insets
	end
	if viewW >= viewH then
		if viewW / math.max(1, viewH) >= CinematicFit.WideAspect then
			local side = math.max(CinematicFit.NotchSide, viewW * CinematicFit.NotchShare)
			insets.Left = side
			insets.Right = side
			insets.Bottom = CinematicFit.HomeIndicator
		end
	else
		insets.Top = math.max(insets.Top, CinematicFit.PortraitTop)
		insets.Bottom = CinematicFit.PortraitBottom
	end
	return insets
end

-- The visible band: between the bars and inside the safe insets, in pixels { X, Y, W, H }.
function CinematicFit.Band(viewW: number, viewH: number, barFraction: number, insets)
	insets = insets or { Top = 0, Left = 0, Right = 0, Bottom = 0 }
	local bar = viewH * (barFraction or 0)
	local top = math.max(bar, insets.Top or 0)
	local bottom = viewH - math.max(bar, insets.Bottom or 0)
	local left = insets.Left or 0
	local right = viewW - (insets.Right or 0)
	return { X = left, Y = top, W = math.max(0, right - left), H = math.max(0, bottom - top) }
end

-- The scale (<= 1) at which a card of cardW x cardH fits a band of bandW x bandH with `margin`
-- pixels kept clear on every side.
function CinematicFit.Fit(cardW: number, cardH: number, bandW: number, bandH: number, margin: number?): number
	local m = margin or CinematicFit.Margin
	local scale = 1
	if cardW > 0 then
		scale = math.min(scale, (bandW - 2 * m) / cardW)
	end
	if cardH > 0 then
		scale = math.min(scale, (bandH - 2 * m) / cardH)
	end
	return math.clamp(scale, CinematicFit.MinScale, 1)
end

-- A centre coordinate moved just enough that an extent of `size` around it stays within
-- [low + margin, high - margin] (centred when it cannot).
function CinematicFit.Clamp(centre: number, size: number, low: number, high: number, margin: number?): number
	local m = margin or CinematicFit.Margin
	local lo = low + m + size / 2
	local hi = high - m - size / 2
	if lo > hi then
		return (low + high) / 2
	end
	return math.clamp(centre, lo, hi)
end

return CinematicFit
