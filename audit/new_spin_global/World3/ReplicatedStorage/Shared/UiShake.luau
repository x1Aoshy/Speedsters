--!strict
-- UiShake.luau
-- Reusable HUD "juice": a rotation wiggle and a positional jitter, both decaying to
-- rest. A new shake on the same object replaces the running one, and every shake
-- ends by restoring the exact value it started from, so nothing can be left tilted
-- or nudged off its authored position. Nothing here changes a Size.

local RunService = game:GetService("RunService")

local UiShake = {}

type Entry = { token: number, restore: () -> () }

local running: { [string]: { [GuiObject]: Entry } } = {
	Rotation = setmetatable({}, { __mode = "k" }) :: any,
	Position = setmetatable({}, { __mode = "k" }) :: any,
}
local serial = 0

local function begin(kind: string, object: GuiObject, restore: () -> ()): number
	local registry = running[kind]
	local current = registry[object]
	if current then
		registry[object] = nil
		current.restore()
	end
	serial += 1
	registry[object] = { token = serial, restore = restore }
	return serial
end

local function drive(kind: string, object: GuiObject, token: number, duration: number, step: (elapsed: number, decay: number) -> ())
	local registry = running[kind]
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local entry = registry[object]
		if not entry or entry.token ~= token then
			connection:Disconnect()
			return
		end
		elapsed += dt
		if elapsed >= duration or object.Parent == nil then
			connection:Disconnect()
			registry[object] = nil
			entry.restore()
			return
		end
		local decay = (1 - elapsed / duration) ^ 2
		step(elapsed, decay)
	end)
end

-- Rotation wiggle. `amplitude` in degrees, `frequency` in wiggles per second.
function UiShake.Wiggle(object: GuiObject, amplitude: number?, duration: number?, frequency: number?)
	local base: number
	local token = begin("Rotation", object, function()
		object.Rotation = base
	end)
	-- Read only after begin() has put a running wiggle back to its own start: read
	-- earlier, a second tap mid-wiggle took the tilted angle as "rest" and kept it.
	base = object.Rotation
	local amp = amplitude or 12
	local hz = frequency or 7
	drive("Rotation", object, token, duration or 0.5, function(elapsed, decay)
		object.Rotation = base + math.sin(elapsed * hz * math.pi * 2) * amp * decay
	end)
end

-- Positional jitter. `amplitude` in pixels, `frequency` in shakes per second.
function UiShake.Jitter(object: GuiObject, amplitude: number?, duration: number?, frequency: number?)
	local base: UDim2
	local token = begin("Position", object, function()
		object.Position = base
	end)
	base = object.Position
	local amp = amplitude or 8
	local hz = frequency or 18
	drive("Position", object, token, duration or 0.4, function(elapsed, decay)
		local x = math.sin(elapsed * hz * math.pi * 2) * amp * decay
		local y = math.cos(elapsed * hz * 1.7 * math.pi * 2) * amp * 0.3 * decay
		object.Position = base + UDim2.fromOffset(x, y)
	end)
end

-- True while a shake of this kind is still running on `object`.
function UiShake.IsShaking(object: GuiObject, kind: string?): boolean
	local registry = running[kind or "Rotation"]
	return registry ~= nil and registry[object] ~= nil
end

return UiShake
