-- ReplicatedStorage/Shared/RaceScreenFx.luau — Update 4 race screen effects (2026-09-26, owner).
-- The own racer's screen while racing, all built once by Prewarm (the countdown) from plain
-- Frames, UIGradients, UICorners and UIStrokes (no images, no asset ids, no particles):
--   * speed lines: thin streaks flying out from the middle of the screen, more and brighter the
--     faster the racer runs over their own cruise (Feel.Screen LinesFrom .. LinesFull);
--   * a vignette: the four edges darken with the speed and the FOV, tinted cyan at super speed
--     and gold while a speed pad's boost lasts, and pulse with every shock;
--   * a shock ring: one or two rings racing out of the middle of the screen (the Sonic Boom at
--     GO, a pad, the finish).
-- Reduced motion: no lines and no ring (the vignette stays, calmer). After Prewarm nothing is
-- built: Step and Shock only move, show, hide and restyle (audit/test_u4_race_vfx).
-- Its ScreenGui "RaceScreenFx" sits under RaceHud (DisplayOrder 55); UI/RaceHudController keeps
-- it on screen while it hides the rest of the interface. Kill switch: SetEnabled
-- (Workspace U4Off_RaceScreen / U4Off_RaceFx, read by Race/RacePoseClient).
local Instance, Enum, Color3, UDim, UDim2, Vector2 = Instance, Enum, Color3, UDim, UDim2, Vector2
local NumberSequence, NumberSequenceKeypoint = NumberSequence, NumberSequenceKeypoint
if Instance == nil then
	-- Lune: the datatypes come from @lune/roblox (the dynamic require keeps Script Analysis quiet).
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Instance, Enum, Color3, UDim, UDim2, Vector2 = roblox.Instance, roblox.Enum, roblox.Color3, roblox.UDim, roblox.UDim2, roblox.Vector2
		NumberSequence, NumberSequenceKeypoint = roblox.NumberSequence, roblox.NumberSequenceKeypoint
	end
end

local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local SCREEN = U4.Race.Feel.Screen

local RaceScreenFx = {}

RaceScreenFx.GuiName = "RaceScreenFx"
RaceScreenFx.DisplayOrder = 55 -- under RaceHud (60)
RaceScreenFx.EdgeScale = 0.26 -- the vignette's edges reach this far in (of the screen)
RaceScreenFx.Colors = {
	Normal = Color3.fromRGB(6, 10, 26),
	Super = Color3.fromRGB(20, 110, 170),
	Boost = Color3.fromRGB(150, 110, 10),
	Line = Color3.fromRGB(225, 248, 255),
	Shock = Color3.fromRGB(215, 245, 255),
}

local state: any = nil
local shown = false
local on = true
local reducedMotion = false

