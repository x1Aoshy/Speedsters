-- test_opt6_touch_layout.luau
-- The player's own touch layout ("Move controls" in Settings, 2026-09-21):
--   1. the saved string: FormatTouchLayout / ParseTouchLayout round trip, and every string
--      that is not exactly the format is refused, by the client's parser and by the server's
--      ProfileCodec.SanitizeTouchLayout alike;
--   2. PlaceCustom and TouchControls on 8 phones: whatever the wish, a piece is on screen, off
--      Roblox's jump button, a button out of the thumbstick's area, and no two pieces meet;
--      Heat Vision a thumb's width (HeatClearance, 24 px) from Sprint, the shown Burst
--      button, the jump button and the thumbstick (2026-09-25; the editor's drops too);
--   3. the server: SettingsUpdate's allowed list, ProfileReducers.ApplyPreference and the codec
--      keep a valid layout (also across a save and a rejoin) and refuse bad ones; an old
--      profile loads the automatic layout; StatsProjection sends it as the attribute;
--   4. the editor (UI/TouchLayoutEditor) run in a mock: a drag moves a handle, never a real
--      button, and sends nothing; a drop is kept on screen, off the jump button and off the
--      other handles; Swap side and Reset; one remote when it closes on a changed layout;
--   5. the HUD scripts lay Sprint, the stamina bar (the hide / show slide's base too) and the
--      ability buttons out from the attribute; desktops keep the designer's places.
--   lune run audit/test_opt6_touch_layout.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local H = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")
local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")

local EDITOR = "src/common/StarterPlayer/StarterPlayerScripts/UI/TouchLayoutEditor.client.luau"
local HUD = "src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau"
local BURST = "src/common/StarterPlayer/StarterPlayerScripts/Movement/SonicBurstClient.client.luau"
local HEAT = "src/common/StarterPlayer/StarterPlayerScripts/Movement/HeatVisionClient.client.luau"
local SETTINGS = "src/common/StarterPlayer/StarterPlayerScripts/UI/SettingsController.client.luau"
local BOOTSTRAP = "src/common/ServerScriptService/Bootstrap.server.luau"
local PROJECTION = "src/common/ServerScriptService/Services/Stats/StatsProjection.luau"

local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

local PHONES = { { 844, 390 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 896, 414 }, { 932, 430 }, { 915, 412 }, { 800, 360 } }
local EPS = 1e-6
math.randomseed(20260921)

-- The rules every piece keeps (PlaceCustom's margins).
local function legal(r, width, height, solid, label)
	local edge = H.CustomEdgeMargin
	assert(r.Left >= edge - EPS and r.Top >= edge - EPS and r.Right <= width - edge + EPS and r.Bottom <= height - edge + EPS, label .. ": on screen, 8 px in")
	assert(not H.Overlaps(r, H.JumpButton(width, height), H.CustomJumpMargin - 0.5 - EPS), label .. ": 24 px off the jump button")
	if solid then
		assert(not H.Overlaps(r, H.Thumbstick(width, height), H.CustomStickMargin - 0.5 - EPS), label .. ": out of the thumbstick's area")
	end
end

----------------------------------------------------------------------
-- 1. The saved string
----------------------------------------------------------------------
do
	assert(H.FormatTouchLayout({}) == "" and H.FormatTouchLayout(nil) == "" and H.FormatTouchLayout({ Q = { X = 0.5, Y = 0.5 } }) == "", "Nothing moved: the empty string")
	assert(H.ParseTouchLayout("") == nil and Codec.SanitizeTouchLayout("") == "", "The empty string is the automatic layout")
	assert(H.FormatTouchLayout({ S = { X = -3, Y = 7 } }) == "1|S=0.0000,1.0000", "Shares are clamped to the screen")
	assert(H.FormatTouchLayout({ S = { X = -0.0, Y = 0 } }) == "1|S=0.0000,0.0000", "No -0.0000")
	assert(H.FormatTouchLayout({ S = { X = 0 / 0, Y = 0.5 }, B = { X = 0.25, Y = math.huge } }) == "1|B=0.2500,1.0000", "NaN is dropped, infinity clamped")
	assert(H.FormatTouchLayout({ S = 5, B = { X = "x", Y = 1 } }) == "", "Garbage pieces are dropped")
	assert(H.FormatTouchLayout({ T = { X = 0.5, Y = 0.1 }, S = { X = 0.25, Y = 0.75 } }) == "1|S=0.2500,0.7500|T=0.5000,0.1000", "Pieces in the order S B H T")
	-- Round trip.
	local longest = 0
	for _ = 1, 600 do
		local pieces = {}
		for _, key in H.TouchPieces do
			if math.random() < 0.6 then
				pieces[key] = { X = math.random(), Y = math.random() }
			end
		end
		local text = H.FormatTouchLayout(pieces)
		if next(pieces) == nil then
			assert(text == "", "Nothing moved: the empty string")
		else
			local parsed = H.ParseTouchLayout(text)
			assert(parsed, "The formatter's string parses: " .. text)
			for key, at in pieces do
				assert(parsed[key] and math.abs(parsed[key].X - at.X) <= 0.00005 + EPS and math.abs(parsed[key].Y - at.Y) <= 0.00005 + EPS, "Each piece comes back to 4 decimals: " .. text)
			end
			for key in parsed do
				assert(pieces[key], "No piece appears: " .. text)
			end
			assert(H.FormatTouchLayout(parsed) == text, "Format(Parse(s)) == s")
			assert(Codec.SanitizeTouchLayout(text) == text, "The server keeps what the client writes: " .. text)
			longest = math.max(longest, #text)
		end
	end
	local all = H.FormatTouchLayout({ S = { X = 1, Y = 1 }, B = { X = 1, Y = 1 }, H = { X = 1, Y = 1 }, T = { X = 1, Y = 1 } })
	assert(#all == 65 and #all <= H.TouchLayoutMaxLength, "The longest layout fits the length cap")

	-- Everything that is not exactly the format.
	local BAD = {
		"1", "1|", "|S=0.5000,0.5000", "2|S=0.5000,0.5000", "01|S=0.5000,0.5000", " 1|S=0.5000,0.5000",
		"1|S=0.5000,0.5000|", "1||S=0.5000,0.5000", "1|S=0.5,0.5", "1|S=0.50000,0.5000", "1|S=.5000,0.5000",
		"1|S=1.5000,0.5000", "1|S=1.0001,0.5000", "1|S=0.5000,1.0001", "1|S=-0.5000,0.5000", "1|S=2.0000,0.5000",
		"1|s=0.5000,0.5000", "1|X=0.5000,0.5000", "1|SB=0.5000,0.5000", "1|S=0.5000;0.5000", "1|S=0.5000,0.5000,0.5000",
		"1|B=0.5000,0.5000|S=0.5000,0.5000", "1|S=0.5000,0.5000|S=0.6000,0.6000", "1|T=0.5000,0.5000|H=0.5000,0.5000",
		"1|S=nan,0.5000", "1|S=inf,0.5000", "1|S=0x1p-1,0.5000", "1|S=0.5000,0.5000\n", "1|S=0.5000,0.5000\0",
		"1|S=0.5000,0.5000 ", "1|S= 0.5000,0.5000", "1|S=0.5e00,0.5000", "1|S=0,5000,0.5000", "1|S=0.5000",
		"1|S=0.5000,0.5000|B=0.5000,0.5000|H=0.5000,0.5000|T=0.5000,0.5000|T=0.5000,0.5000",
		"1|S=0.5000,0.5000" .. string.rep("|", 70), string.rep("x", 81), "\u{FF11}|S=0.5000,0.5000",
		"1|S=0.5000,0.5000|B=0.5000,0.5000|H=0.5000,0.5000|T=0.5000,0.5000" .. string.rep(" ", 20),
	}
	for _, text in BAD do
		assert(H.ParseTouchLayout(text) == nil, ("The client refuses %q"):format(text))
		assert(Codec.SanitizeTouchLayout(text) == "", ("The server refuses %q"):format(text))
	end
	for _, value in { nil, 1, 0.5, true, false, {}, { S = { X = 0.5, Y = 0.5 } } } do
		assert(H.ParseTouchLayout(value) == nil and Codec.SanitizeTouchLayout(value) == "", "Not a string: refused")
	end

	-- The two parsers agree on mutated strings, and what they accept is canonical.
	local ALPHABET = "0123456789.,|=SBHTX -1"
	local agreed, accepted = 0, 0
	for _ = 1, 4000 do
		local pieces = {}
		for _, key in H.TouchPieces do
			if math.random() < 0.7 then
				pieces[key] = { X = math.random(), Y = math.random() }
			end
		end
		local text = H.FormatTouchLayout(pieces)
		for _ = 1, math.random(0, 3) do
			local at = math.random(1, math.max(1, #text))
			local kind = math.random(1, 4)
			local pick = math.random(1, #ALPHABET)
			local c = string.sub(ALPHABET, pick, pick)
			if kind == 1 then
				text = string.sub(text, 1, at - 1) .. c .. string.sub(text, at + 1)
			elseif kind == 2 then
				text = string.sub(text, 1, at - 1) .. string.sub(text, at + 1)
			elseif kind == 3 then
				text = string.sub(text, 1, at) .. c .. string.sub(text, at + 1)
			else
				text = text .. "|" .. string.sub(text, 3, 18)
			end
		end
		local client = H.ParseTouchLayout(text)
		local server = Codec.SanitizeTouchLayout(text)
		assert(server == "" or server == text, "The server keeps the string or nothing")
		assert((client ~= nil) == (server ~= ""), ("Client and server agree on %q"):format(text))
		if client then
			accepted += 1
			assert(H.FormatTouchLayout(client) == text, ("An accepted string is exactly the formatter's: %q"):format(text))
		end
		agreed += 1
	end
	assert(accepted > 500, "The fuzz kept some valid strings")
	print(("PASS saved string: 600 round trips (longest %d of %d), %d bad strings and %d mutations refused or kept alike by client and server"):format(longest, H.TouchLayoutMaxLength, #BAD, agreed))
end

----------------------------------------------------------------------
-- 2. PlaceCustom and TouchControls on 8 phones
----------------------------------------------------------------------
do
	assert(H.PlaceCustom(390, 844, 46, 46, 0.5, 0.5, true) == nil, "Upright: the automatic layout")
	assert(H.PlaceCustom(300, 200, 46, 46, 0.5, 0.5, true) == nil, "Not measured yet: the automatic layout")
	assert(H.PlaceCustom(844, 354, 46, 46, 0 / 0, 0.5, true) == nil, "NaN: the automatic layout")
	local placed, refused, kept = 0, 0, 0
	for _, s in PHONES do
		for _, topBar in { 0, 36, 58 } do
			local width, height = s[1], s[2] - topBar
			local label = ("%dx%d top %d"):format(s[1], s[2], topBar)
			local sprint = H.SprintButton(width, height)
			local ability = H.AbilityButton(width, height)
			local bar = H.CentreBarRects(width, height)[2]
			local KINDS = {
				{ "S", sprint.Size, sprint.Size, true },
				{ "B", ability.Size, ability.Size, true },
				{ "T", bar.Right - bar.Left, bar.Bottom - bar.Top, false },
			}
			for _, kind in KINDS do
				for _ = 1, 300 do
					local nx, ny = math.random() * 1.2 - 0.1, math.random() * 1.2 - 0.1
					local r = H.PlaceCustom(width, height, kind[2], kind[3], nx, ny, kind[4])
					if r then
						placed += 1
						legal(r, width, height, kind[4], label .. " " .. kind[1])
						assert(math.abs(r.Right - r.Left - kind[2]) < EPS and math.abs(r.Bottom - r.Top - kind[3]) < EPS, "The piece keeps its size")
						-- A wish that is already legal is kept where it is.
						local wish = { Left = nx * width - kind[2] / 2, Top = ny * height - kind[3] / 2 }
						wish.Right, wish.Bottom = wish.Left + kind[2], wish.Top + kind[3]
						local ok = pcall(legal, wish, width, height, kind[4], "")
						if ok and not H.Overlaps(wish, H.JumpButton(width, height), H.CustomJumpMargin) then
							if not kind[4] or not H.Overlaps(wish, H.Thumbstick(width, height), H.CustomStickMargin) then
								kept += 1
								assert(math.abs(r.X - nx * width) < EPS and math.abs(r.Y - ny * height) < EPS, label .. ": a legal wish is kept")
							end
						end
					else
						refused += 1
					end
				end
			end
			-- Swap side: the left preset is legal as it is.
			local preset = H.LeftPreset(width, height)
			for key, at in preset do
				local size = if key == "S" then sprint.Size else ability.Size
				local r = H.PlaceCustom(width, height, size, size, at.X, at.Y, true)
				assert(r and math.abs(r.X - at.X * width) < EPS and math.abs(r.Y - at.Y * height) < EPS, label .. ": the left preset's " .. key .. " is legal as it is")
				assert(r.Right < width / 2, label .. ": the left preset is on the left")
			end
		end
	end
	assert(refused * 50 < placed, ("Almost every wish finds a place (%d refused of %d)"):format(refused, placed + refused))

	-- Whole layouts: the pieces never meet, whatever was saved.
	local layouts = 0
	for _, s in PHONES do
		for _, topBar in { 36, 58 } do
			local width, height = s[1], s[2] - topBar
			local label = ("%dx%d top %d"):format(s[1], s[2], topBar)
			local neighbours = H.TouchNeighbours(s[1], s[2], false, topBar)
			local auto = H.TouchControls(width, height, "", neighbours, true)
			local sprint = H.SprintButton(width, height)
			assert(auto.S.Left == sprint.Left and auto.S.Top == sprint.Top and auto.T == nil, label .. ": no layout, the automatic Sprint and the designer's bar")
			local obstacles = table.clone(neighbours)
			table.insert(obstacles, sprint)
			local burst = H.AbilityButton(width, height, obstacles)
			assert(auto.B.Left == burst.Left and auto.B.Top == burst.Top, label .. ": no layout, the automatic Burst button")
			for trial = 1, 250 do
				local wish = {}
				for _, key in H.TouchPieces do
					if math.random() < 0.6 then
						wish[key] = { X = math.random(), Y = math.random() }
					end
				end
				local burstShown = trial % 3 ~= 0
				local text = H.FormatTouchLayout(wish)
				local plan = H.TouchControls(width, height, text, neighbours, burstShown)
				layouts += 1
				assert(plan.S.Size == sprint.Size and plan.B.Size == burst.Size and plan.H.Size == burst.Size, label .. ": sizes")
				local buttons = { S = plan.S, B = plan.B, H = plan.H }
				for key, r in buttons do
					local where = label .. " " .. key .. " " .. text
					assert(r.Left >= 0 and r.Top >= 0 and r.Right <= width and r.Bottom <= height, where .. ": on screen")
					assert(not H.Overlaps(r, H.JumpButton(width, height), 8 - EPS), where .. ": off the jump button")
					assert(not H.Overlaps(r, H.Thumbstick(width, height)), where .. ": out of the thumbstick")
				end
				if plan.T then
					legal(plan.T, width, height, false, label .. " T " .. text)
				end
				local pairs_ = { { "S", "B" }, { "S", "H" }, { "S", "T" }, { "B", "T" }, { "H", "T" } }
				if burstShown then
					table.insert(pairs_, { "B", "H" })
				end
				for _, pair in pairs_ do
					local a, b = plan[pair[1]], plan[pair[2]]
					if a and b then
						assert(not H.Overlaps(a, b), ("%s: %s and %s never meet (%s)"):format(label, pair[1], pair[2], text))
					end
				end
				-- Heat Vision: a thumb's width from Sprint, the shown Burst button, the jump
				-- button and the thumbstick (2026-09-25).
				local heatNeighbours = { plan.S, H.JumpButton(width, height), H.Thumbstick(width, height), if burstShown then plan.B else nil }
				for _, other in heatNeighbours do
					assert(not H.Overlaps(plan.H, other, H.HeatClearance - EPS), ("%s: Heat Vision a thumb's width from the others (%s)"):format(label, text))
				end
				-- A piece moved to a legal, free place is where the player put it.
				if wish.S then
					local r = H.PlaceCustom(width, height, sprint.Size, sprint.Size, tonumber(string.format("%.4f", wish.S.X)), tonumber(string.format("%.4f", wish.S.Y)), true)
					if r then
						assert(math.abs(plan.S.X - r.X) < EPS and math.abs(plan.S.Y - r.Y) < EPS, label .. ": Sprint where it was put")
					end
				end
			end
		end
	end
	print(("PASS PlaceCustom: %d wishes on 8 phones x 3 top bars, all on screen, off the jump button and the thumbstick (%d legal wishes kept exactly, %d refused); left preset legal; %d whole layouts with no two pieces meeting"):format(placed + refused, kept, refused, layouts))
end

----------------------------------------------------------------------
-- 3. The server: allowed list, reducer, codec, save and rejoin, projection
----------------------------------------------------------------------
do
	local VALID = "1|S=0.2124,0.2294|B=0.2901,0.2294|T=0.5000,0.6200"
	local BAD = { "1|S=0.5,0.5", "2|S=0.5000,0.5000", string.rep("1", 200), "1|B=0.5000,0.5000|S=0.5000,0.5000" }

	-- Bootstrap's SettingsUpdate handler, run as it is.
	local bootstrap = read(BOOTSTRAP)
	local header = "RemoteGuard.Connect(SettingsUpdate, 0.05, function(player: Player, attrName: any, value: any)\n"
	local body = between(bootstrap, header, "\nend)\n\nRemoteGuard.Connect(UpdateLogClosed", "SettingsUpdate handler")
	body = string.sub(body, #header + 1)
	local profile = Codec.CreateDefault()
	local calls = {}
	local DataService = {
		GetHandle = function()
			return { userId = 1 }
		end,
		SetPreference = function(_, key, value)
			table.insert(calls, { key, value })
			return Reducers.ApplyPreference(profile, key, value)
		end,
	}
	local handler = luau.load("return function(player, attrName, value)\n" .. body .. "\nend", {
		environment = { DataService = DataService, type = type, math = math },
	})()
	local player = {
		UserId = 1,
		GetAttribute = function(_, name)
			return name == "DataLoaded"
		end,
	}
	handler(player, "TouchLayout", VALID)
	assert(#calls == 1 and profile.Settings.TouchLayout == VALID, "A valid layout reaches the profile")
	for _, bad in BAD do
		handler(player, "TouchLayout", bad)
		assert(profile.Settings.TouchLayout == VALID, "A bad layout never replaces the saved one: " .. bad)
	end
	local before = #calls
	handler(player, "TouchLayout", 5)
	handler(player, "TouchLayout", true)
	handler(player, "TouchLayout", nil)
	handler(player, "Muted", "true")
	handler(player, "WalkSpeedMode", "Blue")
	handler(player, "EquippedSkin", "Shadow")
	handler(player, "Speed", "1e30")
	assert(#calls == before, "Not a string, or a string for another key: never reaches DataService")
	handler(player, "TouchLayout", "")
	assert(profile.Settings.TouchLayout == "", "Reset: the automatic layout is saved")
	handler(player, "Muted", true)
	assert(profile.Settings.Muted == true, "The other settings still save")
	local notLoaded = { UserId = 1, GetAttribute = function() return false end }
	handler(notLoaded, "TouchLayout", VALID)
	assert(profile.Settings.TouchLayout == "", "Nothing before the profile has loaded")

	-- The reducer on its own.
	local p = Codec.CreateDefault()
	assert(p.Settings.TouchLayout == "", "A new profile: the automatic layout")
	assert(Reducers.ApplyPreference(p, "TouchLayout", VALID).ok and p.Settings.TouchLayout == VALID, "Reducer keeps a valid layout")
	for _, bad in { "1|S=0.5,0.5", 3, true, "x" } do
		assert(not Reducers.ApplyPreference(p, "TouchLayout", bad).ok and p.Settings.TouchLayout == VALID, "Reducer refuses a bad layout")
	end
	assert(Reducers.ApplyPreference(p, "TouchLayout", "").ok and p.Settings.TouchLayout == "", "Reducer keeps the reset")

	-- The codec: additive and backward compatible.
	local old = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { Muted = true, MusicVolume = 40 } })
	assert(old.ok and old.value.Settings.TouchLayout == "" and old.value.Settings.Muted == true and old.value.Settings.MusicVolume == 40, "An old profile loads the automatic layout, its other settings kept")
	local fresh = Codec.Decode(nil)
	assert(fresh.ok and fresh.value.Settings.TouchLayout == "", "A new player: the automatic layout")
	for _, raw in { 5, true, "1|S=0.5,0.5", string.rep("1|S=0.5000,0.5000", 6), { "table" } } do
		local decoded = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { TouchLayout = raw } })
		assert(decoded.ok and decoded.value.Settings.TouchLayout == "", "A corrupt saved layout loads as the automatic one")
	end
	local saved = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { TouchLayout = VALID } })
	assert(saved.ok and saved.value.Settings.TouchLayout == VALID, "A saved layout loads")
	local encoded = Codec.Encode(saved.value)
	assert(encoded.Settings.TouchLayout == VALID, "...and is written back")
	assert(Codec.Decode(encoded).value.Settings.TouchLayout == VALID, "...round trip")

	-- A whole session: set, save on release, rejoin.
	local now = 3000000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local store = Adapter.CreateMock({ Player_91 = { Version = 306, Speed = 1, Wins = 0 } })
	local a = Actor.new({ userId = 91, sessionId = "touch-A", storeAdapter = store, clock = clock })
	local opened = a:Open()
	assert(opened.ok, "Session opens")
	local handle = opened.value
	assert(a:Inspect(handle).value.profile.Settings.TouchLayout == "", "An old profile: the automatic layout")
	assert(a:SetPreference(handle, "TouchLayout", VALID).ok, "SetPreference keeps a valid layout")
	assert(not a:SetPreference(handle, "TouchLayout", "1|S=9.0000,0.5000").ok, "SetPreference refuses a bad one")
	now += 30
	assert(a:Release(handle).kind == "Released", "Session saves on leaving")
	local b = Actor.new({ userId = 91, sessionId = "touch-B", storeAdapter = store, clock = clock })
	local reopened = b:Open()
	assert(reopened.ok, "Rejoin opens")
	assert(b:Inspect(reopened.value).value.profile.Settings.TouchLayout == VALID, "The layout survives a rejoin")

	-- StatsProjection sends every setting, strings too, as an attribute of the same name.
	local projection = read(PROJECTION)
	has(projection, "for settingKey, settingVal in pairs(profile.Settings) do\n\t\t\t\tsetAttributeIfChanged(player, settingKey, settingVal)", "Settings are projected to attributes")
	has(projection, "if instance:GetAttribute(name) ~= value then\n\t\tinstance:SetAttribute(name, value)", "...only when they change")
	print("PASS server: SettingsUpdate takes TouchLayout as a string only, the reducer and the codec keep exactly the format (else the automatic layout), an old profile loads \"\", the layout survives a save and a rejoin and is projected as the attribute")
end

----------------------------------------------------------------------
-- 4. The editor, run in a mock
----------------------------------------------------------------------
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		return {
			Disconnect = function()
				local at = table.find(self.handlers, fn)
				if at then
					table.remove(self.handlers, at)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	return signal
end

local SCREEN = rb.Vector2.new(844, 354)
local GUI_CLASSES = { Frame = true, TextButton = true, TextLabel = true, ImageButton = true, ImageLabel = true }
local Object = {}
local objectMeta = {}
local function mock(class, props)
	local o = setmetatable({ _class = class, _props = {}, _signals = {}, _children = {}, _attributes = {}, _writes = 0 }, objectMeta)
	for key, value in props or {} do
		rawget(o, "_props")[key] = value
	end
	return o
end
local function absoluteSize(o)
	local props = rawget(o, "_props")
	if rawget(o, "_class") == "ScreenGui" then
		return props.AbsoluteSize or SCREEN
	end
	local parent = props.Parent
	local parentSize = parent and absoluteSize(parent) or SCREEN
	local size = props.Size or rb.UDim2.new()
	return rb.Vector2.new(parentSize.X * size.X.Scale + size.X.Offset, parentSize.Y * size.Y.Scale + size.Y.Offset)
end
local function absolutePosition(o)
	local props = rawget(o, "_props")
	if rawget(o, "_class") == "ScreenGui" then
		return rb.Vector2.new(0, 0)
	end
	local parent = props.Parent
	local parentAt = parent and absolutePosition(parent) or rb.Vector2.new(0, 0)
	local parentSize = parent and absoluteSize(parent) or SCREEN
	local position = props.Position or rb.UDim2.new()
	local anchor = props.AnchorPoint or rb.Vector2.new(0, 0)
	local size = absoluteSize(o)
	return rb.Vector2.new(
		parentAt.X + parentSize.X * position.X.Scale + position.X.Offset - anchor.X * size.X,
		parentAt.Y + parentSize.Y * position.Y.Scale + position.Y.Offset - anchor.Y * size.Y
	)
end
objectMeta.__index = function(self, key)
	if key == "AbsoluteSize" then
		return absoluteSize(self)
	elseif key == "AbsolutePosition" then
		return absolutePosition(self)
	elseif key == "ClassName" then
		return rawget(self, "_class")
	end
	local value = rawget(self, "_props")[key]
	if value ~= nil then
		return value
	end
	if Object[key] then
		return Object[key]
	end
	if key == "InputBegan" or key == "Activated" or key == "Event" then
		local signal = newSignal()
		rawget(self, "_props")[key] = signal
		return signal
	end
	return nil
end
objectMeta.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	local old = props[key]
	if key == "Parent" then
		if old then
			local siblings = rawget(old, "_children")
			local at = table.find(siblings, self)
			if at then
				table.remove(siblings, at)
			end
		end
		if value then
			table.insert(rawget(value, "_children"), self)
		end
	end
	props[key] = value
	rawset(self, "_writes", rawget(self, "_writes") + 1)
	if old ~= value then
		local signal = rawget(self, "_signals")[key]
		if signal then
			signal:Fire()
		end
	end
end
function Object:GetPropertyChangedSignal(name)
	local signals = rawget(self, "_signals")
	signals[name] = signals[name] or newSignal()
	return signals[name]
end
function Object:IsA(class)
	local own = rawget(self, "_class")
	return own == class or (class == "GuiObject" and GUI_CLASSES[own] == true) or (class == "GuiButton" and (own == "TextButton" or own == "ImageButton"))
end
function Object:FindFirstChild(name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function Object:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild: " .. name)
	return child
end
function Object:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function Object:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end
function Object:SetAttribute(name, value)
	local attributes = rawget(self, "_attributes")
	local old = attributes[name]
	attributes[name] = value
	rawset(self, "_attributeWrites", (rawget(self, "_attributeWrites") or 0) + 1)
	local signal = rawget(self, "_signals")["@" .. name]
	if signal and old ~= value then
		signal:Fire()
	end
end
function Object:GetAttributeChangedSignal(name)
	return self:GetPropertyChangedSignal("@" .. name)
end
function Object:FireServer(...)
	table.insert(rawget(self, "_props").Sent, { ... })
end

-- The client's world for the editor: a 844 x 390 phone under a 36 px top bar.
local TOPBAR = 36
local playerGui = mock("PlayerGui", { Name = "PlayerGui" })
local player = mock("Player", { Name = "Player" })
playerGui.Parent = player
local mainhud = mock("ScreenGui", { Name = "Mainhud", Enabled = true, AbsoluteSize = SCREEN, ScreenInsets = rb.Enum.ScreenInsets.CoreUISafeInsets })
mainhud.Parent = playerGui
local burstButton = mock("TextButton", { Name = "SonicBurstButton", Visible = true })
burstButton.Parent = mainhud
local heatButton = mock("TextButton", { Name = "HeatVisionButton", Visible = true })
heatButton.Parent = mainhud
rawset(burstButton, "_writes", 0)
rawset(heatButton, "_writes", 0)
local remote = mock("RemoteEvent", { Name = "SettingsUpdate", Sent = {} })
local remotes = mock("Folder", { Name = "Remotes" })
remote.Parent = remotes
local shared = mock("Folder", { Name = "Shared" })
local hudModule = mock("ModuleScript", { Name = "HudErgonomics" })
hudModule.Parent = shared
local menuModule = mock("ModuleScript", { Name = "MenuEvents" })
menuModule.Parent = shared
local replicated = mock("ReplicatedStorage", { Name = "ReplicatedStorage" })
shared.Parent = replicated
remotes.Parent = replicated
local menuEvents = {}
local MenuEvents = {
	HUDVisibilityChanged = { Event = newSignal() },
	Get = function(name)
		menuEvents[name] = menuEvents[name] or { Event = newSignal(), Fire = function(self, ...) self.Event:Fire(...) end }
		return menuEvents[name]
	end,
}
local UIS = { TouchEnabled = true, KeyboardEnabled = false, InputChanged = newSignal(), InputEnded = newSignal() }
local camera = { ViewportSize = rb.Vector2.new(SCREEN.X, SCREEN.Y + TOPBAR) }
local services = {
	GuiService = {
		GetGuiInset = function()
			return rb.Vector2.new(0, TOPBAR), rb.Vector2.new(0, 0)
		end,
	},
	Players = { LocalPlayer = player },
	ReplicatedStorage = replicated,
	UserInputService = UIS,
	Workspace = { CurrentCamera = camera },
}
local env = setmetatable({
	game = {
		GetService = function(_, name)
			return assert(services[name], "service " .. name)
		end,
	},
	Instance = {
		new = function(class)
			return mock(class, { Name = class })
		end,
	},
	require = function(module)
		if module == hudModule then
			return H
		elseif module == menuModule then
			return MenuEvents
		end
		error("unexpected require")
	end,
	UDim2 = rb.UDim2,
	UDim = rb.UDim,
	Vector2 = rb.Vector2,
	Color3 = rb.Color3,
	Enum = rb.Enum,
	Font = rb.Font,
}, { __index = _G })

do
	local source = read(EDITOR)
	luau.load(source, { environment = env })()
	local editEvent = MenuEvents.Get("TouchLayoutEdit")
	local sent = rawget(remote, "_props").Sent
	local width, height = SCREEN.X, SCREEN.Y
	local neighbours = H.TouchNeighbours(camera.ViewportSize.X, camera.ViewportSize.Y, false, TOPBAR)
	assert(playerGui:FindFirstChild("TouchLayoutEditGui") == nil, "Closed: the editor's screen is not even parented")

	local function layout()
		return player:GetAttribute("TouchLayout") or ""
	end
	local gui
	local function handle(key)
		return gui:FindFirstChild("Handle" .. key)
	end
	local function centre(key)
		local position = handle(key).Position
		return rb.Vector2.new(position.X.Offset, position.Y.Offset)
	end
	-- The handles are where the HUD scripts put the real pieces.
	local function checkHandles(label)
		local plan = H.TouchControls(width, height, layout(), neighbours, burstButton.Visible)
		plan.T = plan.T or H.CentreBarRects(width, height)[2]
		-- (Whole pixels: offsets are integers, rounded as the HUD scripts round them.)
		for _, key in H.TouchPieces do
			local r, at = plan[key], centre(key)
			assert(at.X == math.floor((r.Left + r.Right) / 2 + 0.5) and at.Y == math.floor((r.Top + r.Bottom) / 2 + 0.5), label .. ": handle " .. key .. " over its piece")
			local size = handle(key).Size
			assert(math.abs(size.X.Offset - (r.Right - r.Left)) <= 0.5 and math.abs(size.Y.Offset - (r.Bottom - r.Top)) <= 0.5, label .. ": handle " .. key .. " the piece's size")
		end
		for _, a in { "S", "B", "H", "T" } do
			for _, b in { "S", "B", "H", "T" } do
				if a < b then
					assert(not H.Overlaps(plan[a], plan[b]), label .. ": " .. a .. " and " .. b .. " apart")
				end
			end
		end
		for _, key in { "S", "B", "H" } do
			assert(not H.Overlaps(plan[key], H.JumpButton(width, height), 8 - EPS), label .. ": " .. key .. " off the jump button")
			assert(not H.Overlaps(plan[key], H.Thumbstick(width, height)), label .. ": " .. key .. " out of the thumbstick")
		end
		-- Heat Vision a thumb's width from Sprint and the shown Burst button (2026-09-25).
		for _, other in { plan.S, if burstButton.Visible then plan.B else nil } do
			assert(not H.Overlaps(plan.H, other, H.HeatClearance - EPS), label .. ": Heat Vision a thumb's width from the other buttons")
		end
		-- The toolbar's buttons are never under a handle.
		local toolbar = gui:FindFirstChild("Toolbar")
		local at, size = toolbar.AbsolutePosition, toolbar.AbsoluteSize
		local area = { Left = at.X, Top = at.Y, Right = at.X + size.X, Bottom = at.Y + size.Y }
		for _, key in H.TouchPieces do
			assert(not H.Overlaps(area, plan[key]), label .. ": the toolbar is clear of handle " .. key)
		end
	end
	-- A finger: down on a handle, `steps` moves to `target` (a centre), up.
	local attributeWrites = function()
		return rawget(player, "_attributeWrites") or 0
	end
	local function drag(key, target, steps, keepDown)
		local from = centre(key)
		local finger = rb.Vector3.new(from.X + 3, from.Y + TOPBAR - 2, 0)
		local input = { UserInputType = rb.Enum.UserInputType.Touch, Position = finger }
		handle(key).InputBegan:Fire(input)
		local writes, sentBefore, layoutBefore = attributeWrites(), #sent, layout()
		for step = 1, steps do
			local t = step / steps
			input.Position = rb.Vector3.new(finger.X + (target.X - from.X) * t, finger.Y + (target.Y - from.Y) * t, 0)
			UIS.InputChanged:Fire(input)
			-- Moving sends nothing and changes nothing but the handle.
			assert(#sent == sentBefore and attributeWrites() == writes and layout() == layoutBefore, "A drag sends nothing and saves nothing while it moves")
			local at, extent = centre(key), handle(key).AbsoluteSize
			assert(at.X >= extent.X / 2 - 0.5 and at.X <= width - extent.X / 2 + 0.5 and at.Y >= extent.Y / 2 - 0.5 and at.Y <= height - extent.Y / 2 + 0.5, "The handle stays whole on the screen")
		end
		if not keepDown then
			UIS.InputEnded:Fire(input)
		end
		return input
	end

	-- Open.
	editEvent:Fire("Open")
	gui = playerGui:FindFirstChild("TouchLayoutEditGui")
	assert(gui and gui.Enabled and gui.DisplayOrder > 47, "Open: the editor's screen over the HUD and the speedometer")
	assert(gui.ScreenInsets == mainhud.ScreenInsets, "...in the Main HUD's pixels")
	for _, key in H.TouchPieces do
		assert(handle(key) and handle(key).Visible and handle(key).Active, "A handle for " .. key)
	end
	checkHandles("opened")

	-- A tap is not a move: the automatic place is not pinned into the layout.
	local openedLayout, sprintAt = layout(), centre("S")
	drag("S", rb.Vector2.new(sprintAt.X + 2, sprintAt.Y + 1), 1)
	assert(layout() == openedLayout and centre("S") == sprintAt, "A tap on a handle saves nothing and leaves it where it was")
	-- A touch the system took away (it never ends here) does not lock the other handles.
	local burstAt = centre("B")
	local lost = drag("B", rb.Vector2.new(burstAt.X - 40, burstAt.Y - 30), 3, true)
	lost.UserInputState = rb.Enum.UserInputState.Cancel
	drag("S", rb.Vector2.new(sprintAt.X + 1, sprintAt.Y + 2), 1)
	assert(centre("B") == burstAt and layout() == openedLayout, "A lost drag goes back where it started, unsaved")

	-- Sprint up to the top right.
	drag("S", rb.Vector2.new(0.7 * width, 0.2 * height), 60)
	local pieces = H.ParseTouchLayout(layout())
	-- (To the pixel: a handle sits on whole pixels.)
	assert(pieces and pieces.S and math.abs(pieces.S.X - 0.7) * width <= 1 and math.abs(pieces.S.Y - 0.2) * height <= 1, "Sprint's drop is saved where it was put: " .. layout())
	assert(#sent == 0, "A drop saves locally only")
	checkHandles("Sprint moved")

	-- The Burst button onto the jump button: moved off it.
	local jump = H.JumpButton(width, height)
	drag("B", rb.Vector2.new((jump.Left + jump.Right) / 2, (jump.Top + jump.Bottom) / 2), 40)
	pieces = H.ParseTouchLayout(layout())
	local abilitySize = H.AbilityButton(width, height).Size
	local function savedRect(at, w, h)
		local x, y = at.X * width, at.Y * height
		return { Left = x - w / 2, Right = x + w / 2, Top = y - h / 2, Bottom = y + h / 2 }
	end
	assert(pieces.B, "The Burst button's drop is kept, moved: " .. layout())
	assert(not H.Overlaps(savedRect(pieces.B, abilitySize, abilitySize), jump, H.CustomJumpMargin - 1), "A drop on the jump button is saved off it")
	checkHandles("Burst dropped on the jump button")

	-- Heat Vision onto Sprint: refused, back where it was.
	local heatBefore, layoutBefore = centre("H"), layout()
	drag("H", centre("S"), 30)
	assert(layout() == layoutBefore, "A drop on another handle is refused")
	assert(centre("H") == heatBefore, "...and the handle goes back")
	checkHandles("Heat Vision refused")

	-- Heat Vision 12 px short of Sprint (the gap it used to keep): refused too; a thumb's
	-- width away (30 px): kept (2026-09-25).
	local sprintRect = H.TouchControls(width, height, layout(), neighbours, burstButton.Visible).S
	local heatSize = H.AbilityButton(width, height).Size
	heatBefore, layoutBefore = centre("H"), layout()
	drag("H", rb.Vector2.new(sprintRect.Left - 12 - heatSize / 2, sprintRect.Y), 30)
	assert(layout() == layoutBefore and centre("H") == heatBefore, "Heat Vision dropped 12 px from Sprint is refused")
	drag("H", rb.Vector2.new(sprintRect.Left - 30 - heatSize / 2, sprintRect.Y), 30)
	assert(H.ParseTouchLayout(layout()).H, "Heat Vision dropped a thumb's width from Sprint is kept: " .. layout())
	checkHandles("Heat Vision beside Sprint")

	-- The stamina bar, a little higher.
	drag("T", rb.Vector2.new(0.5 * width, 0.62 * height), 30)
	pieces = H.ParseTouchLayout(layout())
	assert(pieces.T and math.abs(pieces.T.Y - 0.62) * height <= 1, "The stamina bar moves: " .. layout())
	local barY = pieces.T.Y
	checkHandles("stamina bar moved")

	-- Swap side: Sprint and the ability buttons to the left thumb, the bar stays.
	local swap = gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Swap side")
	swap.Activated:Fire()
	pieces = H.ParseTouchLayout(layout())
	assert(pieces.S.X < 0.5 and pieces.B.X < 0.5 and pieces.H.X < 0.5 and pieces.T.Y == barY, "Swap side: Sprint, Burst and Heat on the left, the bar kept: " .. layout())
	checkHandles("swapped")
	assert(centre("S").X < width / 2, "Swap side: the handles follow")
	swap.Activated:Fire()
	pieces = H.ParseTouchLayout(layout())
	assert(pieces and pieces.S == nil and pieces.B == nil and pieces.H == nil and pieces.T, "Swap again: back beside the jump button, the bar kept")
	checkHandles("swapped back")

	-- Far off the screen: the handle stays on it, the drop lands on it.
	drag("S", rb.Vector2.new(-900, -900), 20)
	pieces = H.ParseTouchLayout(layout())
	local sprintSize = H.SprintButton(width, height).Size
	assert(pieces.S, "A drop past the screen's corner is kept")
	local corner = savedRect(pieces.S, sprintSize, sprintSize)
	assert(corner.Left >= H.CustomEdgeMargin - 1 and corner.Top >= H.CustomEdgeMargin - 1, "...8 px inside the screen")
	checkHandles("dragged off the screen")

	-- Reset: the automatic layout.
	gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Reset").Activated:Fire()
	assert(layout() == "", "Reset: the automatic layout")
	checkHandles("reset")
	assert(#sent == 0, "Nothing sent while the editor is open")

	-- Done: one remote with the layout.
	drag("S", rb.Vector2.new(0.66 * width, 0.25 * height), 10)
	local final = layout()
	gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Done").Activated:Fire()
	assert(#sent == 1 and sent[1][1] == "TouchLayout" and sent[1][2] == final, "Done sends the layout once")
	assert(Codec.SanitizeTouchLayout(final) == final and final ~= "", "...in the format the server keeps")
	assert(playerGui:FindFirstChild("TouchLayoutEditGui") == nil and not gui.Enabled, "Done closes the editor")
	UIS.InputChanged:Fire({ UserInputType = rb.Enum.UserInputType.Touch, Position = rb.Vector3.new(1, 1, 0) })
	assert(#sent == 1, "Closed: nothing more")

	-- Opened and closed with no change: nothing sent.
	editEvent:Fire("Open")
	checkHandles("reopened")
	gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Done").Activated:Fire()
	assert(#sent == 1, "No change, no remote")

	-- Sprint saved in the middle of the screen: the toolbar makes way for it.
	local saved = layout()
	player:SetAttribute("TouchLayout", "1|S=0.5000,0.4500")
	editEvent:Fire("Open")
	checkHandles("Sprint in the middle")
	assert(math.abs(gui:FindFirstChild("Toolbar").Position.Y.Scale - 0.45) > 0.1, "The toolbar moves off a handle in the middle")
	gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Done").Activated:Fire()
	assert(#sent == 1, "Still no change, no remote")
	player:SetAttribute("TouchLayout", saved)

	-- A menu opening mid-drag closes it, saved once; the finger lifting later does nothing.
	editEvent:Fire("Open")
	drag("S", rb.Vector2.new(0.75 * width, 0.15 * height), 5)
	local dropped = layout()
	assert(dropped ~= final, "A new drop")
	local finger = drag("S", rb.Vector2.new(0.8 * width, 0.12 * height), 5, true)
	MenuEvents.HUDVisibilityChanged.Event:Fire(false)
	assert(#sent == 2 and sent[2][2] == dropped and playerGui:FindFirstChild("TouchLayoutEditGui") == nil, "A menu opening closes the editor, saved as last dropped")
	UIS.InputEnded:Fire(finger)
	assert(#sent == 2 and layout() == dropped, "...once; the finger lifting later changes nothing")

	-- The HUD going away (a cinematic, Hide HUD) closes it too; a hidden HUD does not open it.
	editEvent:Fire("Open")
	gui:FindFirstChild("Toolbar"):FindFirstChild("Buttons"):FindFirstChild("Reset").Activated:Fire()
	mainhud.Enabled = false
	assert(#sent == 3 and sent[3][2] == "" and playerGui:FindFirstChild("TouchLayoutEditGui") == nil, "The HUD switched off closes the editor, saved")
	editEvent:Fire("Open")
	assert(playerGui:FindFirstChild("TouchLayoutEditGui") == nil, "No editor over a switched-off HUD")
	mainhud.Enabled = true

	-- The editor never touched a real button.
	assert(rawget(burstButton, "_writes") == 0 and rawget(heatButton, "_writes") == 0, "The real buttons are never touched by the editor")

	-- Its source: one FireServer, in close(), nothing per frame.
	local _, fires = string.gsub(source, "FireServer", "")
	assert(fires == 1, "One FireServer in the editor")
	has(between(source, "local function close()", "\nend\n", "close()"), "remote:FireServer(ATTRIBUTE, text)", "...sent from close()")
	for _, line in string.split(source, "\n") do
		local code = string.gsub(line, "%-%-.*$", "")
		for _, perFrame in { "RenderStepped", "Heartbeat", "Stepped", "BindToRenderStep", "task.wait", "wait(" } do
			assert(not string.find(code, perFrame, 1, true), "The editor has no per-frame loop: " .. perFrame)
		end
		assert(not string.find(code, "%f[%w]while%f[%W]") and not string.find(code, "%f[%w]repeat%f[%W]"), "The editor has no loop that waits: " .. line)
	end
	local moving = between(source, "UserInputService.InputChanged:Connect(function(input)", "\nend)\n", "InputChanged")
	assert(not string.find(moving, "FireServer", 1, true) and not string.find(moving, "SetAttribute", 1, true), "A move neither sends nor saves")
	assert(not string.find(source, "MobileSprint", 1, true), "The editor never reaches for the real Sprint button")
	print(("PASS editor: handles over the pieces on a 844x390 phone, drags move only the handle and send nothing, drops kept on screen and off the jump button and the other handles, Swap side / Reset, one remote on Done / a menu / the HUD going away (%d sent in all), none without a change"):format(#sent))
end

----------------------------------------------------------------------
-- 5. The HUD scripts lay the pieces out from the attribute
----------------------------------------------------------------------
do
	local hud = read(HUD)
	local chunk = between(hud, "local function touchLayout()", "-- The editor sets the attribute on every drop", "MainHUDController's touch layout")
	chunk ..= "\nreturn layoutSprint, layoutStaminaBar, function() return mobileSprintBasePos, speedsterBarBasePos end, function(v) hudVisible = v end"
	local authoredBar = rb.UDim2.new(0.5, 0, 0.857061, 0)
	local authoredSprint = { AnchorPoint = rb.Vector2.new(1, 1), Size = rb.UDim2.new(0.1, 0, 0.1, 0), Corner = rb.UDim.new(0.2, 0), Position = rb.UDim2.new(0.8, 0, 0.8, 0) }
	local sprintButton = mock("TextButton", { Name = "MobileSprint", Position = authoredSprint.Position })
	local bar = mock("Frame", { Name = "SpeedsterBar", Position = authoredBar })
	local hudPlayer = mock("Player", { Name = "Player" })
	local uis = { TouchEnabled = true }
	local layoutSprint, layoutStaminaBar, bases, setVisible = luau.load(chunk, {
		environment = setmetatable({
			UserInputService = uis,
			player = hudPlayer,
			mobileSprint = sprintButton,
			authoredSprint = authoredSprint,
			sprintCorner = mock("UICorner", { CornerRadius = authoredSprint.Corner }),
			mainhud = { AbsoluteSize = SCREEN },
			HudErgonomics = H,
			mobileSprintBasePos = authoredSprint.Position,
			hudVisible = true,
			speedsterBar = bar,
			authoredSpeedsterBarPos = authoredBar,
			speedsterBarBasePos = authoredBar,
			UDim2 = rb.UDim2,
			UDim = rb.UDim,
			Vector2 = rb.Vector2,
		}, { __index = _G }),
	})()
	local width, height = SCREEN.X, SCREEN.Y
	local function run()
		layoutSprint()
		layoutStaminaBar()
		return bases()
	end
	local function offsetCentre(position)
		return position.X.Scale == 0 and position.Y.Scale == 0 and rb.Vector2.new(position.X.Offset, position.Y.Offset)
	end

	-- No layout: the automatic Sprint, the designer's bar, and nothing written to the bar.
	rawset(bar, "_writes", 0)
	local sprintBase, barBase = run()
	local auto = H.SprintButton(width, height)
	assert(offsetCentre(sprintBase) == rb.Vector2.new(math.floor(auto.X + 0.5), math.floor(auto.Y + 0.5)), "No layout: Sprint beside the jump button")
	assert(barBase == authoredBar and rawget(bar, "_writes") == 0, "No layout: the designer's bar, untouched")

	-- A saved layout: Sprint and the bar where the player put them.
	local text = "1|S=0.2500,0.3000|T=0.5000,0.6200"
	hudPlayer:SetAttribute("TouchLayout", text)
	sprintBase, barBase = run()
	local plan = H.TouchControls(width, height, text)
	assert(offsetCentre(sprintBase) == rb.Vector2.new(math.floor(plan.S.X + 0.5), math.floor(plan.S.Y + 0.5)) and math.abs(plan.S.X - 0.25 * width) < 1, "Sprint where the player put it")
	assert(offsetCentre(barBase) == rb.Vector2.new(math.floor(plan.T.X + 0.5), math.floor(plan.T.Y + 0.5)) and math.abs(plan.T.Y - 0.62 * height) < 1, "The stamina bar where the player put it")
	assert(bar.Position == barBase and sprintButton.Position == sprintBase, "...drawn there while the HUD shows")
	assert(sprintButton.AnchorPoint == rb.Vector2.new(0.5, 0.5), "Placed by its centre")
	rawset(bar, "_writes", 0)
	run()
	assert(rawget(bar, "_writes") == 0, "The same layout again: nothing written")

	-- While a menu hides the HUD: the base moves (the show slide goes there), the bar does not.
	setVisible(false)
	bar.Position = rb.UDim2.new(barBase.X.Scale, barBase.X.Offset, 1.4, 0)
	hudPlayer:SetAttribute("TouchLayout", "1|T=0.5000,0.5500")
	local _, hiddenBase = run()
	assert(math.abs(hiddenBase.Y.Offset - 0.55 * height) <= 1 and math.abs(bar.Position.Y.Scale - 1.4) < 1e-5, "Hidden HUD: the base follows the layout, the bar stays down")
	setVisible(true)

	-- A layout that does not fit this screen, or garbage: the automatic places.
	hudPlayer:SetAttribute("TouchLayout", "not a layout")
	sprintBase, barBase = run()
	assert(offsetCentre(sprintBase) == rb.Vector2.new(math.floor(auto.X + 0.5), math.floor(auto.Y + 0.5)) and barBase == authoredBar, "Garbage: the automatic places")
	hudPlayer:SetAttribute("TouchLayout", "1|S=0.9290,0.8446")
	sprintBase = run()
	local jump = H.JumpButton(width, height)
	local at = offsetCentre(sprintBase)
	local placed = { Left = at.X - auto.Size / 2, Top = at.Y - auto.Size / 2, Right = at.X + auto.Size / 2, Bottom = at.Y + auto.Size / 2 }
	assert(not H.Overlaps(placed, jump, H.CustomJumpMargin - 1), "A Sprint saved on the jump button is moved off it")

	-- Desktops and consoles: the designer's places, whatever is saved.
	hudPlayer:SetAttribute("TouchLayout", text)
	uis.TouchEnabled = false
	rawset(bar, "_writes", 0)
	run()
	rawset(bar, "_writes", 0)
	sprintBase, barBase = run()
	assert(sprintBase == authoredSprint.Position and barBase == authoredBar and rawget(bar, "_writes") == 0, "Keyboard / gamepad: the designer's places")
	uis.TouchEnabled = true

	-- The hide / show slide leaves from and comes back to the base; every change re-lays out.
	has(hud, "local target = visible and speedsterBarBasePos or UDim2.new(speedsterBarBasePos.X.Scale, speedsterBarBasePos.X.Offset, 1.40, 0)", "The slide uses the bar's base")
	has(hud, 'player:GetAttributeChangedSignal("TouchLayout"):Connect(function()\n\tlayoutSprint()\n\tlayoutStaminaBar()', "A new layout re-lays out Sprint and the bar")
	has(hud, "\tlayoutSprint()\n\tlayoutStaminaBar()\n", "...and so does a new screen size")
	has(hud, 'mainhud:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveHudLayout)', "...on a resize or rotation")

	-- The ability buttons: TouchControls, from the attribute, on touch screens only.
	local burst = read(BURST)
	has(burst, 'local layout = if UserInputService.TouchEnabled then player:GetAttribute("TouchLayout") else nil', "Burst reads the layout on touch screens only")
	has(burst, "HudErgonomics.TouchControls(hud.X, hud.Y, layout, neighbours, button.Visible).B", "Burst is placed by TouchControls")
	has(burst, 'player:GetAttributeChangedSignal("TouchLayout"):Connect(layoutButton)', "...re-laid out on a new layout")
	has(burst, 'mainhud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutButton)', "...and a new screen")
	local heat = read(HEAT)
	has(heat, 'local layout = if UserInputService.TouchEnabled then player:GetAttribute("TouchLayout") else nil', "Heat Vision reads the layout on touch screens only")
	has(heat, "HudErgonomics.TouchControls(hud.X, hud.Y, layout, neighbours, burstShown).H", "Heat Vision is placed by TouchControls")
	has(heat, 'player:GetAttributeChangedSignal("TouchLayout"):Connect(layoutButton)', "...re-laid out on a new layout")
	has(heat, 'burst:GetPropertyChangedSignal("Visible"):Connect(layoutButton)', "...and when the Burst button shows or hides")

	-- Settings: the "Move controls" row on touch screens only, opening the editor.
	local settings = read(SETTINGS)
	has(settings, "if not UserInputService.TouchEnabled or ScrollingFrame:FindFirstChild(MOVE_CONTROLS_ROW) then", "The row is for touch screens only, made once")
	has(settings, 'closePanel()\n\t\tMenuEvents.Get("TouchLayoutEdit"):Fire("Open")', "Edit closes Settings and opens the editor")
	has(settings, "row.Parent = ScrollingFrame", "...a row of the Settings list")
	print("PASS HUD: Sprint and the stamina bar (the slide's base too) from the attribute, moved off the jump button, automatic on garbage, untouched on desktops; Burst and Heat Vision by TouchControls; the Settings row opens the editor")
end

print("ALL TOUCH LAYOUT CHECKS PASSED")
