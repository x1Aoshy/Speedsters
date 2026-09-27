-- ReplicatedStorage/Shared/LeaderboardChampionRig.luau
-- 2026-09-26 (owner): "the leaderboards don't look good - make the characters' accessories show
-- properly and make them dance". The #1 player standing on each lobby leaderboard's pedestal
-- (UI/GlobalLeaderboardDisplay builds them on the client; this module is its rig, placement and
-- dance). With the constructors of `env` ({ Instance, Vector3, CFrame, Color3, Enum }: the Roblox
-- globals in the game, @lune/roblox in audit/test_leaderboard_champions).
--
-- What was wrong before: the champion's every part (accessory handles too) was anchored right
-- after the model from Players:CreateHumanoidModelFromDescriptionAsync entered the world. A rig
-- out of the world has not laid its limbs and accessories out yet, so each Handle was frozen
-- where the asset left it; scaling (x3.6) and moving the model carried that offset along, and
-- hair or hats ended up lying at the foot of the pedestal. A fully anchored rig cannot animate.
--
-- Now, out of the world (Parent nil: CFrame writes there are plain writes, no assembly moves):
--   Prepare(env, model)       scripts / tools / lights / sounds out; every part unanchored and
--                             untouchable; the BodyColors applied; the Humanoid quiet (no name,
--                             no health, no state machine) with an Animator; every accessory
--                             welded again from its attachments (AccessoryWeld: Handle -> the
--                             body attachment of the same name, or a legacy hat's
--                             AttachmentPoint on the head), and one that fits nowhere on an R6
--                             (layered clothing, an R15-only attachment) dropped, never left lying.
--   Place(env, model, target) the rig laid out from its root through its joints (the rest pose,
--                             as the engine will once it is in the world), scaled to the stand's
--                             height (Model:ScaleTo), faced to the board's front, feet on the
--                             stand's top; the height and the feet checked; ONLY the
--                             HumanoidRootPart anchored, so the Motor6Ds animate and the welded
--                             accessories follow the body.
--   Settle(env, model, target) after a frame in the world: the feet measured again from the
--                             engine's own layout and the root nudged if they are off.
--   LoadDance / PlayDance / StopDance   the looping dance on the Humanoid's Animator.
--   BuildNeutralR6(env, name, accent)   the default champion while there is no #1 or the avatar
--                             cannot load: a real jointed R6 (classic head, face, the board's
--                             colour on the torso) that dances too, not a blank white body.
-- Nothing here yields, connects or tweens.
local Rig = {}

Rig.Version = "20260926_RootAnchoredDancingR6"

-- Roblox's own public R6 dances: the "/e dance", "/e dance2" and "/e dance3" emotes of the
-- classic R6 Animate script (its dance1 / dance2 / dance3 lists: 182435998, 182491037,
-- 182491065 / 182436842, 182491248, 182491277 / 182436935, 182491368, 182491423; the same
-- R6 set AdminAbuseEffects' disco uses). One per board, so no two champions dance alike.
Rig.Dances = {
	Robux = "rbxassetid://182435998", -- R6 dance (dance1)
	Speed = "rbxassetid://182436842", -- R6 dance2
	Wins = "rbxassetid://182436935", -- R6 dance3
	Race = "rbxassetid://182491037", -- R6 dance, its second variant
}
Rig.DefaultDance = "rbxassetid://182435998"

-- The dance plays only while the camera is this close (phones: nobody animates statues they
-- cannot see); past DanceFar it stops (the gap keeps it from flickering on the edge).
Rig.DanceNear = 120
Rig.DanceFar = 150

-- The body is this tall on the stand: the board frame's height x 1.12, within [10, 18] studs.
Rig.HeightFactor = 1.12
Rig.MinHeight = 10
Rig.MaxHeight = 18
-- A placed body outside [0.82, 1.18] x that height, or feet more than FeetEpsilon off the
-- stand's top, is refused (the server's old validation, kept on the client). 0.02 studs: CFrames
-- are float32, and at the sky lobbies (y ~37,500) a position only holds to ~0.004 studs.
Rig.MinHeightRatio = 0.82
Rig.MaxHeightRatio = 1.18
Rig.FeetEpsilon = 0.02

