-- test_admin_panel_and_spin_hud.luau
-- One admin panel, and the Spin Wheel's button on the Main HUD:
--
--   1. The admin UI is one panel, the Admin Abuse Panel: the old SpeedsterAdminPanelGui and
--      the first admin abuse client are retired (their scripts hold no code, in the sources
--      and in every built place), the floating broadcast bar is gone, the topbar has one
--      admin icon, F2 opens only the panel, and the chat commands (/admin, /panel, /g with
--      no message) open it.
--   2. The testing places show the preview features to everyone.
--   3. The Spin Wheel button: beside x2 Speed on the right, with no button behind it, a small
--      copy of the wheel turning with the designer's label and badge (from Time Gifts); its
--      text follows the wheel's state (free spin, tickets, countdown and price); a click
--      opens the panel; it follows the right buttons when they hide or x2 Speed is gone.
--   4. The Main HUD comes back from every topbar menu, however it closes; the admin panel,
--      run for real on a small Roblox, is ready from the first frame, opens with F2 at once,
--      scales to the screen, and every card of its categories sends its action.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local UDim2, Vector2 = roblox.UDim2, roblox.Vector2

local function read(path)
	-- Some sources are CRLF: the multi-line needles below are written with "\n".
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function codeOf(source)
	return (string.gsub(source, "%-%-[^\n]*", ""))
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-4)
end

