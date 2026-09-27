-- test_u4_stamina_pass.luau (Update 4, community_pass_admin, 2026-09-25)
-- The 2x Stamina Regen gamepass (output/Update4/PLAN.md §7.8.4):
--   1. Economy/StaminaRegenPass (the real script, stubbed services): ownership from
--      UserOwnsGamePassAsync (3 tries) or GiftedPasses, a gift arriving mid-session, the
--      purchase-finished event (attribute + funnel step 3), and nothing at all while the
--      pass id is 0 or the kill switch is on.
--   2. UI/StaminaPassHint: the rule (3 empty-bar tries + 10 minutes, not owned, not in the
--      tutorial or a race) and, running the real script, once per session, funnel 0/1/2 and
--      the purchase prompt; with id 0 it stops before building anything.
--   3. ShopController: the "2X Stamina" card is mapped, priced, owned by attribute, hidden
--      while the id is 0, and its clicks report funnel steps 1/2.
--   4. audit/u4_shop_card.Insert: clones a sibling pass card into "2X Stamina" (bolt icon, title,
--      price, hidden, stamped) and is idempotent; an unstamped card of that name stops it.
--      2026-09-26 (owner): the sibling is "2X Speed" (Revive's backdrop sits 23 % high and it has
--      no description line), LayoutOrder after the designer's cards; the layout itself is
--      audit/test_u4_shop_layout's.
-- Run: lune run audit/test_u4_stamina_pass.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local SRC = "src/common/"
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local PlaceFiles = require("./place_files")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local function node(name, children)
	local n = { Name = name, __instance = true, children = children or {} }
	function n:WaitForChild(child)
		return self.children[child]
	end
	function n:FindFirstChild(child)
		return self.children[child]
	end
	return n
end
local function moduleNode(value)
	local n = node("module")
	n.module = value
	return n
end

-- U4 with the pass id and kill switch the test picks.
local function config(passId, off)
	local stamina = setmetatable({ GamePassId = passId }, { __index = U4.StaminaPass })
	return setmetatable({
		StaminaPass = stamina,
		IsOn = function(feature)
			if feature == "StaminaPass" then
				return passId > 0 and not off
			end
			return U4.IsOn(feature)
		end,
	}, { __index = U4 })
end

local function typeofStub(value)
	if type(value) == "table" and value.__instance then
		return "Instance"
	end
	return typeof(value)
end