Rig.BodyPartNames = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
Rig.FootNames = { "Left Leg", "Right Leg" }

local BODY_COLOR_FIELDS = {
	Head = "HeadColor3",
	Torso = "TorsoColor3",
	["Left Arm"] = "LeftArmColor3",
	["Right Arm"] = "RightArmColor3",
	["Left Leg"] = "LeftLegColor3",
	["Right Leg"] = "RightLegColor3",
}

-- What a statue must not carry: code, tools, lights, sounds, prompts.
local REMOVED_CLASSES = { "LuaSourceContainer", "Tool", "Highlight", "Light", "ForceField", "Sound", "ProximityPrompt", "ClickDetector" }

local function set(instance: any, property: string, value: any)
	pcall(function()
		instance[property] = value
	end)
end

local function read(instance: any, property: string, default: any): any
	local ok, value = pcall(function()
		return instance[property]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

-- The lowest and highest world Y of a part's box.
function Rig.VerticalBounds(part: any): (number, number)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local extentY = math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
	local y = cframe.Position.Y
	return y - extentY, y + extentY
end

-- The dance of a board (Rig.Dances), the classic dance for any other.
function Rig.DanceFor(categoryId: string?): string
	return (categoryId and Rig.Dances[categoryId]) or Rig.DefaultDance
end

-- Where a board's champion stands, read once while its parts are streamed in: the stand top's
-- surface, the board's horizontal front and the body height.
function Rig.StandTarget(env: any, standTop: any, frame: any, screen: any): any?
	if not standTop or not frame or not screen then
		return nil
	end
	local _, surfaceY = Rig.VerticalBounds(standTop)
	local look = screen.CFrame.LookVector
	local front = env.Vector3.new(look.X, 0, look.Z)
	if front.Magnitude <= 1e-4 then
		front = env.Vector3.new(0, 0, -1)
	else
		front = front.Unit
	end
	local position = standTop.CFrame.Position
	return {
		SupportName = standTop.Name,
		SurfaceY = surfaceY,
		Position = env.Vector3.new(position.X, surfaceY, position.Z),
		Front = front,
		Height = math.clamp(frame.Size.Y * Rig.HeightFactor, Rig.MinHeight, Rig.MaxHeight),
	}
end

-- The root's frame at `position`, looking along the horizontal `front` (CFrame.fromMatrix: Lune's
-- CFrame.lookAt is wrong).
function Rig.Facing(env: any, position: any, front: any): any
	local up = env.Vector3.new(0, 1, 0)
	return env.CFrame.fromMatrix(position, front:Cross(up), up)
end

local function accessoryOf(part: any, model: any): any?
	local current = part.Parent
	while current and current ~= model do
		if current:IsA("Accoutrement") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isInside(instance: any, ancestor: any): boolean
	local current = instance
	while current do
		if current == ancestor then
			return true
		end
		current = current.Parent
	end
	return false
end

----------------------------------------------------------------------
-- Prepare
----------------------------------------------------------------------

