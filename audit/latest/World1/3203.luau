local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TemporaryBoostUpdate = remotes:WaitForChild("TemporaryBoostUpdate")
local CodesUpdate = remotes:WaitForChild("CodesUpdate")
local function getToastElements()
	local toastGui = playerGui:FindFirstChild("ToastMessages")
	if not toastGui then
		toastGui = playerGui:WaitForChild("ToastMessages", 10)
	end
	if not toastGui then return nil, nil end
	local toast = toastGui:FindFirstChild("Toast")
	if not toast then
		toast = toastGui:WaitForChild("Toast", 10)
	end
	return toastGui, toast
end

local toastGui, toast = getToastElements()
if toast then
	toast.Visible = false
	-- Modern centered banner styling
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.06, 0)
	toast.Size = UDim2.new(0.65, 0, 0, 46)
	toast.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	toast.BackgroundTransparency = 0.12
	toast.TextScaled = true

	local corner = toast:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = toast
	end

	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = toast
	end
	stroke.Color = Color3.fromRGB(50, 180, 255)
	stroke.Transparency = 0.3
end

if toastGui then
	toastGui.Enabled = false
	toastGui.DisplayOrder = 100
	toastGui.ResetOnSpawn = false
end

local winSound = Instance.new("Sound")
winSound.Name = "ToastSuccessSound"
winSound.SoundId = "rbxassetid://80736831159506"
winSound.Volume = 0.9
winSound.Parent = SoundService

local serial = 0
local function showToast(message, success)
	if type(message) ~= "string" or message == "" then return end
	local gui, label = getToastElements()
	if not gui or not label then return end
	if Players.LocalPlayer:GetAttribute("HidePopups") == true then return end

	serial += 1
	local current = serial
	label.Text = message
	label.TextColor3 = success and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 95, 95)
	
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = success and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 95, 95)
	end

	label.Visible = true
	gui.Enabled = true

	if success then
		winSound.TimePosition = 0
		SoundService:PlayLocalSound(winSound)
	end

	task.delay(4, function()
		if current == serial then
			label.Visible = false
			gui.Enabled = false
		end
	end)
end

TemporaryBoostUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and (payload.Type == "SpeedPotion" or payload.Type == "WinsPotion" or payload.Type == "ServerBoost") then
		showToast(tostring(payload.Message or ""), true)
	end
end)

CodesUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	showToast(tostring(data.Message or ""), data.Success == true)
end)