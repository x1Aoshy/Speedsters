--!strict
-- audit/test_gift_panel.luau
-- The gift list has to reach every player in the server, and a button that cannot
-- possibly work must say so instead of doing nothing.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local shopSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")

-- 1. The canvas must grow with the rows.
assert(string.find(shopSource, "list.CanvasSize = UDim2.new(0, 0, height, 0)", 1, true),
	"The gift list must resize its canvas from the row count")
assert(string.find(shopSource, "giftRowHeightScale = template.Size.Y.Scale", 1, true),
	"Row height must come from the authored template, not a number chosen in code")
assert(string.find(shopSource, "ScrollingDirection = Enum.ScrollingDirection.Y", 1, true),
	"A vertical list should not scroll sideways")

-- 2. Thumbnails must not block building the list.
assert(string.find(shopSource, "giftThumbnailCache", 1, true), "Head shots must be cached")
local loopStart = string.find(shopSource, "for _, plr in ipairs(Players:GetPlayers()) do", 1, true)
local loopChunk = string.sub(shopSource, loopStart or 1, (loopStart or 1) + 2400)
local thumbCall = string.find(loopChunk, "GetUserThumbnailAsync", 1, true)
assert(thumbCall, "Expected the thumbnail fetch inside the row loop")
local spawnBefore = string.find(loopChunk, "task.spawn(function()", 1, true)
assert(spawnBefore and spawnBefore < thumbCall,
	"GetUserThumbnailAsync yields; it must not run inline while building rows")

-- 3. Ineligible targets are labelled, not silently dead, and a status message never
-- sits under the Robux icon (that icon is its own image at the centre of the button).
assert(string.find(shopSource, 'showStatus("Not giftable")', 1, true),
	"A card without a gift product must say it cannot be gifted")
assert(string.find(shopSource, "Config.GamePassGiftProducts", 1, true)
	and string.find(shopSource, "local giftable = selectedGift ~= nil and giftProductId > 0", 1, true),
	"A pass is giftable exactly when its gift product exists, decided up front")
assert(string.find(shopSource, "GiftContextRequest:FireServer(plr.UserId,giftProductId,id)", 1, true),
	"The gift request must carry the gift product, not the pass id")
assert(string.find(shopSource, 'reason=="Owned"', 1, true) and string.find(shopSource, 'showStatus("Owned")', 1, true),
	"A recipient who already has the pass must read Owned, not Try again")
assert(not string.find(shopSource, 'priceLabel.Text="Gift unavailable"', 1, true),
	"The old click-to-discover failure message should be gone")
assert(not string.find(shopSource, "Passes can't be gifted", 1, true)
	and not string.find(shopSource, "Could not prepare gift. Retry.", 1, true),
	"Long status sentences shrank to unreadable text in the small gift button")
local showStatusBody = string.match(shopSource, "local function showStatus%(text%)(.-)\n\t\t\tend\n")
assert(showStatusBody and string.find(showStatusBody, "robuxIcon.Visible = false", 1, true),
	"A status message must hide the Robux icon or the icon lands on its letters")
local showPriceBody = string.match(shopSource, "local function showPrice%(%)(.-)\n\t\t\tend\n")
assert(showPriceBody and string.find(showPriceBody, "robuxIcon.Visible = true", 1, true),
	"A price must bring the Robux icon back")
assert(not string.find(shopSource, "desc.ZIndex = math.max(desc.ZIndex, 51)", 1, true),
	"Flattening every gift descendant to one ZIndex put the rows' dark backdrop over the names")

