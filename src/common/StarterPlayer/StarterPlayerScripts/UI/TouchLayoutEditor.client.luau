-- TouchLayoutEditor.client.luau
-- "Move controls" (Settings, touch screens only): drag the Sprint button, the ability
-- buttons and the stamina bar where the thumbs want them.
--
--   * Opened by Settings' "Move controls" row: MenuEvents.Get("TouchLayoutEdit"):Fire("Open").
--   * What is dragged are HANDLES in this script's own ScreenGui (the Main HUD's screen space),
--     drawn where HudErgonomics.TouchControls puts each piece, never the real buttons: a drag
--     cannot toggle Sprint or charge a burst.
--   * Every drop goes through HudErgonomics.PlaceCustom (on screen, 24 px off Roblox's jump
--     button, buttons out of the thumbstick's area, Heat Vision 24 px off it) and may not
--     land on another handle or on the toolbar, nor Heat Vision within a thumb's width of
--     another button; one that would goes back where it was.
--   * The layout is the player's TouchLayout attribute (HudErgonomics.FormatTouchLayout): set
--     locally on every drop, so MainHUDController, SonicBurstClient and HeatVisionClient lay
--     the real pieces out under the handles at once, and sent ONCE, when the editor closes
--     (Done, a menu opening, the HUD going away) on a changed layout, through
--     Remotes.SettingsUpdate: the server keeps it in the profile's Settings like the other
--     preferences, and sends it back as the attribute on every join.
--   * Swap side: Sprint and the ability buttons over to the left thumb (HudErgonomics.
--     LeftPreset), or back. Reset: the automatic layout.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if not UserInputService.TouchEnabled then
	return -- a keyboard or a gamepad keeps the designer's HUD
end

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudErgonomics = require(Shared:WaitForChild("HudErgonomics"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ATTRIBUTE = "TouchLayout"
local HANDLE_GAP = 6 -- between handles on a drop (TouchControls wants 4; rounding keeps 2)
-- Heat Vision and the other buttons: a thumb's width (TouchControls wants HeatClearance, 24;
-- 2026-09-25), with the same 2 px for rounding.
local HEAT_GAP = HudErgonomics.HeatClearance + 2
local TAP_SLOP = 6 -- a handle dropped nearer than this to where it started was only tapped
local playerGui = player:WaitForChild("PlayerGui")
local mainhud = playerGui:WaitForChild("Mainhud", 30)
if not mainhud or not mainhud:IsA("ScreenGui") then
	return
end

-- The pieces, their handles' words, and the HUD button that says whether one is on screen.
local PIECES = {
	{ Key = "S", Text = "SPRINT" },
	{ Key = "B", Text = "BURST", Button = "SonicBurstButton" },
	{ Key = "H", Text = "HEAT", Button = "HeatVisionButton" },
	{ Key = "T", Text = "STAMINA" },
}

-- Parented only while open: Hide HUD turns the ScreenGuis it hid back on, and must never
-- turn this one on by itself.
local gui = Instance.new("ScreenGui")
gui.Name = "TouchLayoutEditGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60 -- over the Main HUD (0) and the speedometer (47), under toasts (100)
gui.ScreenInsets = mainhud.ScreenInsets -- the Main HUD's pixels, and the touch controls'
gui.Enabled = false

-- The toolbar, in the middle of the screen: the top middle is where Swap side puts the
-- buttons on small phones, and the corners are the HUD's. Higher or lower where a handle is
-- in the middle (syncHandles).
local TOOLBAR_SIZE = Vector2.new(304, 72)
local TOOLBAR_HEIGHTS = { 0.45, 0.25, 0.65 }
local toolbar = Instance.new("Frame")
toolbar.Name = "Toolbar"
toolbar.AnchorPoint = Vector2.new(0.5, 0.5)
toolbar.Position = UDim2.fromScale(0.5, TOOLBAR_HEIGHTS[1])
toolbar.Size = UDim2.fromOffset(TOOLBAR_SIZE.X, TOOLBAR_SIZE.Y)
toolbar.BackgroundTransparency = 1
toolbar.Parent = gui
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, 0, 0, 24)
hint.Text = "Drag a control to move it"
hint.TextScaled = true
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextStrokeTransparency = 0
hint.Parent = toolbar
local row = Instance.new("Frame")
row.Name = "Buttons"
row.BackgroundTransparency = 1
row.Position = UDim2.fromOffset(0, 30)
row.Size = UDim2.new(1, 0, 0, 42)
row.Parent = toolbar
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = row

local function withFont(label)
	pcall(function()
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	end)
end
withFont(hint)

local function toolbarButton(text: string, order: number, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(96, 42) -- a thumb's target
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0
	button.TextScaled = true
	button.Text = text
	withFont(button)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = button
	button.Parent = row
	return button
end
local swapButton = toolbarButton("Swap side", 1, Color3.fromRGB(60, 150, 255))
local resetButton = toolbarButton("Reset", 2, Color3.fromRGB(230, 70, 70))
local doneButton = toolbarButton("Done", 3, Color3.fromRGB(70, 210, 85))

local pieces = {} -- the layout being edited: { S = { X, Y }, ... } (shares of the Main HUD)
local openedWith = "" -- the layout when the editor opened: closing on it sends nothing
local plan = nil -- HudErgonomics.TouchControls for it: where each handle is drawn
local handles = {} -- Key -> TextButton
local open = false
local dragging = nil -- { Handle, Piece, Input, StartInput = Vector2, StartCentre = Vector2 }

local function shown(piece): boolean
	if not piece.Button then
		return true
	end
	local button = mainhud:FindFirstChild(piece.Button)
	return button ~= nil and button:IsA("GuiObject") and button.Visible
end

-- The plan for `pieces` on this screen, with the same inputs as the HUD scripts.
local function planFor()
	local size = mainhud.AbsoluteSize
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or size
	local topBar = (GuiService:GetGuiInset()).Y
	local neighbours = HudErgonomics.TouchNeighbours(viewport.X, viewport.Y, UserInputService.KeyboardEnabled, topBar)
	local controls = HudErgonomics.TouchControls(size.X, size.Y, HudErgonomics.FormatTouchLayout(pieces), neighbours, shown(PIECES[2]))
	-- The stamina bar keeps the designer's place until it is moved.
	controls.T = controls.T or HudErgonomics.CentreBarRects(size.X, size.Y)[2]
	return controls
end

-- The handles over the pieces' places (not over the real pieces, which may be sliding in),
-- and the toolbar where it stands clear of them (where it is, else the first free height).
local function syncHandles()
	plan = planFor()
	for _, piece in PIECES do
		local handle, r = handles[piece.Key], plan[piece.Key]
		handle.Visible = shown(piece)
		-- Whole pixels, rounded as the HUD scripts round the real pieces (an offset is an integer).
		handle.Size = UDim2.fromOffset(math.floor(r.Right - r.Left + 0.5), math.floor(r.Bottom - r.Top + 0.5))
		handle.Position = UDim2.fromOffset(math.floor((r.Left + r.Right) / 2 + 0.5), math.floor((r.Top + r.Bottom) / 2 + 0.5))
	end
	local size = mainhud.AbsoluteSize
	for _, share in { toolbar.Position.Y.Scale, table.unpack(TOOLBAR_HEIGHTS) } do
		local y = share * size.Y
		local area = { Left = (size.X - TOOLBAR_SIZE.X) / 2, Right = (size.X + TOOLBAR_SIZE.X) / 2, Top = y - TOOLBAR_SIZE.Y / 2, Bottom = y + TOOLBAR_SIZE.Y / 2 }
		local clear = true
		for _, piece in PIECES do
			clear = clear and not (shown(piece) and HudErgonomics.Overlaps(area, plan[piece.Key], HANDLE_GAP))
		end
		if clear then
			toolbar.Position = UDim2.fromScale(0.5, share)
			break
		end
	end
end

local function apply()
	player:SetAttribute(ATTRIBUTE, HudErgonomics.FormatTouchLayout(pieces))
	syncHandles()
end

local function centreOf(handle: GuiObject): Vector2
	return Vector2.new(handle.Position.X.Offset, handle.Position.Y.Offset)
end

local function drop()
	local drag = dragging
	dragging = nil
	if not drag or not open then
		return
	end
	local size = mainhud.AbsoluteSize
	local key = drag.Piece.Key
	local r = plan[key]
	local centre = centreOf(drag.Handle)
	-- A tap is not a move: it would pin the automatic place into the saved layout, and the
	-- piece would stop following the automatic layout (another screen, the Burst button shown).
	if (centre - drag.StartCentre).Magnitude < TAP_SLOP then
		drag.Handle.Position = UDim2.fromOffset(drag.StartCentre.X, drag.StartCentre.Y)
		return
	end
	-- Heat Vision keeps its 24 px off the thumbstick too (PlaceCustom's stick margin).
	local stickMargin = if key == "H" then HudErgonomics.HeatClearance else nil
	local placed = HudErgonomics.PlaceCustom(size.X, size.Y, r.Right - r.Left, r.Bottom - r.Top, centre.X / size.X, centre.Y / size.Y, key ~= "T", stickMargin)
	if placed then
		-- Not on another handle, nor under the toolbar (the handle could not be taken back);
		-- Heat Vision and another button no nearer than HEAT_GAP, whichever one moved.
		local bar = toolbar.AbsolutePosition - gui.AbsolutePosition
		local others = { { Left = bar.X, Top = bar.Y, Right = bar.X + toolbar.AbsoluteSize.X, Bottom = bar.Y + toolbar.AbsoluteSize.Y, Gap = HANDLE_GAP } }
		for _, piece in PIECES do
			if piece.Key ~= key and shown(piece) then
				local heat = (key == "H" or piece.Key == "H") and key ~= "T" and piece.Key ~= "T"
				local other = table.clone(plan[piece.Key])
				other.Gap = if heat then HEAT_GAP else HANDLE_GAP
				table.insert(others, other)
			end
		end
		for _, other in others do
			if HudErgonomics.Overlaps(placed, other, other.Gap) then
				placed = nil
				break
			end
		end
	end
	if placed then
		pieces[key] = { X = placed.X / size.X, Y = placed.Y / size.Y }
		apply()
	else
		drag.Handle.Position = UDim2.fromOffset(drag.StartCentre.X, drag.StartCentre.Y)
	end
end

for _, piece in PIECES do
	local handle = Instance.new("TextButton")
	handle.Name = "Handle" .. piece.Key
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.AutoButtonColor = false
	handle.Active = true -- takes the touch: the real piece under it never hears it
	handle.BackgroundColor3 = Color3.fromRGB(120, 225, 255)
	handle.BackgroundTransparency = 0.35
	handle.Text = piece.Text
	handle.TextScaled = true
	handle.TextColor3 = Color3.new(1, 1, 1)
	handle.TextStrokeTransparency = 0
	handle.ZIndex = 5
	handle.Visible = false
	withFont(handle)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(if piece.Key == "T" then 0.3 else 0.5, 0)
	corner.Parent = handle
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = handle
	handle.Parent = gui
	handles[piece.Key] = handle

	handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		-- A touch the system took away (an app switch, a system gesture) never ends here:
		-- its drag is dropped where it was so the next touch can drag again.
		local state = dragging and dragging.Input.UserInputState
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			local stale = dragging
			dragging = nil
			stale.Handle.Position = UDim2.fromOffset(stale.StartCentre.X, stale.StartCentre.Y)
		end
		if dragging or not open or (kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1) then
			return
		end
		dragging = {
			Handle = handle,
			Piece = piece,
			Input = input,
			StartInput = Vector2.new(input.Position.X, input.Position.Y),
			StartCentre = centreOf(handle),
		}
	end)
end

-- Only how far the finger has moved counts: no top bar or notch inset to get wrong. The
-- handle stays whole on the screen while it follows.
UserInputService.InputChanged:Connect(function(input)
	local drag = dragging
	if not drag then
		return
	end
	local mouse = drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
	if input ~= drag.Input and not mouse then
		return
	end
	local size, extent = mainhud.AbsoluteSize, drag.Handle.AbsoluteSize
	local moved = Vector2.new(input.Position.X, input.Position.Y) - drag.StartInput
	local x = math.clamp(drag.StartCentre.X + moved.X, extent.X / 2, math.max(extent.X / 2, size.X - extent.X / 2))
	local y = math.clamp(drag.StartCentre.Y + moved.Y, extent.Y / 2, math.max(extent.Y / 2, size.Y - extent.Y / 2))
	drag.Handle.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end)
UserInputService.InputEnded:Connect(function(input)
	local drag = dragging
	if drag and (input == drag.Input or (drag.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
		drop()
	end
end)

-- Closed: saved once, whatever closed it, when the layout changed.
local function close()
	if not open then
		return
	end
	open = false
	dragging = nil
	gui.Enabled = false
	gui.Parent = nil
	local text = HudErgonomics.FormatTouchLayout(pieces)
	local remote = Remotes:FindFirstChild("SettingsUpdate")
	if text ~= openedWith and remote and remote:IsA("RemoteEvent") then
		remote:FireServer(ATTRIBUTE, text)
	end
end

local function openEditor()
	if open or not mainhud.Enabled then
		return
	end
	open = true
	pieces = HudErgonomics.ParseTouchLayout(player:GetAttribute(ATTRIBUTE)) or {}
	openedWith = HudErgonomics.FormatTouchLayout(pieces)
	syncHandles()
	gui.Enabled = true
	gui.Parent = playerGui
end

swapButton.Activated:Connect(function()
	if not open then
		return
	end
	local size = mainhud.AbsoluteSize
	if plan.S.X >= size.X / 2 then
		local preset = HudErgonomics.LeftPreset(size.X, size.Y)
		pieces.S, pieces.B, pieces.H = preset.S, preset.B, preset.H
	else
		pieces.S, pieces.B, pieces.H = nil, nil, nil -- back beside the jump button
	end
	apply()
end)
resetButton.Activated:Connect(function()
	if open then
		pieces = {}
		apply()
	end
end)
doneButton.Activated:Connect(close)

MenuEvents.Get("TouchLayoutEdit").Event:Connect(function(action)
	if action == "Open" then
		openEditor()
	else
		close()
	end
end)
-- A menu opening (the HUD slides away) ends the edit, saved.
MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
	if visible == false then
		close()
	end
end)
-- So do a cinematic or Hide HUD turning the HUD or this screen off.
mainhud:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not mainhud.Enabled then
		close()
	end
end)
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if open and not gui.Enabled then
		close()
	end
end)
-- A rotation or a resize: the handles follow the pieces' new places.
mainhud:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if open then
		dragging = nil
		syncHandles()
	end
end)
for _, piece in PIECES do
	local button = piece.Button and mainhud:FindFirstChild(piece.Button)
	if button and button:IsA("GuiObject") then
		button:GetPropertyChangedSignal("Visible"):Connect(function()
			if open and not dragging then
				syncHandles()
			end
		end)
	end
end