----------------------------------------------------------------------
-- 1. StaminaRegenPass
----------------------------------------------------------------------
local function serverWorld(passId, options)
	options = options or {}
	local w = { clock = 0, steps = {}, ownsCalls = 0, failFirst = options.failFirst or 0 }
	local Players = node("Players")
	Players.PlayerAdded = signal()
	Players.list = {}
	function Players:GetPlayers()
		return self.list
	end
	local purchaseFinished = signal()
	w.purchaseFinished = purchaseFinished
	local gifted = options.gifted or {}
	local GiftedPasses = {
		Has = function(player, id)
			return gifted[player.UserId] == id
		end,
		UpgradeId = function(id)
			return "GiftedPass:" .. tostring(math.floor(id))
		end,
	}
	local owners = options.owners or {}
	local services = {
		MarketplaceService = {
			UserOwnsGamePassAsync = function(_, userId, id)
				w.ownsCalls += 1
				if w.ownsCalls <= w.failFirst then
					error("HTTP 500")
				end
				assert(id == passId, "asks for the stamina pass")
				return owners[userId] == true
			end,
			PromptGamePassPurchaseFinished = purchaseFinished,
		},
		Players = Players,
		ReplicatedStorage = node("ReplicatedStorage", { Shared = node("Shared", { Update4Config = moduleNode(config(passId, options.off)) }) }),
		ServerScriptService = node("ServerScriptService", { Services = node("Services", {
			Monetization = node("Monetization", { GiftedPasses = moduleNode(GiftedPasses) }),
			FunnelAnalytics = moduleNode({ Step = function(player, funnel, step)
				table.insert(w.steps, { player = player, funnel = funnel, step = step })
				return true
			end }),
		}) }),
	}
	w.G = {}
	local env = setmetatable({
		game = { GetService = function(_, name) return assert(services[name], name) end },
		require = function(object)
			assert(type(object) == "table" and object.module ~= nil, "require of an unknown stub")
			return object.module
		end,
		typeof = typeofStub,
		task = {
			spawn = function(fn, ...) fn(...) end,
			wait = function(seconds)
				w.clock += seconds or 0
			end,
		},
		os = { clock = function() return w.clock end, time = os.time },
		_G = w.G,
	}, { __index = _G })
	luau.load(fs.readFile(SRC .. "ServerScriptService/Economy/StaminaRegenPass.server.luau"), { environment = env })()
	function w.join(userId)
		local attributes = { DataLoaded = true }
		local owned = node("OwnedUpgrades")
		owned.ChildAdded = signal()
		local player = { __instance = true, UserId = userId, Name = "P" .. userId, Parent = Players, attributes = attributes }
		player.children = { SpeedsterData = node("SpeedsterData", { OwnedUpgrades = owned }) }
		function player:WaitForChild(child)
			return self.children[child]
		end
		function player:IsA(class)
			return class == "Player"
		end
		function player:GetAttribute(key)
			return attributes[key]
		end
		function player:SetAttribute(key, value)
			attributes[key] = value
		end
		player.owned = owned
		table.insert(Players.list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	return w
end

do
	-- The id is 0 until the owner makes the pass: nothing runs.
	local zero = serverWorld(0, { owners = { [1] = true } })
	local p = zero.join(1)
	zero.purchaseFinished:Fire(p, 0, true)
	assert(zero.ownsCalls == 0 and p.attributes.StaminaRegen2xOwned == nil and #zero.steps == 0, "Id 0: no ownership calls, no attribute, no funnel")
	assert(#p.owned.ChildAdded.handlers == 0, "Id 0: no gift watch either")

	local w = serverWorld(777, { owners = { [1] = true }, gifted = { [2] = 777 }, failFirst = 2 })
	local buyer = w.join(1)
	assert(buyer.attributes.StaminaRegen2xOwned == true and w.ownsCalls == 3, "Roblox ownership, after two failed tries (3 tries)")
	local giftee = w.join(2)
	assert(giftee.attributes.StaminaRegen2xOwned == true, "A gift saved on the profile (GiftedPasses) counts")
	local nobody = w.join(3)
	assert(nobody.attributes.StaminaRegen2xOwned == nil, "No pass, no attribute")

	-- A gift received mid-session.
	nobody.owned.ChildAdded:Fire({ Name = "GiftedPass:123" })
	assert(nobody.attributes.StaminaRegen2xOwned == nil, "Another pass's gift does nothing")
	nobody.owned.ChildAdded:Fire({ Name = "GiftedPass:777" })
	assert(nobody.attributes.StaminaRegen2xOwned == true, "The stamina pass gift sets it at once")

	-- Buying it in this session.
	local shopper = w.join(4)
	w.purchaseFinished:Fire(shopper, 777, false)
	w.purchaseFinished:Fire(shopper, 555, true)
	assert(shopper.attributes.StaminaRegen2xOwned == nil and #w.steps == 0, "A cancelled prompt or another pass does nothing")
	w.purchaseFinished:Fire(shopper, 777, true)
	assert(shopper.attributes.StaminaRegen2xOwned == true, "Purchase sets the attribute")
	assert(#w.steps == 1 and w.steps[1].funnel == "Monetization_StaminaPass" and w.steps[1].step == 3, "...and logs Purchased (step 3)")

	-- The kill switch.
	local off = serverWorld(777, { owners = { [1] = true }, off = true })
	local offPlayer = off.join(1)
	off.purchaseFinished:Fire(offPlayer, 777, true)
	assert(off.ownsCalls == 0 and offPlayer.attributes.StaminaRegen2xOwned == nil and #off.steps == 0, "Switched off: nothing")
	assert(type(w.G.SpeedsterRefreshStaminaPass) == "function", "_G.SpeedsterRefreshStaminaPass for the admin panel and gifts")
	pass("StaminaRegenPass: Roblox (3 tries) or GiftedPasses, gifts mid-session, purchase -> attribute + step 3, id 0 / kill switch -> nothing")
end

----------------------------------------------------------------------
-- 2. The hint
----------------------------------------------------------------------
local hintSource = fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/UI/StaminaPassHint.client.luau")
do
	local a = assert(string.find(hintSource, "-- HINT_RULE_BEGIN", 1, true))
	local b = assert(string.find(hintSource, "-- HINT_RULE_END", a, true))
	local rule = luau.load(string.sub(hintSource, a, b - 1) .. "\nreturn shouldShowHint")()
	local function state(changes)
		local s = { shown = false, owned = false, tutorial = false, racing = false, passOn = true, empties = 3, afterEmpties = 3, sessionSeconds = 600, minSessionSeconds = 600 }
		for k, v in changes or {} do
			s[k] = v
		end
		return s
	end
	assert(rule(state()) == true, "3 empties at 10 minutes: shown")
	assert(rule(state({ empties = 2 })) == false, "2 empties: not yet")
	assert(rule(state({ sessionSeconds = 599 })) == false, "Under 10 minutes: not yet")
	assert(rule(state({ empties = 9, sessionSeconds = 4000 })) == true, "Later empties still count")
	for _, key in { "shown", "owned", "tutorial", "racing" } do
		assert(rule(state({ [key] = true })) == false, key .. ": never")
	end
	assert(rule(state({ passOn = false })) == false, "Pass off: never")
	pass("hint rule: after U4.StaminaPass.HintAfterEmpties tries and HintMinSessionSeconds, never owned / tutorial / race / shown / off")
end

-- The real script, on stubs.
local function genericInstance(className)
	local object = { ClassName = className, __instance = true, children = {}, Activated = signal(), Enabled = true }
	object.AbsoluteSize = if className == "ScreenGui" then roblox.Vector2.new(1920, 1080) else roblox.Vector2.new(104, 30)
	function object:FindFirstChild(name)
		return self.children[name]
	end
	return setmetatable(object, { __newindex = function(t, key, value)
		if key == "Parent" and type(value) == "table" and value.children then
			value.children[t.Name or className] = t
		end
		rawset(t, key, value)
	end })
end

local function hintWorld(passId)
	local w = { clock = 0, reports = {}, prompts = 0, required = {}, created = 0, bindings = {} }
	local attributes = {}
	local attributeSignals = {}
	local player = { __instance = true, UserId = 5, attributes = attributes }
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:GetAttributeChangedSignal(key)
		attributeSignals[key] = attributeSignals[key] or signal()
		return attributeSignals[key]
	end
	local bar = genericInstance("Frame")
	bar.Name = "SpeedsterBar"
	bar.Visible = true
	bar.AbsolutePosition = roblox.Vector2.new(300, 600)
	bar.AbsoluteSize = roblox.Vector2.new(200, 20)
	function bar:IsA(class)
		return class == "GuiObject" or class == "Frame"
	end
	local mainhud = genericInstance("ScreenGui")
	mainhud.Name = "Mainhud"
	mainhud.IgnoreGuiInset = true
	mainhud.ScreenInsets = roblox.Enum.ScreenInsets.None
	mainhud.Enabled = true
	function mainhud:IsA(class)
		return class == "ScreenGui" or class == "LayerCollector"
	end
	mainhud.children.SpeedsterBar = bar
	local playerGui = genericInstance("PlayerGui")
	playerGui.children.Mainhud = mainhud
	player.children = { PlayerGui = playerGui }
	function player:WaitForChild(name)
		return self.children[name]
	end
	w.player, w.attributes, w.attributeSignals = player, attributes, attributeSignals
	local attempted = signal()
	w.attempted = attempted
	local report = { __instance = true }
	function report:IsA(class)
		return class == "RemoteEvent"
	end
	function report:FireServer(funnel, step)
		table.insert(w.reports, { funnel = funnel, step = step })
	end
	local remotes = node("Remotes", { FunnelReport = report })
	local sharedModules = {
		Update4Config = config(passId, false),
		StaminaFeedback = { Attempted = attempted },
	}
	local shared = node("Shared")
	for name, value in sharedModules do
		local m = moduleNode(value)
		m.Name = name
		shared.children[name] = m
	end
	local services = {
		ContextActionService = {
			BindActionAtPriority = function(_, name, fn, _, _, key)
				w.bindings[name] = { fn = fn, key = key }
			end,
			UnbindAction = function(_, name)
				w.bindings[name] = nil
			end,
		},
		MarketplaceService = { PromptGamePassPurchase = function(_, who, id)
			assert(who == player and id == passId, "prompts the stamina pass")
			w.prompts += 1
		end },
		Players = { LocalPlayer = player },
		ReplicatedStorage = node("ReplicatedStorage", { Shared = shared, Remotes = remotes }),
		UserInputService = { GamepadEnabled = false },
	}
	local env = setmetatable({
		game = { GetService = function(_, name) return assert(services[name], name) end },
		require = function(object)
			table.insert(w.required, object.Name)
			return object.module
		end,
		typeof = typeofStub,
		task = {
			spawn = function(fn, ...) fn(...) end,
			wait = function(seconds)
				w.clock += seconds or 0
			end,
		},
		os = { clock = function() return w.clock end },
		Instance = { new = function(className)
			w.created += 1
			return genericInstance(className)
		end },
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Vector2 = roblox.Vector2,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
	}, { __index = _G })
	luau.load(hintSource, { environment = env })()
	w.playerGui = playerGui
	return w
end

do
	local zero = hintWorld(0)
	assert(zero.created == 0 and not table.find(zero.required, "StaminaFeedback") and #zero.attempted.handlers == 0, "Id 0: the hint stops before listening or building anything")

	local w = hintWorld(4242)
	assert(#w.attempted.handlers == 1, "Listens to StaminaFeedback.Attempted")
	for _ = 1, 3 do
		w.attempted:Fire("run")
	end
	assert(w.playerGui.children.StaminaPassHint == nil and #w.reports == 0, "3 empties in the first minutes: no chip yet")
	w.attempted:Fire("fly")
	w.clock = 601
	w.attributes.FirstTimeTutorialActive = true
	w.attempted:Fire("run")
	assert(w.playerGui.children.StaminaPassHint == nil, "Never in the tutorial")
	w.attributes.FirstTimeTutorialActive = false
	w.attempted:Fire("run")
	local gui = w.playerGui.children.StaminaPassHint
	assert(gui and #w.reports == 1 and w.reports[1].funnel == "Monetization_StaminaPass" and w.reports[1].step == 0, "After 10 minutes: the chip, funnel step 0")
	local chip = gui.children.Chip
	assert(chip and chip.Size == roblox.UDim2.fromOffset(104, 30), "A 30 px chip")
	assert(chip.Position.X.Offset >= 500, "At the bar's right end")
	assert(gui.Enabled == false, "Gone after HintSeconds (the follow loop ran out)")
	w.attempted:Fire("run")
	w.attempted:Fire("run")
	assert(#w.reports == 1, "Once per session")

	-- Tapping it (a second world, the chip still up).
	local t = hintWorld(4242)
	t.clock = 700
	for _ = 1, 3 do
		t.attempted:Fire("run")
	end
	local tapGui = t.playerGui.children.StaminaPassHint
	tapGui.Enabled = true -- the stub's loop has already run out; show it again to tap it
	tapGui.children.Chip.Activated:Fire()
	assert(t.prompts == 1, "Tap: Roblox's purchase prompt")
	local stepsSeen = {}
	for _, r in t.reports do
		table.insert(stepsSeen, r.step)
	end
	assert(table.concat(stepsSeen, ",") == "0,1,2", "Funnel 0 shown, 1 tapped, 2 prompt (" .. table.concat(stepsSeen, ",") .. ")")
	assert(tapGui.Enabled == false, "The chip goes on tap")
	assert(string.find(hintSource, "Enum.KeyCode.DPadRight", 1, true), "Gamepad: D-pad right buys while the chip is up")
	local owned = hintWorld(4242)
	owned.clock = 700
	owned.attributes.StaminaRegen2xOwned = true
	for _ = 1, 4 do
		owned.attempted:Fire("run")
	end
	assert(owned.playerGui.children.StaminaPassHint == nil, "Owners never see it")
	pass("hint script: id 0 does nothing, chip after 3 empties + 10 min, once per session, never in the tutorial or for owners, tap -> prompt, funnel 0/1/2")
end

----------------------------------------------------------------------
-- 3. ShopController
----------------------------------------------------------------------
do
	local shop = fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")
	for _, needle in {
		'local U4 = require(ReplicatedStorage.Shared:WaitForChild("Update4Config"))',
		'["2X Stamina"] = { type = "GamePass", id = tonumber(U4.StaminaPass.GamePassId) or 0 },',
		'["2X Stamina"] = tonumber(U4.StaminaPass.PriceRobux) or 149,',
		'if player:GetAttribute("StaminaRegen2xOwned") == true then',
		'player:GetAttributeChangedSignal("StaminaRegen2xOwned"):Connect(refreshAllPassCardsOwnership)',
		'pcall(report.FireServer, report, "Monetization_StaminaPass", step)',
	} do
		assert(string.find(shop, needle, 1, true), "ShopController: " .. needle)
	end
	local wire = string.sub(shop, assert(string.find(shop, "local function wirePassCards()", 1, true)), assert(string.find(shop, "local function wirePotionCards()", 1, true)))
	local hide = assert(string.find(wire, 'item.Visible = passId > 0 and U4.IsOn("StaminaPass")', 1, true), "The card is hidden at id 0")
	local skip = assert(string.find(wire, "if passId <= 0 then", 1, true))
	assert(hide < skip, "...before the id-0 cards are skipped")
	local buy = string.sub(shop, assert(string.find(shop, "local function wireCardBuy", 1, true)), assert(string.find(shop, "local function applyGamePassDescription", 1, true)))
	local one = assert(string.find(buy, "reportStaminaFunnel(1)", 1, true))
	local prompt = assert(string.find(buy, "promptPurchase(passType, passId)", 1, true))
	local two = assert(string.find(buy, "reportStaminaFunnel(2)", 1, true))
	assert(one < prompt and prompt < two, "Card click: step 1, prompt, step 2")
	-- The hiding rule itself, on both ids.
	local visibleFor = luau.load("local U4 = ...\nreturn function(passId) return passId > 0 and U4.IsOn(\"StaminaPass\") end")
	assert(visibleFor(config(0, false))(0) == false and visibleFor(config(9, false))(9) == true and visibleFor(config(9, true))(9) == false, "Hidden at id 0 or when switched off")
	pass("ShopController: 2X Stamina mapped, priced 149, owned by attribute, hidden at id 0 / switched off, click -> funnel 1, prompt, 2")
end

----------------------------------------------------------------------
-- 4. u4_shop_card
----------------------------------------------------------------------
do
	local ShopCard = require("./u4_shop_card")
	local dm = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
	local list = assert(ShopCard.PassList(dm), "the Passes list")
	local notes = {}
	local card = ShopCard.Insert(dm, notes)
	assert(card.Parent == list and card.Name == "2X Stamina" and card.Visible == false, "Cloned into Pass, hidden")
	assert(card:GetAttribute("U4Asset") == ShopCard.Stamp, "Stamped")
	-- 2026-09-26 (owner): cloned from 2X Speed; its speed icon (and sparkles) became the bolt.
	local bolts, speedIcons = 0, 0
	for _, child in card:GetChildren() do
		if child:IsA("ImageLabel") then
			local uri = tostring(child.ImageContent.Uri)
			if uri == ShopCard.Icon then
				bolts += 1
			elseif uri == "rbxassetid://97058106405348" then
				speedIcons += 1
			end
		end
	end
	assert(bolts >= 1 and speedIcons == 0, "2X Speed's icon (and its sparkles) became the bolt (" .. bolts .. ")")
	local titles = ShopCard.Titles(card)
	assert(titles[1] and titles[1].Text == ShopCard.Title and titles[1].Text == "2X Stamina", "Title")
	assert(titles[2] and titles[2].Text == ShopCard.Description, "Description line")
	local highest = -math.huge
	for _, sibling in ShopCard.Siblings(list) do
		highest = math.max(highest, sibling.LayoutOrder)
	end
	assert(card.LayoutOrder == highest + 1, "LayoutOrder right after the designer's cards")
	assert(#ShopCard.LayoutProblems(list, card) == 0, "Laid out exactly like its sibling")
	assert(card.Buy:FindFirstChild("Name").Text == tostring(U4.StaminaPass.PriceRobux), "Default price on the button")
	assert(card:FindFirstChild("Gift") and card:FindFirstChild("Buy"), "Buy and Gift buttons kept")
	ShopCard.Insert(dm, notes)
	local count = 0
	for _, child in list:GetChildren() do
		if child.Name == "2X Stamina" then
			count += 1
		end
	end
	assert(count == 1 and #notes == 2, "Idempotent: one card after two inserts")
	local revive = list:FindFirstChild("Revive")
	assert(revive and revive:FindFirstChild("Tittle").Text == "Revive infinitely", "Revive untouched")
	assert(ShopCard.Titles(list:FindFirstChild("2X Speed"))[1].Text == "2X Speed", "2X Speed untouched")
	list:FindFirstChild("2X Stamina"):SetAttribute("U4Asset", nil)
	local ok, err = pcall(ShopCard.Insert, dm, notes)
	assert(not ok and string.find(tostring(err), "without the U4Asset stamp", 1, true), "An unstamped card stops the build")
	pass("u4_shop_card: 2X Speed -> 2X Stamina (bolt, title, description, price, hidden, stamped, LayoutOrder last), idempotent, refuses a foreign card")
end

print(("test_u4_stamina_pass: %d checks passed"):format(passed))
