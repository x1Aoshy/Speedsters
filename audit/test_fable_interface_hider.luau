-- READ-ONLY probe: runs the proposed Shared/InterfaceHider (src/common/ReplicatedStorage/Shared/InterfaceHider.luau)
-- offline, the way an audit test would, and compiles the proposed edits of the two client scripts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local SOURCE = fs.readFile("src/common/ReplicatedStorage/Shared/InterfaceHider.luau")
assert(#luau.compile(SOURCE) > 0)

local function newWorld()
	local playerGui = rb.Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local core = {}
	for _, kind in { "PlayerList", "Health", "Backpack", "Chat", "EmotesMenu" } do
		core[kind] = true
	end
	local coreCalls = {}
	local services = {
		Players = { LocalPlayer = { FindFirstChildOfClass = function(_, class)
			assert(class == "PlayerGui")
			return playerGui
		end } },
		StarterGui = {
			GetCoreGuiEnabled = function(_, kind) return core[kind.Name] end,
			SetCoreGuiEnabled = function(_, kind, on)
				table.insert(coreCalls, tostring(kind) .. "=" .. tostring(on))
				core[kind.Name] = on
			end,
		},
	}
	local Hider = luau.load(SOURCE, { debugName = "InterfaceHider", environment = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		Enum = rb.Enum, pcall = pcall, next = next,
	} })()
	-- Lune has no events: the test keeps the callbacks and fires them by hand.
	local enabledWatchers, childAdded, live = {}, nil, 0
	Hider._onEnabledChanged = function(gui, callback)
		live += 1
		local connection = { Connected = true }
		function connection:Disconnect()
			if self.Connected then
				self.Connected = false
				live -= 1
				enabledWatchers[gui] = nil
			end
		end
		enabledWatchers[gui] = callback
		return connection
	end
	Hider._onChildAdded = function(_, callback)
		live += 1
		childAdded = callback
		return { Disconnect = function()
			live -= 1
			childAdded = nil
		end }
	end
	local world = { Hider = Hider, PlayerGui = playerGui, Core = core, CoreCalls = coreCalls }
	function world.gui(name, enabled)
		local gui = rb.Instance.new("ScreenGui")
		gui.Name = name
		gui.Enabled = enabled
		gui.Parent = playerGui
		if childAdded then
			childAdded(gui)
		end
		return gui
	end
	-- Other code sets Enabled: the property changes, then the (deferred) signal runs.
	function world.set(gui, enabled)
		if gui.Enabled ~= enabled then
			gui.Enabled = enabled
			if enabledWatchers[gui] then
				enabledWatchers[gui]()
			end
		end
	end
	function world.live() return live end
	return world
end

local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end

-- 1. Exactly what was showing goes and comes back; what was off stays off.
do
	local w = newWorld()
	local H = w.Hider
	local hud, messages, topbar = w.gui("Mainhud", true), w.gui("Messages", true), w.gui("TopbarPlus", true)
	local shop, toast = w.gui("Shop", false), w.gui("ToastMessages", false)
	local loading = w.gui("SpeedsterLoadingScreen", true)
	local reveal = w.gui("AdminTreadmillReveal", true)
	local billboard = rb.Instance.new("BillboardGui")
	billboard.Parent = w.PlayerGui
	w.Core.Backpack = false -- the game had it off
	H.Hide("AdminTreadmillReveal", { reveal })
	assert(not hud.Enabled and not messages.Enabled and not topbar.Enabled, "the HUD, the messages and the topbar icons must go")
	assert(loading.Enabled and reveal.Enabled and billboard.Enabled, "the loading screen, the cinematic's own GUI and world-space GUIs stay")
	assert(not w.Core.PlayerList and not w.Core.Chat)
	assert(H.IsHidden() and not H.IsHidden("AdminTreadmillReveal") and H.IsHidden("WorldPortalCinematic"))
	H.Show("AdminTreadmillReveal")
	assert(hud.Enabled and messages.Enabled and topbar.Enabled, "they come back")
	assert(not shop.Enabled and not toast.Enabled, "what was off must never be turned on")
	assert(w.Core.PlayerList and w.Core.Chat and w.Core.Backpack == false,
		"core GUI goes back to what it was, not simply on")
	for _, call in w.CoreCalls do
		assert(not call:find("Backpack"), "Backpack was off and must not be touched: " .. call)
	end
	assert(w.live() == 0 and not H.IsHidden(), "no watcher may outlive the hide")
	pass("hide / show: exactly what was showing, core GUI as it was, nothing of the cinematic or the loading screen")
