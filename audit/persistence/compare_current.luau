local fs=require('@lune/fs');local r=require('@lune/roblox');local serde=require('@lune/serde')
local reports={}
for world,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
	local base={}
	for _,row in serde.decode('json',fs.readFile('audit/latest/'..world..'/inventory.json')) do if row.file then base[row.path]=fs.readFile('audit/latest/'..world..'/'..row.file) end end
	local g=r.deserializePlace(fs.readFile(file));local report={instances=#g:GetDescendants(),changed={},conflicts={},alreadyIntegrated={},new={}}
	for _,i in g:GetDescendants() do
		if not i:IsA('LuaSourceContainer') then continue end
		local path=i:GetFullName();local relative=path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
		local snapshot='audit/current/'..world..'/'..relative;fs.writeDir(snapshot:match('^(.*)/'));fs.writeFile(snapshot,i.Source)
		local merged='audit/merged/'..world..'/'..relative
		local ours=fs.isFile(merged) and fs.readFile(merged) or nil
		local function normalize(s) return s and s:gsub('\r\n','\n') end
		if normalize(i.Source)~=normalize(base[path]) then
			table.insert(report.changed,path)
			if ours==nil then table.insert(report.new,path)
			elseif normalize(ours)==normalize(i.Source) then table.insert(report.alreadyIntegrated,path)
			elseif normalize(ours)~=normalize(base[path]) then table.insert(report.conflicts,path) end
		end
	end
	reports[world]=report;print(world,serde.encode('json',report,true))
end
fs.writeFile('audit/rebase_report.json',serde.encode('json',reports,true))
