-- Builds the finished game UIs that are saved into every place's StarterGui (build_core's
-- ASSETS), so they are real instances in the .rbxl files that can be seen and edited in
-- Studio, rather than panels made from code when a player joins:
--
--   src/ui/SpinWheelGui.rbxm   the designer's Spin Wheel panel (design/ui), with what the
--                              game adds to it (SpinWheelExtras: rarity colours, hub cap,
--                              the Wins spin, the X10 pack and their captions)
--   src/ui/AfkRewardsGui.rbxm  the designer's Earnings panel (the AFK Zone's rewards)
--   src/ui/QuestGui.rbxm       the designer's Choose Your Destiny panel (design/ui/Quests.rbxm),
--                              with what the game adds to it (Shared/QuestUi.Decorate: the
--                              timer, the close button, progress bars, the phone scroll)
--
-- Both are ResetOnSpawn = false and start closed; their controllers open them. Run it
-- whenever the designer's file, SpinWheelExtras or the Spin Wheel's packs change, then
-- build_core.
--
-- Usage: lune run audit/build_ui_prefabs.luau              everything
--        lune run audit/build_ui_prefabs.luau QuestGui     only the named groups (GROUPS below)
-- Build one group when only its sources changed: the lobby wheels in src/assets were also edited
-- in place by audit/fix_spinwheel_streaming.luau (2026-09-19), and a full run makes them again
-- from scratch.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rb = require("@lune/roblox")

local GROUPS = { "SpinWheelGui", "AfkRewardsGui", "QuestGui", "ReviveCloseButton", "MobileSprint", "AbilityButtons", "SpinWheelLobby" }
for _, name in process.args do
	assert(table.find(GROUPS, name), "build_ui_prefabs: no group called " .. name .. " (" .. table.concat(GROUPS, ", ") .. ")")
end
local function wanted(name)
	return #process.args == 0 or table.find(process.args, name) ~= nil
end

local Layout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")
local Catalog = require("../src/common/ReplicatedStorage/Shared/SpinWheelCatalog")
local Extras = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SpinWheelExtras.luau"), {
	environment = setmetatable({
		Instance = rb.Instance,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
		UDim = rb.UDim,
		UDim2 = rb.UDim2,
		Vector2 = rb.Vector2,
		Enum = rb.Enum,
	}, { __index = _G }),
})()

-- The Spin Wheel's Robux packs, as Config.SpinWheel.Products lists them.
local function products()
	local config = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
	local block = assert(string.match(config, "Products = (%b{})"), "Config.SpinWheel.Products")
	local list = {}
	for entry in string.gmatch(string.sub(block, 2, -2), "%b{}") do
		local key = string.match(entry, 'Key = "([^"]+)"')
		if key then
			table.insert(list, {
				Key = key,
				Button = string.match(entry, 'Button = "([^"]+)"'),
				PriceRobux = tonumber(string.match(entry, "PriceRobux = (%d+)")),
				Caption = string.match(entry, 'Caption = "([^"]*)"'),
			})
		end
	end
	return list
end

local design = rb.deserializeModel(fs.readFile("design/ui/SpinWheelAndEarnings.rbxm"))[1]
fs.writeDir("src/ui")

local function finish(gui, name)
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Enabled = false
	for _, d in gui:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), name .. " carries no script")
	end
	return gui
end

