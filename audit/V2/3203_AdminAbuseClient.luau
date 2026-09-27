local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))

if not AdminBannerConfig.IsAdmin(player.UserId) then
	return
end

local AdminRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAbuseRemote")
local Gui = playerGui:WaitForChild("AdminAbusePanelGui", 15)
if not Gui then
	return
end

Gui.DisplayOrder = 100
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true

local MainFrame = Gui:WaitForChild("MainFrame")
local Header = MainFrame:WaitForChild("Header")
local Sidebar = MainFrame:WaitForChild("Sidebar")
local Workspace = MainFrame:WaitForChild("Workspace")
local AnnounceFrame = Workspace:WaitForChild("AnnounceFrame")
local MusicFrame = Workspace:WaitForChild("MusicFrame")
local CodesFrame = Workspace:WaitForChild("CodesFrame")
local MultipliersFrame = Workspace:WaitForChild("MultipliersFrame")
local EffectsFrame = Workspace:WaitForChild("EffectsFrame")
local WipeDataFrame = Workspace:WaitForChild("WipeDataFrame")
local SessionLogsFrame = Workspace:WaitForChild("SessionLogsFrame")
local ChatLogsFrame = Workspace:WaitForChild("ChatLogsFrame")

local AnnounceMessageBox = AnnounceFrame:WaitForChild("AnnounceMessageGroup"):WaitForChild("AnnounceMessageBox")
local AnnounceDurationBox = AnnounceFrame:WaitForChild("AnnounceDurationGroup"):WaitForChild("AnnounceDurationBox")
local AnnounceColorBox = AnnounceFrame:WaitForChild("AnnounceColorGroup"):WaitForChild("AnnounceColorBox")
local TypewriterToggleBtn = AnnounceFrame:WaitForChild("TypewriterToggleBtn")
local SoundToggleBtn = AnnounceFrame:WaitForChild("SoundToggleBtn")
local BroadcastBtn = AnnounceFrame:WaitForChild("BroadcastBtn")

local MusicSongListFrame = MusicFrame
local PlayMusicBtn = MusicFrame:WaitForChild("PlayMusicBtn")
local StopMusicBtn = MusicFrame:WaitForChild("StopMusicBtn")

local CodeNameBox = CodesFrame:WaitForChild("CodeNameGroup"):WaitForChild("CodeNameBox")
local StatNameBox = CodesFrame:WaitForChild("StatNameGroup"):WaitForChild("StatNameBox")
local StatAmountBox = CodesFrame:WaitForChild("StatAmountGroup"):WaitForChild("StatAmountBox")
local CreateCodeBtn = CodesFrame:WaitForChild("CreateCodeBtn")

local SpeedValueBox = MultipliersFrame:WaitForChild("SpeedValueGroup"):WaitForChild("SpeedValueBox")
local JumpValueBox = MultipliersFrame:WaitForChild("JumpValueGroup"):WaitForChild("JumpValueBox")
local WinMultiBox = MultipliersFrame:WaitForChild("WinMultiGroup"):WaitForChild("WinMultiBox")
local ApplyMultipliersBtn = MultipliersFrame:WaitForChild("ApplyMultipliersBtn")
local SpawnTreadmillBtn = MultipliersFrame:WaitForChild("SpawnTreadmillBtn")
local ResetAllNormalBtn = MultipliersFrame:WaitForChild("ResetAllNormalBtn")

local ToggleDiscoBtn = EffectsFrame:WaitForChild("ToggleDiscoBtn")
local ToggleStrobeBtn = EffectsFrame:WaitForChild("ToggleStrobeBtn")
local ToggleFogBtn = EffectsFrame:WaitForChild("ToggleFogBtn")
local ConfettiEffectBtn = EffectsFrame:WaitForChild("ConfettiEffectBtn")


local EffectsStatusLabel = Instance.new("TextLabel")
EffectsStatusLabel.Name = "EffectsStatusLabel"
EffectsStatusLabel.Size = UDim2.new(1, -10, 0, 40)
EffectsStatusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
EffectsStatusLabel.Text = "Effects: none active"
EffectsStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
EffectsStatusLabel.TextSize = 13
EffectsStatusLabel.Font = Enum.Font.GothamBold
EffectsStatusLabel.RichText = true
EffectsStatusLabel.BorderSizePixel = 0
EffectsStatusLabel.TextWrapped = true
EffectsStatusLabel.LayoutOrder = 99
EffectsStatusLabel.Parent = EffectsFrame
local esCorner = Instance.new("UICorner")
esCorner.CornerRadius = UDim.new(0, 6)
esCorner.Parent = EffectsStatusLabel

local ResetAllEffectsBtn = Instance.new("TextButton")
ResetAllEffectsBtn.Name = "ResetAllEffectsBtn"
ResetAllEffectsBtn.Size = UDim2.new(1, -10, 0, 34)
ResetAllEffectsBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
ResetAllEffectsBtn.Text = "RESET ALL EFFECTS"
ResetAllEffectsBtn.TextColor3 = Color3.new(1, 1, 1)
ResetAllEffectsBtn.TextSize = 14
ResetAllEffectsBtn.Font = Enum.Font.GothamBold
ResetAllEffectsBtn.BorderSizePixel = 0
ResetAllEffectsBtn.LayoutOrder = 100
ResetAllEffectsBtn.Parent = EffectsFrame
local raeCorner = Instance.new("UICorner")
raeCorner.CornerRadius = UDim.new(0, 6)
raeCorner.Parent = ResetAllEffectsBtn
ResetAllEffectsBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "ResetAllNormal" })
end)

