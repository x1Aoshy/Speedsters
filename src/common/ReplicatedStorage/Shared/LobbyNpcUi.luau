-- ReplicatedStorage/Shared/LobbyNpcUi.luau — Update 4 (2026-09-25): the lobby NPCs' UI, built from
-- plain Instances with the constructors of `env` (Shared/RaceUiKit: the Roblox globals in the
-- game, @lune/roblox in audit/test_u4_npcs), in the race UI's blocky look (RaceUiBuilder's
-- window: white frame over the stud art, ink outline, title on the top edge, round close).
--   BuildFlashDialog(env)  LobbyNpcFlashGui  DisplayOrder 20, Window 660x440 "RACE SIGN-UP":
--                          Flash's line on a stud plate, the race status, three category
--                          tiles (Beginner / Rank / Open, attribute Category) and WEEKLY
--                          RECORDS. The window's FitScale is sized by the controller
--                          (LobbyNpcUi.Fit; 560x296 on phones since 2026-09-26).
--   BuildBubble(env)       LobbyNpcBubble    a speech bubble (BillboardGui, fixed pixel size)
--   BuildTag(env)          LobbyNpcTag       name + role over an NPC's head
--   BuildAlert(env)        LobbyNpcAlert     Eggman's gold "!" (a quest reward or choice waits)
-- No scripts, nothing connected or tweened: UI/LobbyNpcsClient fills the words (Shared/
-- LobbyNpcText) and animates.
local RaceUiKit: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceUiKit", 10))
	else require("./RaceUiKit")
local RaceUiBuilder: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceUiBuilder", 10))
	else require("./RaceUiBuilder")
local RaceHudLayout: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceHudLayout", 10))
	else require("./RaceHudLayout")

local LobbyNpcUi = {}

LobbyNpcUi.DialogName = "LobbyNpcFlashGui"
LobbyNpcUi.BubbleName = "LobbyNpcBubble"
LobbyNpcUi.TagName = "LobbyNpcTag"
LobbyNpcUi.AlertName = "LobbyNpcAlert"
LobbyNpcUi.DialogSize = { 660, 440 }
-- Tile palettes: open / greyed out.
LobbyNpcUi.TilePalettes = { Beginner = "Green", Rank = "Blue", Open = "Gold" }
LobbyNpcUi.LockedPalette = "Navy"
LobbyNpcUi.Categories = { "Beginner", "Rank", "Open" }

local function kitFor(env: any?): any
	return RaceUiKit.new(env)
end

----------------------------------------------------------------------
-- Flash's sign-up window
----------------------------------------------------------------------
-- 2026-09-26 (owner, phone playtest: "the race sign-up is too big"): two arrangements, as the
-- race windows (RaceUiBuilder.ArrangeResults / ArrangePanel): Wide, the desktop's 660 x 440,
-- and Compact, 560 x 296 for phones (the tiles 168 x 112, WEEKLY RECORDS 54 px tall, words
-- 14 px or more), picked and placed by RaceUiBuilder.FitWindow (LobbyNpcUi.Fit).
LobbyNpcUi.DialogCompactSize = { 560, 296 }
LobbyNpcUi.DialogLayouts = {
	Wide = {
		Speech = { 24, 50, 612, 74 }, Speaker = { 14, 4, 240, 22 }, SpeakerText = 18, Line = { 14, 26, 28, 44 },
		Status = { 24, 130, 612, 26 }, Tiles = { 24, 164, 612, 176 }, Tile = { 196, 176 }, TileGap = 12,
		Icon = { 8, 48 }, Label = { 58, 16, 40 }, Sub = { 104, 18, 60 }, RecordsY = 356, Records = { 320, 60 },
	},
	Compact = {
		Speech = { 18, 28, 524, 60 }, Speaker = { 44, 4, 240, 18 }, SpeakerText = 15, Line = { 12, 22, 24, 34 },
		Status = { 18, 92, 524, 20 }, Tiles = { 18, 116, 524, 112 }, Tile = { 168, 112 }, TileGap = 10,
		Icon = { 6, 30 }, Label = { 38, 12, 26 }, Sub = { 66, 14, 40 }, RecordsY = 234, Records = { 300, 54 },
	},
}