-- Every accessory on the body by its attachments; returns (attached, dropped).
function Rig.AttachAccessories(env: any, model: any): (number, number)
	local head = model:FindFirstChild("Head")
	local bodyAttachments = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			for _, attachment in child:GetChildren() do
				if attachment:IsA("Attachment") and bodyAttachments[attachment.Name] == nil then
					bodyAttachments[attachment.Name] = attachment
				end
			end
		end
	end

	local joints = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			table.insert(joints, descendant)
		end
	end

	local attached, dropped = 0, 0
	for _, accessory in model:GetChildren() do
		if not accessory:IsA("Accoutrement") then
			continue
		end
		local handle = accessory:FindFirstChild("Handle")
		local weld = nil
		if handle and handle:IsA("BasePart") and not handle:FindFirstChildWhichIsA("WrapLayer") then
			-- The joint that held it before (the AccessoryWeld, a WeldConstraint) goes: the weld is
			-- made again from the attachments. Joints inside the accessory stay.
			for _, joint in joints do
				local part0, part1 = read(joint, "Part0", nil), read(joint, "Part1", nil)
				local other = if part0 == handle then part1 elseif part1 == handle then part0 else nil
				if (part0 == handle or part1 == handle) and not (other and isInside(other, accessory)) then
					joint:Destroy()
				end
			end
			local own, body = nil, nil
			local anyAttachment = false
			for _, attachment in handle:GetChildren() do
				if attachment:IsA("Attachment") then
					anyAttachment = true
					if bodyAttachments[attachment.Name] then
						own, body = attachment, bodyAttachments[attachment.Name]
						break
					end
				end
			end
			if own and body then
				weld = env.Instance.new("Weld")
				weld.Part0 = handle
				weld.Part1 = body.Parent
				weld.C0 = own.CFrame
				weld.C1 = body.CFrame
			elseif not anyAttachment and head and head:IsA("BasePart") then
				-- A legacy hat: its AttachmentPoint on top of the head.
				weld = env.Instance.new("Weld")
				weld.Part0 = handle
				weld.Part1 = head
				weld.C0 = read(accessory, "AttachmentPoint", env.CFrame.new())
				weld.C1 = env.CFrame.new(0, head.Size.Y / 2, 0)
			end
		end
		if weld then
			weld.Name = "AccessoryWeld"
			weld.Parent = handle
			handle.CFrame = weld.Part1.CFrame * weld.C1 * weld.C0:Inverse()
			attached += 1
		else
			accessory:Destroy()
			dropped += 1
		end
	end
	return attached, dropped
end

-- The model's BodyColors on its six parts (the engine applies them in the world too; here the
-- colours are right from the first frame).
function Rig.ApplyBodyColors(model: any): boolean
	local colors = model:FindFirstChildOfClass("BodyColors")
	if not colors then
		return false
	end
	for name, field in BODY_COLOR_FIELDS do
		local part = model:FindFirstChild(name)
		local color = read(colors, field, nil)
		if part and part:IsA("BasePart") and color then
			part.Color = color
		end
	end
	return true
end

-- A statue's Humanoid: no name or health over it, no state machine, no death, an Animator.
function Rig.QuietHumanoid(env: any, model: any): any?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	set(humanoid, "DisplayDistanceType", env.Enum.HumanoidDisplayDistanceType.None)
	set(humanoid, "HealthDisplayType", env.Enum.HumanoidHealthDisplayType.AlwaysOff)
	set(humanoid, "NameDisplayDistance", 0)
	set(humanoid, "AutoRotate", false)
	set(humanoid, "Sit", false)
	set(humanoid, "PlatformStand", false)
	set(humanoid, "EvaluateStateMachine", false)
	set(humanoid, "BreakJointsOnDeath", false)
	set(humanoid, "RequiresNeck", false)
	set(humanoid, "WalkSpeed", 0)
	set(humanoid, "JumpPower", 0)
	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = env.Instance.new("Animator")
		animator.Parent = humanoid
	end
	return humanoid
end

-- Scripts and the like out, parts unanchored and untouchable, colours, the Humanoid, the
-- accessories. Returns a summary for the model's attributes.
function Rig.Prepare(env: any, model: any): { Removed: number, Attached: number, Dropped: number }
	local removed = 0
	for _, descendant in model:GetDescendants() do
		for _, className in REMOVED_CLASSES do
			if descendant:IsA(className) then
				descendant:Destroy()
				removed += 1
				break
			end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			set(descendant, "CanTouch", false)
			set(descendant, "CanQuery", false)
			set(descendant, "Massless", true)
		end
	end
	Rig.ApplyBodyColors(model)
	Rig.QuietHumanoid(env, model)
	local attached, dropped = Rig.AttachAccessories(env, model)
	model:SetAttribute("ChampionAccessoriesAttached", attached)
	model:SetAttribute("ChampionAccessoriesDropped", dropped)
	return { Removed = removed, Attached = attached, Dropped = dropped }
