-- test_ui_ergonomics.luau
-- The mobile / console pass on the UI (2026-09-18):
--   1. the Revive offer's close X: saved in every place, big enough to tap, and it closes the
--      offer at once (tap or ButtonB), tells the server, which drops the offer and respawns
--      a player still lying dead;
--   2. the x2 badges never share a pixel with the Starter Pack and wear their colours (gold
--      Wins, blue Speed) in the places; on phones the right edge is one column (Starter
--      Pack, badges, speedometer, jump button) with the boost cards beside the speedometer,
--      and the top middle of the screen is clear (the row of badges there hid the track);
--   3. the touch Sprint button: 46-54 px, beside the jump button, clear of it and of the
--      thumbstick, with a pressed state; 30-36 px from the jump button (the jumping thumb
--      kept landing on it at 14), off the level and stamina bars wherever the gap allows;
--   4. the Spin Wheel on phones: the wheel 75-85% of the screen's height, a circle, every
--      button at least 44 px tall and clear of the wheel and of each other;
--   5. consoles: the 5% safe zone and gamepad navigation (wheel, shop, Revive).
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local HudErgonomics = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")
local SpinWheelLayout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")
local ReviveCloseButton = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/ReviveCloseButton.luau"), {
	environment = setmetatable({ Instance = rb.Instance, UDim2 = rb.UDim2, Vector2 = rb.Vector2, Enum = rb.Enum }, { __index = _G }),
})()

local function read(path)
	return fs.readFile(path)
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end

local PHONES = { { 844, 390 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 896, 414 }, { 932, 430 }, { 915, 412 }, { 800, 360 } }
local TABLETS = { { 1024, 768 }, { 1180, 820 }, { 1366, 1024 } }
local DESKTOPS = { { 1280, 720 }, { 1366, 768 }, { 1440, 900 }, { 1920, 1080 }, { 2560, 1440 }, { 1000, 600 } }

local places = {}
for _, world in { "World1", "World2", "World3" } do
	places[world] = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
end

----------------------------------------------------------------------
-- A small Roblox harness: instances with properties, children, events and attributes.
----------------------------------------------------------------------
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		return { Disconnect = function() end }
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	function s:Wait() end
	return s
end
local methods = {}
local function instance(class)
	local o = { __mock = true, props = { ClassName = class, Name = class, Visible = true, Active = true, ZIndex = 1 }, children = {}, events = {}, attrs = {} }
	setmetatable(o, {
		__index = function(self, k)
			if methods[k] then
				return methods[k]
			end
			if self.props[k] ~= nil then
				return self.props[k]
			end
			for _, c in self.children do
				if c.Name == k then
					return c
				end
			end
			if type(k) == "string" and (k:match("Changed$") or k:match("Added$") or k:match("Removing$") or k:match("Began$") or k:match("Ended$") or k:match("Event$") or k == "Activated" or k == "MouseEnter" or k == "MouseLeave" or k == "Completed") then
				self.events[k] = self.events[k] or signal()
				return self.events[k]
			end
			return nil
		end,
		__newindex = function(self, k, v)
			if k == "Parent" then
				local old = self.props.Parent
				if old then
					local idx = table.find(old.children, self)
					if idx then
						table.remove(old.children, idx)
					end
				end
				if v then
					table.insert(v.children, self)
				end
			end
			self.props[k] = v
		end,
	})
	return o
