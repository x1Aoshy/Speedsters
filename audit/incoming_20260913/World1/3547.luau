local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))

local Builder = {}
local builtTemplates = nil

         
                                                                            
                                                                                  
                                                                     
                                                                              
                                                                              
                                                                    
                                                                          
                                                                            
                                    

local BLACK_ID_BY_TYPE = {
    Aura = "Aura04",
    Trail = "Trail04",
}

local COLOR_NAME_BY_ID = {
    Aura01 = "Purple",
    Aura02 = "Red",
    Aura03 = "White",
    Aura04 = "Black",
    Aura05 = "Orange",
    Aura06 = "Yellow",
    Aura07 = "Blue",
    Trail01 = "Purple",
    Trail02 = "Red",
    Trail03 = "White",
    Trail04 = "Black",
    Trail05 = "Orange",
    Trail06 = "Yellow",
    Trail07 = "Blue",
}

local ORIGINAL_AURA_OFFSET = CFrame.new(0, -0.5, 0)

local function isPreviewDummy(instance)
    return instance:IsA("Model")
        and instance:FindFirstChildOfClass("Humanoid") ~= nil
        and instance:FindFirstChild("HumanoidRootPart") ~= nil
end

local function getEffectCounts(instance)
    local trailCount = 0
    local emitterCount = 0

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("Trail") then
            trailCount = trailCount + 1
        elseif descendant:IsA("ParticleEmitter") then
            emitterCount = emitterCount + 1
        end
    end

    return trailCount, emitterCount
end

local function classifyContainer(container)
    local dummies = {}
    local trailParts = {}
    local auraParts = {}

    for _, child in ipairs(container:GetChildren()) do
        if isPreviewDummy(child) then
            table.insert(dummies, child)
        elseif child:IsA("BasePart") then
            local trailCount, emitterCount = getEffectCounts(child)
            if trailCount > 0 then
                table.insert(trailParts, child)
            elseif emitterCount > 0 then
                table.insert(auraParts, child)
            end
        end
    end

    return dummies, trailParts, auraParts
end

local function findCosmeticSourceContainer(rawPack)
    local candidates = { rawPack }

    for _, descendant in ipairs(rawPack:GetDescendants()) do
        if descendant:IsA("Model") or descendant:IsA("Folder") then
            table.insert(candidates, descendant)
        end
    end

    for _, candidate in ipairs(candidates) do
        local dummies, trailParts, auraParts = classifyContainer(candidate)
        if #dummies == 7 and #trailParts == 7 and #auraParts == 7 then
            return candidate, dummies, trailParts, auraParts
        end
    end

    error(
        "[CosmeticTemplateBuilder] Could not find the original cosmetic source container "
            .. "with exactly 7 dummies, 7 trail parts and 7 aura parts inside RawCosmeticPack."
    )
end

local function addColorSequence(sequence, accumulator)
    for _, keypoint in ipairs(sequence.Keypoints) do
        accumulator.R = accumulator.R + keypoint.Value.R
        accumulator.G = accumulator.G + keypoint.Value.G
        accumulator.B = accumulator.B + keypoint.Value.B
        accumulator.Count = accumulator.Count + 1
    end
end

local function representativeEffectColor(part, cosmeticType)
    local accumulator = { R = 0, G = 0, B = 0, Count = 0 }

    for _, descendant in ipairs(part:GetDescendants()) do
        if cosmeticType == "Aura" and descendant:IsA("ParticleEmitter") then
            addColorSequence(descendant.Color, accumulator)
        elseif cosmeticType == "Trail" and descendant:IsA("Trail") then
            addColorSequence(descendant.Color, accumulator)
        end
    end

    if accumulator.Count <= 0 then
        error(
            ("[CosmeticTemplateBuilder] %s source '%s' has no usable effect ColorSequence.")
                :format(cosmeticType, part:GetFullName())
        )
    end

    return Color3.new(
        accumulator.R / accumulator.Count,
        accumulator.G / accumulator.Count,
        accumulator.B / accumulator.Count
    )