end

----------------------------------------------------------------------
-- Layout and placement
----------------------------------------------------------------------

-- The rest pose: every part reached from `root` through Motor6Ds / Welds (Part1 = Part0 * C0 *
-- C1:Inverse(), what the engine does with no animation) and WeldConstraints (their current
-- offset). Only out of the world: in it, writing one part's CFrame moves its whole assembly.
-- Returns the set of parts reached.
function Rig.SolveRestPose(model: any, root: any): { [any]: boolean }
	local links = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") then
			local part0, part1 = read(descendant, "Part0", nil), read(descendant, "Part1", nil)
			if part0 and part1 and read(descendant, "Enabled", true) ~= false then
				table.insert(links, { Part0 = part0, Part1 = part1, C0 = descendant.C0, C1 = descendant.C1 })
			end
		elseif descendant:IsA("WeldConstraint") then
			local part0, part1 = read(descendant, "Part0", nil), read(descendant, "Part1", nil)
			if part0 and part1 and read(descendant, "Enabled", true) ~= false then
				table.insert(links, { Part0 = part0, Part1 = part1, Rigid = part0.CFrame:ToObjectSpace(part1.CFrame) })
			end
		end
	end
	local solved = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, link in links do
			local has0, has1 = solved[link.Part0] == true, solved[link.Part1] == true
			if has0 and not has1 then
				link.Part1.CFrame = if link.Rigid then link.Part0.CFrame * link.Rigid else link.Part0.CFrame * link.C0 * link.C1:Inverse()
				solved[link.Part1] = true
				progress = true
			elseif has1 and not has0 then
				link.Part0.CFrame = if link.Rigid then link.Part1.CFrame * link.Rigid:Inverse() else link.Part1.CFrame * link.C1 * link.C0:Inverse()
				solved[link.Part0] = true
				progress = true
			end
		end
	end
	return solved
end

-- Head top to feet bottom of the six R6 parts (0 when there are none).
function Rig.BodyHeight(model: any): number
	local low, high, found = math.huge, -math.huge, false
	for _, name in Rig.BodyPartNames do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local partLow, partHigh = Rig.VerticalBounds(part)
			low = math.min(low, partLow)
			high = math.max(high, partHigh)
			found = true
		end
	end
	return if found and high > low then high - low else 0
end

-- The bottom of the legs.
function Rig.FeetBottomY(model: any): number?
	local low, found = math.huge, false
	for _, name in Rig.FootNames do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			low = math.min(low, (Rig.VerticalBounds(part)))
			found = true
		end
	end
	return if found then low else nil
end

-- Lays the rig out with its root at `rootCFrame`; false when an R6 body part is not jointed to
-- the root (not a rig this can stand).
local function layOut(model: any, root: any, rootCFrame: any): { [any]: boolean }?
	root.CFrame = rootCFrame
	local solved = Rig.SolveRestPose(model, root)
	for _, name in Rig.BodyPartNames do
		local part = model:FindFirstChild(name)
		if not part or not part:IsA("BasePart") or not solved[part] then
			return nil
		end
	end
	return solved
end

