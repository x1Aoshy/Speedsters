-- test_u4_race_board.luau (Update 4, titles_boards, 2026-09-25)
-- The "FASTEST RACERS" lobby board (PLAN §7.6 items 7-8). 2026-09-26 (owner): the physical board
-- is retired: the race records are the digital holo board beside The Flash (Shared/FlashGate,
-- audit/test_u4_flash_gate). Checks:
--   1. audit/u4_race_board.Remove on copies of the 3 places: every Race_* part stamped RaceBoard
--      (the 09-25 build's board) goes, a Race_* part without the stamp stays (with a note), it is
--      idempotent, and build_update4 calls Remove, never Place;
--   1b. the race titles (top 1/5/10) no longer depend on that board: RaceLeaderboard hands its
--      all-time order to deps.setBoardRanks("Race", ids) after every read, and RaceServer wires
--      it to TitleService.SetBoardRanks;
--   2. GlobalLeaderboards.server: the Race category stays (Ascending, ExternalWrites, Optional, the
--      all-time store from Update4Config): with no Race_* parts it binds nothing and the other
--      three boards still bind; publishPlayer skips ExternalWrites, refreshBoard reads
--      GetSortedAsync(category.Ascending == true) and feeds TitleService.SetBoardRanks;
--   3. GlobalLeaderboardDisplay.client: the Race category (colours of the plan) and the same
--      Optional handling.
-- "places" checks the built places on disk: no stamped Race_* part left.
-- Run: lune run audit/test_u4_race_board.luau [places]   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Board = require("./u4_race_board")
local SERVER = "src/common/ServerScriptService/Social/GlobalLeaderboards.server.luau"
local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/UI/GlobalLeaderboardDisplay.client.luau"
local PLACES = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local PLACES_MODE = process.args[1] == "places"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end

for _, path in { SERVER, CLIENT, "audit/u4_race_board.luau" } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("GlobalLeaderboards server/display and u4_race_board compile")

----------------------------------------------------------------------
-- 1. The old board comes out (2026-09-26)
----------------------------------------------------------------------
for _, place in PLACES do
	local dm = roblox.deserializePlace(fs.readFile(place.file))
	local found = Board.Find(dm)
	if PLACES_MODE then
		assert(#found.stamped == 0, place.key .. ": " .. #found.stamped .. " stamped Race_* parts are still in the built place")
		print(string.format("  %s: no old race board (%d unstamped Race_* parts kept)", place.key, #found.foreign))
	else
		local before = #found.stamped
		-- A Race_* part someone else made (no stamp) stays where it is.
		local model = Board.FindModel(dm)
		assert(model, place.key .. ": leaderboard1")
		local foreign = roblox.Instance.new("Part")
		foreign.Name = "Race_OwnersSign"
		foreign.Parent = model
		local notes = {}
		local removed = Board.Remove(dm, notes)
		assert(removed == before, place.key .. ": removed " .. removed .. " of " .. before)
		local after = Board.Find(dm)
		assert(#after.stamped == 0, place.key .. ": stamped Race_* parts left")
		assert(foreign.Parent == model and table.find(after.foreign, foreign), place.key .. ": an unstamped Race_* part stays")
		local noted = false
		for _, line in notes do
			noted = noted or string.find(line, "Race_OwnersSign", 1, true) ~= nil
		end
		assert(noted, place.key .. ": the kept part is named in the notes")
		assert(Board.Remove(dm, {}) == 0 and foreign.Parent == model, place.key .. ": idempotent")
		-- The leaderboard model's other boards are untouched.
		assert(model:FindFirstChild("Wins_LeaderboardScreen", true) and model:FindFirstChild("Robux_LeaderboardScreen", true),
			place.key .. ": the Wins / Robux boards stay")
		print(string.format("  %s: %d stamped Race_* parts removed; an unstamped one kept", place.key, removed))
	end
end
do
	local build = read("audit/build_update4.luau")
	has(build, 'require("./u4_race_board").Remove(dm, notes)', "the build takes the old board out")
	assert(not string.find(build, "u4_race_board\").Place", 1, true), "the build no longer places the board")
	assert(Board.Place == nil, "u4_race_board has no Place any more")
end
pass(if PLACES_MODE
	then "the 3 built places carry no stamped Race_* part"
	else "Remove: every stamped Race_* part out, unstamped ones kept (noted), idempotent; build_update4 removes, never places")

----------------------------------------------------------------------
-- 1b. The race titles are fed without the board (2026-09-26)
----------------------------------------------------------------------
do
	local RaceLeaderboard = require("../src/common/ServerScriptService/Services/Race/RaceLeaderboard")
	local function store(rows)
		return {
			GetSortedAsync = function(_, ascending, size)
				assert(ascending == true, "ascending")
				local page = {}
				for i = 1, math.min(size, #rows) do
					page[i] = rows[i]
				end
				return { GetCurrentPage = function() return page end }
			end,
			UpdateAsync = function() end,
		}
	end
	local fed = {}
	local board = RaceLeaderboard.new({
		allTimeStore = store({ { key = "U_7", value = 31000 }, { key = "U_3", value = 32000 }, { key = "U_9", value = 40000 } }),
		weeklyStore = function()
			return store({ { key = "U_3", value = 32000 } })
		end,
		unix = function() return 1728259200 end,
		clock = function() return 0 end,
		setBoardRanks = function(boardId, ids)
			table.insert(fed, { boardId, ids })
		end,
	})
	board:Read()
	assert(#fed == 1 and fed[1][1] == "Race", "one Race feed per read")
	assert(table.concat(fed[1][2], ",") == "7,3,9", "the all-time order, fastest first: " .. table.concat(fed[1][2], ","))
	-- A failed all-time read feeds nothing (the titles keep their last ranks).
	local failed = RaceLeaderboard.new({
		allTimeStore = { GetSortedAsync = function() error("503") end },
		weeklyStore = function()
			return store({})
		end,
		unix = function() return 1728259200 end,
		setBoardRanks = function()
			error("must not be called")
		end,
	})
	failed:Read()
	local server = read("src/common/ServerScriptService/Gameplay/RaceServer.server.luau")
	has(server, "setBoardRanks = function(boardId, userIds)", "RaceServer passes setBoardRanks")
	has(server, "service.SetBoardRanks(boardId, userIds)", "...to TitleService.SetBoardRanks")
	pass("RaceLeaderboard feeds the race titles its all-time order after every read (RaceServer -> TitleService.SetBoardRanks)")
end

----------------------------------------------------------------------
-- 2. GlobalLeaderboards.server
----------------------------------------------------------------------
do
	local source = read(SERVER)
	local race = string.match(source, 'Id = "Race",(.-)\n\t}%)')
	assert(race, "GlobalLeaderboards has the Race category")
	for _, needle in { 'Title = "FASTEST RACERS"', 'ColumnTitle = "TIME"', "Primary = Color3.fromRGB(0, 190, 235)",
		"Accent = Color3.fromRGB(190, 95, 255)", "Dark = Color3.fromRGB(6, 22, 48)", "Ascending = true",
		"ExternalWrites = true", "Optional = true", "Decode = cleanOrderedInteger", 'string.format("%.2fs"',
		"GetOrderedDataStore(raceStoreName)" } do
		has(race, needle, "Race category")
	end
	has(source, "U4.Race.Leaderboard.AllTimeStore", "reads the store name from Update4Config")
	has(source, "GetSortedAsync(category.Ascending == true, DISPLAY_COUNT)", "refreshBoard honours Ascending")
	has(source, "if category.ExternalWrites then", "publishPlayer skips externally written boards")
	has(source, "if not category.Optional and not categoryHasTargets(model, category) then", "hasImportedTargets ignores Optional")
	has(source, "if category.Optional and not categoryHasTargets(model, category) then", "bindImportedBoards skips missing Optional")
	has(source, "#boardStates == expectedBoardCount", "the refresh loop counts the bound boards")
	assert(not string.find(source, "#boardStates == #categories", 1, true), "no loop may require every category")
	has(source, "pcall(TitleService.SetBoardRanks, category.Id, orderedUserIds)", "board order feeds the titles")
	assert(string.find(source, "setBoardRows(state, entries, nil)\n\t-- The live top 1/5/10", 1, true),
		"SetBoardRanks right after setBoardRows")
	-- The published Race store name is the one the race server writes.
	local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
	assert(U4.Race.Leaderboard.AllTimeStore == "SpeedsterEscape_RaceBestMs_v1")
	pass("GlobalLeaderboards: Race (ascending, external writes, optional), SetBoardRanks after every refresh")
end

----------------------------------------------------------------------
-- 3. GlobalLeaderboardDisplay.client
----------------------------------------------------------------------
do
	local source = read(CLIENT)
	local race = string.match(source, 'Id = "Race",(.-)\n\t}')
	assert(race, "the display has the Race category")
	for _, needle in { 'Title = "FASTEST RACERS"', 'ColumnTitle = "TIME"', "Primary = Color3.fromRGB(0, 190, 235)",
		"Accent = Color3.fromRGB(190, 95, 255)", "Background = Color3.fromRGB(6, 22, 48)",
		"RowA = Color3.fromRGB(8, 40, 78)", "RowB = Color3.fromRGB(6, 32, 64)", "Optional = true" } do
		has(race, needle, "display Race category")
	end
	has(source, "if not category.Optional and not categoryHasTargets(model, category) then", "display hasImportedTargets ignores Optional")
	has(source, "waitingOptional", "the display binds an Optional board when its parts stream in")
	pass("GlobalLeaderboardDisplay: Race category (plan colours) and Optional binding")
end

print(string.format("test_u4_race_board: %d checks passed", passed))
