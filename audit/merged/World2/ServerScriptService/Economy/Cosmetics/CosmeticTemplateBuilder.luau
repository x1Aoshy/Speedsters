local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

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
-- In the authored pack the trail exhibits float behind AND above their preview rig
-- so the showroom reads cleanly: 26.8 studs back and 2 studs up. Both are staging,
-- not design. The ribbon is placed this far behind the player's back, and centred
-- on the body so it runs head to feet like a speed streak instead of towering over
-- the character's head.
local TRAIL_BACK_DISTANCE = 0.55

-- Vertical extent of a rig's visible body, relative to its HumanoidRootPart.
local function bodyExtentY(previewDummy, root)
    local low, high = math.huge, -math.huge
    for _, part in ipairs(previewDummy:GetChildren()) do
        if part:IsA("BasePart") and part ~= root then
            local centre = root.CFrame:ToObjectSpace(part.CFrame).Position.Y
            local half = part.Size.Y * 0.5
            low = math.min(low, centre - half)
            high = math.max(high, centre + half)
        end
    end
    if low > high then
        return nil
    end
    return low, high
end

-- Vertical extent the trail ribbon actually draws, relative to the holder origin.
local function ribbonExtentY(holder)
    local low, high = math.huge, -math.huge
    for _, attachment in ipairs(holder:GetChildren()) do
        if attachment:IsA("Attachment") then
            local base = attachment.CFrame.Position.Y
            for _, tip in ipairs(attachment:GetChildren()) do
                if tip:IsA("Attachment") and (tip.Name == "t0" or tip.Name == "t1") then
                    local y = base + tip.CFrame.Position.Y
                    low = math.min(low, y)
                    high = math.max(high, y)
                end
            end
        end
    end
    if low > high then
        return nil
    end
    return low, high
end
local ORIGINAL_AURA_IDS = {
    Aura01 = true,
    Aura02 = true,
    Aura03 = true,
    Aura04 = true,
    Aura05 = true,
    Aura06 = true,
    Aura07 = true,
}

