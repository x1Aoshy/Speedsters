local fs=require('@lune/fs');local rb=require('@lune/roblox')
local dm=rb.deserializePlace(fs.readFile('World1Update3New.rbxl'))
local gui=dm:GetService('StarterGui'):FindFirstChild('SpinWheelGui')
local function show(node,depth,max)
 if not node then return end
 print(string.rep(' ',depth)..node.Name..' '..node.ClassName)
 if depth>=max then return end
 for _,child in node:GetChildren() do show(child,depth+1,max) end
end
show(gui,0,4)