local effectState = { Disco = false, Strobe = false, Fog = false }
local function renderEffectsStatus()
	local active = {}
	if effectState.Disco then table.insert(active, "DISCO") end
	if effectState.Strobe then table.insert(active, "STROBE") end
	if effectState.Fog then table.insert(active, "FOG") end
	if #active == 0 then
		EffectsStatusLabel.Text = "Effects: <font color=\"rgb(120,120,140)\">none active</font>"
	else
		EffectsStatusLabel.Text = "Effects ON: <font color=\"rgb(120,255,150)\">" .. table.concat(active, ", ") .. "</font>"
	end
end

local WipeTargetBox = WipeDataFrame:WaitForChild("WipeTargetGroup"):WaitForChild("WipeTargetBox")
local ConfirmWipeBtn = WipeDataFrame:WaitForChild("ConfirmWipeBtn")

local SessionLogsText = SessionLogsFrame:WaitForChild("SessionLogsText")
local ChatLogsText = ChatLogsFrame:WaitForChild("ChatLogsText")

local ALL_FRAMES = {
	AnnounceFrame,
	MusicFrame,
	CodesFrame,
	MultipliersFrame,
	EffectsFrame,
	WipeDataFrame,
	SessionLogsFrame,
	ChatLogsFrame,
}

local SIDEBAR_MAP = {
	AnnounceBtn = AnnounceFrame,
	MusicBtn = MusicFrame,
	CodesBtn = CodesFrame,
	MultipliersBtn = MultipliersFrame,
	EffectsBtn = EffectsFrame,
	WipeDataBtn = WipeDataFrame,
	SessionLogsBtn = SessionLogsFrame,
	ChatLogsBtn = ChatLogsFrame,
}

local panelOpen = false
local typewriterEnabled = false
local soundEnabled = false
local currentSessionLogs = ""
local currentChatLogs = ""
local musicList = {}
local activeRainbowConnection = nil
local announcementActive = false
local announcementVersion = 0
local musicBeatConnection = nil
local globalEffectsEnabled = false

local TYPEWRITER_SOUND_ID = "rbxassetid://96949444184991"
local TYPEWRITER_DELAY = 0.04
local SESSION_LOG_MAX = 50
local CHAT_LOG_MAX = 50
local KEEP_LOOP_ENABLED = true

local TopBarBtn = Instance.new("TextButton")
TopBarBtn.Name = "TopBarToggleBtn"
TopBarBtn.Size = UDim2.new(0, 36, 0, 28)
TopBarBtn.Position = UDim2.new(1, -190, 0, 4)
TopBarBtn.AnchorPoint = Vector2.new(0, 0)
TopBarBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
TopBarBtn.Text = "Admin"
TopBarBtn.TextColor3 = Color3.new(1, 1, 1)
TopBarBtn.TextSize = 12
TopBarBtn.Font = Enum.Font.GothamBold
TopBarBtn.BorderSizePixel = 0
TopBarBtn.ZIndex = 500
TopBarBtn.AutoButtonColor = false
TopBarBtn.Parent = Gui
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 6)
topCorner.Parent = TopBarBtn
TopBarBtn.MouseEnter:Connect(function()
	TweenService:Create(TopBarBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(140, 70, 255)}):Play()
end)
TopBarBtn.MouseLeave:Connect(function()
	TweenService:Create(TopBarBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(100, 50, 200)}):Play()
end)

MainFrame.Visible = false
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.ZIndex = 350

local function hideAllFrames()
	for _, frame in ipairs(ALL_FRAMES) do
		frame.Visible = false
	end
end

local function showFrame(targetFrame)
	hideAllFrames()
	if targetFrame then
		targetFrame.Visible = true
	end
end

local function highlightSidebar(activeBtnName)
	for name, _ in pairs(SIDEBAR_MAP) do
		local btn = Sidebar:FindFirstChild(name)
		if btn then
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		end
	end
	local activeBtn = Sidebar:FindFirstChild(activeBtnName)
	if activeBtn then
		activeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
	end
end

local DimOverlay = Instance.new("TextButton")
DimOverlay.Name = "DimOverlay"
DimOverlay.Size = UDim2.new(1, 0, 1, 0)
DimOverlay.Position = UDim2.new(0, 0, 0, 0)
DimOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
DimOverlay.BackgroundTransparency = 0.5
DimOverlay.BorderSizePixel = 0
DimOverlay.Text = ""
DimOverlay.ZIndex = 300
DimOverlay.Visible = false
DimOverlay.Parent = Gui
DimOverlay.Activated:Connect(function()
	panelOpen = false
	MainFrame.Visible = false
	DimOverlay.Visible = false
end)