-- The seven trails in RawCosmeticPack, matched to the catalog by colour. Every other
-- trail is a ribbon the builder draws from its catalog entry (buildRibbonTrail).
local ORIGINAL_TRAIL_IDS = {
    Trail01 = true,
    Trail02 = true,
    Trail03 = true,
    Trail04 = true,
    Trail05 = true,
    Trail06 = true,
    Trail07 = true,
}

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
        if (cosmeticType == "Trail" and ORIGINAL_TRAIL_IDS[entry.Id]) or (cosmeticType == "Aura" and ORIGINAL_AURA_IDS[entry.Id]) then
            if entry.Id == blackId then
                blackEntry = entry
            else
                table.insert(normal, entry)
            end
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

                                                                         
                                                                              
                                                          
local function pairPartsToNearestDummies(auraParts, dummies)
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
                    -- CFrame.Position rather than BasePart.Position: identical result,
                    -- and it lets the offline geometry test drive this module.
                    local delta = root.CFrame.Position - part.CFrame.Position
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
        error("[CosmeticTemplateBuilder] Could not pair cosmetic holders to preview dummies.")
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

    -- Physics and visibility only: authored geometry is never rescaled here.
    -- Forcing the trail's t0/t1 attachments to +/-0.75 studs (and squashing its
    -- a1..a5 offsets) collapsed a 6-8 stud ribbon into a 1.5 stud sliver, which
    -- is why equipped trails looked tiny next to their shop preview.
    for _, descendant in ipairs(holder:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.CastShadow = false
            descendant.Massless = true
            descendant.Transparency = 1
        elseif descendant:IsA("Trail") or descendant:IsA("ParticleEmitter") then
            descendant.Enabled = true
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
    local targetPartName = cosmeticType == "Trail" and "UpperTorso" or "HumanoidRootPart"
    template:SetAttribute("TargetPart", targetPartName)
    template:SetAttribute("SupportsR6", true)
    template:SetAttribute("SupportsR15", true)
    template:SetAttribute("SourcePreviewRig", "R6")
    template:SetAttribute("ColorName", COLOR_NAME_BY_ID[entry.Id] or entry.DisplayName)
    template:SetAttribute("SourceName", sourceHolder.Name)

    local root = previewDummy and (previewDummy:FindFirstChild("HumanoidRootPart") or previewDummy:FindFirstChild("Torso"))
    if root and root:IsA("BasePart") then
        template:SetAttribute("SourceColumnX", root.CFrame.Position.X)
    end

    local finalOffset = localOffset
    if previewDummy and root and root:IsA("BasePart") and sourceHolder:IsA("BasePart") then
        local computed = root.CFrame:ToObjectSpace(sourceHolder.CFrame)
        if cosmeticType == "Trail" then
            -- Drop the showroom staging entirely and centre the authored ribbon on
            -- the body, so it runs head to feet. Measured from the pack rather than
            -- hard-coded, so it stays right if the artist re-exports.
            local bodyLow, bodyHigh = bodyExtentY(previewDummy, root)
            local ribbonLow, ribbonHigh = ribbonExtentY(sourceHolder)
            local height = 0
            if bodyLow and ribbonLow then
                height = ((bodyLow + bodyHigh) * 0.5) - ((ribbonLow + ribbonHigh) * 0.5)
            end
            finalOffset = CFrame.new(0, height, TRAIL_BACK_DISTANCE) * (computed - computed.Position)
        else
            finalOffset = computed
        end
    end

    -- The offset is measured against the preview rig's HumanoidRootPart, which
    -- exists on both R6 and R15; CosmeticService converts it to whichever part it
    -- welds to, so no rig needs a hand-tuned height correction.
    template:SetAttribute("OffsetSpace", "HumanoidRootPart")
    template.Parent = parent
    addOffsetValue(template, finalOffset)

                                                                                
                                                                                          
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

-- Authored auras (ServerStorage.AuthoredAuras). Each is either a bare part carrying its
-- emitters (Aura 67) or a folder holding an R6 preview rig that wears the effects on its
-- limbs, sometimes with a floor effect (FloorVFX) or a companion (ShidouBall) beside it.
local AUTHORED_ALIASES = {
    -- The originals in AURAS/ (audit/capture_aura_sources.luau): Water, Galaxy, Cursed.
    Aura08 = { "AquaticOpenSource", "Aquatic", "Aura08" },
    Aura09 = { "GalacticOpenSource", "GlacticOpenSource", "Galactic", "Aura09" },
    Aura10 = { "Cursed Energy Green", "Aura10" },
    Aura11 = { "Cursed Energy Red", "Aura11" },
    Aura12 = { "Cursed Energy Purple", "Aura12" },
    Aura13 = { "Cursed Energy Normal", "Cursed Energy Blue", "Aura13" },
    Aura14 = { "Shidou", "Shidou Effects", "Aura14" },
    Aura16 = { "DemonAura", "Demon Aura", "Aura16" },
    Aura17 = { "LightningAura", "Lightning Aura", "Lightning Aura V2", "Aura17" },
    Aura18 = { "Musical", "musciall", "Musical Aura", "Aura18" },
    Aura67 = { "67", "Aura67" },
}
-- R6 limbs, and the R15 part each one stands for.
local AUTHORED_LIMBS = {
    Torso = "UpperTorso",
    Head = "Head",
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
    HumanoidRootPart = "HumanoidRootPart",
}
-- Pieces that do not ride a limb: every client places them (AuraSpecialEffectsClient).
local AUTHORED_EXTRAS = {
    FloorVFX = { Tag = "DynamicFloorVFX", Flag = "HasFloorVFX" },
    ShidouBall = { Tag = "DynamicShidouBall", Flag = "HasShidouBall" },
}
-- Orbs that circle the wearer (Galaxy's Orbit1 and Orbit2; the showcase rig spun them
-- with an animation): every client turns them round the wearer's root.
local ORBIT_SPEED = 1.4 -- radians a second

-- Makes a part ride a character without moving it: no collisions, no mass, no touches.
local function quietPart(part, anchored)
    part.Anchored = anchored
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
end

local function isAuthoredEffect(instance)
    return instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail")
        or instance:IsA("Light") or instance:IsA("Fire") or instance:IsA("Sparkles") or instance:IsA("Smoke")
end

local function hasAuthoredEffect(instance)
    for _, descendant in ipairs(instance:GetDescendants()) do
        if isAuthoredEffect(descendant) then
            return true
        end
    end
    return false
end

local function findPreviewRig(container)
    if container:IsA("Model") and container:FindFirstChildOfClass("Humanoid") then
        return container
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            local rig = findPreviewRig(child)
            if rig then
                return rig
            end
        end
    end
    return nil
end

local function newEffectHolder(name, size)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.CastShadow = false
    part.Transparency = 1
    part.Size = size
    part.CFrame = CFrame.new()
    return part
end

-- NewAurasFactory's templates carry extra parts (a beam's far end, a ring) whose
-- WeldConstraints were exported without their parts, so on a character those parts
-- would just drop away. Weld each one to the holder, exactly where it was drawn.
local function weldLooseParts(template)
    local holder = template:FindFirstChild("EffectHolder")
    if not holder or not holder:IsA("BasePart") then
        return 0
    end
    for _, joint in ipairs(template:GetDescendants()) do
        if joint:IsA("WeldConstraint") and (joint.Part0 == nil or joint.Part1 == nil) then
            joint:Destroy()
        end
    end
    local welded = 0
    for _, part in ipairs(template:GetDescendants()) do
        if part:IsA("BasePart") and part ~= holder and part:GetAttribute("HolderPart") ~= true
            and not part.Anchored and not part:FindFirstChild("HolderWeld")
        then
            local weld = Instance.new("Weld")
            weld.Name = "HolderWeld"
            weld.Part0 = holder
            weld.Part1 = part
            weld.C0 = holder.CFrame:ToObjectSpace(part.CFrame)
            weld.Parent = part
            welded += 1
        end
    end
    return welded
