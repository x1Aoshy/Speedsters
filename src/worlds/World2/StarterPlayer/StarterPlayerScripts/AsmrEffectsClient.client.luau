-- Cosmetic presses are local for Keyboard and Bubble grids.
-- Original solid Butter surfaces are handled natively and authoritatively by their server scripts.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local records = {}
local STEP, LOAD_DISTANCE, UNLOAD_DISTANCE = 0.05, 160, 220
local PRESS = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

-- Permanently eradicate any obsolete placeholder SurfaceGuis (e.g. "Loading... (click play)")
for _, desc in ipairs(Workspace:GetDescendants()) do
	if desc:IsA("SurfaceGui") and desc.Parent and (desc.Parent.Name == "Keyboard" or desc.Parent.Name == "Bubble") then
		desc:Destroy()
	end
end

local function unmount(record)
	for _, cell in ipairs(record.cells or {}) do
		if cell.tween then
			cell.tween:Cancel()
		end
	end
	if record.folder then
		record.folder:Destroy()
	end
	if record.origin and record.origin.Parent then
		record.origin.LocalTransparencyModifier = 0
	end
	record.folder, record.cells, record.origin, record.sounds = nil, nil, nil, nil
end

local function discover(instance)
	if instance.Name == "AsmrEffectKind" and instance:IsA("StringValue") then
		instance = instance.Parent
	end
	local marker = instance:IsA("Script") and instance:FindFirstChild("AsmrEffectKind")
	-- Butter is authoritative on the server; do not clone on client to prevent duplicated decals and clashing tweens
	if marker and marker:IsA("StringValue") and marker.Value ~= "Butter" and not records[instance] then
		records[instance] = { source = instance, kind = marker.Value }
	end
end

local function resolve(record)
	local source = record.source
	if not source or not source:IsDescendantOf(Workspace) then
		return nil, nil
	end
	if record.kind == "Butter" then
		return nil, nil
	end
	local parent = source.Parent
	if not parent then
		return nil, nil
	end
	local origin = parent:FindFirstChild(record.kind)
	local template = source:FindFirstChild(record.kind == "Keyboard" and "Key" or "Bubble")
	if origin and origin:IsA("BasePart") and template and template:IsA("BasePart") then
		return origin, template
	end
	return nil, nil
end

local function mount(record, origin, template)
	local folder = Instance.new("Folder")
	folder.Name = "LocalAsmrEffects"
	folder.Parent = Workspace
	record.folder, record.origin, record.cells = folder, origin, {}
	local cols = math.floor(origin.Size.X / math.max(template.Size.X, 0.01) + 0.001)
	local rows = math.floor(origin.Size.Z / math.max(template.Size.Z, 0.01) + 0.001)
	if cols < 1 or rows < 1 or cols * rows > 512 then
		unmount(record)
		return
	end

	local soundIds = {}
	for _, child in ipairs(template:GetChildren()) do
		if child:IsA("Sound") and child.SoundId ~= "" then
			table.insert(soundIds, child.SoundId)
		end
	end

	-- One emitter at the pressed piece, at most two overlapping voices per grid.
	record.sounds = {}
	for index = 1, 2 do
		local emitter = Instance.new("Part")
		emitter.Name = "SoundEmitter"
		emitter.Anchored, emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = true, false, false, false
		emitter.Transparency, emitter.Size = 1, Vector3.new(0.1, 0.1, 0.1)
		emitter.CFrame = origin.CFrame
		emitter.Parent = folder
		local sound = Instance.new("Sound")
		sound.RollOffMaxDistance, sound.Volume, sound.Parent = 60, 0.5, emitter
		record.sounds[index] = sound
	end
	record.soundIndex, record.soundIds = 0, soundIds

	for row = 1, rows do
		for col = 1, cols do
			local piece = template:Clone()
			for _, child in ipairs(piece:GetDescendants()) do
				if child:IsA("LuaSourceContainer") or child:IsA("Sound") then
					child:Destroy()
				elseif child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			piece.Anchored, piece.CanCollide, piece.CanTouch, piece.CanQuery = true, false, false, false
			local authoredTransparency = template:FindFirstChild("AsmrTemplateTransparency")
			piece.Transparency = (authoredTransparency and authoredTransparency.Value) or template.Transparency
			piece.LocalTransparencyModifier = 0
			piece.CFrame = origin.CFrame * CFrame.new((col - (cols + 1) / 2) * template.Size.X, 0, (row - (rows + 1) / 2) * template.Size.Z)

			if record.kind == "Keyboard" then
				piece.Color, piece.Material = origin.Color, origin.Material
				local letter = string.char(65 + ((row - 1) * cols + col - 1) % 26)
				piece.Name = letter
				local label = piece:FindFirstChildWhichIsA("TextLabel", true)
				if label then
					label.Text = letter
				end
			end
			piece.Parent = folder
			table.insert(record.cells, { piece = piece, cf = piece.CFrame, size = piece.Size, pressed = false, tween = nil })
		end
	end
	origin.LocalTransparencyModifier = 1
