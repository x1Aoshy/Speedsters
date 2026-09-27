-- Dark Zonic's old Workspace dummy is absent from the shipped places. Owners
-- should still equip the mask and clothes configured in SuitCatalog.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
local first = assert(string.find(source, "local function applyWorkspaceDummySuit(player, entry)", 1, true))
local after = assert(string.find(source, "-- RigOutfit: Superman and A-Train", first, true))
local snippet = string.sub(source, first, after - 1)
local catalogCalls, neckCalls = 0, 0
local humanoid = {}
local character = {
	FindFirstChildOfClass = function(_, className)
		return if className == "Humanoid" then humanoid else nil
	end,
}
local env = setmetatable({
	getDarkZonicDummy = function() return nil end,
	applyCatalogSuit = function(player, entry)
		assert(player.Character == character and entry.Id == "DarkZonicSuit")
		catalogCalls += 1
		return true
	end,
	setDarkZonicNeckSpacing = function(model, enabled)
		assert(model == character and enabled == true)
		neckCalls += 1
	end,
}, { __index = _G })
local apply = luau.load(snippet .. "\nreturn applyWorkspaceDummySuit", { environment = env })()
local ok = apply({ Character = character }, { Id = "DarkZonicSuit" })
assert(ok == true and catalogCalls == 1 and neckCalls == 1,
	"Dark Zonic owners must get the catalog outfit when the old dummy is absent")
print("PASS Dark Zonic: missing dummy equips catalog mask/clothes for an owner")
