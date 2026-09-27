-- audit/capture_taco_meteor_assets.luau  (2026-09-20)
-- Takes the fire VFX the taco meteor wears out of the V40 place into src/ui/TacoMeteorAssets.rbxm:
--   Wrap  - the orange fireball (event "Bombardiro Crocodilo", part Explosion), runs while it falls
--   Boom  - the explosion burst of the same event (part ExplosionBoom), fired once on impact
--   Jet   - the flamethrower's flame + smoke (1 Year map), the tail behind the meteor
--   Trail - the Starfall meteor's Trail
-- Particle emitters only: no scripts, no sounds (the V40 sounds are another group's private
-- audio and would not play in this game). Flipbook layouts are checked after saving, because a
-- lost layout is what made the taco flakes look broken.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local v40 = rb.deserializePlace(fs.readFile("Outdated/V40 SAB by FaypleStudios.rbxl"))
local rs = v40:GetService("ReplicatedStorage")
local events = rs.Controllers.EventController.Events

local folder = rb.Instance.new("Folder")
folder.Name = "TacoMeteorAssets"

local function clean(instance)
	for _, item in instance:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	for _, item in instance:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			item.Transparency = 1
			item.CastShadow = false
		elseif item:IsA("ParticleEmitter") then
			item.Enabled = false
		end
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide, instance.CanTouch, instance.CanQuery = false, false, false
		instance.Transparency = 1
	end
	return instance
end

local bombardiro = events["Bombardiro Crocodilo"]
local wrap = clean(bombardiro.Explosion:Clone())
wrap.Name = "Wrap"
wrap.Parent = folder
local boom = clean(bombardiro.ExplosionBoom:Clone())
boom.Name = "Boom"
boom.Parent = folder

local flamethrower = rs.Models.Events["1 Year"].AnniversaryMap.StageFeatures.Flamethrowers:GetChildren()[1]
local jet = rb.Instance.new("Part")
jet.Name = "Jet"
jet.Size = rb.Vector3.new(1, 1, 1)
local flame = flamethrower.Tip.Flame:Clone()
flame.CFrame = rb.CFrame.new(0, 0, 0)
flame.Parent = jet
clean(jet)
jet.Parent = folder

local trail = events.Starfall.Meteor.Trail:Clone()
trail.Name = "Trail"
trail.Enabled = false
trail.Parent = folder

local function layouts(root)
	local out = {}
	for _, item in root:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			table.insert(out, item.Name .. ":" .. tostring(item.FlipbookLayout) .. ":" .. tostring(item.FlipbookMode))
		end
	end
	table.sort(out)
	return table.concat(out, "|")
end
local before = layouts(folder)
fs.writeFile("src/ui/TacoMeteorAssets.rbxm", rb.serializeModel({ folder }))
local saved = rb.deserializeModel(fs.readFile("src/ui/TacoMeteorAssets.rbxm"))[1]
assert(layouts(saved) == before, "flipbook layouts were lost while saving")
local emitters, scripts = 0, 0
for _, item in saved:GetDescendants() do
	if item:IsA("ParticleEmitter") then emitters += 1 end
	if item:IsA("LuaSourceContainer") or item:IsA("Sound") then scripts += 1 end
end
assert(scripts == 0 and emitters > 40, "unexpected content")
print(("saved src/ui/TacoMeteorAssets.rbxm: %d emitters (Wrap %d, Boom %d, Jet %d), flipbook layouts intact"):format(
	emitters, #saved.Wrap:GetDescendants(), #saved.Boom:GetDescendants(), #saved.Jet:GetDescendants()))
