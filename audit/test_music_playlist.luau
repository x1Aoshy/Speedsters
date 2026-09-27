--!strict
-- audit/test_music_playlist.luau
-- The requested playlist reaches the game, and exactly one script owns the
-- background music Sound.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local stub = {}
stub.GetAttribute = function() return nil end
stub.FindFirstChild = function() return nil end
stub.WaitForChild = function() return stub end
local Config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), {
	environment = {
		game = { GetService = function() return stub end, PlaceId = 85065221510105 },
		workspace = stub, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
		CFrame = roblox.CFrame, Enum = roblox.Enum, UDim2 = roblox.UDim2,
		table = table, math = math, string = string, os = os, ipairs = ipairs, pairs = pairs,
		tonumber = tonumber, tostring = tostring, type = type, typeof = typeof, next = next,
		select = select, pcall = pcall, error = error, assert = assert,
		print = function() end, warn = function() end,
	},
})()

local REQUESTED = {
	"rbxassetid://85735197482652",
	"rbxassetid://139777823649977",
	"rbxassetid://122959603077641",
	"rbxassetid://136221009150327",
	"rbxassetid://140521045204459",
	"rbxassetid://139959590610806",
	"rbxassetid://95131770144654",
}

local tracks = Config.BackgroundMusicTracks or {}
assert(#tracks == #REQUESTED, string.format("Expected %d tracks, found %d", #REQUESTED, #tracks))
local present = {}
for _, track in ipairs(tracks) do
	assert(tostring(track.Id):match("^rbxassetid://%d+$"), "Track id is malformed: " .. tostring(track.Id))
	present[tostring(track.Id)] = true
end
for _, id in ipairs(REQUESTED) do
	assert(present[id], "Requested track missing from the playlist: " .. id)
end

local music = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Audio/BackgroundMusic.client.luau")
assert(string.find(music, "Config.BackgroundMusicTracks", 1, true), "The player must read the playlist from Config")
assert(string.find(music, "music.Ended:Connect", 1, true), "Tracks must advance when one ends")
-- The behaviours the old single-track script had, which must survive.
assert(string.find(music, 'GetAttributeChangedSignal("Muted")', 1, true), "Mute toggle must still silence the music")
assert(string.find(music, 'GetAttributeChangedSignal("MusicVolume")', 1, true), "The volume slider must still apply")
assert(string.find(music, "BossAreaAmbienceDuck", 1, true), "Boss/arena ducking must still apply")

-- The real playlist builder, against a Music folder shaped like the shipped one:
-- six of the seven requested tracks already authored, other authored tracks, and
-- admin tracks that must stay out. Config used to apply only to an EMPTY folder, so
-- the one requested track missing from it never played.
do
	local startAt = assert(string.find(music, "local function buildPlaylist()", 1, true))
	local stopAt = assert(string.find(music, "local playlist = buildPlaylist()", startAt, true))
	local chunk = string.sub(music, startAt, stopAt - 1) .. "\nreturn buildPlaylist"

	local function sound(name, id)
		return { Name = name, SoundId = id, IsA = function(_, class) return class == "Sound" end }
	end
	local folder = {
		sound("#phonkmusic", "rbxassetid://139777823649977"),
		sound("Harbor at Dusk", "rbxassetid://122959603077641"),
		sound("MONTAGEM DRIFT ETERNO", "rbxassetid://136221009150327"),
		sound("BATE FORTE", "rbxassetid://140521045204459"),
		sound("FUNK FESTA", "rbxassetid://139959590610806"),
		sound("AURA", "rbxassetid://95131770144654"),
		sound("Raining Tacos", "rbxassetid://1000000001"),
		sound("Chill Jazz", "rbxassetid://1000000002"),
		sound("ADMIN ABUSE FUNK", "rbxassetid://96676453601711"),
		sound("ADMIN ABUSE HARDSTYLE", "rbxassetid://128689215851296"),
	}
	local buildPlaylist = luau.load(chunk, {
		environment = {
			ReplicatedStorage = {
				FindFirstChild = function(_, name)
					return if name == "Music" then { GetChildren = function() return folder end } else nil
				end,
			},
			Config = Config,
			FALLBACK_SOUND_ID = "rbxassetid://1840684529",
		},
	})()

	local playlist = buildPlaylist()
	local counts = {}
	for _, id in ipairs(playlist) do
		counts[id] = (counts[id] or 0) + 1
	end
	for _, id in ipairs(REQUESTED) do
		assert(counts[id] == 1, "Requested track must play exactly once in the rotation: " .. id)
	end
	assert(counts["rbxassetid://1000000001"] == 1 and counts["rbxassetid://1000000002"] == 1,
		"Authored folder tracks must stay in the rotation")
	assert(counts["rbxassetid://96676453601711"] == nil and counts["rbxassetid://128689215851296"] == nil,
		"Admin abuse tracks are event music, not background rotation")
	assert(#playlist == 9, "Expected 7 requested + 2 other authored tracks, got " .. #playlist)
	print("PASS music: every requested track plays alongside the authored folder, no duplicates")
end

-- Exactly one owner of the Sound's SoundId, or they fight on spawn.
local reset = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Audio/AudioIdReset.client.luau")
assert(not string.find(reset, "SpeedsterBackgroundMusic", 1, true),
	"AudioIdReset must not force the background music id; BackgroundMusic.client owns it")
assert(string.find(reset, "SpeedsterUiClickSound", 1, true), "AudioIdReset still owns the click sound")

print(string.format("PASS music: %d requested tracks in the playlist, single owner, mute/volume/ducking intact", #tracks))