local function rng(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function smooth01(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function number(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

-- The speed lines' and the vignette's levels (0..1) for a speed over the own cruise and the FOV.
function RaceScreenFx.Levels(ratio: number?, fov: number?): (number, number)
	local r = number(ratio, 0)
	local lines = smooth01((r - SCREEN.LinesFrom) / (SCREEN.LinesFull - SCREEN.LinesFrom))
	local wide = math.clamp((number(fov, SCREEN.BaseFov) - SCREEN.BaseFov) / (SCREEN.FovFull - SCREEN.BaseFov), 0, 1)
	return lines, math.clamp(0.55 * lines + 0.45 * wide, 0, 1)
end

-- How many of `count` lines show at `level`.
function RaceScreenFx.LineCount(count: number, level: number): number
	return math.clamp(math.floor(count * math.clamp(number(level, 0), 0, 1) + 0.5), 0, count)
end

----------------------------------------------------------------------
-- Prewarm
----------------------------------------------------------------------
local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Active = false
	f.Parent = parent
	return f
end

local function gradient(parent: Instance, rotation: number, points: { { number } }): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	g.Transparency = NumberSequence.new(keys)
	g.Parent = parent
	return g
end

local EDGE_FALLOFF = { { 0, 0 }, { 0.5, 0.72 }, { 1, 1 } }

local function build(parent: Instance, tier: string): any
	local gui = Instance.new("ScreenGui")
	gui.Name = RaceScreenFx.GuiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	pcall(function()
		(gui :: any).ScreenInsets = Enum.ScreenInsets.None
	end)
	gui.DisplayOrder = RaceScreenFx.DisplayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- The vignette: four edges, opaque at the screen's border, clear inward.
	local vignette = frame("Vignette", gui)
	vignette.Size = UDim2.fromScale(1, 1)
	local edges = {}
	local edge = RaceScreenFx.EdgeScale
	for _, spec in {
		{ "Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, edge), 90 },
		{ "Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, edge), 270 },
		{ "Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(edge * 0.75, 1), 0 },
		{ "Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(edge * 0.75, 1), 180 },
	} do
		local f = frame(spec[1], vignette)
		f.AnchorPoint = spec[2]
		f.Position = spec[3]
		f.Size = spec[4]
		f.BackgroundColor3 = RaceScreenFx.Colors.Normal
		gradient(f, spec[5], EDGE_FALLOFF)
		table.insert(edges, f)
	end

	-- The speed lines.
	local holder = frame("Lines", gui)
	holder.Size = UDim2.fromScale(1, 1)
	local lines = {}
	for index = 1, SCREEN.Lines[tier] or 0 do
		local f = frame("Line" .. index, holder)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = RaceScreenFx.Colors.Line
		f.Visible = false
		gradient(f, 0, { { 0, 1 }, { 0.4, 0.15 }, { 1, 1 } })
		lines[index] = { Frame = f, Shown = false, Radius = 0, Angle = 0, Length = 0, Speed = 0, Alpha = -1 }
	end

	-- The shock rings.
	local rings = {}
	for index = 1, SCREEN.ShockRings[tier] or 1 do
		local f = frame("Shock" .. index, gui)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Visible = false
		local corner = Instance.new("UICorner")
		local round = UDim.new(0.5, 0)
		pcall(function()
			corner.CornerRadius = round
		end)
		for _, name in { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" } do
			pcall(function()
				(corner :: any)[name] = round
			end)
		end
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Color = RaceScreenFx.Colors.Shock
		stroke.Thickness = 4
		stroke.Transparency = 1
		pcall(function()
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		end)
		stroke.Parent = f
		rings[index] = { Frame = f, Stroke = stroke, Start = -math.huge, Strength = 0, Alive = false }
	end

	gui.Parent = parent
	return {
		Gui = gui,
		Tier = tier,
		Edges = edges,
		EdgeAlpha = -1,
		EdgeColor = RaceScreenFx.Colors.Normal,
		Lines = lines,
		LineClock = 0,
		Rings = rings,
		PulseStart = -math.huge,
		PulseStrength = 0,
		Shocks = 0,
	}
end

-- Builds the ScreenGui under `parent` (the PlayerGui) once per tier; hidden until Show.
function RaceScreenFx.Prewarm(parent: Instance?, tier: string?): any
	local name = if tier == "High" or tier == "Mid" or tier == "Low" then tier else "Low"
	if state and state.Gui.Parent ~= nil and state.Tier == name and (parent == nil or state.Gui.Parent == parent) then
		return state
	end
	if state then
		state.Gui:Destroy()
		state = nil
	end
	if not parent then
		return nil
	end
	state = build(parent, name)
	shown = false
	return state
end

function RaceScreenFx.Get(): any
	return state
end

----------------------------------------------------------------------
-- Showing, switches
----------------------------------------------------------------------
local function hideAll()
	if not state then
		return
	end
	for _, line in state.Lines do
		if line.Shown then
			line.Shown = false
			line.Frame.Visible = false
		end
	end
	for _, ring in state.Rings do
		ring.Alive = false
		ring.Frame.Visible = false
	end
	for _, f in state.Edges do
		f.BackgroundTransparency = 1
	end
	state.EdgeAlpha = -1
	state.PulseStrength = 0
end

function RaceScreenFx.Show(visible: boolean)
	local want = visible == true and on
	if not state then
		shown = false
		return
	end
	if shown ~= want then
		shown = want
		if not want then
			hideAll()
		end
		state.Gui.Enabled = want
	end
end

function RaceScreenFx.IsShown(): boolean
	return shown
end

-- The kill switch (off hides it at once; on shows it again only with the next Show).
function RaceScreenFx.SetEnabled(enabled: boolean)
	on = enabled ~= false
	if not on then
		RaceScreenFx.Show(false)
	end
end

function RaceScreenFx.SetReducedMotion(reduced: boolean)
	reducedMotion = reduced == true
	if reducedMotion and state then
		for _, line in state.Lines do
			if line.Shown then
				line.Shown = false
				line.Frame.Visible = false
			end
		end
		for _, ring in state.Rings do
			ring.Alive = false
			ring.Frame.Visible = false
		end
	end
end

-- A shock (0..1): the rings race out of the middle of the screen and the vignette pulses.
-- Reduced motion: only a softer pulse.
function RaceScreenFx.Shock(strength: number?, now: number?)
	local s = math.clamp(number(strength, 0), 0, 1)
	if not state or not shown or s <= 0 then
		return
	end
	local clock = now or os.clock()
	state.PulseStart = clock
	state.PulseStrength = if reducedMotion then 0.5 * s else s
	state.Shocks += 1
	if reducedMotion then
		return
	end
	for index, ring in state.Rings do
		ring.Start = clock + (index - 1) * 0.07
		ring.Strength = s
		ring.Alive = true
	end
end

----------------------------------------------------------------------
-- Step: every frame of the own racer's run (Race/RacePoseClient's RenderStepped)
----------------------------------------------------------------------
local function respawnLine(line: any, reach: number, height: number, fresh: boolean)
	line.Angle = rng(0, 2 * math.pi)
	line.Radius = if fresh then rng(0.3, 0.9) else rng(0.3, 0.55)
	line.Length = rng(0.08, 0.22) * reach
	line.Speed = rng(1.4, 2.4)
	local thick = math.max(1, rng(1.5, 3.5) * height / 720)
	line.Frame.Size = UDim2.fromOffset(math.floor(line.Length + 0.5), math.floor(thick * 10 + 0.5) / 10)
	line.Frame.Rotation = math.deg(line.Angle)
end

local function stepLines(dt: number, level: number, viewport: Vector2)
	local lines = state.Lines
	if #lines == 0 then
		return
	end
	local want = if reducedMotion then 0 else RaceScreenFx.LineCount(#lines, level)
	state.LineClock += dt
	local hz = SCREEN.Hz[state.Tier] or 30
	if state.LineClock < 1 / hz and want > 0 then
		return
	end
	local step = state.LineClock
	state.LineClock = 0
	local half = viewport * 0.5
	local reach = half.Magnitude
	local alpha = math.floor((0.25 + 0.6 * level) * 20 + 0.5) / 20
	for index, line in lines do
		if index <= want then
			if not line.Shown then
				respawnLine(line, reach, viewport.Y, true)
				line.Shown = true
				line.Frame.Visible = true
			end
			line.Radius += line.Speed * (0.6 + level) * step
			if line.Radius > 1.05 then
				respawnLine(line, reach, viewport.Y, false)
			end
			local distance = line.Radius * reach + line.Length * 0.5
			line.Frame.Position = UDim2.fromOffset(half.X + math.cos(line.Angle) * distance, half.Y + math.sin(line.Angle) * distance)
			if line.Alpha ~= alpha then
				line.Alpha = alpha
				line.Frame.BackgroundTransparency = 1 - alpha
			end
		elseif line.Shown then
			line.Shown = false
			line.Frame.Visible = false
		end
	end
end

local function stepRings(clock: number, viewport: Vector2)
	local diagonal = viewport.Magnitude
	for _, ring in state.Rings do
		if ring.Alive then
			local alpha = (clock - ring.Start) / SCREEN.ShockSeconds
			if alpha >= 1 then
				ring.Alive = false
				ring.Frame.Visible = false
			elseif alpha >= 0 then
				local e = 1 - (1 - alpha) ^ 2
				local size = math.floor((0.12 + 1.4 * e) * diagonal + 0.5)
				ring.Frame.Size = UDim2.fromOffset(size, size)
				ring.Stroke.Thickness = math.max(1, (3 + 16 * ring.Strength) * (1 - alpha))
				ring.Stroke.Transparency = 0.1 + 0.9 * alpha ^ 1.2
				if not ring.Frame.Visible then
					ring.Frame.Visible = true
				end
			end
		end
	end
end

-- input: { Ratio = speed / own cruise, Fov = the camera's, Super, Boosted, Viewport, Now }.
function RaceScreenFx.Step(dt: number, input: any)
	if not state or not shown then
		return
	end
	local clock = input.Now or os.clock()
	local viewport = if typeof(input.Viewport) == "Vector2" and input.Viewport.X > 0 then input.Viewport else Vector2.new(1280, 720)
	local lines, vignette = RaceScreenFx.Levels(input.Ratio, input.Fov)
	-- The shock's pulse of the vignette (0.3 s).
	local pulse = 0
	if state.PulseStrength > 0 then
		local a = (clock - state.PulseStart) / 0.3
		if a >= 1 then
			state.PulseStrength = 0
		elseif a >= 0 then
			pulse = state.PulseStrength * (1 - a)
		end
	end
	local alpha = SCREEN.VignetteAlpha * math.clamp(vignette + 0.6 * pulse, 0, 1) * (if reducedMotion then 0.7 else 1)
	alpha = math.floor(alpha * 50 + 0.5) / 50
	local color = if input.Super then RaceScreenFx.Colors.Super elseif input.Boosted then RaceScreenFx.Colors.Boost else RaceScreenFx.Colors.Normal
	if alpha ~= state.EdgeAlpha or color ~= state.EdgeColor then
		state.EdgeAlpha = alpha
		state.EdgeColor = color
		for _, f in state.Edges do
			f.BackgroundTransparency = 1 - alpha
			f.BackgroundColor3 = color
		end
	end
	stepLines(math.max(0, number(dt, 0)), lines, viewport)
	if not reducedMotion then
		stepRings(clock, viewport)
	end
end

function RaceScreenFx.Release()
	if state then
		state.Gui:Destroy()
	end
	state = nil
	shown = false
end

return RaceScreenFx