if wanted("SpinWheelGui") then
	local gui = finish(design:FindFirstChild("SpinWheel"):Clone(), "SpinWheelGui")
	Extras.Decorate(gui, products(), Layout, Catalog)
	fs.writeFile("src/ui/SpinWheelGui.rbxm", rb.serializeModel({ gui }))
	print(("built SpinWheelGui -> src/ui/SpinWheelGui.rbxm (%d instances)"):format(#gui:GetDescendants() + 1))
end

if wanted("AfkRewardsGui") then
	local gui = finish(design:FindFirstChild("Earnings"):Clone(), "AfkRewardsGui")
	fs.writeFile("src/ui/AfkRewardsGui.rbxm", rb.serializeModel({ gui }))
	print(("built AfkRewardsGui -> src/ui/AfkRewardsGui.rbxm (%d instances)"):format(#gui:GetDescendants() + 1))
end

if wanted("QuestGui") then
	local QuestUi = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/QuestUi.luau"), {
		environment = setmetatable({
			Instance = rb.Instance,
			Color3 = rb.Color3,
			ColorSequence = rb.ColorSequence,
			ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
			Enum = rb.Enum,
		}, { __index = _G }),
	})()
	local quests = rb.deserializeModel(fs.readFile("design/ui/Quests.rbxm"))[1]
	-- Named QuestGui: MenuEvents, the topbar and the Main HUD know the panel by that name.
	local gui = finish(quests:Clone(), "QuestGui")
	QuestUi.Decorate(gui)
	fs.writeFile("src/ui/QuestGui.rbxm", rb.serializeModel({ gui }))
	print(("built QuestGui -> src/ui/QuestGui.rbxm (%d instances)"):format(#gui:GetDescendants() + 1))
end

-- Pieces added to authored HUDs (build_core's ASSETS puts each one in its place):
--   src/ui/ReviveCloseButton.rbxm      the Revive offer's close X
--                                      (StarterGui.RevivePromptHUD.ReviveOfferHolder)
--   src/ui/MobileSprintPressScale.rbxm the touch Sprint button's pressed state
--                                      (StarterGui.Mainhud.MobileSprint)
--   src/ui/SonicBurstButton.rbxm       the Sonic Burst's touch button, the designer's Sprint
--                                      button re-titled (StarterGui.Mainhud)
--   src/ui/SonicBurstCard.rbxm         the Sonic Burst's card in the Abilities panel, the
--                                      designer's Flight card re-dressed
--                                      (StarterGui.Abilities.Panel.ScrollingFrame)
--   src/ui/HeatVisionButton.rbxm       Superman's Heat Vision button, the designer's Sprint
--                                      button with eyes shooting beams (StarterGui.Mainhud)
local function piece(instance, file)
	for _, d in instance:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), instance.Name .. " carries no script")
	end
	fs.writeFile(file, rb.serializeModel({ instance }))
	print(("built %s -> %s (%d instances)"):format(instance.Name, file, #instance:GetDescendants() + 1))
end

if wanted("ReviveCloseButton") then
	local ReviveCloseButton = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/ReviveCloseButton.luau"), {
		environment = setmetatable({
			Instance = rb.Instance,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
			Enum = rb.Enum,
		}, { __index = _G }),
	})()
	piece(ReviveCloseButton.Build(), "src/ui/ReviveCloseButton.rbxm")
end

if wanted("MobileSprint") then
	local press = rb.Instance.new("UIScale")
	press.Name = "PressScale"
	press.Scale = 1
	piece(press, "src/ui/MobileSprintPressScale.rbxm")
end

if wanted("MobileSprint") then
	local label = rb.Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = rb.UDim2.fromScale(1, 1)
	label.Position = rb.UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = rb.Vector2.new(0.5, 0.5)
	label.Text = "Sprint"
	label.TextColor3 = rb.Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = rb.Color3.fromRGB(11, 27, 61)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.ZIndex = 5
	pcall(function()
		label.FontFace = rb.Font.fromEnum(rb.Enum.Font.FredokaOne)
	end)
	piece(label, "src/ui/MobileSprintLabel.rbxm")
end

if wanted("AbilityButtons") then
	local env = setmetatable({
		Instance = rb.Instance,
		Color3 = rb.Color3,
		Font = rb.Font,
		UDim = rb.UDim,
		UDim2 = rb.UDim2,
		Vector2 = rb.Vector2,
		Enum = rb.Enum,
	}, { __index = _G })
	local SonicBurstUi = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SonicBurstUi.luau"), { environment = env })()

	-- The designer's Sprint button and Flight card, from World 1's input place (World 2's
	-- and 3's are the same).
	local serde = require("@lune/serde")
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	local place = rb.deserializePlace(fs.readFile(manifest.worlds.World1.input))
	local sprint = place:GetService("StarterGui").Mainhud:FindFirstChild("MobileSprint")
	assert(sprint, "The Main HUD's Sprint button")
	piece(SonicBurstUi.DecorateButton(sprint:Clone()), "src/ui/SonicBurstButton.rbxm")
	local HeatVisionUi = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/HeatVisionUi.luau"), {
		environment = setmetatable({
			Instance = rb.Instance,
			Color3 = rb.Color3,
			ColorSequence = rb.ColorSequence,
			Font = rb.Font,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
			Enum = rb.Enum,
		}, { __index = _G }),
	})()
	piece(HeatVisionUi.DecorateButton(sprint:Clone()), "src/ui/HeatVisionButton.rbxm")
	local flight = place:GetService("StarterGui").Abilities.Panel.ScrollingFrame:FindFirstChild("Frame")
	assert(flight, "The Abilities panel's Flight card")
	piece(SonicBurstUi.DecorateCard(flight:Clone()), "src/ui/SonicBurstCard.rbxm")
end

-- 3D Spin Wheel Lobby models for World1, World2, and World3.
-- Placed in Workspace so designers can view and position them directly in Studio.
if wanted("SpinWheelLobby") then
	local WorldPlacement = {
		World1 = { Position = rb.Vector3.new(328.3, 37467.69, -1753.1), Face = rb.Vector3.new(280.3, 37467.69, -1781.1) },
		World2 = { Position = rb.Vector3.new(-828.8, 36626.65, -1003.8), Face = rb.Vector3.new(-783.8, 36626.65, -993.8) },
		World3 = { Position = rb.Vector3.new(345.0, 95.61, 390.0), Face = rb.Vector3.new(265.3, 95.61, 521.6) },
	}
	local savedGui = rb.deserializeModel(fs.readFile("src/ui/SpinWheelGui.rbxm"))[1]
	local wheelHolder = savedGui:FindFirstChild("Frame")
	local timerLabel = savedGui:FindFirstChild("Button"):FindFirstChild("TextLabel")
	local measure = Layout.Measure(wheelHolder)

	local function buildLobbyModel(placement)
		local RADIUS = 6
		local floorPosition = placement.Position
		local facing = if typeof(placement.Face) == "Vector3"
			then (placement.Face - floorPosition) * rb.Vector3.new(1, 0, 1)
			else rb.Vector3.new(0, 0, 1)
		if facing.Magnitude < 0.1 then
			facing = rb.Vector3.new(0, 0, 1)
		end
		facing = facing.Unit
		local centre = floorPosition + rb.Vector3.new(0, RADIUS * 1.3 + 1.2, 0)
		local wheelFrame = rb.CFrame.lookAt(centre, centre - facing)
		local flat = rb.CFrame.lookAt(floorPosition, floorPosition - facing)

		local model = rb.Instance.new("Model")
		model.Name = "SpinWheelLobby"
		-- The client binds this wheel once; keep the complete authored model available
		-- even when a player's character starts outside the lobby streaming radius.
		model.ModelStreamingMode = rb.Enum.ModelStreamingMode.Persistent

		local function part(name, className, size, cframe, color, collide)
			local instance = rb.Instance.new(className)
			instance.Name = name
			instance.Anchored = true
			instance.CanCollide = collide == true
			instance.CanQuery = collide == true
			instance.CanTouch = false
			instance.Material = rb.Enum.Material.SmoothPlastic
			instance.Size = size
			instance.CFrame = cframe
			instance.Color = color
			instance.Parent = model
			return instance
		end

		local NAVY = rb.Color3.fromRGB(38, 44, 74)
		local GOLD = rb.Color3.fromRGB(255, 186, 0)
		local function studs(target, faces)
			for _, face in faces do
				local texture = rb.Instance.new("Texture")
				texture.Texture = Layout.StudTexture
				texture.Face = face
				texture.StudsPerTileU = 2
				texture.StudsPerTileV = 2
				texture.Transparency = 0.7
				texture.Parent = target
			end
		end

		local postHeight = centre.Y - floorPosition.Y
		part("Trim", "Part", rb.Vector3.new(RADIUS * 2.5, 0.4, RADIUS * 1.25), flat * rb.CFrame.new(0, 0.2, -0.6), GOLD, true)
		local plinth = part("Plinth", "Part", rb.Vector3.new(RADIUS * 2.3, 1.4, RADIUS * 1.05), flat * rb.CFrame.new(0, 1.1, -0.6), NAVY, true)
		studs(plinth, { rb.Enum.NormalId.Top, rb.Enum.NormalId.Front, rb.Enum.NormalId.Back })
		for _, side in { -1, 1 } do
			local bottom = rb.Vector3.new(side * RADIUS * 0.95, 1.8, -1.1)
			local top = rb.Vector3.new(side * 0.8, postHeight, -1.1)
			local up = (top - bottom).Unit
			local leg = part(if side < 0 then "LeftLeg" else "RightLeg", "Part", rb.Vector3.new(1.1, (top - bottom).Magnitude + 1, 1.1),
				flat * rb.CFrame.fromMatrix((top + bottom) / 2, up:Cross(rb.Vector3.zAxis).Unit, up), GOLD, true)
			studs(leg, { rb.Enum.NormalId.Front, rb.Enum.NormalId.Back })
		end
		local axle = part("Axle", "Part", rb.Vector3.new(1.6, 2.2, 2.2), wheelFrame * rb.CFrame.new(0, 0, -1.1) * rb.CFrame.Angles(0, math.rad(90), 0), GOLD, false)
		axle.Shape = rb.Enum.PartType.Cylinder
		local outerRim = part("GoldRim", "Part", rb.Vector3.new(0.3, RADIUS * 2.32, RADIUS * 2.32), wheelFrame * rb.CFrame.new(0, 0, -0.55) * rb.CFrame.Angles(0, math.rad(90), 0), GOLD, false)
		outerRim.Shape = rb.Enum.PartType.Cylinder
		outerRim.Material = rb.Enum.Material.Neon
		local innerRim = part("NavyRim", "Part", rb.Vector3.new(0.35, RADIUS * 2.18, RADIUS * 2.18), wheelFrame * rb.CFrame.new(0, 0, -0.35) * rb.CFrame.Angles(0, math.rad(90), 0), NAVY, false)
		innerRim.Shape = rb.Enum.PartType.Cylinder
		local backing = part("Backing", "Part", rb.Vector3.new(0.5, RADIUS * 2.04, RADIUS * 2.04), wheelFrame * rb.CFrame.Angles(0, math.rad(90), 0), rb.Color3.fromRGB(245, 245, 250), false)
		backing.Shape = rb.Enum.PartType.Cylinder

		local ART_SHARE = 0.84
		local faceStuds = RADIUS * 2 / ART_SHARE
		local face = part("Face", "Part", rb.Vector3.new(faceStuds, faceStuds, 0.05), wheelFrame * rb.CFrame.new(0, 0, 0.3), rb.Color3.new(1, 1, 1), false)
		face.Transparency = 1
		local surface = rb.Instance.new("SurfaceGui")
		surface.Name = "Wheel"
		surface.Face = rb.Enum.NormalId.Back
		surface.SizingMode = rb.Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 45
		surface.LightInfluence = 0
		surface.MaxDistance = 220
		surface.ZIndexBehavior = rb.Enum.ZIndexBehavior.Sibling
		surface.Parent = face

		local holder = wheelHolder:Clone()
		for _, name in { "Close", "WinsSpin", "WinsCaption" } do
			local extra = holder:FindFirstChild(name)
			if extra then
				extra:Destroy()
			end
		end
		local holderHeight = ART_SHARE / (measure.ArtRadius * 2)
		holder.AnchorPoint = rb.Vector2.new(0, 0)
		holder.Size = rb.UDim2.fromScale(holderHeight * measure.Ratio, holderHeight)
		holder.Position = rb.UDim2.fromScale(0.5 - measure.WheelCenter.x * holderHeight, 0.5 - measure.WheelCenter.y * holderHeight)
		holder.Parent = surface

		local overhead = part("Overhead", "Part", rb.Vector3.new(1, 1, 1), rb.CFrame.new(centre + rb.Vector3.new(0, RADIUS * 1.6, 0)), rb.Color3.new(1, 1, 1), false)
		overhead.Transparency = 1
		local billboard = rb.Instance.new("BillboardGui")
		billboard.Name = "Billboard"
		billboard.Size = rb.UDim2.fromScale(14, 4.4)
		billboard.MaxDistance = 160
		billboard.LightInfluence = 0
		billboard.Parent = overhead
		local title = timerLabel:Clone()
		title.Name = "Title"
		title.AnchorPoint = rb.Vector2.new(0.5, 0)
		title.Position = rb.UDim2.fromScale(0.5, 0)
		title.Size = rb.UDim2.fromScale(1, 0.6)
		title.Text = "SPIN WHEEL"
		title.Parent = billboard
		local lobbyStatus = timerLabel:Clone()
		lobbyStatus.Name = "Status"
		lobbyStatus.AnchorPoint = rb.Vector2.new(0.5, 0)
		lobbyStatus.Position = rb.UDim2.fromScale(0.5, 0.62)
		lobbyStatus.Size = rb.UDim2.fromScale(1, 0.38)
		lobbyStatus.Text = ""
		lobbyStatus.Parent = billboard
		for _, label in { title, lobbyStatus } do
			local constraint = label:FindFirstChildOfClass("UIAspectRatioConstraint")
			if constraint then
				constraint:Destroy()
			end
		end

		local promptAnchor = part("PromptAnchor", "Part", rb.Vector3.new(1, 1, 1), flat * rb.CFrame.new(0, 3, RADIUS * 0.9), rb.Color3.new(1, 1, 1), false)
		promptAnchor.Transparency = 1
		local prompt = rb.Instance.new("ProximityPrompt")
		prompt.ActionText = "Spin"
		prompt.ObjectText = "Spin Wheel"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptAnchor

		model.PrimaryPart = plinth
		return model
	end

	fs.writeDir("src/assets")
	for worldName, placement in WorldPlacement do
		local model = buildLobbyModel(placement)
		piece(model, "src/assets/SpinWheelLobby_" .. worldName .. ".rbxm")
	end
end
