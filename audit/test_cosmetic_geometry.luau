--!strict
-- audit/test_cosmetic_geometry.luau
-- Builds the real trail/aura templates from the authored RawCosmeticPack and
-- checks that nothing rescales or re-places the artist's geometry.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function loadModule(path: string, env, transform)
	local source = fs.readFile(path)
	if transform then
		source = transform(source)
	end
	return luau.load(source, { environment = env })()
end

-- Lune instances have no WaitForChild. Every child the builder waits for already
-- exists in the authored place, so the two waits are read as lookups here; the
-- rest of the module runs exactly as it ships.
local function withoutWaits(source: string): string
	source = source:gsub('ServerStorage:WaitForChild%("RawCosmeticPack", 30%)', 'ServerStorage:FindFirstChild("RawCosmeticPack")')
	return source
end

for _, place in ipairs(PlaceFiles.Files("World1", "World2")) do
	local game = roblox.deserializePlace(fs.readFile(place))
	local replicated = game:GetService("ReplicatedStorage")
	local serverStorage = game:GetService("ServerStorage")

	local baseEnv = {
		Instance = roblox.Instance, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame,
		Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange, Enum = roblox.Enum,
		table = table, math = math, string = string, ipairs = ipairs, pairs = pairs,
		tonumber = tonumber, tostring = tostring, type = type, typeof = typeof,
		next = next, select = select, pcall = pcall, error = error, assert = assert,
		print = function() end, warn = function() end,
	}

	local catalog = loadModule("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau", baseEnv)

	local builderEnv = table.clone(baseEnv)
	builderEnv.game = {
		GetService = function(_, name)
			if name == "ServerStorage" then return serverStorage end
			-- The builder only reaches ReplicatedStorage to require the catalog.
			local stub
			-- (and CollectionService, to tag the templates).
			stub = { WaitForChild = function() return stub end, AddTag = function() end }
			return stub
		end,
	}
	-- World 3's auras come from NewAurasFactory, next to the builder.
	local factoryEnv = table.clone(baseEnv)
	factoryEnv.Vector2 = roblox.Vector2
	local factory = loadModule("src/common/ServerScriptService/Economy/Cosmetics/NewAurasFactory.luau", factoryEnv)
	builderEnv.script = { Parent = { WaitForChild = function(_, name) return name end } }
	builderEnv.require = function(module)
		return if module == "NewAurasFactory" then factory else catalog
	end

	local builder = loadModule("src/common/ServerScriptService/Economy/Cosmetics/CosmeticTemplateBuilder.luau", builderEnv, withoutWaits)
	local root = builder.Build()
	local trails = root:FindFirstChild("Trails")
	local auras = root:FindFirstChild("Auras")
	assert(trails and auras, place .. ": builder produced no Trails/Auras folders")

	local function offsetOf(template)
		local value = template:FindFirstChild("LocalOffset")
		assert(value and value:IsA("CFrameValue"), template.Name .. " has no LocalOffset")
		return value.Value
	end

	local function near(actual: number, expected: number, tolerance: number): boolean
		return math.abs(actual - expected) <= tolerance
	end

	for _, entry in ipairs(catalog.Trails) do
		local template = trails:FindFirstChild(entry.Id)
		assert(template, place .. ": missing trail template " .. entry.Id)
		assert(template:GetAttribute("OffsetSpace") == "HumanoidRootPart",
			entry.Id .. " must declare its offset relative to the HumanoidRootPart")

		local offset = offsetOf(template).Position
		-- Neither showroom offset may survive: not the 26.8-stud gap behind the
		-- preview dummy, nor the 2 studs it floated above the dummy's head.
		assert(near(offset.X, 0, 0.05), entry.Id .. " drifted sideways: X=" .. tostring(offset.X))
		assert(near(offset.Z, 0.55, 0.01), entry.Id .. " is not on the player's back: Z=" .. tostring(offset.Z))
		assert(offset.Y < 1, entry.Id .. " still rides above the character: Y=" .. tostring(offset.Y))

		-- The ribbon keeps the authored length (6 studs on a1..a5, 8 on a0) and must
		-- run head to feet, not tower over the head. An R6 body spans -3 (soles) to
		-- +2 (crown) around the HumanoidRootPart.
		local BODY_LOW, BODY_HIGH = -3, 2
		local low, high, tips = math.huge, -math.huge, 0
		for _, attachment in ipairs(template:GetDescendants()) do
			-- The pack's ribbons end in t0/t1; World 3's drawn ribbons in <Layer>Top/Bottom.
			local tip = attachment.Name == "t0" or attachment.Name == "t1"
				or (entry.Ribbon ~= nil and (string.match(attachment.Name, "Top$") ~= nil or string.match(attachment.Name, "Bottom$") ~= nil))
			if attachment:IsA("Attachment") and tip then
				tips += 1
				assert(math.abs(attachment.CFrame.Position.Y) >= 2.5,
					entry.Id .. " ribbon was shrunk in code: half-height " .. tostring(attachment.CFrame.Position.Y))
				local parentY = attachment.Parent:IsA("Attachment") and attachment.Parent.CFrame.Position.Y or 0
				local y = offset.Y + parentY + attachment.CFrame.Position.Y
				low = math.min(low, y)
				high = math.max(high, y)
			end
		end
		assert(tips >= (if entry.Ribbon then 4 else 12), entry.Id .. " lost trail attachments: " .. tostring(tips))
		assert(low <= BODY_LOW, string.format("%s does not reach the feet: lowest %.2f", entry.Id, low))
		assert(high >= BODY_HIGH, string.format("%s does not reach the head: highest %.2f", entry.Id, high))
		local centre = (low + high) * 0.5
		local bodyCentre = (BODY_LOW + BODY_HIGH) * 0.5
		assert(math.abs(centre - bodyCentre) <= 0.35, string.format(
			"%s is not centred on the body: ribbon centre %.2f vs body centre %.2f", entry.Id, centre, bodyCentre))
	end

	for _, entry in ipairs(catalog.Auras) do
		local template = auras:FindFirstChild(entry.Id)
		assert(template, place .. ": missing aura template " .. entry.Id)
		local offset = offsetOf(template).Position
		-- The seven originals share one offset; World 3's keep their authored one,
		-- which is always on the root's axis and within half a stud of it.
		local expectedY = if entry.World == nil and entry.Exclusive == nil then -0.5 else offset.Y
		assert(near(offset.X, 0, 0.05) and near(offset.Y, expectedY, 0.05) and math.abs(offset.Y) <= 0.55 and near(offset.Z, 0, 0.05),
			entry.Id .. " aura offset drifted: " .. tostring(offset))
	end

	print("PASS " .. place .. ": " .. #catalog.Trails .. " trails on the back at authored scale, " .. #catalog.Auras .. " auras centred on the root")
end

print("ALL COSMETIC GEOMETRY CHECKS PASSED")
