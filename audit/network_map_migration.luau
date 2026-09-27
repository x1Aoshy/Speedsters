local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local luau = require('@lune/luau')
local Migration = {}

local function address(instance)
	local segments = {}
	while instance.Parent do
		local ordinal = 0
		for _,sibling in instance.Parent:GetChildren() do
			if sibling.Name == instance.Name and sibling.ClassName == instance.ClassName then ordinal += 1 end
			if sibling == instance then break end
		end
		table.insert(segments, 1, {name = instance.Name, class = instance.ClassName, ordinal = ordinal})
		instance = instance.Parent
	end
	return segments
end

local function resolve(game, segments)
	local current = game
	for _,segment in segments do
		local ordinal, nextNode = 0, nil
		for _,child in current:GetChildren() do
			if child.Name == segment.name and child.ClassName == segment.class then
				ordinal += 1
				if ordinal == segment.ordinal then nextNode = child; break end
			end
		end
		assert(nextNode, 'Migration undo lost instance '..segment.name)
		current = nextNode
	end
	return current
end

function Migration.Apply(game)
	local changes, undo, inserted = {}, {}, {}
	local function marker(parent, class, name, value)
		assert(not parent:FindFirstChild(name), 'Duplicate ASMR marker')
		local instance = roblox.Instance.new(class)
		instance.Name, instance.Value, instance.Parent = name, value, parent
		table.insert(inserted, {path = instance:GetFullName(), address = address(instance)})
	end
	local function set(instance, property, value, attribute)
		local old = attribute and instance:GetAttribute(property) or nil
		if not attribute then old = instance[property] end
		if old == value then return end
		local entry = {address = address(instance), path = instance:GetFullName(), property = property, attribute = attribute == true, old = old, new = value}
		table.insert(undo, entry)
		table.insert(changes, entry)
		if attribute then instance:SetAttribute(property, value) else instance[property] = value end
	end
	local counts = {Bubble = 0, Keyboard = 0, Butter = 0}
	for _,kit in game:GetService('Workspace'):GetChildren() do
		if kit.Name ~= 'ASMR kit -  by Agus_Fellini2' then continue end
		for _,source in kit:GetDescendants() do
			if not source:IsA('Script') then continue end
			local parent = source.Parent
			local kind, template
			if parent.Name == 'Bubble' and parent:IsA('Model') then
				kind, template = 'Bubble', source:FindFirstChild('Bubble')
			elseif parent.Name == 'Keyboard' and parent:IsA('Model') then
				kind, template = 'Keyboard', source:FindFirstChild('Key')
			elseif parent.Name == 'Butter' and parent:IsA('BasePart') then kind = 'Butter' end
			assert(kind, 'Unexpected ASMR script; review before migration: '..source:GetFullName())
			if kind ~= 'Butter' then
				assert(template and template:IsA('BasePart'), 'Missing effect template')
				local origin = parent:FindFirstChild(kind)
				assert(origin and origin:IsA('BasePart') and not origin.CanCollide and not template.CanCollide, 'Unexpected solid grid: cannot move gameplay physics to client')
				marker(template, 'NumberValue', 'AsmrTemplateTransparency', template.Transparency)
				set(template, 'Anchored', true)
				set(template, 'CanCollide', false)
				set(template, 'CanTouch', false)
				set(template, 'CanQuery', false)
				set(template, 'Transparency', 1)
			else assert(parent.Anchored, 'Butter must retain anchored authoritative collision') end
			set(source, 'Disabled', true)
			marker(source, 'StringValue', 'AsmrEffectKind', kind)
			counts[kind] += 1
		end
	end
	local total = counts.Bubble + counts.Keyboard + counts.Butter
	if total > 0 then
		assert(counts.Bubble == 9 and counts.Keyboard == 10 and counts.Butter == 6, 'Unexpected ASMR inventory; review snapshot')
		local scripts = game:GetService('StarterPlayer'):FindFirstChild('StarterPlayerScripts')
		assert(scripts and not scripts:FindFirstChild('AsmrEffectsClient'), 'Missing container or duplicate ASMR migration')
		local controller = roblox.Instance.new('LocalScript')
		controller.Name = 'AsmrEffectsClient'
		controller.Source = fs.readFile('audit/AsmrEffectsClient.luau')
		luau.compile(controller.Source)
		controller.Parent = scripts
		table.insert(inserted, {path = controller:GetFullName(), address = address(controller)})
	end
	return {
		changes = changes, inserted = inserted, counts = counts,
		Undo = function(target)
			for _,entry in inserted do resolve(target, entry.address):Destroy() end
			for index = #undo, 1, -1 do
				local entry = undo[index]
				local instance = resolve(target, entry.address)
				if entry.attribute then instance:SetAttribute(entry.property, entry.old) else instance[entry.property] = entry.old end
			end
		end,
	}
end

return Migration
