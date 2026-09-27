--!strict
-- Update 4 profile field U4: one dispatcher, one section module per feature (Services/Data/U4/*).
-- ProfileCodec (Default/Decode/Encode) and ProfileReducers (commands "U4.<Section>.<Op>") call
-- it; each workstream owns one section module with the contract
--   Default() -> table, Sanitize(raw) -> table (never throws), Encode(t) -> table,
--   Apply(state, op, command, now) -> {ok=true,value} | {ok=false,error={code,message,retryable}}.
-- 2026-09-25 (integrator, Phase 0): a section that is missing or fails to load is tolerated,
-- and its saved data is carried through untouched (deep copy) instead of being dropped, so a
-- bad section build can never wipe a player's streak, titles or race records on the next save.
local Update4Profile = {}

local SECTION_NAMES = { "Race", "Retention", "Titles", "Community" }
local VOLATILE = { ["U4.Retention.Playtime"] = true, ["U4.Titles.SetPref"] = true }
Update4Profile.Version = 1
Update4Profile.SectionNames = SECTION_NAMES

-- Server modules are all in place before any script runs, so FindFirstChild (never a wait):
-- an absent U4 folder or section must not hold up ProfileCodec's first require.
local sections: { [string]: any } = {}
for _, name in SECTION_NAMES do
	local ok, mod = pcall(function(): any
		if typeof(script) == "Instance" and script.Parent then
			local folder = script.Parent:FindFirstChild("U4")
			local module = folder and folder:FindFirstChild(name .. "Section")
			return if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
		end
		return (require :: any)("./U4/" .. name .. "Section")
	end)
	if ok and type(mod) == "table" and type(mod.Default) == "function" and type(mod.Sanitize) == "function"
		and type(mod.Encode) == "function" and type(mod.Apply) == "function" then
		sections[name] = mod
	end
end

local function reject(message: string)
	return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } }
end

-- Plain data only (DataStore JSON): bounded depth, functions/userdata dropped.
local function copyPlain(value: any, depth: number?): any
	local level = depth or 0
	if type(value) ~= "table" then
		return if type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then nil else value
	end
	if level > 12 then
		return nil
	end
	local out = {}
	for k, v in value do
		if type(k) == "string" or type(k) == "number" then
			out[k] = copyPlain(v, level + 1)
		end
	end
	return out
end

local function defaultOf(mod: any): any
	local ok, value = pcall(mod.Default)
	return if ok and type(value) == "table" then value else {}
end

function Update4Profile.HasSection(name: string): boolean
	return sections[name] ~= nil
end

function Update4Profile.IsVolatile(kind: any): boolean
	return VOLATILE[kind] == true
end

function Update4Profile.Default(): { [string]: any }
	local u4: { [string]: any } = { V = Update4Profile.Version }
	for name, mod in sections do
		u4[name] = defaultOf(mod)
	end
	return u4
end

function Update4Profile.Sanitize(raw: any): { [string]: any }
	local u4: { [string]: any } = { V = Update4Profile.Version }
	for _, name in SECTION_NAMES do
		local mod = sections[name]
		local rawSection = if type(raw) == "table" then raw[name] else nil
		if mod then
			local ok, clean = pcall(mod.Sanitize, rawSection)
			u4[name] = if ok and type(clean) == "table" then clean else defaultOf(mod)
		elseif type(rawSection) == "table" then
			u4[name] = copyPlain(rawSection)
		end
	end
	return u4
end

function Update4Profile.Encode(u4: any): { [string]: any }
	local out: { [string]: any } = { V = Update4Profile.Version }
	for _, name in SECTION_NAMES do
		local mod = sections[name]
		local current = if type(u4) == "table" and type(u4[name]) == "table" then u4[name] else nil
		if mod then
			local ok, encoded = pcall(mod.Encode, current or defaultOf(mod))
			-- A section that cannot encode keeps its in-memory copy rather than losing it.
			out[name] = if ok and type(encoded) == "table" then encoded else copyPlain(current or defaultOf(mod))
		elseif current then
			out[name] = copyPlain(current)
		end
	end
	return out
end

function Update4Profile.Apply(profile: any, command: any, now: number)
	if type(profile) ~= "table" or type(command) ~= "table" or type(command.kind) ~= "string" then
		return reject("Invalid U4 command")
	end
	local section, op = string.match(command.kind, "^U4%.(%a+)%.(%a+)$")
	local mod = section and sections[section]
	if not mod then
		return reject("Unknown U4 command")
	end
	if type(profile.U4) ~= "table" then
		profile.U4 = Update4Profile.Default()
	end
	if type(profile.U4[section]) ~= "table" then
		profile.U4[section] = defaultOf(mod)
	end
	-- A throwing section is a rejected command (Commit discards its draft), never a crash
	-- inside the session lock.
	local ok, result = pcall(mod.Apply, profile.U4[section], op, command, now)
	if not ok then
		return reject("U4 section error: " .. tostring(result))
	end
	if type(result) ~= "table" or type(result.ok) ~= "boolean" then
		return reject("U4 section returned no result")
	end
	return result
end

return Update4Profile
