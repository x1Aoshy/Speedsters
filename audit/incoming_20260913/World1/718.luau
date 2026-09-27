-- Shared frame and popup layout contract for menus and modal popups.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Layout = {}

Layout.Panels = {
	Abilities = "Panel",
	Shop = "Shop",
	Index = "Index",
	Rebirth = "Rebirth",
	Evolve = "Evolve",
	StageTeleport = "StageTeleport",
	Backpack = "MainFrame",
	TimeGift = "TimeGift",
	DailyReward = "Days31",
	Settings = "Settings",
	Worlds = "Worlds",
	UpdateLogs = "Title",
	Treadmill = "TimeGift",
	RankReward = "Panel",
	Admin = "MainFrame",
}

Layout.ModalSizes = {
	Treadmill = Vector2.new(650, 315),
	RankReward = Vector2.new(690, 430),
	UpdateLogs = Vector2.new(670, 410),
	DailyReward = Vector2.new(680, 450),
	Settings = Vector2.new(660, 440),
	Worlds = Vector2.new(680, 440),
	Admin = Vector2.new(680, 440),
}

function Layout.Calculate(width: number, height: number, touch: boolean, hasSidebar: boolean?)
	local compact = (touch and (width < 1100 or height < 650)) or width < 700 or height < 500
	if not compact then
		return { x = 0.498, y = 0.453, width = 0.32, height = 0.586, scale = 1, compact = false }
	end
	-- Uniformly scale the desktop canvas, retaining readable proportions in either orientation.
	local canvasWidth, canvasHeight = 1920 * 0.32, 1080 * 0.586
	local extraWidth = hasSidebar and canvasWidth * 0.16 or 0
	local scale = math.min(1, math.max(1, width - 24) / (canvasWidth + extraWidth), math.max(1, height - 24) / canvasHeight)
	return {
		x = 0.5 + extraWidth * scale / (2 * math.max(width, 1)),
		y = 0.5,
		width = canvasWidth,
		height = canvasHeight,
		scale = scale,
		compact = true,
	}
end

-- Asegura un único UIScale canónico en el frame, limpiando cualquier UIScale duplicado que cause distorsiones
function Layout.EnsureSingleScale(panel: GuiObject, scaleName: string?): UIScale
	local name = scaleName or "UIScale"
	local chosen: UIScale? = nil
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UIScale") then
			if not chosen then
				chosen = child
				chosen.Name = name
			else
				child:Destroy()
			end
		end
	end
	if not chosen then
		chosen = Instance.new("UIScale")
		chosen.Name = name
		chosen.Scale = 1
		chosen.Parent = panel
	end
	return chosen
end

-- Calcula la escala ideal para un popup o modal centrado en función de la resolución visible
function Layout.GetModalScale(viewport: Vector2, baseSize: Vector2?, isTouch: boolean?, customMargin: Vector2?): number
	local inset = Vector2.zero
	pcall(function()
		inset = GuiService:GetGuiInset()
	end)
	local marginX = if customMargin then customMargin.X else (if isTouch then 32 else 60)
	local marginY = if customMargin then customMargin.Y else (if isTouch then 28 else 60)
	local availX = math.max(1, viewport.X - marginX)
	local availY = math.max(1, viewport.Y - inset.Y - marginY)
	local size = baseSize or Vector2.new(680, 420)
	local fit = math.min(availX / size.X, availY / size.Y)
	return math.clamp(fit, 0.45, 1.05)
end

-- Animación estandarizada y suave de apertura (Back Out elástico)
function Layout.AnimateOpen(panel: GuiObject, dim: GuiObject?, uiScale: UIScale?, targetScale: number?, duration: number?)
	panel.Visible = true
	local scale = targetScale or 1
	local dur = duration or 0.24
	local tweens = {}

	if uiScale then
		uiScale.Scale = scale * 0.88
		local t = TweenService:Create(uiScale, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		t:Play()
		table.insert(tweens, t)
	end

	if dim then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		local t = TweenService:Create(dim, TweenInfo.new(math.max(0.12, dur - 0.04), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.48,
		})
		t:Play()
		table.insert(tweens, t)
	end

	return tweens[1]
end

-- Animación estandarizada de cierre (Quad In)
function Layout.AnimateClose(panel: GuiObject, dim: GuiObject?, uiScale: UIScale?, targetScale: number?, onComplete: (() -> ())?, duration: number?)
	local scale = targetScale or 1
	local dur = duration or 0.18
	local remaining = 0

	local function checkDone()
		remaining -= 1
		if remaining <= 0 then
			panel.Visible = false
			if dim then
				dim.Visible = false
				dim.Active = false
			end
			if onComplete then
				onComplete()
			end
		end
	end

	if uiScale then
		remaining += 1
		local t = TweenService:Create(uiScale, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = scale * 0.88,
		})
		t.Completed:Connect(checkDone)
		t:Play()
	end

	if dim then
		remaining += 1
		local t = TweenService:Create(dim, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(checkDone)
		t:Play()
	end

	if remaining == 0 then
		panel.Visible = false
		if dim then
			dim.Visible = false
			dim.Active = false
		end
		if onComplete then
			onComplete()
		end
	end
end

return Layout
