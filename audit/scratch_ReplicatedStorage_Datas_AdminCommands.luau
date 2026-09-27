
local v0 = {};
for _, v2 in script:GetChildren() do
	if v2:IsA("ModuleScript") then
		v0[v2.Name] = require(v2);
	end;
end;
return v0;