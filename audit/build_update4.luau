-- audit/build_update4.luau  (Update 4, integrator, 2026-09-25; output/Update4/PLAN.md §5.J)
-- Puts Update 4 into the three root places: the 09-24 retention P0 files, the P0 remainder
-- (p0_data, p0_gameplay) and the Update 4 features (race, titles, retention, community, pass),
-- plus the authored assets they need:
--   (1) the designer ScreenGuis of design/ui/uineww.rbxm (Folder NewUI: Titles, Playtime Boost,
--       Streak Rewards, Community rewards) into StarterGui, Enabled=false, ResetOnSpawn=false,
--       DisplayOrder=20, ZIndexBehavior=Sibling (the controllers open them);
--   (2) the MeshPart `Mesh` of design/vfx/BubbleModule.rbxm under ReplicatedStorage.BubbleModule
--       (the ModuleScript itself is src/common/ReplicatedStorage/BubbleModule.luau);
--   (3) Workspace.RaceArena and Workspace.RaceGate (Services/Race/RaceArenaBuilder);
--   (4) 2026-09-26: the old "FASTEST RACERS" Race_* board parts (audit/u4_race_board) are taken
--       out (the holo board beside The Flash replaced them); only our stamped ones;
--   (5) the Plain/Gold/Owner title templates in ReplicatedStorage.Titles (audit/u4_title_templates);
--   (6) the hidden "2X Stamina" Shop card (audit/u4_shop_card);
--   (7) optional, 2026-09-25: design/race/RaceAssets.rbxm (the race art the owner imports once
--       in Studio, design/race/IMPORTAR_EN_STUDIO.md) as ServerStorage.RaceAssets, before (3),
--       so RaceArenaBuilder builds the arena and gate from those meshes. No file: skipped with a
--       note, and (3) keeps the part geometry (or uses a RaceAssets already in the place).
--   (8) 2026-09-26 (owner): ReplicatedStorage.SuperSonicEventAssets (audit/u4_supersonic_assets): the
--       Super Sonic vs Eggman event's VFX (assets/vfx_imported/) and the Blender kit's Meshes.
-- Every authored asset carries a `U4Asset` stamp: a stamped one is replaced, one of the same name
-- without the stamp was made by someone else and stops the build.
--
-- Sources are not written by hand: every file of src/ that differs from
-- output/FableRetentionP0_20260924/backup_src/ (what the places carry today: the 09-22 build),
-- plus every new file. Each changed source is guarded by its backup copy, so a place edited in
-- Studio meanwhile stops the build instead of being lost.
--
--   lune run audit/build_update4.luau list [p0]     print what it would put in (nothing is read
--                                                   from or written to the places)
--   lune run audit/build_update4.luau check [p0]    everything but the writes (Lib dryRun)
--   lune run audit/build_update4.luau p0            only the P0 files (no Update 4 feature, no asset)
--   lune run audit/build_update4.luau               everything
-- `--allow-locks` builds even when a place has a .rbxl.lock (Studio may have it open).
-- `--greenhill` (2026-09-26, with the full build, `check` or `list`): Workspace.RaceArena becomes
-- the Green Hill map (audit/u4_greenhill_arena: Astra's design/race/Astra_Recta/RaceArena.rbxm
-- without its local-only meshes, with barriers, banks, fences and an online look; the owner's
-- design/race/greenhill/GreenHillKit.rbxm + layout.json when present), stamped U4Asset
-- "RaceArenaGreenHill". It replaces our stamped arenas (RaceArena, RaceArenaGreenHill) and
-- refuses any other; RaceGate is kept (built only when missing). The kit is cloned into the
-- arena, so nothing else goes into ServerStorage/ReplicatedStorage. The water around it is the
-- server's (Gameplay/RaceArenaWater), not the place's.
-- `--rebuild-gate` (2026-09-26, with the full build or `check`): rebuilds Workspace.RaceGate when it
-- is ours (U4Asset "RaceGate") even at the current version, and nothing else of the race map.
-- Without it a gate of ours older than RaceArenaBuilder.GateVersion (attribute RaceGateVersion;
-- none = 1, the 09-25 part frame) is rebuilt anyway: The Flash's arch; a RaceGate without our
-- stamp (the owner's) is never touched.
-- Outputs and backups: output/Update4/build_p0 and output/Update4/build_full.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Lib = require("./fable_build_lib")

local BACKUP = "output/FableRetentionP0_20260924/backup_src/"
-- src as it was before Update 4 began: the 18 files that differ between the two backups are the
-- 09-24 retention P0 files the places do not carry yet.
local PRE_U4 = "output/Update4/backup_src_pre_u4/"
local DESIGN_UI = "design/ui/uineww.rbxm"
local DESIGN_BUBBLE = "design/vfx/BubbleModule.rbxm"
-- 2026-09-25: optional and not pinned (the owner saves it from Studio; it changes on purpose).
local DESIGN_RACE_ASSETS = "design/race/RaceAssets.rbxm"
local PINNED = {
	[DESIGN_UI] = "3cedc6a19ca3db37d3f507b54c1151cd387750ed95aea037fd0d8d085667030f",
	[DESIGN_BUBBLE] = "7c10eae8d43b607568a3243f668ead7d0b17579d744b3b647a2f38f0bcfa78fa",
}
local DESIGNER_GUIS = { "Titles", "Playtime Boost", "Streak Rewards", "Community rewards" }
local DESIGNER_IMAGES = 33
local ARENA_CLEARANCE = 1500

-- The P0 remainder (PLAN §4: p0_data, p0_gameplay) and the integrator's P0 share. The build
-- p0 ships these, the 18 files of 09-24, and nothing of the Update 4 features.
local P0_FILES = {
	-- p0_data: H3 (+ApplyVolatile), M14/M15 Daily, M33 quests
	"src/common/ServerScriptService/Services/Data/SessionActor.luau",
	"src/common/ServerScriptService/Services/Data/DataService.luau",
	"src/common/ServerScriptService/Services/Stats/StatsProjection.luau",
	"src/common/ReplicatedStorage/Shared/DailyRewardsData.luau",
	"src/common/ReplicatedStorage/Shared/DailyRewards.luau",
	"src/common/ServerScriptService/Social/DailyLoginSystem.server.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau",
	"src/common/ReplicatedStorage/Shared/QuestCatalog.luau",
	"src/common/ServerScriptService/Social/QuestService.server.luau",
	"src/common/ReplicatedStorage/Shared/QuestPeriod.luau",
	-- M15: the Spin / potion days' art (the Streak hand-off in it stays off without Update 4)
	"src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau",
	-- p0_gameplay: H5 W1 rewind, H6 client-only deaths, M50 speed dial, H10 MovementGuard Observe.
	-- The four new modules must ship together: without LocalDeathArbiter there is no
	-- LocalDeathClaim, and a client that died locally stays dead.
	"src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau",
	"src/worlds/World1/ServerScriptService/Gameplay/NewWorld1MapSystems.server.luau",
	"src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau",
	"src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau",
	"src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau",
	"src/common/ReplicatedStorage/Shared/HudErgonomics.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/UI/WalkSpeedSelector.client.luau",
	"src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau",
	"src/common/ServerScriptService/Services/MovementGuard.luau",
	"src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau",
	"src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau",
	"src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau",
	"src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau",
	"src/common/ServerScriptService/Services/PoseHistory.luau",
	"src/common/ReplicatedStorage/Shared/HazardNames.luau",
	"src/common/ServerScriptService/Services/LocalDeathRules.luau",
	"src/common/ServerScriptService/Gameplay/LocalDeathArbiter.server.luau",
	-- Integrator: Config (M50/H10 keys), the M33 codec/reducer wiring (the U4 profile field rides
	-- along: its dispatcher carries saved data through even with no section module), the new
	-- custom events LocalDeathArbiter/MovementGuard send, and Update4Config, which
	-- AdminAbusePanelService (09-24) requires. Every Update 4 hook in these stays inert without
	-- the Update 4 services (no RaceActive, no EquippedTitle, no _G.SpeedsterRace/Titles).
	"src/common/ReplicatedStorage/Shared/Config.luau",
	"src/common/ServerScriptService/Services/Data/ProfileCodec.luau",
	"src/common/ServerScriptService/Services/Data/ProfileReducers.luau",
	"src/common/ServerScriptService/Services/Data/Update4Profile.luau",
	"src/common/ServerScriptService/Services/FunnelAnalytics.luau",
	"src/common/ReplicatedStorage/Shared/Update4Config.luau",
	"src/common/ReplicatedStorage/Shared/MenuEvents.luau",
}

-- Modules a P0 file names that p0 leaves at the places' copy, checked on 2026-09-25: what
-- changed in them is Update 4 only, and the P0 callers use nothing new.
local P0_GAPS_REVIEWED = {
	StatsService = "only the retention multiplier; an older copy ignores the extra key",
	StageTeleportService = "only ArmArrivalGrace, which the race server calls",
	ModalJuice = "only the six Update 4 panel names",
	-- 2026-09-26 (phone UI pass): reviewed for a p0-only build.
	MenuPanelLayout = "only PhoneBlock (TimeGift's smaller phone fit); an older copy has none, and BindPhoneFit keeps its old fit",
	RaceHudLayout = "MainHUDController 5d finds it without waiting (FindFirstChild, pcall); without it the side menu only keeps above the counters",
	-- 2026-09-26 (owner): the Super Sonic vs Eggman event's chaos sky, a blendLighting layer in AdminAbuseEffects.
	SuperSonicEvent = "AdminAbuseEffects' chaos sky layer finds it without waiting (FindFirstChild, pcall, every 2 s); without it the layer stays at 0 and blendLighting is as before",
	SuperSonicEventFx = "AdminAbuseEffects' chaos sky layer finds it without waiting (FindFirstChild, pcall, every 2 s); without it the layer stays at 0 and blendLighting is as before",
}

local function lf(text)
	return (text:gsub("\r\n", "\n"))
end

local function walk(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

local function baseName(path)
	return (path:match("([^/]+)$"):gsub("%.client%.luau$", ""):gsub("%.server%.luau$", ""):gsub("%.luau$", ""))
end

----------------------------------------------------------------------
-- Source lists
----------------------------------------------------------------------
local files = walk("src/common", {})
walk("src/worlds", files)
table.sort(files)

-- 2026-09-25, second build: the places carry the previous Update 4 build, exported by
-- audit/export_place_sources.luau into PLACES_NOW; that is what a changed source must still find
-- in its place (a guard against the older BACKUP would refuse every file that build put in).
-- Twin rows (same-named authored scripts) cannot be exported by path: for them, and on a first
-- build (no PLACES_NOW), the older BACKUP still stands.
local PLACES_NOW = "output/Update4/places_now_src/"
local function baselineOf(relative)
	if fs.isFile(PLACES_NOW .. relative) then
		return PLACES_NOW .. relative
	end
	return BACKUP .. relative
end

local all, changed, added = {}, {}, {}
for _, path in files do
	local relative = path:gsub("^src/", "")
	local backup = baselineOf(relative)
	local world = path:match("^src/worlds/([^/]+)/")
	local spec = { source = path, worlds = if world then { world } else nil }
	if not fs.isFile(backup) then
		table.insert(all, spec)
		table.insert(added, path)
	elseif lf(fs.readFile(backup)) ~= lf(fs.readFile(path)) then
		spec.guard = backup
		table.insert(all, spec)
		table.insert(changed, path)
	end
end
-- Nothing may have been deleted from src by this work.
for _, path in walk(BACKUP:sub(1, -2), {}) do
	local relative = path:sub(#BACKUP + 1)
	if relative:match("^common/") or relative:match("^worlds/") then
		assert(fs.isFile("src/" .. relative), "src/" .. relative .. " was deleted: restore it or retire it as a comment stub")
	end
end

-- The 18 retention P0 files of 09-24: they differ between the two backups.
local p0Set = {}
for _, path in walk(PRE_U4:sub(1, -2), {}) do
	local relative = path:sub(#PRE_U4 + 1)
	if relative:match("^common/") or relative:match("^worlds/") then
		local before = BACKUP .. relative
		if not fs.isFile(before) or lf(fs.readFile(before)) ~= lf(fs.readFile(path)) then
			p0Set["src/" .. relative] = "0924"
		end
	end
end
for _, path in P0_FILES do
	p0Set[path] = p0Set[path] or "p0"
end

local p0Sources = {}
for _, spec in all do
	if p0Set[spec.source] then
		table.insert(p0Sources, spec)
	end
end
-- A P0 file must exist and differ from what the places carry; a stale entry is a mistake here.
for path in p0Set do
	assert(fs.isFile(path), "P0 file " .. path .. " is missing from src")
end

-- A P0 file that names a module this build changes or adds, but p0 does not ship, would run
-- against the old copy (or none): listed so the list can be checked (warnings, not errors,
-- because a name can also be a plain string such as an attribute).
local function p0Gaps()
	local shipped, byName = {}, {}
	for _, spec in p0Sources do
		shipped[spec.source] = true
	end
	for _, spec in all do
		if not shipped[spec.source] and not spec.source:match("%.client%.luau$") and not spec.source:match("%.server%.luau$") then
			byName[baseName(spec.source)] = spec.source
		end
	end
	local gaps = {}
	for _, spec in p0Sources do
		local text = fs.readFile(spec.source)
		for name, source in byName do
			if text:find('"' .. name .. '"', 1, true) or text:find("%." .. name .. "[%s%)%.:,]") then
				table.insert(gaps, { text = spec.source .. " -> " .. source, reviewed = P0_GAPS_REVIEWED[name] })
			end
		end
	end
	table.sort(gaps, function(a, b)
		return a.text < b.text
	end)
	return gaps
end

----------------------------------------------------------------------
-- Authored assets (edit / verify)
----------------------------------------------------------------------
local ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange,
	Font = roblox.Font, -- labels through FontFace: a Lune `.Font =` cannot be serialized
	ColorSequence = roblox.ColorSequence, -- (7) the finish gantry's confetti colours
	PhysicalProperties = roblox.PhysicalProperties, -- 2026-09-26 (owner): frictionless race walls (RaceArenaBuilder.WallPhysics)
}

local designCache = nil
local function design()
	if designCache then
		return designCache
	end
	for path, sha in PINNED do
		assert(serde.hash("sha256", fs.readFile(path)) == sha, path .. " is not the pinned copy (SHA-256); re-pin it on purpose")
	end
	local ui = roblox.deserializeModel(fs.readFile(DESIGN_UI))
	assert(#ui == 1 and ui[1].ClassName == "Folder" and ui[1].Name == "NewUI", DESIGN_UI .. ": the root must be Folder NewUI")
	for _, d in ui[1]:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), DESIGN_UI .. " carries a script (" .. d:GetFullName() .. ")")
	end
	for _, name in DESIGNER_GUIS do
		local gui = ui[1]:FindFirstChild(name)
		assert(gui and gui.ClassName == "ScreenGui", DESIGN_UI .. ": ScreenGui " .. name .. " is missing")
	end
	assert(#ui[1]:GetChildren() == #DESIGNER_GUIS, DESIGN_UI .. ": NewUI holds more than the 4 panels")
	local bubble = roblox.deserializeModel(fs.readFile(DESIGN_BUBBLE))
	assert(#bubble == 1 and bubble[1].ClassName == "ModuleScript" and bubble[1].Name == "BubbleModule", DESIGN_BUBBLE .. ": root BubbleModule")
	local mesh = bubble[1]:FindFirstChild("Mesh")
	assert(mesh and mesh.ClassName == "MeshPart", DESIGN_BUBBLE .. ": BubbleModule.Mesh (MeshPart) is missing")
	assert(bubble[1].Source == fs.readFile("src/common/ReplicatedStorage/BubbleModule.luau"),
		"src/common/ReplicatedStorage/BubbleModule.luau must stay byte-identical to the rbxm's module")
	designCache = { guis = ui[1], mesh = mesh }
	return designCache
end

-- The image ids under a root: { [id] = count } and the total.
local function imageIds(root)
	local ids, total = {}, 0
	for _, d in root:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			local ok, content = pcall(function()
				return d.ImageContent
			end)
			local id = if ok then tostring(content) else "?"
			ids[id] = (ids[id] or 0) + 1
			total += 1
		end
	end
	return ids, total
end

-- Replaces a stamped asset; an unstamped one of the same name stops the build.
local function clearStamped(parent, name, stamp)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:GetAttribute("U4Asset") == stamp,
			parent:GetFullName() .. "." .. name .. " exists without the U4Asset stamp '" .. stamp .. "'; not replacing it")
		existing.Parent = nil
	end
end

local function insertDesignerGuis(dm, notes)
	local starterGui = dm:GetService("StarterGui")
	for _, name in DESIGNER_GUIS do
		clearStamped(starterGui, name, "DesignerUI")
		local gui = design().guis:FindFirstChild(name):Clone()
		gui.Enabled = false
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 20
		gui.ZIndexBehavior = roblox.Enum.ZIndexBehavior.Sibling
		gui:SetAttribute("U4Asset", "DesignerUI")
		gui.Parent = starterGui
	end
	table.insert(notes, "designer panels " .. table.concat(DESIGNER_GUIS, "/"))
end

local function insertBubbleMesh(dm, notes)
	local module = dm:GetService("ReplicatedStorage"):FindFirstChild("BubbleModule")
	assert(module and module.ClassName == "ModuleScript", "ReplicatedStorage.BubbleModule (src) must be in before its Mesh")
	clearStamped(module, "Mesh", "BubbleMesh")
	local mesh = design().mesh:Clone()
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CastShadow = false
	mesh.Massless = true
	for _, d in mesh:GetDescendants() do
		if d:IsA("Highlight") then
			d.Enabled = false
		end
	end
	mesh:SetAttribute("U4Asset", "BubbleMesh")
	mesh.Parent = module
	table.insert(notes, "BubbleModule.Mesh")
end

-- (7) Race art (2026-09-25): design/race/RaceAssets.rbxm, read once. Its root is the Folder (or
-- Model) the owner saved; several roots are wrapped in one Folder. Scripts are refused.
local raceAssetsCache = nil
local function raceAssets()
	if raceAssetsCache ~= nil then
		return raceAssetsCache or nil
	end
	if not fs.isFile(DESIGN_RACE_ASSETS) then
		raceAssetsCache = false
		return nil
	end
	local roots = roblox.deserializeModel(fs.readFile(DESIGN_RACE_ASSETS))
	local folder
	if #roots == 1 and (roots[1].ClassName == "Folder" or roots[1].ClassName == "Model") then
		folder = roots[1]
	else
		folder = roblox.Instance.new("Folder")
		for _, root in roots do
			root.Parent = folder
		end
	end
	folder.Name = "RaceAssets"
	for _, d in folder:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), DESIGN_RACE_ASSETS .. " carries a script (" .. d:GetFullName() .. "); remove it and save again")
	end
	raceAssetsCache = folder
	return folder
end

-- Which models of a RaceAssets folder are complete, and the first problem of each other one.
local function raceAssetsSummary(folder)
	local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
	local report = RaceArenaBuilder.ResolveAssets(folder)
	local ok, bad = {}, {}
	for _, model in RaceArenaBuilder.AssetModels do
		local entry = report[model]
		if entry and entry.ok then
			table.insert(ok, model)
		else
			table.insert(bad, model .. " (" .. (if entry then entry.problems[1] or "?" else "?") .. ")")
		end
	end
	return ok, bad
end

local function insertRaceAssets(dm, notes)
	local folder = raceAssets()
	local serverStorage = dm:GetService("ServerStorage")
	if not folder then
		local existing = serverStorage:FindFirstChild("RaceAssets")
		table.insert(notes, if existing then "RaceAssets: no " .. DESIGN_RACE_ASSETS .. ", the place's own ServerStorage.RaceAssets is used"
			else "RaceAssets: no " .. DESIGN_RACE_ASSETS .. " yet (part geometry)")
		return
	end
	clearStamped(serverStorage, "RaceAssets", "RaceAssets")
	local copy = folder:Clone()
	copy:SetAttribute("U4Asset", "RaceAssets")
	copy.Parent = serverStorage
	local ok = raceAssetsSummary(copy)
	table.insert(notes, "ServerStorage.RaceAssets (" .. (if #ok > 0 then table.concat(ok, ", ") else "no complete model") .. ")")
end

-- 2026-09-25: the race map is now made by hand (Astra). A place that already has
-- Workspace.RaceArena and Workspace.RaceGate keeps them as they are, ours or not; only
-- `--rebuild-race` replaces (our stamped copies of) them with the builder's.
local REBUILD_RACE = table.find(process.args, "--rebuild-race") ~= nil
local GREENHILL = table.find(process.args, "--greenhill") ~= nil

-- Our arenas carry one of these stamps; anything else named RaceArena is someone else's.
local ARENA_STAMPS = { RaceArena = true, RaceArenaGreenHill = true }
local function clearArena(workspace)
	local existing = workspace:FindFirstChild("RaceArena")
	if existing then
		local stamp = existing:GetAttribute("U4Asset")
		assert(ARENA_STAMPS[stamp] == true, "Workspace.RaceArena exists without our U4Asset stamp (RaceArena / RaceArenaGreenHill; it has "
			.. tostring(stamp) .. "); not replacing it")
		existing.Parent = nil
	end
end

-- (8) 2026-09-26: the Green Hill arena, converted once and cloned into each place.
local greenHillCache = nil
local function greenHill()
	if not greenHillCache then
		local GreenHill = require("./u4_greenhill_arena")
		local arena, report = GreenHill.Build()
		greenHillCache = { arena = arena, report = report, describe = GreenHill.Describe(report), stamp = GreenHill.Stamp }
	end
	return greenHillCache
end

local function insertGreenHill(dm, key, notes)
	local workspace = dm:GetService("Workspace")
	clearArena(workspace)
	local built = greenHill()
	local arena = built.arena:Clone()
	arena:SetAttribute("U4Asset", built.stamp)
	arena.Parent = workspace
	if REBUILD_RACE or not workspace:FindFirstChild("RaceGate") then
		clearStamped(workspace, "RaceGate", "RaceGate")
		local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
		ENV.RaceAssets = dm:GetService("ServerStorage"):FindFirstChild("RaceAssets") or false
		local gate = RaceArenaBuilder.BuildGate(workspace, key, ENV)
		ENV.RaceAssets = nil
		assert(gate, key .. ": no Race Gate point in Update4Config.Race.Gate")
		gate:SetAttribute("U4Asset", "RaceGate")
		table.insert(notes, "RaceArena Green Hill (" .. built.describe .. ") + RaceGate built")
	else
		table.insert(notes, "RaceArena Green Hill (" .. built.describe .. "), RaceGate kept")
	end
end

local function insertRace(dm, key, notes)
	if GREENHILL then
		insertGreenHill(dm, key, notes)
		return
	end
	local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
	local workspace = dm:GetService("Workspace")
	if not REBUILD_RACE and workspace:FindFirstChild("RaceArena") and workspace:FindFirstChild("RaceGate") then
		table.insert(notes, "RaceArena + RaceGate kept as the place has them (--rebuild-race rebuilds them, --greenhill puts the Green Hill map in)")
		return
	end
	clearArena(workspace)
	clearStamped(workspace, "RaceGate", "RaceGate")
	-- (7) the builder uses these meshes when they fit (false: the part geometry).
	ENV.RaceAssets = dm:GetService("ServerStorage"):FindFirstChild("RaceAssets") or false
	local arena = RaceArenaBuilder.Build(workspace, ENV)
	arena:SetAttribute("U4Asset", "RaceArena")
	local gate = RaceArenaBuilder.BuildGate(workspace, key, ENV)
	ENV.RaceAssets = nil
	assert(gate, key .. ": no Race Gate point in Update4Config.Race.Gate")
	gate:SetAttribute("U4Asset", "RaceGate")
	local meshes = tostring(arena:GetAttribute("RaceArenaAssets") or "")
	table.insert(notes, string.format("RaceArena (%s parts%s) + RaceGate%s", tostring(arena:GetAttribute("RaceArenaParts")),
		if meshes ~= "" then ", meshes " .. meshes else "", if gate:GetAttribute("RaceGateAssets") == true then " (booth)" else ""))
end

-- 2026-09-25: the owner's Eggman and Flash (Eggmanr6andflashr15.rbxm, converted to R6 by
-- audit/build_npc_r6 into design/npc/LobbyCharacters.rbxm) stand in every lobby at the spots
-- Shared/LobbyNpcConfig keeps; Gameplay/LobbyNpcs adopts them by name (prompt, dialog, idle).
-- Optional: no file, no characters (the server then spawns its own avatar Flash).
local LOBBY_CHARACTERS = "design/npc/LobbyCharacters.rbxm"
local function insertLobbyCharacters(dm, key, notes)
	if not fs.isFile(LOBBY_CHARACTERS) then
		table.insert(notes, "no " .. LOBBY_CHARACTERS .. ": no owner NPC models")
		return
	end
	local workspace = dm:GetService("Workspace")
	clearStamped(workspace, "LobbyCharacters", "LobbyCharacters")
	local folder = roblox.deserializeModel(fs.readFile(LOBBY_CHARACTERS))[1]:Clone()
	for _, d in folder:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), LOBBY_CHARACTERS .. " holds a script: " .. d:GetFullName())
	end
	local Npc = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
	local R6 = require("./u4_npc_r6")
	for _, model in folder:GetChildren() do
		local spot = Npc.Spot(key, model.Name)
		assert(spot, key .. ": no lobby spot for " .. model.Name)
		R6.Place(model, Npc.SpotCFrame(spot, roblox.CFrame))
	end
	-- 2026-09-26 (owner): Eggman drives his Egg Mobile (audit/u4_egg_mobile, Shared/EggMobile),
	-- built inside him on his spot from the Blender kit design/npc/EggMobileKit.rbxm; without that
	-- file there is no ship and he stands. The stamped folder is replaced on a rebuild (old ships go).
	require("./u4_egg_mobile").Insert(folder, key, notes)
	folder:SetAttribute("U4Asset", "LobbyCharacters")
	folder.Parent = workspace
	table.insert(notes, "LobbyCharacters (Eggman, Flash as R6)")