TopBarBtn.Activated:Connect(function()
	panelOpen = not panelOpen
	MainFrame.Visible = panelOpen
	DimOverlay.Visible = panelOpen
	if panelOpen then
		showFrame(AnnounceFrame)
		highlightSidebar("AnnounceBtn")
		AdminRemote:FireServer({ Action = "GetSessionLogs" })
		AdminRemote:FireServer({ Action = "GetChatLogs" })
		AdminRemote:FireServer({ Action = "GetMusicList" })
		AdminRemote:FireServer({ Action = "GetEffectsStatus" })
	end
end)

for name, frame in pairs(SIDEBAR_MAP) do
	local btn = Sidebar:FindFirstChild(name)
	if btn then
		btn.Activated:Connect(function()
			showFrame(frame)
			highlightSidebar(name)
		end)
	end
end

Header:WaitForChild("TextLabel").Text = "ADMIN ABUSE PANEL"

BroadcastBtn.Activated:Connect(function()
	local msg = AnnounceMessageBox.Text
	local dur = tonumber(AnnounceDurationBox.Text) or 8
	local col = AnnounceColorBox.Text
	if msg == "" then
		return
	end
	AdminRemote:FireServer({
		Action = "Broadcast",
		Message = msg,
		Duration = dur,
		Color = col,
		Typewriter = typewriterEnabled,
		UseSound = soundEnabled,
	})
end)

TypewriterToggleBtn.Activated:Connect(function()
	typewriterEnabled = not typewriterEnabled
	TypewriterToggleBtn.Text = typewriterEnabled and "TYPEWRITER: ON" or "TYPEWRITER: OFF"
end)

SoundToggleBtn.Activated:Connect(function()
	soundEnabled = not soundEnabled
	SoundToggleBtn.Text = soundEnabled and "SOUND: ON" or "SOUND: OFF"
end)

local currentSongName = ""

local function buildMusicList()
	for _, child in ipairs(MusicSongListFrame:GetChildren()) do
		if child:IsA("TextButton") and child.Name:match("SongItem_") then
			child:Destroy()
		end
	end
	local oldSearchGroup = MusicFrame:FindFirstChild("SongSearchGroup")
	if oldSearchGroup then
		oldSearchGroup.Visible = false
	end
	if #musicList == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "SongItem_empty"
		empty.Size = UDim2.new(1, -10, 0, 30)
		empty.BackgroundTransparency = 1
		empty.Text = "No songs in ReplicatedStorage.Music yet"
		empty.TextColor3 = Color3.fromRGB(120, 120, 140)
		empty.TextSize = 13
		empty.Font = Enum.Font.Gotham
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.BorderSizePixel = 0
		empty.LayoutOrder = 0
		empty.Parent = MusicSongListFrame
		return
	end
	for i, songName in ipairs(musicList) do
		local btn = Instance.new("TextButton")
		btn.Name = "SongItem_" .. songName
		btn.Size = UDim2.new(1, -10, 0, 30)
		btn.BackgroundColor3 = currentSongName == songName and Color3.fromRGB(80, 50, 180) or Color3.fromRGB(45, 45, 65)
		btn.Text = "  " .. songName
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextSize = 13
		btn.Font = Enum.Font.Gotham
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BorderSizePixel = 0
		btn.LayoutOrder = i
		btn.Parent = MusicSongListFrame
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = btn
		btn.Activated:Connect(function()
			currentSongName = songName
			AdminRemote:FireServer({ Action = "PlayMusic", SongName = songName })
			buildMusicList()
		end)
	end
end

local function duckBackgroundMusic(duck)
	local bgMusic = SoundService:FindFirstChild("SpeedsterBackgroundMusic")
	if bgMusic then
		if duck then
			bgMusic.Volume = 0
		else
			local isMuted = Players.LocalPlayer:GetAttribute("Muted") == true
			bgMusic.Volume = isMuted and 0 or 0.24
		end
	end
end

PlayMusicBtn.Activated:Connect(function()
	if currentSongName == "" then
		return
	end
	AdminRemote:FireServer({ Action = "PlayMusic", SongName = currentSongName })
end)

StopMusicBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "StopMusic" })
end)

local ResumeMusicBtn = Instance.new("TextButton")
ResumeMusicBtn.Name = "ResumeMusicBtn"
ResumeMusicBtn.Size = UDim2.new(1, 0, 0, 30)
ResumeMusicBtn.BackgroundColor3 = Color3.fromRGB(20, 120, 200)
ResumeMusicBtn.Text = "▶ CONTINUE MUSIC"
ResumeMusicBtn.TextColor3 = Color3.new(1, 1, 1)
ResumeMusicBtn.TextSize = 11
ResumeMusicBtn.Font = Enum.Font.GothamBold
ResumeMusicBtn.BorderSizePixel = 0
ResumeMusicBtn.LayoutOrder = 3
ResumeMusicBtn.Parent = MusicFrame
local rcCorner = Instance.new("UICorner")
rcCorner.CornerRadius = UDim.new(0, 6)
rcCorner.Parent = ResumeMusicBtn

ResumeMusicBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "ResumeMusic" })
end)

CreateCodeBtn.Activated:Connect(function()
	AdminRemote:FireServer({
		Action = "CreateCode",
		CodeName = CodeNameBox.Text,
		StatName = StatNameBox.Text,
		StatAmount = StatAmountBox.Text,
	})
end)

