-- audit/u4_shop_card.luau (Update 4, community_pass_admin, 2026-09-25)
-- Lune helper the Update 4 build calls: puts the "2X Stamina" card (the 2x Stamina Regen
-- gamepass) into the Shop's Passes list, StarterGui.Shop.Shop.ScrollingFrame.Pass, as a clone
-- of a real sibling pass card: the lightning icon (123961542220277, the Shop's Server tab bolt)
-- wherever that sibling shows its own icon, its title and description, the default price, and
-- Visible = false. ShopController shows it only once U4.StaminaPass.GamePassId is set (and the
-- pass is on), so a build made before the owner creates the pass sells nothing.
-- 2026-09-26 (owner): the card came out misaligned and out of order (QA on phone, PC, tablet and
-- console): it was a clone of "Revive", whose backdrop the designer left 23 % high (Position Y
-- 0.273 where every other card has 0.5) and which has no description line, and it kept
-- LayoutOrder 0 like its siblings, so its place in the list was left to Roblox. Now:
--   * the source is "2X Speed" (then "2X Win", then "Revive" if the designer renames them): the
--     closest sibling, a "2X ..." pass with a title, a description and an icon, so size, padding,
--     UIAspectRatioConstraint, text and icon layout are that sibling's, copied, not typed here;
--   * LayoutOrder is explicit: one past the highest of the other cards, so it is always the last
--     pass card, right after the designer's own;
--   * Insert checks the result against the sibling (every child's Size/Position/AnchorPoint, the
--     card's own Size and aspect, the same Size and aspect as every other pass card) and stops
--     the build if anything differs.
-- The room the card needs below the list (the Treadmills header and cards come after it) is
-- made at runtime by ShopController with Shared/ShopCanvasFlow, which also ends the canvas
-- under the last content; the designer's canvas is left as authored here.
-- Idempotent through the `U4Asset` stamp: a stamped card is replaced by a fresh clone; a
-- "2X Stamina" without the stamp is someone else's and stops the build.
--   local ShopCard = require("./u4_shop_card"); ShopCard.Insert(dm, notes) -> card
local roblox = require("@lune/roblox")

local ShopCard = {}

ShopCard.Name = "2X Stamina"
-- 2026-09-26 (owner): the sibling it is cloned from, first found wins.
ShopCard.Sources = { "2X Speed", "2X Win", "Revive" }
ShopCard.Source = ShopCard.Sources[1]
ShopCard.Stamp = "StaminaPassCard"
ShopCard.Icon = "rbxassetid://123961542220277"
ShopCard.IconAssetId = 123961542220277
-- The header, as its siblings word theirs ("2X Speed", "2X Win"), and the description line
-- under it (ShopController replaces it with the pass's live description, as it does theirs).
ShopCard.Title = "2X Stamina"
ShopCard.Description = "Stamina refills 2X faster"

local function loadConfig()
	local ok, U4 = pcall(require, "../src/common/ReplicatedStorage/Shared/Update4Config")
	return if ok then U4 else nil
end

function ShopCard.PassList(dm)
	local gui = dm:GetService("StarterGui"):FindFirstChild("Shop")
	local window = gui and gui:FindFirstChild("Shop")
	local scroll = window and window:FindFirstChild("ScrollingFrame")
	return scroll and scroll:FindFirstChild("Pass")
end

local function uriOf(image)
	local ok, content = pcall(function()
		return image.ImageContent
	end)
	if ok and typeof(content) == "Content" then
		return tostring(content.Uri or "")
	end
	return ""
end

-- The card's own icon is the image that is neither its backdrop (the first, full-size one) nor
-- the ribbon every card shares: the one the other passes do not have. A card draws it (and its
-- sparkles) with one asset, so every image with that asset is swapped.
local function iconUri(card, siblings)
	local shared = {}
	for _, other in siblings do
		if other ~= card and other:IsA("Frame") then
			for _, child in other:GetChildren() do
				if child:IsA("ImageLabel") then
					shared[uriOf(child)] = true
				end
			end
		end
	end
	local counts = {}
	for _, child in card:GetChildren() do
		if child:IsA("ImageLabel") then
			local uri = uriOf(child)
			if uri ~= "" and not shared[uri] then
				counts[uri] = (counts[uri] or 0) + 1
			end
		end
	end
	local best, bestCount = nil, 0
	for uri, count in counts do
		if count > bestCount then
			best, bestCount = uri, count
		end
	end
	return best
end

-- The designer's pass cards in the list (Frames that are not ours).
function ShopCard.Siblings(list)
	local cards = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("U4Asset") == nil then
			table.insert(cards, child)
		end
	end
	return cards
end

function ShopCard.SourceCard(list)
	for _, name in ShopCard.Sources do
		local card = list:FindFirstChild(name)
		if card and card:IsA("Frame") and card:GetAttribute("U4Asset") == nil then
			return card
		end
	end
	return nil
end

-- A card's "Tittle" labels, header first (the header sits above the description).
function ShopCard.Titles(card)
	local labels = {}
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "Tittle" then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	return labels
end

local function aspectOf(object)
	local shape = object:FindFirstChildOfClass("UIAspectRatioConstraint")
	return shape and shape.AspectRatio or nil
end

-- 2026-09-26 (owner): what "identical to its siblings" means, as a list of differences (empty
-- when the card is right): the card's Size and aspect equal every designer card's; every child
-- GuiObject of the card has the Size, Position and AnchorPoint of the source's child at the same
-- index, with the same class and name.
function ShopCard.LayoutProblems(list, card)
	local problems = {}
	local source = ShopCard.SourceCard(list)
	if not source then
		return { "no source sibling (" .. table.concat(ShopCard.Sources, ", ") .. ")" }
	end
	for _, sibling in ShopCard.Siblings(list) do
		if card.Size ~= sibling.Size then
			table.insert(problems, "Size " .. tostring(card.Size) .. " vs " .. sibling.Name .. " " .. tostring(sibling.Size))
		end
		if aspectOf(card) ~= aspectOf(sibling) then
			table.insert(problems, "aspect " .. tostring(aspectOf(card)) .. " vs " .. sibling.Name .. " " .. tostring(aspectOf(sibling)))
		end
	end
	local mine, theirs = card:GetChildren(), source:GetChildren()
	if #mine ~= #theirs then
		table.insert(problems, ("%d children vs %d in %s"):format(#mine, #theirs, source.Name))
	end
	for index = 1, math.min(#mine, #theirs) do
		local a, b = mine[index], theirs[index]
		if a.ClassName ~= b.ClassName or a.Name ~= b.Name then
			table.insert(problems, ("child %d is %s %s, %s has %s %s"):format(index, a.ClassName, a.Name, source.Name, b.ClassName, b.Name))
		elseif a:IsA("GuiObject") then
			for _, key in { "Size", "Position", "AnchorPoint" } do
				if a[key] ~= b[key] then
					table.insert(problems, ("child %d %s %s %s vs %s"):format(index, a.Name, key, tostring(a[key]), tostring(b[key])))
				end
			end
			if aspectOf(a) ~= aspectOf(b) then
				table.insert(problems, ("child %d %s aspect %s vs %s"):format(index, a.Name, tostring(aspectOf(a)), tostring(aspectOf(b))))
			end
		end
	end
	local highest = -math.huge
	for _, sibling in ShopCard.Siblings(list) do
		highest = math.max(highest, sibling.LayoutOrder)
	end
	if card.LayoutOrder <= highest then
		table.insert(problems, ("LayoutOrder %d is not after the designer's cards (%d)"):format(card.LayoutOrder, highest))
	end
	return problems
end

function ShopCard.Insert(dm, notes)
	local list = ShopCard.PassList(dm)
	assert(list, "[u4_shop_card] StarterGui.Shop.Shop.ScrollingFrame.Pass not found")
	local existing = list:FindFirstChild(ShopCard.Name)
	if existing then
		if existing:GetAttribute("U4Asset") ~= ShopCard.Stamp then
			error("[u4_shop_card] " .. existing:GetFullName() .. " exists without the U4Asset stamp; not replacing it")
		end
		existing:Destroy()
	end
	local source = ShopCard.SourceCard(list)
	assert(source, "[u4_shop_card] none of the sibling pass cards (" .. table.concat(ShopCard.Sources, ", ") .. ") is in the list")
	local icon = iconUri(source, list:GetChildren())
	local card = source:Clone()
	card.Name = ShopCard.Name
	card.Visible = false
	card:SetAttribute("U4Asset", ShopCard.Stamp)
	card:SetAttribute("Purchased", nil)
	-- 2026-09-26 (owner): right after the designer's last pass card, whatever order they use.
	local highest = 0
	for _, sibling in ShopCard.Siblings(list) do
		highest = math.max(highest, sibling.LayoutOrder)
	end
	card.LayoutOrder = highest + 1
	local swapped = 0
	for _, child in card:GetChildren() do
		if child:IsA("ImageLabel") and icon and uriOf(child) == icon then
			child.ImageContent = roblox.Content.fromAssetId(ShopCard.IconAssetId)
			swapped += 1
		end
	end
	local titles = ShopCard.Titles(card)
	if titles[1] then
		titles[1].Text = ShopCard.Title
	end
	if titles[2] then
		titles[2].Text = ShopCard.Description
	end
	local U4 = loadConfig()
	local price = tostring(U4 and U4.StaminaPass and U4.StaminaPass.PriceRobux or 149)
	local buy = card:FindFirstChild("Buy")
	local priceLabel = buy and buy:FindFirstChild("Name")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = price
	end
	card.Parent = list
	local problems = ShopCard.LayoutProblems(list, card)
	if #problems > 0 then
		error("[u4_shop_card] the card is not laid out like its siblings: " .. table.concat(problems, "; "))
	end
	if type(notes) == "table" then
		table.insert(notes, ("shop card %s (from %s, LayoutOrder %d, %d icons)"):format(ShopCard.Name, source.Name, card.LayoutOrder, swapped))
	end
	return card
end

return ShopCard
