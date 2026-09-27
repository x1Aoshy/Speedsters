local fs=require('@lune/fs');local r=require('@lune/roblox');local serde=require('@lune/serde')
local files={World1='World1 Speedtercorrect.rbxl',World2='World2Old has to be synced with world1updated the p[ad bug still.rbxl'}
local reports={}
for world,file in files do
	local raw=fs.readFile(file);local g=r.deserializePlace(raw)
	local dir='audit/incoming_20260913/'..world
	fs.writeDir(dir);fs.writeFile(dir..'/input.rbxl',raw)
	local rows={};local names={};local different={};local count=0
	for n,i in g:GetDescendants() do
		local row={id=n,path=i:GetFullName(),class=i.ClassName}
		if i:IsA('LuaSourceContainer') then
			count+=1;row.file=tostring(n)..'.luau';fs.writeFile(dir..'/'..row.file,i.Source)
			if i:IsA('BaseScript') then row.disabled=i.Disabled end
			names[row.path]=(names[row.path] or 0)+1
			local path='audit/merged/'..world..'/'..row.path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
			if not fs.isFile(path) or fs.readFile(path)~=i.Source then table.insert(different,row.path) end
		end
		table.insert(rows,row)
	end
	local duplicates={};for path,n in names do if n>1 then duplicates[path]=n end end
	fs.writeFile(dir..'/inventory.json',serde.encode('json',rows,true))
	reports[world]={file=file,instances=#g:GetDescendants(),scripts=count,differentFromMerged=different,duplicateScriptPaths=duplicates,
		world=g:GetService('ReplicatedStorage'):GetAttribute('PlaceWorldNumber'),rankGuiInStarter=g:GetService('StarterGui'):FindFirstChild('RankRewardGui')~=nil}
	print(world,serde.encode('json',reports[world],true))
end
fs.writeFile('audit/incoming_20260913/summary.json',serde.encode('json',reports,true))
