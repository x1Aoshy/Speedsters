-- StageBarrierShatter.client.luau
-- Breaking through at speed: crossing into a new stage, or running onto the finish, faster
-- than Config.StageBarrierShatterMinSpeed shatters the screen: the very same Glass Shatter
-- the sprint used to play (Shared.GlassShatter, with the same settings), plus the smash
-- sound. This is where it lives now; the sprint no longer shatters the screen every few
-- seconds.
--
--   * a new stage: the server sets LastReachedStage when the player enters a stage's
--     checkpoint; a step up from the stage before is a crossing (a respawn or a teleport
--     moves the player without the speed, so it breaks nothing);
--   * the finish: nearing the world's final Win pad (the pads' runtime folders mark it)
--     before the pad sends the player back to the lobby.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GlassShatter = require(Shared:WaitForChild("GlassShatter"))

local player = Players.LocalPlayer

local MIN_SPEED = math.max(10, tonumber(Config.StageBarrierShatterMinSpeed) or 45)
local COOLDOWN = 1.5
local FINISH_COOLDOWN = 8
local FINISH_REACH = 24 -- studs from the final pad, flat
-- Exactly what the sprint's sonic barrier played (InstantMovementController, before
-- 2026-09-18), now on a real impact.
local SHATTER = {
	Distance = 3.2,
	HoldTime = 0.02,
	Depth = 4,
	Intensity = 2.2,
	Thickness = 0.07,
	Transparency = 0.4,
	Color = Color3.fromRGB(250, 252, 255),
	CameraPunch = true,
	Shockwave = true,
}
-- Each world's pads and the attribute that marks its final pad.
local FINAL_PADS = {
	{ Folder = "NewWorld1ManualStagePads_Runtime", Attribute = "NewWorld1FinalWinStagePad" },
	{ Folder = "World2ManualStagePads_Runtime", Attribute = "World2FinalWinStagePad" },
	{ Folder = "World3ManualStagePads_Runtime", Attribute = "World3FinalWinStagePad" },
}

local lastBreakAt = -math.huge
local lastFinishAt = -math.huge

local function rootOf()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function flatVelocity(root)
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

-- The barrier breaks: the screen shatters as the player goes through it.
local function breakBarrier()
	local shatter = table.clone(SHATTER)
	shatter.PlaySound = player:GetAttribute("SoundEffects") ~= false
	task.defer(GlassShatter.Play, shatter)
	lastBreakAt = os.clock()
	return true
end

-- A new stage, crossed at speed.
local reachedStage = tonumber(player:GetAttribute("LastReachedStage"))
player:GetAttributeChangedSignal("LastReachedStage"):Connect(function()
	if Config and Config.StageBarrierShatterEnabled == false then
		return
	end
	local stage = tonumber(player:GetAttribute("LastReachedStage"))
	local previous = reachedStage
	reachedStage = stage
	if not stage or not previous or previous < 1 or stage <= previous then
		return
	end
	local root = rootOf()
	if root and flatVelocity(root).Magnitude >= MIN_SPEED and os.clock() - lastBreakAt >= COOLDOWN then
		breakBarrier()
	end
end)

-- The finish: the world's final Win pads, looked up again every few seconds (they stream).
local finalPads = {}
local lastScan = -math.huge
local function scanFinalPads()
	lastScan = os.clock()
	table.clear(finalPads)
	for _, world in FINAL_PADS do
		local folder = Workspace:FindFirstChild(world.Folder)
		if folder then
			for _, item in folder:GetDescendants() do
				if item:IsA("BasePart") and item:GetAttribute(world.Attribute) == true then
					table.insert(finalPads, item)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.1)
		if os.clock() - lastScan >= 3 then
			scanFinalPads()
		end
		local root = rootOf()
		if root and #finalPads > 0 and os.clock() - lastFinishAt >= FINISH_COOLDOWN then
			local velocity = flatVelocity(root)
			if velocity.Magnitude >= MIN_SPEED then
				for _, pad in finalPads do
					if pad.Parent then
						local offset = pad.Position - root.Position
						local flat = Vector3.new(offset.X, 0, offset.Z)
						-- Running at it, not away from it.
						if flat.Magnitude <= FINISH_REACH and math.abs(offset.Y) <= 15 and flat:Dot(velocity) > 0 then
							lastFinishAt = os.clock()
							breakBarrier()
							break
						end
					end
				end
			end
		end
	end
end)
