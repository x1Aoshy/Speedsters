--!strict
-- ReplicatedStorage/Shared/LobbyNpcConfig.luau — Update 4 (2026-09-25): the two lobby NPCs of
-- every world. Dr. Eggman (Talk -> the daily quests) and The Flash (Sign up -> the race
-- categories). Gameplay/LobbyNpcs prepares them on the server, Gameplay/LobbyNpcsClient animates
-- them and runs their dialogs; audit/test_u4_npcs checks every spot against the three .rbxl
-- files (on the floor, clear of the lobby's features, not in the portal flight's shot).
-- 2026-09-25 (owner): Eggman is the owner's own model, placed in Workspace in Studio (found by
-- name or tag, OwnerModels below; design/npc/EGGMAN_EN_WORKSPACE.md); the parts-built Eggman
-- only with SpawnPartsEggman. Flash is the owner's model when there is one, else an R6 avatar in
-- the game's FlashSuit spawned by the Race Gate. Both run the procedural R6 idle (R15 mapped).
-- Pure data + maths: no services at require time, Lune-safe (Vector3/CFrame from @lune/roblox
-- there, the Roblox globals in the game).
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end
local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local LobbyNpcConfig = {}

-- Workspace attribute U4Off_Npcs = true takes both NPCs out of the lobby, live (the U4 kill
-- switch naming; Update4Config has no "Npcs" flag, so the attribute is read directly).
LobbyNpcConfig.KillAttribute = U4.KillAttributePrefix .. "Npcs"
LobbyNpcConfig.FolderName = "LobbyNpcs"
LobbyNpcConfig.ModelNames = { Eggman = "DrEggman", Flash = "TheFlash" }
-- Every NPC model the server has prepared carries attribute LobbyNpc = its kind ("Eggman" /
-- "Flash") and its kind's tag (Tags): the clients find them by tag as they stream in and out.
LobbyNpcConfig.KindAttribute = "LobbyNpc"
LobbyNpcConfig.Tags = { Eggman = "LobbyNpcEggman", Flash = "LobbyNpcFlash" }

-- The owner's own models, anywhere under Workspace: a Model with one of these names (compared
-- lower-case, letters and digits only: "Dr. Eggman" = "dreggman") and a Humanoid or
-- AnimationController, or any Model the owner tagged with Tags[kind]. Never a player's
-- character, never inside our own LobbyNpcs folder. An owner's Flash replaces the spawned one.
LobbyNpcConfig.OwnerNames = {
	Eggman = { "eggman", "dreggman", "doctoreggman", "robotnik", "drrobotnik", "doctorrobotnik" },
	Flash = { "flash", "theflash" },
}
-- Off: Eggman is the owner's model. On: the parts-built Eggman (Shared/LobbyNpcRig) stands on
-- the spot below when the owner has placed none.
LobbyNpcConfig.SpawnPartsEggman = false

-- "Dr. Eggman" -> "dreggman".
function LobbyNpcConfig.NormalizeName(name: any): string
	return (string.gsub(string.lower(tostring(name or "")), "[^%w]", ""))
end

-- "Eggman" / "Flash" for a name the owner may give his models, else nil.
function LobbyNpcConfig.KindForName(name: any): string?
	local key = LobbyNpcConfig.NormalizeName(name)
	for kind, names in LobbyNpcConfig.OwnerNames do
		if table.find(names, key) then
			return kind
		end
	end
	return nil
end