end

-- (9) 2026-09-26 (owner): The Flash's race gate (RaceArenaBuilder.BuildGate v2: the red arch,
-- the medallion, the ring pad, FlashSpot and HoloBoardAnchor). Our gate (U4Asset "RaceGate") is
-- rebuilt when its RaceGateVersion is older than RaceArenaBuilder.GateVersion (none = 1), or with
-- `--rebuild-gate` (or `force`); a RaceGate without our stamp is the owner's and is kept.
-- 2026-09-26 (owner): with design/race/flashgate/FlashGateKit.rbxm (audit/u4_flash_gate_kit) the
-- gate is the Blender meshes (FlashGate.MeshVersion), so a part-built v2 of ours is rebuilt; a
-- mesh gate is never turned back into parts when the file is gone.
local REBUILD_GATE = table.find(process.args, "--rebuild-gate") ~= nil
local FlashGateKit = require("./u4_flash_gate_kit")
local function refreshGate(dm, key, notes, force)
	local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
	local workspace = dm:GetService("Workspace")
	local existing = workspace:FindFirstChild("RaceGate")
	if existing and existing:GetAttribute("U4Asset") ~= "RaceGate" then
		table.insert(notes, "RaceGate kept: it has no U4Asset \"RaceGate\" stamp (the owner's)")
		return false
	end
	local kit = FlashGateKit.Load()
	local want = RaceArenaBuilder.GateVersionFor(kit)
	local version = if existing then tonumber(existing:GetAttribute("RaceGateVersion")) or 1 else 0
	if existing and version >= want and not (force or REBUILD_GATE) then
		table.insert(notes, "RaceGate v" .. version .. " kept (--rebuild-gate rebuilds it)")
		return false
	end
	clearStamped(workspace, "RaceGate", "RaceGate")
	ENV.FlashGateKit = kit or false
	local gate = RaceArenaBuilder.BuildGate(workspace, key, ENV)
	ENV.FlashGateKit = nil
	assert(gate, key .. ": no Race Gate point in Update4Config.Race.Gate")
	gate:SetAttribute("U4Asset", "RaceGate")
	table.insert(notes, string.format("RaceGate v%d built (The Flash's arch, %s, %d parts%s)", tonumber(gate:GetAttribute("RaceGateVersion")) or 0,
		if gate:GetAttribute("RaceGateKit") == true then "Blender meshes" else "parts",
		tonumber(gate:GetAttribute("RaceArenaParts")) or 0, if existing then ", replaced v" .. version else ""))
	return true
