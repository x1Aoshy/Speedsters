local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local output = "output/TutorialPolish"
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local paths = {
	"ReplicatedStorage/Shared/TutorialGuide.luau",
	"ReplicatedStorage/Shared/TutorialGuideLayout.luau",
	"ReplicatedStorage/Shared/AdminGlobalEvents.luau",
	"ServerScriptService/Admin/AdminAbusePanelService.server.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/CreatorFollowPopup.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau",
	"StarterGui/Backpack/BackpackScript.client.luau",
	"ReplicatedStorage/Shared/EvolveAvailability.luau",
}
local function find(root, segments)
	for _, name in segments do root = assert(root:FindFirstChild(name), name) end
	return root
end
for _, path in paths do
	local bytecode = luau.compile(fs.readFile("src/common/" .. path))
	assert(bytecode:byte(1) ~= 0, path)
	print("COMPILED", path)
end
local prepared, report = {}, {sources=paths,worlds={},studioPlaytest=false}
for _, spec in {{"World1","World1Update3New.rbxl"},{"World2","World2Update3new.rbxl"},{"World3","World3Update3New.rbxl"}} do
	local key,file = spec[1],spec[2]
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)
	local rows = {}
	for _, row in manifest.worlds[key].scripts do rows[row.source] = row end
	local prev = if fs.isFile(output.."/"..file) then rb.deserializePlace(fs.readFile(output.."/"..file)) else nil
	for _, path in paths do
		local full = "src/common/"..path
		local row = rows[full]
		if not row then
			assert(path == "ReplicatedStorage/Shared/EvolveAvailability.luau")
			row = {added=true,class="ModuleScript",duplicate=false,source=full,
				segments={"ReplicatedStorage","Shared","EvolveAvailability"},path="ReplicatedStorage.Shared.EvolveAvailability",
				legacyPath="ReplicatedStorage/Shared/EvolveAvailability"}
			table.insert(manifest.worlds[key].scripts,row)
			local node = rb.Instance.new("ModuleScript")
			node.Name,node.Parent = "EvolveAvailability", dm.ReplicatedStorage.Shared
			rows[full]=row
		end
		local node = find(dm,row.segments)
		if fs.isFile(output.."/backup/"..path) then
			assert(node.Source == fs.readFile(output.."/backup/"..path) or node.Source == fs.readFile(full)
				or (prev and node.Source == find(prev,row.segments).Source), "Unsynced source: "..key..":"..path)
		end
		node.Source = fs.readFile(full)
	end
	-- Remove retired UI if a copy was saved from a Studio session.
	for _, parent in {dm.StarterGui.Backpack.MainFrame, dm.StarterGui.Evolve.Evolve} do
		local old = parent:FindFirstChild("InfoButton")
		if old then old:Destroy() end
	end
	for _, specGui in {{dm.StarterGui.Backpack,"BackpackHelpCard"},{dm.StarterGui.Evolve,"EvolveHelpCard"},{dm.StarterGui,"CreatorFollowGui"}} do
		local old = specGui[1]:FindFirstChild(specGui[2])
		if old then old:Destroy() end
	end
	local legacyRemote = dm.ReplicatedStorage.Remotes:FindFirstChild("ShowFollowCreator")
	if legacyRemote then legacyRemote:Destroy() end
	local bar = dm.StarterGui.Mainhud.LeftSideBar
	assert(bar.Rebirth:FindFirstChild("!"), "Missing authored Rebirth badge")
	local result = rb.serializePlace(dm)
	local check = rb.deserializePlace(result)
	assert(#check:GetDescendants() == #dm:GetDescendants())
	for _, path in paths do assert(find(check,rows["src/common/"..path].segments).Source == fs.readFile("src/common/"..path),path) end
	if not fs.isFile(output.."/backup/"..file) then fs.writeFile(output.."/backup/"..file,raw) end
	fs.writeFile(output.."/"..file,result)
	table.insert(prepared,{file=file,before=raw,after=result})
	report.worlds[key]={instances=#check:GetDescendants(),sha256=serde.hash("sha256",result)}
	print("VERIFIED",key)
end
for _, item in prepared do assert(fs.readFile(item.file)==item.before,"Concurrent edit") end
for _, item in prepared do fs.writeFile(item.file,item.after) end
local unique = {}
for _, world in manifest.worlds do for _, row in world.scripts do
	if row.source:sub(1,11)=="src/common/" then unique[row.source]=true end
end end
local count=0
for _ in unique do count+=1 end
manifest.commonSources=count
fs.writeFile("src/manifest.json",serde.encode("json",manifest,true))
fs.writeFile(output.."/validation.json",serde.encode("json",report,true))
print("SAVED",output)
