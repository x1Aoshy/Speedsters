-- test_spin_wheel.luau
-- The Spin Wheel on the designer's layout: the catalog, where the wheel really stops,
-- the capped Wins purchase, and the wiring that keeps it a preview feature.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Catalog = require("../src/common/ReplicatedStorage/Shared/SpinWheelCatalog")
local GuiGeometry = require("../src/common/ReplicatedStorage/Shared/GuiGeometry")
local SpinWheelLayout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")

local function read(path)
	return fs.readFile(path)
end

-- 1. Catalog: six segments for the six-slice art, odds that add up, prices that scale.
do
	assert(#Catalog.Segments == 6, "The designer's wheel art has six slices")
	assert(Catalog.TotalWeight() == 100, "Weights are percentages and must add up to 100")
	local counts = {}
	for index = 1, #Catalog.Segments do
		counts[index] = 0
	end
	for step = 0, 9999 do
		local index = Catalog.Pick(step / 10000)
		counts[index] += 1
	end
	for index, segment in Catalog.Segments do
		assert(counts[index] == segment.Weight * 100, segment.Id .. " must be picked exactly at its weight")
		assert(Catalog.IconImages[segment.Icon], segment.Id .. " needs an icon image")
		assert(Catalog.OddsText(index) == tostring(segment.Weight) .. "%", segment.Id .. " odds text")
		assert(Catalog.ShortLabel(index, { Level = 100, Speed = 1e6 }) ~= "", segment.Id .. " needs a label")
	end
	local settings = { PrizeMultiple = 20, MinimumCost = 50000 }
	assert(Catalog.WinsSpinCost(1, 1, settings, 0.5) == 100000, "Level 1 pays the large prize (5K) x 20")
	assert(Catalog.WinsSpinCost(100, 1, settings, 0.5) == Catalog.RoundNice(Catalog.WinsAmount("Large", 100) * 20), "Level 100 pays its large prize x 20")
	assert(Catalog.WinsSpinCost(100, 32, settings, 0.5) > Catalog.WinsSpinCost(100, 1, settings, 0.5) * 5, "x32 Wins pays more than 5x")
	assert(Catalog.WinsSpinCost(1, 1, { PrizeMultiple = 1, MinimumCost = 50000 }, 0.5) == 50000, "Never below MinimumCost")
	-- A spin bought with Wins costs far more than the Wins it can pay back on average.
	for _, level in { 1, 50, 100, 1000, 10000 } do
		local expected = 0
		for index, segment in Catalog.Segments do
			if segment.Kind == "Wins" then
				expected += Catalog.WinsAmount(segment.Tier, level) * segment.Weight / 100
			end
		end
		assert(Catalog.WinsSpinCost(level, 1, settings, 0.5) > expected * 10, "Level " .. level .. ": a Wins spin must be a Wins sink")
	end
	print("PASS catalog: six weighted segments, exact odds, Wins price scales and stays a sink")
end

-- 2. Where the wheel stops: rotate the designer's real tree and measure the paid prize.
do
	local roots = roblox.deserializeModel(read("design/ui/SpinWheelAndEarnings.rbxm"))
	local gui = roots[1]:FindFirstChild("SpinWheel")
	local holder = gui:FindFirstChild("Frame")
	local wheel = holder:FindFirstChild("Spin Wheel")
	local hub = wheel:FindFirstChild("Spin")
	local ratio = holder:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio
	local wheelWidth, wheelHeight = GuiGeometry.SizeIn(holder, wheel, ratio, 1)
	local wheelCenter = GuiGeometry.CenterIn(holder, wheel, ratio, 1)
	local arrowImage = holder:FindFirstChild("Arrow"):FindFirstChildOfClass("ImageLabel")
	local pointer = GuiGeometry.AngleAround(wheelCenter, GuiGeometry.CenterIn(holder, arrowImage, ratio, 1))
	assert(math.abs(GuiGeometry.DeltaDegrees(pointer, 0)) < 5, "The arrow sits at the top of the wheel")

	local middle = { x = wheelWidth / 2, y = wheelHeight / 2 }
	local slots = {}
	for _, child in hub:GetChildren() do
		if string.match(child.Name, "^Slice%d+$") then
			local label = child:FindFirstChildOfClass("TextLabel")
			table.insert(slots, { Label = label, Angle = GuiGeometry.AngleAround(middle, GuiGeometry.CenterIn(wheel, label, wheelWidth, wheelHeight)) })
		end
	end
	assert(#slots == #Catalog.Segments, "Every catalog segment needs a slice on the art")
	local halfSector = 180 / #slots
	table.sort(slots, function(a, b)
		return (a.Angle + halfSector) % 360 < (b.Angle + halfSector) % 360
	end)
	for index, slot in slots do
		local ideal = (index - 1) * 360 / #slots
		assert(math.abs(GuiGeometry.DeltaDegrees(slot.Angle, ideal)) < 8, string.format("Slice %d sits at %.1f, expected near %.0f", index, slot.Angle, ideal))
	end

	-- The controller's landing rule, applied to the real tree.
	local source = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	assert(string.find(source, "local target = (POINTER_ANGLE - slot.Angle + jitter) % 360", 1, true), "Landing rule changed; update this test")
	assert(string.find(source, "local jitter = (math.random() - 0.5) * halfSector", 1, true), "Jitter rule changed; update this test")
	for index, slot in slots do
		for _, jitter in { -halfSector / 2, 0, halfSector / 2 } do
			local rotation = (pointer - slot.Angle + jitter) % 360
			wheel.Rotation = rotation
			local shown = GuiGeometry.AngleAround(wheelCenter, GuiGeometry.CenterIn(holder, slot.Label, ratio, 1))
			local offset = GuiGeometry.DeltaDegrees(shown, pointer)
			assert(math.abs(offset) <= halfSector / 2 + 0.5, string.format(
				"Segment %d with jitter %.0f stops %.1f degrees from the arrow", index, jitter, offset))
			-- And no other prize is closer to the arrow.
			for otherIndex, other in slots do
				if otherIndex ~= index then
					local otherShown = GuiGeometry.AngleAround(wheelCenter, GuiGeometry.CenterIn(holder, other.Label, ratio, 1))
					assert(math.abs(GuiGeometry.DeltaDegrees(otherShown, pointer)) > math.abs(offset), "Another prize sat closer to the arrow")
				end
			end
		end
	end
	print(string.format("PASS geometry: arrow at %.1f deg, every prize lands under it on the real rotated tree", pointer))

	-- The packs the Config names are buttons the designer drew.
	local row = gui:FindFirstChild("Button")
	local configSource = read("src/common/ReplicatedStorage/Shared/Config.luau")
	for _, button in { "X1", "X3" } do
		assert(row:FindFirstChild(button), "Designer row has no " .. button)
		assert(string.find(configSource, 'Button = "' .. button .. '"', 1, true), "Config pack must drive " .. button)
	end
	assert(row:FindFirstChild("Claim") and row:FindFirstChild("TextLabel"), "Spin button and countdown label must exist")
end

-- 3. The Wins purchase: two an hour, atomic with the debit and the ticket.
do
	local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
	local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
	local now = 5000000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local store = Adapter.CreateMock({ Player_91 = { Version = 306, Speed = 1, Wins = 1000000 } })
	local actor = Actor.new({ userId = 91, sessionId = "spinwins", storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok)
	local handle = opened.value
	local serial = 0
	local function buy(cost)
		serial += 1
		return actor:Commit(handle, {
			operationId = "spinwins-" .. serial,
			fingerprint = "spinwins",
			commands = {
				{ kind = "DebitWins", amount = cost },
				{ kind = "RecordWinsSpin", window = 3600, limit = 2 },
				{ kind = "GrantSpinTickets", amount = 1 },
			},
		})
	end
	local function profile()
		return actor:Inspect(handle).value.profile
	end
	assert(buy(300000).kind == "Committed", "First Wins spin of the hour")
	now += 60
	assert(buy(300000).kind == "Committed", "Second Wins spin of the hour")
	now += 60
	local third = buy(300000)
	assert(third.kind == "Rejected", "A third Wins spin inside the hour must be refused")
	assert(profile().Wins == 400000 and profile().SpinTickets == 2, "A refused purchase spends nothing and grants nothing")
	now += 3600
	assert(buy(300000).kind == "Committed", "The window starts over after an hour")
	assert(profile().SpinWinsWindowCount == 1 and profile().SpinWinsWindowStart == now, "A new window opens at that purchase")
	local broke = buy(300000)
	assert(broke.kind == "Rejected", "Not enough Wins")
	assert(profile().SpinWinsWindowCount == 1 and profile().SpinTickets == 3, "A purchase without the Wins must not use up the hourly limit")
	now += 30
	assert(actor:Release(handle).kind == "Released")
	local again = Actor.new({ userId = 91, sessionId = "spinwins-2", storeAdapter = store, clock = clock })
	local reopened = again:Open()
	assert(reopened.ok)
	local loaded = again:Inspect(reopened.value).value.profile
	assert(loaded.SpinWinsWindowCount == 1 and loaded.SpinTickets == 3 and loaded.Wins == 100000, "The hourly limit survives a rejoin")
	print("PASS Wins spins: two per hour, atomic with the debit and the ticket, and saved across rejoins")
end

-- 4. Wiring.
do
	local service = read("src/common/ServerScriptService/Economy/SpinWheelService.server.luau")
	assert(string.find(service, "FeatureGate.IsPreviewPlayer(player)", 1, true), "The service serves preview players only")
	assert(string.find(service, '{ kind = "DebitWins", amount = cost },\n\t\t\t{ kind = "RecordWinsSpin", window = WINS_WINDOW, limit = WINS_LIMIT },\n\t\t\t{ kind = "GrantSpinTickets", amount = 1 },', 1, true),
		"Debit, limit and ticket must travel in one transaction")
	assert(string.find(service, "if WINS_ENABLED and allowed", 1, true), "Wins spins follow the paid random items policy too")
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	assert(string.find(controller, 'PlayerGui:WaitForChild("SpinWheelGui")', 1, true), "The panel is the saved designer layout")
	assert(string.find(controller, "FeatureGate.IsPreviewPlayer(player)", 1, true), "The panel is a preview feature")
	local extras = read("src/common/ReplicatedStorage/Shared/SpinWheelExtras.luau")
	assert(string.find(extras, "shape.Size = UDim2", 1, true), "The panel's extras size their own slice shapes")
	assert(string.find(controller, "SpinWheelExtras.Decorate(gui, settings.Products, SpinWheelLayout, SpinWheelCatalog)", 1, true), "...added by the controller where the saved panel lacks them")
	for _, authored in { "wheelHolder.Size", "spinButton.Size", "wheel.Size" } do
		assert(not string.find(controller, authored .. " =", 1, true), authored .. " is the designer's; do not resize it in code")
	end
	-- The row is the designer's everywhere but phones and tablets, where the compact layout
	-- stretches it over the screen (SpinWheelLayout.Compact), and it goes back to its size.
	local _, rowSizes = string.gsub(controller, "row%.Size = ", "")
	assert(rowSizes == 2, "row.Size is set only by the compact layout and when restoring the designer's")
	assert(string.find(controller, "row.Size = UDim2.fromOffset(screen.X, screen.Y)", 1, true), "Compact stretches the row")
	assert(string.find(controller, "row.Size = authoredRow.Size", 1, true), "...and the designer's size comes back")
	assert(string.find(controller, "SpinWheelLayout.UseCompact(viewport.X, viewport.Y, UserInputService.TouchEnabled)", 1, true), "Compact on touch screens and short windows only")
	print("PASS wiring: preview gate, one transaction per Wins spin, designer layout left at its sizes outside compact")
end

-- 5. Slice colours: every point of a slice shows that slice's rarity colour, the edges
-- are straight, and nothing spills past the ring.
do
	local roots = roblox.deserializeModel(read("design/ui/SpinWheelAndEarnings.rbxm"))
	local gui = roots[1]:FindFirstChild("SpinWheel")
	local measure = SpinWheelLayout.Measure(gui:FindFirstChild("Frame"))
	local pieces = SpinWheelLayout.SlicePieces(measure)
	local centre = measure.ArtCenter
	local radius = measure.ArtRadius * SpinWheelLayout.ColourRadiusShare

	local function corners(piece)
		local cx, cy = piece.X * measure.WheelWidth, piece.Y * measure.WheelHeight
		local w, h = piece.Width * measure.WheelWidth, piece.Height * measure.WheelHeight
		local r = math.rad(piece.Rotation)
		local list = {}
		for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local dx, dy = c[1] * w / 2, c[2] * h / 2
			table.insert(list, { x = cx + dx * math.cos(r) - dy * math.sin(r), y = cy + dx * math.sin(r) + dy * math.cos(r) })
		end
		return list
	end
	local function covers(piece, x, y)
		local cx, cy = piece.X * measure.WheelWidth, piece.Y * measure.WheelHeight
		local r = math.rad(-piece.Rotation)
		local dx, dy = x - cx, y - cy
		local lx, ly = dx * math.cos(r) - dy * math.sin(r), dx * math.sin(r) + dy * math.cos(r)
		return math.abs(lx) <= piece.Width * measure.WheelWidth / 2 + 1e-9 and math.abs(ly) <= piece.Height * measure.WheelHeight / 2 + 1e-9
	end

	local ringOuter = radius * (1 + 2 * SpinWheelLayout.RingWidthShare)
	local fills = 0
	for _, piece in pieces do
		if piece.Kind == "Fill" then
			fills += 1
			for _, corner in corners(piece) do
				local distance = math.sqrt((corner.x - centre.x) ^ 2 + (corner.y - centre.y) ^ 2)
				assert(distance <= ringOuter, string.format("A fill reaches %.3f of the radius, past the ring", distance / radius))
			end
		end
	end
	assert(fills > 0, "Slices need fills")

	local separatorHalf = measure.ArtRadius * SpinWheelLayout.SeparatorWidthShare / 2
	local dotRadius = measure.ArtRadius * SpinWheelLayout.DotRadiusShare
	local checked = 0
	for index = 1, #measure.Slots do
		local middle = measure.SectorOffset + (index - 1) * measure.SectorDegrees
		for offset = -29.5, 29.5, 1.5 do
			for share = 0.05, 0.99, 0.02 do
				local r = radius * share
				local angle = math.rad(middle + offset)
				local x, y = centre.x + math.sin(angle) * r, centre.y - math.cos(angle) * r
				-- Distance to the nearer slice edge, measured straight across.
				local edge = math.min(
					math.abs(r * math.sin(math.rad(offset + measure.SectorDegrees / 2))),
					math.abs(r * math.sin(math.rad(measure.SectorDegrees / 2 - offset)))
				)
				if r > dotRadius and edge > separatorHalf then
					local top = nil
					for _, piece in pieces do
						if piece.Kind == "Fill" and covers(piece, x, y) then
							top = piece
						end
					end
					assert(top ~= nil, string.format("Slice %d is not coloured at %.1f deg, radius %.2f", index, middle + offset, share))
					assert(top.Sector == index, string.format(
						"Slice %d shows slice %d's colour at %.1f deg, radius %.2f", index, top.Sector, middle + offset, share))
					checked += 1
				end
			end
		end
	end

	-- Rarity gradients: common green, big prizes purple and gold, rare light blue, and no
	-- two neighbours alike.
	assert(Catalog.RarityGradients.Common, "Common needs a gradient")
	assert(Catalog.RarityGradients.Epic, "Epic needs a gradient")
	assert(Catalog.RarityGradients.Legendary, "Legendary needs a gradient")
	assert(Catalog.RarityGradients.Rare, "Rare needs a gradient")
	for _, rarity in { "Common", "Epic", "Legendary", "Rare" } do
		local rimCol = Catalog.RarityColorAt(rarity, 0)
		local centerCol = Catalog.RarityColorAt(rarity, 1)
		assert(#rimCol == 3 and #centerCol == 3, rarity .. " color at stops must be RGB")
	end
	for index, segment in Catalog.Segments do
		local nextSegment = Catalog.Segments[index % #Catalog.Segments + 1]
		assert(segment.Rarity ~= nextSegment.Rarity, segment.Id .. " and " .. nextSegment.Id .. " share a colour side by side")
		if (segment.Kind == "Wins" and segment.Tier == "Small") or segment.Kind == "Speed" then
			assert(segment.Rarity == "Common", segment.Id .. " is common and must be green")
		end
	end
	assert(Catalog.Segments[4].Rarity == "Rare", "The rare prize (Aura 67) is light blue")
	assert(Catalog.RarityGradients.Mythic and Catalog.Segments[6].Rarity == "Mythic", "Tung Tung, the rarest, is red")
	print(string.format("PASS slice colours: %d sample points each show their own slice, nothing past the ring", checked))
end

-- 6. The Wins button on real screens: same size as X1, clear of the wheel, the Robux
-- buttons and the countdown, and fully on screen, tag and caption included.
do
	local roots = roblox.deserializeModel(read("design/ui/SpinWheelAndEarnings.rbxm"))
	local gui = roots[1]:FindFirstChild("SpinWheel")
	local holder = gui:FindFirstChild("Frame")
	local row = gui:FindFirstChild("Button")
	local measure = SpinWheelLayout.Measure(holder)
	local screens = {
		{ "desktop", 1920, 1022 },
		{ "laptop", 1366, 710 },
		{ "tablet", 1024, 710 },
		{ "phone", 750, 354 },
		{ "big phone", 814, 394 },
		{ "ultrawide", 2560, 1022 },
		{ "square", 1000, 1000 },
	}
	local function rectOf(root, node, width, height)
		local centreNode = GuiGeometry.CenterIn(root, node, width, height)
		local w, h = GuiGeometry.SizeIn(root, node, width, height)
		return { left = centreNode.x - w / 2, top = centreNode.y - h / 2, right = centreNode.x + w / 2, bottom = centreNode.y + h / 2, w = w, h = h }
	end
	local function visual(rect, node)
		local minX, minY, maxX, maxY = GuiGeometry.BoundsIn(node, rect.w, rect.h)
		return { left = rect.left + minX, top = rect.top + minY, right = rect.left + maxX, bottom = rect.top + maxY }
	end
	local function overlap(a, b)
		return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
	end
	for _, screen in screens do
		local name, width, height = screen[1], screen[2], screen[3]
		local placement = SpinWheelLayout.WinsButton(measure, gui, row:FindFirstChild("X1"), row:FindFirstChild("TextLabel"), width, height)
		assert(placement.Fits, name .. ": the Wins button does not fit beside the wheel")
		local holderRect = rectOf(gui, holder, width, height)
		local function inHolder(rect)
			local w, h = rect.Width * holderRect.w, rect.Height * holderRect.h
			local cx, cy = holderRect.left + rect.X * holderRect.w, holderRect.top + rect.Y * holderRect.h
			return { left = cx - w / 2, top = cy - h / 2, right = cx + w / 2, bottom = cy + h / 2, w = w, h = h }
		end
		local button = inHolder(placement.Button)
		local x1 = rectOf(gui, row:FindFirstChild("X1"), width, height)
		assert(math.abs(button.w - x1.w) < 0.5 and math.abs(button.h - x1.h) < 0.5, name .. ": the Wins button must match X1's size")
		local drawn = visual(button, row:FindFirstChild("X1"))
		local caption = inHolder(placement.Caption)

		-- The wheel is a circle: its centre and radius on this screen.
		local wheelX = holderRect.left + measure.WheelCenter.x * holderRect.h
		local wheelY = holderRect.top + measure.WheelCenter.y * holderRect.h
		local wheelRadius = measure.ArtRadius * holderRect.h
		for _, box in { { "button", drawn }, { "caption", caption } } do
			local rect = box[2]
			local nearestX = math.clamp(wheelX, rect.left, rect.right)
			local nearestY = math.clamp(wheelY, rect.top, rect.bottom)
			assert(math.sqrt((nearestX - wheelX) ^ 2 + (nearestY - wheelY) ^ 2) > wheelRadius,
				name .. ": the Wins " .. box[1] .. " touches the wheel")
			assert(rect.left >= 0 and rect.top >= 0 and rect.right <= width and rect.bottom <= height,
				name .. ": the Wins " .. box[1] .. " leaves the screen")
			for _, other in { "X3", "Claim", "X1" } do
				local node = row:FindFirstChild(other)
				local otherRect = visual(rectOf(gui, node, width, height), node)
				assert(not overlap(rect, otherRect), name .. ": the Wins " .. box[1] .. " overlaps " .. other)
			end
			local timer = rectOf(gui, row:FindFirstChild("TextLabel"), width, height)
			assert(not overlap(rect, timer), name .. ": the Wins " .. box[1] .. " overlaps the countdown")
			assert(not overlap(rect, rectOf(gui, holder:FindFirstChild("Close"), width, height)), name .. ": overlaps Close")
		end
		assert(caption.top >= drawn.bottom - 0.5, name .. ": the caption must sit under the button")
	end
	print("PASS Wins button: X1's size, clear of the wheel, buttons and countdown on " .. #screens .. " screen shapes")
end

-- 7. Big numbers read like the HUD does.
do
	local cases = {
		{ 999, "999" }, { 1500, "1.5K" }, { 12345, "12.3K" }, { 999999, "1M" }, { 2.6e6, "2.6M" },
		{ 5e15, "5Qa" }, { 5e48, "5Qid" }, { 1e63, "1Vg" },
	}
	for _, case in cases do
		assert(Catalog.FormatNumber(case[1]) == case[2], string.format("%g reads %s, expected %s", case[1], Catalog.FormatNumber(case[1]), case[2]))
	end
	assert(#Catalog.FormatNumber(1e70) <= 9, "Past the last suffix the text stays short")
	print("PASS numbers: suffixes up to Vg, then short scientific notation")
end

-- 8. The X10 pack beside the wheel (right, the Wins spin has the left): X3's size, clear of
-- the wheel, the row's buttons, the countdown, Close and the Wins spin, on every screen.
do
	local roots = roblox.deserializeModel(read("design/ui/SpinWheelAndEarnings.rbxm"))
	local gui = roots[1]:FindFirstChild("SpinWheel")
	local holder = gui:FindFirstChild("Frame")
	local row = gui:FindFirstChild("Button")
	local measure = SpinWheelLayout.Measure(holder)
	local screens = {
		{ "desktop", 1920, 1022 },
		{ "laptop", 1366, 710 },
		{ "tablet", 1024, 710 },
		{ "phone", 750, 354 },
		{ "big phone", 814, 394 },
		{ "ultrawide", 2560, 1022 },
		{ "square", 1000, 1000 },
	}
	local function rectOf(root, node, width, height)
		local centreNode = GuiGeometry.CenterIn(root, node, width, height)
		local w, h = GuiGeometry.SizeIn(root, node, width, height)
		return { left = centreNode.x - w / 2, top = centreNode.y - h / 2, right = centreNode.x + w / 2, bottom = centreNode.y + h / 2, w = w, h = h }
	end
	local function visual(rect, node)
		local minX, minY, maxX, maxY = GuiGeometry.BoundsIn(node, rect.w, rect.h)
		return { left = rect.left + minX, top = rect.top + minY, right = rect.left + maxX, bottom = rect.top + maxY }
	end
	local function overlap(a, b)
		return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
	end
	for _, screen in screens do
		local name, width, height = screen[1], screen[2], screen[3]
		local x3 = row:FindFirstChild("X3")
		local placement = SpinWheelLayout.PackButton(measure, gui, x3, row:FindFirstChild("TextLabel"), width, height)
		local wins = SpinWheelLayout.WinsButton(measure, gui, row:FindFirstChild("X1"), row:FindFirstChild("TextLabel"), width, height)
		assert(placement.Fits, name .. ": X10 does not fit beside the wheel")
		local holderRect = rectOf(gui, holder, width, height)
		local function inHolder(rect)
			local w, h = rect.Width * holderRect.w, rect.Height * holderRect.h
			local cx, cy = holderRect.left + rect.X * holderRect.w, holderRect.top + rect.Y * holderRect.h
			return { left = cx - w / 2, top = cy - h / 2, right = cx + w / 2, bottom = cy + h / 2, w = w, h = h }
		end
		local button = inHolder(placement.Button)
		local x3Rect = rectOf(gui, x3, width, height)
		assert(math.abs(button.w - x3Rect.w) < 0.5 and math.abs(button.h - x3Rect.h) < 0.5, name .. ": X10 matches X3's size")
		local drawn = visual(button, x3)
		local caption = inHolder(placement.Caption)
		local winsDrawn = visual(inHolder(wins.Button), row:FindFirstChild("X1"))
		local wheelX = holderRect.left + measure.WheelCenter.x * holderRect.h
		local wheelY = holderRect.top + measure.WheelCenter.y * holderRect.h
		local wheelRadius = measure.ArtRadius * holderRect.h
		assert(drawn.left > wheelX, name .. ": X10 is on the right of the wheel")
		for _, box in { { "button", drawn }, { "caption", caption } } do
			local rect = box[2]
			local nearestX = math.clamp(wheelX, rect.left, rect.right)
			local nearestY = math.clamp(wheelY, rect.top, rect.bottom)
			assert(math.sqrt((nearestX - wheelX) ^ 2 + (nearestY - wheelY) ^ 2) > wheelRadius, name .. ": the X10 " .. box[1] .. " touches the wheel")
			assert(rect.left >= 0 and rect.top >= 0 and rect.right <= width and rect.bottom <= height, name .. ": the X10 " .. box[1] .. " leaves the screen")
			for _, other in { "X3", "Claim", "X1" } do
				local node = row:FindFirstChild(other)
				assert(not overlap(rect, visual(rectOf(gui, node, width, height), node)), name .. ": the X10 " .. box[1] .. " overlaps " .. other)
			end
			assert(not overlap(rect, rectOf(gui, row:FindFirstChild("TextLabel"), width, height)), name .. ": the X10 " .. box[1] .. " overlaps the countdown")
			assert(not overlap(rect, rectOf(gui, holder:FindFirstChild("Close"), width, height)), name .. ": the X10 " .. box[1] .. " overlaps Close")
			assert(not overlap(rect, winsDrawn), name .. ": the X10 " .. box[1] .. " overlaps the Wins spin")
		end
	end
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	assert(string.find(controller, "SpinWheelLayout.PackButton(measure, gui, row:FindFirstChild(\"X3\")", 1, true), "The panel places X10 with PackButton")
	print("PASS X10: X3's size, right of the wheel, clear of everything on " .. #screens .. " screen shapes")
end

-- 9. The wheel's economy: a free spin every 12 hours, packs at 39 / 99 / 299, a flat 50M
-- Wins spin that stays a sink, and Wins prizes from a lap of the player's world.
do
	local source = read("src/common/ReplicatedStorage/Shared/Config.luau")
	assert(string.find(source, "FreeSpinWindowSeconds = 12 * 3600,", 1, true), "A free spin every 12 hours")
	local prices = {}
	for key, spins, price in string.gmatch(source, 'Key = "(Spins%d+)", Button = "X%d+", ProductId = [%d%w_]+, Spins = (%d+), PriceRobux = (%d+)') do
		prices[key] = { Spins = tonumber(spins), Price = tonumber(price) }
	end
	assert(prices.Spins1 and prices.Spins1.Price == 29, "One spin: 29 R$")
	assert(prices.Spins3 and prices.Spins3.Price == 69 and prices.Spins3.Spins == 3, "Three spins: 69 R$")
	assert(prices.Spins10 and prices.Spins10.Price == 199 and prices.Spins10.Spins == 10, "Ten spins: 199 R$")
	assert(prices.Spins3.Price / 3 < prices.Spins1.Price and prices.Spins10.Price / 10 < prices.Spins3.Price / 3, "Bigger packs are cheaper per spin")
	assert(string.find(source, "FixedCost = 50000000,", 1, true), "The Wins spin costs 50M Wins")
	assert(Catalog.WinsSpinCost(1, 1, { FixedCost = 50000000 }, 0.5) == 50000000 and Catalog.WinsSpinCost(900, 32, { FixedCost = 50000000 }, 0.5) == 50000000, "...flat, whatever the level or multiplier")

	-- Wins prizes follow the world's lap; the spin never pays back what the Wins spin costs.
	local laps = { World1 = 1157020, World2 = 2985000, World3 = 26500000 }
	local shares = { Small = 0.15, Large = 0.6 }
	for world, lap in laps do
		local small = Catalog.WinsAmount("Small", 200, lap, shares)
		local large = Catalog.WinsAmount("Large", 200, lap, shares)
		assert(math.abs(small - lap * 0.15) / (lap * 0.15) < 0.06 and math.abs(large - lap * 0.6) / (lap * 0.6) < 0.06, world .. ": 15% and 60% of a lap")
		local expected = 0
		for _, segment in Catalog.Segments do
			if segment.Kind == "Wins" then
				expected += Catalog.WinsAmount(segment.Tier, 200, lap, shares) * segment.Weight / 100
			end
		end
		assert(expected < lap * 0.2, world .. ": a spin pays under a fifth of a lap on average, so running stays the way to earn")
		assert(50000000 > expected * 10, world .. ": the Wins spin is a sink (costs over 10x what it pays back)")
	end
	local big = Catalog.WinsAmount("Large", 200, laps.World3, shares)
	assert(big >= 10000000 and big <= 25000000, "World 3's big Wins prize is 10M-25M (" .. big .. ")")
	print("PASS wheel economy: free spin every 12 h, 29/69/199 R$, a flat 50M Wins spin, prizes from the world's lap")
end

-- 2026-09-18 pre-launch review: the 50M Wins spin wears the Wins trophy, never the Robux
-- icon it is copied from; and the Skip pass (49 R$) lands the wheel in 0.6 s, prompts its
-- purchase when not owned, and works without it in Studio and for preview accounts.
do
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	local config = read("src/common/ReplicatedStorage/Shared/Config.luau")
	local catalog = read("src/common/ReplicatedStorage/Shared/SpinWheelCatalog.luau")
	assert(string.find(catalog, 'Wins = "rbxassetid://15540211845"', 1, true), "The Wins trophy icon")
	assert(string.find(controller, "winsIcon.Image = SpinWheelCatalog.IconImages.Wins", 1, true), "The Wins spin's icon is set to the Wins trophy at run time")
	assert(string.find(controller, 'Workspace:WaitForChild("SpinWheelLobby")', 1, true), "The lobby wheel uses its authored model")
	assert(not string.find(controller, "wheelHolder:Clone()", 1, true), "The client does not create a duplicate lobby wheel")
	assert(string.find(config, "SkipPriceRobux = 49,", 1, true) and string.find(config, "SkipSpinSeconds = 0.6,", 1, true), "Skip: 49 R$, lands in 0.6 s")
	assert(string.find(controller, "local duration = if skipping then SKIP_SECONDS else", 1, true), "Skipping uses the short landing")
	assert(string.find(controller, "MarketplaceService:UserOwnsGamePassAsync(player.UserId, SKIP_PASS_ID)", 1, true), "Checks real pass ownership")
	assert(string.find(controller, "MarketplaceService.PromptGamePassPurchaseFinished", 1, true), "Unlocks immediately when purchased")
	assert(string.find(config, "SkipGamePassId = 1986854592,", 1, true), "Skip GamePass ID is 1986854592")
	print("PASS the 50M spin shows the Wins trophy; Skip lands in 0.6 s, checks ownership and prompts gamepass purchase (1986854592)")
end

print("ALL SPIN WHEEL CHECKS PASSED")
