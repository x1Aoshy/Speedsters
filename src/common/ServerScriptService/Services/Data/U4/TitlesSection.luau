--!strict
-- Services/Data/U4/TitlesSection.luau (Update 4, 2026-09-25) — profile section U4.Titles, pure.
-- { Pref = "" | "none" | "<id>" (<= 32 chars, ^[a-z0-9_]*$), Owned = { <= 40 marker ids } }
-- Commands (Update4Profile dispatches "U4.Titles.<Op>"):
--   Grant {id}    earned titles (race/streak/community/admin) — idempotent, and a full list
--                 keeps what it has instead of failing: other workstreams put this command in
--                 their reward Commit, and a rejected command would cost the player that reward.
--   AdminGrant {id} 2026-09-26 (owner): an admin gives ANY catalog title (staff and rank ones
--                 too) from the admin panel; same list, same rules as Grant otherwise.
--   Revoke {id}   admin; removing a title that is not there is fine too.
--   SetPref {pref} volatile (DataService.ApplyVolatile), saved by the autosave / release.
local TitlesSection = {}

-- Shared modules are in place before any script runs: FindFirstChild, never a wait (this loads
-- inside ProfileCodec's first require).
local function tryRequire(path: string, name: string): any
	local ok, mod = pcall(function(): any
		if typeof(script) == "Instance" then
			local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
			local module = shared and shared:FindFirstChild(name)
			return if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
		end
		return (require :: any)(path)
	end)
	return if ok and type(mod) == "table" then mod else nil
end

-- The catalog decides which ids can be granted; without it (a broken build) any well-formed id is
-- accepted rather than failing somebody's reward.
local Catalog = tryRequire("../../../../ReplicatedStorage/Shared/TitleCatalog", "TitleCatalog")
local U4 = tryRequire("../../../../ReplicatedStorage/Shared/Update4Config", "Update4Config")

local MAX_ID = 32
TitlesSection.MaxOwned = if U4 and U4.Titles and tonumber(U4.Titles.MaxOwned) then math.floor(U4.Titles.MaxOwned) else 40

local function validId(id: any): boolean
	return type(id) == "string" and #id <= MAX_ID and string.match(id, "^[a-z0-9_]*$") ~= nil
end
TitlesSection.ValidId = validId

local function reject(message: string)
	return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } }
end

function TitlesSection.Default(): { [string]: any }
	return { Pref = "", Owned = {} }
end

function TitlesSection.Sanitize(raw: any): { [string]: any }
	local out = TitlesSection.Default()
	if type(raw) ~= "table" then
		return out
	end
	if validId(raw.Pref) then
		out.Pref = raw.Pref
	end
	if type(raw.Owned) == "table" then
		local seen = {}
		for _, id in ipairs(raw.Owned) do
			if #out.Owned >= TitlesSection.MaxOwned then
				break
			end
			if validId(id) and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(out.Owned, id)
			end
		end
	end
	return out
end

function TitlesSection.Encode(state: any): { [string]: any }
	local clean = TitlesSection.Sanitize(state)
	return { Pref = clean.Pref, Owned = table.clone(clean.Owned) }
end

local function indexOf(list: { string }, id: string): number?
	for index, value in ipairs(list) do
		if value == id then
			return index
		end
	end
	return nil
end

function TitlesSection.Apply(state: any, op: string, command: any, _now: number)
	if type(state.Owned) ~= "table" then
		state.Owned = {}
	end
	if type(state.Pref) ~= "string" then
		state.Pref = ""
	end
	if op == "Grant" or op == "AdminGrant" then
		local id = command.id
		if not validId(id) or id == "" then
			return reject("Invalid title id")
		end
		-- 2026-09-26 (owner): AdminGrant takes any catalog id; Grant stays markers only.
		if Catalog and op == "Grant" and not Catalog.IsMarker(id) then
			return reject("Title cannot be granted: " .. tostring(id))
		end
		if Catalog and op == "AdminGrant" and not Catalog.ById[id] then
			return reject("Unknown title: " .. tostring(id))
		end
		if indexOf(state.Owned, id) then
			return { ok = true, value = false }
		end
		if #state.Owned >= TitlesSection.MaxOwned then
			return { ok = true, value = false }
		end
		table.insert(state.Owned, id)
		return { ok = true, value = true }
	elseif op == "Revoke" then
		local id = command.id
		if not validId(id) or id == "" then
			return reject("Invalid title id")
		end
		local index = indexOf(state.Owned, id)
		if index then
			table.remove(state.Owned, index)
		end
		return { ok = true, value = index ~= nil }
	elseif op == "SetPref" then
		local pref = command.pref
		if not validId(pref) then
			return reject("Invalid title preference")
		end
		state.Pref = pref
		return { ok = true, value = pref }
	end
	return reject("Unknown U4.Titles command")
end

return TitlesSection
