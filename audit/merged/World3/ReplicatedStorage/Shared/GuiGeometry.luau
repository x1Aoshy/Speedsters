--!strict
-- GuiGeometry.luau
-- Where a GuiObject really draws inside a rotated tree, worked out from its authored
-- Size, Position, AnchorPoint, Rotation and UIAspectRatioConstraint alone.
--
-- Roblox reports AbsolutePosition without the rotation of the ancestors, so a label
-- inside a turned slice of a wheel cannot be located from it. The designer's spin
-- wheel places each prize by hand inside rotated frames; this finds the angle each
-- prize actually sits at, so the wheel can stop with that prize under the arrow.
--
-- Pure arithmetic on the authored properties (no Vector2, no Enum globals), so the
-- offline tests run it on the designer's .rbxm exactly as the client runs it.

local GuiGeometry = {}

export type Point = { x: number, y: number }

local function constrainedSize(node: any, parentWidth: number, parentHeight: number): (number, number)
	local size = node.Size
	local width = size.X.Scale * parentWidth + size.X.Offset
	local height = size.Y.Scale * parentHeight + size.Y.Offset
	local constraint = node:FindFirstChildOfClass("UIAspectRatioConstraint")
	if constraint and constraint.AspectRatio > 0 then
		local ratio = constraint.AspectRatio
		if constraint.AspectType.Name == "ScaleWithParentSize" then
			width, height = parentWidth, parentHeight
		end
		-- FitWithinMaxSize: the largest rectangle of that ratio inside the size.
		local fitted = math.min(width, height * ratio)
		width, height = fitted, fitted / ratio
	end
	return width, height
end

local function rotateAround(point: Point, center: Point, degrees: number): Point
	if degrees == 0 then
		return point
	end
	-- Screen space has y pointing down, so a positive Rotation turns clockwise.
	local radians = math.rad(degrees)
	local cos, sin = math.cos(radians), math.sin(radians)
	local dx, dy = point.x - center.x, point.y - center.y
	return { x = center.x + dx * cos - dy * sin, y = center.y + dx * sin + dy * cos }
end

-- The chain of GuiObjects from just below `root` down to `node`, outermost first.
local function chainBelow(root: Instance, node: Instance): { any }
	local chain = {}
	local current: Instance? = node
	while current and current ~= root do
		table.insert(chain, 1, current)
		current = current.Parent
	end
	assert(current == root, "GuiGeometry: node is not inside root")
	return chain
end