ApplyMultipliersBtn.Activated:Connect(function()
	AdminRemote:FireServer({
		Action = "ApplyMultipliers",
		SpeedValue = SpeedValueBox.Text,
		JumpValue = JumpValueBox.Text,
		WinMulti = WinMultiBox.Text,
	})
end)

local SpawnDurationLabel = Instance.new("TextLabel")
SpawnDurationLabel.Name = "SpawnDurationLabel"
SpawnDurationLabel.Size = UDim2.new(1, 0, 0, 18)
SpawnDurationLabel.BackgroundTransparency = 1
SpawnDurationLabel.Text = "Spawn duration (seconds, optional)"
SpawnDurationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpawnDurationLabel.TextSize = 10
SpawnDurationLabel.Font = Enum.Font.Gotham
SpawnDurationLabel.TextXAlignment = Enum.TextXAlignment.Left
SpawnDurationLabel.Parent = MultipliersFrame

local SpawnDurationBox = Instance.new("TextBox")
SpawnDurationBox.Name = "SpawnDurationBox"
SpawnDurationBox.Size = UDim2.new(1, 0, 0, 28)
SpawnDurationBox.PlaceholderText = "Leave empty for permanent"
SpawnDurationBox.Text = ""
SpawnDurationBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
SpawnDurationBox.BackgroundTransparency = 0.4
SpawnDurationBox.TextColor3 = Color3.new(1, 1, 1)
SpawnDurationBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
SpawnDurationBox.TextSize = 11
SpawnDurationBox.Font = Enum.Font.Gotham
SpawnDurationBox.ClearTextOnFocus = true
SpawnDurationBox.Parent = MultipliersFrame
local sdCorner = Instance.new("UICorner")
sdCorner.CornerRadius = UDim.new(0, 6)
sdCorner.Parent = SpawnDurationBox

local TreadmillSpeedLabel = Instance.new("TextLabel")
TreadmillSpeedLabel.Size = UDim2.new(1, 0, 0, 14)
TreadmillSpeedLabel.BackgroundTransparency = 1
TreadmillSpeedLabel.Text = "Treadmill speed multiplier (x)"
TreadmillSpeedLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TreadmillSpeedLabel.TextSize = 9
TreadmillSpeedLabel.Font = Enum.Font.Gotham
TreadmillSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
TreadmillSpeedLabel.Parent = MultipliersFrame

local TreadmillSpeedBox = Instance.new("TextBox")
TreadmillSpeedBox.Size = UDim2.new(1, 0, 0, 24)
TreadmillSpeedBox.PlaceholderText = "Default: 5"
TreadmillSpeedBox.Text = "5"
TreadmillSpeedBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TreadmillSpeedBox.BackgroundTransparency = 0.4
TreadmillSpeedBox.TextColor3 = Color3.new(1, 1, 1)
TreadmillSpeedBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
TreadmillSpeedBox.TextSize = 10
TreadmillSpeedBox.Font = Enum.Font.Gotham
TreadmillSpeedBox.ClearTextOnFocus = true
TreadmillSpeedBox.Parent = MultipliersFrame
local tsc = Instance.new("UICorner")
tsc.CornerRadius = UDim.new(0, 6)
tsc.Parent = TreadmillSpeedBox

local TreadmillWinLabel = Instance.new("TextLabel")
TreadmillWinLabel.Size = UDim2.new(1, 0, 0, 14)
TreadmillWinLabel.BackgroundTransparency = 1
TreadmillWinLabel.Text = "Treadmill wins multiplier (x)"
TreadmillWinLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
TreadmillWinLabel.TextSize = 9
TreadmillWinLabel.Font = Enum.Font.Gotham
TreadmillWinLabel.TextXAlignment = Enum.TextXAlignment.Left
TreadmillWinLabel.Parent = MultipliersFrame

local TreadmillWinBox = Instance.new("TextBox")
TreadmillWinBox.Size = UDim2.new(1, 0, 0, 24)
TreadmillWinBox.PlaceholderText = "Default: 2"
TreadmillWinBox.Text = "2"
TreadmillWinBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TreadmillWinBox.BackgroundTransparency = 0.4
TreadmillWinBox.TextColor3 = Color3.new(1, 1, 1)
TreadmillWinBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
TreadmillWinBox.TextSize = 10
TreadmillWinBox.Font = Enum.Font.Gotham
TreadmillWinBox.ClearTextOnFocus = true
TreadmillWinBox.Parent = MultipliersFrame
local twc = Instance.new("UICorner")
twc.CornerRadius = UDim.new(0, 6)
twc.Parent = TreadmillWinBox

SpawnTreadmillBtn.Activated:Connect(function()
	local duration = tonumber(SpawnDurationBox.Text)
	AdminRemote:FireServer({
		Action = "SpawnTreadmill",
		Duration = duration,
		SpeedMult = tonumber(TreadmillSpeedBox.Text),
		WinMult = tonumber(TreadmillWinBox.Text),
	})
end)

