local fs=require('@lune/fs')
local source=[==[
--!strict
-- One server sample and spatial index for all pads. Presentation geometry is unchanged.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Service = {}
local CELL = 64
local grid, previous, lastContacts, entries = {}, {}, {}, {}
local evidence = setmetatable({}, { __mode = "k" })
local serial = 0

function Service.Intersects(cf, size, from, to)
 local a, b = cf:PointToObjectSpace(from), cf:PointToObjectSpace(to)
 local half, low, high = size * 0.5, 0, 1
 for _, axis in { "X", "Y", "Z" } do
  local delta = b[axis] - a[axis]
  if math.abs(delta) < 1e-8 then
   if math.abs(a[axis]) > half[axis] then return false end
  else
   local near, far = (-half[axis] - a[axis]) / delta, (half[axis] - a[axis]) / delta
   if near > far then near, far = far, near end
   low, high = math.max(low, near), math.min(high, far)
   if low > high then return false end
  end
 end
 return true, low
end

local function characterRoot(player)
 local character = player and player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 local root = character and character:FindFirstChild("HumanoidRootPart")
 if not player or player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true
  or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
 local p = root.Position
 if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or math.abs(p.X) == math.huge or math.abs(p.Y) == math.huge or math.abs(p.Z) == math.huge then return nil end
 return root, humanoid
end

local function geometry(pad)
 -- Retain Gemini's 14-stud trigger height and 4-stud border, without a SECOND expansion.
 local height = tonumber(pad:GetAttribute("PadTriggerHeight")) or 14
 height = math.clamp(height == height and height or 14, 1, 24)
 local size = Vector3.new(pad.Size.X + 4, height, pad.Size.Z + 4)
 return pad.CFrame * CFrame.new(0, (pad.Size.Y + height) * 0.5 - 0.2, 0), size
end

function Service.IsAtPad(player, pad)
 local root = characterRoot(player)
 if not root or not pad or not pad.Parent or not pad:IsDescendantOf(Workspace) then return false end
 local cf, size = geometry(pad)
 return Service.Intersects(cf, size, root.Position, root.Position)
end

function Service.ConsumeContact(player, pad)
 local root = characterRoot(player)
 local proof = evidence[player]
 if not root or not proof or proof.pad ~= pad or proof.root ~= root or proof.used
  or proof.serial ~= player:GetAttribute("StageTeleportProtectionSerial")
  or os.clock() - proof.at > 1 or (root.Position - proof.position).Magnitude > 1
  or not entries[pad] or entries[pad].closed then return false end
 proof.used = true
 return true
end

function Service.RequestRetry(player, pad)
 local entry = entries[pad]
 if entry then
  entry.inside[player] = nil
  entry.retryAt[player] = os.clock() + 0.5
 end
end

local function key(x, z) return x .. ":" .. z end
local function remove(entry)
 for _, cell in ipairs(entry.cells) do
  local bucket = grid[cell]
  if bucket then bucket[entry] = nil; if next(bucket) == nil then grid[cell] = nil end end
 end
 entry.cells = {}
end

function Service.Connect(pad, callback)
 assert(not entries[pad], "Pad already connected")
 serial += 1
 local entry = { pad = pad, callback = callback, cells = {}, order = serial,
  inside = setmetatable({}, { __mode = "k" }), busy = setmetatable({}, { __mode = "k" }),
  retryAt = setmetatable({}, { __mode = "k" }) }
 entries[pad] = entry
 local hitbox = Instance.new("Part")
 hitbox.Name, hitbox.Anchored, hitbox.Transparency = "PadTriggerVolume", true, 1
 -- Sweeps supply contact; no duplicate physics touch events for the invisible volume.
 hitbox.CanCollide, hitbox.CanTouch, hitbox.CanQuery, hitbox.CastShadow = false, false, false, false
 entry.hitbox = hitbox
 local function refresh()
  remove(entry)
  hitbox.CFrame, hitbox.Size = geometry(pad)
  local p = hitbox.Position
  -- Bounding sphere also covers tilted authored pads, not just Y rotations.
  local radius = hitbox.Size.Magnitude * 0.5
  for x = math.floor((p.X-radius)/CELL), math.floor((p.X+radius)/CELL) do
   for z = math.floor((p.Z-radius)/CELL), math.floor((p.Z+radius)/CELL) do
    local cell = key(x,z)
    grid[cell] = grid[cell] or {}; grid[cell][entry] = true
    table.insert(entry.cells,cell)
   end
  end
 end
 refresh(); hitbox.Parent = pad
 local connections = {}
 local function close()
  if entry.closed then return end
  entry.closed = true; remove(entry); entries[pad] = nil
  for _, connection in ipairs(connections) do connection:Disconnect() end
  for player, proof in pairs(evidence) do if proof.pad == pad then evidence[player] = nil end end
  for _, contacts in pairs(lastContacts) do contacts[entry] = nil end
  if hitbox.Parent then hitbox:Destroy() end
 end
 table.insert(connections,pad:GetPropertyChangedSignal("CFrame"):Connect(refresh))
 table.insert(connections,pad:GetPropertyChangedSignal("Size"):Connect(refresh))
 table.insert(connections,pad:GetAttributeChangedSignal("PadTriggerHeight"):Connect(refresh))
 table.insert(connections,pad.Destroying:Connect(close))
 return { Disconnect = close }
end

RunService.Heartbeat:Connect(function(dt)
 local now = os.clock()
 for _, player in ipairs(Players:GetPlayers()) do
  local root, humanoid = characterRoot(player)
  local contacts, candidates = {}, {}
  if root then
   local to, old = root.Position, previous[player]
   local protection = player:GetAttribute("StageTeleportProtectionSerial")
   local grace = now < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
   local continuous = old and old.root == root and old.serial == protection and not old.grace and not grace
   local from = continuous and old.position or to
   local elapsed = math.min(0.25, math.max(dt, old and now-old.at or dt))
   -- WalkSpeed is set by server progression. A fixed 256-stud sweep alone accepted short teleports.
   local maxStep = math.min(256, math.max(0, humanoid.WalkSpeed) * elapsed * 1.5 + 8)
   if (to-from).Magnitude > maxStep then from = to; evidence[player] = nil end
   previous[player] = { root = root, position = to, serial = protection, grace = grace, at = now }
   if not grace then
    local visited = {}
    for x = math.floor(math.min(from.X,to.X)/CELL), math.floor(math.max(from.X,to.X)/CELL) do
     for z = math.floor(math.min(from.Z,to.Z)/CELL), math.floor(math.max(from.Z,to.Z)/CELL) do
      for entry in pairs(grid[key(x,z)] or {}) do
       if not visited[entry] and not entry.closed and entry.pad:IsDescendantOf(Workspace) then
        visited[entry] = true
        local hit, fraction = Service.Intersects(entry.hitbox.CFrame,entry.hitbox.Size,from,to)
        if hit then
         contacts[entry] = true
         table.insert(candidates,{ entry = entry, fraction = fraction, distance = (to-entry.pad.Position).Magnitude })
        end
       end
      end
     end
    end
   else evidence[player] = nil end
  else previous[player] = nil; evidence[player] = nil end
  for entry in pairs(lastContacts[player] or {}) do
   if not contacts[entry] then entry.inside[player] = nil end
  end
  lastContacts[player] = contacts
  -- Overlapping volumes cannot dispatch two competing claims/prompts from one sample.
  table.sort(candidates,function(a,b)
   if a.fraction ~= b.fraction then return a.fraction < b.fraction end
   if a.distance ~= b.distance then return a.distance < b.distance end
   return a.entry.order < b.entry.order
  end)
  local entry = candidates[1] and candidates[1].entry
  if entry and not entry.inside[player] and not entry.busy[player] and now >= (entry.retryAt[player] or 0) then
   entry.inside[player], entry.busy[player] = true, true
   evidence[player] = { pad = entry.pad, root = root, position = root.Position, at = now,
    serial = player:GetAttribute("StageTeleportProtectionSerial") }
   task.spawn(function()
    local ok, result = pcall(entry.callback, root)
    entry.busy[player] = nil
    if not ok or result == false then Service.RequestRetry(player,entry.pad) end
    if not ok then warn("[PadTouchService] " .. tostring(result)) end
   end)
  end
 end
end)
Players.PlayerRemoving:Connect(function(player)
 previous[player], lastContacts[player], evidence[player] = nil, nil, nil
end)
return Service
]==]
for _,world in {'World1','World2'} do
 local base='audit/merged/'..world..'/ServerScriptService/Services/'
 fs.writeFile(base..'PadTouchService.luau',source)
 local claims=fs.readFile(base..'RewardPadClaims.luau')
 local start=assert(string.find(claims,'local function characterAtPad',1,true))
 local finish=assert(string.find(claims,'function Service.IsAtPad',start,true))
 claims=string.sub(claims,1,start-1)..'local PadTouchService = require(script.Parent.PadTouchService)\nlocal function characterAtPad(player, pad)\n\treturn PadTouchService.IsAtPad(player, pad)\nend\n\n'..string.sub(claims,finish)
 claims=string.gsub(claims,'or not characterAtPad%(player, pad%) then return false end','then PadTouchService.RequestRetry(player, pad); return false end\n\tif not characterAtPad(player, pad) and not PadTouchService.ConsumeContact(player, pad) then return false end')
 claims=string.gsub(claims,'if not MovementGuard.CanClaim%(player, stage, isFinal%) then return false end','if not MovementGuard.CanClaim(player, stage, isFinal) then PadTouchService.RequestRetry(player, pad); return false end')
 claims=string.gsub(claims,'if not handle then return false end','if not handle then PadTouchService.RequestRetry(player, pad); return false end')
 -- Consume any proof even for an endpoint inside, so it cannot be reused after a return.
 claims=string.gsub(claims,'local state = { handle = handle }','PadTouchService.ConsumeContact(player, pad)\n\tlocal state = { handle = handle }')
 fs.writeFile(base..'RewardPadClaims.luau',claims)
end
