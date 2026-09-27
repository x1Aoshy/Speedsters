-- audit/u4_title_templates.luau (Update 4, titles_boards, 2026-09-25)
-- Lune helper the Update 4 build calls: adds the three new overhead title templates to
-- ReplicatedStorage.Titles next to the authored Dev and Tester parts. Bootstrap clones the one
-- TitleService.Visual names (Shared/TitleCatalog Template) above the player's head.
--   Plain  = Tester without any ParticleEmitter (most titles: no particles, no animation, so
--            phones pay nothing for them);
--   Gold   = Tester keeping 2 emitters, recoloured gold (the #1 titles and the legends);
--   Owner  = Dev recoloured gold (emitters and text gradient).
-- Idempotent: a template stamped U4Asset = "TitleTemplate" is replaced; one with the same name
-- and no stamp was made by someone else and stops the build.
local roblox = require("@lune/roblox")
local Color3, ColorSequence, ColorSequenceKeypoint = roblox.Color3, roblox.ColorSequence, roblox.ColorSequenceKeypoint

local Templates = {}

Templates.Stamp = "TitleTemplate"
Templates.Names = { "Plain", "Gold", "Owner" }
Templates.Gold = Color3.fromRGB(255, 211, 33)
Templates.GoldDeep = Color3.fromRGB(255, 150, 20)

local function emitters(part)
	local out = {}
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(out, descendant)
		end
	end
	return out
end

local function label(part)
	local attachment = part:FindFirstChild("Title")
	local billboard = attachment and attachment:FindFirstChild("BillboardGui")
	local text = billboard and billboard:FindFirstChild("Title")
	return if text and text:IsA("TextLabel") then text else nil
end

local function gradientOf(part)
	local text = label(part)
	return text and text:FindFirstChildOfClass("UIGradient")
end

local function goldSequence()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Templates.Gold),
		ColorSequenceKeypoint.new(1, Templates.GoldDeep),
	})
end

-- Insert(dm, notes) -> number of templates written (3). Errors when Dev/Tester are missing or a
-- same-named template has no stamp.
function Templates.Insert(dm, notes)
	local folder = dm:GetService("ReplicatedStorage"):FindFirstChild("Titles")
	assert(folder, "[u4_title_templates] ReplicatedStorage.Titles is missing")
	local tester, dev = folder:FindFirstChild("Tester"), folder:FindFirstChild("Dev")
	assert(tester and tester:IsA("BasePart"), "[u4_title_templates] Titles.Tester is missing")
	assert(dev and dev:IsA("BasePart"), "[u4_title_templates] Titles.Dev is missing")
	for _, name in Templates.Names do
		local existing = folder:FindFirstChild(name)
		if existing then
			assert(existing:GetAttribute("U4Asset") == Templates.Stamp,
				"[u4_title_templates] Titles." .. name .. " exists without the U4Asset stamp; not replacing it")
			existing.Parent = nil
		end
	end

	local plain = tester:Clone()
	plain.Name = "Plain"
	for _, emitter in emitters(plain) do
		emitter.Parent = nil
	end

	local gold = tester:Clone()
	gold.Name = "Gold"
	for index, emitter in emitters(gold) do
		if index > 2 then
			emitter.Parent = nil
		else
			emitter.Color = roblox.ColorSequence.new(Templates.Gold)
			emitter.Enabled = false
		end
	end
	local goldGradient = gradientOf(gold)
	if goldGradient then
		goldGradient.Color = goldSequence()
	end

	local owner = dev:Clone()
	owner.Name = "Owner"
	for _, emitter in emitters(owner) do
		emitter.Color = goldSequence()
		emitter.Enabled = false
	end
	local ownerGradient = gradientOf(owner)
	if ownerGradient then
		ownerGradient.Color = goldSequence()
	end

	for _, template in { plain, gold, owner } do
		local text = label(template)
		if text then
			text.Text = "" -- Bootstrap writes the title's own text (TitleService.Visual)
		end
		template:SetAttribute("U4Asset", Templates.Stamp)
		template.Parent = folder
	end
	if type(notes) == "table" then
		table.insert(notes, "title templates Plain/Gold/Owner")
	end
	return #Templates.Names
end

Templates._internal = { emitters = emitters, label = label }

return Templates
