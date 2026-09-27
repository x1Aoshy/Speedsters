-- The Stage 10 WoodenBridge must carry runners over its visible arch.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local planSource = fs.readFile("src/common/ServerScriptService/Gameplay/BridgeRampPlan.luau")
local hazardSource = fs.readFile("src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau")
luau.compile(planSource)
luau.compile(hazardSource)
local Plan = luau.load(planSource, {
 environment = setmetatable({ Vector3 = rb.Vector3, CFrame = rb.CFrame }, { __index = _G }),
})()
local dm = rb.deserializePlace(fs.readFile("World3Update3New.rbxl"))
local bridge = assert(dm.Workspace:FindFirstChild("Stage 10"):FindFirstChild("Decor"):FindFirstChild("WoodenBridge"))
local parts = {}
for _, item in bridge:GetDescendants() do
 if item:IsA("BasePart") then table.insert(parts, item) end
end
assert(#parts == 53, "Expected the 53-piece Stage 10 wooden bridge")
local pieces = assert(Plan.CurvedArch(parts), "Could not fit the bridge's visible arch")
assert(#pieces >= 9 and #pieces <= 11, "A piecewise arch must cover every pair of boards")

local starts = {}
for index, piece in pieces do
 assert(piece.Size.X > 28 and piece.Size.X < 33, "The ramp must fill the whole deck width")
 assert(piece.CFrame.UpVector.Y > 0.9, "Each collision surface must face up")
 local top = piece.CFrame * rb.CFrame.new(0, piece.Size.Y / 2, 0)
 local half = (piece.Size.Z - Plan.Overlap) / 2
 starts[index] = {
  A = top * rb.Vector3.new(0, 0, -half),
  B = top * rb.Vector3.new(0, 0, half),
  Y = top.Position.Y,
 }
end
for index = 1, #starts - 1 do
 local a, b = starts[index], starts[index + 1]
 local gap = math.min(
  (a.A - b.A).Magnitude, (a.A - b.B).Magnitude,
  (a.B - b.A).Magnitude, (a.B - b.B).Magnitude
 )
 assert(gap < 0.3, ("Ramp seam %d has a %.2f-stud gap"):format(index, gap))
end
local edgeY = math.max(starts[1].Y, starts[#starts].Y)
local highest = -math.huge
for _, row in starts do highest = math.max(highest, row.Y) end
assert(highest - edgeY > 4, "The collider must rise over the 5-stud arch")

local deckSlabs = 0
for _, part in parts do
 if part.Size.X > 1.8 and part.Size.X < 2.2 and part.Size.Y >= 4.8 and part.Size.Z >= 13 then
  deckSlabs += 1
  local slabTop = part.CFrame.Position + part.CFrame.RightVector * (part.Size.X / 2)
  local above = math.huge
  for _, piece in pieces do
   local localTop = piece.CFrame:PointToObjectSpace(slabTop)
   if math.abs(localTop.X) <= piece.Size.X / 2 and math.abs(localTop.Z) <= piece.Size.Z / 2 then
    above = math.min(above, piece.Size.Y / 2 - localTop.Y)
   end
  end
  assert(above < math.huge, "The ramp must cover every broad deck slab")
  assert(above >= -0.2 and above < 0.35,
   ("The ramp must run close over the visible deck (%.2f studs)"):format(above))
 end
end
assert(deckSlabs >= 7, "Expected the broad deck slabs")
assert(not string.find(hazardSource, "local pStart =", 1, true), "The old flat bridge shortcut must be removed")
assert(string.find(hazardSource, "walkway:Destroy()", 1, true), "A saved old flat collider must be removed")
print(("PASS Stage 10 WoodenBridge: %d curved pieces, %d deck slabs covered, %.2f-stud rise"):format(
 #pieces, deckSlabs, highest - edgeY))
