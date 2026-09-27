local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")

local places = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local catalogSource = fs.readFile("src/common/ReplicatedStorage/Shared/QuestCatalog.luau")
local questUiSource = fs.readFile("src/common/ReplicatedStorage/Shared/QuestUi.luau")

-- Verify Luau compilation first
print("Compiling QuestCatalog.luau...")
local cOk, cErr = pcall(function() return luau.compile(catalogSource) end)
assert(cOk and not string.find(tostring(cErr), "SyntaxError"), "QuestCatalog compilation failed: " .. tostring(cErr))

print("Compiling QuestUi.luau...")
local uOk, uErr = pcall(function() return luau.compile(questUiSource) end)
assert(uOk and not string.find(tostring(uErr), "SyntaxError"), "QuestUi compilation failed: " .. tostring(uErr))

local backupDir = "output/Backup_QuestUiFix_" .. os.date("%Y%m%d_%H%M%S")
fs.writeDir(backupDir)

for world, filename in places do
	print(string.format("=== Updating %s (%s) ===", world, filename))
	local raw = fs.readFile(filename)
	fs.writeFile(backupDir .. "/" .. filename, raw)
	
	local dm = rb.deserializePlace(raw)
	
	-- 1. Update ReplicatedStorage.Shared.QuestCatalog
	local rep = dm:FindFirstChild("ReplicatedStorage")
	assert(rep, "Missing ReplicatedStorage")
	local shared = rep:FindFirstChild("Shared")
	assert(shared, "Missing Shared")
	
	local catalogModule = shared:FindFirstChild("QuestCatalog")
	assert(catalogModule and catalogModule:IsA("ModuleScript"), "Missing QuestCatalog ModuleScript")
	catalogModule.Source = catalogSource
	print("  Updated ReplicatedStorage.Shared.QuestCatalog")
	
	-- 2. Update ReplicatedStorage.Shared.QuestUi
	local questUiModule = shared:FindFirstChild("QuestUi")
	assert(questUiModule and questUiModule:IsA("ModuleScript"), "Missing QuestUi ModuleScript")
	questUiModule.Source = questUiSource
	print("  Updated ReplicatedStorage.Shared.QuestUi")

	-- 2b. Update ReplicatedStorage.Shared.DesignerUi.QuestGui
	local designerUi = shared:FindFirstChild("DesignerUi")
	if designerUi then
		local questGuiSpec = designerUi:FindFirstChild("QuestGui")
		if questGuiSpec and questGuiSpec:IsA("ModuleScript") then
			local designerSource = fs.readFile("src/common/ReplicatedStorage/Shared/DesignerUi/QuestGui.luau")
			questGuiSpec.Source = designerSource
			print("  Updated ReplicatedStorage.Shared.DesignerUi.QuestGui")
		end
	end
	
	-- 3. Update StarterGui pre-existing QuestGui instances
	local sg = dm:FindFirstChild("StarterGui")
	if sg then
		local questGui = sg:FindFirstChild("QuestGui") or sg:FindFirstChild("Quests")
		if questGui then
			local frame = questGui:FindFirstChild("Frame")
			if frame then
				local patchedCount = 0
				for _, card in frame:GetChildren() do
					if string.match(card.Name, "^Quest") or string.match(card.Name, "^Quests") then
						local rewardTemplate = card:FindFirstChild("RewardTemplate")
						if rewardTemplate then
							for _, item in rewardTemplate:GetChildren() do
								if item:IsA("ImageLabel") then
									local qty = item:FindFirstChild("Quantity") or item:FindFirstChildOfClass("TextLabel")
									if qty then
										qty.Name = "Quantity"
										qty.AnchorPoint = rb.Vector2.new(1, 1)
										qty.Position = rb.UDim2.new(1, 0, 1, 0)
										qty.Size = rb.UDim2.new(1.15, 0, 0.42, 0)
										qty.TextXAlignment = rb.Enum.TextXAlignment.Right
										qty.TextYAlignment = rb.Enum.TextYAlignment.Bottom
										qty.TextWrapped = false
										qty.LineHeight = 1
										qty.TextScaled = true
										
										local aspect = qty:FindFirstChildOfClass("UIAspectRatioConstraint")
										if aspect then
											aspect:Destroy()
										end
										
										local cap = qty:FindFirstChild("QuantityTextSize")
										if not cap then
											cap = rb.Instance.new("UITextSizeConstraint")
											cap.Name = "QuantityTextSize"
											cap.Parent = qty
										end
										cap.MinTextSize = 8
										cap.MaxTextSize = 14
										
										for _, st in qty:GetChildren() do
											if st:IsA("UIStroke") then
												st.StrokeSizingMode = rb.Enum.StrokeSizingMode.FixedSize
												st.Thickness = 1.5
											end
										end
										patchedCount += 1
									end
								end
							end
						end
					end
				end
				print(string.format("  Patched %d Quantity badges in StarterGui.%s", patchedCount, questGui.Name))
			end
		end
	end
	
	-- Save updated place
	local updatedPlace = rb.serializePlace(dm)
	fs.writeFile(filename, updatedPlace)
	print(string.format("  Successfully saved %s (size: %d bytes)", filename, #updatedPlace))
end

print("\nAll 3 places updated successfully!")
