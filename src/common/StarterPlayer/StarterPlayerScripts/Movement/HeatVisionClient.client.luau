-- HeatVisionClient.client.luau
-- Superman's Heat Vision Trail on this player's side (the server melts the path:
-- Core/Abilities/HeatVisionService). While the Superman skin is worn:
--   * R on a keyboard (or Y on a gamepad) fires it: toward the mouse on a PC, where the
--     camera looks with Shift Lock or a gamepad;
--   * the HUD button (StarterGui.Mainhud.HeatVisionButton, the designer's Sprint button with
--     eyes shooting beams, Shared.HeatVisionUi) fires it too: on a touch screen it waits for
--     a tap on the world and aims there ("Tap where to melt a path!"); clicked, it fires
--     where the camera looks;
--   * the button shows the cooldown (HeatVisionReadyAt, server time) as a draining cover.
-- The aim point only says which way and how far; the server decides the rest.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HeatVisionMath = require(Shared:WaitForChild("HeatVisionMath"))
local settings = HeatVisionMath.Settings(Config)
if not settings.Enabled then
	return
end
local HeatVisionUi = require(Shared:WaitForChild("HeatVisionUi"))
local HudErgonomics = require(Shared:WaitForChild("HudErgonomics"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local Request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HeatVision")

local ACTION = "SupermanHeatVision"
local AIM_SECONDS = 4 -- how long a touch waits for its aiming tap
local AIM_RANGE = 400

local function equipped()
	return player:GetAttribute("EquippedSkin") == settings.SkinId
end

local function readyIn()
	return HeatVisionMath.ReadyIn(player:GetAttribute("HeatVisionReadyAt"), Workspace:GetServerTimeNow())
end

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

----------------------------------------------------------------------
-- Aiming and firing
----------------------------------------------------------------------
-- The world point under screen point `point` (the mouse or a tap), never this character.
local function worldPointAt(point: Vector2): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 60
end

-- Straight ahead where the camera looks, as far as the path can go.
local function forwardPoint(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root then
		return nil
	end
	local direction = HeatVisionMath.FlatDirection(camera and camera.CFrame.LookVector, root.CFrame.LookVector)
	return root.Position + direction * settings.MaxLength
end

local button = nil
local function nudge()
	if button then
		local press = button:FindFirstChild("PressScale")
		if press and press:IsA("UIScale") then
			press.Scale = 0.9
			TweenService:Create(press, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
end

local function fire(target: Vector3?)
	if not target or not equipped() or readyIn() > 0 then
		nudge()
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	Request:FireServer({ Target = target })
end

-- A keyboard's R or a gamepad's Y: the mouse's point on a PC, else straight ahead.
local function onAction(_, state, input)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local pointer = input.UserInputType == Enum.UserInputType.Keyboard
		and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
	fire(if pointer then worldPointAt(UserInputService:GetMouseLocation()) else forwardPoint())
	return Enum.ContextActionResult.Sink
end

local bound = false
local function bind()
	local want = equipped()
	if want and not bound then
		ContextActionService:BindAction(ACTION, onAction, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	elseif not want and bound then
		ContextActionService:UnbindAction(ACTION)
	end
	bound = want
end

----------------------------------------------------------------------
-- The HUD button
----------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local mainhud = playerGui:WaitForChild("Mainhud", 30)
if mainhud then
	button = mainhud:FindFirstChild(HeatVisionUi.ButtonName) or mainhud:WaitForChild(HeatVisionUi.ButtonName, 5)
	if not button then
		-- A place without the saved button: the designer's Sprint button, made the same way.
		local sprint = mainhud:FindFirstChild("MobileSprint")
		if sprint then
			button = HeatVisionUi.DecorateButton(sprint:Clone())
			button.Parent = mainhud
		end
	end
end

-- MainHUDController keeps the Main HUD's state on it (HudVisible): a script that starts
-- while a menu hides the HUD must not draw the button over the menu.
local hudVisible = not (mainhud and mainhud:GetAttribute("HudVisible") == false)

-- Declared ahead: the HUD-visibility handler below calls it (a later `local function`
-- would leave that call on a nil global).
local layoutButton

MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
	hudVisible = (visible == true)
	if hudVisible and button then
		layoutButton()
	end
end)

function layoutButton()
	if not button or not mainhud or not mainhud:IsA("ScreenGui") then
		return
	end
	local hud = mainhud.AbsoluteSize
	if hud.X <= 0 or hud.Y <= 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or hud
	local topBar = (GuiService:GetGuiInset()).Y
	-- Clear of the Sonic Burst's button when it shows and of the phone column, or where the
	-- player moved it ("Move controls" in Settings) when that place is legal on this screen.
	-- The Burst button's place comes from the same plan (SonicBurstClient lays it out), not
	-- from where it is drawn now: that may be mid-slide, or not laid out yet.
	local burst = mainhud:FindFirstChild("SonicBurstButton")
	local burstShown = burst ~= nil and burst:IsA("GuiObject") and burst.Visible
	local neighbours = HudErgonomics.TouchNeighbours(viewport.X, viewport.Y, UserInputService.KeyboardEnabled, topBar)
	local layout = if UserInputService.TouchEnabled then player:GetAttribute("TouchLayout") else nil
	local plan = HudErgonomics.TouchControls(hud.X, hud.Y, layout, neighbours, burstShown).H
	button.Size = UDim2.fromOffset(plan.Size, plan.Size)
	local basePos = UDim2.fromOffset(math.floor(plan.X + 0.5), math.floor(plan.Y + 0.5))
	-- (2026-09-25) The place is published even while a menu hides the HUD: MainHUDController's
	-- show slide goes to it. It used to read the base back from the button's Position, so a
	-- slide cut short by the next menu kept its half-way point, and the button came back
	-- lower, on top of Sprint (on tablets it sits right above Sprint when no Burst shows).
	button:SetAttribute("HudBasePosition", basePos)
	if hudVisible then
		button.Position = basePos
	end
end

local aiming = nil -- while a touch waits for its aiming tap: when it gives up
local function stopAiming()
	aiming = nil
	local hint = button and button:FindFirstChild("AimHint")
	if hint then
		hint.Visible = false
	end
end

local function refreshButton()
	if not button then
		return
	end
	button.Visible = equipped()
	local key = button:FindFirstChild("KeyHint")
	if key then
		key.Visible = UserInputService.KeyboardEnabled and not touchOnly()
	end
	if not button.Visible then
		stopAiming()
	end
	layoutButton()
end

if button then
	button.Activated:Connect(function(input)
		if readyIn() > 0 then
			nudge()
			return
		end
		if input and input.UserInputType == Enum.UserInputType.Touch then
			-- Aim by touch: the next tap on the world is where the path goes.
			aiming = os.clock() + AIM_SECONDS
			local hint = button:FindFirstChild("AimHint")
			if hint then
				hint.Visible = true
			end
			nudge()
			return
		end
		fire(forwardPoint())
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not aiming or processed or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		stopAiming()
		fire(worldPointAt(Vector2.new(input.Position.X, input.Position.Y)))
	end)
	if mainhud then
		mainhud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutButton)
		player:GetAttributeChangedSignal("TouchLayout"):Connect(layoutButton)
		local burst = mainhud:FindFirstChild("SonicBurstButton")
		if burst then
			burst:GetPropertyChangedSignal("Visible"):Connect(layoutButton)
		end
	end
end

-- The cooldown cover, the seconds, and a touch that waited too long.
RunService.Heartbeat:Connect(function()
	if not button or not button.Visible then
		return
	end
	if aiming and os.clock() > aiming then
		stopAiming()
	end
	local left = readyIn()
	local cover = button:FindFirstChild("Cooldown")
	local seconds = button:FindFirstChild("Seconds")
	if cover then
		cover.Visible = left > 0
		cover.Size = UDim2.fromScale(1, math.clamp(left / settings.CooldownSeconds, 0, 1))
	end
	if seconds then
		seconds.Visible = left > 0
		seconds.Text = tostring(math.ceil(left))
	end
end)

player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
	bind()
	refreshButton()
end)
UserInputService.LastInputTypeChanged:Connect(refreshButton)
bind()
refreshButton()
