-- audit/perf_place_edits.luau
-- Place content for the 2026-09-22 phone performance pass, applied by the lead's build
-- (audit/fable_build_lib.luau: edit(key, dm, notes) returns true when it changed the place,
-- verify(key, dm) asserts on the round-tripped place). Every edit is idempotent: a second
-- run finds nothing left to do and returns false. Checked by audit/test_perf_phone.luau.
--
-- (a) World 3: the two Stage 10.Decor emitters live 75-120 s at Rate 98 (about 19k large
--     additive particles climbing thousands of studs). Lifetime 2-3 s; the identical
--     emitter in Stage 10.Action Parts uses 1.
-- (b) Worlds 1 and 3: the faint grid overlay Textures (Transparency 0.9) on the Bottom face
--     of static map parts. A face pointing straight down is never seen from the route, so
--     each is a draw layer for nothing (World 1 about 1.4k, World 3 about 2k). Only Bottom
--     faces at the authored 0.9, only on anchored upright Block parts under the map roots,
--     and never on anything the hazard scripts move or rotate.
-- (c) Sounds whose assets this experience may not load ("User is not authorized" in the
--     live error report): World 1's Zoom LightningStart and Trampoline JumpSound, and in
--     every place the Aquatic aura rig's looped Sound. No script uses any of them. Matched
--     by exact path and asset id. The Zoom 'Zoom CW Run' music and LightningSound stay.
--     NOTE: audit/build_core.luau re-inserts ServerStorage.AuthoredAuras.AquaticOpenSource
--     from src/assets/AquaticOpenSource.rbxm, which still carries that Sound; a core rebuild
--     brings it back until this edit runs again.
local rb = require("@lune/roblox")

local Edits = {}

-- (a) -------------------------------------------------------------------------------------
local STAGE10_MAX_LIFETIME = 10
local STAGE10_LIFETIME = rb.NumberRange.new(2, 3)