-- The pose joints (Shared/LobbyNpcPose, R6 names) and the Motor6D that plays each on an R6 or an
-- R15 rig, in order of preference. R15's Root turns the whole body as R6's RootJoint does (Waist,
-- the upper body only, when a rig has no Root); its shoulders and hips turn the whole arm / leg.
LobbyNpcConfig.JointMap = {
	RootJoint = { "RootJoint", "Root", "Waist" },
	Neck = { "Neck" },
	["Left Shoulder"] = { "Left Shoulder", "LeftShoulder" },
	["Right Shoulder"] = { "Right Shoulder", "RightShoulder" },
	["Left Hip"] = { "Left Hip", "LeftHip" },
	["Right Hip"] = { "Right Hip", "RightHip" },
}
-- Without these four the idle is skipped (one warning); the prompt and dialog still work.
LobbyNpcConfig.RequiredJoints = { "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }

-- The floor points the NPCs stand on (the top of what shows there) and the points they turn to.
-- 2026-09-25, chosen from the maps (audit/test_u4_npcs):
--   Eggman  in the open floor between the treadmill row and the dance floor, on the portal's
--           side of the spawn, facing the spawn: in view a quarter turn from where players
--           spawn, on the way to the treadmills; World 2's lobby is smaller, so he stands in
--           the free corner west of its treadmill row, in the spawn's view.
--   Flash   beside the Race Gate (U4.Race.Gate), FlashBesideGate below, looking where the gate
--           looks (into the lobby). The race booth's RaceGate.FlashSpot overrides it at runtime.
LobbyNpcConfig.Spawns = {
	World1 = Vector3.new(280.28, 37467.69, -1781.14),
	World2 = Vector3.new(-783.83, 36626.65, -993.76),
	World3 = Vector3.new(265.30, 95.61, 521.64),
}
-- World 1 and World 3 stand him on the treadmill area's raised mat (its top, 0.35 / 0.23 over
-- the lobby floor), inside its curb, 12+ studs from the dance floor, about 50 degrees off the
-- spawn's view (in frame on a phone's wide screen). With SpawnPartsEggman off these are the spots
-- design/npc/EGGMAN_EN_WORKSPACE.md suggests to the owner (tested clear and in sight).
LobbyNpcConfig.Eggman = {
	World1 = { Position = Vector3.new(219, 37468.04, -1820), Facing = Vector3.new(280.28, 37468.04, -1781.14) },
	World2 = { Position = Vector3.new(-844, 36626.65, -1060), Facing = Vector3.new(-783.83, 36626.65, -993.76) },
	World3 = { Position = Vector3.new(339, 95.835, 564), Facing = Vector3.new(265.30, 95.835, 521.64) },
}
-- In the gate's own frame: Side (+1 = the gate's right, -1 its left) x Along studs across, and
-- Forward studs toward where the gate looks. The side with the open floor in each lobby (World 3's
-- right is the leaderboard wall; World 2's right runs into the boards by the portal).
LobbyNpcConfig.FlashBesideGate = {
	World1 = { Side = 1, Along = 18, Forward = 3 },
	World2 = { Side = -1, Along = 18, Forward = 3 },
	World3 = { Side = -1, Along = 18, Forward = 3 },
}

-- The race booth (RaceArenaBuilder's RaceLobbyBooth build, still named RaceGate) carries
-- FlashSpot: an invisible 2 x 0.2 x 2 marker on its kiosk whose bottom is the floor under Flash's
-- feet, LookVector toward the players. When Workspace holds one of these models with a
-- FlashSpot (BasePart or Attachment) inside, Flash stands there, without his base disc.
LobbyNpcConfig.BoothNames = { "RaceLobbyBooth", "RaceGate" }
LobbyNpcConfig.FlashSpotName = "FlashSpot"

LobbyNpcConfig.Prompt = {
	Eggman = { MaxDistance = 10, Offset = Vector3.new(0, 0.6, 0) },
	-- 12: behind a booth counter Flash stands a few studs further from the players.
	Flash = { MaxDistance = 12, Offset = Vector3.new(0, 0.4, 0) },
}

-- Client budget. Poses run within AnimateRadius of the camera: every frame within FullRate,
-- ReducedHz beyond; Low tier (phones under 30 FPS) halves both radii. Flash's sparks run within
-- SparkRadius on High (3 emitters) and Mid (1), never on Low.
LobbyNpcConfig.Client = {
	AnimateRadius = 110,
	FullRateRadius = 45,
	ReducedHz = 15,
	SparkRadius = 70,
	TagDistance = 60, -- name tags drawn within this many studs
	AlertDistance = 160, -- Eggman's "!" (seen from the spawn)
	DialogCloseDistance = 22, -- walking this far from Flash closes his window
	TierSeconds = 5, -- how often the FPS tier is looked at again
	TalkSeconds = 1.9, -- Eggman's line types out and stays this long before the quests open
}

----------------------------------------------------------------------
-- Race categories (the race server owns the rules; this only names them)
----------------------------------------------------------------------
LobbyNpcConfig.Categories = { "Beginner", "Rank", "Open" }
local CATEGORY = { Beginner = true, Rank = true, Open = true }
LobbyNpcConfig.JoinSource = "Npc"
-- Player attribute published by the race server: "Beginner" | "Mid" | "Pro".
LobbyNpcConfig.BracketAttribute = "RaceBracket"
local ABOVE_BEGINNER = { Mid = true, Pro = true }

-- The RaceRequest payload Flash's buttons send: { action = "Join", source = "Npc", category = ... }.
-- Nil for anything that is not one of the three categories.
function LobbyNpcConfig.JoinPayload(category: any): { action: string, source: string, category: string }?
	if type(category) ~= "string" or not CATEGORY[category] then
		return nil
	end
	return { action = "Join", source = LobbyNpcConfig.JoinSource, category = category }
end

-- Beginners is greyed out for players the race server puts above it; with no bracket published
-- (an older race server) every category stays open.
function LobbyNpcConfig.CategoryAllowed(category: string, bracket: any): boolean
	if category == "Beginner" then
		return not (type(bracket) == "string" and ABOVE_BEGINNER[bracket] == true)
	end
	return CATEGORY[category] == true
end

----------------------------------------------------------------------
-- Spots
----------------------------------------------------------------------
local function flatUnit(v: any): any?
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 1e-4 then
		return nil
	end
	return flat.Unit
end

-- Flash beside the gate of `world`, from U4.Race.Gate (so he follows the gate if it moves).
function LobbyNpcConfig.FlashBeside(world: string): { Position: any, Facing: any }?
	local gate = U4.Race.Gate[world]
	local offset = LobbyNpcConfig.FlashBesideGate[world]
	if type(gate) ~= "table" or type(offset) ~= "table" then
		return nil
	end
	local look = flatUnit(gate.Face - gate.Position) or Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X) -- CFrame.RightVector of a frame looking along `look`
	local position = gate.Position + right * (offset.Side * offset.Along) + look * offset.Forward
	return { Position = position, Facing = position + look * 10 }
end

-- The spot a booth's FlashSpot marker gives (the race builder's contract): the marker's bottom
-- (`height` = its Size.Y; 0 for an Attachment) is the floor under Flash's feet, and he looks
-- along its flattened LookVector (toward the players).
function LobbyNpcConfig.MarkerSpot(cframe: any, height: number?): { Position: any, Facing: any }
	local position = cframe.Position - Vector3.new(0, (height or 0) / 2, 0)
	local look = flatUnit(cframe.LookVector) or Vector3.new(0, 0, -1)
	return { Position = position, Facing = position + look * 10 }
