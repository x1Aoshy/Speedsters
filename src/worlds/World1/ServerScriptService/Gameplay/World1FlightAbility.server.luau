-- Compatibility entrypoint; the implementation is shared between all worlds.
local ServerScriptService = game:GetService("ServerScriptService")
require(ServerScriptService:WaitForChild("Core"):WaitForChild("Abilities"):WaitForChild("FlightService")).Start()