function LobbyNpcUi.ArrangeFlashDialog(env: any, window: any, compact: boolean)
	local UDim2 = env.UDim2
	local L = LobbyNpcUi.DialogLayouts[if compact then "Compact" else "Wide"]
	local size = if compact then LobbyNpcUi.DialogCompactSize else LobbyNpcUi.DialogSize
	RaceUiBuilder.ArrangeHeader(env, window, size[1], size[2], compact)
	local function box(object: any, r: { number })
		object.Position = UDim2.fromOffset(r[1], r[2])
		object.Size = UDim2.fromOffset(r[3], r[4])
	end
	local speech = window.Speech
	box(speech, L.Speech)
	box(speech.Speaker, L.Speaker)
	speech.Speaker.TextSize = L.SpeakerText
	speech.Line.Position = UDim2.fromOffset(L.Line[1], L.Line[2])
	speech.Line.Size = UDim2.new(1, -L.Line[3], 0, L.Line[4])
	box(window.Status, L.Status)
	box(window.Tiles, L.Tiles)
	for index, category in LobbyNpcUi.Categories do
		local tile = window.Tiles:FindFirstChild(category)
		if tile then
			tile.Position = UDim2.fromOffset((index - 1) * (L.Tile[1] + L.TileGap), 0)
			tile.Size = UDim2.fromOffset(L.Tile[1], L.Tile[2])
			tile.Icon.Position = UDim2.new(0.5, 0, 0, L.Icon[1])
			tile.Icon.Size = UDim2.fromOffset(L.Icon[2], L.Icon[2])
			tile.Label.Position = UDim2.new(0.5, 0, 0, L.Label[1])
			tile.Label.Size = UDim2.new(1, -L.Label[2], 0, L.Label[3])
			tile.Sub.Position = UDim2.new(0.5, 0, 0, L.Sub[1])
			tile.Sub.Size = UDim2.new(1, -L.Sub[2], 0, L.Sub[3])
		end
	end
	local records = window.Records
	records.Position = UDim2.new(0.5, 0, 0, L.RecordsY)
	records.Size = UDim2.fromOffset(L.Records[1], L.Records[2])
	RaceUiBuilder.ArrangeButtonLabel(env, records, compact)
end

