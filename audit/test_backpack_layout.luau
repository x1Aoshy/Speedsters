--!strict
-- audit/test_backpack_layout.luau
-- The trail/aura menu is authored in the place, not built in code. This checks
-- the authored numbers actually resolve to the card the designer drew, and that
-- BackpackScript never invents a size of its own.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local script_ = fs.readFile("src/common/StarterGui/Backpack/BackpackScript.client.luau")

-- Guard the rule the report was about: no size arithmetic in the controller.
assert(not string.find(script_, "AutomaticCanvasSize", 1, true),
	"BackpackScript must not override the authored canvas sizing")
assert(not string.find(script_, "CellSize", 1, true),
	"BackpackScript must not drive layout cell sizes")
assert(string.find(script_, "releaseAuthoredCardHeight", 1, true),
	"BackpackScript must hand card sizing to the authored aspect constraint")
assert(string.find(script_, "applyMultiplierLabel", 1, true),
	"BackpackScript must fill each card's multiplier from the catalog")

for _, place in ipairs(PlaceFiles.Files("World1", "World2")) do
	local game = roblox.deserializePlace(fs.readFile(place))
	local backpack = game:GetService("StarterGui"):FindFirstChild("Backpack")
	assert(backpack, place .. ": Backpack ScreenGui missing")
	local mainFrame = backpack:FindFirstChild("MainFrame")
	assert(mainFrame, place .. ": Backpack.MainFrame missing")

	local panelRatio = mainFrame:FindFirstChildOfClass("UIAspectRatioConstraint")
	assert(panelRatio, place .. ": MainFrame has no aspect constraint")

	for _, listName in ipairs({ "Trail", "Aura" }) do
		local list = nil
		for _, child in ipairs(mainFrame:GetChildren()) do
			if child.Name == listName and child:IsA("ScrollingFrame") then
				list = child
			end
		end
		assert(list, place .. ": " .. listName .. " ScrollingFrame missing")
		assert(list.AutomaticCanvasSize == Enum.AutomaticSize.None,
			listName .. " must keep the authored fixed canvas")

		local layout = list:FindFirstChildOfClass("UIListLayout")
		assert(layout, listName .. " has no UIListLayout")

		-- Work in units of the panel width; every authored size is relative to it.
		local panelHeight = 1 / panelRatio.AspectRatio
		local listWidth = list.Size.X.Scale
		local listHeight = list.Size.Y.Scale * panelHeight

		local cards = {}
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				table.insert(cards, child)
			end
		end
		assert(#cards == 7, listName .. " should hold exactly the 7 shipped cosmetics, found " .. tostring(#cards))

		local totalHeight = 0
		for _, card in ipairs(cards) do
			local constraint = card:FindFirstChildOfClass("UIAspectRatioConstraint")
			assert(constraint, card.Name .. " has no aspect constraint")
			assert(constraint.AspectType == Enum.AspectType.FitWithinMaxSize,
				card.Name .. " aspect type changed; the layout fix assumes FitWithinMaxSize")

			local maxWidth = card.Size.X.Scale * listWidth

			-- As authored: the card's own height is the binding side, so the card
			-- renders far narrower than the designer drew it.
			local authoredMaxHeight = card.Size.Y.Scale * listHeight
			local authoredWidth = math.min(maxWidth, authoredMaxHeight * constraint.AspectRatio)
			assert(authoredWidth < maxWidth * 0.5,
				card.Name .. " no longer reproduces the squashed authored layout; re-check this test")

			-- After releaseAuthoredCardHeight: height is released, width binds, and
			-- the card resolves to the full authored width at the authored ratio.
			local fixedMaxHeight = 1 * listHeight
			local fixedWidth = math.min(maxWidth, fixedMaxHeight * constraint.AspectRatio)
			assert(math.abs(fixedWidth - maxWidth) < 1e-6,
				card.Name .. " still cannot reach its authored width")
			totalHeight += fixedWidth / constraint.AspectRatio
		end

		totalHeight += layout.Padding.Scale * listHeight * (#cards - 1)

		-- The authored canvas has to be tall enough to scroll through all of them.
		local canvasHeight = list.CanvasSize.Y.Scale * listHeight
		assert(canvasHeight >= totalHeight - 1e-6, string.format(
			"%s canvas (%.3f) cannot hold 7 full-size cards (%.3f)", listName, canvasHeight, totalHeight))
		assert(canvasHeight <= totalHeight * 1.2, string.format(
			"%s canvas (%.3f) leaves a large empty tail below 7 cards (%.3f)", listName, canvasHeight, totalHeight))
	end

	-- The lower of a card's two labels is its speed multiplier, and BackpackScript
	-- refills it from the catalog. Prove the authored text really had drifted, so
	-- this stays a test and not a tautology.
	local drifted = 0
	local catalogByText = {}
	do
		local catalogSource = fs.readFile("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau")
		for id, multiplier in string.gmatch(catalogSource, 'Id = "(%w+)".-SpeedMultiplier = ([%d%.]+)') do
			catalogByText[id] = tonumber(multiplier)
		end
	end
	assert(catalogByText.Trail07 == 25 and catalogByText.Aura07 == 25,
		"Catalog no longer grants x25 for the blue cosmetics; refresh this check")

	for _, listName in ipairs({ "Trail", "Aura" }) do
		for _, child in ipairs(mainFrame:GetChildren()) do
			if child.Name == listName and child:IsA("ScrollingFrame") then
				for _, card in ipairs(child:GetChildren()) do
					if card:IsA("Frame") then
						local lowest = nil
						for _, label in ipairs(card:GetChildren()) do
							if label:IsA("TextLabel") then
								if not lowest or label.Position.Y.Scale > lowest.Position.Y.Scale then
									lowest = label
								end
							end
						end
						assert(lowest and string.find(string.lower(lowest.Text), "speed", 1, true),
							listName .. " card " .. card.Name .. " has no multiplier label to correct")
						if string.find(string.lower(lowest.Text), "x10 speed", 1, true) then
							drifted += 1
						end
					end
				end
			end
		end
	end
	assert(drifted >= 2, "Expected the authored blue cards to still read x10; found " .. tostring(drifted))

	print("PASS " .. place .. ": Trail and Aura menus resolve to full-width authored cards inside the authored canvas")
end

-- Phones (2026-09-18, Sung: "way too big on screen"): the cards are drawn smaller, 25-30%,
-- keeping their shape, so three to four show at once in the list. Worked out on an 844 x 390
-- phone from the authored numbers.
do
	local scale = tonumber(string.match(script_, "local PHONE_CARD_SCALE = ([%d%.]+)"))
	assert(scale and scale >= 0.7 and scale <= 0.75, "Cards 25-30% smaller on phones")
	assert(string.find(script_, "fitCardsForPhones(trailFrame)", 1, true) and string.find(script_, "fitCardsForPhones(auraFrame)", 1, true), "...in both lists")
	local game = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
	local mainFrame = game:GetService("StarterGui").Backpack.MainFrame
	local list = mainFrame:FindFirstChild("Trail")
	local card = nil
	for _, child in list:GetChildren() do
		if child:IsA("Frame") and child:FindFirstChildOfClass("UIAspectRatioConstraint") then
			card = child
			break
		end
	end
	local screenW, screenH = 844, 390
	local ratio = mainFrame:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio
	local panelW = math.min(mainFrame.Size.X.Scale * screenW, mainFrame.Size.Y.Scale * screenH * ratio)
	local panelH = panelW / ratio
	local listW, listH = list.Size.X.Scale * panelW, list.Size.Y.Scale * panelH
	local gap = list:FindFirstChildOfClass("UIListLayout").Padding.Scale * list.CanvasSize.Y.Scale * listH
	local cardRatio = card:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio
	local function shown(k)
		local height = card.Size.X.Scale * k * listW / cardRatio
		return listH / (height + gap * k)
	end
	assert(shown(1) < 2.5, ("(the designer's cards: %.1f in view)"):format(shown(1)))
	assert(shown(scale) >= 3 and shown(scale) <= 4.2, ("Three to four cards in view on a phone (%.2f)"):format(shown(scale)))
	print(("PASS phones: cards at %d%% of the designer's size, %.1f in view instead of %.1f"):format(scale * 100, shown(scale), shown(1)))
end

-- Phones (2026-09-19): the SALE badge scales with its card on the card's top-left corner
-- (a fixed 70x18 px tag on the top-right covered the Wins button), and the Backpack and
-- Index panels are larger, the Index in three even columns.
do
	assert(not string.find(script_, "UDim2.new(0, 70, 0, 18)", 1, true), "No fixed-pixel SALE badge")
	assert(string.find(script_, 'saleBadge.Size = UDim2.new(0.17, 0, 0.24, 0)', 1, true) and string.find(script_, "saleBadge.TextScaled = true", 1, true), "The SALE badge scales with its card")
	assert(string.find(script_, "mainFrame.Size = if isPhone() then PHONE_PANEL_SIZE else authoredPanelSize", 1, true), "The Backpack is larger on phones")
	local index = fs.readFile("src/common/StarterGui/Index/IndexScript.client.luau")
	assert(string.find(index, "mainFrame.Size = PHONE_PANEL_SIZE", 1, true) and string.find(index, "local PHONE_COLUMNS = 3", 1, true), "The Index is larger on phones, in three columns")
	print("PASS phones: SALE badge clear of the buy buttons; Backpack and Index sized for phones")
end

print("ALL BACKPACK LAYOUT CHECKS PASSED")