-- (b) -------------------------------------------------------------------------------------
local TEXTURE_TRANSPARENCY = 0.9
local UPRIGHT = 0.99 -- the part's up vector; the Bottom face then points within ~8 degrees of down
-- Containers the hazard scripts move, spin or swap (World 1's NewWorld1ServerMotion names,
-- World 3's World3HazardLayout containers). Names are compared lowercased, letters and
-- digits only.
local MOVING = {
	fast = true, fastend = true, laserplatform = true, laser = true, slide1 = true, slide2 = true,
	lavaup = true, lava = true, bridge = true, hitbox = true, cylinder = true, cylinder1 = true,
	rollingcylinder = true, cylinderstart = true, cylinderstop = true,
	main = true, platform = true, quicksandpart = true, parkour = true, rails = true, smallwagon = true,
	actionparts = true, pit = true, cactus = true, tumbleweed = true, scorpion = true,
}
local function normalize(name: string): string
	return (string.gsub(string.lower(name), "[^%w]", ""))
end
local function isMovingName(name: string): boolean
	local n = normalize(name)
	return MOVING[n] == true
		or string.match(n, "^hammer%d+$") ~= nil
		or string.match(n, "^pressdown%d+$") ~= nil
		or string.match(n, "^pressdown%d+stop$") ~= nil
		or string.match(n, "^pressdownstop%d+$") ~= nil
end

local function mapRoots(key: string, workspace): { any }
	local roots = {}
	if key == "World1" then
		local root = workspace:FindFirstChild("neworld1")
		if root then
			table.insert(roots, root)
		end
	elseif key == "World3" then
		for _, child in workspace:GetChildren() do
			if string.match(child.Name, "^Stage %d+$") or child.Name == "Lobby" or child.Name == "End" then
				table.insert(roots, child)
			end
		end
	end
	return roots
end

-- The texture overlays (b) removes: returns the list, so verify can demand it is empty.
local function hiddenBottomTextures(key: string, dm): { any }
	local found = {}
	for _, root in mapRoots(key, dm:GetService("Workspace")) do
		for _, texture in root:GetDescendants() do
			if texture.ClassName ~= "Texture" or texture.Face ~= rb.Enum.NormalId.Bottom
				or math.abs(texture.Transparency - TEXTURE_TRANSPARENCY) >= 0.01
				or next(texture:GetAttributes()) ~= nil
			then
				continue
			end
			local part = texture.Parent
			if not part or part.ClassName ~= "Part" or part.Shape ~= rb.Enum.PartType.Block
				or not part.Anchored or part.CFrame.UpVector.Y < UPRIGHT
			then
				continue
			end
			local moving = false
			local node = part
			while node and node ~= root do
				if isMovingName(node.Name) then
					moving = true
					break
				end
				node = node.Parent
			end
			if not moving then
				table.insert(found, texture)
			end
		end
	end
	return found
end

-- (c) -------------------------------------------------------------------------------------
local SOUNDS = {
	{ worlds = { World1 = true }, path = { "Workspace", "Folder", "Zoom", "HumanoidRootPart", "LightningStart" }, id = "10468691302" },
	{ worlds = { World1 = true }, path = { "Workspace", "Trampoline", "Trampoline_Hitbox", "JumpSound" }, id = "15898694877" },
	{ worlds = { World1 = true, World2 = true, World3 = true },
		path = { "ServerStorage", "AuthoredAuras", "AquaticOpenSource", "Rig", "HumanoidRootPart", "Sound" }, id = "71911088386355" },
}

-- The id a Sound plays: these places keep it in AudioContent, which Lune reads; SoundId
-- is tried as well for older files. nil when neither can be read.
local function soundAsset(sound): string?
	for _, property in { "AudioContent", "SoundId" } do
		local ok, value = pcall(function()
			return sound[property]
		end)
		if ok and value ~= nil then
			local text = tostring(value)
			if string.match(text, "%d%d%d%d%d") then
				return text
			end
		end
	end
	return nil
end

-- Every instance at the path (a name may repeat, so all same-named children are followed).
local function atPath(dm, path: { string }): { any }
	local level = { dm:GetService(path[1]) }
	for index = 2, #path do
		local nextLevel = {}
		for _, node in level do
			for _, child in node:GetChildren() do
				if child.Name == path[index] then
					table.insert(nextLevel, child)
				end
			end
		end
		level = nextLevel
	end
	return level
end

local function unauthorizedSounds(key: string, dm): { { sound: any, path: string, id: string, matchedId: boolean } }
	local found = {}
	for _, spec in SOUNDS do
		if not spec.worlds[key] then
			continue
		end
		for _, sound in atPath(dm, spec.path) do
			if sound.ClassName ~= "Sound" then
				continue
			end
			local asset = soundAsset(sound)
			-- An unreadable id still matches on the exact path; a readable different id is left.
			if asset == nil or string.find(asset, spec.id, 1, true) then
				table.insert(found, { sound = sound, path = table.concat(spec.path, "."), id = spec.id, matchedId = asset ~= nil })
			end
		end
	end
	return found
end

local function stage10Emitters(key: string, dm): { any }
	local found = {}
	if key ~= "World3" then
		return found
	end
	local stage = dm:GetService("Workspace"):FindFirstChild("Stage 10")
	local decor = stage and stage:FindFirstChild("Decor")
	if decor then
		for _, emitter in decor:GetDescendants() do
			if emitter.ClassName == "ParticleEmitter" and emitter.Lifetime.Max > STAGE10_MAX_LIFETIME then
				table.insert(found, emitter)
			end
		end
	end
	return found
end

-- Exposed for audit/test_perf_phone.luau.
Edits.hiddenBottomTextures = hiddenBottomTextures
Edits.unauthorizedSounds = unauthorizedSounds
Edits.stage10Emitters = stage10Emitters

function Edits.edit(key: string, dm, notes: { string }?): boolean
	local changed = false
	local function note(text: string)
		if notes then
			table.insert(notes, text)
		end
	end

	local emitters = stage10Emitters(key, dm)
	for _, emitter in emitters do
		emitter.Lifetime = STAGE10_LIFETIME
	end
	if #emitters > 0 then
		changed = true
		note(("perf: Stage 10.Decor emitters lifetime 2-3 s (%d)"):format(#emitters))
	end

	local textures = hiddenBottomTextures(key, dm)
	for _, texture in textures do
		texture:Destroy()
	end
	if #textures > 0 then
		changed = true
		note(("perf: hidden Bottom 0.9 textures removed (%d)"):format(#textures))
	end

	local sounds = unauthorizedSounds(key, dm)
	for _, entry in sounds do
		entry.sound:Destroy()
		note(("perf: unauthorized sound %s (%s%s) removed"):format(entry.path, entry.id, if entry.matchedId then "" else ", id unreadable"))
	end
	if #sounds > 0 then
		changed = true
	end
	return changed
end

function Edits.verify(key: string, dm)
	assert(#stage10Emitters(key, dm) == 0, key .. ": a Stage 10.Decor emitter still lives longer than 10 s")
	assert(#hiddenBottomTextures(key, dm) == 0, key .. ": hidden Bottom 0.9 textures remain")
	assert(#unauthorizedSounds(key, dm) == 0, key .. ": an unauthorized place Sound remains")
	if key == "World1" then
		-- The Zoom music and the looped lightning stay (not in the error report).
		local zoom = atPath(dm, { "Workspace", "Folder", "Zoom" })
		for _, model in zoom do
			local root = model:FindFirstChild("HumanoidRootPart")
			assert(not root or root:FindFirstChild("LightningSound"), key .. ": Zoom's LightningSound must stay")
		end
	end
	return true
end

return Edits
