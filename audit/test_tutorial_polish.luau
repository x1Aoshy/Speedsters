local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Availability = require("../src/common/ReplicatedStorage/Shared/EvolveAvailability")
local catalog = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau"))()
local owned = {[catalog.DefaultSkinId]=true}
assert(Availability.Count(catalog.Ordered,owned,9,0)==0)
local count,nextId=Availability.Count(catalog.Ordered,owned,10,0)
assert(count==1 and nextId=="ReverseSpeedsterSuit")
assert(Availability.Count(catalog.Ordered,owned,40,0)==1,"Rebirth requirement ignored")
assert(Availability.Count(catalog.Ordered,owned,40,2)==3)
owned.ReverseSpeedsterSuit=true
assert(Availability.Count(catalog.Ordered,owned,40,2)==2)
assert(Availability.Count(catalog.Ordered,owned,1,2)==0,"Badge must clear after rebirth level reset")
for _,entry in catalog.Ordered do owned[entry.Id]=true end
assert(Availability.Count(catalog.Ordered,owned,999,999)==0,"Already owned suits counted")
print("PASS evolve availability: first unlock, multiple unlocks, rebirth gates, ownership, level reset, max evolved")
local sources={
	"ServerScriptService/Admin/AdminAbusePanelService.server.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/CreatorFollowPopup.client.luau",
}
for _,path in sources do
	local source=fs.readFile("src/common/"..path)
	for _,forbidden in {"Hosted by @", "PromptFollow", "ShowFollowCreator", "FollowHost", "COPY PROFILE", "GekkoH"} do
		assert(not source:find(forbidden,1,true),path..":"..forbidden)
	end
end
print("PASS no event profile promotion paths")
