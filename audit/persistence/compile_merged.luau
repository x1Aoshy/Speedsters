local fs=require('@lune/fs')
local luau=require('@lune/luau')
local function walk(dir)
 for _,n in fs.readDir(dir) do
  local path=dir..'/'..n
  if fs.isDir(path) then walk(path)
  elseif path:sub(-5)=='.luau' then
   local ok,e=pcall(luau.compile,fs.readFile(path));if not ok then error(path..'\n'..tostring(e)) end
  end
 end
end
walk('audit/merged');print('PASS all merged sources compile')
