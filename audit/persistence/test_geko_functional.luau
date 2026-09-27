local fs = require("@lune/fs")

local function check(cond, msg)
	if not cond then
		error("TEST FAILURE: " .. msg, 2)
	end
end

print("=== FUNCTIONAL TEST FOR PROFILE & CODES ===")

-- Test World 1 and World 2
for _, world in ipairs({ "World1", "World2" }) do
	print("Testing functional behavior for " .. world .. "...")
	local Catalog = require("../../audit/merged/" .. world .. "/ReplicatedStorage/Shared/Catalogs/CodesCatalog")
	local Codec = require("../../audit/merged/" .. world .. "/ServerScriptService/Services/Data/ProfileCodec")
	local Reducers = require("../../audit/merged/" .. world .. "/ServerScriptService/Services/Data/ProfileReducers")

	-- 1. CodesCatalog Lookup
	local c1 = Catalog.Get("geko")
	check(c1 ~= nil, "Lookup 'geko' failed")
	check(c1.Speed == 800000, "Expected Speed 800,000, got " .. tostring(c1.Speed))
	check(c1.Wins == 20000, "Expected Wins 20,000, got " .. tostring(c1.Wins))
	check(c1.FlightMinutes == 20, "Expected FlightMinutes 20, got " .. tostring(c1.FlightMinutes))
	check(c1.Marker == "Code_GekoFly_v1", "Expected Marker Code_GekoFly_v1")

	local c2 = Catalog.Get("  GEKOFLY ")
	check(c2 ~= nil and c2.Marker == "Code_GekoFly_v1", "Normalized lookup failed")

	local c3 = Catalog.Get("admingiveawayfly")
	check(c3 ~= nil and c3.Marker == "Code_GekoFly_v1", "Lookup admingiveawayfly failed")

	-- 2. ProfileCodec Default
	local defaultProfile = Codec.CreateDefault()
	check(defaultProfile.TemporaryFlightRemainingSeconds == 0, "Default TemporaryFlightRemainingSeconds should be 0")

	-- 3. Reducer GrantBuff TemporaryFlight
	local grantRes = Reducers.ApplyCommand(defaultProfile, {
		kind = "GrantBuff",
		grant = {
			kind = "TemporaryFlight",
			addedSeconds = 1200,
		},
	})
	check(grantRes.ok == true, "ApplyCommand GrantBuff failed")
	check(defaultProfile.TemporaryFlightRemainingSeconds == 1200, "Expected 1200 seconds, got " .. tostring(defaultProfile.TemporaryFlightRemainingSeconds))

	-- 4. Codec Encode & Decode
	local encoded = Codec.Encode(defaultProfile)
	check(encoded.TemporaryFlightRemainingSeconds == 1200, "Encoded TemporaryFlightRemainingSeconds should be 1200")

	local decodeRes = Codec.Decode(encoded)
	check(decodeRes.ok == true, "Decode failed")
	check(decodeRes.value.TemporaryFlightRemainingSeconds == 1200, "Decoded TemporaryFlightRemainingSeconds should be 1200")

	print(world .. " functional verification PASSED!")
end

print("ALL FUNCTIONAL TESTS PASSED!")