end

local function edit(key, dm, notes)
	insertDesignerGuis(dm, notes)
	insertBubbleMesh(dm, notes)
	ENV.FlashGateKit = FlashGateKit.Load() or false -- 2026-09-26: a gate insertRace builds uses the kit too
	insertRaceAssets(dm, notes)
	insertRace(dm, key, notes)
	refreshGate(dm, key, notes, false)
	insertLobbyCharacters(dm, key, notes)
	require("./u4_race_board").Remove(dm, notes)
	require("./u4_title_templates").Insert(dm, notes)
	require("./u4_shop_card").Insert(dm, notes)
	-- 2026-09-26 (owner): the Super Sonic vs Eggman event's art (ReplicatedStorage.SuperSonicEventAssets:
	-- the 4 VFX of assets/vfx_imported/ and the Blender kit's Meshes when audit/u4_event_kit.luau exists).
	require("./u4_supersonic_assets").Insert(dm, notes)
	return true
end

local function boxRadius(part)
	local size = part.Size
	return math.sqrt(size.X * size.X + size.Z * size.Z) * 0.5
end

local function verify(key, dm)
	local starterGui = dm:GetService("StarterGui")
	local images = 0
	for _, name in DESIGNER_GUIS do
		local gui = starterGui:FindFirstChild(name)
		assert(gui and gui.ClassName == "ScreenGui" and gui:GetAttribute("U4Asset") == "DesignerUI", key .. ": StarterGui." .. name)
		assert(gui.Enabled == false and gui.ResetOnSpawn == false, key .. ": " .. name .. " starts closed and survives respawns")
		-- Every designer image id came through the round trip unchanged (the Content type).
		local placed, count = imageIds(gui)
		local original = imageIds(design().guis:FindFirstChild(name))
		assert(placed["?"] == nil, key .. ": " .. name .. " has an unreadable image")
		for id, n in original do
			assert(placed[id] == n, key .. ": " .. name .. " lost or changed image " .. id)
		end
		images += count
	end
	assert(images == DESIGNER_IMAGES, key .. ": " .. images .. "/" .. DESIGNER_IMAGES .. " designer images")

	local module = dm:GetService("ReplicatedStorage"):FindFirstChild("BubbleModule")
	local mesh = module and module:FindFirstChild("Mesh")
	assert(mesh and mesh.ClassName == "MeshPart" and mesh.Anchored == true and mesh.CanCollide == false
		and mesh.CanQuery == false and mesh.CastShadow == false, key .. ": ReplicatedStorage.BubbleModule.Mesh")

	local workspace = dm:GetService("Workspace")
	local arena = workspace:FindFirstChild("RaceArena")
	assert(arena and workspace:FindFirstChild("RaceGate"), key .. ": Workspace.RaceArena and Workspace.RaceGate")
	-- The checks below are about the builder's own arena and gate; a hand-made map (Astra's,
	-- 2026-09-25) is not ours to hold to them. The Green Hill conversion (2026-09-26) has its own.
	local ours = arena:GetAttribute("U4Asset") == "RaceArena"
	local greenHillArena = arena:GetAttribute("U4Asset") == "RaceArenaGreenHill"
	if greenHillArena then
		local problems = require("./u4_greenhill_arena").Verify(arena)
		assert(#problems == 0, key .. ": Green Hill arena: " .. table.concat(problems, "; "))
	end
	if ours then
	assert(arena:GetAttribute("RaceArenaVersion") == 1, key .. ": Workspace.RaceArena")
	local parts = tonumber(arena:GetAttribute("RaceArenaParts")) or math.huge
	assert(parts <= 600, key .. ": arena part budget (" .. tostring(parts) .. " > 600)")
	local gate = workspace:FindFirstChild("RaceGate")
	assert(gate and gate:FindFirstChild("RaceGatePad") and gate:FindFirstChild("RaceGateSign"), key .. ": Workspace.RaceGate")
	-- (7) the race art: the meshes exactly where RaceAssets is complete (never for the gate since
	-- 2026-09-26: The Flash's arch is parts only).
	assert(gate:GetAttribute("RaceGateAssets") ~= true, key .. ": the gate uses no booth meshes")
	if raceAssets() then
		local stored = dm:GetService("ServerStorage"):FindFirstChild("RaceAssets")
		assert(stored and stored:GetAttribute("U4Asset") == "RaceAssets", key .. ": ServerStorage.RaceAssets (stamped)")
		local complete = {}
		for _, model in (raceAssetsSummary(stored)) do
			complete[model] = true
		end
		local meshes = tostring(arena:GetAttribute("RaceArenaAssets") or "")
		for _, model in { "RaceStartGantry", "RaceFinishGantry", "RaceTrackBarrier" } do
			assert((string.find(meshes, model, 1, true) ~= nil) == (complete[model] == true),
				key .. ": the arena uses " .. model .. " exactly when RaceAssets has it complete")
		end
	end
	end -- ours
	if ours or greenHillArena then
	-- The arena stands >= 1500 studs (XZ) from every other part, so the lobby streams out.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") then
			local p, r = d.CFrame.Position, boxRadius(d)
			minX, maxX = math.min(minX, p.X - r), math.max(maxX, p.X + r)
			minZ, maxZ = math.min(minZ, p.Z - r), math.max(maxZ, p.Z + r)
		end
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(arena) and d.ClassName ~= "Terrain" then
			local p, r = d.CFrame.Position, boxRadius(d)
			local dx = math.max(minX - (p.X + r), (p.X - r) - maxX, 0)
			local dz = math.max(minZ - (p.Z + r), (p.Z - r) - maxZ, 0)
			assert(dx * dx + dz * dz >= ARENA_CLEARANCE * ARENA_CLEARANCE,
				key .. ": " .. d:GetFullName() .. " is within " .. ARENA_CLEARANCE .. " studs of the race arena")
		end
	end
	end -- ours or greenHillArena

	-- 2026-09-26: our gate is The Flash's arch at the current version (its contract parts there),
	-- and the old Race_* board is gone.
	do
		local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
		local gate = workspace:FindFirstChild("RaceGate")
		if gate and gate:GetAttribute("U4Asset") == "RaceGate" then
			-- 2026-09-26: the mesh version when the Blender kit is there (and a mesh gate stays one).
			local want = RaceArenaBuilder.GateVersionFor(FlashGateKit.Load())
			assert((tonumber(gate:GetAttribute("RaceGateVersion")) or 0) >= want, key .. ": RaceGate is not v" .. want)
			for _, name in { "RaceGatePad", "RaceGateSign", "FlashSpot", "HoloBoardAnchor" } do
				assert(gate:FindFirstChild(name), key .. ": RaceGate." .. name)
			end
		end
	end
	local raceBoard = #require("./u4_race_board").Find(dm).stamped
	assert(raceBoard == 0, key .. ": " .. raceBoard .. " old Race_* board parts left")

	local titles = dm:GetService("ReplicatedStorage"):FindFirstChild("Titles")
	for _, name in { "Dev", "Tester", "Plain", "Gold", "Owner" } do
		local template = titles and titles:FindFirstChild(name)
		assert(template and template:IsA("BasePart"), key .. ": ReplicatedStorage.Titles." .. name)
	end

	local ShopCard = require("./u4_shop_card")
	local list = ShopCard.PassList(dm)
	local card = list and list:FindFirstChild(ShopCard.Name)
	assert(card and card:GetAttribute("U4Asset") == ShopCard.Stamp and card.Visible == false, key .. ": the hidden 2X Stamina Shop card")
	-- 2026-09-26 (owner): Eggman seated in his Egg Mobile at his spot.
	if fs.isFile(LOBBY_CHARACTERS) then
		require("./u4_egg_mobile").Verify(key, dm)
	end
	-- 2026-09-26 (owner): the Super Sonic vs Eggman event's art (stamped, VFX x4, Meshes, no scripts).
	require("./u4_supersonic_assets").Verify(key, dm)
	print(("  %s: 4 panels (%d images), Bubble mesh, arena (%s parts%s), gate, board, titles, shop card"):format(key, images,
		tostring(arena:GetAttribute("RaceArenaParts") or "?"), if ours then "" elseif greenHillArena then ", Green Hill" else ", hand-made"))
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------
local args = {}
local allowLocks = false
for _, arg in process.args do
	if arg == "--allow-locks" then
		allowLocks = true
	elseif arg == "--rebuild-race" or arg == "--greenhill" or arg == "--rebuild-gate" then
		-- read by insertRace (REBUILD_RACE, GREENHILL) and refreshGate (REBUILD_GATE); not modes
	else
		table.insert(args, arg)
	end
end
local mode = args[1] or "full"
local scope = if mode == "p0" or ((mode == "list" or mode == "check") and args[2] == "p0") then "p0" else "full"

-- `module`: the helpers only (an in-memory test harness may call edit/verify on a place it
-- loaded itself); nothing is built.
if mode == "module" then
	return { edit = edit, verify = verify, all = all, p0 = p0Sources, p0Gaps = p0Gaps, design = design,
		raceAssets = raceAssets, raceAssetsSummary = raceAssetsSummary, insertRaceAssets = insertRaceAssets,
		insertGreenHill = insertGreenHill, clearArena = clearArena, refreshGate = refreshGate }
end

local sources = if scope == "p0" then p0Sources else all
print(("src: %d changed, %d new source(s) against %s"):format(#changed, #added, BACKUP))
local shownChanged, shownAdded = 0, 0
for _, spec in sources do
	if spec.guard then
		shownChanged += 1
		print("  changed " .. spec.source .. (if p0Set[spec.source] then "  [" .. p0Set[spec.source] .. "]" else ""))
	end
end
for _, spec in sources do
	if not spec.guard then
		shownAdded += 1
		print("  new     " .. spec.source .. (if p0Set[spec.source] then "  [" .. p0Set[spec.source] .. "]" else ""))
	end
end
print(("%s build: %d changed + %d new = %d sources%s"):format(scope, shownChanged, shownAdded, #sources,
	if scope == "full" then "; assets: " .. table.concat(DESIGNER_GUIS, ", ") .. ", BubbleModule.Mesh, RaceArena, RaceGate (The Flash's arch: " .. (if FlashGateKit.Load() then "Blender meshes, " .. FlashGateKit.KitFile else "parts v2, no " .. FlashGateKit.KitFile) .. "), old Race_* board out, title templates, 2X Stamina card" else "; no assets"))
if scope == "full" then
	-- (7) 2026-09-25: the optional race art, reported before any place is opened.
	local folder = raceAssets()
	if folder then
		local ok, bad = raceAssetsSummary(folder)
		print("race art: " .. DESIGN_RACE_ASSETS .. " -> ServerStorage.RaceAssets; meshes for " .. (if #ok > 0 then table.concat(ok, ", ") else "nothing"))
		for _, line in bad do
			print("  part geometry kept: " .. line)
		end
	else
		print("race art: no " .. DESIGN_RACE_ASSETS .. " (design/race/IMPORTAR_EN_STUDIO.md); the arena and gate keep their part geometry")
	end
	-- (8) 2026-09-26: the Green Hill map, converted in memory (nothing is written).
	if GREENHILL then
		local built = greenHill()
		print("race map (--greenhill): Workspace.RaceArena <- Green Hill, stamp " .. built.stamp .. ": " .. built.describe)
		for _, line in built.report.warnings do
			print("  kit warning: " .. line)
		end
		for _, line in built.report.skipped do
			print("  kit skipped: " .. line)
		end
		if built.report.kitNote then
			print("  kit: " .. built.report.kitNote)
		end
	else
		print("race map: Workspace.RaceArena kept as the places have it (--greenhill puts the Green Hill map in)")
	end
end
if scope == "p0" then
	for _, gap in p0Gaps() do
		if gap.reviewed then
			print("  ok     " .. gap.text .. " (left out: " .. gap.reviewed .. ")")
		else
			print("  CHECK  p0 file names a module p0 does not ship: " .. gap.text)
		end
	end
end
local locks = {}
for _, place in Lib.Places do
	if fs.isFile(place.file .. ".lock") then
		table.insert(locks, place.file .. ".lock")
	end
end
if #locks > 0 then
	print("  lock files: " .. table.concat(locks, ", ") .. (if allowLocks then " (--allow-locks)" else " (the build refuses them without --allow-locks)"))
end
if mode == "list" then
	return
end

assert(mode == "full" or mode == "p0" or mode == "check", "unknown mode " .. tostring(mode) .. " (list | check | p0 | full)")
assert(#locks == 0 or allowLocks, "a place is locked (open in Studio?): " .. table.concat(locks, ", ") .. "; close it or pass --allow-locks")
assert(#sources > 0 or (scope == "full" and (GREENHILL or REBUILD_RACE or REBUILD_GATE)), "nothing to build")
if scope == "full" then
	design() -- pinned SHA-256 and roots checked before any place is opened
end
Lib.run({
	output = if scope == "p0" then "output/Update4/build_p0" else "output/Update4/build_full",
	sources = sources,
	createFolders = true,
	dryRun = mode == "check",
	edit = if scope == "full" then edit else nil,
	verify = if scope == "full" then verify else nil,
})
