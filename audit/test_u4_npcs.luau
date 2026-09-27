-- test_u4_npcs.luau (Update 4, lobby NPCs, 2026-09-25)
-- Dr. Eggman (Talk -> quests) and The Flash (Sign up -> race categories) in every lobby
-- (Shared/LobbyNpcConfig, LobbyNpcRig, LobbyNpcPose, LobbyNpcUi, LobbyNpcText;
-- Gameplay/LobbyNpcs.server, Gameplay/LobbyNpcsClient.client). Checks:
--   1. every NPC source compiles; none uses CFrame.lookAt;
--   2. the contract: Flash's buttons send RaceRequest { action = "Join", source = "Npc",
--      category = "Beginner" | "Rank" | "Open" } (exactly those keys; nothing else is sent), and
--      Beginners greys out only for RaceBracket "Mid" / "Pro" (absent: all open); the kill
--      switch is Workspace.U4Off_Npcs; no parts-built Eggman by default and never a parts Flash;
--      the owner's models found by name, tag, later arrival; the clients find NPCs by tag;
--   2b. the owner's models (2026-09-25): a fake owner-placed R6 Eggman (an anchored statue with an
--      Animate script, an Animator and a loose pedestal), a tagged model with another name, and the
--      real R15 Flash captured from Steal a Hero (design/npc/Flash.rbxm) are recognised, prepared
--      where they stand (root anchored, body jointed and out of the way, scripts off), get their
--      E / ButtonX prompt, and their idle and reactions (R15 joints mapped) keep the feet down and
--      read as meant; a rig without shoulders keeps its prompt and skips the idle; nothing in the
--      three places is taken for an NPC by mistake;
--   3. the words: every key in en / es / pt (Spanish and Portuguese really translated), every
--      language within its caps, the Eggman line as written;
--   4. the rigs: both build in Lune, six R6-named Motor6Ds and welds that hold the rest pose,
--      only the root and the base anchored, only the base colliding / queryable, nothing
--      touchable; the idles and reactions are finite, keep a foot on the base, and Eggman's
--      gloves rest on his hips;
--   5. the spots, read from the three .rbxl files (never written): the base on the floor at every
--      probe, nothing inside the NPC's volume, clear of the spawn, the portal, the Spin Wheel,
--      the treadmills, the boards, Rank Rewards, the AFK ring, the dance floor, the admin
--      treadmill and (Eggman) the Race Gate; outside the portal flight's shot; Eggman in sight
--      of the spawn;
--   6. Flash's window, the bubble, the tag and the "!" build; every tile carries its Category.
-- Run: lune run audit/test_u4_npcs.luau   (from the project root; design/npc/Flash.rbxm comes from
--      lune run audit/u4_npc_assets.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local SHARED = "src/common/ReplicatedStorage/Shared/"
local SERVER_FILE = "src/common/ServerScriptService/Gameplay/LobbyNpcs.server.luau"
local CLIENT_FILE = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/LobbyNpcsClient.client.luau"
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local LobbyNpcConfig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local LobbyNpcText = require("../src/common/ReplicatedStorage/Shared/LobbyNpcText")
local LobbyNpcPose = require("../src/common/ReplicatedStorage/Shared/LobbyNpcPose")
local LobbyNpcRig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcRig")
local LobbyNpcUi = require("../src/common/ReplicatedStorage/Shared/LobbyNpcUi")
local PlaceFiles = require("./place_files")

local ENV = {
	Instance = roblox.Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Font = roblox.Font,
}

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function near(a, b, eps)
	return (a.Position - b.Position).Magnitude <= eps
		and (a.LookVector - b.LookVector).Magnitude <= eps and (a.UpVector - b.UpVector).Magnitude <= eps
end

----------------------------------------------------------------------
-- 1. Compile
----------------------------------------------------------------------
local SOURCES = {
	SHARED .. "LobbyNpcConfig.luau", SHARED .. "LobbyNpcText.luau", SHARED .. "LobbyNpcRig.luau",
	SHARED .. "LobbyNpcPose.luau", SHARED .. "LobbyNpcUi.luau", SERVER_FILE, CLIENT_FILE,
}
for _, path in SOURCES do
	local source = fs.readFile(path)
	local ok, problem = pcall(luau.compile, source)
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
	assert(not string.find(source, "lookAt(", 1, true), path .. ": calls CFrame.lookAt (wrong in Lune, not needed)")
end
pass(("%d NPC sources compile"):format(#SOURCES))

----------------------------------------------------------------------
-- 2. The contract
----------------------------------------------------------------------
do
	for _, category in { "Beginner", "Rank", "Open" } do
		local payload = assert(LobbyNpcConfig.JoinPayload(category), "no payload for " .. category)
		local keys = 0
		for key in payload do
			keys += 1
			assert(key == "action" or key == "source" or key == "category", "unexpected payload key " .. tostring(key))
		end
		assert(keys == 3, category .. ": the payload must have exactly action, source and category")
		assert(payload.action == "Join" and payload.source == "Npc" and payload.category == category,
			category .. ": payload is not { action = \"Join\", source = \"Npc\", category = \"" .. category .. "\" }")
	end
	for _, bad in { "Pro", "Mid", "", 1, true } do
		assert(LobbyNpcConfig.JoinPayload(bad) == nil, "a payload for " .. tostring(bad))
	end
	assert(LobbyNpcConfig.JoinPayload(nil) == nil, "a payload for nil")
	assert(#LobbyNpcConfig.Categories == 3, "three categories")
	assert(LobbyNpcConfig.BracketAttribute == "RaceBracket", "the bracket attribute is RaceBracket")
	for _, bracket in { "Beginner", "", "Unknown" } do
		assert(LobbyNpcConfig.CategoryAllowed("Beginner", bracket), "Beginners closed for bracket " .. bracket)
	end
	assert(LobbyNpcConfig.CategoryAllowed("Beginner", nil), "Beginners closed with no bracket")
	for _, bracket in { "Mid", "Pro" } do
		assert(not LobbyNpcConfig.CategoryAllowed("Beginner", bracket), "Beginners open for bracket " .. bracket)
		assert(LobbyNpcConfig.CategoryAllowed("Rank", bracket) and LobbyNpcConfig.CategoryAllowed("Open", bracket),
			"My Rank / Open closed for " .. bracket)
	end
	assert(LobbyNpcConfig.KillAttribute == "U4Off_Npcs", "kill switch is " .. tostring(LobbyNpcConfig.KillAttribute))

	-- The client sends exactly one thing, the payload above, from the category a tile carries.
	local client = fs.readFile(CLIENT_FILE)
	local _, fires = string.gsub(client, ":FireServer%(", "")
	assert(fires == 1, ("the client fires %d remotes (expected only RaceRequest)"):format(fires))
	assert(string.find(client, "local payload = LobbyNpcConfig.JoinPayload(category)", 1, true), "the client builds its payload elsewhere")
	assert(string.find(client, "remote:FireServer(payload)", 1, true), "the client does not send the payload as built")
	assert(string.find(client, 'WaitForChild("RaceRequest"', 1, true), "the client does not use RaceRequest")
	assert(string.find(client, "tiles[category].Activated:Connect(function()\n\t\tchoose(category)", 1, true), "tiles not wired to their category")
	assert(string.find(client, "LobbyNpcConfig.BracketAttribute", 1, true), "the client ignores RaceBracket")
	assert(string.find(client, 'MenuEvents.Request("Quests"', 1, true), "Eggman does not open the quests")
	assert(string.find(client, 'MenuEvents.Request("Race"', 1, true), "Weekly Records does not open the race panel")
	for _, attribute in { "QuestRewardReady", "QuestAvailable" } do
		assert(string.find(client, attribute, 1, true), "the \"!\" ignores " .. attribute)
	end
	local server = fs.readFile(SERVER_FILE)
	for _, needle in { "LobbyNpcConfig.KillAttribute", "ModelStreamingMode.Atomic", 'U4.IsOn("Race")', "CreateHumanoidModelFromDescription",
		"LobbyNpcRig.PrepareOwnerModel(", "LobbyNpcRig.AddPrompt(", "CollectionService:AddTag(", "CollectionService:GetTagged(",
		"GetInstanceAddedSignal(", "Workspace.DescendantAdded:Connect(consider)", "GetPlayerFromCharacter" } do
		assert(string.find(server, needle, 1, true), "the server lacks " .. needle)
	end
	assert(not string.find(server, "FireServer", 1, true) and not string.find(server, "RaceService", 1, true),
		"the server must not join races itself")
	-- Owner, 2026-09-25: Eggman is his own model (the parts one only behind the flag, off), and
	-- there is no parts-built Flash at all.
	assert(LobbyNpcConfig.SpawnPartsEggman == false, "the parts-built Eggman must be off by default")
	assert(string.find(server, "if LobbyNpcConfig.SpawnPartsEggman then\n\tlocal ok, problem = pcall(spawnPartsEggman)", 1, true),
		"the parts Eggman is not behind LobbyNpcConfig.SpawnPartsEggman")
	local _, eggmanBuilds = string.gsub(server, "BuildEggman%(", "")
	local _, spawnCalls = string.gsub(server, "spawnPartsEggman%(", "")
	assert(eggmanBuilds == 1 and spawnCalls == 1, "BuildEggman / spawnPartsEggman called outside the flag")
	assert(not string.find(server, "BuildR6", 1, true), "the server still builds a parts Flash")
	for _, needle in { "CollectionService:GetInstanceAddedSignal(tagName)", "CollectionService:GetInstanceRemovedSignal(tagName)",
		"LobbyNpcRig.FindJoints(model)", "LobbyNpcConfig.KindAttribute" } do
		assert(string.find(client, needle, 1, true), "the client lacks " .. needle)
	end
	for kind, tag in LobbyNpcConfig.Tags do
		assert(tag == "LobbyNpc" .. kind, "tag of " .. kind)
	end
	pass("RaceRequest { action = \"Join\", source = \"Npc\", category } only; RaceBracket greys out Beginners; U4Off_Npcs; no parts Eggman by default, no parts Flash; owner models by name, tag and later arrival; clients by tag")
end

----------------------------------------------------------------------
-- 3. The words
----------------------------------------------------------------------
do
	local en = LobbyNpcText.Strings.en
	for key in LobbyNpcText.Caps do
		assert(type(en[key]) == "string", "no English for " .. key)
	end
	for key in en do
		assert(LobbyNpcText.Caps[key], "no cap for " .. key)
	end
	for _, lang in LobbyNpcText.Required do
		local strings = assert(LobbyNpcText.Strings[lang], "no " .. lang)
		for key in LobbyNpcText.Caps do
			assert(type(strings[key]) == "string" and strings[key] ~= "", lang .. " lacks " .. key)
		end
	end
	for _, lang in { "es", "pt" } do
		for _, key in { "EggmanLine", "EggmanPrompt", "FlashLine", "FlashPrompt", "BeginnerSub", "Records" } do
			assert(LobbyNpcText.Strings[lang][key] ~= en[key], lang .. " " .. key .. " is not translated")
		end
	end
	local languages = 0
	for lang, strings in LobbyNpcText.Strings do
		languages += 1
		assert(table.find(LobbyNpcText.Languages, lang), "unknown language " .. lang)
		for key, text in strings do
			local cap = assert(LobbyNpcText.Caps[key], lang .. ": unknown key " .. key)
			local length = LobbyNpcText.MeasuredLength(text)
			assert(length <= cap, ("%s %s is %d long (cap %d): %s"):format(lang, key, length, cap, text))
			if lang == "fr" then
				assert(not string.find(text, " [!?:]"), "fr " .. key .. ": a plain space before ! ? :")
			end
		end
	end
	assert(en.EggmanLine == "Ho ho ho! Think you're fast enough for my daily challenges?", "Eggman's line changed")
	assert(LobbyNpcText.Get("EggmanLine", "xx") == en.EggmanLine and LobbyNpcText.Get("Nope", "es") == "Nope", "fallbacks")
	pass(("NPC words: every key in en/es/pt, %d languages within their caps"):format(languages))
end

----------------------------------------------------------------------
-- 4. Rigs and poses
----------------------------------------------------------------------
local function boxOf(part)
	local cf, size = part.CFrame, part.Size
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
				lo[1], lo[2], lo[3] = math.min(lo[1], p.X), math.min(lo[2], p.Y), math.min(lo[3], p.Z)
				hi[1], hi[2], hi[3] = math.max(hi[1], p.X), math.max(hi[2], p.Y), math.max(hi[3], p.Z)
			end
		end
	end
	return { x0 = lo[1], y0 = lo[2], z0 = lo[3], x1 = hi[1], y1 = hi[2], z1 = hi[3] }
end

-- Every part's CFrame with the Motor6Ds at `transforms` (Motor6D -> Transform), from the root
-- (welds and weld constraints keep their rest offsets).
local function posed(model, transforms)
	local frames = {}
	local root = LobbyNpcRig.FindRoot(model)
	frames[root] = root.CFrame
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			table.insert(joints, d)
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			table.insert(joints, { Part0 = d.Part0, Part1 = d.Part1, C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame, C1 = CFrame.new(), Weld = true })
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d ~= root then
			frames[d] = d.CFrame
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, joint in joints do
			if frames[joint.Part0] and not frames[joint.Part1] then
				local transform = transforms[joint] or CFrame.new()
				frames[joint.Part1] = frames[joint.Part0] * joint.C0 * transform * joint.C1:Inverse()
				progress = true
			end
		end
	end
	return frames
end

-- The Transforms the client writes (LobbyNpcsClient): the pose joints found by
-- LobbyNpcRig.FindJoints (R6, or R15 mapped), each turned into its joint's C0 axes.
local function transformsAt(model, kind, t, reaction, age)
	local out = LobbyNpcPose.Sample(kind, t, LobbyNpcPose.NewOut(), reaction, age)
	local transforms = {}
	for _, joint in (LobbyNpcRig.FindJoints(model)) do
		local basis = joint.motor.C0.Rotation
		transforms[joint.motor] = basis:Inverse() * LobbyNpcPose.ToCFrame(out[joint.name], CFrame) * basis
	end
	return transforms, out
end

local function checkRig(model, kind, minHeight, maxHeight)
	local root = assert(model:FindFirstChild("HumanoidRootPart"), kind .. ": no HumanoidRootPart")
	local base = assert(model:FindFirstChild(LobbyNpcRig.BaseName), kind .. ": no base")
	assert(root.Anchored and root.Transparency == 1 and not root.CanQuery and not root.CanCollide, kind .. ": root must be anchored, invisible, no collide/query")
	assert(base.Anchored and base.CanCollide and base.CanQuery, kind .. ": the base must be anchored and collide")
	local parts, top = 0, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			assert(not d.CanTouch, kind .. ": " .. d.Name .. " can touch")
			if d ~= base then
				assert(not d.CanCollide and not d.CanQuery, kind .. ": " .. d.Name .. " collides or blocks rays")
				assert(d.Anchored == (d == root or d.Name == LobbyNpcRig.RimName), kind .. ": " .. d.Name .. " anchored wrongly")
			end
			top = math.max(top, boxOf(d).y1)
		end
		assert(not d:IsA("LuaSourceContainer"), kind .. ": a script inside")
	end
	assert(parts <= 60, kind .. ": " .. parts .. " parts")
	assert(top >= minHeight and top <= maxHeight, ("%s: %.2f studs tall"):format(kind, top))
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
		if d:IsA("Motor6D") or d:IsA("Weld") then
			assert(d.Part0 and d.Part1, kind .. ": joint " .. d.Name .. " unset")
			-- The rest pose holds: nothing snaps when the model is parented.
			assert(near(d.Part0.CFrame * d.C0, d.Part1.CFrame * d.C1, 1e-3), kind .. ": joint " .. d:GetFullName() .. " does not hold the parts where they are")
		end
	end
	for _, name in LobbyNpcRig.JointNames do
		assert(motors[name], kind .. ": no Motor6D " .. name)
	end
	return parts, top
end

local eggman = LobbyNpcRig.BuildEggman(ENV, CFrame.new())
local eggParts, eggTop = checkRig(eggman, "Eggman", 7, 8.6)
local flash = LobbyNpcRig.BuildR6(ENV, CFrame.new())
local flashParts, flashTop = checkRig(flash, "Flash", 5, 6.2)
assert(flash:FindFirstChildOfClass("Humanoid"), "Flash's fallback needs a Humanoid (clothing renders only with one)")
for _, name in { "HatAttachment", "FaceFrontAttachment" } do
	assert(flash.Head:FindFirstChild(name), "Flash's head lacks " .. name)
end
pass(("rigs: Eggman %d parts %.1f studs tall, Flash (fallback) %d parts %.1f tall; joints hold, only the base collides"):format(eggParts, eggTop, flashParts, flashTop))

do
	local baseTop = LobbyNpcRig.BaseHeight
	local function footY(model, frames)
		local low = math.huge
		for part, cf in frames do
			if part.Parent and (string.find(part.Name, "Leg", 1, true) or string.find(part.Name, "Boot", 1, true)) and not string.find(part.Name, "Band", 1, true) then
				local size = part.Size
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						low = math.min(low, (cf * Vector3.new(sx * size.X / 2, -size.Y / 2, sz * size.Z / 2)).Y)
					end
				end
			end
		end
		return low
	end
	local samples = 0
	for _, entry in { { eggman, "Eggman", "Laugh" }, { flash, "Flash", "Point" } } do
		local model, kind, reaction = entry[1], entry[2], entry[3]
		local def = LobbyNpcPose.Defs[kind]
		for step = 0, math.floor(def.Loop * 20) do
			local t = 1.7e9 + step / 20 -- server-clock sized times
			for _, sampleAge in { -1, 0.1, def.Reactions[reaction].Duration * 0.5 } do -- -1: no reaction
				local age = if sampleAge >= 0 then sampleAge else nil
				local transforms, out = transformsAt(model, kind, t, if age then reaction else nil, age)
				for joint, v in out do
					for index = 1, 6 do
						assert(finite(v[index]), kind .. " " .. joint .. ": not finite")
					end
					assert(math.abs(v[4]) <= 180 and math.abs(v[5]) <= 180 and math.abs(v[6]) <= 180, kind .. " " .. joint .. ": over 180 degrees")
					assert(Vector3.new(v[1], v[2], v[3]).Magnitude <= 0.6, kind .. " " .. joint .. ": moved more than 0.6 studs")
				end
				local foot = footY(model, posed(model, transforms))
				assert(foot >= baseTop - 0.45 and foot <= baseTop + 0.35,
					("%s at %.2f s (reaction %s): the lowest foot is at %.2f (base top %.2f)"):format(kind, step / 20, tostring(age), foot, baseTop))
				samples += 1
			end
		end
	end
	-- Hands on hips: the gloves' centres just outside the belly (touching it), at the waist.
	local frames = posed(eggman, (transformsAt(eggman, "Eggman", 0)))
	local torso = eggman.Torso
	for _, name in { "LeftGlove", "RightGlove" } do
		local glove = eggman:FindFirstChild(name)
		local rel = frames[torso]:PointToObjectSpace(frames[glove].Position)
		local a = torso.Size / 2
		local r = math.sqrt((rel.X / a.X) ^ 2 + (rel.Y / a.Y) ^ 2 + (rel.Z / a.Z) ^ 2)
		assert(r >= 1.0 and r <= 1.45, ("Eggman's %s is %.2f belly radii out (hands on hips wants 1.0-1.45)"):format(name, r))
		assert(math.abs(rel.Y) <= a.Y * 0.6, ("Eggman's %s is not at his waist (%.2f)"):format(name, rel.Y))
	end
	-- The gestures read as meant on both rigs (the pose axes are the parent part's, whatever the
	-- joint's own C0): Flash points ahead, looks at a watch on his left wrist in front of his
	-- chest, stretches a leg behind him; Eggman laughs with both fists up.
	local function handIn(model, frames, armName)
		local arm = model:FindFirstChild(armName)
		local hand = frames[arm] * Vector3.new(0, -arm.Size.Y / 2, 0)
		return frames[model.Torso]:PointToObjectSpace(hand)
	end
	local point = LobbyNpcPose.Defs.Flash.Reactions.Point
	local f = posed(flash, (transformsAt(flash, "Flash", 1, "Point", point.Duration / 2)))
	local hand = handIn(flash, f, "Right Arm")
	assert(hand.Z < -1.5 and hand.Y > -0.2 and hand.X > 0.5, ("Flash does not point ahead: right hand at %s"):format(tostring(hand)))
	f = posed(flash, (transformsAt(flash, "Flash", 13.6)))
	hand = handIn(flash, f, "Left Arm")
	assert(hand.Z < -1 and hand.X > -1.6 and hand.Y > -0.6, ("Flash's watch is not in front of him: left hand at %s"):format(tostring(hand)))
	f = posed(flash, (transformsAt(flash, "Flash", 4.4)))
	local foot = f[flash["Right Leg"]] * Vector3.new(0, -1, 0)
	local rel = f[flash.Torso]:PointToObjectSpace(foot)
	assert(rel.Z > 1.2 and rel.Y > -2.2, ("Flash's stretch does not lift his right leg behind: foot at %s"):format(tostring(rel)))
	local laugh = LobbyNpcPose.Defs.Eggman.Reactions.Laugh
	f = posed(eggman, (transformsAt(eggman, "Eggman", 1, "Laugh", laugh.Duration / 2)))
	for _, name in { "LeftGlove", "RightGlove" } do
		local glove = f[eggman:FindFirstChild(name)].Position
		assert(glove.Y > eggman.Head.CFrame.Position.Y - 0.5, ("Eggman's %s is not raised when he laughs (y %.2f)"):format(name, glove.Y))
	end
	pass(("idles and reactions: %d samples finite, a foot always on the base; Eggman's gloves on his hips, fists up when he laughs; Flash points, checks his watch, stretches"):format(samples))
end

----------------------------------------------------------------------
-- 4b. The owner's models (2026-09-25: the owner places Eggman, and may place Flash, himself)
----------------------------------------------------------------------
do
	for name, kind in { Eggman = "Eggman", DrEggman = "Eggman", ["Dr. Eggman"] = "Eggman", ["dr eggman"] = "Eggman",
		ROBOTNIK = "Eggman", ["Dr. Robotnik"] = "Eggman", Flash = "Flash", ["The Flash"] = "Flash", TheFlash = "Flash" } do
		assert(LobbyNpcConfig.KindForName(name) == kind, ("%q is not taken for %s"):format(name, kind))
	end
	for _, name in { "ReverseFlashBoss", "FlashSuit", "Eggs", "Flash2", "Eggman's Base", "Kid Flash", "" } do
		assert(LobbyNpcConfig.KindForName(name) == nil, ("%q taken for an NPC"):format(name))
	end

	-- An R6 as a toolbox statue comes: every part anchored and colliding, an Animate script, an
	-- Animator, a loose (unanchored) pedestal under it; turned 35 degrees, away from the origin.
	local function statue(name)
		local floor = CFrame.new(40, 10, -25) * CFrame.Angles(0, math.rad(35), 0)
		local model = LobbyNpcRig.BuildR6(ENV, floor)
		model.Name = name
		for _, extra in { LobbyNpcRig.BaseName, LobbyNpcRig.RimName, "FallbackSuit" } do
			model:FindFirstChild(extra):Destroy()
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = true
			end
		end
		local animate = roblox.Instance.new("Script")
		animate.Name = "Animate"
		animate.Parent = model
		roblox.Instance.new("Animator").Parent = model:FindFirstChildOfClass("Humanoid")
		local pedestal = roblox.Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Anchored = false
		pedestal.CanCollide = true
		pedestal.Size = Vector3.new(6, 0.4, 6)
		pedestal.CFrame = floor * CFrame.new(0, 0.2, 0)
		pedestal.Parent = model
		return model, pedestal, animate
	end

	local function feetLow(model, frames, names)
		local low = math.huge
		for _, name in names do
			local part = model:FindFirstChild(name)
			local cf, size = frames[part], part.Size
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					low = math.min(low, (cf * Vector3.new(sx * size.X / 2, -size.Y / 2, sz * size.Z / 2)).Y)
				end
			end
		end
		return low
	end

	-- The idle and a reaction on `model`: finite, a foot always down (within the tolerance of the
	-- R6 base check), sampled every 0.25 s over the whole loop.
	local function idleKeepsFeetDown(model, kind, reaction, feet)
		local rest = feetLow(model, posed(model, {}), feet)
		local def = LobbyNpcPose.Defs[kind]
		local samples = 0
		for step = 0, def.Loop * 4 do
			for _, sampleAge in { -1, def.Reactions[reaction].Duration / 2 } do
				local age = if sampleAge >= 0 then sampleAge else nil
				local frames = posed(model, (transformsAt(model, kind, step / 4, if age then reaction else nil, age)))
				local low = feetLow(model, frames, feet)
				assert(low == low and low >= rest - 0.5 and low <= rest + 0.4,
					("%s (%s idle) at %.2f s: the lowest foot moved from %.2f to %.2f"):format(model.Name, kind, step / 4, rest, low))
				samples += 1
			end
		end
		return samples
	end

	local function checkPrompt(root, kind)
		local settings = LobbyNpcConfig.Prompt[kind]
		local prompt = LobbyNpcRig.AddPrompt(ENV, root, settings.Offset, settings.MaxDistance, "Action", "Object")
		-- Where the client looks for it: root.PromptAttachment.NpcPrompt.
		assert(root:FindFirstChild("PromptAttachment") and root.PromptAttachment:FindFirstChild("NpcPrompt") == prompt, kind .. ": prompt not on the root")
		assert(prompt.KeyboardKeyCode == roblox.Enum.KeyCode.E and prompt.GamepadKeyCode == roblox.Enum.KeyCode.ButtonX
			and prompt.HoldDuration == 0 and prompt.RequiresLineOfSight == false and prompt.AutoLocalize == false
			and prompt.MaxActivationDistance == settings.MaxDistance, kind .. ": prompt settings")
		-- Adopted twice (a tag arriving after the name): still one prompt.
		LobbyNpcRig.AddPrompt(ENV, root, settings.Offset, settings.MaxDistance, "Action", "Object")
		local count = 0
		for _, d in root:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				count += 1
			end
		end
		assert(count == 1, kind .. ": " .. count .. " prompts after a second adoption")
	end

	-- 1. The owner's R6 Eggman.
	local model, pedestal, animate = statue("Dr. Eggman")
	local before = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			before[d] = d.CFrame
		end
	end
	local kind, root = LobbyNpcRig.OwnerKind(model, nil)
	assert(kind == "Eggman" and root == model.HumanoidRootPart, "the owner's \"Dr. Eggman\" is not found")
	local report = LobbyNpcRig.PrepareOwnerModel(ENV, model, root)
	assert(root.Anchored and not root.CanCollide and not root.CanQuery and not root.CanTouch, "the root must be anchored and out of the way")
	local joined = LobbyNpcRig.JoinedParts(model, root)
	for part in joined do
		assert(part == root or not part.Anchored, part.Name .. " stays anchored: its joint could not move it")
		assert(not part.CanCollide and not part.CanQuery and not part.CanTouch, part.Name .. " collides, touches or blocks rays")
	end
	assert(not joined[pedestal] and pedestal.Anchored and pedestal.CanCollide, "the loose pedestal must stay put, as authored")
	assert(report.Scripts == 1 and animate.Enabled == false, "the model's Animate script is still on")
	assert(not model:FindFirstChildWhichIsA("Animator", true), "an Animator is left to fight the idle")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid.DisplayDistanceType == roblox.Enum.HumanoidDisplayDistanceType.None, "the Humanoid still shows its name")
	for part, cf in before do
		assert(near(part.CFrame, cf, 1e-6), part.Name .. " moved: the owner's pose and place must be kept")
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			assert(near(d.Part0.CFrame * d.C0, d.Part1.CFrame * d.C1, 1e-3), d.Name .. " would snap when unanchored")
		end
	end
	checkPrompt(root, "Eggman")
	local joints, rig, complete = LobbyNpcRig.FindJoints(model)
	assert(rig == "R6" and complete and #joints == 6, "the R6 Eggman's joints: " .. rig .. " " .. #joints)
	local samples = idleKeepsFeetDown(model, "Eggman", "Laugh", { "Left Leg", "Right Leg" })

	-- 2. Tagged, with another name; not NPCs: a prop called Flash, a Part called Eggman, a Model
	-- with no root.
	local tagged = statue("Robot Doctor")
	assert(LobbyNpcRig.OwnerKind(tagged, nil) == nil, "an untagged \"Robot Doctor\" is taken for an NPC")
	assert(LobbyNpcRig.OwnerKind(tagged, "Eggman") == "Eggman", "a model tagged LobbyNpcEggman is not taken")
	local prop = roblox.Instance.new("Model")
	prop.Name = "Flash"
	local prop_part = roblox.Instance.new("Part")
	prop_part.Parent = prop
	prop.PrimaryPart = prop_part
	assert(LobbyNpcRig.OwnerKind(prop, nil) == nil, "a prop named Flash (no Humanoid) is taken for Flash")
	local loosePart = roblox.Instance.new("Part")
	loosePart.Name = "Eggman"
	assert(LobbyNpcRig.OwnerKind(loosePart, nil) == nil, "a Part named Eggman is taken for an NPC")
	local rootless = roblox.Instance.new("Model")
	rootless.Name = "Eggman"
	roblox.Instance.new("Humanoid").Parent = rootless
	assert(LobbyNpcRig.OwnerKind(rootless, nil) == nil, "a model with no root is taken for an NPC")

	-- 3. A rig with no shoulders: it keeps its prompt, the idle is skipped.
	local broken = statue("Eggman")
	broken.Torso["Left Shoulder"]:Destroy()
	broken.Torso["Right Shoulder"]:Destroy()
	local brokenKind, brokenRoot = LobbyNpcRig.OwnerKind(broken, nil)
	assert(brokenKind == "Eggman", "a rig without shoulders is not taken")
	LobbyNpcRig.PrepareOwnerModel(ENV, broken, brokenRoot)
	checkPrompt(brokenRoot, "Eggman")
	local _, _, brokenComplete = LobbyNpcRig.FindJoints(broken)
	assert(not brokenComplete, "a rig without shoulders is not recognised as incomplete (the client would pose half of it)")

	-- 4. The real R15: Steal a Hero's Flash (design/npc/Flash.rbxm), as the owner would place it.
	local file = "design/npc/Flash.rbxm"
	assert(fs.isFile(file), file .. " is missing: lune run audit/u4_npc_assets.luau")
	local r15 = roblox.deserializeModel(fs.readFile(file))[1]
	assert(not r15:FindFirstChildWhichIsA("LuaSourceContainer", true), "the captured Flash carries a script")
	local r15Kind, r15Root = LobbyNpcRig.OwnerKind(r15, nil)
	assert(r15Kind == "Flash" and r15Root == r15.HumanoidRootPart, "the captured Flash is not found by name")
	LobbyNpcRig.PrepareOwnerModel(ENV, r15, r15Root)
	checkPrompt(r15Root, "Flash")
	local r15Joints, r15Rig, r15Complete = LobbyNpcRig.FindJoints(r15)
	assert(r15Rig == "R15" and r15Complete and #r15Joints == 6, "the R15 joints: " .. r15Rig .. " " .. #r15Joints)
	local mapped = {}
	for _, joint in r15Joints do
		mapped[joint.name] = joint.motor.Name
	end
	assert(mapped.RootJoint == "Root" and mapped.Neck == "Neck" and mapped["Left Shoulder"] == "LeftShoulder"
		and mapped["Right Hip"] == "RightHip", "R15 joints mapped wrongly")
	local r15Feet = { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg" }
	samples += idleKeepsFeetDown(r15, "Flash", "Point", r15Feet)
	samples += idleKeepsFeetDown(r15, "Eggman", "Laugh", r15Feet) -- an R15 Eggman
	local function partIn(frames, name, relativeTo)
		return frames[r15[relativeTo]]:PointToObjectSpace(frames[r15[name]].Position)
	end
	local point = LobbyNpcPose.Defs.Flash.Reactions.Point
	local f = posed(r15, (transformsAt(r15, "Flash", 1, "Point", point.Duration / 2)))
	local hand = partIn(f, "RightHand", "UpperTorso")
	assert(hand.Z < -1.5 and hand.Y > -0.5, "R15 Flash does not point ahead: " .. tostring(hand))
	f = posed(r15, (transformsAt(r15, "Flash", 13.6)))
	hand = partIn(f, "LeftHand", "UpperTorso")
	assert(hand.Z < -1 and hand.X > -1.6, "R15 Flash's watch is not in front of him: " .. tostring(hand))
	f = posed(r15, (transformsAt(r15, "Flash", 4.4)))
	local foot = partIn(f, "RightFoot", "UpperTorso")
	assert(foot.Z > 1, "R15 Flash does not stretch his leg behind: " .. tostring(foot))
	local laugh = LobbyNpcPose.Defs.Eggman.Reactions.Laugh
	f = posed(r15, (transformsAt(r15, "Eggman", 1, "Laugh", laugh.Duration / 2)))
	for _, name in { "LeftHand", "RightHand" } do
		assert(f[r15[name]].Position.Y > r15.Head.CFrame.Position.Y - 0.5, "an R15 Eggman's fists are not up when he laughs")
	end

	pass(("the owner's models: R6 statue prepared in place (root anchored, body jointed, pedestal kept, Animate off), tagged / named / not NPCs told apart, a rig without shoulders still talks, the real R15 Flash mapped (Root, Neck, LeftShoulder...); %d idle samples keep a foot down"):format(samples))
end

----------------------------------------------------------------------
-- 5. The spots in the three places
----------------------------------------------------------------------
-- Config.luau cannot load in Lune (it reads the place at require time): its lobby spots are
-- read from the source text, as test_u4_race_placement does.
local configSource = fs.readFile(SHARED .. "Config.luau")
local function block(startPattern)
	local start = assert(string.find(configSource, startPattern, 1, true), "Config block " .. startPattern)
	local stop = string.find(configSource, "\n}\n", start, true)
	return string.sub(configSource, start, stop)
end
local function vector(text)
	local x, y, z = string.match(text, "Vector3%.new%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
	return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end
local afkBlock = block("Config.AfkZone = {")
local spotRadius = tonumber(string.match(afkBlock, "SpotRadius%s*=%s*([%d%.]+)")) or 22
local treadmillBlock = block("Config.AdminTreadmill = {")
local discoBlock = block("Config.AdminDisco = {")

-- The portal flight's maths, run for real (it reads the global Vector3).
local Shot = luau.load(fs.readFile(SHARED .. "WorldPortalShot.luau"), {
	debugName = "WorldPortalShot",
	environment = { Vector3 = Vector3, math = math, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring },
})()

local TREADMILL_MODELS = { Basic = true, Golden = true, Candy = true, Diamond = true, Needoh = true, Admin = true, Hacker = true }
-- Studs of floor kept between an NPC's base disc and each lobby feature (XZ, edge to edge).
local CLEARANCE = {
	Eggman = { spawn = 16, portal = 12, spinwheel = 12, treadmill = 10, leaderboard = 8, rankrewards = 10, racegate = 12,
		afk = 6, disco = 12, admintreadmill = 12 },
	Flash = { spawn = 12, portal = 12, spinwheel = 12, treadmill = 10, leaderboard = 6, rankrewards = 10, racegate = 1.5,
		afk = 6, disco = 12, admintreadmill = 12 },
}
local FOOTPRINT = 2.95 -- the base rim's radius
local VOLUME = { Eggman = { Radius = 2.5, Top = 7.8 }, Flash = { Radius = 1.7, Top = 5.8 } }

local function segmentHitsPart(a, b, part)
	local cf = part.CFrame
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local half = part.Size / 2
	local t0, t1 = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local from, delta = la[axis], lb[axis] - la[axis]
		if math.abs(delta) < 1e-6 then
			if math.abs(from) > half[axis] then
				return nil
			end
		else
			local n, f = (-half[axis] - from) / delta, (half[axis] - from) / delta
			if n > f then
				n, f = f, n
			end
			t0, t1 = math.max(t0, n), math.min(t1, f)
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0
end

local function inside(part, point)
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- XZ gap from a disc (centre, radius) to a box.
local function gapToBox(center, radius, box)
	local dx = math.max(box.x0 - center.X, center.X - box.x1, 0)
	local dz = math.max(box.z0 - center.Z, center.Z - box.z1, 0)
	return math.sqrt(dx * dx + dz * dz) - radius
end

local function ancestorKey(part, ws)
	local cursor = part
	while cursor and cursor ~= ws do
		local name = cursor.Name
		local lower = string.lower(name)
		if name == "SpinWheelLobby" then
			return "spinwheel", cursor
		elseif name == "RaceGate" or name == "RaceLobbyBooth" then
			return "racegate", cursor
		elseif name == "Rank Rewards" then
			return "rankrewards", cursor
		elseif string.find(lower, "leaderboard", 1, true) and not string.find(lower, "area", 1, true) then
			return "leaderboard", part -- each board on its own: World 2 has them on both sides
		elseif string.find(lower, "portal", 1, true) then
			return "portal", cursor
		elseif TREADMILL_MODELS[name] and cursor:IsA("Model") then
			return "treadmill", cursor
		end
		cursor = cursor.Parent
	end
	return nil, nil
end

local problems = {}
for _, place in PlaceFiles.Places do
	local world = place.key
	local game = roblox.deserializePlace(fs.readFile(place.file))
	local ws = game:GetService("Workspace")
	local spawnPoint = LobbyNpcConfig.Spawns[world]
	local floorY = spawnPoint.Y
	local lines = {}

	-- The lobby's parts within 260 studs of the spawn, between 10 under and 60 over the floor.
	local lobby = {}
	local zones = {}
	for _, d in ws:GetDescendants() do
		if d:IsA("BasePart") and d.ClassName ~= "Terrain" and not d:FindFirstAncestor(LobbyNpcConfig.FolderName) then
			local box = boxOf(d)
			if box.x1 >= spawnPoint.X - 260 and box.x0 <= spawnPoint.X + 260 and box.z1 >= spawnPoint.Z - 260 and box.z0 <= spawnPoint.Z + 260
				and box.y1 >= floorY - 10 and box.y0 <= floorY + 60 then
				table.insert(lobby, { part = d, box = box })
				local key, owner = ancestorKey(d, ws)
				if d:IsA("SpawnLocation") then
					key, owner = "spawn", d
				end
				if key then
					local id = key .. ":" .. owner:GetFullName()
					local zone = zones[id]
					if not zone then
						zone = { key = key, name = owner:GetFullName(), box = box }
						zones[id] = zone
					else
						local b = zone.box
						zone.box = { x0 = math.min(b.x0, box.x0), y0 = math.min(b.y0, box.y0), z0 = math.min(b.z0, box.z0),
							x1 = math.max(b.x1, box.x1), y1 = math.max(b.y1, box.y1), z1 = math.max(b.z1, box.z1) }
					end
				end
			end
		end
	end
	local function rect(key, center, halfX, halfZ)
		zones[key] = { key = key, name = key, box = { x0 = center.X - halfX, x1 = center.X + halfX, z0 = center.Z - halfZ, z1 = center.Z + halfZ, y0 = -math.huge, y1 = math.huge } }
	end
	local afk = vector(assert(string.match(afkBlock, world .. "%s*=%s*(Vector3%.new%b())"), world .. " AFK spot"))
	local tread = vector(assert(string.match(treadmillBlock, world .. "%s*=%s*{%s*Position%s*=%s*(Vector3%.new%b())"), world .. " admin treadmill"))
	local discoWorld = assert(string.match(discoBlock, world .. "%s*=%s*(%b{})"), world .. " disco")
	local discoFloor = vector(assert(string.match(discoWorld, "Floor%s*=%s*(Vector3%.new%b())")))
	local discoSize = vector(assert(string.match(discoWorld, "Size%s*=%s*(Vector3%.new%b())")))
	rect("afk", afk, spotRadius, spotRadius)
	rect("admintreadmill", tread, 13.5, 19)
	rect("disco", discoFloor, discoSize.X / 2, discoSize.Z / 2)

	-- The portal flight's shot in this world.
	local fallback = Shot.Fallback[place.world]
	local shotPoints = {}
	for step = 0, 40 do
		local eye = Shot.Eye(fallback.Position, fallback.Front, step / 40)
		for k = 0, 40 do
			table.insert(shotPoints, fallback.Position:Lerp(eye, k / 40))
		end
	end

	local spawnPart = nil
	for _, entry in lobby do
		if entry.part:IsA("SpawnLocation") and (entry.part.CFrame.Position - spawnPoint).Magnitude < 3 then
			spawnPart = entry.part
		end
	end
	assert(spawnPart, world .. ": the spawn in LobbyNpcConfig.Spawns is stale")
	-- What the server would take for the owner's NPCs in this place (none until he places them).
	local found = {}
	-- 2026-09-25: the owner's NPCs (Workspace.LobbyCharacters, put there by the build) stand on these
	-- very spots: they are the NPC, not something in its way.
	local ownerNpcPart = {}
	for _, d in ws:GetDescendants() do
		local ownerKind = if d:IsA("Model") then LobbyNpcRig.OwnerKind(d, nil) else nil
		if ownerKind then
			for _, part in d:GetDescendants() do
				if part:IsA("BasePart") then
					ownerNpcPart[part] = true
				end
			end
			local _, rig, complete = LobbyNpcRig.FindJoints(d)
			table.insert(found, ("%s %s (%s%s)"):format(ownerKind, d:GetFullName(), rig, if complete then "" else ", no idle"))
		end
	end
	table.insert(lines, ("  %s owner-placed NPCs: %s"):format(world, if #found > 0 then table.concat(found, "; ") else "none yet"))
	-- The sight-line probe itself must work: straight down from over the spawn it meets the spawn.
	assert(segmentHitsPart(spawnPoint + Vector3.new(0, 6, 0), spawnPoint - Vector3.new(0, 30, 0), spawnPart),
		world .. ": the line-of-sight probe cannot see the spawn under it")

	-- A place built with the race booth (RaceGate carrying FlashSpot) puts Flash on its kiosk, as
	-- Gameplay/LobbyNpcs does; the booth's author placed that spot, so there only his volume and the
	-- lobby around the booth are checked (the kiosk's floor is the booth's mesh).
	local marker = nil
	for _, name in LobbyNpcConfig.BoothNames do
		local booth = ws:FindFirstChild(name)
		local found = booth and booth:FindFirstChild(LobbyNpcConfig.FlashSpotName, true)
		if found and found:IsA("BasePart") then
			marker = found
			break
		end
	end
	for _, kind in { "Eggman", "Flash" } do
		local onBooth = kind == "Flash" and marker ~= nil
		local spot = if onBooth then LobbyNpcConfig.MarkerSpot(marker.CFrame, marker.Size.Y) else LobbyNpcConfig.Spot(world, kind)
		assert(spot, world .. " " .. kind .. ": no spot")
		local position = spot.Position
		local floor = LobbyNpcConfig.SpotCFrame(spot, CFrame)
		local model
		if kind == "Eggman" then
			model = LobbyNpcRig.BuildEggman(ENV, floor)
		elseif onBooth then
			-- No disc on the kiosk: the feet on the marker's bottom.
			model = LobbyNpcRig.BuildR6(ENV, floor * CFrame.new(0, -LobbyNpcRig.BaseHeight, 0))
			model:FindFirstChild(LobbyNpcRig.BaseName):Destroy()
			model:FindFirstChild(LobbyNpcRig.RimName):Destroy()
			floor = floor * CFrame.new(0, -LobbyNpcRig.BaseHeight, 0)
		else
			model = LobbyNpcRig.BuildR6(ENV, floor)
		end
		local own = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				own[d] = true
			end
		end
		if onBooth then
			for _, d in marker.Parent:GetDescendants() do
				if d:IsA("BasePart") then
					own[d] = true -- the booth's own meshes wrap the kiosk: not obstacles for its host
				end
			end
		end
		local bad = {}
		local function fail(text)
			table.insert(bad, text)
		end
		if onBooth then
			local look = marker.CFrame.LookVector
			if math.abs(look.Y) > 0.05 then
				fail("the booth's FlashSpot does not look level")
			end
			local gate = U4.Race.Gate[world].Position
			if (Vector3.new(position.X, 0, position.Z) - Vector3.new(gate.X, 0, gate.Z)).Magnitude > 30 then
				fail("the booth's FlashSpot is far from the Race Gate point")
			end
		end
		-- The spot is the top of what shows under it (the lobby floor, or a mat laid on it).
		local surface = if onBooth then position.Y else nil
		for _, entry in lobby do
			local part = entry.part
			if (part.CanCollide or part.Transparency < 0.95) and position.X >= entry.box.x0 and position.X <= entry.box.x1
				and position.Z >= entry.box.z0 and position.Z <= entry.box.z1 then
				local rel = part.CFrame:PointToObjectSpace(position)
				if math.abs(rel.X) <= part.Size.X / 2 and math.abs(rel.Z) <= part.Size.Z / 2 then
					local top = position.Y + part.Size.Y / 2 - rel.Y
					if top <= position.Y + 1.2 and top >= position.Y - 1 and (surface == nil or top > surface) then
						surface = top
					end
				end
			end
		end
		if surface == nil or math.abs(surface - position.Y) > 0.05 then
			fail(("the spot's height %.2f is not the surface under it (%s)"):format(position.Y, tostring(surface)))
		end

		-- a) On the floor: the centre and eight points on the base's edge have a colliding top
		-- within 1 stud under them, and the floor's top at the centre is the spot's height.
		for index = 0, if onBooth then -1 else 8 do
			local offset = if index == 0 then Vector3.new(0, 0, 0)
				else Vector3.new(math.cos(index * math.pi / 4), 0, math.sin(index * math.pi / 4)) * 2.6
			local point = position + offset
			local best = nil
			for _, entry in lobby do
				local part = entry.part
				if part.CanCollide and not own[part] and point.X >= entry.box.x0 and point.X <= entry.box.x1 and point.Z >= entry.box.z0 and point.Z <= entry.box.z1 then
					local rel = part.CFrame:PointToObjectSpace(point)
					if math.abs(rel.X) <= part.Size.X / 2 and math.abs(rel.Z) <= part.Size.Z / 2 then
						local topAbove = part.Size.Y / 2 - rel.Y
						if topAbove >= -1.0 and topAbove <= 0.05 and (best == nil or topAbove > best) then
							best = topAbove
						end
					end
				end
			end
			if best == nil then
				fail(("no floor within 1 stud under (%.1f, %.1f)"):format(point.X, point.Z))
			elseif index == 0 and best < -0.5 then
				-- (World 1's treadmill mat does not collide: the floor under it is 0.35 lower.)
				fail(("the floor is %.2f studs under the spot"):format(-best))
			end
		end

		-- b) Nothing inside the NPC: a grid of points through its volume against every lobby
		-- part that collides or shows (the base disc's own layer against anything over the floor).
		local volume = VOLUME[kind]
		local blockers = {}
		for _, entry in lobby do
			local part = entry.part
			local box = entry.box
			if not own[part] and not ownerNpcPart[part] and (part.CanCollide or part.Transparency < 0.95)
				and box.x1 >= position.X - FOOTPRINT and box.x0 <= position.X + FOOTPRINT
				and box.z1 >= position.Z - FOOTPRINT and box.z0 <= position.Z + FOOTPRINT
				and box.y1 > position.Y + 0.1 then
				table.insert(blockers, part)
			end
		end
		local hit = {}
		for y = 0.1, volume.Top, 0.5 do
			local radius = if y <= LobbyNpcRig.BaseHeight then FOOTPRINT else volume.Radius
			for x = -radius, radius, 0.5 do
				for z = -radius, radius, 0.5 do
					if x * x + z * z <= radius * radius then
						local point = floor * Vector3.new(x, y, z)
						for _, part in blockers do
							if not hit[part] and inside(part, point) then
								hit[part] = true
								fail(("%s is inside the NPC (%.1f studs up)"):format(part:GetFullName(), y))
							end
						end
					end
				end
			end
		end

		-- c) Clear of the lobby's features.
		local nearest, nearestName = math.huge, ""
		for _, zone in zones do
			local need = CLEARANCE[kind][zone.key]
			if need and not (onBooth and zone.key == "racegate") then
				local gap = gapToBox(position, FOOTPRINT, zone.box)
				if zone.key ~= "racegate" and gap < nearest then
					nearest, nearestName = gap, zone.name
				end
				if gap < need then
					fail(("%.1f studs from %s (needs %s)"):format(gap, zone.name, tostring(need)))
				end
			end
		end

		-- d) Not in the portal flight's shot (2 studs of margin around the NPC's cylinder).
		for _, point in shotPoints do
			local flat = Vector3.new(point.X - position.X, 0, point.Z - position.Z).Magnitude
			if flat <= volume.Radius + 2 and point.Y >= position.Y - 2 and point.Y <= position.Y + volume.Top + 2 then
				fail("in the portal flight's shot")
				break
			end
		end

		-- e) Eggman in sight of the spawn (eye height over it to his face), close enough.
		local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(spawnPoint.X, 0, spawnPoint.Z)).Magnitude
		if kind == "Eggman" then
			if distance > 160 then
				fail(("%.0f studs from the spawn"):format(distance))
			end
			local eye = spawnPoint + Vector3.new(0, 5, 0)
			local face = floor * Vector3.new(0, 6.8, 0)
			for _, entry in lobby do
				local part = entry.part
				-- (2026-09-26: the owner's NPC model itself, e.g. Eggman's Egg Mobile, is not in its own way.)
				if part ~= spawnPart and not own[part] and not ownerNpcPart[part] and (part.CanCollide or part.Transparency < 0.6) and part.Size.Magnitude >= 2
					and part.Transparency < 0.95 then
					local t = segmentHitsPart(eye, face, part)
					if t and t > 0.01 and t < 0.98 then
						fail(("%s blocks the view from the spawn"):format(part:GetFullName()))
						break
					end
				end
			end
		end

		if #bad == 0 then
			table.insert(lines, ("  %s %-6s at (%.1f, %.1f, %.1f)%s: on the floor, clear; nearest feature %.1f studs (%s); %.0f studs from the spawn")
				:format(world, kind, position.X, position.Y, position.Z, if onBooth then " on the booth" else "", nearest, nearestName, distance))
		else
			table.insert(problems, world .. " " .. kind)
			table.insert(lines, ("  %s %s at (%.1f, %.1f, %.1f):"):format(world, kind, position.X, position.Y, position.Z))
			for index = 1, math.min(8, #bad) do
				table.insert(lines, "    FAIL " .. bad[index])
			end
		end
	end
	print(table.concat(lines, "\n"))
end
if #problems > 0 then
	error("test_u4_npcs: misplaced NPCs: " .. table.concat(problems, ", "))
end
pass("both NPCs stand on the floor, clear of every lobby feature and the portal flight, in all 3 places; Eggman in sight of the spawn")

----------------------------------------------------------------------
-- 5b. On the race booth's kiosk (RaceArenaBuilder's RaceLobbyBooth spec, booth space): Flash on
-- FlashSpot, through his whole idle and reaction, never cuts into the booth's colliders.
----------------------------------------------------------------------
do
	local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
	local spec = RaceArenaBuilder.AssetSpec and RaceArenaBuilder.AssetSpec.RaceLobbyBooth
	if not spec or not spec.Markers or not spec.Markers.FlashSpot then
		print("  (no RaceLobbyBooth FlashSpot in RaceArenaBuilder: kiosk check skipped)")
	else
		local feet = spec.Markers.FlashSpot
		local floor = CFrame.new(feet[1], feet[2], feet[3]) -- the marker's bottom, looking -Z (the booth's front)
		local model = LobbyNpcRig.BuildR6(ENV, floor * CFrame.new(0, -LobbyNpcRig.BaseHeight, 0))
		-- How deep `p` is inside the collider (<= 0: outside).
		local function depthIn(collider, p)
			local c = collider.Center
			if collider.Shape == "Cylinder" then
				local dx, dz = p.X - c[1], p.Z - c[3]
				return math.min(collider.Radius - math.sqrt(dx * dx + dz * dz), collider.Height / 2 - math.abs(p.Y - c[2]))
			end
			local s = collider.Size
			return math.min(s[1] / 2 - math.abs(p.X - c[1]), s[2] / 2 - math.abs(p.Y - c[2]), s[3] / 2 - math.abs(p.Z - c[3]))
		end
		local bodyParts = {}
		for _, name in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			table.insert(bodyParts, model:FindFirstChild(name))
		end
		local worst, deepest = nil, 0
		local def = LobbyNpcPose.Defs.Flash
		local cases = 0
		for step = 0, math.floor(def.Loop * 4) do
			for _, sampleAge in { -1, def.Reactions.Point.Duration / 2 } do -- -1: no reaction
				local age = if sampleAge >= 0 then sampleAge else nil
				local frames = posed(model, (transformsAt(model, "Flash", step / 4, if age then "Point" else nil, age)))
				cases += 1
				for _, part in bodyParts do
					local cf, size = frames[part], part.Size
					for ix = -1, 1, 0.5 do
						for iy = -1, 1, 0.5 do
							for iz = -1, 1, 0.5 do
								local p = cf * Vector3.new(ix * size.X * 0.45, iy * size.Y * 0.45, iz * size.Z * 0.45)
								if p.Y > feet[2] + 0.1 then
									for _, collider in spec.Colliders do
										local depth = depthIn(collider, p)
										if depth > deepest then
											deepest = depth
											worst = ("Flash's %s %.2f studs into the booth's %s at %.2f s"):format(part.Name, depth, collider.Name, step / 4)
										end
									end
								end
							end
						end
					end
				end
			end
		end
		-- A hand may graze the counter's back edge in a quick swing (the kiosk spot is ~0.8 studs
		-- behind it); nothing may go deeper than KIOSK_GRAZE.
		local KIOSK_GRAZE = 0.15
		assert(deepest <= KIOSK_GRAZE, worst)
		pass(("on the race booth's kiosk (FlashSpot %s): %d poses, never more than %.2f studs into its %d colliders%s"):format(
			table.concat({ feet[1], feet[2], feet[3] }, ", "), cases, deepest, #spec.Colliders, if worst then " (" .. worst .. ")" else ""))
	end
end

----------------------------------------------------------------------
-- 6. The UI
----------------------------------------------------------------------
do
	local gui = LobbyNpcUi.BuildFlashDialog(ENV)
	assert(gui:IsA("ScreenGui") and gui.Name == LobbyNpcUi.DialogName and gui.ResetOnSpawn == false and gui.Enabled == false, "dialog ScreenGui")
	local window = assert(gui:FindFirstChild("Window"), "no Window")
	for _, name in { "Title", "Close", "Icon", "FitScale", "Speech", "Status", "Tiles", "Records" } do
		assert(window:FindFirstChild(name), "the window lacks " .. name)
	end
	assert(window.Speech:FindFirstChild("Line") and window.Speech:FindFirstChild("Speaker"), "no speech line")
	for _, category in LobbyNpcConfig.Categories do
		local tile = assert(window.Tiles:FindFirstChild(category), "no tile " .. category)
		assert(tile:IsA("TextButton") and tile:GetAttribute("Category") == category, category .. ": tile category attribute")
		assert(tile:FindFirstChild("Label") and tile:FindFirstChild("Sub") and tile:FindFirstChild("Icon"), category .. ": tile pieces")
		assert(LobbyNpcUi.TilePalettes[category] and LobbyNpcText.CategoryKeys[category], category .. ": palette / words")
		-- A tap target on the smallest phone (812 x 375 points): at least 44 px each way.
		local scale = LobbyNpcUi.FitScale(812, 375)
		assert(tile.Size.X.Offset * scale >= 44 and tile.Size.Y.Offset * scale >= 44, category .. ": too small on a phone")
	end
	assert(window.Records:IsA("TextButton"), "Records is a button")
	assert(LobbyNpcUi.FitScale(1920, 1080) == 1, "the window shrinks on a desktop")
	for _, d in gui:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "a script in the dialog")
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			assert(d.AutoLocalize == false, d:GetFullName() .. " would be auto-translated")
		end
	end
	local bubble = LobbyNpcUi.BuildBubble(ENV)
	assert(bubble:IsA("BillboardGui") and bubble.Holder.Plate:FindFirstChild("Text") and bubble.Holder:FindFirstChild("Pop"), "bubble")
	local tag = LobbyNpcUi.BuildTag(ENV)
	assert(tag:FindFirstChild("NameLabel") and tag:FindFirstChild("Role"), "tag")
	local alert = LobbyNpcUi.BuildAlert(ENV)
	assert(alert.Badge:FindFirstChild("Mark") and alert.Badge.Mark.Text == "!" and alert.Badge:FindFirstChild("Bounce"), "alert")
	pass("Flash's window (3 category tiles + WEEKLY RECORDS, phone-sized taps), the bubble, the tag and the \"!\" build")
end

print(("test_u4_npcs: %d checks passed"):format(passed))