-- Permanent remove button (present in the ServerStorage template so it cannot
-- be lost): fires the same server-side despawn action as the legacy runtime button.
local DespawnTreadmillBtn = MultipliersFrame:WaitForChild("RemoveTreadmillBtn", 15)
if DespawnTreadmillBtn then
	DespawnTreadmillBtn.Activated:Connect(function()
		AdminRemote:FireServer({ Action = "DespawnTreadmill" })
	end)
end

ResetAllNormalBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "ResetAllNormal" })
end)

ToggleStrobeBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "ToggleStrobe" })
end)

ToggleFogBtn.Activated:Connect(function()
	AdminRemote:FireServer({ Action = "ToggleFog" })
end)

local GlobalEffectsToggleBtn = Instance.new("TextButton")
GlobalEffectsToggleBtn.Name = "GlobalEffectsToggleBtn"
GlobalEffectsToggleBtn.Size = UDim2.new(1, 0, 0, 34)
GlobalEffectsToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
GlobalEffectsToggleBtn.Text = "GLOBAL: OFF"
GlobalEffectsToggleBtn.TextColor3 = Color3.new(1, 1, 1)
GlobalEffectsToggleBtn.TextSize = 12
GlobalEffectsToggleBtn.Font = Enum.Font.GothamBold
GlobalEffectsToggleBtn.BorderSizePixel = 0
GlobalEffectsToggleBtn.LayoutOrder = 2
GlobalEffectsToggleBtn.Parent = EffectsFrame
local geCorner = Instance.new("UICorner")
geCorner.CornerRadius = UDim.new(0, 6)
geCorner.Parent = GlobalEffectsToggleBtn
GlobalEffectsToggleBtn.Activated:Connect(function()
	globalEffectsEnabled = not globalEffectsEnabled
	GlobalEffectsToggleBtn.Text = globalEffectsEnabled and "GLOBAL: ON" or "GLOBAL: OFF"
	GlobalEffectsToggleBtn.BackgroundColor3 = globalEffectsEnabled and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(45, 45, 65)
end)

local function makeConfettiBox(labelText, placeholder, default, order)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 14)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
	lbl.TextSize = 9
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order
	lbl.Parent = EffectsFrame
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 24)
	box.PlaceholderText = placeholder
	box.Text = default
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	box.BackgroundTransparency = 0.4
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
	box.TextSize = 10
	box.Font = Enum.Font.Gotham
	box.ClearTextOnFocus = true
	box.LayoutOrder = order + 1
	box.Parent = EffectsFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = box
	return box
end

ConfettiEffectBtn.LayoutOrder = 10
local ConfettiLifetimeBox = makeConfettiBox("Confetti lifetime (seconds)", "Default: 5", "5", 11)
local ConfettiCountBox = makeConfettiBox("Confetti count", "Default: 15", "15", 13)
local makeMultTypeBtn = function(label, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.48, 0, 0, 26)
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	btn.Text = label
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 10
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order
	btn.Parent = EffectsFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	return btn
end
local confettiMultType = "BOTH"
local ConfettiMultBothBtn = makeMultTypeBtn("BOTH (Speed+Wins)", 15)
local ConfettiMultSpeedBtn = makeMultTypeBtn("SPEED ONLY", 16)
local ConfettiMultWinsBtn = makeMultTypeBtn("WINS ONLY", 17)
local function highlightMultTypeBtn(activeBtn)
	ConfettiMultBothBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	ConfettiMultSpeedBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	ConfettiMultWinsBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
	activeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
end
ConfettiMultBothBtn.Activated:Connect(function() confettiMultType = "BOTH" highlightMultTypeBtn(ConfettiMultBothBtn) end)
ConfettiMultSpeedBtn.Activated:Connect(function() confettiMultType = "SPEED" highlightMultTypeBtn(ConfettiMultSpeedBtn) end)
ConfettiMultWinsBtn.Activated:Connect(function() confettiMultType = "WINS" highlightMultTypeBtn(ConfettiMultWinsBtn) end)
highlightMultTypeBtn(ConfettiMultBothBtn)
local ConfettiMultAmountBox = makeConfettiBox("Multiplier amount (x)", "Default: 2", "2", 18)
local ConfettiBoostDurBox = makeConfettiBox("Boost duration (minutes)", "Default: 5", "5", 20)

local DiscoBrightnessBox = makeConfettiBox("Disco brightness (0-1)", "Default: 0.35", "0.35", 26)
local DiscoBallCountBox = makeConfettiBox("Disco ball count", "Default: 1", "1", 32)

ToggleDiscoBtn.Activated:Connect(function()
	AdminRemote:FireServer({
		Action = "ToggleDisco",
		Global = globalEffectsEnabled,
		DiscoSpec = globalEffectsEnabled and {
			Brightness = tonumber(DiscoBrightnessBox.Text) or 0.35,
			BallCount = tonumber(DiscoBallCountBox.Text) or 1,
		} or nil,
	})
end)

ConfettiEffectBtn.Activated:Connect(function()
	local amount = tonumber(ConfettiMultAmountBox.Text) or 2
	local speedMult = (confettiMultType == "BOTH" or confettiMultType == "SPEED") and amount or 1
	local winMult = (confettiMultType == "BOTH" or confettiMultType == "WINS") and amount or 1
	AdminRemote:FireServer({
		Action = "ConfettiEffect",
		Duration = tonumber(ConfettiLifetimeBox.Text) or 5,
		Count = tonumber(ConfettiCountBox.Text) or 15,
		SpeedMult = speedMult,
		WinMult = winMult,
		BoostDuration = tonumber(ConfettiBoostDurBox.Text) or 5,
		Global = globalEffectsEnabled,
	})
end)