end

-- { Position, Facing } of `kind` ("Eggman" / "Flash") in `world`, or nil.
function LobbyNpcConfig.Spot(world: string, kind: string): { Position: any, Facing: any }?
	if kind == "Eggman" then
		return LobbyNpcConfig.Eggman[world]
	elseif kind == "Flash" then
		return LobbyNpcConfig.FlashBeside(world)
	end
	return nil
end

-- The yaw (radians) of a frame at `position` looking toward `facing` (flat): LookVector =
-- (-sin yaw, 0, -cos yaw). No CFrame.lookAt: it is wrong in Lune.
function LobbyNpcConfig.Yaw(position: any, facing: any): number
	local dx, dz = facing.X - position.X, facing.Z - position.Z
	if dx * dx + dz * dz < 1e-6 then
		return 0
	end
	return math.atan2(-dx, -dz)
end

-- The floor frame of a spot: at the floor point, turned to its Facing.
function LobbyNpcConfig.SpotCFrame(spot: { Position: any, Facing: any }, cframe: any?): any
	local C = cframe or CFrame
	local position = spot.Position
	return C.new(position.X, position.Y, position.Z) * C.Angles(0, LobbyNpcConfig.Yaw(position, spot.Facing), 0)
end

-- The world key of a place from Shared/Config's flags.
function LobbyNpcConfig.WorldKey(config: any): string
	if type(config) == "table" then
		if config.IsWorld2Place == true then
			return "World2"
		elseif config.IsWorld3Place == true then
			return "World3"
		end
	end
	return "World1"
end

return LobbyNpcConfig