end

local function colorDistanceSquared(a, b)
    local dr = a.R - b.R
    local dg = a.G - b.G
    local db = a.B - b.B
    return (dr * dr) + (dg * dg) + (db * db)
end

local function getNormalCatalogEntries(cosmeticType)
    local entries = Catalog.GetList(cosmeticType)
    if not entries then
        error("[CosmeticTemplateBuilder] Missing catalog list for " .. tostring(cosmeticType))
    end

    local blackId = BLACK_ID_BY_TYPE[cosmeticType]
    local normal = {}
    local blackEntry = nil

    for _, entry in ipairs(entries) do
        if entry.Id == blackId then
            blackEntry = entry
        else
            table.insert(normal, entry)
        end
    end

    if #normal ~= 6 or not blackEntry then
        error(
            ("[CosmeticTemplateBuilder] Expected 6 normal %s entries plus 1 Black/Secret entry.")
                :format(cosmeticType)
        )
    end

    return normal, blackEntry
end

                                                                                    
                                                                            
local function matchPartsByActualEffectColor(parts, cosmeticType)
    local sourceColors = {}
    for index, part in ipairs(parts) do
        sourceColors[index] = representativeEffectColor(part, cosmeticType)
    end

    local normalEntries, blackEntry = getNormalCatalogEntries(cosmeticType)
    local used = {}
    local current = {}
    local best = nil
    local bestCost = math.huge

    local function search(entryIndex, cost)
        if cost >= bestCost then
            return
        end

        if entryIndex > #normalEntries then
            bestCost = cost
            best = {}
            for index, sourceIndex in pairs(current) do
                best[index] = sourceIndex
            end
            return
        end

        local entry = normalEntries[entryIndex]
        for sourceIndex, sourceColor in ipairs(sourceColors) do
            if not used[sourceIndex] then
                used[sourceIndex] = true
                current[entryIndex] = sourceIndex
                search(
                    entryIndex + 1,
                    cost + colorDistanceSquared(sourceColor, entry.ThemeColor)
                )
                current[entryIndex] = nil
                used[sourceIndex] = nil
            end
        end
    end

    search(1, 0)

    if not best then
        error("[CosmeticTemplateBuilder] Could not solve " .. cosmeticType .. " visual color mapping.")
    end

    local byId = {}
    local assignedSource = {}

    for entryIndex, sourceIndex in pairs(best) do
        local entry = normalEntries[entryIndex]
        byId[entry.Id] = parts[sourceIndex]
        assignedSource[sourceIndex] = true
    end

    local leftoverIndex = nil
    for sourceIndex = 1, #parts do
        if not assignedSource[sourceIndex] then
            if leftoverIndex then
                error("[CosmeticTemplateBuilder] More than one Black/Secret source remained.")
            end
            leftoverIndex = sourceIndex
        end
    end

    if not leftoverIndex then
        error("[CosmeticTemplateBuilder] No source remained for Black/Secret " .. cosmeticType .. ".")
    end

    byId[blackEntry.Id] = parts[leftoverIndex]

    return byId, sourceColors
end

                                                                         
                                                                              
                                                          
local function pairAuraPartsToNearestDummies(auraParts, dummies)
    local used = {}
    local current = {}
    local best = nil
    local bestCost = math.huge

    local function search(partIndex, cost)
        if cost >= bestCost then
            return
        end

        if partIndex > #auraParts then
            bestCost = cost
            best = {}
            for index, dummyIndex in pairs(current) do
                best[index] = dummyIndex
            end
            return
        end

        local part = auraParts[partIndex]
        for dummyIndex, dummy in ipairs(dummies) do
            if not used[dummyIndex] then
                local root = dummy:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") then
                    local delta = root.Position - part.Position
                    local distanceCost = delta:Dot(delta)
                    used[dummyIndex] = true
                    current[partIndex] = dummyIndex
                    search(partIndex + 1, cost + distanceCost)
                    current[partIndex] = nil
                    used[dummyIndex] = nil
                end
            end
        end
    end

    search(1, 0)

    if not best then
        error("[CosmeticTemplateBuilder] Could not pair aura holders to preview dummies.")
    end

    local byPart = {}
    for partIndex, dummyIndex in pairs(best) do
        byPart[auraParts[partIndex]] = dummies[dummyIndex]
    end
    return byPart
