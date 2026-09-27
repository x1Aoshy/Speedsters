-- test_designer_ui.luau
-- The designer's UI ships as generated source (Shared.DesignerUi.*). Rebuilds each
-- module with the real builder and compares every scriptable property, attribute and
-- child against the designer's .rbxm, so a regenerated module can never drift from
-- the file it came from.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local failures = 0
local function check(condition, message)
	if not condition then
		failures += 1
		print("FAIL " .. message)
	end
end

local RBXM = "design/ui/SpinWheelAndEarnings.rbxm"
local MODULES = {
	{ Module = "SpinWheelGui", Instance = "SpinWheel" },
	{ Module = "EarningsGui", Instance = "Earnings" },
	{ Module = "QuestGui", Instance = "Quests", Rbxm = "design/ui/Quests.rbxm" },
}

local constructors = {
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
	Vector3 = roblox.Vector3,
	Rect = roblox.Rect,
	Font = roblox.Font,
	Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
}

local warnings = {}
local builderEnv = setmetatable({
	Instance = roblox.Instance,
	warn = function(message)
		table.insert(warnings, message)
	end,
}, { __index = _G })
local builderSource = fs.readFile("src/common/ReplicatedStorage/Shared/DesignerUiBuilder.luau")
local DesignerUi = luau.load(builderSource, { debugName = "DesignerUiBuilder", environment = builderEnv })()

local db = roblox.getReflectionDatabase()
local BLOCKING_TAGS = { Deprecated = true, Hidden = true, NotScriptable = true, ReadOnly = true }
local SKIP = { Parent = true, Name = true, Archivable = true, UniqueId = true, HistoryId = true, SourceAssetId = true, Capabilities = true, Sandboxed = true, DefinesCapabilities = true, Tags = true, AttributesSerialize = true }

local function properties(className)
	local list, seen = {}, {}
	local current = db:GetClass(className)
	while current do
		for name, property in current.Properties do
			if not seen[name] then
				seen[name] = true
				local blocked = SKIP[name] or property.Scriptability ~= "ReadWrite"
				for _, tag in property.Tags do
					if BLOCKING_TAGS[tag] then
						blocked = true
					end
				end
				local datatype = tostring(property.Datatype)
				if not blocked and datatype ~= "Ref" and datatype ~= "ContentId" then
					table.insert(list, { Name = name, Datatype = datatype })
				end
			end
		end
		current = if current.Superclass then db:GetClass(current.Superclass) else nil
	end
	return list
end

local compared = 0
local function compare(original, rebuilt, path)
	check(original.ClassName == rebuilt.ClassName, path .. " class " .. original.ClassName .. " vs " .. rebuilt.ClassName)
	check(original.Name == rebuilt.Name, path .. " name")
	for _, property in properties(original.ClassName) do
		local okA, a = pcall(function()
			return original[property.Name]
		end)
		local okB, b = pcall(function()
			return rebuilt[property.Name]
		end)
		if property.Datatype == "Content" then
			local uri = if okA and typeof(a) == "Content" then a.Uri else nil
			if type(uri) == "string" and uri ~= "" then
				local twin = string.gsub(property.Name, "Content$", "")
				local okTwin, twinValue = pcall(function()
					return rebuilt[twin]
				end)
				check(okTwin and twinValue == uri, path .. "." .. twin .. " expected " .. uri .. " got " .. tostring(twinValue))
				compared += 1
			end
		elseif okA then
			-- A property the original has but the rebuild could not read was never
			-- written, which is only right when the original holds the default.
			local default = db:GetClass(original.ClassName).DefaultProperties[property.Name]
			if okB then
				check(a == b, path .. "." .. property.Name .. " expected " .. tostring(a) .. " got " .. tostring(b))
			else
				check(default == nil or default == a, path .. "." .. property.Name .. " missing, expected " .. tostring(a))
			end
			compared += 1
		end
	end
	for name, value in original:GetAttributes() do
		check(rebuilt:GetAttribute(name) == value, path .. " attribute " .. name)
	end
	local originalChildren, rebuiltChildren = original:GetChildren(), rebuilt:GetChildren()
	check(#originalChildren == #rebuiltChildren, path .. " child count " .. #originalChildren .. " vs " .. #rebuiltChildren)
	for index, child in originalChildren do
		if rebuiltChildren[index] then
			compare(child, rebuiltChildren[index], path .. "/" .. child.Name)
		end
	end
end

local function find(name, file)
	local roots = roblox.deserializeModel(fs.readFile(file))
	for _, root in roots do
		if root.Name == name and root:IsA("LayerCollector") then
			return root
		end
		for _, descendant in root:GetDescendants() do
			if descendant.Name == name and descendant:IsA("LayerCollector") then
				return descendant
			end
		end
	end
	return nil
end

for _, entry in MODULES do
	local path = "src/common/ReplicatedStorage/Shared/DesignerUi/" .. entry.Module .. ".luau"
	local source = fs.readFile(path)
	local spec = luau.load(source, { debugName = entry.Module, environment = constructors })()
	local file = entry.Rbxm or RBXM
	local original = find(entry.Instance, file)
	check(original ~= nil, entry.Instance .. " exists in " .. file)
	if original then
		local rebuilt = DesignerUi.Build(spec)
		compare(original, rebuilt, entry.Instance)
	end
end
check(#warnings == 0, "builder warned: " .. table.concat(warnings, " | "))

if failures > 0 then
	error(failures .. " designer UI checks failed")
end
print("PASS designer UI modules rebuild the .rbxm exactly (" .. compared .. " properties compared)")