local CameraShakeBtn = Instance.new("TextButton")
CameraShakeBtn.Name = "CameraShakeBtn"
CameraShakeBtn.Size = UDim2.new(1, 0, 0, 34)
CameraShakeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 30)
CameraShakeBtn.Text = "CAMERA SHAKE"
CameraShakeBtn.TextColor3 = Color3.new(1, 1, 1)
CameraShakeBtn.TextSize = 13
CameraShakeBtn.Font = Enum.Font.GothamBold
CameraShakeBtn.BorderSizePixel = 0
CameraShakeBtn.LayoutOrder = 22
CameraShakeBtn.Parent = EffectsFrame
local csCorner = Instance.new("UICorner")
csCorner.CornerRadius = UDim.new(0, 6)
csCorner.Parent = CameraShakeBtn
local CameraShakeIntensityBox = makeConfettiBox("Shake intensity (0.1-5)", "Default: 1", "1", 23)
local CameraShakeDurBox = makeConfettiBox("Shake duration (seconds)", "Default: 1", "1", 25)

CameraShakeBtn.Activated:Connect(function()
	AdminRemote:FireServer({
		Action = "CameraShake",
		Intensity = tonumber(CameraShakeIntensityBox.Text) or 1,
		Duration = tonumber(CameraShakeDurBox.Text) or 1,
	})
end)

ConfirmWipeBtn.Activated:Connect(function()
	AdminRemote:FireServer({
		Action = "WipeData",
		Target = WipeTargetBox.Text,
	})
end)

local function formatLogTime(unixTime)
	return os.date("%H:%M:%S", unixTime)
end

local function renderSessionLogs()
	SessionLogsText.Text = currentSessionLogs
end

local function renderChatLogs()
	ChatLogsText.Text = currentChatLogs
end

local function appendSessionLog(entry)
	local line = "<font color=\"rgb(170,130,255)\">" .. formatLogTime(entry.Time) .. "</font> "
	line = line .. "<font color=\"rgb(255,220,100)\">" .. entry.Admin .. "</font> "
	line = line .. "<font color=\"rgb(200,200,210)\">" .. entry.Action .. "</font>"
	if entry.Details and entry.Details ~= "" then
		line = line .. " <font color=\"rgb(150,150,170)\">" .. entry.Details .. "</font>"
	end
	currentSessionLogs = currentSessionLogs .. line .. "\n"
	local lines = currentSessionLogs:split("\n")
	if #lines > SESSION_LOG_MAX then
		local trimmed = {}
		for i = #lines - SESSION_LOG_MAX + 1, #lines do
			if lines[i] and lines[i] ~= "" then
				table.insert(trimmed, lines[i])
			end
		end
		currentSessionLogs = table.concat(trimmed, "\n") .. "\n"
	end
	renderSessionLogs()
end

local function appendChatLog(entry)
	local line = "<font color=\"rgb(100,180,255)\">" .. formatLogTime(entry.Time) .. "</font> "
	line = line .. "<font color=\"rgb(255,255,100)\">" .. entry.Player .. "</font>: "
	line = line .. "<font color=\"rgb(220,220,230)\">" .. entry.Message .. "</font>"
	currentChatLogs = currentChatLogs .. line .. "\n"
	local lines = currentChatLogs:split("\n")
	if #lines > CHAT_LOG_MAX then
		local trimmed = {}
		for i = #lines - CHAT_LOG_MAX + 1, #lines do
			if lines[i] and lines[i] ~= "" then
				table.insert(trimmed, lines[i])
			end
		end
		currentChatLogs = table.concat(trimmed, "\n") .. "\n"
	end
	renderChatLogs()
end

