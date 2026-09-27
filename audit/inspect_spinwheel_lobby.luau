local fs=require('@lune/fs');local rb=require('@lune/roblox')
for _,file in {'World1Update3New.rbxl','World2Update3new.rbxl','World3Update3New.rbxl'} do
 local dm=rb.deserializePlace(fs.readFile(file));local w=dm:GetService('Workspace')
 local model=w:FindFirstChild('SpinWheelLobby') or w:FindFirstChild('SpinWheel')
 print(file,model and model.ClassName or 'MISSING',model and model.Name or '',model and tostring(model.ModelStreamingMode) or '',model and #model:GetDescendants() or 0)
 if model then for _,name in {'Face','Overhead','PromptAnchor'} do local x=model:FindFirstChild(name);print(' ',name,x and x.ClassName or 'MISSING') end end
end