end

-- One template from one authored source, keeping the source's own structure. Everything
-- is MOVED out of a single clone, never cloned piece by piece: a beam's attachments are
-- often siblings (or on another limb), and a piecewise clone would leave the beam pointing
-- at the original. Tags and attributes (Forge VFX: Bezier, ConstantVFX, EmitCount...) come
-- along with their instances.
--   A part source (the Cursed energies, 67) IS the holder: the clone of the part itself,
--   with every attachment, emitter, trail and nested part it carries, the nested parts
--   welded where they were drawn.
--   A folder with a showcase rig (Galaxy, Water, Demon, Lightning, Musical, Shidou) gives
--   one holder per limb with that limb's effects; its other effect parts (Galaxy's
--   AuraPart, Water's aura Part) ride the root at the offset they had from the rig's root;
--   orbs (Orbit1, Orbit2) circle the wearer; FloorVFX and ShidouBall are placed by clients.
local function buildAuthoredAura(auraId, source)
    local template = Instance.new("Model")
    template.Name = auraId
    template:SetAttribute("CosmeticType", "Aura")
    template:SetAttribute("CosmeticId", auraId)
    template:SetAttribute("TargetPart", "HumanoidRootPart")
    template:SetAttribute("SupportsR6", true)
    template:SetAttribute("SupportsR15", true)
    template:SetAttribute("AuthoredSource", source:GetFullName())

    local offset = Instance.new("CFrameValue")
    offset.Name = "LocalOffset"
    offset.Value = CFrame.new(0, -0.5, 0)
    offset.Parent = template

    local copy = source:Clone()
    -- Joints that tie it to things outside it (another model's parts) mean nothing on a
    -- character.
    local function dropForeignJoints(root)
        for _, joint in ipairs(root:GetDescendants()) do
            if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
                local part0, part1 = joint.Part0, joint.Part1
                if not part0 or not part1 or not part0:IsDescendantOf(root) and part0 ~= root or not part1:IsDescendantOf(root) and part1 ~= root then
                    joint:Destroy()
                end
            end
        end
    end
    if copy:IsA("BasePart") then
        dropForeignJoints(copy)
        -- Nested parts keep their place relative to the holder, which sits at the origin.
        local origin = copy.CFrame
        for _, part in ipairs(copy:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CFrame = origin:ToObjectSpace(part.CFrame)
                quietPart(part, false)
            end
        end
        copy.Name = "EffectHolder"
        copy.CFrame = CFrame.new()
        quietPart(copy, false)
        copy.Transparency = 1
        copy.Parent = template
        copy = nil
    else
        local holder = newEffectHolder("EffectHolder", Vector3.new(2, 2, 1))
        holder.Parent = template
        local rig = findPreviewRig(copy)
        local rigRoot = rig and rig:FindFirstChild("HumanoidRootPart")
        local rootFrame = if rigRoot and rigRoot:IsA("BasePart") then rigRoot.CFrame else nil
        if rig then
            local reached = {}
            for _, descendant in ipairs(rig:GetDescendants()) do
                if descendant:IsA("Beam") or descendant:IsA("Trail") then
                    if descendant.Attachment0 then
                        reached[descendant.Attachment0] = true
                    end
                    if descendant.Attachment1 then
                        reached[descendant.Attachment1] = true
                    end
                end
            end
            for _, limb in ipairs(rig:GetChildren()) do
                local r15Name = limb:IsA("BasePart") and AUTHORED_LIMBS[limb.Name]
                if r15Name then
                    local limbHolder = nil
                    for _, child in ipairs(limb:GetChildren()) do
                        -- Effects and the attachments they use; never the rig's own
                        -- joints, clothing handles or plain rig attachments.
                        local keep = isAuthoredEffect(child)
                            or (child:IsA("Attachment") and (reached[child] == true or hasAuthoredEffect(child)))
                        if keep then
                            if not limbHolder then
                                limbHolder = newEffectHolder(string.gsub(limb.Name, " ", "") .. "Holder", limb.Size)
                                limbHolder:SetAttribute("TargetLimb", limb.Name)
                                limbHolder:SetAttribute("TargetLimbR15", r15Name)
                                limbHolder:SetAttribute("HolderPart", true)
                                limbHolder.Parent = template
                            end
                            child.Parent = limbHolder
                        end
                    end
                end
            end
        end
        -- The rest of the source's effect parts: floor effects and companions for the
        -- clients, orbs, and parts that ride the root.
        for _, part in ipairs(copy:GetDescendants()) do
            if part.Parent and (part:IsA("BasePart") or part:IsA("Model")) and not (rig and part.Parent == rig and AUTHORED_LIMBS[part.Name]) then
                local extra = AUTHORED_EXTRAS[part.Name]
                if extra then
                    part.Parent = template
                    part:SetAttribute(extra.Tag, true)
                    template:SetAttribute(extra.Flag, true)
                    -- Anchored: each client moves it next to its wearer every frame. An
                    -- unanchored, unwelded part would just fall on the server.
                    local parts = part:GetDescendants()
                    table.insert(parts, part)
                    for _, piece in ipairs(parts) do
                        if piece:IsA("BasePart") then
                            quietPart(piece, true)
                        end
                    end
                elseif part:IsA("BasePart") and hasAuthoredEffect(part) and not part:FindFirstAncestorWhichIsA("Accessory") then
                    local relative = if rootFrame then rootFrame:ToObjectSpace(part.CFrame) else CFrame.new()
                    dropForeignJoints(part)
                    for _, joint in ipairs(part:GetChildren()) do
                        if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
                            joint:Destroy()
                        end
                    end
                    part.Parent = template
                    part.CFrame = relative
                    part.Transparency = 1
                    if string.match(part.Name, "^Orbit%d") then
                        -- Circles the wearer at this radius and height, starting here.
                        quietPart(part, true)
                        part:SetAttribute("DynamicOrbit", true)
                        part:SetAttribute("OrbitRadius", Vector3.new(relative.X, 0, relative.Z).Magnitude)
                        part:SetAttribute("OrbitHeight", relative.Y)
                        part:SetAttribute("OrbitPhase", math.atan2(relative.Z, relative.X))
                        part:SetAttribute("OrbitSpeed", ORBIT_SPEED)
                        template:SetAttribute("HasOrbit", true)
                    else
                        -- Rides the root, where it sat on the showcase rig.
                        quietPart(part, false)
                        part:SetAttribute("TargetLimb", "HumanoidRootPart")
                        part:SetAttribute("TargetLimbR15", "HumanoidRootPart")
                        part:SetAttribute("HolderPart", true)
                        part:SetAttribute("LimbOffset", relative)
                    end
                end
            end
        end
    end
    if copy then
        copy:Destroy()
    end

    local limbHolders = 0
    for _, child in ipairs(template:GetChildren()) do
        if child:GetAttribute("TargetLimb") then
            limbHolders += 1
        end
    end
    if limbHolders > 0 then
        template:SetAttribute("HasLimbHolders", true)
        template:SetAttribute("LimbHolderCount", limbHolders)
    end
    if not template:FindFirstChildWhichIsA("ParticleEmitter", true) then
        template:Destroy()
        return nil
    end
    return template
end

-- A ribbon trail: a main band from the head to the feet and a thinner, quicker one
-- beside it, like the originals' layers, with an optional burst of particles.
local RIBBON_LAYERS = {
    { Name = "Main", Offset = Vector3.new(0, 0, 0), Half = 3, Lifetime = 0.55, Taper = 0.85, Fade = { 0.2, 0, 0, 1 } },
    { Name = "Accent", Offset = Vector3.new(0.35, 0, 0.3), Half = 2.6, Lifetime = 0.35, Taper = 0.6, Fade = { 0.5, 0.35, 0.45, 1 } },
}

local function colorSequenceOf(colors)
    if type(colors) ~= "table" or #colors == 0 then
        return ColorSequence.new(Color3.new(1, 1, 1))
    end
    if #colors == 1 then
        return ColorSequence.new(colors[1])
    end
    local points = {}
    for index, color in ipairs(colors) do
        table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
    end
    return ColorSequence.new(points)
end

local function buildRibbonTrail(entry)
    local ribbon = entry.Ribbon
    local template = Instance.new("Model")
    template.Name = entry.Id
    template:SetAttribute("CosmeticType", "Trail")
    template:SetAttribute("CosmeticId", entry.Id)
    template:SetAttribute("TargetPart", "UpperTorso")
    template:SetAttribute("SupportsR6", true)
    template:SetAttribute("SupportsR15", true)
    template:SetAttribute("ColorName", entry.DisplayName)
    template:SetAttribute("SourceName", "Ribbon")
    template:SetAttribute("OffsetSpace", "HumanoidRootPart")

    -- Centred on an R6 body (feet at -3, head top at +2 from the root) and just behind it.
    local offset = Instance.new("CFrameValue")
    offset.Name = "LocalOffset"
    offset.Value = CFrame.new(0, -0.5, TRAIL_BACK_DISTANCE)
    offset.Parent = template

    local holder = newEffectHolder("EffectHolder", Vector3.new(2, 4, 1))
    holder.Parent = template
    template.PrimaryPart = holder

    for _, layer in ipairs(RIBBON_LAYERS) do
        local top = Instance.new("Attachment")
        top.Name = layer.Name .. "Top"
        top.CFrame = CFrame.new(layer.Offset + Vector3.new(0, layer.Half, 0))
        top.Parent = holder
        local bottom = Instance.new("Attachment")
        bottom.Name = layer.Name .. "Bottom"
        bottom.CFrame = CFrame.new(layer.Offset - Vector3.new(0, layer.Half, 0))
        bottom.Parent = holder

        local trail = Instance.new("Trail")
        trail.Name = layer.Name
        trail.Attachment0 = top
        trail.Attachment1 = bottom
        trail.Texture = ribbon.Texture
        trail.TextureMode = Enum.TextureMode[ribbon.Mode or "Static"]
        trail.TextureLength = ribbon.Length or 20
        trail.Lifetime = layer.Lifetime
        trail.MinLength = 0.1
        trail.FaceCamera = true
        trail.LightEmission = ribbon.Emission or 1
        trail.LightInfluence = ribbon.Influence or 0
        trail.Brightness = ribbon.Brightness or 3
        trail.Color = colorSequenceOf(ribbon.Colors)
        trail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, layer.Taper),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, layer.Fade[1]),
            NumberSequenceKeypoint.new(0.17, layer.Fade[2]),
            NumberSequenceKeypoint.new(0.72, layer.Fade[3]),
            NumberSequenceKeypoint.new(1, layer.Fade[4]),
        })
        trail.Enabled = true
        trail.Parent = holder
    end

    if type(entry.Numbers) == "table" then
        local spout = Instance.new("Attachment")
        spout.Name = "Numbers"
        spout.CFrame = CFrame.new(0, 0.5, 0.4)
        spout.Parent = holder
        local tint = colorSequenceOf(ribbon.Colors)
        for _, number in ipairs(entry.Numbers) do
            -- Left behind in the world as the runner goes (not locked to the part).
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = number.Name
            emitter.Texture = number.Texture
            emitter.Rate = 4
            emitter.Lifetime = NumberRange.new(0.8, 1.2)
            emitter.Speed = NumberRange.new(1, 2.5)
            emitter.SpreadAngle = Vector2.new(35, 35)
            emitter.EmissionDirection = Enum.NormalId.Top
            emitter.Acceleration = Vector3.new(0, 1.5, 0)
            emitter.Drag = 1
            emitter.Rotation = NumberRange.new(-20, 20)
            emitter.RotSpeed = NumberRange.new(-40, 40)
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.15, 1.1),
                NumberSequenceKeypoint.new(0.8, 0.9),
                NumberSequenceKeypoint.new(1, 0),
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.7, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            })
            emitter.Color = tint
            emitter.LightEmission = 0.35
            emitter.LockedToPart = false
            emitter.Enabled = true
            emitter.Parent = spout
        end
    end
    return template
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
    local auraDummyByPart = pairPartsToNearestDummies(auraParts, dummies)
    local trailDummyByPart = pairPartsToNearestDummies(trailParts, dummies)

                                                                                      
    renameResolvedSources(auraById, trailById, auraDummyByPart)

    local root, auraFolder, trailFolder = recreateTemplateRoot()

    for _, entry in ipairs(Catalog.Auras) do
        if ORIGINAL_AURA_IDS[entry.Id] then
            local auraHolder = auraById[entry.Id]
            local auraDummy = auraHolder and auraDummyByPart[auraHolder]
            if not auraHolder or not auraDummy then
                error("[CosmeticTemplateBuilder] Missing resolved source for " .. entry.DisplayName)
            end

            createTemplate(auraFolder, "Aura", entry, auraHolder, auraDummy, ORIGINAL_AURA_OFFSET)
        end
    end

    -- World 3's auras: NewAurasFactory draws Aura08-Aura15 in code; the authored models
    -- then replace (Shidou) or add (Demon, Lightning, Musical, 67) their own.
    local okFactory, NewAurasFactory = pcall(function()
        return require(script.Parent:WaitForChild("NewAurasFactory"))
    end)
    if okFactory and NewAurasFactory and type(NewAurasFactory.Build) == "function" then
        NewAurasFactory.Build(auraFolder)
    else
        warn("[CosmeticTemplateBuilder] NewAurasFactory is unavailable: " .. tostring(NewAurasFactory))
    end
    local authoredFolder = ServerStorage:FindFirstChild("AuthoredAuras") or ServerStorage:FindFirstChild("NewAuras")
    if authoredFolder then
        for auraId, aliases in pairs(AUTHORED_ALIASES) do
            local found = nil
            for _, alias in ipairs(aliases) do
                found = authoredFolder:FindFirstChild(alias) or authoredFolder:FindFirstChild(alias, true)
                if found then
                    break
                end
            end
            if found and Catalog.IsValid("Aura", auraId) then
                local ok, template = pcall(buildAuthoredAura, auraId, found)
                if ok and template then
                    local old = auraFolder:FindFirstChild(auraId)
                    if old then
                        old:Destroy()
                    end
                    template.Parent = auraFolder
                else
                    warn(("[CosmeticTemplateBuilder] Could not build %s from %s: %s"):format(auraId, found:GetFullName(), tostring(template)))
                end
            end
        end
    end
    for _, template in ipairs(auraFolder:GetChildren()) do
        weldLooseParts(template)
        CollectionService:AddTag(template, "LoadVFXTextures")
    end

    local TRAIL_BACK_OFFSET = CFrame.new(0, 0, TRAIL_BACK_DISTANCE)
    for _, entry in ipairs(Catalog.Trails) do
        if ORIGINAL_TRAIL_IDS[entry.Id] then
            local trailHolder = trailById[entry.Id]
            if not trailHolder then
                error("[CosmeticTemplateBuilder] Missing resolved source for " .. entry.DisplayName)
            end

            createTemplate(trailFolder, "Trail", entry, trailHolder, trailDummyByPart[trailHolder], TRAIL_BACK_OFFSET)
        elseif type(entry.Ribbon) == "table" then
            local ok, template = pcall(buildRibbonTrail, entry)
            if ok and template then
                template.Parent = trailFolder
                CollectionService:AddTag(template, "LoadVFXTextures")
            else
                warn("[CosmeticTemplateBuilder] Could not build " .. entry.Id .. ": " .. tostring(template))
            end
        end
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
