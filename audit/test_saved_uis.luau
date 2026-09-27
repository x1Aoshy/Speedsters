-- test_saved_uis.luau
-- The Spin Wheel and Earnings panels are real instances in every place's StarterGui (so
-- they can be seen and edited in Studio), finished: the designer's layout plus what the
-- game adds to it. The saved files are current, and the controllers use the saved panels.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Layout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")
local Catalog = require("../src/common/ReplicatedStorage/Shared/SpinWheelCatalog")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function shape(root)
	local list = {}
	for _, d in root:GetDescendants() do
		table.insert(list, d:GetFullName() .. "|" .. d.ClassName)
	end
	table.sort(list)
	return table.concat(list, "\n")
end

local Extras = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SpinWheelExtras.luau"), {
	environment = setmetatable({
		Instance = rb.Instance, Color3 = rb.Color3, ColorSequence = rb.ColorSequence,
		ColorSequenceKeypoint = rb.ColorSequenceKeypoint, UDim = rb.UDim, UDim2 = rb.UDim2,
		Vector2 = rb.Vector2, Enum = rb.Enum,
	}, { __index = _G }),
})()

-- 1. In every place, finished and closed.
do
	local design = rb.deserializeModel(fs.readFile("design/ui/SpinWheelAndEarnings.rbxm"))[1]
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local starter = place:GetService("StarterGui")
		local wheel = starter:FindFirstChild("SpinWheelGui")
		assert(wheel and wheel:IsA("ScreenGui"), world .. ": the Spin Wheel is a real ScreenGui in StarterGui")
		assert(wheel.ResetOnSpawn == false and wheel.Enabled == false, world .. ": kept across respawns, and closed until opened")
		local holder = wheel:FindFirstChild("Frame")
		assert(holder:FindFirstChild("Spin Wheel"):FindFirstChild("SliceColours"), world .. ": with its rarity colours")
		for _, name in { "HubCap", "WinsSpin", "WinsCaption", "X10", "X10Caption" } do
			assert(holder:FindFirstChild(name), world .. ": with its " .. name)
		end
		assert(holder.X10.Name == "X10" and holder.X10:FindFirstChild("Price").Text == "199", world .. ": X10 at 199 R$")
		assert(holder.X10Caption.Text == "BEST VALUE", world .. ": ...marked BEST VALUE")
		-- The designer's own pieces are as the designer made them.
		local row, designRow = wheel:FindFirstChild("Button"), design.SpinWheel:FindFirstChild("Button")
		for _, name in { "X1", "X3", "Claim" } do
			assert(row[name].Size == designRow[name].Size and row[name].Position == designRow[name].Position, world .. ": the designer's " .. name .. " is untouched")
		end
		local earnings = starter:FindFirstChild("AfkRewardsGui")
		assert(earnings and earnings:IsA("ScreenGui") and earnings.ResetOnSpawn == false and earnings.Enabled == false, world .. ": the Earnings panel is saved too")
		assert(earnings:FindFirstChild("Earnings"), world .. ": ...with the designer's panel")
		assert(holder:FindFirstChild("CompactScale") and holder.CompactScale.Scale == 1, world .. ": the wheel's compact (phone) scale is saved, at the designer's size")
		-- The pieces added to authored HUDs in the mobile / console pass.
		local revive = starter.RevivePromptHUD.ReviveOfferHolder:FindFirstChild("CloseButton")
		assert(revive and revive:IsA("ImageButton") and revive:FindFirstChild("Art"), world .. ": the Revive offer's close X is saved")
		local press = starter.Mainhud.MobileSprint:FindFirstChild("PressScale")
		assert(press and press:IsA("UIScale") and press.Scale == 1, world .. ": the Sprint button's pressed state is saved")
		for _, gui in { wheel, earnings, revive } do
			for _, d in gui:GetDescendants() do
				assert(not d:IsA("LuaSourceContainer"), world .. ": saved UIs carry no scripts")
			end
		end
	end
	print("PASS saved: the finished Spin Wheel and Earnings panels, the Revive X and the Sprint press scale are in all three places' StarterGui")
end

