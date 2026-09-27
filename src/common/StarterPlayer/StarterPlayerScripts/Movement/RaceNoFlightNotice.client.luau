-- Movement/RaceNoFlightNotice.client.luau
-- 2026-09-26 (owner): "Flying is off in races" (Shared/RaceNoFlight), or "Flying is off during the event"
-- while a live event grounds the player (RaceNoFlight.Reason "Event"). The world Flight clients
-- report a refused or ended flight in a race or the race arena (RaceNoFlight.Notify: a held
-- Fly press, the server's refusal, a flight landed at staging); this shows the line for two
-- seconds in the player's language, once per RaceNoFlight.RepeatSeconds.
-- Its own small ScreenGui, kept on screen by InterfaceHider (NeverHide): during a race the
-- normal HUD is away (UI/RaceHudController), and that is exactly when the line matters.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaceNoFlight = require(Shared:WaitForChild("RaceNoFlight"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))

local GUI_NAME = "RaceNoFlightNotice"
local SHOW_SECONDS = 2
local FADE_SECONDS = 0.2
local PLATE_TRANSPARENCY = 0.2

InterfaceHider.NeverHide[GUI_NAME] = true

local gui, plate, label, stroke = nil, nil, nil, nil

local function build()
	if gui and gui.Parent then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end
	gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Upper middle of the screen: over the racer, under the race HUD's top line.
	plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.36)
	plate.Size = UDim2.new(0.86, 0, 0, 44)
	plate.BackgroundColor3 = Color3.fromRGB(11, 27, 61)
	plate.BackgroundTransparency = 1
	plate.Visible = false
	plate.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 44)
	limit.Parent = plate
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = plate

	label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -24, 1, -10)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextTransparency = 1
	label.Text = ""
	pcall(function()
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	end)
	label.Parent = plate
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 24
	size.MinTextSize = 12
	size.Parent = label
	stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(11, 27, 61)
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	gui.Parent = player:WaitForChild("PlayerGui")
end

local serial = 0

local function fade(visible)
	local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(plate, info, { BackgroundTransparency = if visible then PLATE_TRANSPARENCY else 1 }):Play()
	TweenService:Create(label, info, { TextTransparency = if visible then 0 else 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = if visible then 0 else 1 }):Play()
end

-- 2026-09-26 (owner): why the flight was refused: a live event ("Flying is off during the event") or the race.
local function reason(): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return RaceNoFlight.Reason(player, if root and root:IsA("BasePart") then root.Position else nil)
end

local function show()
	build()
	local lang = TutorialText.ForPlayer(player)
	TutorialText.Style(label, lang)
	label.Text = RaceNoFlight.Message(lang, reason())
	serial += 1
	local mine = serial
	plate.Visible = true
	fade(true)
	task.delay(SHOW_SECONDS, function()
		if mine ~= serial or not plate then
			return
		end
		fade(false)
		task.delay(FADE_SECONDS, function()
			if mine == serial and plate then
				plate.Visible = false
			end
		end)
	end)
end

RaceNoFlight.OnNotice(function()
	local ok, err = pcall(show)
	if not ok then
		warn("[RaceNoFlightNotice] " .. tostring(err))
	end
end)
