-- test_world3_cosmetics.luau
-- The World 3 cosmetics drop: the Tung Tung Sahur rig and the Aura 67 effect that the
-- user added to World 1 in Studio, now in every built world (and with no scripts);
-- the authored auras in the shop; the new trails; Aura 67 and Tung Tung on the Spin
-- Wheel; the Tung Tung skin; and the admins' Unlock All Cosmetics.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- 1. The captured art is in every world, and carries no script
----------------------------------------------------------------------
do
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local storage = place:GetService("ServerStorage")
		local tung = storage:FindFirstChild("TungTung")
		assert(tung and tung:IsA("Model") and tung:FindFirstChildOfClass("Humanoid"), world .. " has the Tung Tung rig")
		for _, part in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightHand", "LeftFoot" } do
			local found = tung:FindFirstChild(part)
			assert(found and found:IsA("MeshPart") and found:FindFirstChildOfClass("SurfaceAppearance"), world .. " Tung Tung " .. part .. " keeps its mesh and texture")
		end
		for _, d in tung:GetDescendants() do
			assert(not d:IsA("LuaSourceContainer"), world .. ": the rig's hidden scripts are gone (" .. d:GetFullName() .. ")")
		end
		local auras = storage:FindFirstChild("AuthoredAuras")
		local aura = auras and auras:FindFirstChild("67")
		assert(aura and aura:IsA("BasePart"), world .. " has Aura 67 with the authored auras")
		local emitters = 0
		for _, child in aura:GetChildren() do
			if child:IsA("ParticleEmitter") then
				emitters += 1
			end
		end
		assert(emitters == 11, world .. " Aura 67 keeps its 11 emitters")
		for _, d in place:GetDescendants() do
			assert(d.Name ~= "PositionsFix", world .. " has no PositionsFix anywhere")
		end
	end
	local build = fs.readFile("audit/build_core.luau")
	has(build, "'Assets may not carry scripts: '", "build_core refuses an asset with a script")
	print("PASS assets: Tung Tung and Aura 67 are in all three worlds, without the free model's hidden scripts")
end

----------------------------------------------------------------------
-- 2. World 3's auras: in the shop, and built into working templates
----------------------------------------------------------------------
local function catalogEnv()
	return {
		Color3 = rb.Color3, Vector3 = rb.Vector3, table = table, ipairs = ipairs, pairs = pairs,
		tonumber = tonumber, tostring = tostring, math = math, string = string, type = type,
	}
end
local Catalog = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau"), { environment = catalogEnv() })()

-- The real CosmeticTemplateBuilder, run against a built world's ServerStorage.
local function buildTemplates(world)
	local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
	local storage = place:GetService("ServerStorage")
	local factory = luau.load(fs.readFile("src/common/ServerScriptService/Economy/Cosmetics/NewAurasFactory.luau"), {
		environment = setmetatable({ Instance = rb.Instance, Vector3 = rb.Vector3, Vector2 = rb.Vector2, CFrame = rb.CFrame,
			Color3 = rb.Color3, ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
			NumberSequence = rb.NumberSequence, NumberSequenceKeypoint = rb.NumberSequenceKeypoint, NumberRange = rb.NumberRange,
			Enum = rb.Enum, game = { GetService = function() error("no service") end } }, { __index = _G }),
	})()
	local modules = { CosmeticCatalog = Catalog, NewAurasFactory = factory }
	local function finder()
		return { WaitForChild = function(_, name)
			return "module:" .. name
		end }
	end
	local tags = {}
	local services = {
		ReplicatedStorage = { WaitForChild = function() return finder() end },
		ServerStorage = storage,
		CollectionService = { AddTag = function(_, instance, tag) tags[instance] = tag end },
	}
	local source = fs.readFile("src/common/ServerScriptService/Economy/Cosmetics/CosmeticTemplateBuilder.luau")
	source = string.gsub(source, 'ServerStorage:WaitForChild%("RawCosmeticPack", 30%)', 'ServerStorage:FindFirstChild("RawCosmeticPack")')
	local warnings = {}
	local env = setmetatable({
		game = { GetService = function(_, name) return services[name] end },
		script = { Parent = finder() },
		require = function(key) return modules[string.sub(key, 8)] end,
		Instance = rb.Instance, Vector3 = rb.Vector3, Vector2 = rb.Vector2, CFrame = rb.CFrame, Color3 = rb.Color3, Enum = rb.Enum,
		ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint, NumberSequence = rb.NumberSequence,
		NumberSequenceKeypoint = rb.NumberSequenceKeypoint, NumberRange = rb.NumberRange,
		print = function() end,
		warn = function(message) table.insert(warnings, message) end,
	}, { __index = _G })
	local Builder = luau.load(source, { environment = env })()
	local root = Builder.Build()
	return root, warnings, tags
end

