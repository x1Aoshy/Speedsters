-- ServerScriptService (o hijo de la pieza origen) / KeyboardGenerator.server.lua
-- El script debe ser hijo directo de la parte que actúa como origen del teclado.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PRESS_DEPTH = 0.8
local ELASTIC_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local SOUND_POOL_SIZE = 8
local KEYS_PER_BATCH = 40

local originPart = script.Parent.Keyboard
local template = script:WaitForChild("Key")

local function randomLetter()
	local index = math.random(1, #ALPHABET)
	return ALPHABET:sub(index, index)
end

local function buildSoundPool()
	local soundIds = {}
	for _, s in ipairs(template:GetChildren()) do
		if s:IsA("Sound") then
			table.insert(soundIds, s.SoundId)
		end
	end

	local poolFolder = Instance.new("Folder")
	poolFolder.Name = "KeyboardSoundPool_" .. originPart.Name
	poolFolder.Parent = Workspace

	local pool = {}
	for i = 1, SOUND_POOL_SIZE do
		local emitter = Instance.new("Part")
		emitter.Name = "SoundEmitter" .. i
		emitter.Anchored = true
		emitter.CanTouch = false
		emitter.CanQuery = false
		emitter.Transparency = 1
		emitter.Size = Vector3.new(0.1, 0.1, 0.1)
		emitter.Parent = poolFolder

		local sound = Instance.new("Sound")
		sound.Name = "Sound"
		sound.RollOffMaxDistance = 60
		sound.Parent = emitter

		pool[i] = emitter
	end

	local poolIndex = 0
	return function(position)
		if #soundIds == 0 then return end
		poolIndex = (poolIndex % SOUND_POOL_SIZE) + 1
		local emitter = pool[poolIndex]
		emitter.Position = position

		local sound = emitter.Sound
		sound.SoundId = soundIds[math.random(1, #soundIds)]
		sound.Pitch = math.random(80, 110) / 100
		sound:Play()
	end
end

local function getFolder(name)
	local folder = Workspace:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = Workspace
	end
	return folder
end

local function setupPress(piece, playSound)
	local originalPosition = piece.Position
	local pressedPosition = originalPosition - Vector3.new(0, PRESS_DEPTH, 0)

	local touchCount = 0
	local isPressed = false

	local function updateState()
		if touchCount > 0 then
			if not isPressed then
				isPressed = true
				playSound(originalPosition)
				TweenService:Create(piece, ELASTIC_INFO, {Position = pressedPosition}):Play()
			end
		else
			if isPressed then
				isPressed = false
				TweenService:Create(piece, ELASTIC_INFO, {Position = originalPosition}):Play()
			end
		end
	end

	piece.Touched:Connect(function(hit)
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			touchCount += 1
			updateState()
		end
	end)

	piece.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			touchCount = math.max(0, touchCount - 1)
			task.delay(0.08, updateState)
		end
	end)
end

local function buildGrid(playSound)
	local folder = getFolder("Keyboards")
	local cf = originPart.CFrame
	local totalWidth = originPart.Size.X
	local totalDepth = originPart.Size.Z

	local pieceSizeX = template.Size.X
	local pieceSizeZ = template.Size.Z

	local EPSILON = 0.001
	local cols = math.floor(totalWidth / pieceSizeX + EPSILON)
	local rows = math.floor(totalDepth / pieceSizeZ + EPSILON)

	local gridWidth = cols * pieceSizeX
	local gridDepth = rows * pieceSizeZ
	local startX = -totalWidth / 2 + (totalWidth - gridWidth) / 2 + pieceSizeX / 2
	local startZ = -totalDepth / 2 + (totalDepth - gridDepth) / 2 + pieceSizeZ / 2

	local createdThisBatch = 0

	for row = 1, rows do
		for col = 1, cols do
			local piece = template:Clone()

			local letter = randomLetter()
			piece.Name = letter

			local gui = piece:FindFirstChild("SurfaceGui")
			local frame = gui and gui:FindFirstChild("Frame")
			local label = frame and frame:FindFirstChild("TextLabel")
			if label then
				label.Text = letter
			end

			piece.Anchored = true
			piece.CanTouch = true
			piece.CanQuery = false
			piece.Massless = true
			piece.Color = originPart.Color
			piece.Material = originPart.Material

			local xOffset = startX + (col - 1) * pieceSizeX
			local zOffset = startZ + (row - 1) * pieceSizeZ
			piece.CFrame = cf * CFrame.new(xOffset, 0, zOffset)

			for _, s in ipairs(piece:GetChildren()) do
				if s:IsA("Sound") then
					s:Destroy()
				end
			end

			piece.Parent = folder
			setupPress(piece, playSound)

			createdThisBatch += 1
			if createdThisBatch >= KEYS_PER_BATCH then
				createdThisBatch = 0
				task.wait()
			end
		end
	end

	originPart:Destroy()
	script.Key:Destroy()
end

local playSound = buildSoundPool()
buildGrid(playSound)