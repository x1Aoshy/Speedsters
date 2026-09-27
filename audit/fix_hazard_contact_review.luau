local fs=require('@lune/fs')
local function edit(path,fn) local s=fs.readFile(path):gsub('\r\n','\n'); fs.writeFile(path,fn(s)) end
local function replace(s,old,new) local a,b=s:find(old,1,true); assert(a,'missing '..old:sub(1,100)); return s:sub(1,a-1)..new..s:sub(b+1) end
local body=[[local HAZARD_BODY_NAMES = {
 Head=true, Torso=true, UpperTorso=true, LowerTorso=true,
 ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
 LeftUpperArm=true, LeftLowerArm=true, LeftHand=true, RightUpperArm=true, RightLowerArm=true, RightHand=true,
 LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true, RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
}
local function isHazardBodyPart(part, character)
 return part and part:IsA("BasePart") and part.Parent == character and HAZARD_BODY_NAMES[part.Name] == true
end
]]
edit('audit/merged/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.luau',function(s)
 s=replace(s,'local locallyKilledCharacter = nil','local locallyKilledCharacter = nil\nlocal characterConnections = {}')
 s=replace(s,'for _, descendant in ipairs(character:GetDescendants()) do','for _, descendant in ipairs(character:GetChildren()) do')
 s=replace(s,'local function refreshCharacter(newCharacter)\n','local function refreshCharacter(newCharacter)\n\tfor _, connection in ipairs(characterConnections) do connection:Disconnect() end\n\ttable.clear(characterConnections)\n')
 s=replace(s,'character.DescendantAdded:Connect(function(descendant)','table.insert(characterConnections, character.ChildAdded:Connect(function(descendant)')
 s=replace(s,'\t\tend)\n\t\tcharacter.DescendantRemoving:Connect(function(descendant)','\t\tend))\n\t\ttable.insert(characterConnections, character.ChildRemoved:Connect(function(descendant)')
 s=replace(s,'\t\tend)\n\tend\nend\n\nplayer.CharacterAdded','\t\tend))\n\tend\nend\n\nplayer.CharacterAdded')
 s=replace(s,'return player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true','return player:GetAttribute("StageTeleportInvulnerable") == true\n\t\tor player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true')
 s=replace(s,'bodyPart and bodyPart.Parent then','bodyPart and bodyPart.Parent == character then')
 return s
end)
edit('audit/merged/World2/ServerScriptService/Gameplay/World2TreeSlammers.luau',function(s)
 s=replace(s,'local lastServerConfirmAt = {}',body..'\nlocal lastServerConfirmAt = {}')
 s=replace(s,'return player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true','return player:GetAttribute("StageTeleportInvulnerable") == true\n\t\tor player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true')
 s=replace(s,'\ttreeIndex = tonumber(treeIndex)\n\tif not treeIndex or treeIndex < 1 or treeIndex > TREE_COUNT then','\tif type(treeIndex) ~= "number" or treeIndex ~= treeIndex or treeIndex % 1 ~= 0 or treeIndex < 1 or treeIndex > TREE_COUNT then')
 s=replace(s,'\thumanoid.Health = 0\nend)',[=[	local tree = treeObjects[treeIndex]
	if not tree or not tree.Parent then return end
	local bodyParts = {}
	for _, part in ipairs(character:GetChildren()) do
		if isHazardBodyPart(part, character) then table.insert(bodyParts, part) end
	end
	if #bodyParts == 0 then return end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = bodyParts
	params.RespectCanCollide = false
	params.MaxParts = 1
	for _, part in ipairs(getPhysicalParts(tree)) do
		if part.Transparency < 0.95 and #Workspace:GetPartsInPart(part, params) > 0 then
			humanoid.Health = 0
			return
		end
	end
end)]=])
 return s
end)
edit('audit/merged/World1/ServerScriptService/Gameplay/Presser1Controller.luau',function(s)
 local a=s:find('local function findPlayerHumanoid(hit)',1,true)
 local b=s:find('\nlocal function startPresser',a,true)
 assert(a and b)
 s=s:sub(1,a-1)..body..[=[
local function findPlayerHumanoid(hit)
 local character = hit and hit.Parent
 if not character or not isHazardBodyPart(hit, character) then return nil, nil, nil end
 local player = Players:GetPlayerFromCharacter(character)
 local humanoid = player and character:FindFirstChildOfClass("Humanoid")
 if humanoid then return humanoid, character, player end
 return nil, nil, nil
end

-- Broad-phase boxes only find candidates. The cast uses the authored shape.
local function sweptBodyContact(part, previousCFrame, bodyPart)
 local displacement = previousCFrame.Position - part.Position
 if displacement.Magnitude <= 0.0001 then return false end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances = { bodyPart }
 params.RespectCanCollide = false
 return Workspace:Shapecast(part, displacement, params) ~= nil
end
]=]..s:sub(b)
 s=replace(s,'\t\t\t\t\tkillFromHit(crossedPart)','\t\t\t\t\tlocal humanoid = findPlayerHumanoid(crossedPart)\n\t\t\t\t\tif humanoid and humanoid.Health > 0 and sweptBodyContact(part, previousCFrame, crossedPart) then\n\t\t\t\t\t\tkillFromHit(crossedPart)\n\t\t\t\t\tend')
 return s
end)
edit('audit/merged/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.luau',function(s)
 local a=s:find('local hammerCharacterOverlapParams =',1,true)
 local b=s:find('\nlocal function exactHammerTouchesCharacter',a,true)
 assert(a and b)
 s=s:sub(1,a-1)..[=[-- A character can receive body parts after the first collision query (avatar loading).
-- Build this small list from direct children so respawns/accessories cannot leave stale filters.
local function getHammerCharacterOverlapParams(character)
 local bodyParts = {}
 for _, child in ipairs(character:GetChildren()) do
  if child:IsA("BasePart") and HAMMER_VISIBLE_BODY_NAMES[normalizeName(child.Name)] then table.insert(bodyParts, child) end
 end
 local params = OverlapParams.new()
 params.FilterType = Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances = bodyParts
 params.MaxParts = 1
 params.RespectCanCollide = false
 return params
end
]=]..s:sub(b)
 return s
end)
print('hazard contact review patches applied')

