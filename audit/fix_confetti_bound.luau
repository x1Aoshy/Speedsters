local fs=require('@lune/fs')
local function replace(s,a,b) local x,y=s:find(a,1,true);assert(x,a);return s:sub(1,x-1)..b..s:sub(y+1) end
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/ServerScriptService/Admin/AdminAbuseServer.luau';local s=fs.readFile(path)
 s=replace(s,'local activeConfetti = {}',[[local activeConfetti = {}
local MAX_ACTIVE_CONFETTI = 240
local confettiLastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - confettiLastUpdate < 0.1 then return end
	local dt = math.min(now - confettiLastUpdate, 0.25)
	confettiLastUpdate = now
	for id, entry in pairs(activeConfetti) do
		local part = entry.Part
		if not part.Parent then activeConfetti[id] = nil
		else
			part.Color = Color3.fromHSV((entry.Hue + now * 0.15) % 1, 1, 1)
			part.CFrame = part.CFrame * CFrame.Angles(0, 15 * dt, 0)
		end
	end
end)]])
 s=replace(s,'local spawnCount = math.clamp(tonumber(count) or CONFETTI_COUNT, 1, 120)',[[local spawnCount = math.floor(math.clamp(tonumber(count) or CONFETTI_COUNT, 1, 120))
	local activeCount = 0
	for _,entry in pairs(activeConfetti) do if entry.Part.Parent then activeCount += 1 end end
	spawnCount = math.min(spawnCount, MAX_ACTIVE_CONFETTI - activeCount)
	if spawnCount <= 0 then return end]])
 local first=s:find('\t\tactiveConfetti[id] = { Part = part, Claimed = false }',1,true)
 local last=s:find('\t\tprompt.Triggered:Connect',first,true)
 s=s:sub(1,first-1)..'\t\tactiveConfetti[id] = { Part = part, Claimed = false, Hue = math.random() }\n\n'..s:sub(last)
 s=replace(s,'\t\t\t\tif bobConn then bobConn:Disconnect() end\n','')
 fs.writeFile(path,s)
end
print('Confetti global cap and shared 10Hz update installed')
