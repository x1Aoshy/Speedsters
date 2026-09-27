-- SonicBurstUi.luau
-- The Sonic Burst's two pieces of UI, both saved as real instances in every place
-- (audit/build_ui_prefabs.luau, build_core's ASSETS) so they can be seen and edited in
-- Studio; the client makes them the same way only in a place without them:
--
--   * StarterGui.Mainhud.SonicBurstButton: phones and tablets only (a keyboard charges it
--     with Shift, a gamepad with its sprint trigger). The designer's Sprint button, copied
--     as it is (colour, outlines, font) and titled "Burst", round like the Sprint button on
--     phones. Held: it sprints and charges; let go: it bursts. Hidden until equipped.
--   * StarterGui.Abilities.Panel.ScrollingFrame.SonicBurstCard: the designer's Flight card,
--     re-titled and re-coloured for the Sonic Burst, a Wins price and no Robux button.
local SonicBurstUi = {}

SonicBurstUi.ButtonName = "SonicBurstButton"
SonicBurstUi.ButtonText = "Burst"
SonicBurstUi.CardName = "SonicBurstCard"
SonicBurstUi.Cyan = Color3.fromRGB(120, 225, 255)
SonicBurstUi.CardColor = Color3.fromRGB(40, 170, 255)

-- Round, like the Sprint button on phones: every corner (UICorner keeps one radius per
-- corner as well as CornerRadius).
function SonicBurstUi.Round(button)
	local corner = button:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = button
	end
	local round = UDim.new(0.5, 0)
	pcall(function()
		corner.CornerRadius = round
	end)
	for _, name in { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" } do
		pcall(function()
			corner[name] = round
		end)
	end
	return corner
end

-- The designer's Sprint button (Mainhud.MobileSprint, a clone) made into the Burst button.
function SonicBurstUi.DecorateButton(button)
	button.Name = SonicBurstUi.ButtonName
	button.Text = SonicBurstUi.ButtonText
	button.Visible = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(42, 42)
	pcall(function()
		button.TextStrokeColor3 = Color3.fromRGB(11, 27, 61)
		button.TextStrokeTransparency = 0
	end)
	SonicBurstUi.Round(button)
	local strokes = {}
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then
			table.insert(strokes, child)
		end
	end
	if #strokes >= 1 then
		strokes[1].Color = Color3.fromRGB(11, 27, 61)
		strokes[1].Thickness = 2.5
		strokes[1].Transparency = 0
	end
	if #strokes >= 2 then
		strokes[2].Color = Color3.fromRGB(255, 255, 255)
		strokes[2].Thickness = 1.2
		strokes[2].Transparency = 0.15
	end
	-- Shrinks while held (SonicBurstClient).
	if not button:FindFirstChild("PressScale") then
		local press = Instance.new("UIScale")
		press.Name = "PressScale"
		press.Scale = 1
		press.Parent = button
	end

	-- Dedicated child TextLabel so the text is crisp, centered, and visible
	local label = button:FindFirstChild("Label")
	if not label or not label:IsA("TextLabel") then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Parent = button
	end
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Text = SonicBurstUi.ButtonText
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(11, 27, 61)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.ZIndex = 5
	pcall(function()
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	end)

	return button
end

-- The designer's Flight card (a clone) made into the Sonic Burst's.
function SonicBurstUi.DecorateCard(card)
	card.Name = SonicBurstUi.CardName
	card.LayoutOrder = 2
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			local text = string.lower(child.Text)
			if text == "fly" then
				child.Text = "Sonic Burst"
			elseif string.find(text, "glide", 1, true) or string.find(text, "fly", 1, true) then
				child.Text = "Hold Shift to charge the run, let go to burst forward."
				child:SetAttribute("SonicBurstDescription", true)
			elseif string.find(text, "stamina", 1, true) then
				child.Text = "9s cooldown"
			end
		elseif child:IsA("ImageLabel") then
			child.BackgroundColor3 = SonicBurstUi.CardColor
		end
	end
	local inner = card:FindFirstChild("Frame")
	if inner then
		local robux = inner:FindFirstChild("RobuxPurchase")
		if robux then
			robux.Visible = true
			local robuxName = robux:FindFirstChild("Name")
			if robuxName and robuxName:IsA("TextLabel") then
				robuxName.Text = "499"
			end
		end
		local wins = inner:FindFirstChild("WinsPurchase")
		if wins and wins:IsA("GuiObject") then
			wins.Position = UDim2.new(1.1641335, 0, 0.25030318, 0)
		end
		for _, child in inner:GetChildren() do
			if child:IsA("ImageLabel") then
				child.ImageColor3 = SonicBurstUi.Cyan
			end
		end
	end
	return card
end

return SonicBurstUi