end
local GUI_CLASSES = { Frame = true, TextButton = true, ImageButton = true, TextLabel = true, ImageLabel = true, ScrollingFrame = true }
function methods:IsA(class)
	return self.ClassName == class
		or class == "Instance"
		or (class == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton"))
		or (class == "GuiObject" and GUI_CLASSES[self.ClassName] == true)
end
function methods:FindFirstChild(name, recursive)
	for _, c in self.children do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self.children do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found or timeout then
		return found
	end
	error("Missing " .. tostring(self.Name) .. "." .. name)
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:GetDescendants()
	local all = {}
	for _, c in self.children do
		table.insert(all, c)
		for _, d in c:GetDescendants() do
			table.insert(all, d)
		end
	end
	return all
end
function methods:FindFirstChildOfClass(class)
	for _, c in self.children do
		if c.ClassName == class then
			return c
		end
	end
	return nil
end
function methods:FindFirstAncestorWhichIsA()
	return nil
end
function methods:IsDescendantOf(other)
	local p = self.Parent
	while p do
		if p == other then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:GetPropertyChangedSignal(k)
	self.events["prop_" .. k] = self.events["prop_" .. k] or signal()
	return self.events["prop_" .. k]
end
function methods:GetAttribute(k)
	return self.attrs[k]
end
function methods:SetAttribute(k, v)
	self.attrs[k] = v
	if self.events["attr_" .. k] then
		self.events["attr_" .. k]:Fire()
	end
end
function methods:GetAttributeChangedSignal(k)
	self.events["attr_" .. k] = self.events["attr_" .. k] or signal()
	return self.events["attr_" .. k]
end
function methods:Destroy()
	self.Parent = nil
end
function methods:Play() end
function methods:Clone()
	local n = instance(self.ClassName)
	for k, v in self.props do
		if k ~= "Parent" then
			n[k] = v
		end
	end
	return n
end
function methods:TimePosition() end

-- A copy of a real GUI tree (from a built place) as harness instances.
local COPIED = { "Name", "Position", "Size", "AnchorPoint", "Visible", "ZIndex", "Image", "Text", "Enabled", "Scale", "Selectable", "Active", "AspectRatio" }
local function mirror(real, parent)
	local o = instance(real.ClassName)
	for _, prop in COPIED do
		local ok, value = pcall(function()
			return real[prop]
		end)
		if ok and value ~= nil then
			o.props[prop] = value
		end
	end
	o.Parent = parent
	for _, c in real:GetChildren() do
		mirror(c, o)
	end
	return o
end

local function coroutineTask()
	return {
		spawn = function(fn, ...)
			local co = coroutine.create(fn)
			local ok, err = coroutine.resume(co, ...)
			assert(ok, err)
		end,
		defer = function(fn, ...)
			local co = coroutine.create(fn)
			local ok, err = coroutine.resume(co, ...)
			assert(ok, err)
		end,
		delay = function() end,
		wait = function()
			coroutine.yield()
		end,
	}
end

----------------------------------------------------------------------
-- 1. The Revive offer's close X
----------------------------------------------------------------------
do
	for world, place in places do
		local holder = place:GetService("StarterGui").RevivePromptHUD.ReviveOfferHolder
		local close = holder:FindFirstChild("CloseButton")
		assert(close and close:IsA("ImageButton"), world .. ": the Revive offer has its close X, a real instance in StarterGui")
		local art = close:FindFirstChild("Art")
		-- (Lune reads Image back as ImageContent; the XML shows the asset.)
		local xml = rb.serializeModel({ close }, true)
		assert(art and string.find(xml, "<uri>rbxassetid://110882579806743</uri>", 1, true), world .. ": the X is the game's round close art")
		local holderScale = holder:FindFirstChildOfClass("UIScale")
		local screenScale = if holderScale then holderScale.Scale else 1
		assert(close.Size.X.Offset * screenScale >= 48 and close.Size.Y.Offset * screenScale >= 48, world .. ": the touch area is at least 48 px (hit padding)")
		assert(art.Size.X.Offset * screenScale >= 40, world .. ": the X itself is at least 40 px")
		local reviveButton = holder:FindFirstChild("ReviveButton")
		local buttonScale = reviveButton:FindFirstChildOfClass("UIScale")
		local right = reviveButton.Size.X.Offset * (if buttonScale then buttonScale.Scale else 1)
		assert(math.abs(close.Position.X.Offset - right) <= 12 and math.abs(close.Position.Y.Offset) <= 12, world .. ": the X sits on the Revive button's top-right corner")
		assert(close.ZIndex > reviveButton.ZIndex, world .. ": ...drawn over it")
		for _, d in close:GetDescendants() do
			assert(not d:IsA("LuaSourceContainer"), world .. ": the X carries no script")
		end
	end
	local built = ReviveCloseButton.Build()
	assert(built.Name == "CloseButton" and built.Size.X.Offset == ReviveCloseButton.HitSize, "The fallback X is the same as the saved one")
	print("PASS Revive X: saved in all three places, round close art, 60 px touch area (55 on screen), on the button's corner")

	-- The real client script, with the World 1 offer: the X and ButtonB close it at once.
	local function runClient(tenFoot)
		local services = {}
		for _, name in { "Players", "ReplicatedStorage", "MarketplaceService", "SoundService", "TweenService", "UserInputService", "Workspace", "RunService", "GuiService", "ContextActionService" } do
			services[name] = instance(name)
		end
		local player = instance("Player")
		player.Name = "Tester"
		player.Parent = services.Players
		services.Players.LocalPlayer = player
		local playerGui = instance("PlayerGui")
		playerGui.Name = "PlayerGui"
		playerGui.Parent = player
		local hud = mirror(places.World1:GetService("StarterGui").RevivePromptHUD, playerGui)
		local shared = instance("Folder")
		shared.Name = "Shared"
		shared.Parent = services.ReplicatedStorage
		for _, name in { "Config", "ReviveCloseButton" } do
			local m = instance("ModuleScript")
			m.Name = name
			m.Parent = shared
		end
		local remotes = instance("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = services.ReplicatedStorage
		local commerce = instance("RemoteEvent")
		commerce.Name = "ReviveCommerce"
		commerce.Parent = remotes
		commerce.sent = {}
		commerce.FireServer = function(_, ...)
			table.insert(commerce.sent, { ... })
		end
		services.MarketplaceService.GetProductInfo = function()
			return { PriceInRobux = 7 }
		end
		services.RunService.IsStudio = function()
			return false
		end
		services.TweenService.Create = function(_, target, _, values)
			return {
				Play = function()
					for k, v in values do
						target[k] = v
					end
				end,
				Cancel = function() end,
				Completed = signal(),
			}
		end
		services.UserInputService.GamepadEnabled = tenFoot
		services.UserInputService.GetLastInputType = function()
			return if tenFoot then rb.Enum.UserInputType.Gamepad1 else rb.Enum.UserInputType.Touch
		end
		services.GuiService.IsTenFootInterface = function()
			return tenFoot
		end
		services.GuiService.MenuIsOpen = false
		services.GuiService.GuiNavigationEnabled = false
		local bound = {}
		services.ContextActionService.BindActionAtPriority = function(_, name, fn, _, _, key)
			bound[name] = { Fn = fn, Key = key }
		end
		services.ContextActionService.UnbindAction = function(_, name)
			bound[name] = nil
		end
		local modules = {
			Config = { ReviveProductId = 0, RevivePriceRobux = 7, ReviveOfferSeconds = 15 },
			ReviveCloseButton = {
				Name = "CloseButton",
				Build = function()
					error("the saved X must be used")
				end,
			},
		}
		local env = {
			game = {
				GetService = function(_, name)
					return assert(services[name], name)
				end,
			},
			Instance = { new = instance },
			Enum = rb.Enum,
			Vector2 = rb.Vector2,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Color3 = rb.Color3,
			TweenInfo = { new = function() return {} end },
			task = coroutineTask(),
			warn = function() end,
			print = function() end,
			script = instance("LocalScript"),
			require = function(object)
				return assert(modules[object.Name], "module " .. tostring(object.Name))
			end,
		}
		luau.load(read("src/common/StarterPlayer/StarterPlayerScripts/UI/RevivePrompt.client.luau"), { environment = setmetatable(env, { __index = _G }) })()
		return { Hud = hud, Commerce = commerce, Bound = bound, GuiService = services.GuiService }
	end

	local touch = runClient(false)
	local holder = touch.Hud.ReviveOfferHolder
	local close = holder.CloseButton
	touch.Commerce.OnClientEvent:Fire({ Type = "Offer", Token = "T1", Duration = 15, Free = false })
	assert(touch.Hud.Enabled == true and holder.Visible == true, "An offer shows the Revive prompt")
	assert(close.Visible == true and close.Active == true, "...with its X ready")
	close.Activated:Fire()
	assert(holder.Visible == false and touch.Hud.Enabled == false, "The X closes the offer at once")
	local last = touch.Commerce.sent[#touch.Commerce.sent]
	assert(last[1] == "Dismiss" and last[2] == "T1", "...and tells the server which offer was dismissed")
	close.Activated:Fire()
	assert(#touch.Commerce.sent == 1, "A second press on a closed offer sends nothing")
	print("PASS Revive X closes: tapping it hides the offer this frame and sends Dismiss with the offer's token, once")

	local pad = runClient(true)
	local padHolder = pad.Hud.ReviveOfferHolder
	pad.Commerce.OnClientEvent:Fire({ Type = "Offer", Token = "T2", Duration = 15, Free = false })
	assert(pad.GuiService.SelectedObject == padHolder.ReviveButton, "On a gamepad the offer takes the selection (Revive)")
	assert(padHolder.ReviveButton.NextSelectionRight == padHolder.CloseButton and padHolder.CloseButton.NextSelectionLeft == padHolder.ReviveButton, "...and the X is one step to its right")
	local action = pad.Bound["ReviveOfferDismiss_ButtonB"]
	assert(action and action.Key == rb.Enum.KeyCode.ButtonB, "ButtonB is bound while the offer shows")
	local result = action.Fn("ReviveOfferDismiss_ButtonB", rb.Enum.UserInputState.Begin, {})
	assert(result == rb.Enum.ContextActionResult.Sink, "ButtonB is taken by the offer")
	assert(padHolder.Visible == false and pad.Hud.Enabled == false, "ButtonB closes the offer at once")
	assert(pad.Commerce.sent[#pad.Commerce.sent][1] == "Dismiss", "...and dismisses it on the server")
	assert(pad.Bound["ReviveOfferDismiss_ButtonB"] == nil and pad.GuiService.SelectedObject == nil, "ButtonB and the selection are released after")
	print("PASS Revive gamepad: selection on Revive with the X beside it, ButtonB closes it and lets go of the controls")
end

-- The server side of the X: the offer is dropped and a dead player respawns at once.
do
	local server = read("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	local a = assert(server:find("local function dismissReviveOffer(", 1, true))
	local b = assert(server:find("ReviveCommerce.OnServerEvent:Connect(", a, true))
	has(server:sub(b, b + 600), 'if action == "Dismiss" then\n\t\tdismissReviveOffer(player, token)', "The remote routes Dismiss to it")
	local offers, pending, steps, sent = {}, {}, {}, {}
	local dismiss = luau.load(server:sub(a, b - 1) .. "\nreturn dismissReviveOffer", {
		environment = setmetatable({
			activeReviveOffers = offers,
			pendingRevivePurchases = pending,
			FunnelAnalytics = {
				Step = function(_, funnel, step, session)
					table.insert(steps, { funnel, step, session })
					return true
				end,
			},
			ReviveCommerce = {
				FireClient = function(_, _, payload)
					table.insert(sent, payload)
				end,
			},
		}, { __index = _G }),
	})()
	local function newPlayer(dead)
		local p = { Name = "P", attrs = { ReviveOfferActive = true }, loads = 0 }
		local humanoid = { Health = if dead then 0 else 100 }
		p.Character = {
			Parent = true,
			FindFirstChildOfClass = function()
				return humanoid
			end,
			GetAttribute = function()
				return dead
			end,
		}
		function p:GetAttribute(k)
			return self.attrs[k]
		end
		function p:SetAttribute(k, v)
			self.attrs[k] = v
		end
		function p:LoadCharacter()
			self.loads += 1
		end
		return p
	end
	local dead = newPlayer(true)
	offers[dead] = { Token = "A" }
	pending[dead] = { Token = "A" }
	dismiss(dead, "wrong")
	assert(offers[dead] and dead.loads == 0, "Another offer's token changes nothing")
	dismiss(dead, "A")
	assert(offers[dead] == nil and pending[dead] == nil and dead.attrs.ReviveOfferActive == false, "Dismiss drops the offer")
	assert(dead.loads == 1, "A player still lying dead respawns at the spawn at once")
	assert(steps[1][1] == "Monetization_Revive" and steps[1][2] == 3 and steps[1][3] == "A", "RevivePrompt_Dismissed is logged in the offer's funnel session")
	assert(sent[1].Type == "Expired", "The client is told the offer is gone")
	dismiss(dead, "A")
	assert(dead.loads == 1 and #steps == 1, "Dismissing twice does nothing more")
	local alive = newPlayer(false)
	offers[alive] = { Token = "B" }
	dismiss(alive, "B")
	assert(alive.loads == 0 and offers[alive] == nil, "A player who already respawned is not respawned again")
	local buying = newPlayer(true)
	buying.attrs.RevivePurchasePending = true
	offers[buying] = { Token = "C" }
	dismiss(buying, "C")
	assert(offers[buying] and buying.loads == 0, "An offer being paid for is left to its purchase prompt")
	print("PASS Revive dismiss (server): right token only, offer dropped, dead player respawned once, purchase in progress untouched")
end

----------------------------------------------------------------------
-- 2. The x2 badges and the Starter Pack
----------------------------------------------------------------------
do
	-- The boost cards on phones: up to three 44 px cards, 5 px apart, at the 0.7 scale.
	local cards = places.World1:GetService("StarterGui").Mainhud.ActiveBuffsHolder
	local cardSide = cards.SpeedBuffCard.Size.X.Offset
	local cardsWidth, cardsHeight = (3 * cardSide + 2 * 5) * 0.7, cards.Size.Y.Offset * 0.7
	local function down(r, dy)
		return { Left = r.Left, Right = r.Right, Top = r.Top + dy, Bottom = r.Bottom + dy }
	end
	local columns = 0
	local function check(width, height, touch, keyboard, safe, label, topBar)
		for shown = 1, 2 do
			local plan = HudErgonomics.Badges(width, height, touch, keyboard, safe, shown, topBar)
			local where = ("%s %dx%d (top bar %d, %d badges)"):format(label, width, height, topBar or 0, shown)
			for index, badge in plan.Badges do
				assert(not HudErgonomics.Overlaps(badge, plan.Pack, 12), where .. (": badge %d is at least 12 px from the Starter Pack"):format(index))
				assert(badge.Left >= 0 and badge.Right <= width and badge.Top >= 0 and badge.Bottom <= height, where .. (": badge %d on screen"):format(index))
				for other = index + 1, #plan.Badges do
					assert(not HudErgonomics.Overlaps(badge, plan.Badges[other]), "Badges do not overlap each other")
				end
			end
			if plan.Compact then
				columns += 1
				local column = plan.Column
				local limits = HudErgonomics.ColumnBadgeHeight
				assert(plan.BadgeHeight >= limits.Min and plan.BadgeHeight <= limits.Max, where .. ": phone badges are 24-40 px tall")
				for index, badge in plan.Badges do
					-- A column under the Starter Pack, flush with its right edge.
					assert(math.abs(badge.Right - plan.Pack.Right) < 0.5, where .. ": the badges are right-aligned with the Starter Pack")
					local gap = badge.Top - plan.Pack.Bottom
					assert(gap >= 12 and (index > 1 or gap <= 16), where .. ": 12-16 px under the Starter Pack")
					if index > 1 then
						assert(badge.Top >= plan.Badges[index - 1].Bottom and math.abs(badge.Right - plan.Badges[index - 1].Right) < 0.5, where .. ": the badges stack straight down")
					end
					-- The top middle of the screen is the track's: nothing there.
					assert(badge.Left >= width * 0.75, where .. ": the badges keep out of the screen's top middle")
					assert(badge.Top >= (topBar or 0) + HudErgonomics.TopBarGap, where .. ": the badges are under the top bar")
				end
				-- The speedometer: under the badges, above the jump button.
				local speedo = column.Speedometer
				local scale = HudErgonomics.ColumnSpeedometerScale
				assert(speedo.Scale >= scale.Min and speedo.Scale <= scale.Max, where .. ": the speedometer is scaled 0.5-0.88")
				assert(speedo.Rect.Top >= plan.Badges[shown].Bottom + 4, where .. ": the speedometer is under the badges")
				assert(speedo.Rect.Left >= width * 0.7 and speedo.Rect.Right <= width, where .. ": the speedometer stays on the right edge")
				assert(speedo.Rect.Bottom <= (if column.Jump then column.Jump.Top - 4 else height), where .. ": the speedometer is above the jump button")
				-- Screen pixels back to the Main HUD's: the holder's top lands the gauge there.
				local inHud = HudErgonomics.SpeedometerRect(width, height - (topBar or 0), speedo.Scale, speedo.HolderTop)
				assert(math.abs(inHud.Top + (topBar or 0) - speedo.Rect.Top) < 1e-6, where .. ": the speedometer's holder position matches its rect")
				-- The boost cards: left of the speedometer, clear of everything in the column.
				local buffs = {
					Left = column.Buffs.Right - cardsWidth,
					Right = column.Buffs.Right,
					Top = column.Buffs.Y - cardsHeight / 2 + column.TopBar,
					Bottom = column.Buffs.Y + cardsHeight / 2 + column.TopBar,
				}
				assert(buffs.Left >= width / 2 and buffs.Bottom <= height, where .. ": the boost cards are on the right half, on screen")
				assert(not HudErgonomics.Overlaps(buffs, speedo.Rect, 6), where .. ": the boost cards are clear of the speedometer")
				for _, badge in plan.Badges do
					assert(not HudErgonomics.Overlaps(buffs, badge, 4), where .. ": the boost cards are clear of the badges")
				end
				if column.Jump then
					assert(not HudErgonomics.Overlaps(buffs, column.Jump, 4) and not HudErgonomics.Overlaps(buffs, column.Sprint, 4), where .. ": the boost cards are clear of jump and Sprint")
					local stick = down(HudErgonomics.Thumbstick(width, height - column.TopBar), column.TopBar)
					assert(not HudErgonomics.Overlaps(buffs, stick), where .. ": the boost cards are clear of the thumbstick")
				end
			end
		end
	end
	for _, s in PHONES do
		for _, topBar in { 0, 36, 58 } do
			check(s[1], s[2], true, false, false, "phone", topBar)
		end
	end
	assert(columns == #PHONES * 3 * 2, "Every phone screen gets the column")
	for _, s in TABLETS do
		check(s[1], s[2], true, false, false, "tablet")
	end
	for _, s in DESKTOPS do
		check(s[1], s[2], false, true, false, "desktop")
	end
	check(1920, 1080, false, false, true, "console")
	check(1280, 720, false, false, true, "console")
	-- Under Roblox's top bar (58 px with the current top bar, 36 with the old one), where the
	-- TopbarPlus icons sit too: the first playtest had the badges on top of those icons.
	for _, s in PHONES do
		for _, topBar in { 36, 58 } do
			local plan = HudErgonomics.Badges(s[1], s[2], true, false, false, 2, topBar)
			assert(plan.Pack.Top >= topBar + 6, ("%dx%d: the Starter Pack is under the top bar"):format(s[1], s[2]))
		end
	end
	-- (The bug, 2026-09-18 preview: the phone row of badges ran left of the Starter Pack along
	-- the top, over the track. A row of two 42 px badges reached past the screen's right quarter.)
	local rowLeft = HudErgonomics.StarterPack(844, 390, true, false, 58).Left - 14 - 2 * 42 * HudErgonomics.BadgeAspect - 12
	assert(rowLeft < 844 * 0.75, "(the bug: the old row of badges reached into the top middle)")
	-- On a phone the old place (the column at 94% x 24%, scaled 0.65) sat on the Starter Pack.
	local pack = HudErgonomics.StarterPack(844, 390, true)
	local oldColumnHeight = math.min(0.45140797 * 390, 0.16742837 * 844 / 0.6590389) * 0.65
	local oldLeft = 0.945 * 844 - oldColumnHeight * 0.6590389 / 2
	assert(HudErgonomics.Overlaps({ Left = oldLeft, Right = oldLeft + oldColumnHeight * 0.659, Top = 0.24 * 390 - oldColumnHeight / 2, Bottom = 0.24 * 390 + oldColumnHeight / 2 }, pack), "(the bug: the old phone place overlapped the Starter Pack)")

	local hud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(hud, "local plan = HudErgonomics.Badges(", "The Main HUD places the badges with HudErgonomics")
	has(hud, "rightList.FillDirection = Enum.FillDirection.Vertical", "...stacked in a column on phones")
	assert(not hud:find("Enum.FillDirection.Horizontal", 1, true), "...never in a row across the top")
	has(hud, "phoneColumn = plan.Column", "The phone column's plan is kept for the speedometer and the boost cards")
	has(hud, "selectorHolderScale.Scale = if speedometer then speedometer.Scale else 0.88", "The speedometer takes the column's scale")
	has(hud, "UDim2.new(MOBILE_SELECTOR_HOLDER_POS.X.Scale, 0, 0, math.floor(speedometer.HolderTop + 0.5))", "...and its place under the badges")
	has(hud, "buffsHolderBasePos = UDim2.fromOffset(math.floor(phoneColumn.Buffs.Right + 0.5), math.floor(phoneColumn.Buffs.Y + 0.5))", "The boost cards stand beside the speedometer")
	for world, place in places do
		local holder = place:GetService("StarterGui").WalkSpeedSelectorHUD.SelectorHolder
		local spec = HudErgonomics.Speedometer
		local button, value = holder.WalkSpeedModeButton, holder.RealWalkSpeedValue
		local function near(a, b)
			return math.abs(a - b) < 1e-5
		end
		assert(near(holder.Size.X.Scale, spec.HolderWidth) and near(holder.Size.Y.Scale, spec.HolderHeight) and holder.AnchorPoint.X == 1 and holder.AnchorPoint.Y == 0, world .. ": HudErgonomics knows the speedometer's holder")
		assert(near(button.Position.X.Scale, spec.ButtonX) and near(button.Position.Y.Scale, spec.ButtonY) and near(button.Size.X.Scale, spec.ButtonWidth) and near(button.Size.Y.Scale, spec.ButtonHeight), world .. ": ...its gauge")
		assert(near(value.Position.Y.Scale, spec.ValueY) and near(value.Size.Y.Scale, spec.ValueHeight), world .. ": ...and its read-out")
		assert(place:GetService("StarterGui").WalkSpeedSelectorHUD.ScreenInsets == place:GetService("StarterGui").Mainhud.ScreenInsets, world .. ": the speedometer shares the Main HUD's screen space")
	end
	has(hud, "offer.AbsolutePosition - mainhud.AbsolutePosition", "...measured in the Starter Pack's own screen space")
	assert(not hud:find("MOBILE_RIGHT_BUTTONS_POS", 1, true), "The old phone place is gone")
	local offer = read("src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau")
	has(offer, "HudErgonomics.StarterPack(viewport.X, viewport.Y, UserInputService.TouchEnabled, GuiService:IsTenFootInterface(), topBar.Y)", "The Starter Pack takes its box from the same rules, under the top bar")
	has(hud, "(GuiService:GetGuiInset()).Y", "The badges know the top bar's height too")

	for world, place in places do
		local buttons = place:GetService("StarterGui").Mainhud.Rightbuttons
		local victory = buttons["2xVictory"].UIGradient.Color.Keypoints
		local speed = buttons["2xSpeed"].UIGradient.Color.Keypoints
		assert(victory[1].Value.R > 0.95 and victory[1].Value.G > 0.85 and victory[1].Value.B < 0.4, world .. ": x2 Victory (Wins) is gold")
		assert(speed[2].Value.B > 0.95 and speed[2].Value.R < 0.2, world .. ": x2 Speed is blue")
		-- All of it: its fill, outline and inner rim (the rim was orange-yellow until the
		-- 2026-09-18 playtest). The price tag and Robux icon keep their green.
		local speedBadge = buttons["2xSpeed"]
		local warm = {}
		for _, child in speedBadge:GetChildren() do
			local gradients = {}
			if child:IsA("UIGradient") then
				table.insert(gradients, child)
			elseif child:IsA("UIStroke") then
				assert(child.Color.B >= child.Color.R, world .. ": x2 Speed's outline is not warm")
				local inner = child:FindFirstChildOfClass("UIGradient")
				if inner then
					table.insert(gradients, inner)
				end
			end
			for _, gradient in gradients do
				for _, point in gradient.Color.Keypoints do
					if point.Value.R > point.Value.B then
						table.insert(warm, gradient:GetFullName())
					end
				end
			end
		end
		assert(#warm == 0, world .. ": no yellow or orange left on x2 Speed: " .. table.concat(warm, ", "))
	end
	print("PASS badges: never within 12 px of the Starter Pack on 8 phones, 3 tablets, 6 desktops and consoles; on phones a right-edge column (Starter Pack, badges 24-40 px, speedometer, jump) with the boost cards beside it and the top middle clear; gold Wins / blue Speed in all places")
end

----------------------------------------------------------------------
-- 3. The touch Sprint button
----------------------------------------------------------------------
do
	for _, s in PHONES do
		for _, topBar in { 0, 58 } do
			local width, height = s[1], s[2] - topBar
			local sprint = HudErgonomics.SprintButton(width, height)
			local jump = HudErgonomics.JumpButton(width, height)
			assert(sprint.Size >= 46 and sprint.Size <= 54, ("%dx%d: Sprint is 46-54 px"):format(width, height))
			assert(not HudErgonomics.Overlaps(sprint, jump, 10), ("%dx%d: Sprint is at least 10 px from the jump button"):format(width, height))
			assert(not HudErgonomics.Overlaps(sprint, HudErgonomics.Thumbstick(width, height)), ("%dx%d: Sprint is clear of the thumbstick"):format(width, height))
			assert(sprint.Right <= width and sprint.Bottom <= height and sprint.Top >= 0, "Sprint is on screen")
			assert(sprint.Left > width / 2, "Sprint is on the right thumb's side")
		end
	end
	-- The jumping thumb: Sprint 30+ px from the jump button (36 where the bars leave room), and
	-- off the level and stamina bars wherever it keeps more than the minimum.
	assert(HudErgonomics.SprintGapMin >= 30 and HudErgonomics.SprintGap >= HudErgonomics.SprintGapMin, "Sprint's gap to the jump button is 30 px or more")
	local screens = table.clone(PHONES)
	for _, s in TABLETS do
		table.insert(screens, s)
	end
	for _, s in { { 640, 360 }, { 568, 320 }, { 1080, 810 }, { 2048, 1536 } } do
		table.insert(screens, s)
	end
	for _, s in screens do
		for _, topBar in { 0, 36, 58 } do
			local width, height = s[1], s[2] - topBar
			local label = ("%dx%d top %d"):format(s[1], s[2], topBar)
			local sprint = HudErgonomics.SprintButton(width, height)
			local jump = HudErgonomics.JumpButton(width, height)
			local gap = jump.Left - sprint.Right
			assert(gap >= HudErgonomics.SprintGapMin - 1e-6 and gap <= HudErgonomics.SprintGap + 1e-6, label .. ": Sprint 30-36 px from the jump button")
			local bars = HudErgonomics.CentreBarRects(width, height)
			local onBar = false
			for _, bar in bars do
				onBar = onBar or HudErgonomics.Overlaps(sprint, bar)
			end
			if gap > HudErgonomics.SprintGapMin + 1e-6 then
				assert(not onBar, label .. ": Sprint is off the level and stamina bars")
			end
			if gap < HudErgonomics.SprintGap - 1e-6 then
				-- Only where the whole gap would put it on a bar's end.
				local whole = { Left = jump.Left - HudErgonomics.SprintGap - sprint.Size, Right = jump.Left - HudErgonomics.SprintGap, Top = sprint.Top, Bottom = sprint.Bottom }
				local blocked = false
				for _, bar in bars do
					blocked = blocked or HudErgonomics.Overlaps(whole, bar, HudErgonomics.CentreBarGap)
				end
				assert(blocked, label .. ": the gap shrinks only for a bar")
			end
			if topBar > 0 and table.find(PHONES, s) then
				assert(math.abs(gap - HudErgonomics.SprintGap) < 1e-6 and not onBar, label .. ": a phone under the top bar keeps the whole gap, off the bars")
			end
		end
	end
	for world, place in places do
		local press = place:GetService("StarterGui").Mainhud.MobileSprint:FindFirstChild("PressScale")
		assert(press and press:IsA("UIScale"), world .. ": the Sprint button's pressed state is saved in the place")
	end
	local client = read("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau")
	has(client, "TweenService:Create(pressScale, pressDown, { Scale = 0.86 }):Play()", "Pressing Sprint shrinks it")
	has(client, "TweenService:Create(pressScale, pressUp, { Scale = 1 }):Play()", "...and it springs back on release")
	local hud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(hud, "local plan = HudErgonomics.SprintButton(size.X, size.Y)", "The Main HUD places Sprint with HudErgonomics")
	has(hud, "sprintCorner.CornerRadius = UDim.new(0.5, 0)", "...round")
	print("PASS Sprint: 46-54 px beside the jump button, clear of it and the thumbstick on 8 phones, 30-36 px from it and off the level and stamina bars on 15 screens (the whole 36 on phones); pressed state saved")
end

----------------------------------------------------------------------
-- 4. The Spin Wheel on phones
----------------------------------------------------------------------
do
	local saved = rb.deserializeModel(fs.readFile("src/ui/SpinWheelGui.rbxm"))[1]
	local holder = saved.Frame
	local shape = holder["Spin Wheel"]:FindFirstChildOfClass("UIAspectRatioConstraint")
	assert(shape and math.abs(shape.AspectRatio - 1) < 0.01, "The wheel keeps a 1:1 UIAspectRatioConstraint")
	assert(holder:FindFirstChild("CompactScale") and holder.CompactScale:IsA("UIScale"), "The saved panel carries the compact scale")
	local measure = SpinWheelLayout.Measure(holder)
	local function checkScreen(width, height, label)
		local plan = SpinWheelLayout.Compact(measure, saved, saved.Button, width, height, 3.2)
		local share = plan.Wheel.Diameter / height
		-- 2026-09-18 (Sung): 12% smaller than the 80% it was, and nothing in the top 45 px,
		-- where Roblox's top bar is (menu, chat, mic).
		if label == "phone" then
			assert(share >= 0.62 and share <= 0.72, ("%dx%d: the wheel is about 70%% of the screen's height (%.2f)"):format(width, height, share))
		else
			assert(share >= 0.55 and share <= 0.72, ("%dx%d: the wheel is big on tablets too (%.2f)"):format(width, height, share))
		end
		assert(plan.Wheel.Top >= SpinWheelLayout.CompactTopSafe and SpinWheelLayout.CompactTopSafe == 45, ("%dx%d: the wheel and its arrow stay under the top bar's 45 px (%.0f)"):format(width, height, plan.Wheel.Top))
		assert(plan.Wheel.Y + plan.Wheel.Reach <= height, "The wheel and its arrow are on screen")
		local rects = {}
		for name, r in plan.Rects do
			local box = { Left = r.X - r.Width / 2, Right = r.X + r.Width / 2, Top = r.Y - r.Height / 2, Bottom = r.Y + r.Height / 2, Name = name }
			assert(box.Left >= 0 and box.Right <= width and box.Top >= 45 and box.Bottom <= height, ("%dx%d: %s is on screen, under the top bar"):format(width, height, name))
			-- Clear of the wheel's circle (with its arrow above).
			local nx = math.clamp(plan.Wheel.X, box.Left, box.Right)
			local ny = math.clamp(plan.Wheel.Y, box.Top, box.Bottom)
			assert(math.sqrt((nx - plan.Wheel.X) ^ 2 + (ny - plan.Wheel.Y) ^ 2) > plan.Wheel.Reach, ("%dx%d: %s is clear of the wheel"):format(width, height, name))
			table.insert(rects, box)
		end
		for _, name in { "Claim", "X1", "X3", "X10", "WinsSpin" } do
			assert(plan.Rects[name], name .. " is placed")
			assert(plan.Rects[name].Height >= 44, ("%dx%d: %s is at least 44 px tall"):format(width, height, name))
		end
		assert(plan.Rects.Claim.Height >= plan.Rects.X1.Height, "Spin is at least as big as the packs (bigger wherever the column allows)")
		if label == "phone" then
			assert(plan.Rects.Claim.Height > plan.Rects.X1.Height, "On phones Spin is the biggest button")
		end
		for i, a in rects do
			for j = i + 1, #rects do
				assert(not HudErgonomics.Overlaps(a, rects[j]), ("%dx%d: %s and %s do not overlap"):format(width, height, a.Name, rects[j].Name))
			end
		end
		-- Scale values put the pieces back where the plan says.
		local inHolder = SpinWheelLayout.InHolder(plan, plan.Rects.X10)
		local w, h = plan.Holder.Width * plan.Scale, plan.Holder.Height * plan.Scale
		assert(math.abs(plan.Holder.X - w / 2 + inHolder.X * w - plan.Rects.X10.X) < 1e-6, "InHolder round-trips")
		local _ = h
	end
	for _, s in PHONES do
		checkScreen(s[1], s[2], "phone")
	end
	for _, s in TABLETS do
		checkScreen(s[1], s[2], "tablet")
	end
	assert(SpinWheelLayout.UseCompact(1920, 1080, false) == false and SpinWheelLayout.UseCompact(844, 390, true) == true, "Compact on touch screens, the designer's layout on desktops and consoles")
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	has(controller, "local plan = SpinWheelLayout.Compact(measure, gui, row, screen.X, screen.Y, skipAspect)", "The panel uses the compact layout")
	has(controller, "compactScale.Scale = plan.Scale", "...growing the wheel")
	has(controller, "Enum.ScreenInsets.DeviceSafeInsets", "...over the whole screen height")
	print("PASS Spin Wheel on phones: wheel about 70% of the height (1:1) under the top bar's 45 px, Spin/X1/X3/X10/Wins 44+ px in two columns, clear of the wheel and each other")
end

----------------------------------------------------------------------
-- 5. Consoles: safe zone and gamepad navigation
----------------------------------------------------------------------
do
	assert(HudErgonomics.SafeScale(0) == 0.05 and math.abs(HudErgonomics.SafeScale(1) - 0.95) < 1e-9, "The safe zone keeps 5% from each edge")
	for _, scale in { 0, 0.0745, 0.5, 0.911, 0.97, 1 } do
		local safe = HudErgonomics.SafeScale(scale)
		assert(safe >= 0.05 - 1e-9 and safe <= 0.95 + 1e-9, "Every HUD anchor lands inside the safe zone")
	end
	local pack = HudErgonomics.StarterPack(1920, 1080, false, true)
	assert(pack.Right <= 1920 * 0.95 and pack.Top >= 1080 * 0.05, "The Starter Pack stays inside the safe zone on a TV")
	local hud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	for _, name in { "leftBarBasePos", "levelBarBasePos", "speedsterBarBasePos", "rebithTrofBasePos" } do
		has(hud, name .. " = safePosition(" .. name .. ")", "The Main HUD moves " .. name .. " into the safe zone on consoles")
	end
	has(hud, "local DESKTOP_RIGHT_BUTTONS_POS = safePosition(", "...the badges")
	has(hud, "local DESKTOP_BUFFS_HOLDER_POS = safePosition(", "...the boost cards")
	has(hud, "local DESKTOP_SELECTOR_HOLDER_POS = safePosition(", "...the speedometer")
	local console = read("src/common/StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.client.luau")
	has(console, '["SpinWheelGui"] = true', "The Spin Wheel is a managed menu (ButtonB closes it)")
	has(console, '["Shop"] = true', "The shop is a managed menu")
	local wheel = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	has(wheel, "spinButton.NextSelectionRight = packs[1]", "The wheel's buttons lead to each other")
	has(wheel, "GuiService.SelectedObject = spinButton", "...and Spin takes the selection on open")
	print("PASS consoles: 5% safe zone on the HUD and the Starter Pack; gamepad navigation on the wheel, the shop and the Revive offer")
end

-- The Starter Pack comes back from a menu to the spot StarterPackOffer laid out, above the
-- x2 badges (a copy kept before that layout put the desktop spot over them on phones).
do
	local offer = read("src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau")
	local hud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(offer, 'holder:SetAttribute("HudBasePosition", base)', "The pack publishes its laid-out spot")
	has(hud, 'offerHolder:GetAttribute("HudBasePosition")', "The HUD slides it back to that spot")
	has(hud, 'holder:GetAttributeChangedSignal("HudBasePosition")', "...following every new layout")
	assert(not hud:find("offerHolder.Position.X.Offset <= 0", 1, true), "No stale copy of the pack's spot")
	print("PASS Starter Pack returns above the x2 badges after menus")
end

-- Dev / Tester titles: particles on and above the head, text stacked over the name/speed.
do
	local overhead = read("src/common/StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau")
	has(overhead, "billboard.StudsOffsetWorldSpace = Config.OverheadStudsOffset", "The title shares the name board's anchor")
	has(overhead, "billboard.Size = UDim2.fromOffset(260, 2 * (35 + gap + titleHeight))", "...stacked above it in pixels")
	for _, path in { "src/common/ServerScriptService/Bootstrap.server.luau", "src/common/ServerScriptService/Progression/PlayerStats.server.luau" } do
		local source = read(path)
		has(source, "emitter.Enabled = true", path .. ": title particles on")
		has(source, "CFrame.new(0, tonumber(Config.TitleParticleHeight) or 4, 0)", path .. ": title part above the head")
	end
	print("PASS titles: particles on above the head, clear of the name and speed")
end

print("ALL UI ERGONOMICS CHECKS PASSED")
