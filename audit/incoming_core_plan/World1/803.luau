--!strict
-- Server-owned trigger volumes; authored art/labels never move to enlarge a hitbox.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Service = {}
local CELL = 64
local grid = {}
local previous = {}
local lastContacts = {}

function Service.Intersects(cf, size, from, to)
	local a = cf:PointToObjectSpace(from)
	local b = cf:PointToObjectSpace(to)
	local half = size * 0.5 + Vector3.new(2.5, 2.0, 2.5)
	local low, high = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local delta = b[axis] - a[axis]
		if math.abs(delta) < 1e-8 then
			if math.abs(a[axis]) > half[axis] then return false end
		else
			local near = (-half[axis] - a[axis]) / delta
			local far = (half[axis] - a[axis]) / delta
			if near > far then near, far = far, near end
			low = math.max(low, near)
			high = math.min(high, far)
			if low > high then return false end
		end
	end
	return true
end

local function cellKey(x, z)
	return x .. ":" .. z
end

local function removeFromGrid(entry)
	for _, key in ipairs(entry.cells) do
		local bucket = grid[key]
		if bucket then
			bucket[entry] = nil
			if next(bucket) == nil then grid[key] = nil end
		end
	end
	entry.cells = {}
end

local function characterRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true or not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	local p = root.Position
	if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or math.abs(p.X) == math.huge or math.abs(p.Y) == math.huge or math.abs(p.Z) == math.huge then
		return nil
	end
	return root
end

local function resolvePlayerAndRoot(hit)
	if not hit or not hit:IsA("BasePart") then return nil, nil end
	local current = hit.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local root = current:FindFirstChild("HumanoidRootPart")
			local player = Players:GetPlayerFromCharacter(current)
			if player and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				if player.Parent == Players and player:GetAttribute("DataLoaded") == true then
					return player, root
				end
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function dispatch(entry, player, root)
	if entry.closed or entry.inside[player] or entry.busy[player] then return end
	entry.inside[player] = true
	entry.busy[player] = true
	lastContacts[player] = lastContacts[player] or {}
	lastContacts[player][entry] = true
	task.spawn(function()
		local ok, err = pcall(entry.callback, root)
		entry.busy[player] = nil
		if not ok then warn("[PadTouchService] " .. tostring(err)) end
	end)
end

function Service.Connect(pad, callback)
	local entry = {
		pad = pad,
		callback = callback,
		cells = {},
		inside = setmetatable({}, { __mode = "k" }),
		busy = setmetatable({}, { __mode = "k" }),
	}

	local hitbox = Instance.new("Part")
	hitbox.Name = "PadTriggerVolume"
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.CanQuery = false
	hitbox.CastShadow = false

	local function refresh()
		removeFromGrid(entry)
		-- Generous height (14 studs) and border padding (+4 studs) to catch high-speed runners & jumpers
		local boxHeight = 14
		hitbox.Size = Vector3.new(pad.Size.X + 4, boxHeight, pad.Size.Z + 4)
		hitbox.CFrame = pad.CFrame * CFrame.new(0, (pad.Size.Y + boxHeight) * 0.5 - 0.2, 0)
		local p = hitbox.Position
		local radius = math.sqrt((hitbox.Size.X * 0.5) ^ 2 + (hitbox.Size.Z * 0.5) ^ 2) + 2
		for x = math.floor((p.X - radius) / CELL), math.floor((p.X + radius) / CELL) do
			for z = math.floor((p.Z - radius) / CELL), math.floor((p.Z + radius) / CELL) do
				local key = cellKey(x, z)
				grid[key] = grid[key] or {}
				grid[key][entry] = true
				table.insert(entry.cells, key)
			end
		end
	end
	refresh()
	hitbox.Parent = pad
	entry.hitbox = hitbox

	local connections = {}
	local function close()
		if entry.closed then return end
		entry.closed = true
		removeFromGrid(entry)
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		if hitbox.Parent then hitbox:Destroy() end
	end

	table.insert(connections, pad:GetPropertyChangedSignal("CFrame"):Connect(refresh))
	table.insert(connections, pad:GetPropertyChangedSignal("Size"):Connect(refresh))
	table.insert(connections, pad.Destroying:Connect(close))

	-- Instant touch handler: fires as soon as any part of the character touches pad OR hitbox
	local function onTouch(hit)
		local player, root = resolvePlayerAndRoot(hit)
		if not player or not root then return end
		local pPos = pad.Position
		local rPos = root.Position
		local maxRadius = math.max(pad.Size.X, pad.Size.Z) * 0.5 + 18
		local dx = rPos.X - pPos.X
		local dz = rPos.Z - pPos.Z
		local dy = rPos.Y - pPos.Y
		if (dx * dx + dz * dz) <= maxRadius * maxRadius and dy >= -6 and dy <= 24 then
			dispatch(entry, player, root)
		end
	end

	table.insert(connections, hitbox.Touched:Connect(onTouch))
	table.insert(connections, pad.Touched:Connect(onTouch))

	return { Disconnect = close }
end

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = characterRoot(player)
		local contacts = {}
		if root then
			local to = root.Position
			local old = previous[player]
			local from = old and old.root == root and old.position or to
			-- Continuous sweep for high-speed runners (up to 256 studs per frame)
			if (to - from).Magnitude > 256 then from = to end
			previous[player] = { root = root, position = to }
			local visited = {}
			local minX = math.floor(math.min(from.X, to.X) / CELL)
			local maxX = math.floor(math.max(from.X, to.X) / CELL)
			local minZ = math.floor(math.min(from.Z, to.Z) / CELL)
			local maxZ = math.floor(math.max(from.Z, to.Z) / CELL)
			for x = minX, maxX do
				for z = minZ, maxZ do
					for entry in pairs(grid[cellKey(x, z)] or {}) do
						if not visited[entry] then
							visited[entry] = true
							if not entry.closed and Service.Intersects(entry.hitbox.CFrame, entry.hitbox.Size, from, to) then
								contacts[entry] = true
								dispatch(entry, player, root)
							end
						end
					end
				end
			end
		else
			previous[player] = nil
		end
		for entry in pairs(lastContacts[player] or {}) do
			if not contacts[entry] then
				entry.inside[player] = nil
			end
		end
		lastContacts[player] = contacts
	end
end)

Players.PlayerRemoving:Connect(function(player)
	previous[player] = nil
	lastContacts[player] = nil
end)

return Service
