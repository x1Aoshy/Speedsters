-- ParticleFlipbooks: sprite-sheet particle textures need their grid declared.
--
-- Several textures this game builds emitters with in code are 4x4 sheets of animation frames
-- (they come from the taco/firework VFX). An emitter made with Instance.new has
-- FlipbookLayout = None, so it drew the WHOLE sheet on every particle: the clusters of sixteen
-- little dots that looked like broken particles. Apply() gives an emitter the layout its
-- texture needs; it is a no-op for anything else, so it is safe to call after any
-- `x.Texture = ...`.
local Flipbooks = {}

-- texture id -> { layout, mode, frames per second (Loop/PingPong only) }
Flipbooks.Sheets = {
	["13802408466"] = { "Grid4x4", "OneShot", 8 }, -- the yellow / red / green taco flakes
	["8733488500"] = { "Grid4x4", "OneShot", 1 }, -- pixel blob (fireworks, splashes)
	["116373783921886"] = { "Grid4x4", "OneShot", 1 }, -- pixel burst
	["18802780455"] = { "Grid4x4", "OneShot", 1 }, -- fire specs
	["123944207040840"] = { "Grid4x4", "OneShot", 1 }, -- fire specs (orange)
	["16551638647"] = { "Grid4x4", "OneShot", 1 }, -- hit spark
	["15435367107"] = { "Grid4x4", "OneShot", 1 },
	["17629991673"] = { "Grid4x4", "OneShot", 1 }, -- sharp
	["14687560696"] = { "Grid4x4", "OneShot", 1 }, -- circle
	["11866495294"] = { "Grid4x4", "OneShot", 1 }, -- pixelated smoke puff
	["16888340643"] = { "Grid4x4", "OneShot", 1 },
}

function Flipbooks.IdOf(texture)
	return type(texture) == "string" and string.match(texture, "(%d+)%s*$") or nil
end

function Flipbooks.Apply(emitter)
	local ok, isEmitter = pcall(function()
		return emitter:IsA("ParticleEmitter")
	end)
	if not ok or not isEmitter then
		return false
	end
	local sheet = Flipbooks.Sheets[Flipbooks.IdOf(emitter.Texture) or ""]
	if not sheet then
		return false
	end
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout[sheet[1]]
	emitter.FlipbookMode = Enum.ParticleFlipbookMode[sheet[2]]
	emitter.FlipbookFramerate = NumberRange.new(sheet[3])
	return true
end

function Flipbooks.ApplyAll(root)
	local count = 0
	for _, item in root:GetDescendants() do
		if Flipbooks.Apply(item) then
			count += 1
		end
	end
	return count
end

return Flipbooks
