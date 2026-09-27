-- Draft of the offline test for the overhead titles (read-only: the proposed client functions
-- are embedded here as they would be sliced out of OverheadStats.client.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local source = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau")
local first = assert(source:find("local function layoutTitleBoard", 1, true))
local last = assert(source:find("local activeTitleAnimations", first, true))
local PROPOSED = source:sub(first, last - 1)


local Config = {
	OverheadStudsOffset = rb.Vector3.new(0, 2.65, 0),
	OverheadTitleHeight = 34,
	OverheadTitleGap = 5,
	TitleParticleHeight = 4,
	TitleParticleDrop = 0.2,
}
local api = luau.load(PROPOSED .. "\nreturn { layout = layoutTitleBoard, lift = titleParticleLift }", {
	environment = { Config = Config, UDim2 = rb.UDim2, Vector2 = rb.Vector2, Vector3 = rb.Vector3, OVERHEAD_MAX_DISTANCE = 37, tonumber = tonumber, math = math },
})()

-- The strip of the text in pixels over the board's anchor, from the instances themselves.
local function strip(billboard, label)
	assert(billboard.Size.X.Scale == 0 and billboard.Size.Y.Scale == 0, "the board is sized in pixels")
	local height = billboard.Size.Y.Offset
	local top = billboard.SizeOffset.Y * height + height / 2
	local labelHeight = label.Size.Y.Scale * height + label.Size.Y.Offset
	local labelTop = top - (label.Position.Y.Scale * height + label.Position.Y.Offset) + label.AnchorPoint.Y * labelHeight
	return labelTop - labelHeight, labelTop
end

local root = rb.deserializeModel(fs.readFile("src/assets/Titles.rbxm"))[1]
local count = 0
for _, part in root:GetChildren() do
	assert(part:IsA("BasePart"), part.Name .. " is a part")
	local attachment = assert(part:FindFirstChild("Title"), part.Name .. ": Title attachment")
	local billboard = assert(attachment:FindFirstChild("BillboardGui"), part.Name .. ": BillboardGui")
	local label = assert(billboard:FindFirstChild("Title"), part.Name .. ": Title label")
	local head = rb.Instance.new("Part")
	head.Name = "Head"
	head.Parent = root -- Lune only keeps an instance reference inside the same tree
	api.layout(billboard, label, head)
	local bottom, top = strip(billboard, label)
	assert(bottom == 35 + Config.OverheadTitleGap, part.Name .. ": the text starts " .. Config.OverheadTitleGap .. " px over the name board, got " .. bottom)
	assert(top == bottom + Config.OverheadTitleHeight, part.Name .. ": the text is " .. Config.OverheadTitleHeight .. " px tall")
	-- Vector3 is float32 in Lune (2.65 reads back 2.649994): compare with a tolerance.
	assert(billboard.Adornee == head and (billboard.StudsOffsetWorldSpace - Config.OverheadStudsOffset).Magnitude < 1e-4, part.Name .. ": on the head's anchor")
	assert(billboard.StudsOffset == rb.Vector3.zero and billboard.ExtentsOffset == rb.Vector3.zero and billboard.ExtentsOffsetWorldSpace == rb.Vector3.zero, part.Name .. ": no other offset")
	assert(label.AnchorPoint.X == 0.5 and label.Position.X.Scale == 0.5 and label.Size.X.Scale == 1, part.Name .. ": centred over the head")
	local emitters = 0
	for _, child in part:GetChildren() do
		if child:IsA("ParticleEmitter") then
			emitters += 1
			assert(child.LockedToPart, part.Name .. ": particles ride with the part")
		end
	end
	assert(emitters > 0, part.Name .. ": has particles")
	count += 1
end
assert(count >= 2, "Dev and Tester")

-- The particles' part rides on the text at every distance, field of view and screen.
for _, viewport in { 360, 390, 720, 1080, 1440 } do
	for _, fov in { 50, 70, 90, 120 } do
		for _, depth in { 2, 8, 20, 37 } do
			local studsPerPixel = 2 * depth * math.tan(math.rad(fov) / 2) / viewport
			local textCentre = 57 * studsPerPixel
			local part = api.lift(depth, fov, viewport)
			assert(math.abs((textCentre - part) - Config.TitleParticleDrop) < 1e-9, "the part sits TitleParticleDrop under the text's centre")
		end
	end
end
print("PASS overhead titles (" .. count .. " titles)")
