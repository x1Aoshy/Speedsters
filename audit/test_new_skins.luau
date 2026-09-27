-- test_new_skins.luau
-- The endgame skins of 2026-09-18: Superman, A-Train, Shadow and the Silver Surfer.
--   1. The catalog: Superman (L100, 8 rebirths) and A-Train (L140, 12) worn from their rigs,
--      Shadow (L180, 15) from the catalog, all on the evolution ladder in order, the same in
--      every world; the Silver Surfer, World 3's mythic exclusive, with its '07 set and board;
--      each with a suit multiplier and stamina between its neighbours.
--   2. The rigs: captured from the team's Studio models into every place, untouched in look
--      (clothes, accessories, face, exact Body Colors), with no script.
--   3. RigOutfit: SkinSystem's real code dresses an R6 character from a rig (the avatar's own
--      look off, the rig's on, its face and skin tone exact) and takes it all off again.
--   4. The Silver Surfer's board and stance: the board lies flat and along the ride, under
--      the feet; the stance puts the feet apart along the board, the body side-on, the head
--      forward. The Index and the Evolve panel draw rig skins; finishing World 3 unlocks it.
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
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-4)
end
local function xml(instance)
	return rb.serializeModel({ instance:Clone() }, true)
end
-- A decal's texture id (Lune cannot read Content back; the XML has it).
local function textureOf(decal)
	return string.match(xml(decal), "rbxassetid://(%d+)") or string.match(xml(decal), "id=(%d+)")
end

local SKINS = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
local CONFIG = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local function loadCatalog(placeId)
	return luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau"), {
		environment = setmetatable({ game = { PlaceId = placeId } }, { __index = _G }),
	})()
end