local function handleBroadcast(data)
	announcementVersion += 1
	local myVersion = announcementVersion
	announcementActive = true

	if activeRainbowConnection then
		activeRainbowConnection:Disconnect()
		activeRainbowConnection = nil
	end

	local msgGui = playerGui:FindFirstChild("Messages")
	if not msgGui then msgGui = playerGui:WaitForChild("Messages", 10) end
	if not msgGui then return end
	local container = msgGui:FindFirstChild("Container")
	if not container then return end
	local template = container:FindFirstChild("AnnouncementMessage")
	if not template then return end

	local clone = template:Clone()
	clone.Visible = true
	clone.Background.BackgroundTransparency = 1
	clone.Background.TextLabel.TextTransparency = 1
	clone.Background.TextLabel.UIStroke.Transparency = 1
	clone.Background.TextLabel.RichText = true
	clone.Parent = container

	local twSound = nil
	if data.UseSound then
		twSound = Instance.new("Sound")
		twSound.SoundId = TYPEWRITER_SOUND_ID
		twSound.Volume = 0.5
		twSound.Parent = SoundService
	end

	local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local bg = clone.Background
	local tl = bg.TextLabel

	TweenService:Create(bg, fadeInfo, {BackgroundTransparency = 0}):Play()
	TweenService:Create(tl, fadeInfo, {TextTransparency = 0}):Play()
	TweenService:Create(tl.UIStroke, fadeInfo, {Transparency = 0}):Play()

	local function setText(content)
		if myVersion ~= announcementVersion then return end
		tl.Text = content
	end

	local fullMsg = data.FormattedText
	local plainContent = fullMsg:match(':</font>%s*(.*)') or fullMsg:match(':%s*(.*)') or fullMsg
	local namePart = fullMsg:match('(.+:</font>)') or fullMsg:match('(.+:)') or ""
	if namePart ~= "" then
		namePart = namePart .. " "
	end

	if data.Typewriter then
		for i = 1, #plainContent do
			if myVersion ~= announcementVersion then
				break
			end
			setText(namePart .. plainContent:sub(1, i))
			if twSound then
				twSound.TimePosition = 0
				twSound:Play()
			end
			task.wait(TYPEWRITER_DELAY)
		end
		if myVersion ~= announcementVersion then
			clone:Destroy()
			if twSound then twSound:Destroy() end
			return
		end
	else
		setText(data.FormattedText)
	end

	if data.ColorMode == "RAINBOW" then
		local startTime = os.clock()
		local nameColor = data.ColorValue
		local nameStr = ""
		if nameColor and typeof(nameColor) == "Color3" then
			local nr = math.floor(nameColor.R * 255)
			local ng = math.floor(nameColor.G * 255)
			local nb = math.floor(nameColor.B * 255)
			nameStr = '<font color="rgb(' .. nr .. ',' .. ng .. ',' .. nb .. ')">' .. (data.AdminName or "") .. '</font>' .. (data.HasBadge and '<font color="rgb(40,220,140)"><b> </b></font>' or '') .. ': '
		else
			nameStr = namePart
		end
		activeRainbowConnection = RunService.RenderStepped:Connect(function()
			if myVersion ~= announcementVersion then
				if activeRainbowConnection then activeRainbowConnection:Disconnect() end
				activeRainbowConnection = nil
				return
			end
			local hue = (os.clock() - startTime) * 0.3 % 1
			local color = Color3.fromHSV(hue, 1, 1)
			local r = math.floor(color.R * 255)
			local g = math.floor(color.G * 255)
			local b = math.floor(color.B * 255)
			setText(nameStr .. '<font color="rgb(' .. r .. ',' .. g .. ',' .. b .. ')">' .. plainContent .. '</font>')
		end)
	end

	local typewriterDuration = 0
	if data.Typewriter then
		typewriterDuration = #plainContent * TYPEWRITER_DELAY
	end
	task.delay(data.Duration + typewriterDuration, function()
		if myVersion ~= announcementVersion then return end
		announcementActive = false
		if activeRainbowConnection then
			activeRainbowConnection:Disconnect()
			activeRainbowConnection = nil
		end
		local outInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(bg, outInfo, {BackgroundTransparency = 1}):Play()
		TweenService:Create(tl, outInfo, {TextTransparency = 1}):Play()
		local strokeTween = TweenService:Create(tl.UIStroke, outInfo, {Transparency = 1})
		strokeTween:Play()
		strokeTween.Completed:Wait()
		clone:Destroy()
		if twSound then twSound:Destroy() end
	end)
end


local function confettiCollectedFX(minutes, speedMult, winMult)
	local camera = workspace.CurrentCamera
	local baseFoV = camera and camera.FieldOfView or 70

	if camera then
		local fovUp = TweenService:Create(camera, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = math.min(baseFoV + 22, 120) })
		local fovDown = TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { FieldOfView = baseFoV })
		fovUp:Play()
		fovUp.Completed:Connect(function()
			fovDown:Play()
		end)
	end

	local shakeStart = os.clock()
	local shakeConn = nil
	shakeConn = RunService.RenderStepped:Connect(function()
		if not camera then
			shakeConn:Disconnect()
			return
		end
		local elapsed = os.clock() - shakeStart
		if elapsed > 0.4 then
			shakeConn:Disconnect()
			return
		end
		local decay = 1 - (elapsed / 0.4)
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * 0.9 * decay,
			(math.random() - 0.5) * 0.9 * decay,
			(math.random() - 0.5) * 0.4 * decay
		)
	end)

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.35
	flash.BorderSizePixel = 0
	flash.ZIndex = 999
	flash.Parent = playerGui
	local fade = TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function() flash:Destroy() end)

	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.new(0.5, 0, 0.45, 0)
	toast.Size = UDim2.new(0, 360, 0, 60)
	toast.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = Color3.new(0, 0, 0)
	local speedLabel = (speedMult and speedMult ~= 1) and (tostring(speedMult) .. "x SPEED") or ""
	local winLabel = (winMult and winMult ~= 1) and (tostring(winMult) .. "x WINS") or ""
	local parts = {}
	if speedLabel ~= "" then table.insert(parts, speedLabel) end
	if winLabel ~= "" then table.insert(parts, winLabel) end
	if #parts == 0 then table.insert(parts, "BOOST") end
	toast.Text = table.concat(parts, " & ") .. "\n+" .. tostring(minutes or 5) .. " MIN"
	toast.TextSize = 22
	toast.Font = Enum.Font.GothamBold
	toast.TextStrokeTransparency = 0.4
	toast.TextWrapped = true
	toast.ZIndex = 998
	toast.Parent = playerGui
	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 10)
	tCorner.Parent = toast
	local toastTween = TweenService:Create(toast, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = 1, TextTransparency = 1 })
	toastTween:Play()
	toastTween.Completed:Connect(function() toast:Destroy() end)