do
	for _, id in { "Aura08", "Aura09", "Aura10", "Aura11", "Aura12", "Aura13", "Aura14", "Aura15", "Aura16", "Aura17", "Aura18" } do
		local entry = Catalog.GetEntry("Aura", id)
		assert(entry and entry.ShopEnabled == true and entry.World == 3 and not entry.Hidden, id .. " is in the shop")
		assert(entry.WinsCost >= 20000000, id .. " costs Wins like a World 3 item")
	end
	local aura67 = Catalog.GetEntry("Aura", "Aura67")
	assert(aura67 and aura67.ShopEnabled ~= true and aura67.Exclusive == "SpinWheel", "Aura 67 is a Spin Wheel exclusive, never sold")
	assert(aura67.IconImage == "rbxassetid://127283711015110", "...with the user's 67 picture")
	assert(Catalog.IsOwnable("Aura", "Aura67") and not Catalog.GetEntry("Aura", "Aura67").ShopEnabled, "It can be equipped once won")
	local ownable = {}
	for _, entry in Catalog.GetSortedOwnableEntries("Aura") do
		ownable[entry.Id] = true
	end
	assert(ownable.Aura67 and ownable.Aura18 and ownable.Aura01, "The Backpack lists shop auras and the exclusive")
	assert(Catalog.ExperimentalAuras == nil, "No hidden aura list is left behind")

	local root, warnings = buildTemplates("World3")
	assert(#warnings == 0, "The builder raised no warning: " .. tostring(warnings[1]))
	local auras = root:FindFirstChild("Auras")
	for _, entry in Catalog.Auras do
		local template = auras:FindFirstChild(entry.Id)
		assert(template, "Template built for " .. entry.Id)
		assert(template:FindFirstChild("EffectHolder") and template:FindFirstChild("LocalOffset"), entry.Id .. " has its holder and offset")
		assert(template:FindFirstChildWhichIsA("ParticleEmitter", true), entry.Id .. " has particles")
		for _, d in template:GetDescendants() do
			assert(not (d:IsA("WeldConstraint") and (d.Part0 == nil or d.Part1 == nil)), entry.Id .. " has no empty weld")
			assert(not d:IsA("LuaSourceContainer") and not d:IsA("Humanoid") and not d:IsA("Clothing") and not d:IsA("Accessory") and not d:IsA("BodyColors"),
				entry.Id .. " carries only effects, not the preview rig (" .. d:GetFullName() .. ")")
			if d:IsA("Beam") or d:IsA("Trail") then
				local a0, a1 = d.Attachment0, d.Attachment1
				assert(a0 and a0:IsDescendantOf(template), entry.Id .. ": " .. d.Name .. " reaches its own attachment 0")
				if d:IsA("Beam") then
					assert(a1 and a1:IsDescendantOf(template), entry.Id .. ": " .. d.Name .. " reaches its own attachment 1")
				end
			end
			if d:IsA("BasePart") then
				local placed = false
				local current = d
				while current and current ~= template do
					if current:GetAttribute("DynamicFloorVFX") or current:GetAttribute("DynamicShidouBall") or current:GetAttribute("DynamicOrbit") then
						placed = true
					end
					current = current.Parent
				end
				if placed then
					assert(d.Anchored == true and d.CanCollide == false, entry.Id .. ": the client-placed " .. d.Name .. " is anchored, so it cannot fall")
				else
					-- A holder, or a part welded to another part of the same template.
					local weld = d:FindFirstChild("HolderWeld")
					local holderPart = template:FindFirstChild("EffectHolder")
					local welded = weld ~= nil and weld:IsA("Weld") and weld.Part0 == holderPart and weld.Part1 == d
					if welded then
						local drawn = holderPart.CFrame:ToObjectSpace(d.CFrame)
						assert((weld.C0.Position - drawn.Position).Magnitude < 1e-3, entry.Id .. ": " .. d.Name .. " stays where it was drawn")
					end
					assert(d.Name == "EffectHolder" or d:GetAttribute("HolderPart") == true or welded, entry.Id .. ": no loose part (" .. d:GetFullName() .. ")")
				end
			end
		end
	end
	local aura67Template = auras:FindFirstChild("Aura67")
	local holder = aura67Template.EffectHolder
	assert(math.abs(holder.Size.Y - 7.0566826) < 1e-3 and math.abs(holder.Size.X - 3.3113039) < 1e-3, "Aura 67 keeps the size its particles fill")
	local count = 0
	for _, d in holder:GetChildren() do
		if d:IsA("ParticleEmitter") then
			count += 1
		end
	end
	assert(count == 11, "Aura 67 keeps all 11 emitters")
	local demon = auras:FindFirstChild("Aura16")
	assert(demon:GetAttribute("HasFloorVFX") == true and demon:FindFirstChild("FloorVFX"):GetAttribute("DynamicFloorVFX") == true, "Demon Aura's floor effect is placed by the clients")
	assert(demon:FindFirstChild("TorsoHolder") and demon:FindFirstChild("HeadHolder"), "Demon Aura's effects ride the torso and head")
	assert(demon.TorsoHolder.Size == rb.Vector3.new(2, 2, 1), "A limb holder is the limb's size")
	local shidou = auras:FindFirstChild("Aura14")
	assert(shidou:GetAttribute("HasShidouBall") == true and shidou:FindFirstChild("ShidouBall"), "Shidou keeps its floating ball")
	assert(auras:FindFirstChild("Aura18"):FindFirstChild("HumanoidRootPartHolder"), "Musical's notes ride the root")
	assert(auras:FindFirstChild("Aura17"):FindFirstChild("LeftLegHolder"), "Lightning runs down the legs")

	-- Galaxy, Water and Cursed come from their original models, structure and all.
	local storageAuras = rb.deserializePlace(fs.readFile(PlaceFiles.World3)):GetService("ServerStorage").AuthoredAuras
	local galaxy = auras:FindFirstChild("Aura09")
	assert(string.find(galaxy:GetAttribute("AuthoredSource"), "GalacticOpenSource", 1, true), "Galaxy is built from its original model")
	for _, limb in { "TorsoHolder", "LeftArmHolder", "RightArmHolder", "LeftLegHolder", "RightLegHolder" } do
		local holder = galaxy:FindFirstChild(limb)
		assert(holder and #holder:GetDescendants() >= 30, "Galaxy's " .. limb .. " keeps its own effects (" .. (holder and #holder:GetDescendants() or 0) .. ")")
	end
	local auraPart = galaxy:FindFirstChild("AuraPart")
	assert(auraPart and auraPart:GetAttribute("TargetLimb") == "HumanoidRootPart" and auraPart:GetAttribute("HolderPart") == true, "Galaxy's aura volume rides the root")
	assert((auraPart:GetAttribute("LimbOffset").Position - rb.Vector3.new(0, -0.2, 0)).Magnitude < 0.01, "...where it sat on the showcase rig")
	assert(math.abs(auraPart.Size.Y - 5.4) < 1e-3, "...at its own size")
	local orbs = 0
	for _, child in galaxy:GetChildren() do
		if child:GetAttribute("DynamicOrbit") then
			orbs += 1
			assert(math.abs(child:GetAttribute("OrbitRadius") - 4) < 0.01 and child.Anchored, "Galaxy's orbs circle 4 studs out, placed by the clients")
		end
	end
	assert(orbs == 2 and galaxy:GetAttribute("HasOrbit") == true, "Both orbs circle the wearer")

	local water = auras:FindFirstChild("Aura08")
	assert(string.find(water:GetAttribute("AuthoredSource"), "AquaticOpenSource", 1, true), "Water is built from its original model")
	assert(water:FindFirstChild("TorsoHolder") and water:FindFirstChild("LeftLegHolder") and water:FindFirstChild("HumanoidRootPartHolder"), "Water flows along every limb")
	local volume = nil
	for _, child in water:GetChildren() do
		if child:GetAttribute("LimbOffset") then
			volume = child
		end
	end
	assert(volume and (volume:GetAttribute("LimbOffset").Position - rb.Vector3.new(0, -0.5, 0)).Magnitude < 0.01, "...and its aura volume rides the root")

	for id, name in { Aura10 = "Cursed Energy Green", Aura11 = "Cursed Energy Red", Aura12 = "Cursed Energy Purple", Aura13 = "Cursed Energy Normal" } do
		local cursed = auras:FindFirstChild(id)
		local original = storageAuras:FindFirstChild(name, true)
		assert(original and string.find(cursed:GetAttribute("AuthoredSource"), name, 1, true), id .. " is built from " .. name)
		local holder = cursed.EffectHolder
		assert(holder.Size == original.Size, id .. ": the original part is the holder, at its size")
		local emitters, beziers, originalEmitters, forgeAttributes = 0, 0, 0, 0
		for _, d in holder:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				emitters += 1
				if d:GetAttribute("EmitCount") ~= nil then
					forgeAttributes += 1
				end
			end
			if d:HasTag("BezierParticle") and d:HasTag("ConstantVFX") then
				beziers += 1
				assert(d:GetAttribute("Rate") ~= nil and d:GetAttribute("Duration") ~= nil, id .. ": its Bezier streams keep their Forge settings")
			end
		end
		for _, d in original:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				originalEmitters += 1
			end
		end
		assert(emitters == originalEmitters and emitters >= 60, id .. ": every one of the original's emitters (" .. emitters .. "/" .. originalEmitters .. ")")
		assert(beziers == 2, id .. ": both Bezier energy streams, tagged for Forge VFX")
		assert(forgeAttributes > 0, id .. ": emitters keep their Forge attributes")
		assert(holder:FindFirstChild("inwardbezier") and holder:FindFirstChild("inwardbezier"):FindFirstChild("HolderWeld"), id .. ": the nested parts stay, welded where they were drawn")
	end

	local service = fs.readFile("src/common/ServerScriptService/Economy/Cosmetics/CosmeticService.luau")
	has(service, "elseif isClientPlaced(descendant) then\n\t\t\t\tdescendant.Anchored = true", "Equipping keeps the client-placed pieces anchored")
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/AuraSpecialEffectsClient.client.luau")
	assert(not string.find(client, "if true then return end", 1, true), "The floor and ball client runs again")
	has(client, "require(forge).init()", "Forge VFX starts on every client (the server's own init stops early)")
	has(client, 'elseif child:GetAttribute("DynamicOrbit") and child:IsA("BasePart") then', "...and the clients turn the orbs")
	has(service, 'child.CFrame = limbPart.CFrame * (if typeof(offset) == "CFrame" then offset else CFrame.new())', "A holder rides its limb at its own offset")
	has(client, 'setmetatable({}, { __mode = "k" })', "...and forgets destroyed pieces")
	for _, shop in { "Aura", "Trail" } do
		local code = fs.readFile("src/common/ServerScriptService/Economy/" .. shop .. "ShopSystem.server.luau")
		has(code, 'Catalog.GetSortedOwnableEntries("' .. shop .. '")', shop .. " shop reports exclusives too")
		has(code, 'not Catalog.IsOwnable("' .. shop .. '", ', shop .. " shop lets an owned exclusive be equipped")
	end
	print("PASS auras: World 3's auras are in the shop and build into working templates; Aura 67 is a Spin Wheel exclusive")
end

----------------------------------------------------------------------
-- 3. World 3's trails: drawn ribbons, and Trail 67's sixes and sevens
----------------------------------------------------------------------
do
	local expected = {
		{ "Trail08", "Electric Trail", "rbxassetid://13280245934" },
		{ "Trail09", "Fire Trail", "rbxassetid://11767688250" },
		{ "Trail10", "Chain Trail", "rbxassetid://52513855" },
		{ "Trail11", "Glitched Trail", "rbxassetid://107624017803706" },
		{ "Trail12", "Water Trail", "rbxassetid://124411921429725" },
		{ "Trail13", "Spatial Beam", "rbxassetid://16892366666" },
		{ "Trail14", "Pixeled Trail", "rbxassetid://14339514555" },
	}
	local root, warnings = buildTemplates("World3")
	assert(#warnings == 0, "The builder raised no warning: " .. tostring(warnings[1]))
	local trails = root:FindFirstChild("Trails")
	local previous = 0
	for _, row in expected do
		local entry = Catalog.GetEntry("Trail", row[1])
		assert(entry and entry.DisplayName == row[2] and entry.ShopEnabled == true and entry.World == 3, row[2] .. " is in the shop")
		assert(entry.WinsCost > previous and entry.WinsCost >= 20000000, row[2] .. " costs more than the one before")
		previous = entry.WinsCost
		assert(entry.CardIcon == row[3], row[2] .. "'s Backpack card shows its texture")
		local template = trails:FindFirstChild(row[1])
		assert(template and template:GetAttribute("CosmeticType") == "Trail", row[2] .. " has a template")
		local ribbons = 0
		for _, trail in template.EffectHolder:GetChildren() do
			if trail:IsA("Trail") then
				ribbons += 1
				assert(trail.Texture == row[3], row[2] .. " draws its own texture")
				assert(trail.Attachment0 and trail.Attachment0.Parent == template.EffectHolder and trail.Attachment1.Parent == template.EffectHolder, row[2] .. "'s ribbon hangs on its holder")
				local span = trail.Attachment0.CFrame.Position.Y - trail.Attachment1.CFrame.Position.Y
				assert(span >= 5, row[2] .. " runs head to feet (" .. span .. " studs)")
			end
		end
		assert(ribbons == 2, row[2] .. " has a main band and an accent")
	end

	local sixSeven = Catalog.GetEntry("Trail", "Trail15")
	assert(sixSeven and sixSeven.DisplayName == "Trail 67" and sixSeven.WinsCost > previous, "Trail 67 tops the trail shop")
	assert(sixSeven.CardIcon == "rbxassetid://127283711015110", "Trail 67's card shows the 67 picture")
	local template = trails:FindFirstChild("Trail15")
	local numbers = template.EffectHolder:FindFirstChild("Numbers")
	assert(numbers and numbers:IsA("Attachment"), "Trail 67 throws its numbers from the runner's back")
	local six, seven = numbers:FindFirstChild("Six"), numbers:FindFirstChild("Seven")
	assert(six and six:IsA("ParticleEmitter") and six.Texture == "rbxassetid://90832162759563", "...the studded 6 of Aura 67")
	assert(seven and seven:IsA("ParticleEmitter") and seven.Texture == "rbxassetid://89820489250506", "...and its 7")
	for _, emitter in { six, seven } do
		assert(emitter.LockedToPart == false, "The numbers stay behind in the world, like a trail")
		assert(emitter.Rate <= 6, "A few at a time, not a flood (phones)")
		local first = emitter.Color.Keypoints[1].Value
		assert(math.abs(first.R * 255 - 12) < 1 and math.abs(first.G * 255 - 142) < 1 and math.abs(first.B * 255 - 255) < 1, "In Aura 67's blue")
	end
	local ribbon = template.EffectHolder:FindFirstChildOfClass("Trail")
	assert(ribbon.Color.Keypoints[#ribbon.Color.Keypoints].Value == rb.Color3.fromRGB(2, 21, 76), "The band fades to Aura 67's navy")

	-- The originals still come from the pack, matched by colour.
	for index = 1, 7 do
		local id = string.format("Trail%02d", index)
		assert(trails:FindFirstChild(id) and trails:FindFirstChild(id):GetAttribute("SourceName") ~= "Ribbon", id .. " still comes from the pack")
	end

	-- The Backpack: only the original colours own the designer's cards ("Cursed Red"
	-- must not take the Red card), and everything else gets a painted copy.
	local backpack = fs.readFile("src/common/StarterGui/Backpack/BackpackScript.client.luau")
	has(backpack, "local color = if entry.World == nil and entry.Exclusive == nil then colorKeyOf(entry.DisplayName) else nil", "World 3 names never claim a designer card")
	has(backpack, 'addCatalogCards(trailFrame, "Trail")', "Trail cards are added")
	has(backpack, 'addCatalogCards(auraFrame, "Aura")', "Aura cards are added")
	has(backpack, 'local EXCLUSIVE_LABELS = { SpinWheel = "SPIN WHEEL" }', "An exclusive's card says where it is won")
	has(backpack, "MenuEvents.Request(item.exclusiveMenu)", "...and opens the Spin Wheel")
	print("PASS trails: 8 World 3 trails drawn from their textures, Trail 67 throws Aura 67's 6s and 7s, the Backpack sells them all")
end

----------------------------------------------------------------------
-- 4. The Tung Tung Sahur skin, worn over an R6 body
----------------------------------------------------------------------
local SKINS = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")

-- A resting R6 character: root 3 studs over the ground at (10, 3, 20), facing +X.
local function r6Character(rootFrame)
	local character = rb.Instance.new("Model")
	character.Name = "Runner"
	local function part(name, size, offset)
		local p = rb.Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = rootFrame * offset
		p.Transparency = if name == "HumanoidRootPart" then 1 else 0
		p.Parent = character
		return p
	end
	part("HumanoidRootPart", rb.Vector3.new(2, 2, 1), rb.CFrame.new())
	part("Torso", rb.Vector3.new(2, 2, 1), rb.CFrame.new())
	local head = part("Head", rb.Vector3.new(2, 1, 1), rb.CFrame.new(0, 1.5, 0))
	part("Left Arm", rb.Vector3.new(1, 2, 1), rb.CFrame.new(-1.5, 0, 0))
	part("Right Arm", rb.Vector3.new(1, 2, 1), rb.CFrame.new(1.5, 0, 0))
	part("Left Leg", rb.Vector3.new(1, 2, 1), rb.CFrame.new(-0.5, -2, 0))
	part("Right Leg", rb.Vector3.new(1, 2, 1), rb.CFrame.new(0.5, -2, 0))
	local face = rb.Instance.new("Decal")
	face.Name = "face"
	face.Parent = head
	local hat = rb.Instance.new("Accessory")
	local handle = rb.Instance.new("Part")
	handle.Name = "Handle"
	handle.Transparency = 0.25
	handle.Parent = hat
	hat.Parent = character
	rb.Instance.new("Humanoid").Parent = character
	local cosmetics = rb.Instance.new("Folder")
	cosmetics.Name = "SpeedsterCosmetics"
	local holder = rb.Instance.new("Part")
	holder.Name = "EffectHolder"
	holder.Transparency = 1
	holder.Parent = cosmetics
	cosmetics.Parent = character
	return character
end

do
	local suits = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau"), {
		environment = setmetatable({ game = { PlaceId = 0 } }, { __index = _G }),
	})()
	local tung = suits.Get("TungTungSuit")
	assert(tung and tung.SpecialApplyMode == "ModelMorph" and tung.SourceModelName == "TungTung" and tung.Exclusive == "SpinWheel", "Tung Tung is a Spin Wheel exclusive skin worn from the rig")
	assert(tung.PreviewAssetId == 114124284706337, "Its picture is the rig's own thumbnail")
	for _, entry in suits.Ordered do
		assert(entry.Id ~= "TungTungSuit", "It is not on the evolution ladder")
	end
	local config = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
	has(config, "TungTungSuit = 200,", "It carries a suit multiplier between the evolutions and the paid limited")

	local place = rb.deserializePlace(fs.readFile(PlaceFiles.World3))
	local storage = place:GetService("ServerStorage")
	local chunk = between(SKINS, "-- ModelMorph: a whole rig worn over the player's R6 body.", "local function applySkinById(player, skinId)")
	chunk = string.gsub(chunk, "character%.DescendantAdded:Connect%(", "watch(character, ")
	chunk = string.gsub(chunk, "character%.AncestryChanged:Connect%(", "onAncestry(character, ")
	local watched = {}
	local left = {}
	local suitState = {}
	local env = setmetatable({
		ServerStorage = storage,
		Instance = rb.Instance, CFrame = rb.CFrame, Vector3 = rb.Vector3,
		forceSuitState = function(player, id) suitState[player] = id end,
		watch = function(character, callback)
			watched[character] = callback
			return { Disconnect = function() watched[character] = nil end }
		end,
		onAncestry = function(character, callback)
			left[character] = callback
			return { Disconnect = function() left[character] = nil end }
		end,
		game = rb.Instance.new("DataModel"),
	}, { __index = _G })
	local build, apply, clear = luau.load(chunk .. "\nreturn buildMorphPieces, applyModelMorphSuit, clearModelMorph", { environment = env })()

	local pieces = assert(build(tung), "The rig becomes morph pieces")
	assert(#pieces == 15, "All 15 body meshes (" .. #pieces .. ")")
	local source = storage.TungTung
	for _, piece in pieces do
		assert(piece:IsA("MeshPart") and piece:FindFirstChildOfClass("SurfaceAppearance"), piece.Name .. " keeps its mesh and texture")
		for _, child in piece:GetChildren() do
			assert(child:IsA("SurfaceAppearance") or child:IsA("Decal"), piece.Name .. " carries no joint, cage or script (" .. child.ClassName .. ")")
		end
		local ratio = piece.Size.Y / source:FindFirstChild(piece.Name).Size.Y
		assert(ratio > 0.8 and ratio < 0.86, piece.Name .. " is scaled to an R6 height (" .. ratio .. ")")
	end

	local rootFrame = rb.CFrame.new(10, 3, 20) * rb.CFrame.Angles(0, math.rad(90), 0)
	local character = r6Character(rootFrame)
	local player = {}
	player.Character = character
	assert(apply(player, tung) == true, "The skin goes on")
	assert(suitState[player] == "TungTungSuit", "The suit's state is set (stamina, equipped skin)")
	local folder = character:FindFirstChild("SkinMorph")
	assert(folder and #folder:GetChildren() == 15, "The rig's 15 meshes ride the character")
	local lowest, highest = math.huge, -math.huge
	for _, piece in folder:GetChildren() do
		local weld = piece:FindFirstChild("MorphWeld")
		local limb = character:FindFirstChild(piece:GetAttribute("MorphLimb"))
		assert(weld and weld:IsA("Weld") and weld.Part0 == limb and weld.Part1 == piece, piece.Name .. " is welded to its R6 limb")
		local expected = limb.CFrame * weld.C0
		assert((piece.CFrame.Position - expected.Position).Magnitude < 1e-3, piece.Name .. " sits where its weld holds it")
		assert(piece.CanCollide == false and piece.Massless == true and piece.Anchored == false, piece.Name .. " does not change how the runner moves")
		local up = piece.CFrame:VectorToObjectSpace(rb.Vector3.new(0, 1, 0))
		local half = 0.5 * (math.abs(up.X) * piece.Size.X + math.abs(up.Y) * piece.Size.Y + math.abs(up.Z) * piece.Size.Z)
		lowest = math.min(lowest, piece.CFrame.Position.Y - half)
		highest = math.max(highest, piece.CFrame.Position.Y + half)
	end
	assert(math.abs(lowest - 0) < 0.05, "Its feet stand on the runner's ground (" .. lowest .. ")")
	assert(highest > 4.5 and highest < 5.6, "About as tall as an R6 body (" .. highest .. ")")
	-- The face is on the front: the head mesh's front is where the runner looks.
	local head = folder:FindFirstChild("Head")
	assert(head.CFrame.LookVector:Dot(rootFrame.LookVector) > 0.99, "It faces where the runner faces")

	for _, name in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		assert(character[name].Transparency == 1, "The R6 " .. name .. " is hidden under it")
	end
	assert(character.Head.face.Transparency == 1, "...and the R6 face")
	assert(character.Accessory.Handle.Transparency == 1, "...and the hats")
	assert(character.HumanoidRootPart:GetAttribute("SkinMorphHiddenTransparency") == nil, "The root is left alone")
	assert(character.SpeedsterCosmetics.EffectHolder:GetAttribute("SkinMorphHiddenTransparency") == nil, "Auras and trails are left alone")

	-- A hat put on later is hidden too.
	local late = rb.Instance.new("Accessory")
	local lateHandle = rb.Instance.new("Part")
	lateHandle.Name = "Handle"
	lateHandle.Parent = late
	late.Parent = character
	assert(watched[character], "The skin watches for new clothing")
	watched[character](lateHandle)
	assert(lateHandle.Transparency == 1, "A hat put on while wearing it stays hidden")

	-- Taking it off gives the body back exactly as it was.
	clear(character)
	assert(character:FindFirstChild("SkinMorph") == nil, "The rig comes off")
	assert(character.Torso.Transparency == 0 and character.Head.face.Transparency == 0, "The body shows again")
	assert(character.Accessory.Handle.Transparency == 0.25, "Each thing gets its own transparency back")
	assert(watched[character] == nil and left[character] == nil, "The watchers are disconnected")

	-- A character that leaves the world (respawn, leaving) lets go of its watchers.
	local again = r6Character(rootFrame)
	player.Character = again
	assert(apply(player, tung) == true and watched[again] and left[again], "Worn again, watched again")
	left[again]()
	assert(watched[again] == nil and left[again] == nil, "Out of the world, the watchers are gone")

	has(SKINS, 'if entry and entry.SpecialApplyMode ~= "ModelMorph" and player.Character then\n\t\tclearModelMorph(player.Character)', "Any other skin takes the rig off first")
	has(SKINS, "Exclusive = entry.Exclusive,", "The Index learns where an exclusive is won")
	local index = fs.readFile("src/common/StarterGui/Index/IndexScript.client.luau")
	has(index, 'SpinWheel = { Label = "SPIN WHEEL", Menu = "SpinWheel"', "The Index shows it locked with SPIN WHEEL")
	has(index, "elseif wonAt.Menu then\n\t\t\t\t\t\tMenuEvents.Request(wonAt.Menu)", "...and its button opens the Spin Wheel")
	print("PASS skin: Tung Tung Sahur fits an R6 body (feet on the ground, facing forward), hides the body under it, and comes off cleanly")
end

----------------------------------------------------------------------
-- 5. The Spin Wheel's exclusives: Aura 67 and Tung Tung Sahur
----------------------------------------------------------------------
do
	local Wheel = require("../src/common/ReplicatedStorage/Shared/SpinWheelCatalog")
	local SERVICE = fs.readFile("src/common/ServerScriptService/Economy/SpinWheelService.server.luau")
	local byId = {}
	for index, segment in Wheel.Segments do
		byId[segment.Id] = index
	end
	assert(#Wheel.Segments == 6 and Wheel.TotalWeight() == 100, "Six slices for the six-slice art, odds adding to 100%")
	local aura, tung = Wheel.Segments[byId.Aura67], Wheel.Segments[byId.TungTung]
	assert(aura and aura.Kind == "Exclusive" and aura.Cosmetic == "Aura" and aura.CosmeticId == "Aura67", "Aura 67 is on the wheel")
	assert(Wheel.IconImages[aura.Icon] == "rbxassetid://127283711015110", "...with the user's 67 picture")
	assert(tung and tung.Kind == "Exclusive" and tung.Cosmetic == "Skin" and tung.CosmeticId == "TungTungSuit", "Tung Tung Sahur is on the wheel")
	assert(Wheel.IconImages[tung.Icon] == "rbxthumb://type=Asset&id=114124284706337&w=150&h=150", "...with the rig's own thumbnail")
	assert(aura.Weight == 3.5 and tung.Weight == 2.5 and Wheel.OddsText(byId.Aura67) == "3.5%" and Wheel.OddsText(byId.TungTung) == "2.5%", "Their odds are shown: 3.5% and 2.5%")
	local common, potion, big = 0, 0, 0
	for _, segment in Wheel.Segments do
		if segment.Kind == "Wins" and segment.Tier == "Large" then
			big += segment.Weight
		elseif segment.Kind == "Wins" or segment.Kind == "Speed" then
			common += segment.Weight
		elseif segment.Kind == "PotionSpeed" or segment.Kind == "PotionWins" then
			potion += segment.Weight
		end
	end
	assert(common == 50 and potion == 30 and big == 14, "50% common Wins and Speed, 30% potion, 14% big Wins")
	assert(Wheel.ShortLabel(byId.Aura67, { Level = 1, Speed = 0 }) == "AURA 67" and Wheel.ShortLabel(byId.TungTung, { Level = 1, Speed = 0 }) == "TUNG TUNG", "The slices name their prize")

	-- The server's real reward code, on a few profiles.
	local chunk = between(SERVICE, "local function pickRareCosmetic(profile: any)", "local function commit(handle: any, request: any)")
	local rewardFor = luau.load(chunk .. "\nreturn rewardFor", {
		environment = setmetatable({
			SpinWheelCatalog = Wheel,
			random = { NextInteger = function(_, low) return low end },
			context = function() return { Level = 100, Speed = 1e6 } end,
		}, { __index = _G }),
	})()
	local fresh = { OwnedAuras = {}, OwnedTrails = {}, OwnedSkins = { "FlashSuit" } }
	local commands, title = rewardFor({}, byId.Aura67, fresh)
	assert(#commands == 1 and commands[1].kind == "GrantAura" and commands[1].auraId == "Aura67", "Landing on Aura 67 grants it")
	assert(string.find(title, "AURA 67 UNLOCKED", 1, true), "...and says so")
	commands, title = rewardFor({}, byId.TungTung, fresh)
	assert(#commands == 1 and commands[1].kind == "GrantSkin" and commands[1].skinId == "TungTungSuit", "Landing on Tung Tung grants the skin")
	assert(string.find(title, "TUNG TUNG SAHUR UNLOCKED", 1, true), "...and says so")

	local owner = { OwnedAuras = { "Aura67" }, OwnedTrails = {}, OwnedSkins = { "TungTungSuit" } }
	commands = rewardFor({}, byId.Aura67, owner)
	assert(commands[1].kind == "GrantAura" and commands[1].auraId == Wheel.RareCosmetics[1].Id, "An owner of Aura 67 gets a shop cosmetic they lack instead")
	commands = rewardFor({}, byId.TungTung, owner)
	assert(commands[1].kind ~= "GrantSkin", "Tung Tung is never granted twice")
	local everything = { OwnedAuras = { "Aura67" }, OwnedTrails = {}, OwnedSkins = { "TungTungSuit" } }
	for _, cosmetic in Wheel.RareCosmetics do
		table.insert(if cosmetic.Type == "Aura" then everything.OwnedAuras else everything.OwnedTrails, cosmetic.Id)
	end
	commands = rewardFor({}, byId.TungTung, everything)
	assert(commands[1].kind == "GrantExact" and commands[1].stat == "Wins" and commands[1].amount == Wheel.WinsAmount("Large", 100) * Wheel.RareFallbackWinsMultiplier, "Owning it all pays big Wins")

	-- The prize is paid in the same commit that spends the spin.
	has(SERVICE, "local commands, title = rewardFor(player, index, profile)\n\ttable.insert(commands, 1, spend)", "Spend and prize are one transaction")
	print("PASS wheel: Aura 67 (3.5%) and Tung Tung Sahur (2.5%) on the wheel, granted once, in the spin's own commit")
end

----------------------------------------------------------------------
-- 6. Admins: Unlock All Cosmetics, free, on their own account
----------------------------------------------------------------------
do
	local SERVICE = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	local suits = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau"), {
		environment = setmetatable({ game = { PlaceId = 0 } }, { __index = _G }),
	})()
	local chunk = between(SERVICE, "local UNLOCK_SHOWCASE = ", "----------------------------------------------------------------------\n-- Cross-server")
	local committed, equipped, refreshed, skinGiven = nil, {}, 0, nil
	local fakeG = {
		SpeedsterCosmetics = { Equip = function(player, kind, id) equipped[kind] = id return true end },
		SpeedsterRefreshAuraShop = function() refreshed += 1 end,
		SpeedsterRefreshTrailShop = function() refreshed += 1 end,
		SpeedsterAdminGiveSkin = function(player, id) skinGiven = id return true end,
	}
	local ready = true
	local unlock = luau.load(chunk .. "\nreturn unlockAllCosmetics", {
		environment = setmetatable({
			CosmeticCatalog = Catalog,
			SuitCatalog = suits,
			_G = fakeG,
			commit = function(player, commands, reason)
				committed = { Player = player, Commands = commands, Reason = reason }
				return ready
			end,
		}, { __index = _G }),
	})()
	local admin = { Name = "GekkoH" }
	local ok, message = unlock(admin)
	assert(ok and committed and committed.Player == admin, "It commits to the admin's own profile")
	local granted = { Aura = {}, Trail = {}, Skin = {} }
	local equips = {}
	for _, command in committed.Commands do
		if command.kind == "GrantAura" then
			granted.Aura[command.auraId] = true
		elseif command.kind == "GrantTrail" then
			granted.Trail[command.trailId] = true
		elseif command.kind == "GrantSkin" then
			granted.Skin[command.skinId] = true
		elseif command.kind == "EquipAura" or command.kind == "EquipTrail" then
			equips[command.kind] = command.auraId or command.trailId
		else
			error("Unexpected command " .. tostring(command.kind))
		end
	end
	for _, entry in Catalog.Auras do
		assert(granted.Aura[entry.Id], "Grants " .. entry.Id)
	end
	for _, entry in Catalog.Trails do
		assert(granted.Trail[entry.Id], "Grants " .. entry.Id)
	end
	assert(granted.Skin.TungTungSuit and granted.Skin.FlashSuit and granted.Skin.SuperSaiyanSonicSuit, "Grants every evolution skin and Tung Tung")
	assert(not granted.Skin.DarkZonicSuit, "The paid limited keeps its own stock")
	assert(equips.EquipAura == "Aura67" and equips.EquipTrail == "Trail15", "Aura 67 and Trail 67 are saved as equipped")
	assert(equipped.Aura == "Aura67" and equipped.Trail == "Trail15", "...and put on the character")
	assert(refreshed == 2, "Both shops refresh their EQUIP labels")
	assert(skinGiven == "TungTungSuit", "Tung Tung Sahur is put on")
	assert(granted.Skin.SupermanSuit and granted.Skin.ATrainSuit and granted.Skin.ShadowSuit and granted.Skin.SilverSurferSuit, "...and the 2026-09-18 skins: Superman, A-Train, Shadow and the Silver Surfer")
	assert(string.find(message, "Unlocked 19 auras, 15 trails and 17 skins", 1, true), "The toast counts it: " .. message)
	ready = false
	local failed, why = unlock(admin)
	assert(failed == false and string.find(why, "not ready", 1, true), "Nothing is claimed when the profile is not ready")

	has(SERVICE, 'elseif action == "UnlockCosmetics" then\n\t\t-- Only ever the admin\'s own account.\n\t\tlocal ok, message = unlockAllCosmetics(admin)', "The request only ever unlocks for the admin who sent it")
	local handlerStart = string.find(SERVICE, "Panel.OnServerEvent:Connect(function(admin: Player, payload: any)", 1, true)
	local gate = string.find(SERVICE, "if not isAllowed(admin) then", handlerStart, true)
	local unlockAt = string.find(SERVICE, 'action == "UnlockCosmetics"', handlerStart, true)
	assert(gate and unlockAt and gate < unlockAt, "...after the admin check")
	local skins = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
	has(skins, "_G.SpeedsterAdminGiveSkin = function(player, skinId)", "SkinSystem gives and applies a skin for the server")
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	has(controller, '"✨ Unlock All Skins, Auras & Trails"', "The Moderation tab has the button")
	has(controller, 'send({ action = "UnlockCosmetics" })', "...which asks the server")
	print("PASS admin: Unlock All Cosmetics grants every aura, trail and skin to the admin, and puts on Aura 67, Trail 67 and Tung Tung")
end

----------------------------------------------------------------------
-- Robux prices (2026-09-18 pre-launch review)
----------------------------------------------------------------------
do
	local PRICES = {
		Aura10 = 199, Aura11 = 249, Aura12 = 299, Aura13 = 349, Aura08 = 449, Aura09 = 599,
		Aura15 = 699, Aura14 = 799, Aura16 = 999, Aura17 = 1299, Aura18 = 1999,
		Trail08 = 199, Trail09 = 249, Trail10 = 299, Trail11 = 349, Trail12 = 449,
		Trail13 = 599, Trail14 = 799, Trail15 = 1199,
	}
	local SALE_PRICES = {
		Aura10 = 159, Aura11 = 199, Aura12 = 239, Aura13 = 279, Aura08 = 359, Aura09 = 479,
		Aura15 = 559, Aura14 = 639, Aura16 = 799, Aura17 = 800, Aura18 = 850,
		Trail08 = 60, Trail09 = 119, Trail10 = 139, Trail11 = 177, Trail12 = 200,
		Trail13 = 219, Trail14 = 278, Trail15 = 399,
	}
	for cosmeticType, list in { Aura = Catalog.Auras, Trail = Catalog.Trails } do
		local previous = 0
		for _, entry in Catalog.GetSortedShopEntries(cosmeticType) do
			if entry.World == 3 then
				local expectedPrice = SALE_PRICES[entry.Id] or PRICES[entry.Id]
				assert(entry.RobuxPrice == expectedPrice, entry.DisplayName .. " costs " .. tostring(expectedPrice) .. " R$ (" .. tostring(entry.RobuxPrice) .. ")")
				if entry.OriginalRobuxPrice then
					assert(entry.OriginalRobuxPrice == PRICES[entry.Id], entry.DisplayName .. " original price is " .. tostring(PRICES[entry.Id]) .. " R$")
				end
				assert(entry.RobuxPrice > previous, entry.DisplayName .. ": each step up the ladder costs more")
				assert(entry.RobuxPurchaseType == "DeveloperProduct", entry.DisplayName .. " is a developer product")
				previous = entry.RobuxPrice
			end
		end
		for _, entry in list do
			if entry.Exclusive ~= nil then
				assert(entry.RobuxPrice == nil and entry.RobuxPurchaseId == nil, entry.DisplayName .. " has no Robux price (a Spin Wheel exclusive)")
			end
		end
	end
	assert(Catalog.GetEntry("Aura", "Aura67").RobuxPrice == nil, "Aura 67 stays a Spin Wheel exclusive")
	local backpack = fs.readFile("src/common/StarterGui/Backpack/BackpackScript.client.luau")
	has(backpack, 'local robuxSoon = not hasRobux and entry.Exclusive == nil and (tonumber(entry.RobuxPrice) or 0) > 0', "A price without its product yet still shows")
	has(backpack, 'item.robuxLabel.Text = "Soon!"', "...and says Soon! when pressed")
	has(backpack, 'item.robuxButton.Visible = item.robuxShown ~= false', "Items with no Robux price never show an empty Robux button")
	local purchases = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	has(purchases, 'Kind = "CosmeticUnlock"', "Once its id is set, the server grants the item")
	print("PASS Robux prices: World 3's 11 auras (199-1,999 R$) and 8 trails (199-1,199 R$), Aura 67 wheel-only; prices show before the products exist")
end