function LobbyNpcUi.BuildFlashDialog(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local Vector2, Enum = e.Vector2, e.Enum
	local gui = kit:make("ScreenGui", {
		Name = LobbyNpcUi.DialogName,
		Enabled = false,
		DisplayOrder = 20,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- 2026-09-26 (owner): under the top bar and inside the notch (the window centres there).
		IgnoreGuiInset = false,
		AutoLocalize = false,
	}, nil)
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	local size = LobbyNpcUi.DialogSize
	local window = RaceUiBuilder.BlockyWindow(kit, gui, { Width = size[1], Height = size[2], Title = "RACE SIGN-UP", Icon = RaceUiKit.Art.Lightning })

	-- Flash's line, on a light stud plate (places: ArrangeFlashDialog).
	local speech = kit:make("Frame", { Name = "Speech", ZIndex = 2 }, window)
	kit:studPanel(speech, 14)
	kit:text(speech, "Speaker", { Text = "THE FLASH", TextColor3 = kit:color("Gold"), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 }, 18)
	local line = kit:text(speech, "Line", {
		TextColor3 = kit:color("Navy"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		ZIndex = 3,
	})
	line.Outline.Color = kit:color("White")

	kit:text(window, "Status", { TextColor3 = kit:color("Cyan"), ZIndex = 3 })

	-- The three categories.
	local tiles = kit:make("Frame", { Name = "Tiles", BackgroundTransparency = 1, ZIndex = 2 }, window)
	for index, category in LobbyNpcUi.Categories do
		local tile = kit:button(tiles, category, string.upper(category), LobbyNpcUi.TilePalettes[category], {
			ZIndex = 3,
			LayoutOrder = index,
		})
		tile:SetAttribute("Category", category)
		tile.Label.AnchorPoint = Vector2.new(0.5, 0)
		kit:make("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Image = if category == "Open" then RaceUiKit.Art.Trophy else RaceUiKit.Art.Lightning,
			ZIndex = 4,
		}, tile)
		kit:text(tile, "Sub", { AnchorPoint = Vector2.new(0.5, 0), TextWrapped = true, ZIndex = 4 })
	end

	kit:button(window, "Records", "WEEKLY RECORDS", "Purple", {
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 3,
	})
	LobbyNpcUi.ArrangeFlashDialog(e, window, false)
	return gui
end

-- The window on a screen: RaceUiBuilder.FitWindow with the dialog's arrangements (arranges
-- and places `window`, returns the fit; its Scale is the FitScale's, which the caller tweens).
function LobbyNpcUi.Fit(env: any, window: any, viewX: number, viewY: number, roomW: number, roomH: number, touch: boolean?): any
	return RaceUiBuilder.FitWindow(env, window, LobbyNpcUi.ArrangeFlashDialog,
		{ Wide = LobbyNpcUi.DialogSize, Compact = LobbyNpcUi.DialogCompactSize }, viewX, viewY, roomW, roomH, touch)
end

-- The window's scale on a `viewX` x `viewY` touch screen whose top bar is `topBar` px (no notch),
-- in the arrangement RaceHudLayout.WindowCompact picks there.
function LobbyNpcUi.FitScale(viewX: number, viewY: number, topBar: number?, touch: boolean?): number
	local roomW, roomH = viewX, viewY - (topBar or 0)
	local isTouch = touch ~= false
	local compact = RaceHudLayout.WindowCompact(viewX, viewY, roomW, roomH, isTouch)
	local size = if compact then LobbyNpcUi.DialogCompactSize else LobbyNpcUi.DialogSize
	return RaceHudLayout.WindowFit(RaceUiBuilder.WindowDesign(size, compact), roomW, roomH, compact, viewY).Scale
end

----------------------------------------------------------------------
-- Over the NPCs' heads
----------------------------------------------------------------------
local function billboard(kit: any, name: string, width: number, height: number, maxDistance: number, onTop: boolean): any
	local e = kit.env
	return kit:make("BillboardGui", {
		Name = name,
		Size = e.UDim2.fromOffset(width, height),
		MaxDistance = maxDistance,
		AlwaysOnTop = onTop,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = false,
		ClipsDescendants = false,
		AutoLocalize = false,
		Enabled = false,
	}, nil)
end

-- A speech bubble: a light stud plate with a tail, the line in navy with a white edge.
function LobbyNpcUi.BuildBubble(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2 = e.UDim2, e.Vector2
	local gui = billboard(kit, LobbyNpcUi.BubbleName, 330, 118, 70, true)
	local holder = kit:make("Frame", { Name = "Holder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	kit:make("UIScale", { Name = "Pop", Scale = 1 }, holder)
	local tail = kit:make("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(22, 22),
		Rotation = 45,
		BackgroundColor3 = kit:color("White"),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, holder)
	kit:stroke(tail, "Ink", 3)
	local plate = kit:make("Frame", { Name = "Plate", Size = UDim2.new(1, 0, 1, -18), ZIndex = 2 }, holder)
	kit:studPanel(plate, 16)
	local text = kit:text(plate, "Text", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -14),
		TextColor3 = kit:color("Navy"),
		TextWrapped = true,
		ZIndex = 3,
	})
	text.Outline.Color = kit:color("White")
	return gui
end

-- Name (white) over role (gold), as the leaderboards' headers write.
function LobbyNpcUi.BuildTag(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2 = e.UDim2
	local gui = billboard(kit, LobbyNpcUi.TagName, 200, 52, 60, false)
	local name = kit:text(gui, "NameLabel", { Size = UDim2.new(1, 0, 0, 29) })
	name.Outline.Thickness = 3
	kit:text(gui, "Role", { Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 22), TextColor3 = kit:color("Gold") })
	return gui
end

-- A gold disc with a white "!", as the Quest topbar icon's notice. Sized in studs plus pixels:
-- never under 30 px far away (it must read from the spawn), bigger up close.
function LobbyNpcUi.BuildAlert(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2 = e.UDim2, e.Vector2
	local gui = billboard(kit, LobbyNpcUi.AlertName, 30, 30, 160, false)
	gui.Size = UDim2.new(1.6, 30, 1.6, 30)
	local badge = kit:make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = kit:color("White"),
		BorderSizePixel = 0,
	}, gui)
	kit:corner(badge, nil, 0.5)
	kit:make("UIGradient", { Name = "Fill", Rotation = 90, Color = kit:sequence(RaceUiKit.Palettes.Gold.Fill) }, badge)
	kit:stroke(badge, "Ink", 3)
	kit:make("UIScale", { Name = "Bounce", Scale = 1 }, badge)
	local mark = kit:text(badge, "Mark", { Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 2 })
	mark.Outline.Thickness = 3
	return gui
end

return LobbyNpcUi