end

AdminRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end

	-- "Event effects" toggle: when disabled, suppress the admin-abuse event
	-- effects (announcements, music playback, camera shake, and the
	-- disco/strobe/fog toggles). Confetti (ConfettiCollected) and the separate
	-- level-up celebration are intentionally left unaffected.
	if player:GetAttribute("EventEffects") == false then
		if data.Type == "Broadcast" or data.Type == "PlayMusic" or data.Type == "StopMusic"
			or data.Type == "ResumeMusic" or data.Type == "CameraShake" or data.Type == "EffectsStatus" then
			return
		end
	end

	if data.Type == "Broadcast" then
		handleBroadcast(data)

	elseif data.Type == "ActionResult" then
		if data.Ok then
			print("[AdminAbuse] " .. tostring(data.Message))
		else
			warn("[AdminAbuse] " .. tostring(data.Message))
		end

	elseif data.Type == "ConfettiCollected" then
		confettiCollectedFX(tonumber(data.Minutes) or 5, tonumber(data.SpeedMult) or 2, tonumber(data.WinMult) or 2)

	elseif data.Type == "PlayMusic" then
		local existing = SoundService:FindFirstChild("AdminAbuseMusic")
		if existing then existing:Destroy() end
		if musicBeatConnection then musicBeatConnection:Disconnect() musicBeatConnection = nil end
		duckBackgroundMusic(true)
		local sound = Instance.new("Sound")
		sound.Name = "AdminAbuseMusic"
		sound.SoundId = data.SoundId
		sound.Looped = KEEP_LOOP_ENABLED and not string.find((data.SongName or ""):lower(), "^admin")
		sound.Volume = 0.7
		sound.Parent = SoundService
		sound:Play()
		local bpm = tonumber(data.BPM) or 128
		local beatInterval = 60 / bpm
		local beatT = 0
		musicBeatConnection = RunService.RenderStepped:Connect(function(dt)
			if not sound.Parent or not sound.Playing then return end
			beatT = beatT + dt
			if beatT >= beatInterval then
				beatT = beatT - beatInterval
				local cam = workspace.CurrentCamera
				if cam then
					local baseFoV = 70
					cam.FieldOfView = baseFoV + 4
					task.delay(0.08, function()
						if cam then cam.FieldOfView = baseFoV end
					end)
				end
			end
		end)

	elseif data.Type == "StopMusic" then
		local existing = SoundService:FindFirstChild("AdminAbuseMusic")
		if existing then
			existing:Pause()
		end
		if musicBeatConnection then musicBeatConnection:Disconnect() musicBeatConnection = nil end
		duckBackgroundMusic(false)

	elseif data.Type == "ResumeMusic" then
		local existing = SoundService:FindFirstChild("AdminAbuseMusic")
		if existing then
			duckBackgroundMusic(true)
			existing:Resume()
		end

	elseif data.Type == "MusicList" then
		musicList = data.Songs or {}
		buildMusicList()

	elseif data.Type == "EffectsStatus" then
		effectState.Disco = data.Disco == true
		effectState.Strobe = data.Strobe == true
		effectState.Fog = data.Fog == true
		renderEffectsStatus()

	elseif data.Type == "SessionLog" then
		if data.Entry then
			appendSessionLog(data.Entry)
		end

	elseif data.Type == "ChatLog" then
		if data.Entry then
			appendChatLog(data.Entry)
		end

	elseif data.Type == "CameraShake" then
		local intensity = tonumber(data.Intensity) or 1
		local dur = tonumber(data.Duration) or 1
		local cam = workspace.CurrentCamera
		if cam then
			local shakeStart = os.clock()
			local shakeConn = nil
			shakeConn = RunService.RenderStepped:Connect(function()
				if not cam then shakeConn:Disconnect() return end
				local elapsed = os.clock() - shakeStart
				if elapsed > dur then shakeConn:Disconnect() return end
				local decay = 1 - (elapsed / dur)
				cam.CFrame = cam.CFrame * CFrame.new(
					(math.random() - 0.5) * intensity * decay,
					(math.random() - 0.5) * intensity * decay,
					(math.random() - 0.5) * intensity * 0.5 * decay
				)
			end)
		end

	elseif data.Type == "ResetAllNormal" then
		local existing = SoundService:FindFirstChild("AdminAbuseMusic")
		if existing then
			existing:Stop()
			existing:Destroy()
		end
		if musicBeatConnection then
			musicBeatConnection:Disconnect()
			musicBeatConnection = nil
		end
		duckBackgroundMusic(false)
	end
end)

player.CharacterRemoving:Connect(function()
	announcementActive = false
	announcementVersion += 1
	if activeRainbowConnection then
		activeRainbowConnection:Disconnect()
		activeRainbowConnection = nil
	end
end)