----------------------------------------------------------------------
-- 1. The catalog
----------------------------------------------------------------------
do
	local suits = loadCatalog(0)
	local order = {}
	for index, entry in suits.Ordered do
		order[entry.Id] = index
	end
	local superman, atrain, shadow = suits.Get("SupermanSuit"), suits.Get("ATrainSuit"), suits.Get("ShadowSuit")
	assert(superman and superman.RequiredLevel == 100 and superman.RequiredRebirths == 8, "Superman: Level 100, 8 rebirths")
	assert(atrain and atrain.RequiredLevel == 115 and atrain.RequiredRebirths == 10, "A-Train: Level 115, 10 rebirths")
	assert(shadow and shadow.RequiredLevel == 180 and shadow.RequiredRebirths == 15, "Shadow: Level 180, 15 rebirths")
	assert(order.SupermanSuit == order.MobiusWallyWestSuit + 1 and order.BlackFlashSuit == order.SupermanSuit + 1, "Superman evolves between Mobius Wally West and Black Flash")
	assert(order.ATrainSuit == order.BlackFlashSuit + 1 and order.SonicSuit == order.ATrainSuit + 1, "A-Train evolves between Black Flash and Sonic")
	assert(order.SuperSonicSuit == order.SonicSuit + 1, "Super Sonic evolves directly after Sonic")
	assert(order.ShadowSuit == #suits.Ordered, "Shadow is the top of the ladder")
	for index = 2, #suits.Ordered do
		local previous, entry = suits.Ordered[index - 1], suits.Ordered[index]
		assert(entry.RequiredLevel >= previous.RequiredLevel and entry.RequiredRebirths >= previous.RequiredRebirths,
			entry.Id .. " asks no less than " .. previous.Id)
	end
	for _, entry in { superman, atrain } do
		assert(entry.SpecialApplyMode == "RigOutfit" and entry.PreviewRig == entry.SourceModelName, entry.Id .. " is worn from its rig and pictured by it")
	end
	assert(superman.SourceModelName == "Superman" and atrain.SourceModelName == "ATrain", "...the Superman and ATrain rigs")
	assert(shadow.HairId == 140470689397913 and shadow.ShirtId == 17640070614 and shadow.PantsId == 124377132418733, "Shadow's head (a hair accessory), shirt and pants")
	assert(shadow.PreviewAssetId == 140470689397913, "Shadow's picture is his head")

	-- The same in World 2 (the old +2-per-suit restack after Wally West is gone).
	local world2 = loadCatalog(96501592055150)
	for index, entry in suits.Ordered do
		local other = world2.Ordered[index]
		assert(other.Id == entry.Id and other.RequiredLevel == entry.RequiredLevel and other.RequiredRebirths == entry.RequiredRebirths,
			entry.Id .. " asks the same in World 2")
	end
	assert(world2.Get("MobiusWallyWestSuit").RequiredRebirths == 7 and world2.Get("BlackFlashSuit").RequiredRebirths == 9, "World 2's old suits keep the rebirths they had")

	local surfer = suits.Get("SilverSurferSuit")
	assert(surfer and surfer.Exclusive == "World3" and surfer.Rarity == "Mythic", "The Silver Surfer is World 3's mythic exclusive")
	assert(order.SilverSurferSuit == nil, "...never on the evolution ladder")
	assert(surfer.ShirtId == 125551170573176 and surfer.PantsId == 134606364864304, "Its '07 upper and lower")
	local pieces = {}
	for _, accessory in surfer.Accessories do
		pieces[accessory.Id] = accessory.Field
	end
	assert(pieces[121883186226008] == "HatAccessory" and pieces[116050620391341] == "FrontAccessory" and pieces[135898206122665] == "WaistAccessory"
		and pieces[133557750004146] == "ShoulderAccessory" and pieces[84178960816487] == "ShoulderAccessory", "Its head, torso, waist and both shoulders, each in its field")
	assert(surfer.Surfboard.AssetId == 93465249025940 and surfer.Surfboard.FallbackAssetId == 113577354579185, "Its board: the waist board, else the back board")
	assert(type(surfer.SkinColorRGB) == "table" and surfer.SkinColorRGB[1] > 180, "A silver body")

	-- Suit multipliers and stamina, between the neighbours on the ladder.
	local function block(opening)
		local start = assert(string.find(CONFIG, opening, 1, true), opening)
		local body = string.match(CONFIG, "(%b{})", start)
		local values = {}
		for id, value in string.gmatch(body, "(%w+) = (%d+)") do
			values[id] = tonumber(value)
		end
		return values
	end
	local world2Multipliers = block("if Config.IsWorld2Place then\n\tConfig.SuitSpeedGainMultipliers = ")
	local multipliers = block("else\n\tConfig.SuitSpeedGainMultipliers = ")
	local stamina = block("Config.SuitStaminaMax = ")
	for _, table_ in { multipliers, world2Multipliers, stamina } do
		assert(table_.MobiusWallyWestSuit < table_.SupermanSuit and table_.SupermanSuit < table_.BlackFlashSuit, "Superman sits between Mobius and Black Flash")
		assert(table_.BlackFlashSuit < table_.ATrainSuit and table_.ATrainSuit < table_.SonicSuit and table_.SonicSuit < table_.SuperSonicSuit, "A-Train sits before Sonic, Sonic before Super Sonic")
		assert(table_.ShadowSuit > table_.SuperSaiyanSonicSuit, "Shadow tops the ladder")
		assert(table_.SilverSurferSuit >= table_.ShadowSuit, "The mythic is at least the top of the ladder")
	end
	assert(multipliers.SilverSurferSuit > multipliers.TungTungSuit and multipliers.SilverSurferSuit < multipliers.DarkZonicSuit, "The Silver Surfer is above Tung Tung and below the paid limited")
	for _, id in { "SupermanSuit", "ATrainSuit", "ShadowSuit", "SilverSurferSuit" } do
		assert(suits.Get(id).Stamina == stamina[id], id .. ": the catalog and Config agree on its stamina")
	end
	print("PASS catalog: Superman L100/8R, A-Train L115/10R, Shadow L180/15R on the ladder in every world; the Silver Surfer a World 3 mythic with its set and board; multipliers and stamina in order")
end

----------------------------------------------------------------------
-- 2. The rigs, in every place
----------------------------------------------------------------------
local places = {}
for _, world in { "World1", "World2", "World3" } do
	places[world] = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
end
local studio = rb.deserializePlace(fs.readFile("audit/studio_saves/World1_2026-09-18_1139.rbxl"))
do
	for world, place in places do
		local folder = place:GetService("ReplicatedStorage"):FindFirstChild("SkinRigs")
		assert(folder, world .. ": ReplicatedStorage.SkinRigs")
		for name, from in { Superman = "Superman", ATrain = "V0_7H" } do
			local rig, source = folder:FindFirstChild(name), studio.Workspace:FindFirstChild(from)
			assert(rig and rig:IsA("Model") and rig:FindFirstChildOfClass("Humanoid").RigType == rb.Enum.HumanoidRigType.R6, world .. ": the " .. name .. " rig (R6)")
			for _, d in rig:GetDescendants() do
				assert(not d:IsA("LuaSourceContainer"), world .. ": " .. name .. " carries no script")
			end
			local colors, original = rig:FindFirstChildOfClass("BodyColors"), source:FindFirstChildOfClass("BodyColors")
			for _, field in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
				assert(colors[field] == original[field], world .. ": " .. name .. "'s " .. field .. " is exactly the model's")
			end
			assert(xml(rig.Head.face) == xml(source.Head.face), world .. ": " .. name .. "'s face is the model's")
			assert(rig.Shirt.ShirtTemplate == source.Shirt.ShirtTemplate and rig.Pants.PantsTemplate == source.Pants.PantsTemplate, world .. ": " .. name .. "'s clothes")
			local count, expected = 0, 0
			for _, child in rig:GetChildren() do
				if child:IsA("Accessory") then
					count += 1
					assert(source:FindFirstChild(child.Name), world .. ": " .. name .. "'s " .. child.Name)
				end
			end
			for _, child in source:GetChildren() do
				if child:IsA("Accessory") then
					expected += 1
				end
			end
			assert(count == expected, world .. ": every one of " .. name .. "'s accessories")
		end
		assert(not place.Workspace:FindFirstChild("Superman") and not place.Workspace:FindFirstChild("V0_7H"), world .. ": the models are not left standing in the map")
	end
	assert(string.find(xml(places.World1.ReplicatedStorage.SkinRigs.Superman.Head.face), "7074856", 1, true), "The Superman rig has Kent's face (the player keeps their own: RigOutfit)")
	local build = fs.readFile("audit/build_core.luau")
	has(build, "['657552dd15cc85d78cf97e5d4101862d0bd47c364b1baacafc1cf6ba159fa784']=true", "The Studio save with the two models was reviewed and reconciled")
	print("PASS rigs: Superman and A-Train in every place's ReplicatedStorage.SkinRigs, exact Body Colors, face, clothes and accessories, no script")
end

----------------------------------------------------------------------
-- 3. RigOutfit, SkinSystem's own code on an R6 character
----------------------------------------------------------------------
do
	local chunk = between(SKINS, "local function clearReverseAvatarItems(character)", "local function clearReverseDescription(desc)")
		.. between(SKINS, "local RIG_OUTFIT_TAG = ", "local function applyRigOutfitSuit(player, entry)")
		.. "\nreturn clearRigOutfit, dressFromRig, getSkinRig, isRigOutfitWorn"
	local place = places.World1
	local clearRigOutfit, dressFromRig, getSkinRig, isRigOutfitWorn = luau.load(chunk, {
		environment = setmetatable({ ReplicatedStorage = place:GetService("ReplicatedStorage"), Instance = rb.Instance }, { __index = _G }),
	})()
	local superman = assert(getSkinRig({ SourceModelName = "Superman" }), "SkinSystem finds the Superman rig")
	assert(getSkinRig({ SourceModelName = "Nobody" }) == nil, "...and no rig that is not there")

	-- A player's avatar: an R6 body in its own clothes, face and hats (A-Train's, here).
	local character = place.ReplicatedStorage.SkinRigs.ATrain:Clone()
	character.Name = "Player1"
	local ownFace = textureOf(character.Head.face)
	-- The avatar system keeps a hold of this very Body Colors: the outfit must paint it,
	-- never swap it (swapping left older skins put on afterwards in the rig's skin tone).
	local ownColors = character:FindFirstChildOfClass("BodyColors")
	local ownHead, ownLeg = ownColors.HeadColor3, ownColors.LeftLegColor3
	local humanoid = {
		AddAccessory = function(_, accessory)
			accessory.Parent = character
		end,
	}
	dressFromRig(character, humanoid, superman)
	assert(isRigOutfitWorn(character), "The outfit is on")
	local accessories = {}
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			assert(child:GetAttribute("SkinRigOutfit") == true, "Only the rig's accessories are worn: " .. child.Name)
			accessories[child.Name] = true
		end
	end
	assert(accessories.Kent and accessories.BlackZeroFloof and accessories.RedCape, "Superman's hair, Kent and cape")
	assert(not accessories.Goatee, "The avatar's own accessories are off")
	local shirts = 0
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") then
			shirts += 1
			assert(child.ShirtTemplate == superman.Shirt.ShirtTemplate, "Superman's shirt")
		end
	end
	assert(shirts == 1 and character:FindFirstChildOfClass("Pants").PantsTemplate == superman.Pants.PantsTemplate, "One shirt, and Superman's pants")
	-- 2026-09-18: the player keeps their own face, eyes, head and skin tone, as with Flash;
	-- only the rig's hair, suit, cape and accessories go on.
	local colors = character:FindFirstChildOfClass("BodyColors")
	assert(colors == ownColors and colors.HeadColor3 == ownHead and colors.LeftLegColor3 == ownLeg, "The player's own skin tone stays")
	local faces = {}
	for _, child in character.Head:GetChildren() do
		if child:IsA("Decal") then
			table.insert(faces, child)
		end
	end
	assert(#faces == 1 and textureOf(faces[1]) == ownFace and faces[1]:GetAttribute("SkinRigOutfit") ~= true, "The player's own face stays, not Kent's")
	assert(textureOf(faces[1]) ~= textureOf(superman.Head.face), "(Superman's face really is another one)")
	for _, child in character.Head:GetChildren() do
		assert(child:GetAttribute("SkinRigOutfit") ~= true, "Nothing of the rig goes on the head: " .. child.Name)
	end
	assert(not character:FindFirstChild("SkinRigSaved"), "Nothing of the player's is taken off the head")

	clearRigOutfit(character)
	for _, d in character:GetDescendants() do
		assert(d:GetAttribute("SkinRigOutfit") ~= true, "Taking it off leaves none of the rig: " .. d:GetFullName())
	end
	assert(textureOf(character.Head.face) == ownFace and ownFace == "376788359", "...and the avatar still has its own face")
	assert(character:FindFirstChildOfClass("BodyColors") == ownColors and ownColors.HeadColor3 == ownHead and ownColors.LeftLegColor3 == ownLeg,
		"...and its own skin tone, on its own Body Colors")
	assert(not isRigOutfitWorn(character), "It is off")

	has(SKINS, 'if entry and entry.SpecialApplyMode ~= "RigOutfit" and player.Character then\n\t\tclearRigOutfit(player.Character)', "Any other skin takes a rig outfit off first")
	has(SKINS, 'elseif entry.SpecialApplyMode == "RigOutfit" then\n\t\tapplied, message = applyRigOutfitSuit(player, entry)', "RigOutfit skins are applied from their rig")
	has(SKINS, "clearReverseDescription(desc)\n\t\tapplySuitColors(desc, entry, humanoid)\n\t\ttryApplyReverseDescription(humanoid, desc)", "The description reset keeps the player's own skin tone")
	assert(not string.find(SKINS, "rigColors[property]", 1, true), "The rig's skin tone is never put on")
	has(SKINS, "applySuitColors(desc, entry, humanoid)", "Catalog suits wear their own tone, or the player's own back")
	has(SKINS, "if not isAssetCached(tonumber(accessory.Id)) then\n\t\t\tapplyAssetToDescription(desc, accessory.Id, accessory.Field)", "Pieces not cached yet go through the description")
	has(SKINS, "clearRigOutfit(character)\n\tclearSurfboard(character)", "Unequipping takes the rig outfit and the board off")
	print("PASS RigOutfit: the avatar's clothes and accessories come off, the rig's hair, suit, cape and accessories go on over the player's own face and skin tone, and all of it comes off again")
end

----------------------------------------------------------------------
-- 3b. Every suit's accessories go on at once (they came late, or not at all)
----------------------------------------------------------------------
do
	local chunk = between(SKINS, "local function suitAccessories(entry)", "local function applyCatalogSuitDescription(humanoid, entry)")
		.. "\nreturn suitAccessories, wearCachedSuitAccessories"
	local cached, worn, loads = {}, {}, {}
	local suitAccessories, wearCachedSuitAccessories = luau.load(chunk, {
		environment = setmetatable({
			isAssetCached = function(id) return cached[id] == true end,
			hasCatalogAccessory = function(_, id) return worn[id] == true end,
			loadReverseAssetOntoCharacter = function(_, _, id)
				assert(cached[id], "Nothing is fetched from the web while a suit goes on: " .. tostring(id))
				table.insert(loads, id)
				worn[id] = true
				return true
			end,
		}, { __index = _G }),
	})()
	local suits = loadCatalog(0)
	local surfer = suitAccessories(suits.Get("SilverSurferSuit"))
	assert(#surfer == 5, "The Silver Surfer wears its 5 pieces")
	local kid = suitAccessories(suits.Get("KidFlashSuit"))
	assert(#kid == 2 and kid[1].Id == 120260245366958 and kid[2].Field == "HairAccessory", "Kid Flash: mask and hair")
	cached[120260245366958] = true
	wearCachedSuitAccessories({}, {}, suits.Get("KidFlashSuit"))
	assert(#loads == 1 and loads[1] == 120260245366958, "A cached mask goes on at once; the uncached hair is left to the description")
	wearCachedSuitAccessories({}, {}, suits.Get("KidFlashSuit"))
	assert(#loads == 1, "Never twice")

	has(SKINS, "for _, collection in ipairs({ SuitCatalog.Ordered, SuitCatalog.Limited or {}, SuitCatalog.Exclusive or {} }) do", "Every suit's accessories are cached when the server starts")
	has(SKINS, "wearCachedSuitAccessories(character, humanoid, entry)\n\tlocal applied = applyCatalogSuitDescription(humanoid, entry)\n\tif player.Character == character and player:GetAttribute(\"EquippedSkin\") == entry.Id then\n\t\twearCachedSuitAccessories(character, humanoid, entry)",
		"A suit's accessories go on before the description, and again after it")
	has(SKINS, "if not applied or not wearing then", "The description is reset again only when the clothes did not make it")
	print("PASS accessories: cached for every suit at start, on at once from the cache (before and after the clothes), never reset away by the retries")
end

----------------------------------------------------------------------
-- 4. The Silver Surfer's board and stance, the pictures, and the unlock
----------------------------------------------------------------------
do
	local rotationOf = luau.load(between(SKINS, "local function surfboardRotation(size)", "local function buildFallbackSurfboard()") .. "\nreturn surfboardRotation", {
		environment = setmetatable({ CFrame = rb.CFrame, Vector3 = rb.Vector3 }, { __index = _G }),
	})()
	for _, size in { rb.Vector3.new(5.6, 0.3, 1.8), rb.Vector3.new(0.3, 1.8, 5.6), rb.Vector3.new(1.8, 5.6, 0.3), rb.Vector3.new(0.4, 6, 2) } do
		local rotation, length, thickness = rotationOf(size)
		local axes = { rb.Vector3.new(size.X, 0, 0), rb.Vector3.new(0, size.Y, 0), rb.Vector3.new(0, 0, size.Z) }
		local extent = rb.Vector3.zero
		for _, axis in axes do
			local turned = rotation * axis
			extent += rb.Vector3.new(math.abs(turned.X), math.abs(turned.Y), math.abs(turned.Z))
		end
		assert(near(extent.Z, length) and near(extent.Y, thickness), ("The board %s lies along the ride (%s), flat (%s)"):format(tostring(size), tostring(extent.Z), tostring(extent.Y)))
		assert(near(rotation.XVector:Cross(rotation.YVector):Dot(rotation.ZVector), 1), "...turned, never mirrored")
	end
	has(SKINS, "humanoid.HipHeight = base + SURFBOARD_HOVER", "The body is lifted over the board")
	has(SKINS, "local lift = CFrame.new(0, -(R6_SOLES_BELOW_ROOT + template.Thickness / 2) - 0.05, 0)", "The board sits under the soles")
	has(SKINS, 'character:SetAttribute(SURFBOARD_ATTRIBUTE, true)', "Riders are marked for the stance")
	has(SKINS, "if entry.Surfboard then\n\t\t\ttask.spawn(attachSurfboard, player, entry)", "The Silver Surfer gets its board when put on")
	has(SKINS, "if entry and not entry.Surfboard and player.Character then\n\t\tclearSurfboard(player.Character)", "Any other skin takes the board off")
	local hover = tonumber(string.match(CONFIG, "Config.SurfboardHover = ([%d%.]+)"))
	assert(hover and hover - 0.3 - 0.05 > 0.3, "The fallback board (0.3 thick) floats over the floor")

	-- The stance, on the standard R6 joints.
	local Stance = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SurfboardStance.luau"), {
		environment = setmetatable({ CFrame = rb.CFrame }, { __index = _G }),
	})()
	local C = rb.CFrame.new
	local joints = {
		RootJoint = { C(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), C(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
		Neck = { C(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), C(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
		["Right Hip"] = { C(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
		["Left Hip"] = { C(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
		["Right Shoulder"] = { C(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
		["Left Shoulder"] = { C(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	}
	local function posed(pose)
		local transform = function(name)
			return if pose then Stance.Transform(joints[name][1], pose[name]) else rb.CFrame.identity
		end
		local function child(parent, name)
			return parent * joints[name][1] * transform(name) * joints[name][2]:Inverse()
		end
		local torso = child(rb.CFrame.identity, "RootJoint")
		return {
			Torso = torso,
			Head = child(torso, "Neck"),
			RightFoot = child(torso, "Right Hip") * rb.Vector3.new(0, -1, 0),
			LeftFoot = child(torso, "Left Hip") * rb.Vector3.new(0, -1, 0),
			RightHand = child(torso, "Right Shoulder") * rb.Vector3.new(0, -1, 0),
			LeftHand = child(torso, "Left Shoulder") * rb.Vector3.new(0, -1, 0),
		}
	end
	local rest = posed(nil)
	assert(near(rest.RightFoot.X, 0.5) and near(rest.RightFoot.Y, -3) and near(rest.LeftFoot.X, -0.5), "(the joint maths: standing, the feet are under the hips, 3 studs down)")
	for _, speed in { 0, 200, 600 } do
		for _, t in { 0, 0.7, 1.9 } do
			local body = posed(Stance.Pose(t, speed))
			for _, foot in { body.RightFoot, body.LeftFoot } do
				assert(math.abs(foot.X) < 0.75 and math.abs(foot.Z) < 2.6, ("On the board (%.2f, %.2f)"):format(foot.X, foot.Z))
				-- The board's top is at -3.05.
				assert(foot.Y > -3.1 and foot.Y < -2.9, ("Standing on it (%.2f)"):format(foot.Y))
			end
			assert(math.abs(body.RightFoot.Z - body.LeftFoot.Z) > 1.8, "Feet apart along the board")
			assert(body.LeftFoot.Z < body.RightFoot.Z, "Regular stance: left foot forward")
			assert(math.abs(body.Torso.LookVector:Dot(rb.Vector3.new(0, 0, -1))) < 0.5, "The body side-on to the board")
			assert(body.Head.LookVector:Dot(rb.Vector3.new(0, 0, -1)) > 0.8, "The head looks where the board goes")
			assert(body.RightHand.Y > -1.2 and body.LeftHand.Y > -1.2, "Arms out for balance")
		end
	end
	local pose = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SurfboardPose.client.luau")
	has(pose, "RunService.Stepped:Connect(function(now)", "The stance is set after the animations each frame")
	has(pose, "motor.Transform = SurfboardStance.Transform(motor.C0, rotation)", "...on the joints' Transform")
	has(pose, 'character:GetAttribute("Ragdolled") == true', "It stands aside for the ragdoll")
	has(pose, "for _, connection in connections do\n\t\t\t\tconnection:Disconnect()", "A character that is gone lets go of its watchers")

	-- The pictures.
	local SkinPreview = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SkinPreview.luau"), {
		environment = setmetatable({ game = { GetService = function() return {} end }, CFrame = rb.CFrame }, { __index = _G }),
	})()
	local torso = rb.CFrame.new(10, 5, -3) * rb.CFrame.Angles(0, 0.8, 0)
	local camera = SkinPreview.CameraFor(torso)
	local toTorso = (torso.Position - camera.Position).Unit
	assert(camera.LookVector:Dot(toTorso) > 0.98 and (camera.Position - torso.Position):Dot(torso.LookVector) > 5, "The rig's portrait is taken from the front, looking at it")
	assert(SkinPreview.Thumbnail(140470689397913) == "rbxthumb://type=Asset&id=140470689397913&w=420&h=420", "Other skins keep their catalog thumbnail")
	local index = fs.readFile("src/common/StarterGui/Index/IndexScript.client.luau")
	has(index, "SkinPreview.Apply(icon, skin)", "The Index draws each skin's picture (the rig for Superman and A-Train)")
	has(index, 'World3 = { Label = "BEAT WORLD 3"', "The locked Silver Surfer says where it is won")
	local evolve = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau")
	has(evolve, "SkinPreview.Apply(icon, info)", "The Evolve panel too")
	has(SKINS, "PreviewRig = entry.PreviewRig,", "The server sends the Index which skins have a rig")

	-- Finishing World 3 unlocks the Silver Surfer, once.
	local pads = fs.readFile("src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau")
	has(pads, 'task.spawn(grantSkin, player, "SilverSurferSuit", "world3_finish_silver_surfer")', "World 3's finish pays the Silver Surfer")
	local grantChunk = between(SKINS, "_G.SpeedsterGrantExclusiveSkin = function(player, skinId, reason)", "local function connectOwnedSkinUpdates(player)")
	local owned, commits, messages = {}, {}, {}
	local globals = {}
	luau.load(grantChunk, {
		environment = setmetatable({
			_G = globals,
			SuitCatalog = loadCatalog(0),
			typeof = function(value)
				return if type(value) == "table" and value.IsPlayer then "Instance" else type(value)
			end,
			ownsSkin = function(_, id)
				return owned[id] == true
			end,
			ModularData = {
				GetHandle = function()
					return {}
				end,
				Commit = function(_, request)
					table.insert(commits, request)
					owned[request.commands[1].skinId] = true
					return { kind = "Committed" }
				end,
			},
			HttpService = { GenerateGUID = function() return "guid" end },
			unlockSkin = function() end,
			saveSkinState = function() end,
			sendIndexUpdate = function(_, message)
				table.insert(messages, message)
			end,
		}, { __index = _G }),
	})()
	local loaded = true
	local player = {
		IsPlayer = true,
		IsA = function(_, class) return class == "Player" end,
		GetAttribute = function(_, name) return name == "DataLoaded" and loaded end,
	}
	loaded = false
	assert(globals.SpeedsterGrantExclusiveSkin(player, "SilverSurferSuit") == false and #commits == 0, "Nothing is granted before the data loads")
	loaded = true
	assert(globals.SpeedsterGrantExclusiveSkin(player, "ShadowSuit") == false, "Only exclusives are handed out this way")
	assert(globals.SpeedsterGrantExclusiveSkin(player, "SilverSurferSuit") == true and #commits == 1 and commits[1].commands[1].kind == "GrantSkin", "The finish grants it in the profile")
	assert(string.find(messages[1], "Silver Surfer unlocked", 1, true), "...and tells the player")
	assert(globals.SpeedsterGrantExclusiveSkin(player, "SilverSurferSuit") == true and #commits == 1, "A second finish grants nothing more")
	print("PASS Silver Surfer: its board lies flat along the ride under the lifted feet, a surfer's stance on it, pictures for rig skins, and World 3's finish unlocks it once")
end

----------------------------------------------------------------------
-- 5. Superman flies low when he runs (2026-09-18)
----------------------------------------------------------------------
do
	local env = setmetatable({ CFrame = rb.CFrame, Vector3 = rb.Vector3 }, { __index = _G })
	local Pose = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SupermanFlightPose.luau"), { environment = env })()
	local Stance = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SurfboardStance.luau"), { environment = env })()
	-- The pose on the Superman rig (R6), joint by joint: Part1 = Part0 * C0 * Transform * C1^-1.
	local rig = places.World1.ReplicatedStorage.SkinRigs.Superman:Clone()
	local root = rig.HumanoidRootPart
	root.CFrame = rb.CFrame.new(0, 3, 0) -- a standing R6 root is 3 studs over the floor
	local pose = Pose.Pose(0)
	local function place(part0, motor)
		local transform = Stance.Transform(motor.C0, pose[motor.Name])
		motor.Part1.CFrame = part0.CFrame * motor.C0 * transform * motor.C1:Inverse()
	end
	place(root, root.RootJoint)
	local torso = rig.Torso
	for _, name in { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" } do
		place(torso, torso[name])
	end
	local ahead = root.CFrame.LookVector
	assert(math.abs(torso.CFrame.UpVector.Y) < 0.3 and torso.CFrame.UpVector:Dot(ahead) > 0.9, "The body lies almost flat, head first")
	assert(-rig["Right Arm"].CFrame.UpVector:Dot(ahead) > 0.9, "The right arm reaches out in front, fist first")
	assert(-rig["Left Arm"].CFrame.UpVector:Dot(ahead) < -0.8, "The left arm lies back along the side")
	assert(rig.Head.CFrame.LookVector:Dot(ahead) > 0.6, "The head looks where it flies")
	for _, leg in { "Right Leg", "Left Leg" } do
		assert(-rig[leg].CFrame.UpVector:Dot(ahead) < -0.9, leg .. " stretched out behind")
	end
	local lowest = math.huge
	for _, part in rig:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						lowest = math.min(lowest, part.CFrame:PointToWorldSpace(rb.Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
					end
				end
			end
		end
	end
	assert(lowest > 1, "It floats over the floor, never through it (lowest point " .. lowest .. ")")
	local blend = 0
	for _ = 1, 3 do
		blend = Pose.Blend(blend, true, 1 / 30)
	end
	assert(blend > 0 and blend < 1, "It eases into the pose")
	for _ = 1, 30 do
		blend = Pose.Blend(blend, true, 1 / 30)
	end
	assert(blend == 1, "...all the way")
	for _ = 1, 30 do
		blend = Pose.Blend(blend, false, 1 / 30)
	end
	assert(blend == 0, "...and back out when he stops")

	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SupermanFlight.client.luau")
	has(client, 'local SKIN_ID = "SupermanSuit"', "Only the Superman skin flies")
	has(client, 'player:GetAttribute("EquippedSkin") == SKIN_ID', "...by the player's equipped skin")
	has(client, "Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= SupermanFlightPose.MinSpeed", "...while moving at a run")
	has(client, "RunService.Stepped:Connect(function(now, dt)", "After the animations, every frame")
	has(client, 'player:GetAttribute("FlightAbilityActive") == true', "Flight keeps its own pose")
	has(client, "flyer.Cape.C0 = flyer.CapeC0 * CFrame.new():Lerp(SupermanFlightPose.Cape(t), weight)", "The cape flutters")
	has(client, "flyer.Cape.C0 = flyer.CapeC0\n", "...and is put back when he lands")
	assert(rig:FindFirstChild("RedCape"), "Superman's cape is the RedCape accessory")
	print("PASS Superman flight: running, the body lies flat and floats, fist out in front, head up, legs behind, the cape fluttering; eased in and out")
end

print("ALL NEW SKIN CHECKS PASSED")