-- 1. One admin panel ------------------------------------------------------------------------
do
	local retired = {
		"src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseClient.client.luau",
	}
	for _, path in retired do
		assert(string.match(codeOf(read(path)), "^%s*$"), path .. " is retired and holds no code")
	end
	for _, file in { "World1Update3New.rbxl", "World2Update3new.rbxl", "World3Update3New.rbxl" } do
		local scripts = roblox.deserializePlace(fs.readFile(file)):GetService("StarterPlayer").StarterPlayerScripts
		for _, path in { { "UI", "AdminPanelController" }, { "Admin", "AdminAbuseClient" } } do
			local script = scripts[path[1]]:FindFirstChild(path[2])
			assert(script and string.match(codeOf(script.Source), "^%s*$"), file .. ": " .. path[2] .. " is retired")
		end
		assert(scripts.Admin:FindFirstChild("AdminAbusePanelController"), file .. " runs the admin panel")
	end

	-- Nothing builds the old panel or binds F2 but the admin panel.
	local function sources(folder, list)
		for _, entry in fs.readDir(folder) do
			local path = folder .. "/" .. entry
			if fs.isDir(path) then
				sources(path, list)
			elseif string.match(entry, "%.luau$") then
				table.insert(list, path)
			end
		end
		return list
	end
	for _, path in sources("src", {}) do
		local code = codeOf(read(path))
		assert(not string.find(code, "SpeedsterAdminPanelGui", 1, true), path .. " still uses the old admin panel")
		assert(not string.find(code, "AdminAnnouncementBar", 1, true), path .. " still builds the floating broadcast bar")
		-- AdminFlying was the retired panel's own flight loop; set with nothing to fly, it
		-- stops Flight and normal movement.
		assert(not string.find(code, 'SetAttribute("AdminFlying", true', 1, true) and not string.find(code, 'SetAttribute("AdminFlying", enabled', 1, true),
			path .. " turns on AdminFlying, which nothing flies any more")
		if string.find(code, "KeyCode.F2", 1, true) then
			assert(string.find(path, "AdminAbusePanelController", 1, true), path .. " binds F2 too; F2 is the admin panel's")
		end
	end
	local messages = read("src/common/StarterGui/Messages/MessageHandler.client.luau")
	assert(not string.find(messages, "UserInputService", 1, true) and not string.find(messages, "GlobalAnnouncementRequest", 1, true),
		"MessageHandler only shows announcements")
	has(messages, "DisplayRemote.OnClientEvent:Connect(function(payload, legacyDuration)", "Announcements still show")
	has(messages, "pcall(displayAnnouncement, item[1], item[2])", "...one banner at a time")

	local topbar = read("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
	local _, adminIcons = string.gsub(topbar, "image = ADMIN_IMAGE", "")
	assert(adminIcons == 1, "The topbar has one admin icon")
	has(topbar, 'request = "AdminAbuse",\n\t\tpanel = "AdminAbusePanelGui",', "It opens the admin panel")
	local menuEvents = read("src/common/ReplicatedStorage/Shared/MenuEvents.luau")
	has(menuEvents, 'Admin = "OpenAdminAbusePanel"', 'MenuEvents "Admin" opens the admin panel')
	has(menuEvents, 'Admin = "AdminAbusePanelGui"', 'MenuEvents "Admin" is the admin panel\'s GUI')

	-- The chat commands, on the panel's own code.
	local panel = read("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	local first = assert(string.find(panel, "local function openFromChat", 1, true))
	local last = assert(string.find(panel, "-- Ask straight away;", first, true))
	local chunk = string.sub(panel, first, last - 1)
	for _, name in { "allowed", "isOpen", "showTabFromOutside" } do
		chunk = string.gsub(chunk, "%f[%w_]" .. name .. "%f[^%w_]", "ctx." .. name)
	end
	local listeners = {}
	local function remote(name)
		return { OnClientEvent = { Connect = function(_, callback)
			listeners[name] = callback
		end } }
	end
	local requests, tabs = {}, {}
	local ctx = { allowed = true, isOpen = false }
	ctx.showTabFromOutside = function(tab)
		table.insert(tabs, tab)
	end
	local env = setmetatable({
		ctx = ctx,
		MenuEvents = { Request = function(name)
			table.insert(requests, name)
			ctx.isOpen = true
		end },
		ReplicatedStorage = { WaitForChild = function()
			return { WaitForChild = function(_, name)
				return remote(name)
			end }
		end },
		task = { spawn = function(callback)
			callback()
		end },
	}, { __index = _G })
	luau.load(chunk, { environment = env })()
	assert(listeners.AdminPanelStatus and listeners.GlobalAnnouncementRequest, "The panel listens to both chat commands")
	listeners.AdminPanelStatus({ kind = "OpenUI" })
	listeners.AdminPanelStatus({ kind = "OpenUI" })
	assert(#requests == 1 and requests[1] == "AdminAbuse", "/admin opens the panel once, even when two services answer")
	ctx.isOpen = false
	listeners.GlobalAnnouncementRequest("OpenBar")
	assert(#requests == 2 and tabs[#tabs] == "Announce", "/g with no message opens the panel on Announcements")
	ctx.isOpen, ctx.allowed = false, false
	listeners.AdminPanelStatus({ kind = "OpenUI" })
	listeners.GlobalAnnouncementRequest("OpenBar")
	assert(#requests == 2, "Nothing opens for a player the server has not allowed")

	-- Stats & Passes: the first admin panel's service is switched off (it starts with
	-- `if true then return`), which is why those buttons did nothing. Every tool is now an
	-- action of the working service, and the Gekkoh giveaway is gone.
	local old = read("src/common/ServerScriptService/Admin/AdminPanelService.server.luau")
	assert(string.find(old, "if true then", 1, true) and string.find(old, "return -- Admin Panel Service disabled", 1, true), "The first admin service stays switched off")
	assert(not string.find(panel, "AdminPanelAction", 1, true), "The panel sends nothing to the switched-off service")
	assert(not string.find(panel, "GekoFlyGiveaway", 1, true), "The Gekkoh giveaway is gone")
	local service = read("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	for _, action in { "GiveStat", "Pass", "ResetStats", "ForceRebirth", "RedeemCode", "Travel", "GiveSpeed", "RemoveSpeed" } do
		has(panel, 'action = "' .. action .. '"', "The admin panel sends " .. action)
		has(service, 'action == "' .. action .. '"', "The admin service handles " .. action)
	end
	for _, pass in { "VIP", "Flight", "TwoXSpeed", "TwoXVictory", "InfiniteRevives", "DarkZonic", "All" } do
		has(panel, '{ "' .. pass .. '", ', "Gamepass button " .. pass)
		has(service, pass .. " = true", "The admin service knows the gamepass " .. pass)
	end
	has(panel, '{ "Stats", "💰", "Stats & Passes" },', "The Stats & Passes tab")
	has(service, 'remote("AdminPanelStatus")', "The admin service provides the remote /admin in chat answers on")
	print("PASS one admin panel: old panel and client retired, no floating bar, one topbar icon, F2 and chat commands open it, stats and passes work, no Gekkoh giveaway")
end

-- 2. Testing places -------------------------------------------------------------------------
do
	local stub = { GetAttribute = function()
		return nil
	end, FindFirstChild = function()
		return nil
	end }
	local configEnv = setmetatable({ workspace = stub, typeof = typeof, print = function() end, warn = function() end }, { __index = _G })
	for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		configEnv[name] = roblox[name]
	end
	configEnv.game = { PlaceId = 0, GetService = function()
		return stub
	end }
	local Config = luau.load(read("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = configEnv })()
	local testing = {}
	for _, id in Config.PreviewFeatures.TestingPlaceIds do
		testing[id] = true
	end
	assert(testing[138540610580146] and testing[96501592055150] and testing[94956471703437], "The three testing places are listed")
	local function gateIn(placeId)
		local env = setmetatable({
			game = { PlaceId = placeId, GetService = function(_, name)
				if name == "RunService" then
					return { IsStudio = function()
						return false
					end }
				end
				return { WaitForChild = function()
					return { WaitForChild = function()
						return "Config"
					end }
				end }
			end },
			require = function()
				return Config
			end,
		}, { __index = _G })
		return luau.load(read("src/common/ReplicatedStorage/Shared/FeatureGate.luau"), { environment = env })()
	end
	for id in testing do
		assert(gateIn(id).IsPreviewPlayer({ UserId = 1 }) == true, "Everyone sees the preview features in testing place " .. id)
	end
	assert(gateIn(123).IsPreviewPlayer({ UserId = 1 }) == true and gateIn(123).IsPreviewPlayer({ UserId = 767108248 }) == true,
		"Anywhere else, all players also see the features now that preview restrictions are lifted")
	print("PASS preview features are unlocked for every player in testing places and live servers")
end

-- 3. The Spin Wheel button on the Main HUD --------------------------------------------------------
do
	local SpinWheelCatalog = require("../src/common/ReplicatedStorage/Shared/SpinWheelCatalog")
	local SpinWheelLayout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")

	-- The countdown and the text rules.
	for seconds, text in { [0] = "0:00", [7] = "0:07", [59.2] = "1:00", [247] = "4:07", [3599] = "59:59", [3600] = "1:00", [10799] = "2:59" } do
		assert(SpinWheelCatalog.ShortClock(seconds) == text, "ShortClock(" .. seconds .. ") = " .. text)
	end
	local function hud(view)
		return SpinWheelCatalog.HudButton(view)
	end
	assert(hud({ Loading = true }) == "Spin", "Loading")
	local text, badge = hud({ FreeAvailable = true, Tickets = 0, SecondsToFree = 500 })
	assert(text == "Free Spin!" and badge == "!", "A free spin")
	text, badge = hud({ FreeAvailable = true, Tickets = 2, SecondsToFree = 500 })
	assert(text == "Free Spin!" and badge == "3", "A free spin and two tickets: three spins")
	text, badge = hud({ FreeAvailable = false, Tickets = 0, SecondsToFree = -1 })
	assert(text == "Free Spin!" and badge == "!", "The wait is over before the server says so")
	text, badge = hud({ FreeAvailable = false, Tickets = 2, SecondsToFree = 500, PriceRobux = 16, ShowPrice = true })
	assert(text == "2x Spin!" and badge == "2", "Tickets")
	text, badge = hud({ FreeAvailable = false, Tickets = 0, SecondsToFree = 247, PriceRobux = 16, ShowPrice = false })
	assert(text == "4:07" and badge == nil, "The countdown's turn")
	text, badge = hud({ FreeAvailable = false, Tickets = 0, SecondsToFree = 247, PriceRobux = 16, ShowPrice = true })
	assert(text == "Spin 16 R$" and badge == nil, "The price's turn")
	assert(hud({ FreeAvailable = false, Tickets = 0, SecondsToFree = 7200, ShowPrice = true }) == "2:00", "No spins for sale: always the countdown")

	-- The controller's button, built on the real HUD and the designer's wheel. Lune's
	-- instances have no events, so the button's connections are caught by name.
	local controller = read("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	local first = assert(string.find(controller, "local HUD_BUTTON_NAME", 1, true))
	local last = assert(string.find(controller, "task.spawn(function()\n\tlocal mainhud", first, true))
	local chunk = string.sub(controller, first, last - 1)
	for _, name in { "state", "livePrices" } do
		chunk = string.gsub(chunk, "%f[%w_]" .. name .. "%f[^%w_]", "ctx." .. name)
	end
	local hooked
	chunk, hooked = string.gsub(chunk, "button%.(%a+):Connect%(", 'hook("%1", ')
	assert(hooked == 3, "The button connects hover in, hover out and click")
	local holder = roblox.deserializeModel(fs.readFile("design/ui/SpinWheelAndEarnings.rbxm"))[1]:FindFirstChild("SpinWheel"):FindFirstChild("Frame")
	local measure = SpinWheelLayout.Measure(holder)
	local hubCap = roblox.Instance.new("Frame")
	hubCap.Name = "HubCap"
	roblox.Instance.new("UIAspectRatioConstraint").Parent = hubCap
	hubCap.Parent = holder
	local ctx = { state = nil, livePrices = {}, now = 1000, clock = 0 }
	local hooks, requests, sounds = {}, {}, 0
	local env = setmetatable({
		ctx = ctx,
		hook = function(name, callback)
			hooks[name] = callback
		end,
		Instance = roblox.Instance,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Enum = roblox.Enum,
		TweenInfo = { new = function()
			return {}
		end },
		TweenService = { Create = function()
			return { Play = function() end }
		end },
		PurchaseButtonSound = { Play = function()
			sounds += 1
		end },
		MenuEvents = { Request = function(name)
			table.insert(requests, name)
		end },
		SpinWheelCatalog = SpinWheelCatalog,
		SpinWheelLayout = SpinWheelLayout,
		LABEL_SWAP_SECONDS = 3,
		wheel = holder:FindFirstChild("Spin Wheel"),
		wheelHolder = holder,
		measure = measure,
		serverNow = function()
			return ctx.now
		end,
		os = { clock = function()
			return ctx.clock
		end },
		RunService = { RenderStepped = { Connect = function() end } },
	}, { __index = _G })
	local build, refresh, place, setPlacement = luau.load(chunk .. [[

return buildHudButton, refreshHudButton, placeHudButton, function(button, mainhud, rightButtons)
	hudButton, hudMainhud, hudRightButtons = button, mainhud, rightButtons
end]], { environment = env })()

	local placeFile = roblox.deserializePlace(fs.readFile("World1Update3New.rbxl"))
	local mainhud = placeFile:GetService("StarterGui").Mainhud
	local leftBar = mainhud.LeftSideBar
	local timeGifts = leftBar["Time Gifts"]
	build(mainhud)
	build(mainhud)
	local count = 0
	for _, child in mainhud:GetChildren() do
		if child.Name == "SpinWheel" then
			count += 1
		end
	end
	local button = mainhud:FindFirstChild("SpinWheel")
	assert(count == 1 and button:IsA("ImageButton"), "One Spin Wheel button, in Mainhud itself")
	assert(not leftBar:FindFirstChild("SpinWheel") and not mainhud.Rightbuttons:FindFirstChild("SpinWheel"), "Not in the left side bar, nor in the right buttons' list")
	assert(button.ImageTransparency == 1 and button.BackgroundTransparency == 1, "No button behind the wheel")
	for _, child in button:GetChildren() do
		assert(not (child:IsA("UIStroke") or child:IsA("UICorner") or child:IsA("UIGradient")), "No outline, corners or fill: " .. child.ClassName)
	end
	assert(button.AnchorPoint == Vector2.new(1, 0.5), "Placed by its right edge and middle")
	local icon = button:FindFirstChild("Icon")
	local timeGiftsIcon = timeGifts:FindFirstChild("Icon")
	assert(icon.Size == timeGiftsIcon.Size and icon.Position == timeGiftsIcon.Position and icon.ImageTransparency == 1, "The icon keeps its place and shows the wheel instead")
	local label = button:FindFirstChild("Name")
	assert(label.Size == timeGifts:FindFirstChild("Name").Size and label:FindFirstChildOfClass("UIStroke"), "The text keeps the designer's label and outline")
	local spinner = icon:FindFirstChild("Spinner")
	local mini = spinner and spinner:FindFirstChild("Spin Wheel")
	assert(mini and not mini:FindFirstChild("Spin"), "A copy of the wheel turns in the icon, prizes left out")
	local artX = mini.Position.X.Scale + measure.ArtCenter.x / measure.WheelWidth * mini.Size.X.Scale
	local artY = mini.Position.Y.Scale + measure.ArtCenter.y / measure.WheelHeight * mini.Size.Y.Scale
	assert(near(artX, 0.5) and near(artY, 0.5), "The wheel art's centre is the spinner's centre, so it turns in place")
	assert(near(2 * measure.ArtRadius / measure.WheelWidth * mini.Size.X.Scale, 1), "The wheel art fills the icon")
	local cap = icon:FindFirstChild("HubCap")
	assert(cap and cap.ZIndex > spinner.ZIndex and near(cap.Size.X.Scale, 2 * SpinWheelLayout.HubCapRadiusShare), "The hub cap sits still over the turning wheel")
	local badgeFrame = button:FindFirstChild("!")
	assert(badgeFrame.Size.X.Scale <= 0.3 and near(badgeFrame.Size.X.Scale, badgeFrame.Size.Y.Scale, 1e-4), "The badge is small, and still round")
	assert(badgeFrame.ZIndex > icon.ZIndex, "The badge draws over the wheel")
	has(controller, "hudSpinner.Rotation = os.clock() * HUD_WHEEL_DEGREES_PER_SECOND % 360\n\t\tplaceHudButton()", "The wheel turns and follows x2 Speed every frame")

	-- A click opens the panel.
	assert(hooks.Activated and hooks.MouseEnter and hooks.MouseLeave, "Click and hover are wired")
	hooks.MouseEnter()
	hooks.MouseLeave()
	hooks.Activated()
	assert(#requests == 1 and requests[1] == "SpinWheel" and sounds == 1, "A click plays the button sound and opens the Spin Wheel")
	has(read("src/common/ReplicatedStorage/Shared/MenuEvents.luau"), 'SpinWheel = "OpenSpinWheelPanel",', "The SpinWheel menu's event")
	has(controller, 'MenuEvents.Get("OpenSpinWheelPanel").Event:Connect(function(action)', "The panel answers it")
	assert(not string.find(read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau"), 'SpinWheel = "SpinWheel"', 1, true),
		"MainHUDController does not wire it a second time")

	-- The texts.
	local function show(state, clock, prices)
		ctx.state, ctx.clock, ctx.livePrices = state, clock or 0, prices or {}
		refresh()
		return label.Text, if badgeFrame.Visible then badgeFrame:FindFirstChildOfClass("TextLabel").Text else nil
	end
	assert(show(nil) == "Spin" and not badgeFrame.Visible, "Before the state arrives")
	local text2, badge2 = show({ FreeAvailable = true, Tickets = 0, NextFreeAt = 5000, ServerTime = 1000 })
	assert(text2 == "Free Spin!" and badge2 == "!", "Free spin: " .. text2)
	text2, badge2 = show({ FreeAvailable = false, Tickets = 2, NextFreeAt = 5000 })
	assert(text2 == "2x Spin!" and badge2 == "2", "Tickets: " .. text2)
	local forSale = { FreeAvailable = false, Tickets = 0, NextFreeAt = ctx.now + 247, PaidSpinsAllowed = true,
		Products = { { Key = "Spins3", Spins = 3, PriceRobux = 30 }, { Key = "Spins1", Spins = 1, PriceRobux = 16, ProductId = 42 } } }
	text2, badge2 = show(forSale, 0)
	assert(text2 == "4:07" and badge2 == nil, "Countdown turn: " .. text2)
	text2 = show(forSale, 3.5)
	assert(text2 == "Spin 16 R$", "Price turn, the smallest pack: " .. text2)
	text2 = show(forSale, 3.5, { [42] = 19 })
	assert(text2 == "Spin 19 R$", "The live price wins: " .. text2)
	forSale.PaidSpinsAllowed = false
	assert(show(forSale, 3.5) == "4:07", "Not for sale to this player: the countdown only")
	has(controller, "\trefreshTimer()\n\trefreshHudButton()\nend", "The button follows every state update")
	has(controller, "\t\trefreshTimer()\n\t\trefreshHudButton()\n", "...and the clock")

	-- Where it stands (whole pixels, as UDim offsets are): beside x2 Speed, with the numbers of a real 2000x1019 screen (x2 Speed
	-- at x 1700, y 300, 85 high), and following x2 Victory, then the frame, when hidden.
	local function guiObject(left, top, width, height, visible)
		return {
			Visible = visible ~= false,
			AbsolutePosition = Vector2.new(left, top),
			AbsoluteSize = Vector2.new(width, height),
			IsA = function(_, className)
				return className == "GuiObject"
			end,
		}
	end
	local speed = guiObject(1700, 300, 265, 85)
	local victory = guiObject(1700, 446, 265, 85)
	local rightButtons = guiObject(1690, 280, 290, 440)
	rightButtons.FindFirstChild = function(_, name)
		return if name == "2xSpeed" then speed elseif name == "2xVictory" then victory else nil
	end
	local fake = { Position = UDim2.new(), Size = UDim2.new() }
	setPlacement(fake, { AbsolutePosition = Vector2.new(0, 0) }, rightButtons)
	place()
	local side = fake.Size.X.Offset
	local right, middle = fake.Position.X.Offset, fake.Position.Y.Offset
	assert(near(middle, 342.5, 1) and side > 85 and fake.Size.Y.Offset == side, "Level with x2 Speed, a square taller than it")
	local badgeRight = right - side + (badgeFrame.Position.X.Scale + badgeFrame.Size.X.Scale / 2) * side
	assert(right < 1700 and badgeRight < 1700, string.format("Left of x2 Speed, badge included (badge ends at %.0f)", badgeRight))
	assert(right - side > 1300 and middle - side / 2 > 160, "Clear of the middle of the screen and of the Starter Pack")
	speed.Visible = false
	place()
	assert(near(fake.Position.Y.Offset, 488.5, 1), "With x2 Speed hidden, beside x2 Victory")
	victory.Visible = false
	place()
	assert(fake.Position.X.Offset < 1690 + 290 and fake.Position.Y.Offset > 280, "With both hidden, by the right buttons' frame")
	speed.Visible, speed.AbsolutePosition = true, Vector2.new(1700, 1400)
	place()
	assert(fake.Position.Y.Offset > 1019, "When the right buttons slide away for a menu, it goes with them")
	print("PASS the Spin Wheel button: beside x2 Speed with no background, a turning wheel, free/tickets/countdown/price texts, opens the panel")
end

-- 4. The Main HUD comes back, and the admin panel runs --------------------------------------
do
	-- Every menu opened from the topbar hides the Main HUD, and brings it back however it closes.
	local mainHud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	local modalList = assert(string.match(mainHud, "local MODAL_SCREEN_GUIS = (%b{})"), "MainHUDController lists its modal ScreenGuis")
	for _, name in { "QuestGui", "AfkRewardsGui", "SpinWheelGui", "AdminAbusePanelGui", "Shop", "DailyReward", "Settings" } do
		has(modalList, '"' .. name .. '"', "The Main HUD follows " .. name)
	end
	for path, menu in {
		["src/common/StarterPlayer/StarterPlayerScripts/UI/QuestController.client.luau"] = "Quests",
		["src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau"] = "Afk",
		["src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau"] = "SpinWheel",
	} do
		local source = read(path)
		local restore = 'Enabled = false\n\t\t\t-- The Main HUD comes back however the panel was closed (X, the dark background, Escape,\n\t\t\t-- another menu), unless another menu is open by now.\n\t\t\tif not MenuEvents.AnyOpen("'
			.. menu .. '") then\n\t\t\t\tMenuEvents.SetHUDVisible(true, nil)'
		has(source, restore, path .. " brings the Main HUD back once its close has finished")
	end

	-- A small Roblox: instances, signals, a task scheduler.
	local rb = roblox
	local function signal()
		local s = { listeners = {} }
		function s:Connect(callback)
			table.insert(self.listeners, callback)
			return { Disconnect = function() end }
		end
		function s:Fire(...)
			for _, callback in table.clone(self.listeners) do
				callback(...)
			end
		end
		return s
	end
	local methods = {}
	local EVENT_NAMES = { Activated = true, MouseEnter = true, MouseLeave = true, Completed = true, InputChanged = true, InputEnded = true }
	local function instance(class)
		local object = {
			props = { ClassName = class, Name = class, Visible = true, Text = "", ZIndex = 1, Scale = 1, Position = rb.UDim2.new(), Size = rb.UDim2.new() },
			children = {},
			events = {},
			attrs = {},
		}
		return setmetatable(object, {
			__index = function(self, key)
				if methods[key] then
					return methods[key]
				end
				if self.props[key] ~= nil then
					return self.props[key]
				end
				for _, childObject in self.children do
					if childObject.Name == key then
						return childObject
					end
				end
				if EVENT_NAMES[key] or string.match(key, "Event$") or string.match(key, "Began$") or string.match(key, "Added$") or string.match(key, "Removing$") then
					self.events[key] = self.events[key] or signal()
					return self.events[key]
				end
				return nil
			end,
			__newindex = function(self, key, value)
				if key == "Parent" then
					local old = self.props.Parent
					if old then
						local index = table.find(old.children, self)
						if index then
							table.remove(old.children, index)
						end
					end
					if value then
						table.insert(value.children, self)
					end
				end
				self.props[key] = value
			end,
		})
	end
	local GUI_OBJECTS = { Frame = true, ScrollingFrame = true, TextButton = true, ImageButton = true, TextLabel = true, TextBox = true, ImageLabel = true }
	function methods:IsA(class)
		return self.ClassName == class or class == "Instance"
			or (class == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton"))
			or (class == "GuiObject" and GUI_OBJECTS[self.ClassName] == true)
	end
	function methods:FindFirstChild(name)
		for _, childObject in self.children do
			if childObject.Name == name then
				return childObject
			end
		end
		return nil
	end
	function methods:WaitForChild(name)
		return assert(self:FindFirstChild(name), "Missing " .. self.Name .. "." .. name)
	end
	function methods:GetChildren()
		return table.clone(self.children)
	end
	function methods:GetDescendants()
		local all = {}
		for _, childObject in self.children do
			table.insert(all, childObject)
			for _, descendant in childObject:GetDescendants() do
				table.insert(all, descendant)
			end
		end
		return all
	end
	function methods:FindFirstChildOfClass(class)
		for _, childObject in self.children do
			if childObject:IsA(class) then
				return childObject
			end
		end
		return nil
	end
	function methods:GetPropertyChangedSignal(key)
		self.events["changed_" .. key] = self.events["changed_" .. key] or signal()
		return self.events["changed_" .. key]
	end
	function methods:GetAttribute(key)
		return self.attrs[key]
	end
	function methods:SetAttribute(key, value)
		self.attrs[key] = value
		self:GetAttributeChangedSignal(key):Fire()
	end
	function methods:GetAttributeChangedSignal(key)
		return self:GetPropertyChangedSignal("attr_" .. key)
	end
	function methods:Destroy()
		self.Parent = nil
	end
	function methods:Fire(...)
		self.Event:Fire(...)
	end
	function methods:FireServer(payload)
		table.insert(self.calls, payload)
	end
	local function child(parent, class, name)
		local object = instance(class)
		object.Name = name
		object.Parent = parent
		return object
	end
	local function find(root, class, textValue)
		for _, descendant in root:GetDescendants() do
			if descendant.ClassName == class and (textValue == nil or descendant.Text == textValue or descendant.PlaceholderText == textValue) then
				return descendant
			end
		end
		return nil
	end
	-- A card or row button whose own label, or a label inside it, reads `textValue`.
	local function buttonWith(root, textValue)
		for _, descendant in root:GetDescendants() do
			if descendant.ClassName == "TextButton" then
				if descendant.Text == textValue then
					return descendant
				end
				for _, inner in descendant.children do
					if inner.ClassName == "TextLabel" and inner.Text == textValue then
						return descendant
					end
				end
			end
		end
		return nil
	end

	local ADMIN = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau"
	local function newWorld(attributeAllowed)
		local world = { deferred = {}, hud = {} }
		local services = {}
		for _, name in { "Players", "ReplicatedStorage", "Workspace", "UserInputService", "RunService", "TweenService" } do
			services[name] = instance(name)
		end
		services.TweenService.Create = function()
			return { Play = function() end }
		end
		local player = child(services.Players, "Player", "Admin")
		player.UserId = 767108248
		player.DisplayName = "Admin"
		local other = instance("Player")
		other.UserId = 42
		other.DisplayName = "Other"
		services.Players.LocalPlayer = player
		services.Players.GetPlayers = function()
			return { player, other }
		end
		services.Players.GetUserThumbnailAsync = function()
			return "rbxthumb://avatar"
		end
		local playerGui = child(player, "PlayerGui", "PlayerGui")
		child(player, "PlayerScripts", "PlayerScripts")
		child(playerGui, "ScreenGui", "Settings")
		local camera = child(services.Workspace, "Camera", "Camera")
		camera.ViewportSize = rb.Vector2.new(1280, 720)
		services.Workspace.CurrentCamera = camera
		local remotes = child(services.ReplicatedStorage, "Folder", "Remotes")
		local shared = child(services.ReplicatedStorage, "Folder", "Shared")
		world.remotes = {}
		for _, name in { "AdminAbusePanel", "AdminPanelStatus", "GlobalAnnouncementRequest", "AdminPanelAction" } do
			local remoteObject = child(remotes, "RemoteEvent", name)
			remoteObject.calls = {}
			world.remotes[name] = remoteObject
		end
		if attributeAllowed then
			player.attrs.AdminAbusePanelAllowed = true
		end
		local modules = {}
		local env = setmetatable({
			game = { GetService = function(_, name)
				return assert(services[name], name)
			end },
			workspace = services.Workspace,
			Instance = { new = instance },
			Enum = rb.Enum,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
			Vector3 = rb.Vector3,
			Color3 = rb.Color3,
			Font = rb.Font,
			TweenInfo = { new = function()
				return {}
			end },
			ColorSequence = rb.ColorSequence,
			ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
			NumberSequence = rb.NumberSequence,
			NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
			task = {
				spawn = function(callback, ...)
					local thread = coroutine.create(callback)
					local ok, problem = coroutine.resume(thread, ...)
					assert(ok, problem)
					return thread
				end,
				defer = function(callback, ...)
					table.insert(world.deferred, table.pack(callback, ...))
				end,
				delay = function() end,
				wait = function()
					if coroutine.isyieldable() then
						coroutine.yield()
					end
				end,
			},
			print = function() end,
			warn = function() end,
			require = function(object)
				return assert(modules[object.Name], "module " .. tostring(object.Name))
			end,
		}, { __index = _G })
		for _, name in { "StudUi", "GamePanelStyle", "MenuEvents" } do
			env.script = child(shared, "ModuleScript", name)
			modules[name] = luau.load(read("src/common/ReplicatedStorage/Shared/" .. name .. ".luau"), { environment = env })()
		end
		modules.MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
			table.insert(world.hud, visible)
		end)
		env.script = instance("LocalScript")
		luau.load(read(ADMIN), { environment = env })()
		function world.flush()
			while #world.deferred > 0 do
				local item = table.remove(world.deferred, 1)
				item[1](table.unpack(item, 2, item.n))
			end
		end
		function world.key(keyCode)
			services.UserInputService.InputBegan:Fire({ KeyCode = keyCode }, false)
		end
		function world.gui()
			return playerGui:FindFirstChild("AdminAbusePanelGui")
		end
		world.input = services.UserInputService
		world.player, world.camera = player, camera
		world.flush()
		return world
	end
	local function lastCall(remoteObject)
		return remoteObject.calls[#remoteObject.calls]
	end

	-- An admin known from the first frame: the panel is ready, F2 opens it at once.
	local world = newWorld(true)
	local panelRemote = world.remotes.AdminAbusePanel
	assert(panelRemote.calls[1] and panelRemote.calls[1].action == "Hello", "The panel says Hello straight away, not after 3 seconds")
	local gui = world.gui()
	assert(gui and gui.Enabled == false, "The panel is built as soon as the player is known to be an admin")
	world.key(rb.Enum.KeyCode.F2)
	assert(gui.Enabled == true and world.hud[#world.hud] == false, "F2 opens it at once, and the Main HUD steps aside")
	panelRemote.OnClientEvent:Fire({ kind = "Permission", allowed = true, tracks = { { Name = "Song A", Id = "rbxassetid://1" } } })

	local panel = gui.Panel
	-- What broke it in Roblox: a ScreenGui made in code draws by global ZIndex, so the copied
	-- Settings art (ZIndex 2) covered every card and button (ZIndex 1), and ModalJuice
	-- animated that art as a header icon. The window now draws sibling by sibling, and has
	-- no image of its own for ModalJuice to pick up.
	assert(gui.ZIndexBehavior == rb.Enum.ZIndexBehavior.Sibling, "The panel draws sibling by sibling")
	for _, childObject in panel:GetChildren() do
		assert(childObject.ClassName ~= "ImageLabel" or childObject.Name == "Background" or childObject.Name == "Icon",
			"No image straight in the window but its art and its header icon: " .. childObject.Name)
	end
	-- The header icon, like the Shop's basket and Settings' cog on their top-left corners.
	assert(panel.Icon.Image == "rbxassetid://113221127098716" and panel.Icon.Position.X.Offset < 60 and panel.Icon.Position.Y.Offset < 40, "The crown sits on the top-left corner")
	-- The designer's window: the blocky art, the title on the top edge, the round close button.
	assert(panel.Background.Image == "rbxassetid://106477372921851", "The blocky background art")
	assert(panel.Title.Text == "Admin Abuse Panel", "The title on the top edge")
	assert(panel.Close.ClassName == "ImageButton" and panel.Close.Image == "rbxassetid://110882579806743", "The round close image button, like every other panel")
	assert(not buttonWith(panel, "X"), "No text X button")
	for _, descendant in gui:GetDescendants() do
		assert(descendant.Name ~= "AuthoredMenuBackground", "No copied Settings art")
	end
	assert(gui:FindFirstChild("Dim") == nil, "No dark screen behind the window")
	assert(panel.DragBar and panel.ResizeGrip and panel.Header and panel.Nav and panel.Content and panel.Targets and panel.Toast, "Drag bar, resize grip, header, categories, pages, targets and status bar")
	local navButtons = 0
	for _, childObject in panel.Nav:GetChildren() do
		if childObject.ClassName == "TextButton" then
			navButtons += 1
			assert(childObject.Size.Y.Offset >= 44, "Category buttons are big enough to read")
		end
	end
	assert(navButtons == 8 and 8 * 50 + 7 * 6 + 16 <= panel.Size.Y.Offset + panel.Nav.Size.Y.Offset, "All eight categories fit the left column")
	assert(panel.Content.Size.X.Scale == 1 and -panel.Content.Size.X.Offset == panel.Nav.Size.X.Offset + panel.Targets.Size.X.Offset + 4 * 12, "The pages take the width the columns leave, at any window size")
	assert(panel.Targets.Position.X.Scale == 1 and panel.Nav.Size.Y.Scale == 1 and panel.Content.Size.Y.Scale == 1, "The columns follow the window's size")
	for _, page in panel.Content:GetChildren() do
		assert(page.ClassName == "ScrollingFrame" and page.AutomaticCanvasSize == rb.Enum.AutomaticSize.Y, page.Name .. " scrolls when it runs long")
	end
	local scale = panel:FindFirstChildOfClass("UIScale")
	world.camera.ViewportSize = rb.Vector2.new(1366, 768)
	world.camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	assert(scale and scale.Scale == 1, "The panel has its automatic UIScale, full size on a 1366x768 laptop")
	world.camera.ViewportSize = rb.Vector2.new(844, 390)
	world.camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	assert(scale.Scale < 0.6 and scale.Scale > 0.45, "...and shrinks to fit a phone (" .. scale.Scale .. ")")
	world.camera.ViewportSize = rb.Vector2.new(3840, 2160)
	world.camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	assert(scale.Scale == 1, "...and never grows past its design size")

	-- The game's art style: light stud panels, the designer's stud buttons, the game's icons.
	local STUDS = "rbxassetid://135496826236732"
	local function isDesignerButton(object)
		return object.ClassName == "TextButton" and object:FindFirstChild("Studs") and object.Studs.Image == STUDS
			and object:FindFirstChild("Rim") and object.Rim:FindFirstChild("RimShade") and object:FindFirstChild("Edge") and object:FindFirstChild("Fill")
	end
	local buttons, designer = 0, 0
	for _, descendant in panel:GetDescendants() do
		if descendant.ClassName == "TextButton" and descendant.Name ~= "DragBar" and descendant.Name ~= "ResizeGrip" then
			buttons += 1
			if isDesignerButton(descendant) then
				designer += 1
			end
		end
	end
	assert(buttons > 40 and designer == buttons, "Every button is the designer's stud button (" .. designer .. "/" .. buttons .. ")")
	for _, column in { panel.NavBack, panel.Targets } do
		assert(column.BackgroundColor3 == rb.Color3.fromRGB(255, 255, 255) and column:FindFirstChild("Studs") and column.Studs.Image == "rbxassetid://117088684729837",
			column.Name .. " is a light stud panel, like the Shop's tab column")
	end
	local icons = {
		Abuse = "rbxassetid://72658080659794",
		Events = "rbxassetid://94279344773398",
		Boosts = "rbxassetid://123961542220277",
		Stats = "rbxassetid://76936003828964",
		Treadmills = "rbxassetid://140429435591753",
		Announce = "rbxassetid://102193985057745",
		Moderation = "rbxassetid://75521963910910",
	}
	for name, image in icons do
		local tab = assert(panel.Nav:FindFirstChild(name), "Category " .. name)
		assert(tab.TabIcon.ClassName == "ImageLabel" and tab.TabIcon.Image == image, name .. " wears the game's own icon")
	end
	assert(panel.Nav.Abuse:GetAttribute("Palette") == "Gold" and panel.Nav.Events:GetAttribute("Palette") == "Navy", "The open category is gold, the rest navy")
	assert(buttonWith(panel.Header, "This Server"):GetAttribute("Palette") == "Gold" and buttonWith(panel.Header, "All Servers"):GetAttribute("Palette") == "Navy", "The chosen scope is gold")
	for _, page in panel.Content:GetChildren() do
		for _, sectionFrame in page:GetChildren() do
			if sectionFrame.ClassName == "Frame" then
				assert(sectionFrame.BackgroundColor3 == rb.Color3.fromRGB(255, 255, 255) and sectionFrame:FindFirstChild("Studs") and sectionFrame:FindFirstChild("Body"),
					page.Name .. "." .. sectionFrame.Name .. " is a light stud panel with its rows inside")
				assert(sectionFrame.Body.Plate and sectionFrame.Body.Plate.SectionTitle, page.Name .. "." .. sectionFrame.Name .. " has its title on a navy plate")
			end
		end
	end

	local content = panel.Content
	local tabs = {}
	for _, key in { "Abuse", "Events", "Boosts", "Stats", "Treadmills", "Music", "Announce", "Moderation" } do
		tabs[key] = assert(content:FindFirstChild(key), "Tab page " .. key)
	end

	-- 😈 Abuse / Trolls
	local abuseDuration = assert(find(tabs.Abuse, "TextBox", "10"), "Abuse duration input")
	abuseDuration.Text = "25"
	for _, pair in { { "Rocket", "Rocket" }, { "Ragdoll", "Ragdoll" }, { "Jail", "Jail" }, { "Balloon", "Balloon" }, { "Tiny", "Tiny" }, { "Inverse", "Inverse" }, { "Control", "Control" }, { "Jumpscare", "Jumpscare" }, { "No Gravity", "NoGravity" }, { "Snail Mode", "Snail" }, { "Fake Reset", "FakeReset" } } do
		local effect, name = pair[1], pair[2]
		local card = assert(buttonWith(tabs.Abuse, effect), "Abuse card " .. effect)
		card.Activated:Fire()
		local sent = lastCall(panelRemote)
		assert(sent.action == "Abuse" and sent.effect == name and sent.duration == 25 and sent.target == "All" and sent.scope == "Server",
			"Abuse card " .. effect .. " sends its effect with the duration")
		assert(find(card, "TextLabel", "3.0s") or find(card, "TextLabel", "2.9s"), effect .. " shows its cooldown")
		local count = #panelRemote.calls
		card.Activated:Fire()
		assert(#panelRemote.calls == count, effect .. " waits out its cooldown")
	end

	-- 🎉 Events, with the This Server / All Servers switch
	for _, entry in { { "Disco Party", "Disco" }, { "Snow Storm", "Snow" }, { "Sandstorm", "Sandstorm" }, { "Confetti Party", "Confetti" }, { "Fireworks", "Fireworks" } } do
		local frame = assert(find(tabs.Events, "TextLabel", entry[1]), "Event " .. entry[1]).Parent
		find(frame, "TextBox", "60").Text = "90"
		find(frame, "TextButton", "ON").Activated:Fire()
		local on = lastCall(panelRemote)
		assert(on.action == "Event" and on.name == entry[2] and on.enabled == true and on.duration == 90, entry[1] .. " ON with its duration")
		find(frame, "TextButton", "OFF").Activated:Fire()
		assert(lastCall(panelRemote).enabled == false, entry[1] .. " OFF")
	end
	buttonWith(panel.Header, "All Servers").Activated:Fire()
	find(assert(find(tabs.Events, "TextLabel", "Disco Party")).Parent, "TextButton", "ON").Activated:Fire()
	assert(lastCall(panelRemote).scope == "All", "All Servers reaches every server")
	buttonWith(panel.Header, "This Server").Activated:Fire()

	-- ⚡ Boosts & Mults
	for _, entry in { { "2x Speed", "Speed", 2 }, { "4x Speed", "Speed", 4 }, { "2x Wins", "Wins", 2 }, { "5x Wins", "Wins", 5 } } do
		buttonWith(tabs.Boosts, entry[1]).Activated:Fire()
		local sent = lastCall(panelRemote)
		assert(sent.action == "Boost" and sent.stat == entry[2] and sent.multiplier == entry[3] and sent.minutes == 15, "Quick boost " .. entry[1])
	end
	find(tabs.Boosts, "TextBox", "Multiplier").Text = "7"
	find(tabs.Boosts, "TextBox", "Minutes").Text = "30"
	buttonWith(tabs.Boosts, "Boost Wins").Activated:Fire()
	local custom = lastCall(panelRemote)
	assert(custom.stat == "Wins" and custom.multiplier == 7 and custom.minutes == 30, "Custom multiplier and minutes")

	-- 🏃 Treadmills
	buttonWith(tabs.Treadmills, "Spawn Treadmill").Activated:Fire()
	local treadmill = lastCall(panelRemote)
	assert(treadmill.action == "Treadmill" and treadmill.multiplier == 5 and treadmill.minutes == 10, "Spawn an admin treadmill")
	buttonWith(tabs.Treadmills, "Remove All").Activated:Fire()
	assert(lastCall(panelRemote).action == "ClearTreadmills", "Remove All")

	-- 🎵 Music
	buttonWith(tabs.Music, "Song A").Activated:Fire()
	buttonWith(tabs.Music, "▶ Play").Activated:Fire()
	assert(lastCall(panelRemote).action == "PlayMusic" and lastCall(panelRemote).trackId == "rbxassetid://1", "Pick a song and play it")
	buttonWith(tabs.Music, "■ Stop").Activated:Fire()
	assert(lastCall(panelRemote).action == "StopMusic", "Stop")

	-- 📢 Announcements
	find(tabs.Announce, "TextBox", "Message for every player...").Text = "Hello everyone"
	find(tabs.Announce, "TextBox", "8").Text = "12"
	buttonWith(tabs.Announce, "🚨 Alert").Activated:Fire()
	assert(string.find(find(tabs.Announce, "TextLabel", "📢 Hello everyone").Text, "Hello everyone", 1, true), "The preview reads the message")
	buttonWith(panel.Header, "All Servers").Activated:Fire()
	buttonWith(tabs.Announce, "📢 Send Global Message").Activated:Fire()
	local announcement = lastCall(panelRemote)
	assert(announcement.action == "Announce" and announcement.message == "Hello everyone" and announcement.scope == "All", "Send Global Message, following the switch")
	assert(announcement.theme == "Alert" and announcement.duration == 12, "The banner's theme and seconds go with it")
	buttonWith(panel.Header, "This Server").Activated:Fire()

	-- 🛡️ Moderation: one player at a time
	local calls = #panelRemote.calls
	buttonWith(tabs.Moderation, "Kick").Activated:Fire()
	assert(#panelRemote.calls == calls and panel.Toast.Text == "⚠️ Pick one player in the list on the right", "Moderation asks for a player first")
	buttonWith(panel.Targets, "Other").Activated:Fire()
	assert(panel.Targets.ActingOn.Text == "Target: Other", "The target column says who the cards act on")
	find(tabs.Moderation, "TextBox", "Reason").Text = "spam"
	find(tabs.Moderation, "TextBox", "Ban hours (0 = forever)").Text = "12"
	find(tabs.Moderation, "TextBox", "Mute minutes").Text = "5"
	find(tabs.Moderation, "TextBox", "Speed amount").Text = "1000"
	for _, entry in { { "Kick", "Kick" }, { "Ban", "Ban" }, { "Mute", "Mute" }, { "Unmute", "Unmute" }, { "TP to Player", "GoTo" }, { "Bring", "Bring" } } do
		buttonWith(tabs.Moderation, entry[1]).Activated:Fire()
		local sent = lastCall(panelRemote)
		assert(sent.action == entry[2] and sent.target == 42, entry[1] .. " acts on the selected player")
	end
	local banned, muted
	for _, sent in panelRemote.calls do
		if sent.action == "Ban" then
			banned = sent
		elseif sent.action == "Mute" then
			muted = sent
		end
	end
	assert(banned.hours == 12 and banned.reason == "spam" and muted.minutes == 5, "Ban takes its hours and reason, Mute its minutes")
	for _, entry in { { "Give Speed", "GiveSpeed" }, { "Remove Speed", "RemoveSpeed" } } do
		buttonWith(tabs.Moderation, entry[1]).Activated:Fire()
		local sent = lastCall(panelRemote)
		assert(sent.action == entry[2] and sent.amount == 1000 and sent.target == 42, entry[1])
	end

	-- 💰 Stats & Passes, on the selected player, all on the working service.
	find(tabs.Stats, "TextBox", "Amount").Text = "5000"
	for _, stat in { "Speed", "Wins", "Rebirths" } do
		buttonWith(tabs.Stats, "+ " .. stat).Activated:Fire()
		local sent = lastCall(panelRemote)
		assert(sent.action == "GiveStat" and sent.stat == stat and sent.amount == 5000 and sent.target == 42, "Give " .. stat)
	end
	buttonWith(tabs.Stats, "Flight").Activated:Fire()
	buttonWith(tabs.Stats, "Give Pass").Activated:Fire()
	assert(lastCall(panelRemote).action == "Pass" and lastCall(panelRemote).pass == "Flight" and lastCall(panelRemote).enabled == true and lastCall(panelRemote).target == 42, "Give a gamepass")
	buttonWith(tabs.Stats, "Remove Pass").Activated:Fire()
	assert(lastCall(panelRemote).pass == "Flight" and lastCall(panelRemote).enabled == false, "Take it away")
	buttonWith(tabs.Stats, "♻️ Reset Stats").Activated:Fire()
	assert(lastCall(panelRemote).action == "ResetStats" and lastCall(panelRemote).target == 42, "Reset stats")
	buttonWith(tabs.Stats, "✨ Force Rebirth").Activated:Fire()
	assert(lastCall(panelRemote).action == "ForceRebirth" and lastCall(panelRemote).target == 42, "Force a rebirth")
	find(tabs.Stats, "TextBox", "Code name").Text = "WELCOME"
	buttonWith(tabs.Stats, "Redeem Code").Activated:Fire()
	assert(lastCall(panelRemote).action == "RedeemCode" and lastCall(panelRemote).code == "WELCOME", "Redeem a code")
	buttonWith(tabs.Stats, "World 3").Activated:Fire()
	assert(lastCall(panelRemote).action == "Travel" and lastCall(panelRemote).world == 3, "Travel to World 3")
	assert(not world.remotes.AdminPanelAction.calls[1], "Nothing goes to the switched-off service")

	-- A floating window: drag it by the top bar, resize it from the corner.
	local function pointer(target, event, x, y)
		target[event]:Fire({ UserInputType = if event == "InputChanged" then rb.Enum.UserInputType.MouseMovement else rb.Enum.UserInputType.MouseButton1, Position = rb.Vector3.new(x, y, 0) })
	end
	local startPosition = panel.Position
	pointer(panel.DragBar, "InputBegan", 100, 100)
	pointer(world.input, "InputChanged", 160, 130)
	pointer(world.input, "InputEnded", 160, 130)
	assert(panel.Position.X.Offset == startPosition.X.Offset + 60 and panel.Position.Y.Offset == startPosition.Y.Offset + 30, "Dragging the top bar moves the window")
	pointer(world.input, "InputChanged", 400, 400)
	assert(panel.Position.X.Offset == startPosition.X.Offset + 60, "Letting go stops the drag")
	local moved = panel.Position
	pointer(panel.ResizeGrip, "InputBegan", 0, 0)
	pointer(world.input, "InputChanged", -600, -600)
	assert(panel.Size.X.Offset == 820 and panel.Size.Y.Offset == 520, "It shrinks down to its smallest size and no further")
	assert(panel.Position.X.Offset == moved.X.Offset - 110 and panel.Position.Y.Offset == moved.Y.Offset - 70, "Resizing keeps the top-left corner in place")
	pointer(world.input, "InputChanged", 90000, 90000)
	pointer(world.input, "InputEnded", 0, 0)
	assert(panel.Size.X.Offset <= 3840 - 16 and panel.Size.Y.Offset <= 2160 - 16, "It grows no bigger than the screen")

	-- Closing, three ways, brings the Main HUD back.
	panel.Close.Activated:Fire()
	assert(gui.Enabled == false and world.hud[#world.hud] == true, "X closes it and the Main HUD comes back")
	world.key(rb.Enum.KeyCode.F2)
	world.key(rb.Enum.KeyCode.Escape)
	assert(gui.Enabled == false and world.hud[#world.hud] == true, "Escape closes it too")
	world.key(rb.Enum.KeyCode.F2)
	world.key(rb.Enum.KeyCode.F2)
	assert(gui.Enabled == false and world.hud[#world.hud] == true, "F2 toggles it closed")
	-- A category button shows its page.
	world.key(rb.Enum.KeyCode.F2)
	buttonWith(panel.Nav, "🎵  Music").Activated:Fire()
	assert(tabs.Music.Visible == true and tabs.Abuse.Visible == false, "A category button shows its page")

	-- An admin whose permission arrives after F2: the panel opens as soon as it does.
	local late = newWorld(false)
	assert(late.gui() == nil, "No panel before permission")
	late.key(rb.Enum.KeyCode.F2)
	assert(late.gui() == nil and lastCall(late.remotes.AdminAbusePanel).action == "Hello", "F2 asks again")
	late.remotes.AdminAbusePanel.OnClientEvent:Fire({ kind = "Permission", allowed = true, tracks = {} })
	assert(late.gui() and late.gui().Enabled == true, "The early F2 opens the panel when permission arrives")
	late.remotes.AdminAbusePanel.OnClientEvent:Fire({ kind = "Permission", allowed = false })
	assert(late.gui().Enabled == false, "Permission withdrawn closes it")

	-- The attribute arriving later works the same.
	local attribute = newWorld(false)
	attribute.player:SetAttribute("AdminAbusePanelAllowed", true)
	assert(attribute.gui(), "The attribute arriving later builds the panel")
	attribute.key(rb.Enum.KeyCode.F2)
	assert(attribute.gui().Enabled == true, "...and F2 opens it")

	-- The server tells admins on arrival; the topbar icon follows the attribute too.
	local service = read("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	has(service, 'player:SetAttribute("AdminAbusePanelAllowed", true)\n\t\t\tPanel:FireClient(player, { kind = "Permission", allowed = true, tracks = musicTracks() })',
		"The service sends the permission and the music list on arrival")
	has(service, "Players.PlayerAdded:Connect(welcome)", "...to every admin who joins")
	local topbar = read("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
	has(topbar, 'if LocalPlayer:GetAttribute("AdminAbusePanelAllowed") == true then\n\taddAdminIcon()', "The crown shows from the first frame")
	assert(not string.find(topbar, 'request = "SpinWheel"', 1, true) and not string.find(topbar, "SPIN_WHEEL_IMAGE", 1, true), "The Spin Wheel has no topbar button")
	assert(not string.find(topbar, 'request = "Quests"', 1, true), "Quests open from Dr. Eggman (Update 4), not the topbar")
	has(topbar, 'request = "Afk"', "The topbar keeps AFK Rewards")
	print("PASS the Main HUD comes back from every topbar menu; the admin panel opens at once with F2, scales to the screen, and all its categories send their actions")
end

