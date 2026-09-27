-- Server-only validation shared by admin and announcement entry points.
local Validation = {}
function Validation.Finite(value)
 return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function Validation.Payload(value)
 local seen, budget = {}, 96
 local function check(item, depth)
  budget-=1
  if budget<0 then return false end
  local kind=type(item)
  if kind=="boolean" or kind=="nil" then return true end
  if kind=="number" then return Validation.Finite(item) end
  if kind=="string" then
   if #item>512 then return false end
   local numeric=tonumber(item)
   return numeric==nil or Validation.Finite(numeric)
  end
  if kind~="table" or depth>=3 or seen[item] then return false end
  seen[item]=true
  for key,child in pairs(item) do
   if type(key)~="string" or #key>64 or not check(child,depth+1) then return false end
  end
  return true
 end
 return type(value)=="table" and check(value,0)
end
function Validation.EscapeRichText(value)
 return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end
function Validation.FilterBroadcast(textService, userId, raw)
 if type(raw)~="string" or #raw==0 or #raw>512 then return nil end
 local ok, filtered=pcall(function()
  local result=textService:FilterStringAsync(raw,userId)
  return result:GetNonChatStringForBroadcastAsync()
 end)
 if not ok or type(filtered)~="string" or #filtered==0 then return nil end
 return filtered
end
function Validation.NewEventCache()
 local seen={}
 return function(id, now)
  if type(id)~="string" or #id==0 or #id>128 then return false end
  if seen[id] then return false end
  local count=0
  for key,untilTime in pairs(seen) do
   if untilTime<=now then seen[key]=nil else count+=1 end
  end
  if count>=1024 then return false end
  seen[id]=now+600
  return true
 end
end
return Validation
