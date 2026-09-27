-- BackgroundMusic.client.luau
-- Plays the background playlist from Config.BackgroundMusicTracks.
--
-- This used to loop one hardcoded track forever. It now walks a shuffled playlist,
-- advancing when each track ends, while keeping every behaviour the old script had:
-- the Settings mute toggle, the MusicVolume slider, and the boss/arena ducking.
--
-- Sounds placed in ReplicatedStorage.Music play too; the Config list adds any track
-- the folder does not already have.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FALLBACK_SOUND_ID = "rbxassetid://1840684529"
local MUSIC_VOLUME = tonumber(Config.BackgroundMusicVolume) or 0.24
local DUCKED_MUSIC_VOLUME = tonumber(Config.BackgroundMusicDuckedVolume) or 0.06
local DUCK_ATTRIBUTES = {
	"BossAreaAmbienceDuck",
	"ZoomArenaAmbienceDuck",
	"WallyArenaAmbienceDuck",
}

local localPlayer = Players.LocalPlayer

-- Authored sounds in ReplicatedStorage.Music, plus every Config track that is not
-- already one of them. Config used to apply only when the folder was empty; the folder
-- is not empty, so any requested track missing from it never played.
local function buildPlaylist()
	local tracks = {}
	local seen = {}
	local function add(soundId)
		local numeric = string.match(tostring(soundId), "(%d+)$")
		if numeric and not seen[numeric] then
			seen[numeric] = true
			table.insert(tracks, "rbxassetid://" .. numeric)
		end
	end

	local musicFolder = ReplicatedStorage:FindFirstChild("Music")
	if musicFolder then
		for _, child in ipairs(musicFolder:GetChildren()) do
			if child:IsA("Sound") and child.SoundId ~= "" and not child.Name:lower():find("^admin") then
				add(child.SoundId)
			end
		end
	end

	for _, track in ipairs(Config.BackgroundMusicTracks or {}) do
		local id = tostring(track.Id or track)
		if id:match("^rbxassetid://%d+$") then
			add(id)
		end
	end

	if #tracks == 0 then
		table.insert(tracks, FALLBACK_SOUND_ID)
	end

	-- Shuffle per session so a full server does not march through in lockstep.
	for index = #tracks, 2, -1 do
		local swap = math.random(index)
		tracks[index], tracks[swap] = tracks[swap], tracks[index]
	end
	return tracks
end

local playlist = buildPlaylist()
local trackIndex = 0

local function getMusic()
	local music = SoundService:FindFirstChild("SpeedsterBackgroundMusic")
	if not music then
		music = Instance.new("Sound")
		music.Name = "SpeedsterBackgroundMusic"
		music.Parent = SoundService
	end
	return music
end

local function getMusicVolumeMultiplier()
	local value = tonumber(localPlayer:GetAttribute("MusicVolume"))
	if value == nil then
		return 1
	end
	return math.clamp(math.floor(value), 0, 100) / 100
end

-- Volume is recomputed from mute, the slider and the current ducking state.
local function applyVolume()
	local music = getMusic()
	local ducked = false
	for _, attribute in ipairs(DUCK_ATTRIBUTES) do
		if music:GetAttribute(attribute) == true then
			ducked = true
			break
		end
	end
	local muted = localPlayer:GetAttribute("Muted") == true
		-- A track an admin plays for the server replaces the playlist until it stops.
		or workspace:GetAttribute("AdminMusicActive") == true
	local base = ducked and DUCKED_MUSIC_VOLUME or MUSIC_VOLUME
	music.Volume = muted and 0 or (base * getMusicVolumeMultiplier())
end
workspace:GetAttributeChangedSignal("AdminMusicActive"):Connect(function()
	applyVolume()
end)

local lastStartedAt = 0

local function playNextTrack()
	local music = getMusic()
	lastStartedAt = os.clock()
	trackIndex += 1
	if trackIndex > #playlist then
		trackIndex = 1
	end
	music.SoundId = playlist[trackIndex]
	-- A single-track playlist loops itself; a real playlist advances on Ended.
	music.Looped = #playlist <= 1
	music.PlaybackSpeed = 1
	music.RollOffMode = Enum.RollOffMode.InverseTapered
	applyVolume()
	music:Play()
end

local music = getMusic()

music.Ended:Connect(function()
	if #playlist > 1 then
		playNextTrack()
	end
end)

-- A track the experience is not licensed for never loads; skip to the next one
-- instead of leaving the player in silence for the rest of the session.
music.Loaded:Connect(applyVolume)
task.spawn(function()
	while true do
		task.wait(3)
		-- Give a track a fair chance to stream in before declaring it dead, so a
		-- slow connection does not chew through the playlist.
		if #playlist > 1
			and not music.IsPlaying
			and not music.IsPaused
			and os.clock() - lastStartedAt > 8
		then
			playNextTrack()
		end
	end
end)

-- The Settings "Sound" toggle clamps everything to silence.
music:GetPropertyChangedSignal("Volume"):Connect(function()
	if localPlayer:GetAttribute("Muted") == true and music.Volume > 0 then
		music.Volume = 0
	end
end)

localPlayer:GetAttributeChangedSignal("Muted"):Connect(applyVolume)
localPlayer:GetAttributeChangedSignal("MusicVolume"):Connect(applyVolume)
for _, attribute in ipairs(DUCK_ATTRIBUTES) do
	music:GetAttributeChangedSignal(attribute):Connect(applyVolume)
end

playNextTrack()

print(string.format("[BackgroundMusic] Playlist of %d track(s), shuffled, mute and ducking preserved.", #playlist))
