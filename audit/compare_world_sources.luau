local fs=require('@lune/fs')
local function walk(relative)
	for _,name in fs.readDir('audit/merged/World1/'..relative) do
		local path=relative..name
		if fs.isDir('audit/merged/World1/'..path) then walk(path..'/')
		elseif fs.isFile('audit/merged/World2/'..path) then
			local a=fs.readFile('audit/merged/World1/'..path):gsub('\r\n','\n')
			local b=fs.readFile('audit/merged/World2/'..path):gsub('\r\n','\n')
			if a~=b then print(path,#a,#b) end
		end
	end
end
walk('')
