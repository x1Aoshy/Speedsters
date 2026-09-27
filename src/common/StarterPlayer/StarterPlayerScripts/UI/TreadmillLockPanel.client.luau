local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local Config = require(Shared:WaitForChild("Config"))
local TreadmillLocked = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TreadmillLocked")

-- Keep legacy Treadmill ScreenGui disabled without modifying its authored hierarchy
local treadmillGui = playerGui:FindFirstChild("Treadmill")
if treadmillGui and treadmillGui:IsA("ScreenGui") then
	treadmillGui.Enabled = false
end

local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"
local failSound = SoundService:FindFirstChild("SpeedsterRequirementFailSound")
if not failSound or not failSound:IsA("Sound") then
	failSound = Instance.new("Sound")
	failSound.Name = "SpeedsterRequirementFailSound"
	failSound.SoundId = REQUIREMENT_FAIL_SOUND_ID
	failSound.Volume = 0.9
	failSound.Parent = SoundService
end

local function playRequirementFailSound()
	if failSound then
		failSound.TimePosition = 0
		SoundService:PlayLocalSound(failSound)
	end
end

local lastPromptTime = 0
local PROMPT_COOLDOWN = 1.5

local function promptGamePass(gamePassId)
	gamePassId = math.floor(tonumber(gamePassId) or 0)
	if gamePassId <= 0 then
		return
	end
	local now = os.clock()
	if now - lastPromptTime < PROMPT_COOLDOWN then
		return
	end
	lastPromptTime = now

	playRequirementFailSound()
	local success, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)

	if not success then
		warn("[TreadmillLockPanel] Could not open Pass purchase prompt: " .. tostring(err))
	end
end

local lastRebirthOpenTime = 0
local REBIRTH_OPEN_COOLDOWN = 1.2

local function openRebirthUi()
	local now = os.clock()
	if now - lastRebirthOpenTime < REBIRTH_OPEN_COOLDOWN then
		return
	end
	lastRebirthOpenTime = now

	playRequirementFailSound()
	MenuEvents.Request("Rebirth")
end

TreadmillLocked.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.LockType == "GamePass" then
		promptGamePass(payload.GamePassId)
		return
	end

	if payload.LockType == "Rebirth" then
		openRebirthUi()
		return
	end
end)

local openTreadmillEvent = MenuEvents.Get("OpenTreadmillPanel")
openTreadmillEvent.Event:Connect(function(action)
	if action == "Open" then
		openRebirthUi()
	end
end)

MenuEvents.MarkReady("Treadmill", function()
	return false
end)

print("[TreadmillLockPanel] V307 loaded. Ejected rebirth treadmills open native Rebirth UI directly; Pass treadmills open Roblox purchase prompt.")
