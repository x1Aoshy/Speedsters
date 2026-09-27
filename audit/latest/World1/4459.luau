local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage
local DisplayRemote = Remotes:WaitForChild("DisplayGlobalAnnouncement")
local AdminBarRemote = Remotes:WaitForChild("GlobalAnnouncementRequest")

local container = gui:WaitForChild("Container")
local template = container:WaitForChild("AnnouncementMessage")

local sound = script:FindFirstChild("Sound") or Instance.new("Sound", script)
sound.SoundId = "rbxassetid://72264591133889"
sound.Volume = 0.8

gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local activeAnnouncements = 0

local function displayAnnouncement(payload: any, legacyDuration: number?)
	local messageText = ""
	local senderName = "ADMIN"
	local duration = legacyDuration or 8

	if type(payload) == "table" then
		messageText = tostring(payload.Message or "")
		senderName = tostring(payload.SenderName or "ADMIN")
		duration = tonumber(payload.Duration) or 8
	elseif type(payload) == "string" then
		messageText = payload
	end

	if #messageText == 0 then return end
	activeAnnouncements += 1

	local banner = template:Clone()
	banner.Name = "ActiveAnnouncement_" .. tostring(activeAnnouncements)
	banner.Visible = true

	local background = banner:FindFirstChild("Background") or banner
	local textLabel = background:FindFirstChild("TextLabel")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.RichText = true
		textLabel.Text = string.format("<b>📢 ANUNCIO GLOBAL [%s]:</b>\n%s", senderName, messageText)
		textLabel.Font = Enum.Font.FredokaOne
	end

	local bScale = banner:FindFirstChild("BannerScale") or Instance.new("UIScale", banner)
	bScale.Name = "BannerScale"
	bScale.Scale = 0.5
	banner.Parent = container

	pcall(function()
		sound.TimePosition = 0
		sound:Play()
	end)

	TweenService:Create(bScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	task.wait(duration)
	local popOut = TweenService:Create(bScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.1 })
	popOut:Play()
	popOut.Completed:Wait()
	banner:Destroy()
end

DisplayRemote.OnClientEvent:Connect(displayAnnouncement)

local isAdmin = false
AdminBarRemote:FireServer("CheckPermission")

local adminBar = gui:FindFirstChild("AdminAnnouncementBar")
if not adminBar then
	local frame = Instance.new("Frame")
	frame.Name = "AdminAnnouncementBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, -0.3, 0)
	frame.Size = UDim2.fromOffset(680, 110)
	frame.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
	frame.BorderSizePixel = 0
	frame.ZIndex = 50
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(0, 210, 255)
	stroke.Thickness = 3

	local title = Instance.new("TextLabel", frame)
	title.Name = "Title"
	title.Text = "📢 TRANSMITIR ANUNCIO GLOBAL (TODOS LOS SERVIDORES)"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 230, 80)
	title.Position = UDim2.new(0, 18, 0, 8)
	title.Size = UDim2.new(1, -70, 0, 24)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 51

	local closeBtn = Instance.new("TextButton", frame)
	closeBtn.Name = "CloseBtn"
	closeBtn.Text = "✖"
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.BackgroundTransparency = 1
	closeBtn.ZIndex = 52

	local inputBox = Instance.new("TextBox", frame)
	inputBox.Name = "InputBox"
	inputBox.PlaceholderText = "Escribe tu anuncio aquí (Presiona Enter o el botón)..."
	inputBox.Text = ""
	inputBox.Font = Enum.Font.FredokaOne
	inputBox.TextSize = 16
	inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	inputBox.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
	inputBox.Position = UDim2.new(0, 18, 0, 42)
	inputBox.Size = UDim2.new(0.72, 0, 0, 48)
	inputBox.ClearTextOnFocus = false
	inputBox.ZIndex = 51
	local inputCorner = Instance.new("UICorner", inputBox)
	inputCorner.CornerRadius = UDim.new(0, 10)

	local sendBtn = Instance.new("TextButton", frame)
	sendBtn.Name = "SendBtn"
	sendBtn.Text = "ANUNCIAR"
	sendBtn.Font = Enum.Font.FredokaOne
	sendBtn.TextSize = 16
	sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sendBtn.BackgroundColor3 = Color3.fromRGB(50, 205, 80)
	sendBtn.Position = UDim2.new(0.74, 10, 0, 42)
	sendBtn.Size = UDim2.new(0.24, -10, 0, 48)
	sendBtn.ZIndex = 51
	local btnCorner = Instance.new("UICorner", sendBtn)
	btnCorner.CornerRadius = UDim.new(0, 10)

	adminBar = frame
end

local isBarOpen = false
local barTween = nil

local function toggleAdminBar(show: boolean)
	if not adminBar then return end
	if not isAdmin and not RunService:IsStudio() then return end
	if barTween then barTween:Cancel() end

	if show then
		isBarOpen = true
		adminBar.Visible = true
		adminBar.Position = UDim2.new(0.5, 0, -0.3, 0)
		barTween = TweenService:Create(adminBar, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.04, 0),
		})
		barTween:Play()
		local input = adminBar:FindFirstChild("InputBox")
		if input and input:IsA("TextBox") then task.delay(0.1, function() input:CaptureFocus() end) end
	else
		isBarOpen = false
		barTween = TweenService:Create(adminBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.3, 0),
		})
		barTween:Play()
		barTween.Completed:Connect(function() if not isBarOpen then adminBar.Visible = false end end)
	end
end

AdminBarRemote.OnClientEvent:Connect(function(action)
	if action == "PermissionGranted" then isAdmin = true
	elseif action == "OpenBar" then
		isAdmin = true
		toggleAdminBar(true)
	end
end)

if adminBar then
	local closeBtn = adminBar:FindFirstChild("CloseBtn")
	if closeBtn and closeBtn:IsA("TextButton") then closeBtn.Activated:Connect(function() toggleAdminBar(false) end) end

	local sendBtn = adminBar:FindFirstChild("SendBtn")
	local inputBox = adminBar:FindFirstChild("InputBox")

	local function submitBroadcast()
		if not inputBox or not inputBox:IsA("TextBox") then return end
		local text = inputBox.Text
		local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
		if #trimmed > 0 then
			AdminBarRemote:FireServer("Broadcast", trimmed)
			inputBox.Text = ""
			toggleAdminBar(false)
		end
	end

	if sendBtn and sendBtn:IsA("TextButton") then sendBtn.Activated:Connect(submitBroadcast) end
	if inputBox and inputBox:IsA("TextBox") then
		inputBox.FocusLost:Connect(function(enterPressed) if enterPressed then submitBroadcast() end end)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F2 then toggleAdminBar(not isBarOpen) end
end)