end

-- 2. The two cinematics overlap, in both orders: only the last Show brings it back.
for _, order in { { "WorldPortalCinematic", "AdminTreadmillReveal" }, { "AdminTreadmillReveal", "WorldPortalCinematic" } } do
	local w = newWorld()
	local H = w.Hider
	local hud = w.gui("Mainhud", true)
	local first = w.gui(if order[1] == "WorldPortalCinematic" then "WorldPortalCinematicGui" else "AdminTreadmillReveal", true)
	H.Hide(order[1], { first })
	local second = w.gui(if order[2] == "WorldPortalCinematic" then "WorldPortalCinematicGui" else "AdminTreadmillReveal", true)
	assert(second.Enabled, "the other cinematic's GUI, added during the flight, must not be covered")
	H.Hide(order[2], { second })
	assert(first.Enabled and second.Enabled and not hud.Enabled)
	H.Show(order[1])
	assert(not hud.Enabled, "restored too early: " .. order[2] .. " still has the camera")
	assert(not w.Core.PlayerList)
	H.Show(order[1]) -- a second Show from the same owner is nothing
	assert(not hud.Enabled)
	H.Show(order[2])
	assert(hud.Enabled and w.Core.PlayerList and w.live() == 0)
	pass("overlap " .. order[1] .. " then " .. order[2] .. ": back only when both have let go")
end

-- 3. Other code during the flight: a respawn turns the HUD on again, a new banner, a destroyed GUI,
--    a menu closed by its controller, a GUI added disabled, Hide twice by one owner.
do
	local w = newWorld()
	local H = w.Hider
	local hud, touch, rebirth, doomed = w.gui("Mainhud", true), w.gui("TouchGui", true), w.gui("Rebirth", true), w.gui("LevelUpBanner", true)
	local toast = w.gui("ToastMessages", false)
	H.Hide("WorldPortalCinematic", {})
	H.Hide("WorldPortalCinematic", {}) -- the same owner again: still one hold
	w.set(hud, true) -- SettingsController.applyHudVisibility(false) on CharacterAdded
	w.set(toast, true) -- ...which also forces ToastMessages on
	w.set(touch, true) -- ControlModule on the new character
	assert(not hud.Enabled and not toast.Enabled and not touch.Enabled, "what other code turns on during the flight goes off again")
	local revive = w.gui("RevivePromptHUD", false)
	w.set(revive, true) -- the runner died during the flight: the 5 s revive offer
	assert(revive.Enabled, "the revive offer must stay reachable")
	local banner = w.gui("SomeNewBanner", true)
	local quiet = w.gui("SomeNewPanel", false)
	assert(not banner.Enabled and not quiet.Enabled)
	doomed:Destroy()
	H.Forget(rebirth) -- MenuEvents: closed by its controller (death -> CloseAll) while covered
	H.Show("WorldPortalCinematic")
	assert(hud.Enabled and touch.Enabled and toast.Enabled and banner.Enabled, "all of them are showing after the flight")
	assert(not quiet.Enabled, "added off, stays off")
	assert(not rebirth.Enabled, "a menu its controller closed meanwhile must not come back")
	assert(w.live() == 0 and not H.IsHidden())
	-- Nothing of the old hide is alive: turning a GUI on now is nobody's business.
	w.set(hud, false)
	w.set(hud, true)
	assert(hud.Enabled)
	H.Show("WorldPortalCinematic")
	H.Show("NeverHid")
	assert(hud.Enabled)
	pass("during the flight: re-enabled and new GUIs are covered and come back, destroyed ones skipped, forgotten ones stay closed")
