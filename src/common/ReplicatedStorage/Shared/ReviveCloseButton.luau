-- ReviveCloseButton.luau
-- The close "X" on the Revive offer: the game's round close art (the one every panel uses)
-- on the top-right corner of the Revive button. The art is 44 px and the touch area around
-- it 60 px (hit padding), both in the offer's own units (its UIScale is 0.92, so about 40
-- and 55 screen pixels).
--
-- The build saves it into every place's StarterGui.RevivePromptHUD.ReviveOfferHolder
-- (audit/build_ui_prefabs.luau, build_core's ASSETS), so it is a real instance that can be
-- seen and edited in Studio. RevivePrompt.client uses the saved one, and builds one the
-- same way only in a place without it.

local ReviveCloseButton = {}

ReviveCloseButton.Name = "CloseButton"
ReviveCloseButton.Image = "rbxassetid://110882579806743"
ReviveCloseButton.HitSize = 60
ReviveCloseButton.ArtSize = 44
-- The Revive button is 370 x 94 at a UIScale of 0.7 (259 x 66): the X sits on its corner.
ReviveCloseButton.Position = { 251, 4 }
ReviveCloseButton.ZIndex = 8

function ReviveCloseButton.Build()
	local button = Instance.new("ImageButton")
	button.Name = ReviveCloseButton.Name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(ReviveCloseButton.Position[1], ReviveCloseButton.Position[2])
	button.Size = UDim2.fromOffset(ReviveCloseButton.HitSize, ReviveCloseButton.HitSize)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = ""
	button.AutoButtonColor = false
	button.Selectable = true
	button.ZIndex = ReviveCloseButton.ZIndex

	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromOffset(ReviveCloseButton.ArtSize, ReviveCloseButton.ArtSize)
	art.BackgroundTransparency = 1
	art.Image = ReviveCloseButton.Image
	art.ScaleType = Enum.ScaleType.Fit
	art.ZIndex = ReviveCloseButton.ZIndex + 1
	art.Parent = button

	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = 1
	shape.Parent = art

	-- Shrinks while pressed (RevivePrompt.client).
	local press = Instance.new("UIScale")
	press.Name = "PressScale"
	press.Scale = 1
	press.Parent = art

	return button
end

return ReviveCloseButton
