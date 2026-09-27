local fs=require('@lune/fs')
local function replace(s,a,b)
	local x,y=s:find(a,1,true);assert(x,'Missing anchor '..a:sub(1,70))
	return s:sub(1,x-1)..b..s:sub(y+1)
end
local function beforeReturn(s,name,extra) return replace(s,'\nreturn '..name..'\n','\n'..extra..'\nreturn '..name..'\n') end
local root='audit/fixed/V2/'
local function edit(path,fn)
	local src=fs.readFile('audit/patched/V2/'..path)
	fs.writeFile(root..path,fn(src))
end
edit('ServerScriptService/Services/Data/SessionActor.luau',function(s)
	local start=s:find('-- DataStore yields must',1,true)
	if start then s=s:sub(1,start-1)..'return SessionActor\n' end
	-- Remove replaced implementations rather than shipping two authoritative paths.
	for _,pair in {{'Commit','SetPreference'},{'Flush','Quiesce'},{'Quiesce','Release'},{'Release','Subscribe'}} do
		local first=assert(s:find('function SessionActor:'..pair[1]..'(',1,true))
		local last=assert(s:find('function SessionActor:'..pair[2]..'(',first,true))
		s=s:sub(1,first-1)..s:sub(last)
	end
	return beforeReturn(s,'SessionActor',fs.readFile('audit/persistence/ActorOverrides.luau'))
end)
edit('ServerScriptService/Services/Data/ProfileCodec.luau',function(s)
	return beforeReturn(s,'ProfileCodec',[=[
local decodeBase,encodeBase=ProfileCodec.Decode,ProfileCodec.Encode
local function copyOperations(raw)
	local copy={}
	if type(raw)=="table" then
		for id,entry in pairs(raw) do
			if type(id)=="string" and type(entry)=="table" and type(entry.fingerprint)=="string" then
				copy[id]={fingerprint=entry.fingerprint,time=tonumber(entry.time) or 0}
			end
		end
	end
	return copy
end
function ProfileCodec.Decode(raw,validator)
	local result=decodeBase(raw,validator)
	if result.ok then
		result.value.Update2WriteId=type(raw)=="table" and raw.Update2WriteId or nil
		result.value.Update2Operations=copyOperations(type(raw)=="table" and raw.Update2Operations or nil)
	end
	return result
end
function ProfileCodec.Encode(profile)
	local result=encodeBase(profile)
	result.Update2WriteId=profile.Update2WriteId
	result.Update2Operations=copyOperations(profile.Update2Operations)
	return result
end
]=])
end)
edit('ServerScriptService/Services/Data/ProfileReducers.luau',function(s)
	return beforeReturn(s,'ProfileReducers',fs.readFile('audit/persistence/Reducers.luau'))
end)
edit('ServerScriptService/Services/Data/DataService.luau',function(s)
	s=replace(s,'\t\telse\n\t\t\t-- Estado terminal previo: limpiar y reabrir',[=[
		elseif existingActor.profile and existingActor.state ~= "Closed" and existingActor.state ~= "Released" and existingActor.state ~= "Lost" then
			return {ok=false,error={code="NotReady",message="Previous session has unconfirmed data",retryable=true}}
		else
			-- Estado terminal previo: limpiar y reabrir]=])
	return beforeReturn(s,'DataService',fs.readFile('audit/persistence/Lifecycle.luau'))
end)
edit('ServerScriptService/Services/Stats/StatsProjection.luau',function(s)
	s=replace(s,'player:SetAttribute("DataLoaded", true)','player:SetAttribute("DataLoaded", view.state == "Ready" or view.state == "Ephemeral")')
	return s
end)
print('Core persistence changes written to audit/fixed/V2')