-- Centre of `node` in the unrotated frame of `root`, measured with `root` sized
-- `rootWidth` x `rootHeight` (only ratios matter when everything is scale-based).
-- Rotations of every frame between them are applied; root's own rotation is not.
function GuiGeometry.CenterIn(root: Instance, node: Instance, rootWidth: number, rootHeight: number): Point
	local chain = chainBelow(root, node)
	local parentLeft, parentTop = 0, 0
	local parentWidth, parentHeight = rootWidth, rootHeight
	local centers: { Point } = {}
	local rotations: { number } = {}
	for index, object in chain do
		local width, height = constrainedSize(object, parentWidth, parentHeight)
		local position = object.Position
		local anchor = object.AnchorPoint
		local left = parentLeft + position.X.Scale * parentWidth + position.X.Offset - anchor.X * width
		local top = parentTop + position.Y.Scale * parentHeight + position.Y.Offset - anchor.Y * height
		centers[index] = { x = left + width / 2, y = top + height / 2 }
		rotations[index] = object.Rotation
		parentLeft, parentTop, parentWidth, parentHeight = left, top, width, height
	end
	-- The node's own centre, carried out through each enclosing frame's turn.
	local point = centers[#chain]
	for index = #chain - 1, 1, -1 do
		point = rotateAround(point, centers[index], rotations[index])
	end
	return point
end

-- Size of `node` (after aspect constraints, before any rotation) with `root` sized
-- `rootWidth` x `rootHeight`.
function GuiGeometry.SizeIn(root: Instance, node: Instance, rootWidth: number, rootHeight: number): (number, number)
	local width, height = rootWidth, rootHeight
	for _, object in chainBelow(root, node) do
		width, height = constrainedSize(object, width, height)
	end
	return width, height
end

-- The smallest box, in `root`'s own unrotated frame, holding `root` and every visible
-- GuiObject inside it with all their rotations, for `root` sized rootWidth x rootHeight.
-- A price tag tilted past a button's edge counts. Returns minX, minY, maxX, maxY.
function GuiGeometry.BoundsIn(root: Instance, rootWidth: number, rootHeight: number): (number, number, number, number)
	local minX, minY, maxX, maxY = 0, 0, rootWidth, rootHeight
	local function visit(node: Instance, left: number, top: number, width: number, height: number, transforms: { any })
		for _, child in node:GetChildren() do
			local object = child :: any
			if child:IsA("GuiObject") and object.Visible then
				local w, h = constrainedSize(object, width, height)
				local l = left + object.Position.X.Scale * width + object.Position.X.Offset - object.AnchorPoint.X * w
				local t = top + object.Position.Y.Scale * height + object.Position.Y.Offset - object.AnchorPoint.Y * h
				local chain = { { center = { x = l + w / 2, y = t + h / 2 }, angle = object.Rotation } }
				for _, transform in transforms do
					table.insert(chain, transform)
				end
				for _, corner in { { x = l, y = t }, { x = l + w, y = t }, { x = l + w, y = t + h }, { x = l, y = t + h } } do
					local point: Point = corner
					for _, transform in chain do
						point = rotateAround(point, transform.center, transform.angle)
					end
					minX, minY = math.min(minX, point.x), math.min(minY, point.y)
					maxX, maxY = math.max(maxX, point.x), math.max(maxY, point.y)
				end
				visit(child, l, t, w, h, chain)
			end
		end
	end
	visit(root, 0, 0, rootWidth, rootHeight, {})
	return minX, minY, maxX, maxY
end

-- Whether a GuiObject puts something on screen by itself: a text, an image or a background.
-- A frame that only holds other objects draws nothing of its own.
local function draws(object: any): boolean
	if object.BackgroundTransparency < 1 then
		return true
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		return object.Text ~= ""
	end
	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
		local ok, image = pcall(function()
			return object.Image
		end)
		return not ok or image ~= ""
	end
	return false
end

-- The smallest box, in `root`'s unrotated frame with `root` sized rootWidth x rootHeight,
-- around what `node` and the visible GuiObjects inside it actually draw, with every
-- rotation between them applied. `node` counts even while hidden, so a layout measured
-- from it does not move when it shows. Returns minX, minY, maxX, maxY, or nil when
-- nothing inside draws.
function GuiGeometry.DrawnExtentIn(root: Instance, node: Instance, rootWidth: number, rootHeight: number): (number?, number?, number?, number?)
	local width, height = GuiGeometry.SizeIn(root, node, rootWidth, rootHeight)
	local centre = GuiGeometry.CenterIn(root, node, rootWidth, rootHeight)
	-- Turns about different centres add up to one turn by their sum, and the node's own
	-- centre lands on CenterIn, so every point inside maps by that one turn.
	local angle = 0
	for _, object in chainBelow(root, node) do
		angle += (object :: any).Rotation
	end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local function add(point: Point)
		local placed = rotateAround({ x = centre.x + point.x - width / 2, y = centre.y + point.y - height / 2 }, centre, angle)
		minX, minY = math.min(minX, placed.x), math.min(minY, placed.y)
		maxX, maxY = math.max(maxX, placed.x), math.max(maxY, placed.y)
	end
	if draws(node) then
		for _, corner in { { x = 0, y = 0 }, { x = width, y = 0 }, { x = width, y = height }, { x = 0, y = height } } do
			add(corner)
		end
	end
	local function visit(parent: Instance, left: number, top: number, w: number, h: number, transforms: { any })
		for _, child in parent:GetChildren() do
			local object = child :: any
			if child:IsA("GuiObject") and object.Visible then
				local cw, ch = constrainedSize(object, w, h)
				local l = left + object.Position.X.Scale * w + object.Position.X.Offset - object.AnchorPoint.X * cw
				local t = top + object.Position.Y.Scale * h + object.Position.Y.Offset - object.AnchorPoint.Y * ch
				local chain = { { center = { x = l + cw / 2, y = t + ch / 2 }, angle = object.Rotation } }
				for _, transform in transforms do
					table.insert(chain, transform)
				end
				if draws(object) then
					for _, corner in { { x = l, y = t }, { x = l + cw, y = t }, { x = l + cw, y = t + ch }, { x = l, y = t + ch } } do
						local point: Point = corner
						for _, transform in chain do
							point = rotateAround(point, transform.center, transform.angle)
						end
						add(point)
					end
				end
				visit(child, l, t, cw, ch, chain)
			end
		end
	end
	visit(node, 0, 0, width, height, {})
	if minX == math.huge then
		return nil, nil, nil, nil
	end
	return minX, minY, maxX, maxY
end

-- Clockwise angle in degrees (0 = straight up) of `point` around `center`.
function GuiGeometry.AngleAround(center: Point, point: Point): number
	local degrees = math.deg(math.atan2(point.x - center.x, -(point.y - center.y)))
	return degrees % 360
end

-- Smallest signed difference a - b in degrees, in (-180, 180].
function GuiGeometry.DeltaDegrees(a: number, b: number): number
	local delta = (a - b) % 360
	if delta > 180 then
		delta -= 360
	end
	return delta
end

return GuiGeometry