end

local function update(record, root)
	if not record.cells then
		return
	end
	for _, cell in ipairs(record.cells) do
		if not cell.piece or not cell.piece.Parent then
			continue
		end
		-- 2026-09-22: 'root and ...' gave false (not nil) for a dead player and offset.X then
		-- errored 20 times a second (157k live errors); nil lets pressed keys release.
		local offset = if root then cell.cf:PointToObjectSpace(root.Position) else nil
		local pressed = offset ~= nil
			and math.abs(offset.X) <= cell.size.X / 2 + 0.8
			and math.abs(offset.Z) <= cell.size.Z / 2 + 0.8
			and offset.Y >= -cell.size.Y / 2
			and offset.Y <= cell.size.Y / 2 + 4.5

		if pressed ~= cell.pressed then
			cell.pressed = pressed
			if cell.tween then
				cell.tween:Cancel()
				cell.tween = nil
			end
			local target = { CFrame = cell.cf }
			if pressed then
				target.CFrame = cell.cf - Vector3.new(0, 0.8, 0)
				if #record.soundIds > 0 and record.sounds and #record.sounds > 0 then
					record.soundIndex = (record.soundIndex % #record.sounds) + 1
					local sound = record.sounds[record.soundIndex]
					if sound and sound.Parent and sound.Parent:IsA("BasePart") then
						sound.Parent.CFrame = cell.cf
						sound.SoundId = record.soundIds[math.random(1, #record.soundIds)]
						sound.PlaybackSpeed = math.random(80, 110) / 100
						sound:Play()
					end
				end
				local particles = cell.piece:FindFirstChildWhichIsA("ParticleEmitter", true)
				if particles and particles.Parent then
					pcall(function() particles:Emit(4) end)
				end
			end
			local ok, tw = pcall(function()
				return TweenService:Create(cell.piece, pressed and PRESS or RELEASE, target)
			end)
			if ok and tw then
				cell.tween = tw
				tw:Play()
			end
		end
	end
end

Workspace.DescendantAdded:Connect(discover)
Workspace.DescendantRemoving:Connect(function(instance)
	local record = records[instance]
	if record then
		unmount(record)
		records[instance] = nil
	end
end)
for _, instance in ipairs(Workspace:GetDescendants()) do
	discover(instance)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < STEP then
		return
	end
	elapsed = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = if humanoid and humanoid.Health > 0 then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = Workspace.CurrentCamera
	local position = (root and root.Position) or (camera and camera.CFrame.Position)
	for source, record in pairs(records) do
		local origin, template = resolve(record)
		if not origin then
			unmount(record)
		elseif position then
			local distance = (origin.Position - position).Magnitude
			if record.folder and distance > UNLOAD_DISTANCE then
				unmount(record)
			elseif not record.folder and distance <= LOAD_DISTANCE then
				mount(record, origin, template)
			end
			if record.folder then
				update(record, root)
			end
		elseif record.folder then
			unmount(record)
		end
	end
end)