-- Stands a prepared R6 on `target` (Rig.StandTarget). Out of the world only (Parent nil). Returns
-- (true) or (false, reason); the model's attributes record the checks either way.
function Rig.Place(env: any, model: any, target: any): (boolean, string?)
	if model.Parent ~= nil then
		model.Parent = nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "NoHumanoidRootPart"
	end
	model.PrimaryPart = root
	root.Anchored = false

	local facing = Rig.Facing(env, target.Position, target.Front)
	local solved = layOut(model, root, facing)
	if not solved then
		return false, "NotAJointedR6"
	end
	-- Anything the joints do not hold would float or lie on the floor: it goes.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not solved[descendant] and descendant.Parent then
			local accessory = accessoryOf(descendant, model)
			if accessory then
				accessory:Destroy()
				model:SetAttribute("ChampionAccessoriesDropped", (model:GetAttribute("ChampionAccessoriesDropped") or 0) + 1)
			else
				descendant:Destroy()
			end
		end
	end

	local height = Rig.BodyHeight(model)
	if height <= 0.01 then
		return false, "NoBodyHeight"
	end
	local scale = 1
	local readOk, current = pcall(function()
		return model:GetScale()
	end)
	if readOk and type(current) == "number" and current > 0 then
		scale = current
	end
	local scaleOk, scaleError = pcall(function()
		model:ScaleTo(scale * target.Height / height)
	end)
	if not scaleOk then
		return false, "ScaleTo: " .. tostring(scaleError)
	end

	-- ScaleTo scales about the pivot; lay the rig out again at the stand, then lift or lower it
	-- so the feet are on the stand's top.
	if not layOut(model, root, facing) then
		return false, "NotAJointedR6"
	end
	local feet = Rig.FeetBottomY(model)
	if not feet then
		return false, "NoLegs"
	end
	if not layOut(model, root, facing + env.Vector3.new(0, target.SurfaceY - feet, 0)) then
		return false, "NotAJointedR6"
	end

	local measured = Rig.BodyHeight(model)
	local feetError = (Rig.FeetBottomY(model) or math.huge) - target.SurfaceY
	model:SetAttribute("ChampionSupportPart", target.SupportName)
	model:SetAttribute("ChampionSupportY", target.SurfaceY)
	model:SetAttribute("ChampionFeetTargetY", target.SurfaceY)
	model:SetAttribute("ChampionFeetLockError", feetError)
	model:SetAttribute("ChampionMeasuredBodyHeight", measured)
	model:SetAttribute("ChampionTargetBodyHeight", target.Height)
	model:SetAttribute("ChampionPlacementRoute", Rig.Version)
	if measured ~= measured or measured < target.Height * Rig.MinHeightRatio or measured > target.Height * Rig.MaxHeightRatio then
		model:SetAttribute("ChampionValidation", "RejectedBodyHeight")
		return false, "RejectedBodyHeight"
	end
	if math.abs(feetError) > Rig.FeetEpsilon then
		model:SetAttribute("ChampionValidation", "RejectedFootLock")
		return false, "RejectedFootLock"
	end

	-- Only the root is anchored: the Motor6Ds animate the limbs, the welded accessories follow.
	local parts, anchored = 0, 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
			descendant.Anchored = descendant == root
			if descendant.Anchored then
				anchored += 1
			end
		end
	end
	model:SetAttribute("ChampionFreezeMode", "RootOnlyMotor6D")
	model:SetAttribute("ChampionBodyPartCount", parts)
	model:SetAttribute("ChampionAnchoredPartCount", anchored)
	model:SetAttribute("ChampionValidation", "PassedRootAnchoredR6")
	return true, nil
end

-- A frame after the model entered the world: the engine has laid the joints out; the feet are
-- measured on that and the (anchored) root, which carries the whole rig, nudged if needed.
function Rig.Settle(env: any, model: any, target: any): boolean
	local root = model.PrimaryPart
	local feet = Rig.FeetBottomY(model)
	if not root or not feet then
		return false
	end
	local feetError = feet - target.SurfaceY
	if math.abs(feetError) > Rig.FeetEpsilon then
		root.CFrame = root.CFrame - env.Vector3.new(0, feetError, 0)
		feetError = (Rig.FeetBottomY(model) or feet) - target.SurfaceY
	end
	model:SetAttribute("ChampionFeetLockError", feetError)
	model:SetAttribute("ChampionSettled", true)
	return math.abs(feetError) <= Rig.FeetEpsilon
