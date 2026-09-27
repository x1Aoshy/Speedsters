--!strict
-- DesignerUiBuilder.luau
-- Builds a UI designer's layout from its generated data module (Shared.DesignerUi.*,
-- written by scratch/import_designer_ui.luau). Sizes, positions and styling come from
-- the designer's file untouched; controllers only fill in text, images and visibility.

local DesignerUiBuilder = {}

export type Spec = {
	ClassName: string,
	Name: string,
	Properties: { [string]: any },
	Attributes: { [string]: any }?,
	Tags: { string }?,
	Children: { Spec }?,
}

function DesignerUiBuilder.Build(spec: Spec): Instance
	local instance = Instance.new(spec.ClassName)
	instance.Name = spec.Name
	for property, value in spec.Properties do
		local ok, err = pcall(function()
			(instance :: any)[property] = value
		end)
		if not ok then
			warn("[DesignerUiBuilder] " .. spec.ClassName .. "." .. property .. ": " .. tostring(err))
		end
	end
	for name, value in spec.Attributes or {} do
		instance:SetAttribute(name, value)
	end
	for _, tag in spec.Tags or {} do
		instance:AddTag(tag)
	end
	for _, childSpec in spec.Children or {} do
		DesignerUiBuilder.Build(childSpec).Parent = instance
	end
	return instance
end

return DesignerUiBuilder
