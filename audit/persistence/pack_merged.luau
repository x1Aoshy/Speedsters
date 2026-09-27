local fs = require("@lune/fs")
local r = require("@lune/roblox")
local luau = require("@lune/luau")

print("=== PACKAGING MERGED SOURCES INTO RBXL PLACES ===")

local places = {
    World1 = "World1 Speedtercorrect.rbxl",
    World2 = "world2 speedtster.rbxl",
}

for label, filename in pairs(places) do
    print(string.format("\n--- Processing %s (%s) ---", label, filename))
    
    -- Create backup
    local backupName = "audit/" .. label .. "_PrePackBackup.rbxl"
    local raw = fs.readFile(filename)
    fs.writeFile(backupName, raw)
    print("Created backup:", backupName)

    local place = r.deserializePlace(raw)
    local rootDir = "audit/merged/" .. label
    local updatedCount = 0
    local totalScripts = 0

    -- Ensure AdminPanelService exists
    local sss = place:GetService("ServerScriptService")
    local adminFolder = sss:FindFirstChild("Admin")
    if not adminFolder then
        adminFolder = r.Instance.new("Folder")
        adminFolder.Name = "Admin"
        adminFolder.Parent = sss
    end
    local aps = adminFolder:FindFirstChild("AdminPanelService")
    if not aps then
        aps = r.Instance.new("Script")
        aps.Name = "AdminPanelService"
        aps.Parent = adminFolder
        print("Ensured Script: ServerScriptService.Admin.AdminPanelService")
    end

    -- Ensure RewardPadClaims exists in ServerScriptService.Services
    local servicesFolder = sss:FindFirstChild("Services")
    if not servicesFolder then
        servicesFolder = r.Instance.new("Folder")
        servicesFolder.Name = "Services"
        servicesFolder.Parent = sss
    end
    local rpc = servicesFolder:FindFirstChild("RewardPadClaims")
    if not rpc then
        rpc = r.Instance.new("ModuleScript")
        rpc.Name = "RewardPadClaims"
        rpc.Parent = servicesFolder
        print("Ensured ModuleScript: ServerScriptService.Services.RewardPadClaims")
    end

    -- Ensure AdminPanelController exists
    local sp = place:GetService("StarterPlayer")
    local sps = sp:FindFirstChild("StarterPlayerScripts")
    if not sps then
        sps = r.Instance.new("StarterPlayerScripts")
        sps.Name = "StarterPlayerScripts"
        sps.Parent = sp
    end
    local uiFolder = sps:FindFirstChild("UI")
    if not uiFolder then
        uiFolder = r.Instance.new("Folder")
        uiFolder.Name = "UI"
        uiFolder.Parent = sps
    end
    local apc = uiFolder:FindFirstChild("AdminPanelController")
    if not apc then
        apc = r.Instance.new("LocalScript")
        apc.Name = "AdminPanelController"
        apc.Parent = uiFolder
        print("Ensured LocalScript: StarterPlayer.StarterPlayerScripts.UI.AdminPanelController")
    end

    -- Ensure RemoteEvents in ReplicatedStorage.Remotes
    local rep = place:GetService("ReplicatedStorage")
    local remotesFolder = rep:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = r.Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = rep
    end
    for _, remoteName in ipairs({
        "AdminPanelAction",
        "AdminPanelStatus",
        "WinPadFeedback",
        "SpeedGainPopup",
        "BoostState",
        "LevelProgressUpdate",
        "TemporaryBoostUpdate",
        "TeleportAction",
        "TeleportUpdate",
        "UpdateLogClosed",
    }) do
        local rem = remotesFolder:FindFirstChild(remoteName)
        if not rem then
            rem = r.Instance.new("RemoteEvent")
            rem.Name = remoteName
            rem.Parent = remotesFolder
            print("Ensured RemoteEvent: ReplicatedStorage.Remotes." .. remoteName)
        end
    end

    for _, inst in ipairs(place:GetDescendants()) do
        if inst:IsA("LuaSourceContainer") then
            totalScripts += 1
            local relPath = inst:GetFullName():gsub("%.", "/"):gsub('[<>:"|?*]', "_") .. ".luau"
            local diskPath = rootDir .. "/" .. relPath
            
            if fs.isFile(diskPath) then
                local diskSource = fs.readFile(diskPath)
                -- Verify Luau compilation
                local compileOk, compileErr = pcall(luau.compile, diskSource)
                assert(compileOk, string.format("Compilation failed for %s:\n%s", diskPath, tostring(compileErr)))

                if inst.Source ~= diskSource then
                    inst.Source = diskSource
                    updatedCount += 1
                end
            end
        end
    end

    print(string.format("Checked %d scripts in %s. Updated: %d scripts.", totalScripts, label, updatedCount))

    -- Save back to file
    local serialized = r.serializePlace(place)
    fs.writeFile(filename, serialized)
    print("Saved updated place to:", filename)

    -- Verification roundtrip
    local reopened = r.deserializePlace(fs.readFile(filename))
    local verifiedCount = 0
    for _, inst in ipairs(reopened:GetDescendants()) do
        if inst:IsA("LuaSourceContainer") then
            local relPath = inst:GetFullName():gsub("%.", "/"):gsub('[<>:"|?*]', "_") .. ".luau"
            local diskPath = rootDir .. "/" .. relPath
            if fs.isFile(diskPath) then
                local diskSource = fs.readFile(diskPath)
                assert(inst.Source == diskSource, "Mismatch in source after save for " .. inst:GetFullName())
                verifiedCount += 1
            end
        end
    end
    print(string.format("VERIFIED %s: %d scripts match disk exactly after round-trip!", label, verifiedCount))
end

print("\n=== PACKAGING COMPLETE FOR BOTH PLACES ===")