end

----------------------------------------------------------------------
-- Dance
----------------------------------------------------------------------

-- The looping dance track on the champion's Animator (nil when it cannot load).
function Rig.LoadDance(env: any, model: any, animationId: string): any?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = env.Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = env.Instance.new("Animation")
	animation.Name = "ChampionDance"
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	set(track, "Priority", env.Enum.AnimationPriority.Action)
	set(track, "Looped", true)
	return track
end

function Rig.PlayDance(track: any): boolean
	return track ~= nil and (pcall(function()
		track:Play(0.3)
	end))
end

function Rig.StopDance(track: any)
	if track then
		pcall(function()
			track:Stop(0.3)
		end)
	end
end

----------------------------------------------------------------------
-- The default champion
----------------------------------------------------------------------

-- The classic R6 joints (name, Part0, Part1, C0, C1).
local function r6Joints(CFrame: any): { any }
	return {
		{ "RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
		{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
		{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
		{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
		{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
		{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	}
end

Rig.NeutralSkin = { 255, 205, 160 }
Rig.NeutralLegs = { 40, 42, 52 }

-- A classic R6 (1-stud limbs, 5 studs tall) in the board's colour, jointed like any avatar so
-- Place and the dance treat it the same. Out of the world, rest pose around the origin.
function Rig.BuildNeutralR6(env: any, name: string, accent: any): any
	local Instance, Vector3, CFrame, Color3 = env.Instance, env.Vector3, env.CFrame, env.Color3
	local skin = Color3.fromRGB(Rig.NeutralSkin[1], Rig.NeutralSkin[2], Rig.NeutralSkin[3])
	local legs = Color3.fromRGB(Rig.NeutralLegs[1], Rig.NeutralLegs[2], Rig.NeutralLegs[3])
	local model = Instance.new("Model")
	model.Name = name
	local specs = {
		{ "HumanoidRootPart", Vector3.new(2, 2, 1), skin },
		{ "Torso", Vector3.new(2, 2, 1), accent },
		{ "Head", Vector3.new(2, 1, 1), skin },
		{ "Left Arm", Vector3.new(1, 2, 1), skin },
		{ "Right Arm", Vector3.new(1, 2, 1), skin },
		{ "Left Leg", Vector3.new(1, 2, 1), legs },
		{ "Right Leg", Vector3.new(1, 2, 1), legs },
	}
	local parts = {}
	for _, spec in specs do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.Color = spec[3]
		part.Material = env.Enum.Material.SmoothPlastic
		part.TopSurface = env.Enum.SurfaceType.Smooth
		part.BottomSurface = env.Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(0, 3, 0)
		part.Parent = model
		parts[spec[1]] = part
	end
	parts.HumanoidRootPart.Transparency = 1
	for _, joint in r6Joints(CFrame) do
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = parts[joint[2]]
		motor.Part1 = parts[joint[3]]
		motor.C0 = joint[4]
		motor.C1 = joint[5]
		motor.Parent = parts[joint[2]]
	end

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = env.Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = parts.Head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = env.Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = parts.Head

	local colors = Instance.new("BodyColors")
	colors.HeadColor3 = skin
	colors.LeftArmColor3 = skin
	colors.RightArmColor3 = skin
	colors.TorsoColor3 = accent
	colors.LeftLegColor3 = legs
	colors.RightLegColor3 = legs
	colors.Parent = model

	local humanoid = Instance.new("Humanoid")
	set(humanoid, "RigType", env.Enum.HumanoidRigType.R6)
	humanoid.Parent = model
	model.PrimaryPart = parts.HumanoidRootPart
	Rig.SolveRestPose(model, parts.HumanoidRootPart)
	return model
end

return Rig