-- 3b. The price keeps the Robux icon in its gap, on one line, for any price and any
-- screen. Run the real layout against a stand-in TextScaled label: the text renders at
-- the largest size that fits the box on one line, and widths scale with that size.
do
	local luau = require("@lune/luau")
	local fnStart = assert(string.find(shopSource, "local GIFT_SPACE", 1, true))
	local fnEnd = assert(string.find(shopSource, "refreshGiftRows = function()", fnStart, true))
	local chunk = string.sub(shopSource, fnStart, fnEnd - 1) .. "\nreturn layoutGiftPrice, GIFT_SPACE"

	local NBSP = utf8.char(160)
	local glyph = { G = 72, i = 26, f = 34, t = 36, ["("] = 34, [")"] = 34, [NBSP] = 27 }
	for digit = 0, 9 do glyph[tostring(digit)] = 62 end
	local function measure100(text)
		local width = 0
		for _, code in utf8.codes(text) do
			width += assert(glyph[utf8.char(code)], "no width for " .. utf8.char(code))
		end
		return width
	end

	local function makeLabel(boxWidth, boxHeight, iconOffset, iconWidth)
		local label = { FontFace = { Family = "Gotham", Weight = "Bold" }, TextWrapped = true, Parent = true }
		label.AbsolutePosition = { X = 0 }
		label.AbsoluteSize = { X = boxWidth }
		setmetatable(label, { __index = function(self, key)
			if key == "TextBounds" then
				local size = math.min(boxHeight, boxWidth / measure100(rawget(self, "Text")) * 100)
				return { X = measure100(rawget(self, "Text")) * size / 100 }
			end
			return nil
		end })
		local icon = {
			AbsolutePosition = { X = boxWidth / 2 + iconOffset - iconWidth / 2 },
			AbsoluteSize = { X = iconWidth },
		}
		return label, icon
	end

	local layout = luau.load(chunk, {
		environment = setmetatable({
			TextService = { GetTextBoundsAsync = function(_, params) return { X = measure100(params.Text) * params.Size / 100 } end },
			RunService = { RenderStepped = { Wait = function() end } },
			Instance = { new = function() return {} end },
		}, { __index = _G }),
	})()

	local geometries = {
		{ Name = "authored", Width = 288, Height = 62, IconOffset = 3.5, Icon = 51 },
		{ Name = "phone", Width = 150, Height = 32, IconOffset = 2, Icon = 26 },
	}
	for _, geometry in geometries do
		for _, price in { "9", "39", "249", "500", "2199", "12999" } do
			local label, icon = makeLabel(geometry.Width, geometry.Height, geometry.IconOffset, geometry.Icon)
			label.Text = ""
			layout(label, icon, price, function() return true end)
			local text = rawget(label, "Text")
			assert(label.TextWrapped == true, "Wrapping stays on: with it off, TextScaled sizes by height and the price overflows the button")
			local pad1, gap, pad2 = string.match(text, "^(.-)Gift" .. NBSP .. "%((.-)" .. price .. "%)(.*)$")
			assert(gap, "Unexpected gift price format: " .. text)
			assert(not string.find(text, " ", 1, true), "Plain spaces can wrap; the layout uses no-break spaces")
			local size = math.min(geometry.Height, geometry.Width / measure100(text) * 100)
			local scale = size / 100
			local total = measure100(text) * scale
			local start = geometry.Width / 2 - total / 2
			local gapStart = start + (measure100(pad1) + measure100("Gift" .. NBSP .. "(")) * scale
			local gapWidth = measure100(gap) * scale
			local gapCenter = gapStart + gapWidth / 2
			local iconCenter = geometry.Width / 2 + geometry.IconOffset
			assert(gapWidth >= geometry.Icon, string.format(
				"%s %s: the gap (%.1f px) is narrower than the icon (%d px): %q", geometry.Name, price, gapWidth, geometry.Icon, text))
			assert(math.abs(gapCenter - iconCenter) <= glyph[NBSP] * scale, string.format(
				"%s %s: the gap centre is %.1f px from the icon centre: %q", geometry.Name, price, gapCenter - iconCenter, text))
		end
	end
	print("PASS gift price keeps the Robux icon inside a centred gap, on one line, for 1 to 5 digit prices")
end

-- 4. Joins and leaves keep the open list honest.
assert(string.find(shopSource, "refreshGiftRowsIfOpen", 1, true),
	"The open gift list must follow players joining and leaving")

-- 5. Against the authored UI: prove the old fixed canvas really could not hold a
-- full server, so this stays a test rather than a tautology.
for _, place in ipairs(PlaceFiles.Files("World1", "World2")) do
	local game = roblox.deserializePlace(fs.readFile(place))
	local shop = game:GetService("StarterGui"):FindFirstChild("Shop")
	assert(shop, place .. ": Shop missing")
	local gift = shop:FindFirstChild("Gift")
	assert(gift, place .. ": Shop.Gift missing")
	local list = gift:FindFirstChild("ScrollingFrame")
	assert(list and list:IsA("ScrollingFrame"), place .. ": gift list missing")

	local template
	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "TemplatePlayer" then
			template = template or child
		end
	end
	assert(template, place .. ": TemplatePlayer row missing")

	local layout = list:FindFirstChildOfClass("UIListLayout")
	assert(layout, place .. ": gift list has no UIListLayout")

	local rowHeight = template.Size.Y.Scale + layout.Padding.Scale
	assert(rowHeight > 0, place .. ": row height is not scale based; re-check the canvas maths")
	local authoredCapacity = math.floor(list.CanvasSize.Y.Scale / rowHeight)
	assert(authoredCapacity < 30, string.format(
		"%s: the authored canvas already holds %d rows, so this check is stale", place, authoredCapacity))

	-- What the fix computes for a full 30-player server.
	local needed = template.Size.Y.Scale * 30 + layout.Padding.Scale * 29
	assert(needed > list.CanvasSize.Y.Scale, string.format(
		"%s: a full server needs %.2f canvas but the authored value is %.2f", place, needed, list.CanvasSize.Y.Scale))

	print(string.format("PASS %s: authored canvas held %d rows; the list now sizes itself", place, authoredCapacity))
end

print("ALL GIFT PANEL CHECKS PASSED")
