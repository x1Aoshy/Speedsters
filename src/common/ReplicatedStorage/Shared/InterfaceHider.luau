-- InterfaceHider.luau
-- The whole interface away while a cinematic has the camera, and back afterwards.
--
-- Hide(owner, keep) turns off every ScreenGui that is showing, and the core GUI, and remembers
-- exactly which. Show(owner) brings exactly those back once the LAST owner has let go. The two
-- cinematics can overlap (Admin/AdminTreadmillReveal and UI/WorldPortalCinematic): they share
-- this one ledger, so neither brings the interface back under the other and neither can leave
-- it off for good.
--
-- Never hidden: what an owner keeps (its own ScreenGui, or any ScreenGui of a name it gives:
-- the race keeps "TouchGui"), and by name (Hider.NeverHide) the two
-- cinematics' GUIs, the loading screen and the revive offer. A ScreenGui that was already off
-- is never turned on. Only ScreenGuis are touched: world-space GUIs belong to the world.
-- While it is hidden, a ScreenGui that other code turns on or adds (Settings turns the HUD on
-- again on every respawn, ControlModule the touch controls, a first level-up banner...) is
-- turned off again and joins the ledger, so it is showing when the flight ends. One destroyed
-- meanwhile is skipped. Forget(gui) drops one its own controller has closed meanwhile.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Hider = {}

Hider.NeverHide = {
	WorldPortalCinematicGui = true, -- UI/WorldPortalCinematic: the bars, the words, Skip
	AdminTreadmillReveal = true, -- Admin/AdminTreadmillReveal: the bars, the words, the card
	SpeedsterLoadingScreen = true, -- ReplicatedFirst/LoadingScreen: the world behind it is not there yet
	RevivePromptHUD = true, -- UI/RevivePrompt: off unless the runner has just died; its offer lasts 5 s
}
Hider.Core = {
	Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu,
}

-- Lune instances have no events: audit/test_fable_interface_hider replaces these two.
function Hider._onChildAdded(parent, callback)
	return parent.ChildAdded:Connect(callback)
end
function Hider._onEnabledChanged(gui, callback)
	return gui:GetPropertyChangedSignal("Enabled"):Connect(callback)
end

local owners = {} -- owner -> { [Instance] = true }: what that owner keeps on screen
-- While hidden: Guis = { [ScreenGui] = true } to turn on again, Core = { [CoreGuiType] = true },
-- Watching = { [ScreenGui] = connection }, Added = connection.
local ledger = nil

-- An owner keeps a ScreenGui itself or, by name (a string in `keep`), any ScreenGui called so:
-- the race keeps Roblox's "TouchGui" (the thumbstick and jump), which ControlModule may
-- rebuild at any time (Update 4, 2026-09-25).
local function kept(gui)
	if Hider.NeverHide[gui.Name] then
		return true
	end
	for _, keep in owners do
		if keep[gui] or keep[gui.Name] then
			return true
		end
	end
	return false
end

local function cover(gui)
	if ledger and gui.Enabled and not kept(gui) then
		ledger.Guis[gui] = true
		gui.Enabled = false
	end
end

local function watch(gui)
	if not ledger or not gui:IsA("ScreenGui") or ledger.Watching[gui] then
		return
	end
	ledger.Watching[gui] = Hider._onEnabledChanged(gui, function()
		cover(gui)
	end)
	cover(gui)
end

function Hider.Hide(owner, keep)
	local set = {}
	for _, gui in keep or {} do
		set[gui] = true
	end
	owners[owner] = set
	if ledger then
		-- Hidden already, by another owner: what this one keeps comes back if it was covered
		-- (by name too).
		for gui in table.clone(ledger.Guis) do
			if set[gui] or set[gui.Name] then
				ledger.Guis[gui] = nil
				if gui.Parent then
					gui.Enabled = true
				end
			end
		end
		return
	end
	ledger = { Guis = {}, Core = {}, Watching = {} }
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, gui in playerGui:GetChildren() do
			watch(gui)
		end
		ledger.Added = Hider._onChildAdded(playerGui, watch)
	end
	for _, kind in Hider.Core do
		local ok, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(kind)
		end)
		if ok and enabled then
			ledger.Core[kind] = true
			pcall(function()
				StarterGui:SetCoreGuiEnabled(kind, false)
			end)
		end
	end
end

function Hider.Show(owner)
	if owners[owner] == nil then
		return
	end
	owners[owner] = nil
	if next(owners) ~= nil or not ledger then
		return
	end
	local done = ledger
	ledger = nil -- first, so the watchers cannot cover what comes back
	if done.Added then
		done.Added:Disconnect()
	end
	for _, connection in done.Watching do
		connection:Disconnect()
	end
	for gui in done.Guis do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	for kind in done.Core do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(kind, true)
		end)
	end
end

-- Whether anyone other than `exceptOwner` has the interface hidden right now.
function Hider.IsHidden(exceptOwner)
	for owner in owners do
		if owner ~= exceptOwner then
			return true
		end
	end
	return false
end

-- `gui` has been closed by its own controller while it was covered: it must not come back.
function Hider.Forget(gui)
	if ledger then
		ledger.Guis[gui] = nil
	end
end

return Hider
