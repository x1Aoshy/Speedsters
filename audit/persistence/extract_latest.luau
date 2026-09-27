local fs=require('@lune/fs')
local r=require('@lune/roblox')
local serde=require('@lune/serde')
for label,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
	local g=r.deserializePlace(fs.readFile(file));local rows={}
	fs.writeDir('audit/latest/'..label)
	for i,inst in g:GetDescendants() do
		local row={id=i,path=inst:GetFullName(),class=inst.ClassName}
		if inst:IsA('LuaSourceContainer') then
			row.file=tostring(i)..'.luau'
			fs.writeFile('audit/latest/'..label..'/'..row.file,inst.Source)
			if inst:IsA('BaseScript') then row.disabled=inst.Disabled end
		end
		table.insert(rows,row)
	end
	fs.writeFile('audit/latest/'..label..'/inventory.json',serde.encode('json',rows,true))
	print(label,#rows,'world attribute',g:GetService('ReplicatedStorage'):GetAttribute('PlaceWorldNumber'))
end

