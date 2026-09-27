--!strict
-- Services/Data/U4/CommunitySection.luau — profile section U4.Community = { Claimed, At }.
-- Pure (Update4Profile dispatches to it; tests require it directly). One op:
--   U4.Community.Claim { at }   the Community reward, once per account.
-- 2026-09-25 (Update 4): Claim is refused once Claimed is set, so the reward stays one per
-- account even past the operation-id history (CommunityRewardService commits it together with
-- the title, potion and spins: a refused Claim refuses the whole transaction).
local CommunitySection = {}

-- 2100-01-01: anything later (or negative, NaN, infinite) is not a real claim time.
local MAX_UNIX = 4102444800

local function reject(message: string)
	return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } }
end

local function cleanUnix(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value > MAX_UNIX then
		return 0
	end
	return math.floor(value)
end

function CommunitySection.Default(): { [string]: any }
	return { Claimed = false, At = 0 }
end

-- Never throws: anything that is not a table (or holds the wrong types) is cleaned.
function CommunitySection.Sanitize(raw: any): { [string]: any }
	if type(raw) ~= "table" then
		return CommunitySection.Default()
	end
	local claimed = raw.Claimed == true
	return { Claimed = claimed, At = if claimed then cleanUnix(raw.At) else 0 }
end

function CommunitySection.Encode(state: any): { [string]: any }
	return CommunitySection.Sanitize(state)
end

function CommunitySection.Apply(state: any, op: string, command: any, now: number)
	if type(state) ~= "table" then
		return reject("Invalid community state")
	end
	if op ~= "Claim" then
		return reject("Unknown community op")
	end
	if state.Claimed == true then
		return reject("Community reward already claimed")
	end
	local at = if type(command) == "table" then command.at else nil
	state.Claimed = true
	state.At = if type(at) == "number" and cleanUnix(at) > 0 then cleanUnix(at) else cleanUnix(now)
	return { ok = true, value = true }
end

return CommunitySection
