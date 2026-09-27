-- One-time extraction. Runtime behavior stays server-side; both entrypoints share one module.
local fs = require('@lune/fs')
local function read(world)
 return fs.readFile('audit/merged/'..world..'/ServerScriptService/Gameplay/'..world..'FlightAbility.luau'):gsub('\r\n','\n'):gsub('%[World[12]FlightAbility%]', '[FlightService]')
end
local body = read('World1')
assert(body == read('World2'), 'Flight implementations differ beyond their diagnostic label')
assert(not body:find('script[%.:]'), 'Review script-relative dependencies before extraction')
local source = '-- Shared private service. Require is side-effect free; Start is idempotent.\n'
 .. 'local FlightService = {}\nlocal state = "idle"\nlocal failure\n\nlocal function initialize()\n'
 .. body .. '\nend\n\n'
 .. [[function FlightService.Start()
 if state == "started" or state == "starting" then return end
 if state == "failed" then error(failure, 2) end
 state = "starting"
 local ok, reason = pcall(initialize)
 if not ok then
  -- Do not retry partially connected startup and duplicate purchase handlers.
  state = "failed"
  failure = "[FlightService] startup failed: " .. tostring(reason)
  error(failure, 2)
 end
 state = "started"
end

return FlightService
]]
for _, world in {'World1','World2'} do
 local dir = 'audit/merged/'..world..'/ServerScriptService/'
 fs.writeDir(dir..'Core/Abilities')
 fs.writeFile(dir..'Core/Abilities/FlightService.luau', source)
 fs.writeFile(dir..'Gameplay/'..world..'FlightAbility.luau', [[-- Compatibility entrypoint; the implementation is shared between all worlds.
local ServerScriptService = game:GetService("ServerScriptService")
require(ServerScriptService:WaitForChild("Core"):WaitForChild("Abilities"):WaitForChild("FlightService")).Start()
]])
end
for _, path in {'audit/test_stamina_replication.luau','audit/persistence/test_geko_flight.luau'} do
 local s = fs.readFile(path)
 if path:find('stamina') then
  s = s:gsub("base %.%. 'Gameplay/' %.%. world %.%. 'FlightAbility.luau'", "base .. 'Core/Abilities/FlightService.luau'")
 else
  s = s:gsub('local flightServerPath = [^\r\n]+', 'local flightServerPath = "audit/merged/" .. world .. "/ServerScriptService/Core/Abilities/FlightService.luau"')
 end
 fs.writeFile(path,s)
end
print('Extracted FlightService and preserved both legacy Script entrypoints')