end

local function sanitizeHolder(holder, cosmeticType)
    holder.Name = "EffectHolder"
    holder.Anchored = false
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.CastShadow = false
    holder.Massless = true
    holder.Transparency = 1

    for _, descendant in ipairs(holder:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.CastShadow = false
            descendant.Massless = true
            descendant.Transparency = 1
        elseif descendant:IsA("Trail") then
            descendant.Enabled = true
        elseif descendant:IsA("ParticleEmitter") then
            descendant.Enabled = true
            if cosmeticType == "Aura" then
                                                                                     
                descendant.LockedToPart = true
            end
        end
    end
end

local function addOffsetValue(template, offset)
    local value = Instance.new("CFrameValue")
    value.Name = "LocalOffset"
    value.Value = offset
    value.Parent = template
end

local function createTemplate(parent, cosmeticType, entry, sourceHolder, previewDummy, localOffset)
    local template = Instance.new("Model")
    template.Name = entry.Id
    template:SetAttribute("CosmeticType", cosmeticType)
    template:SetAttribute("CosmeticId", entry.Id)
    template:SetAttribute("TargetPart", "HumanoidRootPart")
    template:SetAttribute("SupportsR6", true)
    template:SetAttribute("SupportsR15", true)
    template:SetAttribute("SourcePreviewRig", "R6")
    template:SetAttribute("ColorName", COLOR_NAME_BY_ID[entry.Id] or entry.DisplayName)
    template:SetAttribute("SourceName", sourceHolder.Name)

    local root = previewDummy and previewDummy:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        template:SetAttribute("SourceColumnX", root.Position.X)
    end

    template.Parent = parent
    addOffsetValue(template, localOffset)

                                                                                
                                                                                          
    local holder = sourceHolder:Clone()
    sanitizeHolder(holder, cosmeticType)
    holder.CFrame = CFrame.new()
    holder.Parent = template
    template.PrimaryPart = holder

    return template
end

local function recreateTemplateRoot()
    local oldRoot = ServerStorage:FindFirstChild("CosmeticTemplates")
    if oldRoot then
        oldRoot:Destroy()
    end

    local root = Instance.new("Folder")
    root.Name = "CosmeticTemplates"
    root.Parent = ServerStorage

    local auras = Instance.new("Folder")
    auras.Name = "Auras"
    auras.Parent = root

    local trails = Instance.new("Folder")
    trails.Name = "Trails"
    trails.Parent = root

    return root, auras, trails
end

local function renameResolvedSources(auraById, trailById, auraDummyByPart)
    for _, entry in ipairs(Catalog.Auras) do
        local source = auraById[entry.Id]
        if source then
            local colorName = COLOR_NAME_BY_ID[entry.Id]
            source.Name = colorName .. "Aura"
            source:SetAttribute("AutoMappedCosmeticId", entry.Id)
            source:SetAttribute("AutoMappedBy", "V306EM_ActualVFXColor")

            local dummy = auraDummyByPart[source]
            if dummy then
                dummy.Name = colorName .. "Aura"
                dummy:SetAttribute("AutoMappedCosmeticId", entry.Id)
                dummy:SetAttribute("AutoMappedBy", "V306EM_NearestAuraHolder")
            end
        end
    end

    for _, entry in ipairs(Catalog.Trails) do
        local source = trailById[entry.Id]
        if source then
            local colorName = COLOR_NAME_BY_ID[entry.Id]
            source.Name = colorName .. "Trail"
            source:SetAttribute("AutoMappedCosmeticId", entry.Id)
            source:SetAttribute("AutoMappedBy", "V306EM_ActualVFXColor")
        end
    end
end

local function rgb255(color)
    return math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
end

local function printResolvedMapping(cosmeticType, byId)
    for _, entry in ipairs(Catalog.GetList(cosmeticType)) do
        local source = byId[entry.Id]
        if source then
            local color = representativeEffectColor(source, cosmeticType)
            local r, g, b = rgb255(color)
            print(
                ("[CosmeticTemplateBuilder] V306EM %s %s <- actual source RGB(%d,%d,%d)")
                    :format(entry.DisplayName, source:GetFullName(), r, g, b)
            )
        end
    end
end

function Builder.Build()
    if builtTemplates and builtTemplates.Parent then
        return builtTemplates
    end

    local rawPack = ServerStorage:WaitForChild("RawCosmeticPack", 30)
    if not rawPack then
        error(
            "[CosmeticTemplateBuilder] RawCosmeticPack is missing from ServerStorage. "
                .. "Keep the manually imported original pack in ServerStorage."
        )
    end

    local sourceContainer, dummies, trailParts, auraParts = findCosmeticSourceContainer(rawPack)

    local auraById = matchPartsByActualEffectColor(auraParts, "Aura")
    local trailById = matchPartsByActualEffectColor(trailParts, "Trail")
    local auraDummyByPart = pairAuraPartsToNearestDummies(auraParts, dummies)

                                                                                      
    renameResolvedSources(auraById, trailById, auraDummyByPart)

    local root, auraFolder, trailFolder = recreateTemplateRoot()

    for _, entry in ipairs(Catalog.Auras) do
        local auraHolder = auraById[entry.Id]
        local auraDummy = auraHolder and auraDummyByPart[auraHolder]
        if not auraHolder or not auraDummy then
            error("[CosmeticTemplateBuilder] Missing resolved source for " .. entry.DisplayName)
        end

                                                                                 
                                                                                      
                                                                                    
        createTemplate(auraFolder, "Aura", entry, auraHolder, auraDummy, ORIGINAL_AURA_OFFSET)
    end

    for _, entry in ipairs(Catalog.Trails) do
        local trailHolder = trailById[entry.Id]
        if not trailHolder then
            error("[CosmeticTemplateBuilder] Missing resolved source for " .. entry.DisplayName)
        end

        local colorName = COLOR_NAME_BY_ID[entry.Id]
        local matchingDummy = nil
        for auraPart, dummy in pairs(auraDummyByPart) do
            if auraPart.Name == colorName .. "Aura" then
                matchingDummy = dummy
                break
            end
        end

        createTemplate(trailFolder, "Trail", entry, trailHolder, matchingDummy, CFrame.new())
    end

    root:SetAttribute("AuraCount", #auraFolder:GetChildren())
    root:SetAttribute("TrailCount", #trailFolder:GetChildren())
    root:SetAttribute("ShopSystemInstalled", true)
    root:SetAttribute("AuraShopInstalled", true)
    root:SetAttribute("TrailShopInstalled", true)
    root:SetAttribute("SourcePackName", rawPack.Name)
    root:SetAttribute("SourceContainerName", sourceContainer.Name)
    root:SetAttribute("BindingMode", "ActualVFXColor_NotNamesOrOrder")
    root:SetAttribute("AuraOffsetMode", "FixedOriginalMinus0.5HRP")
    root:SetAttribute("BuilderVersion", "V306EM")

    rawPack:SetAttribute("CosmeticAutoMapVersion", "V306EM")
    rawPack:SetAttribute("CosmeticAutoMapMode", "ActualVFXColor")

    printResolvedMapping("Aura", auraById)
    printResolvedMapping("Trail", trailById)
    print(
        "[CosmeticTemplateBuilder] V306EM built 7 original auras + 7 original trails "
            .. "from actual VFX colors; aura holders are fixed to the player HRP."
    )

    builtTemplates = root
    return root
end

return Builder
