-- Draft of the section to add to audit/test_fable_tutorial_portal.luau (after section 4).
-- Here it loads the PATCHED scratch copy; in the suite it uses the `Layout` already loaded.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Layout = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TutorialGuideLayout.luau"), { debugName = "Layout", environment = { math = math } })()
local function pass(message) print("PASS " .. message) end

----------------------------------------------------------------------
-- 4b. The shade around the hole leaves no line
----------------------------------------------------------------------
do
	local NAMES = { "Top", "Bottom", "Left", "Right" }
	-- Area the four rects leave bare outside the hole / cover twice / cover inside the hole,
	-- over the screen plus `margin` px past every edge. Whole-pixel rects only.
	local function audit(rects, fullW, fullH, margin, hole)
		local xs, ys = { -margin, fullW + margin, hole.x, hole.x + hole.w }, { -margin, fullH + margin, hole.y, hole.y + hole.h }
		for _, name in NAMES do
			local r = rects[name]
			table.insert(xs, r.x); table.insert(xs, r.x + r.w); table.insert(ys, r.y); table.insert(ys, r.y + r.h)
		end
		local function edges(list, lo, hi)
			local out, seen = {}, {}
			for _, v in list do
				v = math.clamp(v, lo, hi)
				if not seen[v] then seen[v] = true; table.insert(out, v) end
			end
			table.sort(out)
			return out
		end
		xs, ys = edges(xs, -margin, fullW + margin), edges(ys, -margin, fullH + margin)
		local bare, twice, inside = 0, 0, 0
		for i = 1, #ys - 1 do
			for j = 1, #xs - 1 do
				local cx, cy, area = xs[j], ys[i], (xs[j + 1] - xs[j]) * (ys[i + 1] - ys[i])
				local count = 0
				for _, name in NAMES do
					local r = rects[name]
					if r.w > 0 and r.h > 0 and cx >= r.x and cx < r.x + r.w and cy >= r.y and cy < r.y + r.h then count += 1 end
				end
				if cx >= hole.x and cx < hole.x + hole.w and cy >= hole.y and cy < hole.y + hole.h then
					if count > 0 then inside += area end
				elseif count == 0 then bare += area
				elseif count > 1 then twice += area end
			end
		end
		return bare, twice, inside
	end
	-- What the guide did until 2026-09-20: every frame's Position and Size cut to whole pixels
	-- on its own (UDim2 offsets are int32).
	local function oldShades(fullW, fullH, x, y, w, h)
		local function cut(px, py, pw, ph)
			return { x = math.floor(px), y = math.floor(py), w = math.floor(math.max(0, pw)), h = math.floor(math.max(0, ph)) }
		end
		return { Top = cut(0, 0, fullW, y), Bottom = cut(0, y + h, fullW, fullH - y - h), Left = cut(0, y, x, h), Right = cut(x + w, y, fullW - x - w, h) }
	end

	local checks = 0
	-- the real buttons at 1920x1080 (dimmer pixels: the top bar's 58 px included), then a sweep
	local holes = {
		{ 1920, 1080, 28.667, 594.950, 129.576, 129.576 }, -- Mainhud.LeftSideBar.Backpack
		{ 1920, 1080, 189.819, 594.950, 129.576, 129.576 }, -- Mainhud.LeftSideBar.Evolve
		{ 1920, 1080, 980.815, 317.694, 67.978, 68.661 }, -- Backpack.MainFrame.Aura (tab)
		{ 1920, 1080, 1057.41, 424.27, 133.13, 52.17 }, -- ...Aura.Orange.Orange.WinsPurchase
		{ 1920, 1080, 868.759, 692.279, 182.482, 72.886 }, -- Evolve.Evolve.EvolveButton
		{ 1920, 1080, 873.874, 683.296, 172.253, 69.233 }, -- the same, mid ModalJuice pop (UIScale 0.94)
	}
	for _, viewport in { { 320, 568 }, { 568, 320 }, { 844, 390 }, { 932, 430 }, { 1366, 768 }, { 1365.5, 767.5 }, { 2560, 1440 }, { 3840, 2160 } } do
		for step = 0, 9 do
			local f = step / 10 + 0.037
			table.insert(holes, { viewport[1], viewport[2], viewport[1] * 0.31 + f, viewport[2] * 0.42 + f * 0.7, 40 + f * 3, 30 + f * 5 })
		end
		table.insert(holes, { viewport[1], viewport[2], -12.4, -7.7, 60.2, 50.9 }) -- over the top-left corner
		table.insert(holes, { viewport[1], viewport[2], viewport[1] - 30.3, viewport[2] - 20.6, 60.2, 50.9 }) -- over the bottom-right
	end
	for _, c in holes do
		local fullW, fullH, x, y, w, h = table.unpack(c)
		local rects = Layout.Shades(fullW, fullH, x, y, w, h)
		local hole = rects.Hole
		for _, name in NAMES do
			for _, key in { "x", "y", "w", "h" } do
				assert(rects[name][key] % 1 == 0, name .. "." .. key .. " is not a whole pixel: a UDim2 offset would cut it")
			end
			assert(rects[name].w >= 0 and rects[name].h >= 0, name .. " has a negative size")
		end
		local bare, twice, inside = audit(rects, math.ceil(fullW), math.ceil(fullH), 200, hole)
		assert(bare == 0, ("%d px^2 of the screen stay lit around the hole at %sx%s"):format(bare, fullW, fullH))
		assert(twice == 0, "two shades overlap: they are translucent, that draws a darker line")
		assert(inside == 0, "a shade reaches into the hole")
		-- shared edges
		assert(rects.Top.y + rects.Top.h == hole.y and rects.Left.y == hole.y and rects.Right.y == hole.y)
		assert(rects.Left.y + rects.Left.h == rects.Bottom.y and rects.Bottom.y == hole.y + hole.h)
		assert(rects.Left.x + rects.Left.w == hole.x and rects.Right.x == hole.x + hole.w)
		-- the hole is the wanted rectangle, grown to whole pixels (never shrunk), kept on the canvas
		local wx0, wy0 = math.max(0, x), math.max(0, y)
		local wx1, wy1 = math.min(fullW, x + w), math.min(fullH, y + h)
		assert(hole.x <= wx0 + 0.002 and hole.y <= wy0 + 0.002 and hole.x + hole.w >= wx1 - 0.002 and hole.y + hole.h >= wy1 - 0.002, "the hole cuts into the button")
		assert(hole.x > wx0 - 1.002 and hole.y > wy0 - 1.002 and hole.x + hole.w < wx1 + 1.002 and hole.y + hole.h < wy1 + 1.002, "the hole grew by more than a pixel")
		-- past every screen edge: the top bar (58 px), a notch, a home bar
		assert(rects.Top.y <= -200 and rects.Top.x <= -200 and rects.Top.x + rects.Top.w >= fullW + 200)
		assert(rects.Bottom.y + rects.Bottom.h >= fullH + 200 and rects.Right.x + rects.Right.w >= fullW + 200 and rects.Left.x <= -200)
		checks += 1
	end
	-- no target yet: one unbroken shade
	local none = Layout.Shades(1920, 1080, 0, 0, 0, 0)
	assert(none.Hole.w == 0 or none.Hole.h == 0)
	local bare, twice = audit(none, 1920, 1080, 200, none.Hole)
	assert(bare == 0 and twice == 0, "the shade without a hole has a line in it")
	-- float noise must not move an edge
	local noisy = Layout.Shades(1920, 1080, 49.999996, 120.000004, 100.000004, 59.999996).Hole
	assert(noisy.x == 50 and noisy.y == 120 and noisy.w == 100 and noisy.h == 60, "float noise moved the hole")
	-- the old maths did leave a line on these very buttons, or this test proves nothing
	local oldBare = audit(oldShades(1920, 1080, 28.667, 594.950, 129.576, 129.576), 1920, 1080, 0, { x = 28, y = 594, w = 131, h = 131 })
	assert(oldBare >= 1920, "the old shade maths left no line; this fix is not needed")

	local source = fs.readFile("scratch/wf_tutmask_TutorialGuide.patched.luau") -- SHARED .. "TutorialGuide.luau" in the suite
	assert(source:find("Layout.Shades(", 1, true), "the guide must lay its shades out with Layout.Shades")
	assert(not source:find("full.X - x - w", 1, true), "the guide still cuts every shade on its own")
	assert(source:find("ClipToDeviceSafeArea = false", 1, true), "the dimmer is clipped to the device safe area: notch strips stay lit")
	assert(source:find("hole.x - ox", 1, true), "the ring must sit on the shade's whole-pixel hole")
	pass(checks .. " shade layouts: whole pixels, shared edges, no bare or doubled pixel up to 200 px past the screen, hole = button + pad")
end