end

-- 4. What a later owner keeps comes back at once if the first hide covered it.
do
	local w = newWorld()
	local H = w.Hider
	local card = w.gui("SomeCinematicGui", true)
	H.Hide("A", {})
	assert(not card.Enabled)
	H.Hide("B", { card })
	assert(card.Enabled, "B keeps it")
	H.Show("A")
	H.Show("B")
	assert(card.Enabled and w.live() == 0)
	pass("a later owner's own GUI is uncovered when it asks to keep it")
end

-- 5. Update 4 (2026-09-25): the race keeps its own ScreenGuis and Roblox's TouchGui BY NAME.
--    ControlModule rebuilds TouchGui (a new instance) on a respawn: that one stays uncovered too;
--    Show brings back exactly the rest; the portal cinematic can overlap the race either way.
do
	local w = newWorld()
	local H = w.Hider
	local hud, messages = w.gui("Mainhud", true), w.gui("Messages", true)
	local oldTouch = w.gui("TouchGui", true)
	local raceHud, raceResults = w.gui("RaceHud", true), w.gui("RaceResults", false)
	H.Hide("Race", { raceHud, raceResults, "TouchGui" })
	assert(not hud.Enabled and not messages.Enabled, "the normal HUD goes during a race")
	assert(raceHud.Enabled and oldTouch.Enabled, "the race HUD and the touch controls stay")
	oldTouch:Destroy()
	local newTouch = w.gui("TouchGui", true)
	assert(newTouch.Enabled, "a TouchGui added later (ControlModule after a respawn) is kept by name")
	w.set(newTouch, false)
	w.set(newTouch, true)
	assert(newTouch.Enabled, "and it may be turned off and on again freely")
	w.set(raceResults, true)
	assert(raceResults.Enabled, "the results window opens during the race")
	-- The portal cinematic starts during the race: one ledger, both owners' GUIs stay up.
	local portal = w.gui("WorldPortalCinematicGui", true)
	H.Hide("WorldPortalCinematic", { portal })
	assert(portal.Enabled and not hud.Enabled, "overlap: the cinematic's own GUI shows, the HUD stays off")
	assert(newTouch.Enabled, "the race still keeps TouchGui while the cinematic overlaps")
	H.Show("Race")
	assert(not hud.Enabled and not messages.Enabled, "the cinematic still holds the interface")
	H.Show("WorldPortalCinematic")
	assert(hud.Enabled and messages.Enabled and newTouch.Enabled, "everything is back after both let go")
	assert(w.live() == 0 and not H.IsHidden(), "no watcher outlives the race")

	-- The other order: a cinematic first, then the race keeps TouchGui by name: it comes back.
	local w2 = newWorld()
	local H2 = w2.Hider
	local hud2, touch2 = w2.gui("Mainhud", true), w2.gui("TouchGui", true)
	H2.Hide("WorldPortalCinematic", {})
	assert(not touch2.Enabled, "the cinematic covers the touch controls")
	H2.Hide("Race", { "TouchGui" })
	assert(touch2.Enabled and not hud2.Enabled, "the race's later Hide uncovers TouchGui by name")
	H2.Show("WorldPortalCinematic")
	H2.Show("Race")
	assert(hud2.Enabled and touch2.Enabled and w2.live() == 0, "both let go: all back")
	pass("race: TouchGui kept by name (also a rebuilt one), Show restores the rest, overlap with the portal both ways")
end

-- 6. The proposed edits of the two client scripts compile (copies in scratch/, if present).
for _, path in { "src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau", "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau" } do
	if fs.isFile(path) then
		local ok, problem = pcall(luau.compile, fs.readFile(path))
		assert(ok, path .. ": " .. tostring(problem))
		pass("compiles: " .. path)
	end
end
print(("ALL PASSED (%d groups)"):format(passed))
