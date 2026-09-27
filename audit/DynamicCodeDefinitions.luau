local Definitions={}
function Definitions.Validate(record,code)
	if type(code)~="string" or #code<1 or #code>40 or not code:match("^[a-z0-9_]+$") then return nil end
	if type(record)~="table" then return nil end
	local stat,amount=record.StatName,record.StatAmount
	if stat~="Speed" and stat~="Wins" and stat~="Rebirths" then return nil end
	if type(amount)~="number" or amount~=amount or amount<1 or amount>1e14 or amount%1~=0 then return nil end
	return {Marker="AdminDynamicCode_"..code.."_v1",[stat]=amount}
end
function Definitions.new(store)
	local cached={};local count=0
	return {Get=function(_,submitted)
		if type(submitted)~="string" then return nil end
		local code=submitted:lower():match("^%s*(.-)%s*$")
		if #code<1 or #code>40 or not code:match("^[a-z0-9_]+$") then return nil end
		local entry=cached[code]
		if entry and os.clock()<entry.untilTime then return entry.value end
		local ok,record=pcall(function() return store:GetAsync("code_"..code) end)
		if not ok then return nil,"unavailable" end
		local value=Definitions.Validate(record,code)
		if count>=128 then cached={};count=0 end
		if not cached[code] then count+=1 end
		cached[code]={value=value,untilTime=os.clock()+(value and 300 or 5)}
		return value
	end}
end
return Definitions