-- 2. The saved files are current: a fresh build of the panel matches what is saved, and
-- decorating the saved panel again adds nothing.
do
	local design = rb.deserializeModel(fs.readFile("design/ui/SpinWheelAndEarnings.rbxm"))[1]
	local saved = rb.deserializeModel(fs.readFile("src/ui/SpinWheelGui.rbxm"))[1]
	local fresh = design:FindFirstChild("SpinWheel"):Clone()
	fresh.Name = "SpinWheelGui"
	Extras.Decorate(fresh, { { Key = "Spins10", Button = "X10", PriceRobux = 299, Caption = "BEST VALUE" } }, Layout, Catalog)
	assert(shape(fresh) == shape(saved), "src/ui/SpinWheelGui.rbxm is out of date: run lune run audit/build_ui_prefabs.luau SpinWheelGui")
	local before = #saved:GetDescendants()
	Extras.Decorate(saved, { { Key = "Spins10", Button = "X10", PriceRobux = 299, Caption = "BEST VALUE" } }, Layout, Catalog)
	assert(#saved:GetDescendants() == before, "Decorating a saved panel makes nothing twice")
	print("PASS current: the saved panel is what the build makes, and nothing is made twice on it")
end

-- 3. The controllers use the saved panels; the Spin Wheel waits for its authored GUI.
do
	local wheel = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	has(wheel, 'local gui = PlayerGui:WaitForChild("SpinWheelGui")', "The Spin Wheel controller waits for the saved panel")
	has(wheel, "SpinWheelExtras.Decorate(gui, settings.Products, SpinWheelLayout, SpinWheelCatalog)", "...and fills in only what is missing")
	local earnings = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau")
	has(earnings, 'local screenGui = PlayerGui:FindFirstChild("AfkRewardsGui") or PlayerGui:WaitForChild("AfkRewardsGui", 8)', "The Earnings controller uses the saved panel")
	local build = fs.readFile("audit/build_core.luau")
	has(build, "{source='src/ui/SpinWheelGui.rbxm',parent={'StarterGui'},name='SpinWheelGui'}", "The build saves the Spin Wheel into StarterGui")
	has(build, "{source='src/ui/ReviveCloseButton.rbxm',parent={'StarterGui','RevivePromptHUD','ReviveOfferHolder'},name='CloseButton'}", "The build saves the Revive X")
	has(build, "{source='src/ui/MobileSprintPressScale.rbxm',parent={'StarterGui','Mainhud','MobileSprint'},name='PressScale'}", "The build saves the Sprint press scale")
	local revive = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/RevivePrompt.client.luau")
	has(revive, "local closeButton = holder:FindFirstChild(ReviveCloseButton.Name)", "The Revive prompt uses the saved X")
	print("PASS controllers: both panels come from StarterGui")
end

-- 4. The Choose Your Destiny panel (design/ui/Quests.rbxm, finished by Shared.QuestUi) is
-- saved too, current, used by its controller, and fits every screen: the designer's three
-- cards side by side on wide screens; on phones and narrow windows the cards scroll, each
-- at least 260 px wide with Choose buttons at least 44 px tall.
do
	local QuestUi = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/QuestUi.luau"), {
		environment = setmetatable({
			Instance = rb.Instance, Color3 = rb.Color3, ColorSequence = rb.ColorSequence,
			ColorSequenceKeypoint = rb.ColorSequenceKeypoint, UDim = rb.UDim, UDim2 = rb.UDim2,
			Vector2 = rb.Vector2, Enum = rb.Enum,
		}, { __index = _G }),
	})()
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local quests = place:GetService("StarterGui"):FindFirstChild("QuestGui")
		assert(quests and quests:IsA("ScreenGui") and quests.ResetOnSpawn == false and quests.Enabled == false, world .. ": the quest panel is a real, closed ScreenGui in StarterGui")
		local frame = quests:FindFirstChild("Frame")
		for _, name in { "Title", "Timer", "Close", "Scroller", "Confetti", "UIScale", "Quest1", "Quest2", "Quest3" } do
			assert(frame:FindFirstChild(name), world .. ": the quest panel has its " .. name)
		end
		assert(frame.Title.Text == "Choose your destiny", world .. ": the designer's title")
		for _, d in quests:GetDescendants() do
			assert(not d:IsA("LuaSourceContainer"), world .. ": the saved quest panel carries no scripts")
		end
	end

	local saved = rb.deserializeModel(fs.readFile("src/ui/QuestGui.rbxm"))[1]
	local fresh = rb.deserializeModel(fs.readFile("design/ui/Quests.rbxm"))[1]
	fresh.Name = "QuestGui"
	QuestUi.Decorate(fresh)
	assert(shape(fresh) == shape(saved), "src/ui/QuestGui.rbxm is out of date: run lune run audit/build_ui_prefabs.luau QuestGui")
	local before = #saved:GetDescendants()
	QuestUi.Decorate(saved)
	assert(#saved:GetDescendants() == before, "Decorating the saved quest panel makes nothing twice")
	-- Builds patch the places directly now (audit/build_quest_ui_fix.luau, 2026-09-19), so the panel
	-- in each place is compared with the prefab: same instances, and Decorate adds nothing to it.
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local inPlace = place:GetService("StarterGui").QuestGui:Clone()
		assert(shape(inPlace) == shape(fresh), world .. ": StarterGui.QuestGui differs from src/ui/QuestGui.rbxm")
		local count = #inPlace:GetDescendants()
		QuestUi.Decorate(inPlace)
		assert(#inPlace:GetDescendants() == count, world .. ": the controller's Decorate adds nothing to the saved panel")
	end
	-- The designer's own pieces are as the designer made them.
	local designFrame = rb.deserializeModel(fs.readFile("design/ui/Quests.rbxm"))[1].Frame
	for index, card in QuestUi.Cards(saved) do
		assert(card.Name == "Quest" .. index, "Cards are named left to right")
		local match = false
		for _, original in designFrame:GetChildren() do
			if original:IsA("Frame") and original.Position == card.Position and original.Size == card.Size then
				match = true
			end
		end
		assert(match, "Card " .. index .. " keeps the designer's place and size")
	end

	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/QuestController.client.luau")
	has(controller, 'local gui = PlayerGui:FindFirstChild("QuestGui") or PlayerGui:WaitForChild("QuestGui", 8)', "The quest controller uses the saved panel")
	has(controller, "QuestUi.Decorate(gui)", "...and fills in only what is missing")
	has(fs.readFile("audit/build_core.luau"), "{source='src/ui/QuestGui.rbxm',parent={'StarterGui'},name='QuestGui'}", "The build saves the quest panel into StarterGui")

	-- Every screen, from a 480x320 phone to 4K.
	local design = QuestUi.Capture(saved)
	local function fits(width, height, touch)
		return QuestUi.Layout(rb.Vector2.new(width, height), touch, design)
	end
	for _, screen in { { 1920, 1022 }, { 1280, 662 }, { 3840, 2102 }, { 1366, 710 } } do
		local layout = fits(screen[1], screen[2], false)
		assert(not layout.Compact, screen[1] .. "x" .. screen[2] .. ": a computer shows the designer's layout")
	end
	assert(fits(899, 600, false).Compact, "A window under 900 px scrolls its cards")
	assert(not fits(1366, 974, true).Compact, "A big tablet whose cards are wide enough keeps the designer's layout")
	for _, screen in { { 844, 332 }, { 480, 320 }, { 740, 302 }, { 390, 780 }, { 1024, 720 }, { 667, 318 } } do
		local name = screen[1] .. "x" .. screen[2]
		local layout = fits(screen[1], screen[2], true)
		assert(layout.Compact, name .. ": a phone scrolls the cards")
		local across = 3 * layout.CardWidth + 4 * 14 <= layout.ViewWidth
		assert(across or layout.CardWidth >= QuestUi.MinCardWidth, name .. ": cards that scroll are at least 150 px wide, got " .. layout.CardWidth)
		assert(layout.ButtonHeight >= QuestUi.MinButtonHeight, name .. ": Choose at least 22 px tall, got " .. layout.ButtonHeight)
		assert(layout.CloseSize >= QuestUi.MinCloseSize, name .. ": a close button big enough to tap")
		assert(layout.FrameWidth <= screen[1] * QuestUi.PhoneWidthShare + 1 and layout.FrameHeight <= screen[2] * QuestUi.PhoneHeightShare + 1, name .. ": the panel leaves the edges of the screen free (phones found it enormous)")
		assert(layout.CanvasHeight == layout.ViewHeight, name .. ": the cards fit the window's height, no vertical scroll")
		for index = 2, 3 do
			assert(layout.Cards[index].X - layout.Cards[index - 1].X >= layout.CardWidth, name .. ": the cards do not overlap")
		end
		local rowRight = layout.Cards[3].X + layout.CardWidth / 2
		assert(rowRight <= layout.CanvasWidth and layout.Cards[1].X - layout.CardWidth / 2 >= 0, name .. ": every card is in the scroll")
		assert(layout.Cards[1].Y + layout.CardHeight * (design.Below - 0.5) <= layout.CanvasHeight, name .. ": the buttons are in the scroll")
		assert(layout.Cards[1].Y - layout.CardHeight * (0.5 + design.Above) >= 0, name .. ": the headings are in the scroll")
	end
	local portrait = fits(390, 780, true)
	assert(portrait.CanvasWidth > portrait.ViewWidth and portrait.CanvasHeight == portrait.ViewHeight, "Portrait phones swipe sideways only")
	local tablet = fits(1024, 720, true)
	assert(tablet.CanvasWidth == tablet.ViewWidth and tablet.CardWidth > 260, "A tablet fits all three bigger cards without scrolling")
	local landscape = fits(844, 332, true)
	assert(landscape.CanvasWidth == landscape.ViewWidth, "A landscape phone shows all three cards without scrolling")

	-- Apply moves the cards into the scroll and back to the designer's placement exactly.
	local panel = saved:Clone()
	local placed = QuestUi.Capture(panel)
	QuestUi.Apply(panel, placed, fits(844, 332, true))
	assert(panel.Frame.Scroller.Visible and panel.Frame.Scroller:FindFirstChild("Quest1") and panel.Frame:FindFirstChild("Quest1") == nil, "Phone: the cards are in the scroll")
	QuestUi.Apply(panel, placed, fits(1920, 1022, false))
	assert(not panel.Frame.Scroller.Visible and panel.Frame:FindFirstChild("Quest1"), "Wide: the cards are back")
	for index, card in QuestUi.Cards(panel) do
		assert(card.Position == placed.Cards[index].Position and card.Size == placed.Cards[index].Size, "...where the designer put them")
	end
	print("PASS quests: the designer's panel is saved in every place, current, used, and fits PC, tablets and phones (compact phone window, cards fit its height)")
end
