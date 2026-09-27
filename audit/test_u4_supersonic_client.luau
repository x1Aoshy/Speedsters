-- test_u4_supersonic_client.luau (2026-09-26, owner: the "Super Sonic vs Dr. Eggman" live event, CLIENT side)
-- Checked here:
--   1. the three client files compile (Gameplay/SuperSonicEventClient, Shared/SuperSonicEventFx,
--      Shared/SuperSonicLook) and the client reads only the shared contract's names (Shared/SuperSonicEvent);
--   2. Shared/SuperSonicEventFx's pure functions: tiers, the owner's textures only, the emitter sets (every
--      name exists in assets/vfx_imported, Steal a Hero's taco confetti never fires), EmitCount, the bomb's
--      camera punch by distance (SSE.Camera values at the blast), the emeralds' fall / orbit / Bezier into the
--      chest (continuous, SSE.EmeraldOrbit in the middle, gone at AbsorbAt), HitPoint, FrameAlong, the words
--      (en / es / pt, refusals, chat lines), the Flight-equipped rule;
--   3. the Blender kit's numbers (design/event/supersonic/event_manifest.json): the cannon's mount and muzzle,
--      SSE.Boss.Cannon = its spawn point x SSE.Boss.DrawScale, the bomb's nose axis;
--   4. the touch HOMING ATTACK button (Fx.HomingButtonRect) against HudErgonomics' touch controls on phone,
--      tablet and desktop shapes, automatic and saved layouts: never on (or within 24 px of) the jump button,
--      never in the thumbstick area, clear of Sprint / Burst / Heat Vision and the phone column, on screen;
--   5. a simulation of Shared/SuperSonicLook on the owner's R6 Eggman (accessories, face, SpecialMesh head)
--      wearing an equipped aura and trail (character.SpeedsterCosmetics): gold body, Neon glaze, ruby eyes,
--      lightning flipbook sparks from the limbs; the aura and trail untouched (not hidden, not disabled, not
--      recoloured, nothing added inside); a server colour change mid-form is the one restored; the spin
--      ball's hide / show; Remove puts everything back exactly and leaves nothing behind;
--   6. the client, read as text: no default particle texture anywhere, the one emitter factory, no Highlight
--      and PointLights only on the emeralds, the boss clone strips highlights / lights, no aura or trail
--      named, the inputs (F / Left Click / gamepad X bound only in the Battle while Super, Space in the air
--      only without the Flight ability, the touch button), the kill switch, cleanup on phase "" and on
--      respawn, pools and nothing built in the per-frame functions, CameraPunch values from the contract,
--      the kinematic flight (PlatformStand, SonicBurstDashLocal, HomingPath, HomingBounce), every message.
-- 2026-09-26 (owner, v2 after testing v1), also:
--   8. the "LE Lightning Globe" texture is gone from every src file; the owner's uploaded sounds are the
--      ones played (and the explosion he likes is kept); sounds respect SoundEffects / Muted;
--   9. Shared/SuperSonicDialogue: every contract cue / taunt has a line in en / es / pt, the typewriter, the
--      box fits every phone viewport (notch insets, the letterbox band, under the boss bar), 11 px text;
--  10. Shared/SuperSonicCinematic: the three shots are smooth, never under the floor, start on the player's
--      camera and end where the player's own camera will be; the letterbox;
--  11. Fx v2: the charge, the red warning zone and its alarm, the bomb's exit from the barrel, the cannon's
--      deploy / retract / kick, the gestures (legs under the floor), the chaos weight, the vignette, the
--      emeralds' VFX sets, the ring rain's maths, the fade into the horizon;
--  12. the Super Sonic skin mode of SuperSonicLook (no glaze, no gold, no eyes: small sparks only);
--  13. Admin/AdminAbuseEffects' blendLighting with the chaos layer: the fiery sky mixes in and the lobby's own
--      Lighting comes back EXACTLY; Audio/BackgroundMusic fades the playlist out under the event's music;
--  14. the real client in the fake Roblox through a whole v2 event: the intro / emeralds / outro cinematics
--      (the camera, the controls and the interface ALWAYS back: the end, a respawn, the kill switch; none for a
--      player who joins mid-event), the dialogue and voices, the charge flow and its messages, the shield and
--      the Reload window, the red zones, the rings, the music, the vignette only while Super, the chaos grade
--      restored, nothing left behind.
-- 2026-09-26 (owner, v3 after the next playtest), also:
--  15. the burn's cadence (a short one-shot now and then, random gaps, never two at once), the chaos toned down
--      (a subtle warm haze, zone-based: only in the event's arena) and restored exactly, the HUD held away (as
--      for a menu) except the topbar and given back, "hit!" only on a damaging connection (the server's
--      acceptance; never on a bounce or a refusal), the hit-stop and the shield's knock-back, the mid-air jump's
--      instant attack (JumpRequest edges), the "(A)" / "(X)" reticle prompt, ONE big wrapping trail, the freeze
--      windows applied and let go exactly, the invite card (YES / NO / let pass / closing by itself), the simple
--      dialogue (no box, no name tab, a small round portrait), the boss bar in the game's HUD style, no banners /
--      notices / hints, the crash (the dive, the impact chain, the rings bursting at their time, no dialogue),
--      the cinematics' eased spline keys (smooth, gentle FOV, kept clear of walls, the Entry shot), and the race
--      map as a plain map (the race pieces hidden and back exactly) with the Teleport / Return beats (the fade,
--      the arrival, the streaming, the lobby Eggman back).
-- Run: lune run audit/test_u4_supersonic_client.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Vector3, CFrame, Color3, Instance = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Instance

local SSE = require("../src/common/ReplicatedStorage/Shared/SuperSonicEvent")
local Fx = require("../src/common/ReplicatedStorage/Shared/SuperSonicEventFx")
local Look = require("../src/common/ReplicatedStorage/Shared/SuperSonicLook")
local H = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")
local Dialogue = require("../src/common/ReplicatedStorage/Shared/SuperSonicDialogue")
local Cine = require("../src/common/ReplicatedStorage/Shared/SuperSonicCinematic")
local CinematicFit = require("../src/common/ReplicatedStorage/Shared/CinematicFit")

local CLIENT_PATH = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/SuperSonicEventClient.client.luau"
local FX_PATH = "src/common/ReplicatedStorage/Shared/SuperSonicEventFx.luau"
local LOOK_PATH = "src/common/ReplicatedStorage/Shared/SuperSonicLook.luau"
local DIALOGUE_PATH = "src/common/ReplicatedStorage/Shared/SuperSonicDialogue.luau"
local CINE_PATH = "src/common/ReplicatedStorage/Shared/SuperSonicCinematic.luau"
local EFFECTS_PATH = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau"
local MUSIC_PATH = "src/common/StarterPlayer/StarterPlayerScripts/Audio/BackgroundMusic.client.luau"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, tolerance, message)
	assert(math.abs(a - b) <= (tolerance or 1e-6), message .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function nearV(a, b, tolerance, message)
	local d = (a - b).Magnitude
	assert(d <= (tolerance or 1e-3), message .. " (off by " .. d .. ": " .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function hasNot(source, needle, message)
	assert(not string.find(source, needle, 1, true), message .. " (found: " .. needle .. ")")
end
local function count(source, needle)
	local n, at = 0, 1
	while true do
		local s, e = string.find(source, needle, at, true)
		if not s then
			return n
		end
		n += 1
		at = e + 1
	end
end

local client = fs.readFile(CLIENT_PATH)
local fxSource = fs.readFile(FX_PATH)
local lookSource = fs.readFile(LOOK_PATH)

-- The body of `[local ]function NAME(` up to the line that is exactly "end" at its indent.
local function body(text, name)
	local start = string.find(text, "\n[\t]*local function " .. name .. "%(")
		or string.find(text, "\n[\t]*function " .. name .. "%(")
	assert(start, "function " .. name .. " not found")
	start += 1
	local indent = string.match(text, "^([\t]*)", start) or ""
	local finish = string.find(text, "\n" .. indent .. "end\n", start, true)
	assert(finish, "end of " .. name .. " not found")
	return string.sub(text, start, finish)
end

----------------------------------------------------------------------
-- 1. The files compile; the contract
----------------------------------------------------------------------
do
	for _, path in { CLIENT_PATH, FX_PATH, LOOK_PATH, DIALOGUE_PATH, CINE_PATH, EFFECTS_PATH, MUSIC_PATH, "src/common/ReplicatedStorage/Shared/SuperSonicEvent.luau" } do
		local ok, problem = pcall(luau.compile, fs.readFile(path))
		assert(ok, path .. " does not compile: " .. tostring(problem))
	end
	-- The client reads the contract's names, never its own spellings of them.
	for _, needle in { "SSE.Attributes", "SSE.PlayerAttributes", "SSE.Messages", "SSE.Phases", "SSE.KillAttribute",
		"SSE.RemoteName", "SSE.RemotesFolder", "SSE.AssetsFolder", "SSE.VfxNames" } do
		has(client, needle, "the client uses " .. needle)
	end
	-- (Comments may name them; the code may not.)
	local code = string.gsub(client, "%-%-[^\n]*", "")
	for _, literal in { '"SSE_Phase"', '"SSE_Super"', '"SSE_BossHP"', '"Bomb"', '"BombHit"', '"HomingGo"', '"U4Off_SuperSonicEvent"' } do
		hasNot(code, literal, "no hand-written protocol name " .. literal)
	end
	for _, name in { "Bomb", "BombHit", "Hit", "Reward", "Defeat", "HomingGo", "HomingNo", "Escape", "Knock" } do
		has(client, "name == MSG." .. name .. " then", "the client handles " .. name)
	end
	-- (v2) the rings' messages are handled even with no event running (the rings outlive it).
	local onMessage = body(client, "onMessage")
	for _, name in { "Rings", "RingGone", "RingNo", "RingsClear" } do
		has(onMessage, "first == MSG." .. name .. " then", "the client handles " .. name)
	end
	assert(string.find(onMessage, "first == MSG.Rings then", 1, true) < string.find(onMessage, "if not state.active then", 1, true),
		"before the check for a running event")
	has(client, "remote:FireServer({ MSG.Charge, serverNow() })", "the press is ONE array { \"Charge\", clientTime }")
	has(client, "remote:FireServer({ MSG.Homing, now, charge01 })", "the release is ONE array { \"Homing\", clientTime, charge01 }")
	has(client, "remote:FireServer({ MSG.RingTake, if #ids == 1 then ids[1] else ids })", "ring takes: { \"RingTake\", id or ids }")
	has(client, "#ids < SSE.Rings.MaxIdsPerMessage", "at most MaxIdsPerMessage ids a message")
	has(client, "(found :: RemoteEvent).OnClientEvent:Connect(onMessage)", "the client listens on the remote")
	-- 2026-09-26 (owner, v3): the new messages.
	has(onMessage, "first == MSG.Invite then", "the invite card (before the check for a running event)")
	has(onMessage, "first == MSG.TeleportGo or first == MSG.TeleportNo then", "the trip closes the card")
	has(onMessage, "name == MSG.ShieldHit then", "a bounce off the shield (anyone's)")
	has(client, "remote:FireServer({ MSG.TeleportToEvent, o.eventId })", "YES: { \"TeleportToEvent\", eventId }")
	has(onMessage, "onHomingGo(message[2], message[3], message[4], message[5], message[6], message[9])", "HomingGo's shielded flag (v3)")
	has(onMessage, "Charge.Knock(message[2], message[4])", "Knock's kind (v3)")
	has(onMessage, "startDefeat(message[2], message[3])", "the Defeat's crash point and impact time (v3)")
	has(onMessage, "Rings.OnRings(message[2], message[3], message[4], message[5], message[6], message[7], message[8])", "the rings' burst time (v3)")
	has(client, "if type(message) ~= \"table\" or killed() then", "one array argument per message; nothing while killed")
	pass("the three client files compile and speak the contract (attributes, messages, one-array remote payloads)")
end

----------------------------------------------------------------------
-- 2. SuperSonicEventFx
----------------------------------------------------------------------
do
	-- The owner's three textures, and nothing else may go on an emitter this client makes. 2026-09-26 (owner, v2):
	-- "LE Lightning Globe" is gone.
	local T = Fx.Textures
	assert(T.Lightning == "rbxassetid://12376549723" and T.WindRings == "rbxassetid://116579220922305"
		and T.SpeedTrail == "rbxassetid://110245787189599", "the owner's texture ids")
	assert(T.LightningGlobe == nil and Fx.Flipbooks.LightningGlobe == nil, "no lightning globe texture")
	local textures = 0
	for _, id in T do
		textures += 1
		assert(Fx.AllowedTexture(id), id .. " allowed")
	end
	assert(textures == 3, "three textures (" .. textures .. ")")
	for _, bad in { "", "rbxasset://textures/particles/sparkles_main.dds", "rbxasset://textures/particles/fire_main.dds", "rbxassetid://1",
		"rbxassetid://127860061030425" } do
		assert(not Fx.AllowedTexture(bad), "not allowed: " .. bad)
	end
	-- Tiers: Low (phones under 30 FPS) the cheapest, never more than Mid, never more than High.
	for _, key in { "OwnLights", "OtherSets", "OtherFull", "OtherSparkLimbs", "OwnSparkLimbs", "BlastPool", "FirePatches", "OtherFlights", "DefeatBlasts", "PoseHz", "Beams",
		"SmokeColumns", "AmbientFires", "EmberRate", "Vignette", "FireLights", "RingsVisible", "TrailSegments",
		"CrashPops", "CrashSmoke", "CrashFires", "CrashBlasts" } do
		local low, mid, high = Fx.Budget("Low")[key], Fx.Budget("Mid")[key], Fx.Budget("High")[key]
		assert(low <= mid and mid <= high, key .. ": Low <= Mid <= High")
	end
	for _, tierName in { "Low", "Mid", "High" } do
		local b = Fx.Budget(tierName)
		assert(b.Globe == nil, tierName .. ": no globe in the budget")
		assert(Fx.EmitterSets.BurstHatch["Muzzle" .. b.Muzzle] and Fx.EmitterSets.BombExplode["Muzzle" .. b.Muzzle], tierName .. ": a muzzle set")
		assert(b.BombTrail == "Full" or b.BombTrail == "Beam", tierName .. ": the bomb's trail")
	end
	assert(Fx.Budget("Low").GemGlow == false and Fx.Budget("Low").OtherGemTrail == false and Fx.Budget("Low").WarningClose == false, "Low: no gem glow, no others' gem trails, no closing ring")
	assert(Fx.Budget("Low").OwnLights == 0 and Fx.Budget("Low").OtherSets == 0 and Fx.Budget("Low").OtherFull == 0, "Low: no emerald lights, no others' emeralds, no others' glaze")
	assert(Fx.Budget("High").OwnLights == 7 and Fx.Budget("nonsense").Tier == "Low", "High: the 7 lights; an unknown tier is Low")
	-- EmitCount: Burst_Hatch's SabEmit first, then EmitCount, scaled, at least 1.
	assert(Fx.EmitCount(8, 1, 1) == 8 and Fx.EmitCount(nil, 12, 0.5) == 6 and Fx.EmitCount(nil, nil, 0.1) == 1 and Fx.EmitCount(nil, 1, 0.4) == 1, "EmitCount")
	-- The camera punch of a blast: SSE.Camera.BombHit at the blast, fading with distance, none far away.
	local d0, s0, f0 = Fx.BombPunch(0)
	assert(d0 == SSE.Camera.BombHit.Shake[1] and s0 == SSE.Camera.BombHit.Shake[2] and f0 == SSE.Camera.BombHit.Fov, "the full punch at the blast")
	local _, s1 = Fx.BombPunch(60)
	local _, s2 = Fx.BombPunch(110)
	assert(s1 and s2 and s0 > s1 and s1 > s2, "the punch fades with distance")
	assert(Fx.BombPunch(Fx.Bomb.ShakeRange + 1) == nil and Fx.BombPunch(0 / 0) == nil, "no punch far away")
	-- Sounds: attenuated to nothing at the range.
	assert(Fx.Attenuate(1, 0) == 1 and Fx.Attenuate(1, Fx.SoundRange) == 0, "sound attenuation")
	-- HitPoint: HitRadius short of the centre, on the attacker's side; InRange at 180.
	local boss = Vector3.new(0, 185, 0)
	local from = Vector3.new(60, 100, -80)
	local hit = Fx.HitPoint(boss, from)
	near((hit - boss).Magnitude, SSE.Boss.HitRadius, 1e-4, "HitPoint: HitRadius from the centre")
	assert((hit - from).Magnitude < (boss - from).Magnitude, "HitPoint on the attacker's side")
	assert(Fx.InRange(Vector3.new(0, 185 - 179, 0), boss) and not Fx.InRange(Vector3.new(0, 185 - 181, 0), boss), "lock-on within 180 studs")
	-- FrameAlong: its LookVector runs along the direction (fromMatrix: Lune's lookAt is wrong).
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(0, -1, 0), Vector3.new(0.3, -0.8, -0.5), Vector3.new(0, 1, 0.001) } do
		local cf = Fx.FrameAlong(Vector3.new(5, 6, 7), dir, CFrame)
		nearV(cf.LookVector, dir.Unit, 1e-4, "FrameAlong looks along " .. tostring(dir))
		nearV(cf.Position, Vector3.new(5, 6, 7), 1e-4, "FrameAlong keeps the position")
	end
	pass("Fx: the owner's 4 textures only, tiers Low <= Mid <= High, EmitCount, the blast's punch by distance, HitPoint, lock-on range, FrameAlong")
end

do
	-- The emeralds: they fall from the sky onto SSE.EmeraldOrbit, orbit, then a Bezier into the chest; gone at AbsorbAt.
	local e, f = SSE.Emeralds, Fx.Emerald
	for i = 1, e.Count do
		local top = Fx.EmeraldOffset(i, 0) :: any
		local orbit0 = SSE.EmeraldOrbit(i, 0)
		near(top.Y - orbit0.Y, f.FallHeight, 1e-3, "emerald " .. i .. " starts FallHeight over its orbit")
		for _, t in { f.FallSeconds, 2.0, 3.3, e.AbsorbAt - e.ConvergeSeconds } do
			nearV(Fx.EmeraldOffset(i, t) :: any, SSE.EmeraldOrbit(i, t), 1e-4, "emerald " .. i .. " on SSE.EmeraldOrbit at " .. t)
		end
		local last = Fx.EmeraldOffset(i, e.AbsorbAt - 1e-4) :: any
		nearV(last, Vector3.new(0, f.ChestY, 0), 0.05, "emerald " .. i .. " ends in the chest")
		assert(Fx.EmeraldOffset(i, e.AbsorbAt) == nil and Fx.EmeraldOffset(i, e.AbsorbAt + 1) == nil, "absorbed at AbsorbAt")
		-- Continuous (60 FPS steps never jump more than the fall's own speed allows).
		local prev = Fx.EmeraldOffset(i, 0) :: any
		for step = 1, math.floor(e.AbsorbAt * 60) - 1 do
			local p = Fx.EmeraldOffset(i, step / 60) :: any
			assert((p - prev).Magnitude < 2.2, ("emerald %d jumps %.2f studs at %.2f s"):format(i, (p - prev).Magnitude, step / 60))
			prev = p
		end
		-- The Bezier's middle rises over the straight line in (the curve).
		local mid = Fx.EmeraldOffset(i, e.AbsorbAt - e.ConvergeSeconds / 2) :: any
		local midOrbit = SSE.EmeraldOrbit(i, e.AbsorbAt - e.ConvergeSeconds / 2)
		assert(mid.Y > midOrbit.Y * 0.5 + f.ChestY * 0.5 + 0.5, "the convergence arcs up (a Bezier, not a straight pull)")
	end
	assert(#SSE.Emeralds.Colors == 7 and f.LightRange == 14 and f.LightBrightness == 2.5, "7 colours; PointLights Range 14, Brightness 2.5")
	pass("emeralds: fall from the sky, SSE.EmeraldOrbit (radius 6, sin(t*4)*1.5), a lifted Bezier into the chest, gone at AbsorbAt, continuous")
end

do
	-- Words: en / es / pt, English for the rest; the reward popup; the HP text; refusals; chat lines.
	assert(Fx.RewardText("en", 1000, 50000) == "+1,000 Wins  +50,000 Speed", "the reward popup: " .. Fx.RewardText("en", 1000, 50000))
	assert(Fx.RewardText("es", 1000, 50000) == "+1,000 Victorias  +50,000 Velocidad", "es reward")
	assert(Fx.RewardText("pt", 1000, 50000) == "+1,000 Vitórias  +50,000 Velocidade", "pt reward")
	assert(Fx.FormatNumber(1234567) == "1,234,567" and Fx.FormatNumber(999) == "999" and Fx.FormatNumber(-1000) == "-1,000", "FormatNumber")
	assert(Fx.Word("fr", "Homing") == Fx.Text.en.Homing and Fx.Word("es", "Homing") == "ATAQUE\nTELEDIRIGIDO", "fallback to English; es button")
	for key, value in Fx.Text.en do
		if value ~= "" then
			for _, lang in { "es", "pt" } do
				assert(type(Fx.Text[lang][key]) == "string" and Fx.Text[lang][key] ~= "", lang .. " has " .. key)
			end
		end
	end
	local text, share = Fx.HpText("34", 60)
	assert(text == "34 / 60" and math.abs(share - 34 / 60) < 1e-9, "HP text")
	local zero = Fx.HpText(-3, 0)
	assert(zero == "0 / 1", "HP text clamps")
	for _, reason in SSE.HomingRefusals do
		assert(type(Fx.RefusalWord("en", reason)) == "string", "a word (or nothing) for refusal " .. reason)
	end
	assert(Fx.RefusalWord("en", SSE.HomingRefusals.Cap) == Fx.Text.en.Cap and Fx.RefusalWord("es", "range") ~= "" and Fx.RefusalWord("en", "ground") ~= ""
		and Fx.RefusalWord("pt", "flying") ~= "" and Fx.RefusalWord("en", "nonsense") == "" and Fx.RefusalWord("en", nil) == "", "refusal words")
	for _, key in { "ChatStart", "ChatDefeat", "ChatEscape" } do
		local line = Fx.ChatLine("en", key)
		assert(string.find(line, '<font color="', 1, true) and string.find(line, Fx.Text.en[key], 1, true), key .. " is a coloured system line")
	end
	assert(not string.find(string.match(Fx.ChatLine("es", "ChatStart"), ">(.*)<") or "", "<", 1, true), "chat text escaped")
	for _, phase in SSE.PhaseOrder do
		assert(Fx.PhaseWord("en", phase) ~= "" and Fx.PhaseWord("pt", phase) ~= "", "a banner for " .. phase)
	end
	assert(Fx.PhaseWord("en", "") == "", "no banner for no event")
	-- The Flight ability rule (the world FlightAbility scripts' flightEquipped).
	local now = 1000
	assert(not Fx.FlightEquipped({}, now, true), "no flight")
	assert(not Fx.FlightEquipped({ FlightAbilityOwned = true }, now, true), "owned, not equipped")
	assert(Fx.FlightEquipped({ FlightAbilityOwned = true, FlightAbilityEquipped = true }, now, true), "owned + equipped")
	assert(Fx.FlightEquipped({ FlightAbilityOwned = true, EquippedAbility = "Flight" }, now, true), "owned + EquippedAbility Flight")
	assert(Fx.FlightEquipped({ TemporaryFlightExpireUnix = now + 60 }, now, true), "a temporary flight")
	assert(not Fx.FlightEquipped({ TemporaryFlightExpireUnix = now - 1 }, now, true), "an expired temporary flight")
	assert(not Fx.FlightEquipped({ FlightAbilityOwned = true, FlightAbilityEquipped = true }, now, false), "the ability switched off in Config")
	pass("words: en / es / pt (every key), the reward popup +1,000 Wins +50,000 Speed, HP text, refusals, chat lines, banners, the Flight rule")
end

----------------------------------------------------------------------
-- 3. The imported VFX and the Blender kit
----------------------------------------------------------------------
do
	local files = { BombExplode = "BombExplodeVFX", EggImpact = "EggImpactDefaultVFX", BurstHatch = "BurstHatchVFX" }
	for vfx, file in files do
		local names = {}
		for _, root in roblox.deserializeModel(fs.readFile("assets/vfx_imported/" .. file .. ".rbxm")) do
			for _, d in root:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					names[d.Name] = true
				end
			end
		end
		for set, list in Fx.EmitterSets[vfx] do
			for _, name in list do
				assert(names[name], ("%s set %s: no emitter %q in %s.rbxm"):format(vfx, set, name, file))
				assert(Fx.EmitterAllowed(vfx, name, set), vfx .. " " .. name .. " allowed in " .. set)
			end
		end
		for name in names do
			assert(Fx.EmitterAllowed(vfx, name, "Full") == not Fx.BlockedEmitters[name], vfx .. ": Full fires " .. name)
		end
	end
	assert(Fx.BlockedEmitters.tacopng and not Fx.EmitterAllowed("BurstHatch", "tacopng", "Full"), "Steal a Hero's taco confetti never fires")
	for _, name in { "darkfire", "smoke", "sw", "rock", "Sparks" } do
		assert(Fx.EmitterAllowed("BombExplode", name, "Low"), "the owner's bomb pieces even on Low: " .. name)
	end
	-- The fire patch: a part with its FireParticle emitters (what burnAt turns on for 5 s).
	local fire = roblox.deserializeModel(fs.readFile("assets/vfx_imported/FireTrailParticlesPart.rbxm"))[1]
	assert(fire:IsA("BasePart") and #fire:GetDescendants() > 0, "FireTrail is a part with emitters")
	assert(SSE.Bombard.FirePatchSeconds == 5, "fire patches burn 5 s")
	pass("the imported VFX: every emitter the tiers name exists (BombExplode, EggImpact, BurstHatch); tacopng blocked; the fire patch part")
end

do
	-- The Blender kit's cannon (audit/u4_event_kit): the fallback barrel and the mesh share its mount and
	-- muzzle; the server's bombs leave its spawn point (SSE.Boss.Cannon) at the drawn scale.
	near(Fx.Boss.Scale, SSE.Boss.DrawScale, 1e-9, "the client draws the ship at SSE.Boss.DrawScale")
	near(3.86 * Fx.Boss.Scale, SSE.Boss.HitRadius, 0.6, "the drawn hull meets HitRadius")
	local manifestPath = "design/event/supersonic/event_manifest.json"
	if fs.isFile(manifestPath) then
		local manifest = serde.decode("json", fs.readFile(manifestPath))
		local cannon = manifest.assets.Cannon
		local function v(t)
			return Vector3.new(t[1], t[2], t[3])
		end
		nearV(v(Fx.Boss.CannonMount), v(cannon.mount.hull), 1e-3, "the cannon mount (hull space)")
		nearV(v(Fx.Boss.CannonMuzzle), v(cannon.muzzle.hull), 1e-3, "the cannon muzzle (hull space)")
		nearV(v(SSE.Boss.Cannon), v(cannon.muzzle.spawnHull) * SSE.Boss.DrawScale, 0.01, "SSE.Boss.Cannon = the kit's spawn point x DrawScale")
		assert(manifest.assets.Bomb.noseAxis == Fx.Bomb.NoseAxis, "the bomb flies nose first along its " .. Fx.Bomb.NoseAxis)
		near(manifest.assets.ChaosEmerald.height, Fx.Emerald.Size[2], 1e-6, "the gem keeps its height (scaled uniformly)")
		assert(manifest.assets.SpinBall.rootOffset ~= nil, "the spin ball's RootOffset")
		pass("the Blender kit: the cannon's mount / muzzle, SSE.Boss.Cannon at its spawn point x " .. SSE.Boss.DrawScale .. ", the bomb's nose, the gem's height, the ball's RootOffset")
	else
		pass("the Blender kit: no manifest here (skipped)")
	end
	-- The client uses the kit the way audit/u4_event_kit documents it.
	has(client, 'template:GetAttribute("MountHull")', "the cannon's MountHull")
	has(client, "clone:ScaleTo(s)", "the Cannon model scaled with the ship")
	has(client, "clone:PivotTo(hull.CFrame * CFrame.new(mount * s))", "the Cannon pivoted on its mount (no rotation)")
	has(client, 'template:GetAttribute("RootOffset")', "the spin ball's RootOffset")
	has(client, 'template:GetAttribute("ColorGold")', "the spin ball's gold")
	has(client, 'fitClone(template, e.Size[2], "Height")', "the gem scaled uniformly by its height")
	has(client, 'template:GetAttribute("VariantOrder")', "the gems' own colours in their order")
	has(client, 'fitClone(template, Fx.Bomb.Size, "Largest")', "the bomb fitted to Fx.Bomb.Size")
	hasNot(client, "CannonPitch", "the kit's barrel is already pitched: no extra pitch")
end

----------------------------------------------------------------------
-- 4. The touch HOMING ATTACK button vs the touch controls
----------------------------------------------------------------------
do
	local checked = 0
	local SCREENS = { { 640, 360 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 844, 390 }, { 896, 414 }, { 932, 430 },
		{ 1024, 768 }, { 1180, 820 }, { 1280, 720 }, { 1366, 1024 }, { 2000, 900 }, { 2388, 1668 }, { 2800, 1300 } }
	local function verify(width, height, topBar, layout, burst, label)
		local hudHeight = height - topBar
		local neighbours = H.TouchNeighbours(width, height, false, topBar)
		local plan = H.TouchControls(width, hudHeight, layout, neighbours, burst)
		local avoid = table.clone(neighbours)
		if H.IsCompact(width, height, true, false) then
			local column = H.PhoneColumn(width, height, true, false, 2, topBar)
			for _, r in { column.Pack, column.Badges[1], column.Badges[2] } do
				table.insert(avoid, { Left = r.Left, Top = r.Top - topBar, Right = r.Right, Bottom = r.Bottom - topBar })
			end
		end
		local r = Fx.HomingButtonRect(width, hudHeight, plan, avoid)
		local where = ("%s %dx%d top %d burst %s %s"):format(label, width, height, topBar, tostring(burst), layout or "")
		checked += 1
		assert(r.Size >= Fx.Button.Min and r.Size <= Fx.Button.Max, where .. ": a large button")
		assert(r.Left >= 0 and r.Top >= 0 and r.Right <= width and r.Bottom <= hudHeight, where .. ": on screen")
		-- Never on the jump button (a thumb's width away), never in the thumbstick area.
		assert(not H.Overlaps(r, H.JumpButton(width, hudHeight), Fx.Button.JumpMargin - 0.5), where .. ": clear of the jump button")
		assert(not H.Overlaps(r, H.Thumbstick(width, hudHeight), Fx.Button.StickMargin - 0.5), where .. ": clear of the thumbstick")
		for _, key in { "S", "B", "H" } do
			if plan[key] and (key ~= "B" or burst) then
				assert(not H.Overlaps(r, plan[key], Fx.Button.PieceMargin - 0.5), where .. ": clear of " .. key)
			end
		end
		for index, other in avoid do
			assert(not H.Overlaps(r, other, (other.Clearance or 6) - 0.5), where .. ": clear of the phone column piece " .. index)
		end
		return r
	end
	for _, topBar in { 0, 36, 58 } do
		for _, s in SCREENS do
			for _, burst in { false, true } do
				local r = verify(s[1], s[2], topBar, "", burst, "auto")
				-- In the right thumb's reach on landscape phones.
				if s[1] <= 1000 then
					assert(r.X >= s[1] / 2, ("auto %dx%d: the button in the right half (x %.0f)"):format(s[1], s[2], r.X))
				end
			end
		end
		for width = 640, 2800, 80 do
			for height = 360, 1700, 60 do
				if width >= height then
					verify(width, height, topBar, "", true, "sweep")
				end
			end
		end
	end
	-- The player's own layouts: Swap side, and random saved places.
	math.randomseed(20260926)
	for _, s in SCREENS do
		for _, topBar in { 36, 58 } do
			local width, hudHeight = s[1], s[2] - topBar
			verify(s[1], s[2], topBar, H.FormatTouchLayout(H.LeftPreset(width, hudHeight)), true, "swap side")
			for _ = 1, 60 do
				local wish = {}
				for _, key in H.TouchPieces do
					if math.random() < 0.6 then
						wish[key] = { X = math.random(), Y = math.random() }
					end
				end
				verify(s[1], s[2], topBar, H.FormatTouchLayout(wish), math.random() < 0.5, "random")
			end
		end
	end
	-- The client places it the same way, only on touch, only while airborne and locked on.
	local layout = body(client, "layoutButton")
	for _, needle in { "HudErgonomics.TouchNeighbours(", "HudErgonomics.TouchControls(", "HudErgonomics.PhoneColumn(", "Fx.HomingButtonRect(", 'player:GetAttribute("TouchLayout")' } do
		has(layout, needle, "layoutButton uses " .. needle)
	end
	local hudBody = body(client, "updateHud")
	has(hudBody, "local show = touch and (locked or Charge.Active()) and not hud.menuOpen and Cinema.active == nil",
		"the button shows on touch, locked on (or held in a charge), no menu of the game open, no cinematic")
	has(client, 'Fx.Word(lang, "Homing")', "its localized label")
	pass(("the HOMING ATTACK button: %d screens / layouts, always clear of the jump button (24 px), the thumbstick, Sprint / Burst / Heat Vision and the phone column"):format(checked))
end

----------------------------------------------------------------------
-- 5. SuperSonicLook on the owner's R6 Eggman wearing an aura and a trail
----------------------------------------------------------------------
local ENV = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Vector2 = roblox.Vector2,
}
local GOLD = Color3.fromRGB(Fx.Gold[1], Fx.Gold[2], Fx.Gold[3])
local RUBY = Color3.fromRGB(Fx.Ruby[1], Fx.Ruby[2], Fx.Ruby[3])

-- Lune has no events: the property watchers are recorded and fired by hand.
local watchers = {}
Look._watch = function(instance, property, callback)
	local entry = { instance = instance, property = property, callback = callback, connected = true }
	table.insert(watchers, entry)
	return { Disconnect = function()
		entry.connected = false
	end }
end
local function fire(instance, property)
	for _, entry in watchers do
		if entry.connected and entry.instance == instance and entry.property == property then
			entry.callback()
		end
	end
end

local function makeCharacter()
	local roots = roblox.deserializeModel(fs.readFile("design/npc/LobbyCharacters.rbxm"))
	local folder = roots[1]
	local source = folder:FindFirstChild("Eggman")
	assert(source and source:FindFirstChild("Head") and source:FindFirstChild("Torso"), "design/npc/LobbyCharacters.rbxm: the R6 Eggman")
	local character = source:Clone()
	character.Name = "PlayerCharacter"
	-- The equipped aura and trail, as Economy/Cosmetics/CosmeticService attaches them.
	local cosmetics = Instance.new("Folder")
	cosmetics.Name = Look.CosmeticsFolder
	local aura = Instance.new("Model")
	aura.Name = "EquippedAura"
	local holder = Instance.new("Part")
	holder.Name = "EffectHolder"
	holder.Transparency = 1
	holder.Parent = aura
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AuraFlame"
	emitter.Enabled = true
	emitter.Rate = 24
	emitter.Parent = attachment
	local limb = Instance.new("MeshPart")
	limb.Name = "AuraArmGlow"
	limb:SetAttribute("TargetLimb", "Right Arm")
	limb.Color = Color3.fromRGB(10, 200, 255)
	limb.Transparency = 0.2
	limb.Parent = aura
	aura.Parent = cosmetics
	local trail = Instance.new("Model")
	trail.Name = "EquippedTrail"
	local trailHolder = Instance.new("Part")
	trailHolder.Name = "EffectHolder"
	trailHolder.Transparency = 1
	trailHolder.Parent = trail
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = trailHolder, trailHolder
	local trailFx = Instance.new("Trail")
	trailFx.Attachment0, trailFx.Attachment1 = a0, a1
	trailFx.Enabled = true
	trailFx.Parent = trailHolder
	trail.Parent = cosmetics
	cosmetics.Parent = character
	-- (Lune: a deserialized part has no LocalTransparencyModifier until one is set; Roblox's start at 0.)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	return character, cosmetics
end

local PROPS = {
	BasePart = { "Color", "Transparency", "LocalTransparencyModifier", "Material", "Size", "CFrame", "Anchored", "CanCollide", "Reflectance" },
	Decal = { "Transparency", "LocalTransparencyModifier", "Color3" },
	ParticleEmitter = { "Enabled", "Rate", "LockedToPart" },
	Trail = { "Enabled" },
	Clothing = { "Color3" },
	BodyColors = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" },
	Attachment = { "CFrame" },
	SpecialMesh = { "Scale", "Offset" },
}
-- Every descendant of `root` and its properties, as text.
local function snapshot(root)
	local out = {}
	for _, d in root:GetDescendants() do
		local line = { d.ClassName, d.Name, d.Parent and d.Parent.Name or "" }
		for class, props in PROPS do
			if d:IsA(class) then
				for _, prop in props do
					local ok, value = pcall(function()
						return d[prop]
					end)
					table.insert(line, prop .. "=" .. (if ok then tostring(value) else "?"))
				end
			end
		end
		out[d] = table.concat(line, " ")
	end
	return out
end
local function sameSnapshot(before, after, label, except)
	for instance, text in before do
		if not (except and except[instance]) then
			assert(after[instance] == text, label .. ": changed: " .. text .. "  ->  " .. tostring(after[instance]))
		end
	end
	for instance, text in after do
		assert(before[instance] ~= nil, label .. ": something was added and left: " .. text)
	end
end
local function added(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #Look.Prefix) == Look.Prefix then
			table.insert(out, d)
		end
	end
	return out
end

do
	local character, cosmetics = makeCharacter()
	local before = snapshot(character)
	local cosmeticsBefore = snapshot(cosmetics)
	local body = Look.BodyParts(character)
	local handles = Look.AccessoryHandles(character)
	assert(#body == 6, "R6: 6 body parts (" .. #body .. ")")
	assert(#handles == 5, "the Eggman's 5 accessories (" .. #handles .. ")")
	local handle = Look.Apply(ENV, character, {
		Gold = GOLD, Ruby = RUBY, Shells = true, AccessoryShells = true, Eyes = true, SparkLimbs = 4, SparkRate = 6,
		Texture = Fx.Textures.Lightning, Flipbook = Fx.Flipbooks.Lightning,
	})
	-- The gold body.
	for _, part in body do
		assert(part.Color == GOLD, part.Name .. " is gold")
	end
	-- What it added: a glaze per body part and accessory, two ruby eyes, 4 lightning flipbook emitters.
	local shells, eyes, sparks = 0, 0, 0
	for _, d in added(character) do
		assert(not d:IsDescendantOf(cosmetics), "nothing added inside the equipped aura / trail: " .. d:GetFullName())
		if d.Name == Look.Prefix .. "Shell" then
			shells += 1
			assert(d.Material == roblox.Enum.Material.Neon and d.Color == GOLD and d.Transparency > 0 and d.Transparency < 1, "a half-transparent Neon gold glaze")
			assert(not d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch and d.Massless, "the glaze is inert and massless")
		elseif d.Name == Look.Prefix .. "Eye" then
			eyes += 1
			assert(d.Color == RUBY and d.Material == roblox.Enum.Material.Neon, "a ruby-red eye")
		elseif d:IsA("ParticleEmitter") then
			sparks += 1
			assert(d.Texture == Fx.Textures.Lightning, "the sparks are the owner's lightning flipbook")
			assert(d.FlipbookLayout.Name == Fx.Flipbooks.Lightning.Layout, "the flipbook grid")
			assert(d.Parent:IsA("Attachment") and d.Parent.Parent and table.find(body, d.Parent.Parent), "the sparks come from a limb")
		end
	end
	assert(shells == #body + #handles and eyes == 2 and sparks == 4, ("glaze %d, eyes %d, sparks %d"):format(shells, eyes, sparks))
	-- No aura was added and the equipped one is untouched.
	sameSnapshot(cosmeticsBefore, snapshot(cosmetics), "the aura / trail while Super")
	-- The server changes the torso's colour mid-form (a skin, the appearance loading late): gold again, and
	-- that colour is the one put back.
	local torso = character:FindFirstChild("Torso")
	local serverColour = Color3.fromRGB(12, 34, 56)
	torso.Color = serverColour
	fire(torso, "Color")
	assert(torso.Color == GOLD, "the gold goes back on")
	-- The spin ball: the whole body hidden (glaze, eyes, face, accessories), the aura and trail NOT.
	local pieces = Look.HidePieces(character)
	for _, piece in pieces do
		assert(not piece:IsDescendantOf(cosmetics), "the ball never hides the aura / trail: " .. piece:GetFullName())
	end
	local saved = {}
	Look.Hide(pieces, saved, true)
	Look.Hide(pieces, saved, true) -- every frame of the flight: the first value stays the kept one
	for _, piece in pieces do
		assert(piece.LocalTransparencyModifier == 1, piece:GetFullName() .. " hidden")
	end
	local face = character:FindFirstChild("Head"):FindFirstChildWhichIsA("Decal")
	assert(face and table.find(pieces, face), "the face hides too")
	Look.SetSparks(handle, false)
	for _, d in added(character) do
		if d:IsA("ParticleEmitter") then
			assert(not d.Enabled, "the sparks pause under the ball")
		end
	end
	sameSnapshot(cosmeticsBefore, snapshot(cosmetics), "the aura / trail under the ball")
	Look.Hide(pieces, saved, false)
	Look.SetSparks(handle, true)
	for _, piece in pieces do
		assert(piece.LocalTransparencyModifier == 0, piece:GetFullName() .. " shown again")
	end
	-- The end of the form: everything back exactly (the torso with the server's latest colour), nothing left.
	Look.Remove(handle)
	Look.Remove(handle) -- twice is harmless
	assert(#added(character) == 0, "nothing of the form left")
	sameSnapshot(before, snapshot(character), "after Remove", { [torso] = true })
	assert(torso.Color == serverColour, "the torso keeps the colour the server gave it meanwhile")
	for _, entry in watchers do
		assert(not entry.connected, "every watcher disconnected")
	end
	fire(torso, "Color")
	assert(torso.Color == serverColour, "a late change after the end is left alone")
	sameSnapshot(cosmeticsBefore, snapshot(cosmetics), "the aura / trail after Remove")
	pass("SuperSonicLook (Own): gold body, Neon glaze on 6 body parts + 5 accessories, 2 ruby eyes, 4 lightning flipbook sparks; the aura and trail never touched; the ball hides and shows exactly; Remove restores everything (the server's latest colour) and leaves nothing")
end

do
	-- The cheap level (far players / Low phones): the gold body and the eyes only.
	table.clear(watchers)
	local character, cosmetics = makeCharacter()
	local before = snapshot(character)
	local handle = Look.Apply(ENV, character, { Gold = GOLD, Ruby = RUBY, Shells = false, AccessoryShells = false, Eyes = true, SparkLimbs = 0, Texture = Fx.Textures.Lightning })
	local eyes, others = 0, 0
	for _, d in added(character) do
		if d.Name == Look.Prefix .. "Eye" then
			eyes += 1
		elseif d:IsA("BasePart") or d:IsA("Attachment") then
			others += 1
		end
	end
	assert(eyes == 2 and others == 0, ("Lite: 2 eyes only (%d eyes, %d other pieces)"):format(eyes, others))
	for _, d in character:GetDescendants() do
		assert(not d:IsA("ParticleEmitter") or d:IsDescendantOf(cosmetics), "Lite: no emitter")
	end
	Look.Remove(handle)
	sameSnapshot(before, snapshot(character), "Lite after Remove")
	-- No texture, no sparks (never Roblox's default sparkles).
	local handle2 = Look.Apply(ENV, character, { Gold = GOLD, Ruby = RUBY, SparkLimbs = 4, Texture = "" })
	for _, d in added(character) do
		assert(not d:IsA("ParticleEmitter"), "no texture: no emitter at all")
	end
	Look.Remove(handle2)
	sameSnapshot(before, snapshot(character), "no-texture after Remove")
	pass("SuperSonicLook (Lite): the gold body and the eyes only, restored exactly; without the lightning texture it makes no emitter at all")
end

----------------------------------------------------------------------
-- 6. The client, read as text
----------------------------------------------------------------------
do
	-- Particles: one factory, the owner's textures only; no default texture anywhere.
	for label, source in { client = client, fx = fxSource, look = lookSource } do
		for _, bad in { "sparkles_main", "rbxasset://textures/particles", "Sparkles\")" } do
			hasNot(source, bad, label .. ": no default particle texture (" .. bad .. ")")
		end
		hasNot(source, 'Instance.new("Highlight")', label .. ": no Highlight")
		hasNot(source, 'Instance.new("Fire")', label .. ": no legacy Fire")
	end
	assert(count(client, 'Instance.new("ParticleEmitter")') == 1, "the client makes emitters in ONE place")
	local factory = body(client, "newEmitter")
	has(factory, 'Instance.new("ParticleEmitter")', "that place is newEmitter")
	has(factory, "assert(Fx.AllowedTexture(texture)", "it refuses any texture that is not the owner's")
	has(factory, "emitter.Texture = texture", "and sets it")
	assert(count(lookSource, 'Instance.new("ParticleEmitter")') == 1, "the look makes emitters in one place")
	has(body(lookSource, "makeSparks"), "emitter.Texture = options.Texture", "the look's emitter takes the lightning texture")
	has(lookSource, 'type(options.Texture) == "string" and options.Texture ~= ""', "no texture, no sparks")
	has(client, "Texture = Fx.Textures.Lightning,", "the client gives the look the lightning flipbook")
	-- Lights: PointLights only on the emeralds and (v2) the fire patches' warm glow (2026-09-26, owner: none on
	-- the boss), and the clone's go.
	assert(count(client, 'Instance.new("PointLight")') == 1, "one PointLight factory")
	has(body(client, "newLight"), 'Instance.new("PointLight")', "the factory is newLight")
	assert(count(client, "newLight(") == 3, "newLight: defined once, used by the gems and the fire patches only")
	has(body(client, "makeGem"), "newLight(gemRoot, e.LightRange, e.LightBrightness, GOLD)", "the gems' lights: Range 14")
	has(body(client, "prewarmFires"), "if lights < budget.FireLights then", "the fire lights within the tier's count")
	for _, class in { "Highlight", "PointLight", "SpotLight", "SurfaceLight", "Script", "ProximityPrompt", "BillboardGui" } do
		assert(table.find(Fx.StripClasses, class), "the boss clone strips " .. class)
	end
	has(body(client, "buildBossFromLobby"), 'd:GetAttribute("EggCollider") == true', "the clone's colliders go")
	has(body(client, "buildBossFromLobby"), "removeTags(d)", "the clone loses the lobby tags (the lobby clients never adopt it)")
	has(body(client, "buildBossFromLobby"), "d.CanCollide = false", "the boss never collides with anyone")
	-- Auras and trails: never named by the client (SuperSonicLook keeps out of SpeedsterCosmetics).
	for _, name in { "SpeedsterCosmetics", "EquippedAura", "EquippedTrail", "EquippedAuraId" } do
		hasNot(client, name, "the client never touches " .. name)
	end
	has(lookSource, 'Look.CosmeticsFolder = "SpeedsterCosmetics"', "the look knows the cosmetics folder")
	pass("particles: one factory, the owner's textures only, never the default sparkles; PointLights only on the emeralds; the boss clone stripped of highlights, lights, prompts, tags and colliders; auras / trails never named")
end

do
	-- Inputs.
	assert(#Fx.Inputs.Keys == 1 and Fx.Inputs.Keys[1] == "F", "PC: F")
	assert(#Fx.Inputs.Gamepad == 1 and Fx.Inputs.Gamepad[1] == "ButtonX", "gamepad: X (A jumps / flies, Y is Heat Vision, B closes menus)")
	assert(Fx.Inputs.Mouse == true and Fx.Inputs.JumpInAir == true, "Left Click; (v3) a jump press in the air")
	local sync = body(client, "syncInputBinding")
	has(sync, "ContextActionService:BindActionAtPriority(Fx.Inputs.Action, onHomingAction, false, Fx.Inputs.Priority, table.unpack(keys))", "F / X bound through ContextActionService")
	has(sync, "ContextActionService:UnbindAction(Fx.Inputs.Action)", "and unbound outside the Battle")
	has(body(client, "battleReady"), "state.phase == PHASE.Battle and player:GetAttribute(PATTR.Super) == true and not killed()", "bound only in the Battle, while Super, not killed")
	has(body(client, "onHomingAction"), "return Enum.ContextActionResult.Pass", "F passes through when nothing happens")
	has(client, "input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed", "a click on the interface is not a homing attack")
	-- 2026-09-26 (owner, v3): jump, then jump again in the air (Space / gamepad A / the touch jump button: the
	-- engine's JumpRequest) = the instant attack; the Flight keeps its jump only where the event does not ground it.
	has(client, "UserInputService.JumpRequest:Connect(function()", "the mid-air jump press (every device)")
	has(client, "local press = Fx.JumpPress(clock, lastJumpRequest)", "a new press, not a held key's stream")
	has(client, "if flightEquipped() and not eventFlightOff() then", "the Flight's own jump outside the event")
	has(client, 'Charge.Instant("Jump")', "the instant, uncharged attack")
	has(body(client, "Charge.Instant"), "return launch(source, 0, nil, nil)", "charge 0, no Charge message before it")
	hasNot(client, 'Charge.Begin("Space"', "no more Space hold charge")
	has(body(client, "flightEquipped"), "Fx.FlightEquipped(", "the Flight rule")
	-- The world FlightAbility scripts lift off when Space is held in the air (0.18 s after the jump): that is
	-- why Space stays theirs for a player with the Flight equipped.
	for _, world in { "World1", "World2", "World3" } do
		local flight = fs.readFile(("src/worlds/%s/StarterPlayer/StarterPlayerScripts/Movement/%sFlightAbility.client.luau"):format(world, world))
		has(flight, "and os.clock() - lastJumpAt >= AIRBORNE_HOLD_SECONDS", world .. ": Space held in the air lifts off")
		has(flight, 'player:GetAttribute("FlightAbilityEquipped") == true or player:GetAttribute("EquippedAbility") == "Flight" or hasTemporaryFlight()', world .. ": the rule Fx.FlightEquipped mirrors")
	end
	has(body(client, "airborne"), "humanoid.FloorMaterial ~= Enum.Material.Air", "airborne = off the floor")
	has(body(client, "canHoming"), "SSE.CheckHoming({", "the client pre-checks with the server's own rule")
	has(client, 'Charge.Begin("Touch", input)', "the touch button: held to charge")
	has(client, 'Charge.Release("Touch")', "and released to launch")
	-- 2026-09-26 (owner, v2): every input is held to charge and released to launch.
	local action = body(client, "onHomingAction")
	has(action, 'Charge.Begin("Action", input)', "F / X pressed: the charge begins")
	has(action, "inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel", "F / X released")
	has(action, 'Charge.Release("Action")', "the release launches")
	has(client, 'Charge.Begin("Mouse", input)', "Left Click held")
	has(client, 'Charge.Release("Mouse")', "Left Click released")
	has(client, 'Charge.Release("Touch", input)', "a finger sliding off the button still lets go")
	has(body(client, "Charge.Update"), "if held >= c.seconds then", "the charge's end releases it (auto)")
	has(body(client, "Charge.Begin"), "Fx.ChargeSeconds(SSE.Homing.ChargeSeconds, soundLength(\"ChargeStart\"))", "the charge's length: the contract's, else the sound's")
	has(body(client, "Charge.Begin"), 'playSound("ChargeStart")', "the charge sound plays while held")
	has(body(client, "Charge.Update"), "Screen.ChargeRing(level", "the ring fills")
	has(body(client, "Charge.Update"), "chargeBall(ball, level, clock)", "the ball spins up, the one trail wrapping it")
	has(body(client, "Charge.Knock"), "Charge.Cancel()", "a throw cancels the charge")
	has(body(client, "syncInputBinding"), "Charge.Cancel()", "unbinding cancels a charge")
	pass("inputs: F / gamepad X (ContextActionService, only in the Battle while Super), Left Click (not on the interface), the touch button, all held to charge; (v3) a mid-air jump press (JumpRequest) = the instant attack")
end

do
	-- The kill switch, cleanup, respawn.
	has(client, "for _, name in { ATTR.Phase, ATTR.PhaseStart, ATTR.EventId, ATTR.Origin, ATTR.EventStart, ATTR.Seed, ATTR.LiftOff, SSE.KillAttribute } do",
		"the kill switch (and the plan's attributes) are watched live")
	has(client, "return not SSE.IsOn()", "killed() is the contract's IsOn")
	local changed = body(client, "onPhaseChanged")
	has(changed, "local phase = SSE.NormalizePhase(Workspace:GetAttribute(ATTR.Phase))", "v1's \"Intro\" reads as the Cinematic")
	has(changed, "if not SSE.IsPhase(phase) or killed() then", "killed: as if no event")
	has(changed, "if phase == \"\" then", "phase \"\"...")
	has(changed, "endEvent()", "...ends everything")
	has(changed, "refreshPlan()", "the boss path's plan follows the attributes")
	has(changed, "if state.active and state.eventId ~= nil and eventId ~= state.eventId then", "only a different event id restarts")
	local ending = body(client, "endEvent")
	for _, call in { 'Cinema.Stop("end")', "destroyFlights()", "destroyBombs()", "destroyEmeralds()", "Rings.Destroy()", "Chaos.Finish(instant)", "destroyRigs()",
		"destroyFires()", "removeAllLooks()", "destroyBoss()", "Screen.Destroy()", "Music.Stop(instant)", "restoreLobby(", "destroyHud()", "destroySounds()",
		"syncInputBinding()", "retire(runtime, instant)",
		-- 2026-09-26 (owner, v3)
		"Freeze.Release()", "HudHide.Release()", "Invite.Hide()", "Beat.Reset()", "ArenaHide.Restore()", "player:SetAttribute(Fx.ChaosZoneAttribute, nil)" } do
		has(ending, call, "endEvent: " .. call)
	end
	has(ending, "steppedConnection:Disconnect()", "the frame loops stop")
	has(ending, "renderConnection:Disconnect()", "the frame loops stop")
	has(body(client, "refreshLook"), "and not killed()", "no Super look while killed")
	has(client, "target.CharacterAdded:Connect(function()", "respawns")
	has(client, "target.CharacterRemoving:Connect(function()", "and characters leaving")
	has(client, "task.defer(refreshLook, target)", "the new body gets the look")
	local flightEnd = body(client, "endFlight")
	for _, needle in { "Look.Hide(f.pieces, f.saved, false)", "f.humanoid.PlatformStand = f.platformStand", "f.character:SetAttribute(DASH_ATTRIBUTE, nil)", "showBall(ownBall, false" } do
		has(flightEnd, needle, "endFlight restores: " .. needle)
	end
	has(body(client, "stepFlight"), "endFlight(nil)", "a flight ends on death / ragdoll / kill / phase end / timeout")
	has(body(client, "stepFlight"), "killed()", "the kill switch ends a flight")
	has(body(client, "putBack"), "LocalTransparencyModifier = value", "the lobby Eggman comes back exactly")
	has(body(client, "restoreLobby"), "LocalTransparencyModifier = 1 + (value - 1) * e", "(v2) fading back in to each piece's own value")
	has(body(client, "stopFade"), "putBack(f.transparency, f.enabled)", "a fade cut short puts every piece exactly back")
	pass("the kill switch (live), cleanup on phase \"\" (everything destroyed, the lobby NPC back, inputs unbound), respawns, the flight's exact restore")
end

do
	-- Pools, and nothing built in the per-frame functions.
	for _, name in { "prewarmRigs", "acquireRig", "prewarmFires", "acquireFire", "prewarmSounds", "releaseBomb", "acquireGem", "releaseGem", "finishOther" } do
		body(client, name)
	end
	for _, pool in { "rigPools", "firePool", "bombPool", "zonePool", "ringPool", "gemPool", "otherBallPool", "soundRings" } do
		has(client, pool, "pool: " .. pool)
	end
	local HOT = { "onStepped", "onRender", "updateBoss", "bossFrame", "applyPose", "pulseBoss", "updateFlash", "updateDefeat", "startFlee",
		"updateBombs", "explode", "releaseBomb", "updateEmeralds", "absorb", "releaseSet", "releaseGem", "updateBall", "placeBall",
		"updateOtherFlights", "finishOther", "updateFires", "burnAt", "acquireFire", "fireRig", "acquireRig", "updateHud", "layoutButton",
		"stepFlight", "arrive", "endFlight", "showBall", "playSound", "taunt", "bossHit", "goldenFlash",
		-- 2026-09-26 (owner, v2)
		"updateCannonAndShield", "fadeModel", "fleeFade", "updateZone", "releaseZone", "chargeBall", "Charge.Update", "Screen.Update",
		"Screen.Vignette", "Screen.ChargeRing", "Screen.SetBars", "Chaos.Update", "applyGrade", "setRates", "Rings.Update", "setAlpha",
		"collect", "Cinema.Step", "updateCues", "updateBossState", "bossGesture", "cannonShot", "muzzleFrame",
		-- 2026-09-26 (owner, v3)
		"updateBurn", "wrapTrail", "updateDefeat", "Beat.Update", "Freeze.Update", "HudHide.Update", "hitFlash", "Screen.SetFade" }
	for _, name in HOT do
		local text = string.gsub(body(client, name), "%-%-[^\n]*", "")
		for _, bad in { "Instance.new", ":Clone(", "prewarm", "buildRig", "makeBombVisual", "makeRing", "makeGem", "makeBallRig", "buildBoss", "Look.Apply", "fitClone", "ensureBoss" } do
			hasNot(text, bad, name .. " (per frame) builds nothing: " .. bad)
		end
	end
	-- The builders run from the handlers and the sweep thread.
	has(body(client, "onBomb"), 'prewarmRigs("Blast", inAir)', "a bomb's blast is ready before it lands")
	has(body(client, "startDefeat"), 'prewarmRigs("Blast", count)', "the defeat's chain")
	has(body(client, "launch"), 'prewarmRigs("Hit", 2)', "the arrival's burst")
	has(body(client, "Charge.Begin"), 'prewarmRigs("Hit", 2)', "(and at the press)")
	has(body(client, "Chaos.Prewarm"), 'Instance.new("ColorCorrectionEffect")', "the grade is made by the prewarm, never per frame")
	has(body(client, "makeSet"), 'prewarmRigs("Burst", sets)', "the absorption's burst")
	has(client, "task.spawn(function()\n\t\t\twhile state.active and serial == sweepSerial do", "the sweep (boss, looks, emerald sets) runs on its own thread")
	hasNot(body(client, "onRender"), "sweep()", "never in the frame callback")
	pass("pools for rigs, fire patches, bombs, rings, gems, balls and sounds; the per-frame functions build nothing (the handlers and the sweep thread do)")
end

do
	-- The boss, the bombs, the camera, the flight.
	has(client, "SSE.BossCFrame(state.origin, now, state.plan)", "the boss flies the contract's plan (the lift-off, the fight, the flight away)")
	has(body(client, "refreshPlan"), "SSE.PlanFromAttributes(function(name: string): any", "the plan from the attributes")
	has(client, "LobbyNpcPose.Sample(EggMobile.PoseKind, now, boss.poseOut, reactionName, reactionAge, boss.aim)", "Eggman's EggmanDriving pose with his reactions")
	assert(require("../src/common/ReplicatedStorage/Shared/EggMobile").PoseKind == "EggmanDriving", "the pose is EggmanDriving")
	has(client, 'taunt("Laugh")', "a taunt")
	has(body(client, "hideLobby"), "LocalTransparencyModifier = 1", "the lobby NPC hidden locally")
	has(client, "Fx.BombPosition(bomb.from, bomb.to, s, bomb.flight, bomb.dir, bomb.depth)", "bombs leave the barrel, then fly SSE.BombArc")
	has(body(client, "explode"), "Fx.BombPunch(", "the bomb's punch by distance")
	has(body(client, "explode"), "burnAt(position, budget.FirePatches)", "the fire patch")
	has(body(client, "explode"), 'fireRig("Blast"', "BombExplode + EggImpact")
	has(body(client, "arrive"), "SSE.Camera.HomingHit", "the homing hit's punch from the contract")
	has(body(client, "arrive"), "f.bounce = SSE.HomingBounce(look, c)", "the bounce: (0, 55 + 30c, 0) - look * (25 + 25c)")
	has(body(client, "stepFlight"), "endFlight(f.bounce, true)", "(v3) after the hit-stop")
	has(body(client, "arrive"), "f.stageUntil = os.clock() + Fx.Homing.HitStop", "(v3) the hit-stop")
	has(body(client, "arrive"), "hitFlash()", "(v3) the white hit flash")
	has(body(client, "playHitSound"), 'playSound("HomingHit")', "the owner's \"hit!\"")
	-- "hit!" only on a damaging connection: the arrival once the server accepted it (not shielded), a late
	-- acceptance within the grace, the server's own Hit; nothing else plays it.
	assert(count(client, 'playSound("HomingHit"') == 2, "\"hit!\" in two places: this client's own hit and another player's Hit")
	has(body(client, "arrive"), "if f.accepted then\n\t\t\tplayHitSound()", "at the arrival when accepted")
	has(body(client, "Charge.Accepted"), "if waiting and shielded ~= true and os.clock() <= waiting.untilClock then", "a late acceptance within the grace")
	has(body(client, "onHit"), "Charge.ServerHit()", "or the server's Hit")
	has(body(client, "onHit"), "if (tonumber(damage) or 1) <= 0 then", "never for a hit that did no damage")
	has(body(client, "shieldBounce"), "SSE.ShieldKnock(f.root.Position, planPosition(serverNow()))", "(v3) off the shield: the contract's knock-back")
	has(body(client, "arrive"), "fireRig(\"Hit\", CFrame.new(f.to), Fx.ChargeScale(c, Fx.Charge.Impact))", "the bigger the charge, the bigger the burst")
	has(body(client, "arrive"), "bossHit(f.from, c)", "his recoil as big as the charge")
	has(body(client, "arrive"), "shielded = f.serverShielded == true", "the server's verdict when it came")
	has(body(client, "arrive"), "shieldBounce(f, nil)", "off his shield when he is not reloading")
	has(body(client, "launch"), "SSE.HomingIntercept(from, state.origin, now, state.plan)", "the flight goes where the ship will be")
	has(body(client, "startDefeat"), "SSE.Camera.Defeat", "the defeat's punch from the contract")
	has(body(client, "stepFlight"), "SSE.HomingPath(f.from, to, s)", "the flight follows HomingPath")
	has(body(client, "stepFlight"), "f.root.CFrame = Fx.FrameAlong(pos, f.dir)", "the root is moved kinematically (a CFrame every frame)")
	has(body(client, "stepFlight"), "f.root.AssemblyLinearVelocity = f.dir * SSE.Homing.Speed", "at 180 studs/s")
	has(body(client, "takeBody"), "f.humanoid.PlatformStand = true", "no humanoid tumble while flying")
	has(body(client, "takeBody"), "f.character:SetAttribute(DASH_ATTRIBUTE, true)", "InstantMovementController stands aside")
	has(fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau"),
		'character:GetAttribute("SonicBurstDashLocal") == true', "InstantMovementController honours SonicBurstDashLocal")
	has(body(client, "placeBall"), "CFrame.Angles(spin, 0, 0)", "the ball spins CFrame.Angles(spin, 0, 0)")
	hasNot(client, "LightningGlobe", "(v2) no lightning globe")
	has(client, 'newEmitter("WindRings")', "the wind rings")
	has(client, "trail.Texture = Fx.Textures.SpeedTrail", "the speed-trail Beam (v3: one, wrapping the ball)")
	has(body(client, "Charge.Knock"), "part.AssemblyLinearVelocity = velocity", "Knock: the victim's own client throws it")
	has(body(client, "onHomingGo"), "if userId == player.UserId", "the requester's own flight is not drawn twice")
	has(body(client, "onHit"), "os.clock() - lastLocalImpact < 0.8", "nor its own hit")
	has(client, 'announce("ChatStart")', "the chat's start line")
	has(client, 'announce("ChatDefeat")', "defeat line")
	has(client, 'announce("ChatEscape")', "escape line")
	has(body(client, "announce"), "general:DisplaySystemMessage(Fx.ChatLine(lang, key))", "posted by the client (DisplaySystemMessage is client-only)")
	has(body(client, "announce"), "pcall(function()", "in a pcall")
	has(client, "showReward(message[2], message[3])", "the reward popup")
	pass("the boss (BossCFrame, EggmanDriving + taunts, the lobby NPC hidden), bombs (BombArc, blast, fire, punch), the kinematic flight (HomingPath, 180 studs/s, PlatformStand, the bounce), Knock, HomingGo / Hit, chat lines, rewards")
end

----------------------------------------------------------------------
-- 8. (v2) The lightning globe is gone everywhere; the owner's sounds; the sound conventions
----------------------------------------------------------------------
local function walkSources(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walkSources(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

do
	local files = walkSources("src", {})
	assert(#files > 100, "the sources are there (" .. #files .. ")")
	for _, path in files do
		local text = fs.readFile(path)
		assert(not string.find(text, "127860061030425", 1, true), path .. ": the \"LE Lightning Globe\" texture is used")
	end
	-- 2026-09-26 (owner): his uploads, each where he asked; the explosion he likes kept.
	local S = Fx.Sounds
	local want = {
		Burn = "rbxassetid://97328578838913", VoiceCatch = "rbxassetid://85365485919704", HomingHit = "rbxassetid://134196260572617",
		VoiceParallel = "rbxassetid://82583368227347", ChargeStart = "rbxassetid://93126470207724", VoiceShielded = "rbxassetid://107740886981758",
		RingCollect = "rbxassetid://112771432761858", RingSpill = "rbxassetid://102136054782395", VoiceBeBack = "rbxassetid://103892608635163",
		BombBlast = "rbxassetid://3149249837",
	}
	for kind, id in want do
		assert(S[kind] and S[kind].Id == id, "sound " .. kind .. " = " .. id .. " (" .. tostring(S[kind] and S[kind].Id) .. ")")
	end
	-- 2026-09-26 (owner, v3): the burn is a short one-shot now and then, never a loop.
	assert(S.Burn.Loop ~= true, "the burn no longer loops")
	assert(Fx.Music.Id == "rbxassetid://133261865867143" and Fx.Music.FadeIn >= 2 and Fx.Music.FadeIn <= 3 and Fx.Music.FadeOut >= 2.5 and Fx.Music.FadeOut <= 3.5,
		"the music \"Eggman's Revenge\" loops with its fades")
	assert(SSE.Homing.ChargeSound == S.ChargeStart.Id, "the contract's charge sound is the one played")
	-- The voices his lines play are real sounds.
	for key, line in Dialogue.Lines do
		if line.Voice then
			assert(S[line.Voice], key .. ": its voice " .. line.Voice .. " is a sound")
		end
	end
	assert(Dialogue.Lines.EggmanShielded.Voice == "VoiceShielded" and Dialogue.Lines.EggmanParallel.Voice == "VoiceParallel"
		and Dialogue.Lines.EggmanBeBack.Voice == "VoiceBeBack" and Dialogue.Lines.EggmanCatch.Voice == "VoiceCatch", "each voice on its line")
	-- The Settings toggle and mute silence it; the SFX group routes the rest (SoundService children).
	assert(Fx.SoundVolume("BombBlast", { SoundEffects = false }) == 0 and Fx.SoundVolume("BombBlast", { Muted = true }) == 0, "silent when sound effects are off or muted")
	assert(Fx.SoundVolume("BombBlast", {}) == S.BombBlast.Volume and Fx.SoundVolume("BombBlast", {}, Fx.SoundRange) == 0, "full volume / attenuated")
	has(client, 'player:GetAttribute("SoundEffects") ~= false and player:GetAttribute("Muted") ~= true', "soundsOn: the toggle and mute")
	has(body(client, "prewarmSounds"), "made.Parent = SoundService", "the sounds live in SoundService (Audio/SfxAudioController routes them)")
	has(body(client, "Music.Start"), "made.SoundGroup = newGroup", "the music has its own group (the MUSIC slider, not SFX)")
	has(client, "lobby:SetAttribute(Fx.Music.SilenceAttribute, true)", "the lobby playlist is silenced while it plays")
	has(client, "lobby:SetAttribute(Fx.Music.SilenceAttribute, nil)", "and given back after")
	local music = fs.readFile(MUSIC_PATH)
	has(music, 'local SILENCE_ATTRIBUTE = "' .. Fx.Music.SilenceAttribute .. '"', "Audio/BackgroundMusic knows the attribute")
	has(music, "or music:GetAttribute(SILENCE_ATTRIBUTE) == true", "and silences the playlist for it")
	has(music, "music:GetAttributeChangedSignal(SILENCE_ATTRIBUTE):Connect(function()\n\tapplyVolume(true)", "fading")
	pass("v2: the lightning globe id is in no source; the owner's 9 uploads + the kept explosion + the music, where he asked; silent with sound effects off / muted; the music's own group; the lobby playlist silenced and given back")
end

----------------------------------------------------------------------
-- 9. (v2) Eggman's dialogue: lines, typewriter, the box on every screen
----------------------------------------------------------------------
do
	-- Every cue and taunt the contract names has a line, in en / es / pt.
	local keys = {}
	for _, cue in SSE.Dialogue do
		keys[cue[3]] = true
	end
	for _, key in SSE.Taunts do
		keys[key] = true
	end
	for key in keys do
		assert(Dialogue.Resolve(key, nil, 1) ~= nil, "a line for the contract's " .. key)
	end
	for key, line in Dialogue.Lines do
		for _, lang in { "en", "es", "pt" } do
			assert(type(line[lang]) == "string" and line[lang] ~= "", key .. " has " .. lang)
		end
		assert(Dialogue.Moods[line.Mood], key .. ": a mood")
	end
	assert(string.find(Dialogue.Line("en", "EggmanSonic"), "SONIC", 1, true), "\"Sonic! ...\"")
	assert(string.find(Dialogue.Line("en", "EggmanRevenge"), "REVENGE", 1, true), "\"I'll have my revenge!\"")
	assert(Dialogue.Line("en", "EggmanBeBack") == "This is not the end. I will be back... I promise.", "the goodbye line matches the owner's audio")
	assert(Dialogue.Line("en", "EggmanShielded") == "What are you doing? I'm right here!", "the shield taunt matches the owner's audio")
	assert(Dialogue.Line("en", "EggmanParallel") == "PARALLEL ATTACK!", "the parallel salvo's call")
	assert(Dialogue.Line("fr", "EggmanBeBack") == Dialogue.Line("en", "EggmanBeBack"), "English for any other language")
	-- Groups never repeat the same line twice in a row.
	for seed = 0, 20 do
		local a = Dialogue.Resolve("EggmanHit", nil, seed)
		local b = Dialogue.Resolve("EggmanHit", a, seed)
		assert(a and b and a ~= b, "a group never repeats itself")
	end
	-- The typewriter: UTF-8 characters, a beat after punctuation, all of it out by TypeSeconds.
	local text = Dialogue.Line("es", "EggmanBeBack")
	local n = Dialogue.Graphemes(text)
	assert(n == utf8.len(text), "graphemes = utf8.len")
	assert(Dialogue.Typed(text, 0) == 0 and Dialogue.Typed(text, Dialogue.TypeSeconds(text) + 0.01) == n, "0 at the start, all by TypeSeconds")
	local last = 0
	for step = 1, 200 do
		local typed = Dialogue.Typed(text, step / 60)
		assert(typed >= last, "the typewriter never goes back")
		last = typed
	end
	assert(Dialogue.Hold(text) >= Dialogue.TypeSeconds(text) and Dialogue.Hold(text) <= Dialogue.HoldMax, "a line stays up after it is out")
	-- The box: inside the safe area (the notch, the home indicator, the top bar), 11 px words or more, on phones
	-- under the boss bar and never on the jump button, on computers over the level bar, during a cinematic
	-- inside the letterbox band.
	local SCREENS = { { 568, 320 }, { 640, 360 }, { 667, 375 }, { 740, 360 }, { 780, 360 }, { 812, 375 }, { 844, 390 }, { 896, 414 },
		{ 932, 430 }, { 1024, 768 }, { 1180, 820 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 375, 812 }, { 390, 844 } }
	local checked = 0
	for _, s in SCREENS do
		local w, h = s[1], s[2]
		for _, topBar in { 0, 36, 58 } do
			for _, touch in { true, false } do
				for _, cinematic in { false, true } do
					local l = Dialogue.Layout(w, h, { topBar = topBar, touch = touch, cinematic = cinematic })
					local where = ("%dx%d top %d touch %s cinematic %s"):format(w, h, topBar, tostring(touch), tostring(cinematic))
					checked += 1
					local safe = l.Safe
					assert(l.Left >= safe.Left - 0.5 and l.Right <= safe.Right + 0.5, where .. ": inside the safe width")
					assert(l.HeaderTop >= safe.Top - 0.5 and l.Bottom <= safe.Bottom + 0.5, where .. ": inside the safe height (tab included)")
					assert(l.TextSize >= Dialogue.MinText, where .. (": words of %.1f px"):format(l.TextSize))
					assert(l.NameSize == 0 and l.HeaderTop == l.Top, where .. ": (v3) no name tab over the strip")
					if cinematic then
						local phone = CinematicFit.IsPhone(w, h, touch)
						local bars = CinematicFit.Bars(w, h, phone)
						assert(l.HeaderTop >= h * bars - 0.5 and l.Bottom <= h * (1 - bars) + 0.5, where .. ": inside the letterbox band")
					elseif l.Phone then
						assert(l.Design == "Compact", where .. ": the compact box")
						local bossBar = Dialogue.BossBarRect(w, topBar)
						assert(l.HeaderTop >= bossBar.Bottom + Dialogue.BossBar.Gap - 0.5, where .. ": under the boss bar")
						assert((l.Bottom - l.HeaderTop) <= h * Dialogue.PhoneHeightShare + 0.5, where .. ": phone-sized")
						assert(not H.Overlaps(l, H.JumpButton(w, h - topBar)), where .. ": clear of the jump button")
					else
						local barTop = H.CentreBarRects(w, h - topBar)[1].Top + topBar
						assert(l.Bottom <= barTop - Dialogue.BarGap + 0.5, where .. ": over the level bar")
						assert(math.abs((l.Left + l.Right) / 2 - w / 2) < 1, where .. ": bottom centre")
					end
				end
			end
		end
	end
	has(client, "local l = Dialogue.Layout(view.X, view.Y, { topBar = topBar, touch = touch, cinematic = cinematic, hudInset = hudInset })", "the client lays the box out with it")
	has(body(client, "Screen.Say"), "textLabel.MaxVisibleGraphemes = 0", "typewriter from nothing")
	has(body(client, "Screen.Update"), "textLabel.MaxVisibleGraphemes = typed", "then Dialogue.Typed")
	has(body(client, "Screen.Say"), "if line.Voice then playSound(line.Voice) else nil", "his voice")
	has(body(client, "Screen.Say"), "Music.Duck(voice ~= nil)", "the music ducks under it")
	has(body(client, "Screen.SetPortrait"), "copy.Parent = viewport", "the portrait: his head in a ViewportFrame")
	-- 2026-09-26 (owner, v3): simple and basic: a slim strip, a small round portrait, no box, no name tab.
	for name, d in Dialogue.Designs do
		assert(d.Header == 0 and d.NameSize == 0, name .. ": no name tab")
		assert(d.Portrait <= 48 and d.Height <= 60, name .. ": a small portrait on a slim strip (" .. d.Portrait .. " / " .. d.Height .. ")")
	end
	local build = body(client, "Screen.Build")
	has(build, 'local b = make("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1', "no box behind the words")
	hasNot(build, "NameTab", "no name tab")
	hasNot(client, "showBanner", "no phase banners")
	hasNot(client, "showNotice", "no notices")
	hasNot(client, "HintHold", "no hints on the reticle")
	assert(Dialogue.BossBar.Height == Fx.BossBarHeight() and Dialogue.BossBar.Top == Fx.BossBar.Top, "the phone strip keeps under the new boss bar")
	has(client, "emblem = drawEmblem(p)", "or his emblem drawn in frames")
	pass(("v2 dialogue: every contract cue / taunt in en / es / pt, the owner's lines, no repeats, the typewriter; the box on %d screen / mode shapes: safe area, letterbox band, under the boss bar on phones, over the level bar on computers, 11 px words"):format(checked))
end

----------------------------------------------------------------------
-- 10. (v2) The cinematics' shots
----------------------------------------------------------------------
do
	local origin = Vector3.new(280.28, 37467.06, -1781.14)
	local spot = Vector3.new(219, 37472, -1820)
	local plan = SSE.Plan(1000, 12345, spot, nil, nil)
	for _, kind in { "Intro", "Emeralds", "Outro" } do
		for _, startOffset in { Vector3.new(0, 8, 20), Vector3.new(-18, 12, -6), Vector3.new(4, 30, 4) } do
			local rootPos = origin + Vector3.new(6, 3, 10)
			local startCam = CFrame.new(rootPos + startOffset)
			local t0 = if kind == "Intro" then 1000 elseif kind == "Emeralds" then 1017 else 1100
			local endPlan = if kind == "Outro" then SSE.Plan(1000, 12345, spot, t0, "Defeat") else plan
			local ctx = {
				startCam = startCam,
				root = function()
					return rootPos
				end,
				rootAtStart = rootPos,
				boss = function(t)
					return SSE.BossPosition(origin, t0 + t, endPlan)
				end,
				spot = spot,
				origin = origin,
				floorY = origin.Y - 3,
			}
			local length = Cine.Length(kind)
			local first = Cine.Frame(kind, 0, ctx, CFrame)
			nearV(first.Position, startCam.Position, 0.05, kind .. ": starts on the player's camera")
			local last = Cine.Frame(kind, length, ctx, CFrame)
			nearV(last.Position, Cine.ReturnCam(ctx, CFrame).Position, 0.05, kind .. ": ends where the player's camera will be")
			nearV(last.LookVector, startCam.LookVector, 0.01, kind .. ": looking the way the player looked")
			local prev = first.Position
			local maxStep = 0
			for step = 1, math.floor(length * 60) do
				local cf, fov = Cine.Frame(kind, step / 60, ctx, CFrame)
				maxStep = math.max(maxStep, (cf.Position - prev).Magnitude)
				prev = cf.Position
				assert(cf.Position.Y >= ctx.floorY + Cine.MinAboveFloor - 0.05, kind .. ": never under the floor")
				assert(fov >= 40 and fov <= 90, kind .. ": a sane field of view")
			end
			assert(maxStep <= 2.4, ("%s: smooth (%.2f studs a frame at most)"):format(kind, maxStep))
		end
		local bars = CinematicFit.Bars(844, 390, true)
		local length = Cine.Length(kind)
		assert(Cine.Bars(0, length, bars) == 0 and Cine.Bars(length, length, bars) == 0 and math.abs(Cine.Bars(length / 2, length, bars) - bars) < 1e-6,
			kind .. ": the letterbox slides in and out")
	end
	assert(CinematicFit.Bars(844, 390, true) == CinematicFit.PhoneBar and CinematicFit.Bars(1920, 1080, false) == CinematicFit.DesktopBar, "thin bars on phones")
	assert(Cine.Length("Intro", SSE.Durations.Cinematic) <= SSE.Durations.Cinematic + 0.01, "the intro fits the Cinematic phase")
	assert(Cine.Length("Emeralds") <= SSE.Durations.Emeralds, "the emeralds' shot fits their phase")
	assert(Cine.Shots.Emeralds.Flash == SSE.Emeralds.AbsorbAt, "the push-in meets the absorption")
	assert(Cine.Length("Outro") <= SSE.Durations.Defeat and Cine.Length("Outro") <= SSE.Durations.Escape, "the outro fits the Defeat / Escape")
	pass("v2 cinematics: Intro / Emeralds / Outro from three starting cameras: start on the player's camera, end on the return camera, smooth (<= 2.4 studs a frame), never under the floor; letterbox in / out; they fit their phases")
end

----------------------------------------------------------------------
-- 11. (v2) Fx: the charge, the red zone, the barrel, the cannon, the gestures, the chaos, the vignette, rings
----------------------------------------------------------------------
do
	-- The charge: the contract's length first, the ring's segments, the scales growing with it.
	assert(Fx.ChargeSeconds(SSE.Homing.ChargeSeconds, 0) == SSE.Homing.ChargeSeconds, "the contract's ChargeSeconds")
	assert(Fx.ChargeSeconds(nil, 1.3) == 1.3 and Fx.ChargeSeconds(nil, 0) == Fx.Charge.Seconds and Fx.ChargeSeconds(nil, 30) == Fx.Charge.Seconds, "else the sound's length, else the default")
	assert(Fx.ChargeLevel(0, 1.6) == 0 and Fx.ChargeLevel(0.8, 1.6) == 0.5 and Fx.ChargeLevel(5, 1.6) == 1, "the charge level")
	assert(Fx.ChargeSegments(0) == 0 and Fx.ChargeSegments(0.5) == Fx.Charge.RingSegments / 2 and Fx.ChargeSegments(1) == Fx.Charge.RingSegments, "the ring's lit segments")
	for _, pair in { Fx.Charge.Impact, Fx.Charge.Recoil, Fx.Charge.Bounce, Fx.Charge.Shake } do
		assert(Fx.ChargeScale(0, pair) == pair[1] and Fx.ChargeScale(1, pair) == pair[2] and Fx.ChargeScale(0.5, pair) > pair[1], "a charge scale grows")
	end
	local r0, d0 = SSE.BossRecoil(0)
	local r1, d1 = SSE.BossRecoil(1)
	assert(r1 > r0 and d1 > d0, "a full charge knocks him further")
	assert(SSE.HomingBounce(Vector3.new(0, 0, -1), 1).Y > SSE.HomingBounce(Vector3.new(0, 0, -1), 0).Y, "and bounces higher")
	-- The red zone: the pulse speeds up (never jumping), the fill closes in by FillBy, the closing ring meets the
	-- blast edge by CloseBy, the alarm ticks faster and higher, the zone is the blast.
	local flight = 1.0
	local prevPulse = select(1, Fx.WarningLook(0, flight))
	local maxJump = 0
	for step = 1, 60 do
		local pulse = Fx.WarningLook(step / 60, flight)
		maxJump = math.max(maxJump, math.abs(pulse - prevPulse))
		prevPulse = pulse
	end
	assert(maxJump < 0.75, "the pulse never jumps (" .. maxJump .. ")")
	local _, f0, c0 = Fx.WarningLook(0, flight)
	local _, fEnd, cEnd = Fx.WarningLook(Fx.Warning.CloseBy, flight)
	local _, fFill = Fx.WarningLook(Fx.Warning.FillBy, flight)
	assert(f0 == 0 and fFill == 1 and fEnd == 1, "the fill closes in quickly: full at FillBy")
	near(c0, 1, 1e-9, "the closing ring starts at the part's edge")
	near(cEnd, 1 / Fx.Warning.Span, 1e-9, "and meets the blast edge")
	local early = Fx.AlarmTick(Fx.Warning.TickFrom - 0.01)
	local i1, p1 = Fx.AlarmTick(0.4)
	local i2, p2 = Fx.AlarmTick(0.95)
	assert(early == nil and i1 and i2 and i2 < i1 and p2 > p1, "the alarm: none early, then faster and higher")
	assert(SSE.Warning.Radius == SSE.Bombard.BlastRadius, "the red zone is the blast")
	assert(Fx.WhistlePitch(0) > Fx.WhistlePitch(1), "the whistle falls")
	-- The barrel: the bomb starts inside it, slides out, and is on SSE.BombArc from ExitSeconds on, without a jump.
	local from, to = Vector3.new(0, 100, 0), Vector3.new(40, 10, -30)
	local dir = Vector3.new(0, -0.34, -0.94).Unit
	local depth = Fx.Bomb.BarrelDepth * 2.2
	nearV(Fx.BombPosition(from, to, 0, 1.2, dir, depth), from - dir * depth, 1e-4, "inside the barrel at the launch")
	local exitT = Fx.Bomb.ExitSeconds / 1.2
	nearV(Fx.BombPosition(from, to, exitT + 0.01, 1.2, dir, depth), SSE.BombArc(from, to, exitT + 0.01), 1e-4, "on the arc after the exit")
	local prev = Fx.BombPosition(from, to, 0, 1.2, dir, depth)
	for step = 1, 72 do
		local p = Fx.BombPosition(from, to, step / 72, 1.2, dir, depth)
		assert((p - prev).Magnitude < 3, "the bomb never jumps (" .. (p - prev).Magnitude .. ")")
		prev = p
	end
	nearV(Fx.BombPosition(from, to, 0.5, 1.2, nil, 0), SSE.BombArc(from, to, 0.5), 1e-6, "no barrel: the arc")
	-- The cannon: in for the reload, out (with a snap) for an attack, out in the Bombard; the kick springs back.
	assert(Fx.CannonOut("Reload", 0) == 1 and Fx.CannonOut("Reload", Fx.Cannon.RetractSeconds) == 0, "retracts for the reload")
	assert(Fx.CannonOut("Attack", 0) == 0 and math.abs(Fx.CannonOut("Attack", Fx.Cannon.DeploySeconds) - 1) < 1e-6, "deploys for an attack")
	local peak = 0
	for step = 0, 30 do
		peak = math.max(peak, Fx.CannonOut("Attack", step / 30 * Fx.Cannon.DeploySeconds))
	end
	assert(peak > 1 and peak <= 1.08, "with a small overshoot")
	assert(Fx.CannonOut("", 0) == 1 and Fx.CannonOut(nil, 99) == 1, "out outside the Battle")
	assert(Fx.CannonKick(0.02) > 0.1 and Fx.CannonKick(Fx.Cannon.KickSeconds) == 0 and Fx.CannonKick(-1) == 0, "the kick and its spring back")
	local rest = Fx.CannonOffset(1, 0, 2.2, CFrame)
	nearV(rest.Position, Vector3.zero, 1e-6, "deployed: at its mount")
	assert(Fx.CannonOffset(0, 0, 2.2, CFrame).Position.Z > 1, "retracted: back into the hull")
	-- The gestures: laid over EggmanDriving, the legs stay under the cockpit floor (the root's added pitch undone
	-- at the hips), nothing outside the joints' sane range.
	local Pose = require("../src/common/ReplicatedStorage/Shared/LobbyNpcPose")
	for _, name in { "Point", "Fire", "Hit", "Smug", "Reload", "Defeat" } do
		for _, age in { 0.05, 0.3, 0.7, 1.2 } do
			local out = Pose.Sample("EggmanDriving", 12.3, Pose.NewOut(), nil, nil, { yaw = 20, pitch = 5 })
			local rootBefore, hipBefore = out.RootJoint[4], out["Right Hip"][4]
			local w = Fx.GestureWeight(name, age)
			Fx.ApplyGesture(out, name, age, w, { yaw = 20, pitch = 5 }, Pose.AimArm)
			near(out.RootJoint[4] - rootBefore, -(out["Right Hip"][4] - hipBefore), 1e-6, name .. ": the legs stay under the floor")
			for _, joint in Pose.Joints do
				for i = 4, 6 do
					assert(math.abs(out[joint][i]) <= 200, name .. ": " .. joint .. " stays sane")
				end
			end
		end
	end
	assert(Fx.GestureWeight("Hit", 0) == 0 and Fx.GestureWeight("Hit", 0.3) == 1 and Fx.GestureWeight("Hit", Fx.Gestures.Hit.Duration) == 0, "a one-shot comes and goes")
	assert(Fx.GestureWeight("Reload", 5) == 1 and Fx.GestureWeight("Reload", -1) == 0, "a loop holds")
	-- The chaos: rises in the Cinematic, holds, falls after the defeat, 0 without an event or under the kill switch.
	assert(Fx.ChaosTarget("", 0, true) == 0 and Fx.ChaosTarget("Battle", 10, false) == 0, "no event, the kill switch: 0")
	assert(Fx.ChaosTarget("Cinematic", 0, true) == 0 and Fx.ChaosTarget("Cinematic", 7, true) == 1 and Fx.ChaosTarget("Bombard", 0, true) == 1, "it rises while he lifts off")
	assert(Fx.ChaosTarget("Defeat", 0, true) == 1 and Fx.ChaosTarget("Defeat", 6, true) == 0, "and falls after the defeat")
	local w = 0
	for _ = 1, 60 * 3 do
		w = Fx.ChaosStep(w, 1, 1 / 60)
	end
	assert(w == 1, "the weight reaches 1 in InSeconds")
	for _ = 1, 60 * 3 do
		w = Fx.ChaosStep(w, 0, 1 / 60)
	end
	assert(w == 0, "and 0 in OutSeconds")
	local base = { Brightness = 2, OutdoorAmbient = Color3.fromRGB(100, 110, 120), Ambient = Color3.fromRGB(90, 90, 90), ClockTime = 14 }
	local none = Fx.ChaosLighting(base, 0, Color3)
	assert(none.Brightness == base.Brightness and none.OutdoorAmbient == base.OutdoorAmbient and none.Ambient == base.Ambient and none.ClockTime == base.ClockTime, "weight 0: the base exactly")
	local full = Fx.ChaosLighting(base, 1, Color3)
	-- 2026-09-26 (owner, v3) "way too red": at full weight only Chaos.Strength of the way to the warm target.
	local k = Fx.Chaos.Strength
	assert(k > 0 and k <= 0.4, "the layer goes at most 40 % of the way (" .. k .. ")")
	near(full.ClockTime, (base.ClockTime + (((Fx.Chaos.Lighting.ClockTime - base.ClockTime + 12) % 24) - 12) * k) % 24, 1e-6, "weight 1: the warm haze")
	local runtimeBase = { Brightness = 3, OutdoorAmbient = Color3.fromRGB(170, 174, 181), Ambient = Color3.fromRGB(132, 134, 142), ClockTime = 14.15 }
	local warm = Fx.ChaosLighting(runtimeBase, 1, Color3)
	assert(warm.Brightness >= runtimeBase.Brightness * 0.85, "a little dimmer, not dark (" .. warm.Brightness .. ")")
	assert(math.abs(warm.ClockTime - runtimeBase.ClockTime) <= 1.1, "no sunset (" .. warm.ClockTime .. ")")
	local dr = warm.OutdoorAmbient.R - runtimeBase.OutdoorAmbient.R
	local dg = warm.OutdoorAmbient.G - runtimeBase.OutdoorAmbient.G
	local db = warm.OutdoorAmbient.B - runtimeBase.OutdoorAmbient.B
	assert(dr >= 0 and dr >= dg and dg >= db and math.max(math.abs(dr), math.abs(dg), math.abs(db)) <= 60 / 255, "a subtle warm (orange, not red) tint")
	local G = Fx.Chaos.Grade
	assert(G.Saturation <= 0.08 and math.abs(G.Contrast) <= 0.06 and math.min(G.TintColor[1], G.TintColor[2], G.TintColor[3]) >= 215, "a light grade")
	assert(Fx.Ambience.SmokeSize <= 2.6 and Fx.Ambience.SmokeRates[1] <= 3 and Fx.Ambience.SmokeColor[1][1] >= 130, "lighter smoke")
	assert(Fx.ChaosTarget("Return", 0.5, true, true) == 0 and Fx.ChaosTarget("Teleport", 1, true, true) == 1, "(v3) the haze comes with the trip to the arena and leaves with the trip home")
	-- Zone-based: nothing outside the event's arena.
	assert(Fx.ChaosTarget("Battle", 10, true, false) == 0 and Fx.ChaosTarget("Battle", 10, true, true) == 1 and Fx.ChaosTarget("Battle", 10, true) == 1,
		"zone-based: 0 outside the arena")
	-- The vignette: invisible at 0, the rim brighter than the glow at 1.
	assert(Fx.VignetteEdge(1, 0, 0) == 1 and Fx.VignetteEdge(2, 0, 3) == 1, "the vignette's edges are invisible at level 0")
	assert(Fx.VignetteEdge(2, 1, 0) < Fx.VignetteEdge(1, 1, 0), "the rim is brighter than the glow")
	-- The fade into the horizon: 0 while he holds, 1 before the phase ends.
	assert(Fx.EndFade(1, true) == 0 and Fx.EndFade(SSE.Boss.DefeatHold, true) == 0, "no fade while he holds")
	assert(Fx.EndFade(SSE.Durations.Defeat, true) == 1 and Fx.EndFade(SSE.Durations.Escape, false) == 1, "gone by the end of the Defeat / Escape")
	local prevFade = 0
	for step = 1, 390 do
		local k = Fx.EndFade(step / 60, true)
		assert(k >= prevFade and k - prevFade < 0.05, "the fade is smooth")
		prevFade = k
	end
	-- The ring rain: the arcs end on the spot, the rings fade at their end.
	local a, b = Vector3.new(0, 90, 0), Vector3.new(30, 2, -20)
	nearV(Fx.RingArc(a, b, 0), a, 1e-6, "a ring leaves the ship")
	nearV(Fx.RingArc(a, b, 1), b, 1e-6, "and lands on its spot")
	assert(Fx.RingAlpha(0, 30) == 1 and Fx.RingAlpha(30, 30) == 0 and Fx.RingAlpha(30 - Fx.Rings.FadeSeconds / 2, 30) > 0, "a ring fades out smoothly at its end")
	assert(Fx.RingFlight(a, b) >= Fx.Rings.FlightMin and Fx.RingFlight(a, b) <= Fx.Rings.FlightMax, "its flight time")
	assert(Fx.MeshNames.Ring == "Ring", "the kit's ring (Meshes.Ring)")
	-- The lobby's smoke and fires: the same places for everyone (the seed), spread round the lobby.
	local p1s, p2s = Fx.AmbiencePoints(99, 6), Fx.AmbiencePoints(99, 6)
	for index = 1, 6 do
		nearV(p1s[index], p2s[index], 0, "seeded places")
		local r = p1s[index].Magnitude
		assert(r >= Fx.Ambience.RadiusMin - 1e-6 and r <= Fx.Ambience.RadiusMax + 1e-6, "round the lobby")
	end
	-- The emeralds' VFX: the imported BurstHatch pieces (no default texture), tinted per gem; seven colours named.
	assert(#Fx.EmeraldNames == #SSE.Emeralds.Colors, "a name per gem colour")
	has(body(client, "acquireGem"), "emitter.Color = tint", "the gem's glow and embers in its colour")
	has(body(client, "acquireGem"), "gem.trail.Color = ColorSequence.new(", "and its trail")
	has(body(client, "makeGem"), 'Fx.EmitterAllowed(SSE.VfxNames.BurstHatch, d.Name, "GemGlow")', "the glow is BurstHatch's")
	pass("v2 Fx: the charge (contract length, ring, scales), the red zone (pulse, fill, closing ring, alarm, whistle), the exit from the barrel, the cannon (deploy snap, retract, kick), gestures (legs under the floor), chaos (rise, fall, exact base), vignette, the fade into the horizon, rings, ambience, gem VFX")
end

----------------------------------------------------------------------
-- 12. (v2) SuperSonicLook while the server's Super Sonic skin is on: none of the old look, small sparks only
----------------------------------------------------------------------
do
	table.clear(watchers)
	local character, cosmetics = makeCharacter()
	local before = snapshot(character)
	local cosmeticsBefore = snapshot(cosmetics)
	local handle = Look.Apply(ENV, character, { Gold = GOLD, Ruby = RUBY, BodyGold = false, Eyes = false, Shells = false, AccessoryShells = false,
		SparkLimbs = 4, SparkRate = 3, SparkScale = 0.55, Texture = Fx.Textures.Lightning, Flipbook = Fx.Flipbooks.Lightning })
	for _, part in Look.BodyParts(character) do
		assert(part.Color ~= GOLD, "the skin's colours stay: " .. part.Name)
	end
	local sparks = 0
	for _, d in added(character) do
		assert(d.Name ~= Look.Prefix .. "Shell" and d.Name ~= Look.Prefix .. "Eye", "no glaze, no eyes: " .. d.Name)
		if d:IsA("ParticleEmitter") then
			sparks += 1
			assert(d.Size.Keypoints[1].Value < Look.Spark.Size[1], "the sparks are small")
		end
	end
	assert(sparks == 4, "lightning on both hands and both feet (" .. sparks .. ")")
	sameSnapshot(cosmeticsBefore, snapshot(cosmetics), "the aura / trail with the skin")
	Look.Remove(handle)
	sameSnapshot(before, snapshot(character), "the skin mode after Remove")
	has(body(client, "lookOptions"), "options.BodyGold = false", "the client uses it for SSE_Skin")
	has(body(client, "wearsSkin"), "return skin ~= nil and target:GetAttribute(SKIN_OVERRIDE) == skin", "when the server's skin is worn (SSE_Skin, and SkinOverride still that skin)")
	has(client, "target:GetAttributeChangedSignal(SKIN_OVERRIDE):Connect(function()", "and redraws when the skin system changes it")
	has(client, "target:GetAttributeChangedSignal(PATTR.Skin):Connect(function()", "and redraws when it comes or goes")
	pass("v2 SuperSonicLook with the server's Super Sonic skin: no gold, no glaze, no eyes; small lightning on the hands and feet; the aura untouched; restored exactly")
end

----------------------------------------------------------------------
-- 13. (v2) The chaos sky through Admin/AdminAbuseEffects' blendLighting: mixed in, then the lobby's EXACT base
----------------------------------------------------------------------
do
	local effects = fs.readFile(EFFECTS_PATH)
	local from = string.find(effects, "local lightingBase = nil", 1, true)
	local to = string.find(effects, "-- Admin treadmills", 1, true)
	assert(from and to and to > from, "blendLighting's block")
	local chunkText = [[
local snowWeight, discoWeight, tacosWeight = 0, 0, 0
local SNOW = { Brightness = 1, OutdoorAmbient = Color3.new(1, 1, 1) }
local DISCO = { Brightness = 1, ClockTime = 0 }
local discoColors = { OutdoorAmbient = Color3.new(0, 0, 0), Ambient = Color3.new(0, 0, 0) }
local function lerp(a, b, t)
	return a + (b - a) * t
end
]] .. string.sub(effects, from, to - 1) .. [[
chaosFx, chaosContract = FX, CONTRACT
return { blend = blendLighting, chaos = updateChaos, weight = function() return chaosWeight end, base = function() return lightingBase end }
]]
	local attrs = {}
	local serverTime = 100
	local lighting = { Brightness = 2.25, OutdoorAmbient = Color3.fromRGB(127, 127, 140), Ambient = Color3.fromRGB(70, 70, 80), ClockTime = 13.5 }
	local original = table.clone(lighting)
	local fakeWorkspace = {
		GetAttribute = function(_, name)
			return attrs[name]
		end,
		GetServerTimeNow = function()
			return serverTime
		end,
	}
	local contract = setmetatable({ IsOn = function()
		return attrs[SSE.KillAttribute] ~= true
	end }, { __index = SSE })
	local zoneAttrs = { [Fx.ChaosZoneAttribute] = true }
	local fakePlayers = { LocalPlayer = { GetAttribute = function(_, name)
		return zoneAttrs[name]
	end } }
	local api = luau.load(chunkText, { debugName = "blendLighting", environment = setmetatable({
		Color3 = Color3, Lighting = lighting, Workspace = fakeWorkspace, FX = Fx, CONTRACT = contract, Players = fakePlayers,
		ReplicatedStorage = { WaitForChild = function()
			error("no ReplicatedStorage here")
		end },
	}, { __index = _G }) })()
	local function run(seconds)
		for _ = 1, math.floor(seconds * 60) do
			serverTime += 1 / 60
			api.chaos(1 / 60)
			api.blend()
		end
	end
	run(1)
	assert(lighting.Brightness == original.Brightness and api.base() == nil, "no event: Lighting untouched")
	attrs[SSE.Attributes.Phase] = "Battle"
	attrs[SSE.Attributes.PhaseStart] = serverTime
	run(3)
	near(api.weight(), 1, 1e-9, "the chaos layer at full")
	local expected = Fx.ChaosLighting(original, 1, Color3)
	near(lighting.ClockTime, expected.ClockTime, 1e-4, "the warm haze (ClockTime)")
	assert(lighting.OutdoorAmbient == expected.OutdoorAmbient, "the warm OutdoorAmbient")
	-- 2026-09-26 (owner, v3): zone-based: leaving the arena blends it back out; the lobby's own light exactly.
	zoneAttrs[Fx.ChaosZoneAttribute] = nil
	run(3)
	assert(api.weight() == 0 and api.base() == nil, "out of the arena: the layer blends out")
	for key, value in original do
		assert(lighting[key] == value, "outside the arena the lobby's own " .. key .. " exactly")
	end
	zoneAttrs[Fx.ChaosZoneAttribute] = true
	run(3)
	near(api.weight(), 1, 1e-9, "back in the arena: the haze again")
	attrs[SSE.KillAttribute] = true
	run(0.05)
	assert(api.weight() == 0 and api.base() == nil, "the kill switch takes the layer away at once")
	for key, value in original do
		assert(lighting[key] == value, "the lobby's own " .. key .. " came back exactly (" .. tostring(lighting[key]) .. " vs " .. tostring(value) .. ")")
	end
	attrs[SSE.KillAttribute] = nil
	attrs[SSE.Attributes.Phase] = "Cinematic"
	attrs[SSE.Attributes.PhaseStart] = serverTime
	run(0.5)
	assert(api.weight() == 0, "the sky only turns once he lifts off")
	run(7)
	assert(api.weight() > 0.9, "and is fiery by the fight")
	attrs[SSE.Attributes.Phase] = nil
	run(3.5)
	for key, value in original do
		assert(lighting[key] == value, "after the event, the lobby's own " .. key .. " exactly")
	end
	has(effects, "updateChaos(dt)\n\tblendLighting()", "the layer steps before the mix, every frame")
	has(effects, "if snowWeight == 0 and discoWeight == 0 and tacosWeight == 0 and chaosWeight == 0 then", "the base comes back only when every layer is at 0")
	hasNot(client, "Lighting.ClockTime", "the event client never writes blendLighting's properties")
	hasNot(client, "Lighting.Brightness", "(nor Brightness)")
	has(body(client, "Chaos.Prewarm"), "made.Parent = Lighting", "its own grade under Lighting")
	has(effects, "local inZone = if zoneName then Players.LocalPlayer:GetAttribute(zoneName) == true else nil", "(v3) the zone attribute")
	pass("v2/v3 chaos sky: blendLighting mixes the (toned-down, zone-based) layer in last (rising in the Cinematic), the kill switch, leaving the arena and the end give the lobby's Lighting back EXACTLY; the client only owns its grade")
end

----------------------------------------------------------------------
-- 15. (v3) The pure pieces of the owner's v3 feedback
----------------------------------------------------------------------
do
	-- The burn's cadence: gaps of several seconds after each short burst, a burst that fades out and ends.
	local b = Fx.Burn
	assert(b.GapMin >= 5 and b.GapMax > b.GapMin and b.Seconds <= 3, "a short burst, gaps of several seconds")
	near(Fx.NextBurnAt(100, 0), 100 + b.Seconds + b.GapMin, 1e-9, "the shortest gap")
	near(Fx.NextBurnAt(100, 1), 100 + b.Seconds + b.GapMax, 1e-9, "the longest gap")
	assert(Fx.BurnLevel(0) == 1 and Fx.BurnLevel(b.Seconds) == 0 and Fx.BurnLevel(-1) == 0, "the burst: on, then off")
	local mid = Fx.BurnLevel(b.Seconds - b.FadeSeconds / 2)
	assert(mid > 0.4 and mid < 0.6, "it fades out over its end")
	-- The trail: ONE wide ribbon hugging the ball (its curve stays round it, never through it), streaming back in
	-- flight.
	local size = 6
	for _, angle in { 0, 1, 2.5, 4 } do
		local p0, a0, p1, a1, c0, c1 = Fx.TrailWrap(size, angle, false)
		local r = size * Fx.Trail.Radius
		for step = 0, 10 do
			local q = Fx.BeamPoint(p0, a0, c0, p1, a1, c1, step / 10)
			local radial = Vector3.new(q.X, q.Y, 0).Magnitude
			assert(radial >= size * 0.5 - 0.05, ("the ribbon never cuts through the ball (%.2f at %d)"):format(radial, step))
			assert(radial <= r * 1.35, ("it wraps close round it (%.2f)"):format(radial))
		end
		near(p0.Magnitude, math.sqrt(r * r + (0.15 * r) ^ 2), 1e-6, "its start on the ring round the ball")
		local fp0, fa0, _, _, fc0, fc1 = Fx.TrailWrap(size, angle, true)
		assert(fc1 == 0 and fc0 > 0 and fa0.Z > 0, "in flight it leaves the ball swirling back toward the tail")
		assert(fp0.Magnitude > 0, "(from the ball's surface)")
	end
	assert(Fx.Trail.Width0 >= 0.8, "wide (" .. Fx.Trail.Width0 .. " x the ball)")
	-- The reticle's prompt and the jump press.
	assert(Fx.ReticlePrompt("Gamepad", true) == "(A)" and Fx.ReticlePrompt("Gamepad", false) == "(X)", "(A) in the air, (X) on the ground")
	assert(Fx.ReticlePrompt("Keys", true) == "" and Fx.ReticlePrompt("Touch", false) == "", "nothing without a gamepad")
	assert(Fx.JumpPress(10, nil) and Fx.JumpPress(10, 9.8) and not Fx.JumpPress(10, 9.95), "a new press after a pause, not a held key")
	-- The HUD hold, the freeze, the invite.
	assert(Fx.HudHideWanted(true, "Battle", true, false) and not Fx.HudHideWanted(true, "Battle", false, false)
		and not Fx.HudHideWanted(true, "", true, false) and not Fx.HudHideWanted(false, "Battle", true, false)
		and not Fx.HudHideWanted(true, "Battle", true, true), "the HUD held away only in the event, never in a race")
	local lobby = Vector3.new(280, 37467, -1781)
	local arena = Vector3.new(6000, 12000, -510)
	assert(Fx.FreezeWanted("Cinematic", 3, lobby + Vector3.new(5, 3, 5), arena, lobby), "the Intro freezes the lobby")
	assert(not Fx.FreezeWanted("Cinematic", 3, arena + Vector3.new(5, 3, 5), arena, lobby), "(not the arena)")
	assert(Fx.FreezeWanted("Emeralds", 1, arena + Vector3.new(5, 3, 5), arena, lobby) and not Fx.FreezeWanted("Emeralds", 1, lobby, arena, lobby), "the emeralds' shot: the arena")
	assert(not Fx.FreezeWanted("Battle", 3, arena, arena, lobby) and not Fx.FreezeWanted("Cinematic", 30, lobby, arena, lobby), "never outside a window")
	assert(not Fx.FreezeWanted("Cinematic", 3, nil, arena, lobby), "no root, no freeze")
	assert(Fx.InviteShown(5, 5, "Battle", false, nil) and not Fx.InviteShown(5, 5, "Battle", true, nil) and not Fx.InviteShown(5, 6, "Battle", false, nil)
		and not Fx.InviteShown(5, 5, "Defeat", false, nil) and not Fx.InviteShown(5, 5, "Battle", false, 5), "the invite: open, the same event, not there yet, not turned down")
	-- The beats' black: out, held until the arrival (at most HoldMax), then in.
	local T = SSE.Beats.Teleport
	assert(Fx.BeatFade(T, 0) == 0 and Fx.BeatFade(T, T.FadeOut) == 1, "fading out to black")
	assert(Fx.BeatFade(T, T.MoveAt + 1) == 1, "held black until the root arrives")
	assert(Fx.BeatFade(T, T.MoveAt + 0.2, T.MoveAt + 0.1) < 1 and Fx.BeatFade(T, T.MoveAt + 0.1 + (T.FadeIn - T.MoveAt), T.MoveAt + 0.1) == 0, "then in over FadeIn - MoveAt")
	assert(Fx.BeatFade(T, T.MoveAt + Fx.Beat.HoldMax + T.FadeIn) == 0, "never black for good")
	local prevFade = 0
	for step = 1, 240 do
		local v = Fx.BeatFade(T, step / 60, 1.0)
		assert(math.abs(v - prevFade) < 0.1, "a smooth fade")
		prevFade = v
	end
	-- The race pieces.
	assert(Fx.ArenaRaceOnly({ "Light1", "StartGantry", "Structure" }) and Fx.ArenaRaceOnly({ "SpeedPad", "SpeedPads" })
		and Fx.ArenaRaceOnly({ "Kit_SpeedPad", "GreenHillDecor" }) and Fx.ArenaRaceOnly({ "Core", "RaceOrb" })
		and Fx.ArenaRaceOnly({ "FinishBanner", "GreenHillDecor" }) and Fx.ArenaRaceOnly({ "x" }, true) and Fx.ArenaRaceOnly({ "Sign" }, false, true),
		"the race-only pieces")
	assert(not Fx.ArenaRaceOnly({ "Floor_001", "TrackFloor" }) and not Fx.ArenaRaceOnly({ "Kit_PalmA", "GreenHillDecor" })
		and not Fx.ArenaRaceOnly({ "WallL_1", "Walls" }) and not Fx.ArenaRaceOnly({ "BankLip_1", "Banks" }), "the plain map stays")
	-- The crash's pieces.
	local pops = Fx.CrashPops(100, 3)
	assert(#pops == 3 and pops[1] > 100 and pops[3] < 100 + SSE.Crash.Seconds, "the blasts on the way down, inside the dive")
	local times = SSE.CrashTimes(100)
	assert(Fx.CrashFade(times.fadeStart - 0.1, times) == 0 and Fx.CrashFade(times.fadeEnd, times) == 1, "the wreck fades between fadeStart and fadeEnd")
	for _, tierName in { "Low", "Mid", "High" } do
		local budgetT = Fx.Budget(tierName)
		assert(budgetT.CrashBlasts <= #SSE.Crash.Explosions and budgetT.CrashBlasts >= 3 and budgetT.CrashSmoke > 0, tierName .. ": a crash that looks great (lighter on Low)")
	end
	-- The boss bar's size and the charge's length (the contract's 0.7 s).
	assert(Fx.BossBarWidth(844) >= Fx.BossBar.MinWidth and Fx.BossBarWidth(3000) == Fx.BossBar.MaxWidth and Fx.BossBarHeight() <= 56, "a small bar")
	assert(Fx.ChargeSeconds(SSE.Homing.ChargeSeconds, 1.6) == SSE.Homing.ChargeSeconds and SSE.Homing.ChargeSeconds <= 0.8, "the full charge in the contract's ~0.7 s")
	-- The races are closed during the event (Workspace.RaceClosedBy): the race HUD button, the gate's sign and the
	-- holo board say so; the race map's StartGate stays open while the event runs.
	assert(SSE.RaceClosed.Attribute == "RaceClosedBy", "the contract's attribute")
	local RaceText = require("../src/common/ReplicatedStorage/Shared/RaceText")
	assert(RaceText.Get("RaceEventClosed", "en") == "Races are closed during the event" and RaceText.Get("RaceEventClosed", "es") ~= RaceText.Get("RaceEventClosed", "en"), "the line (10 languages)")
	local lobbyUi = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/RaceLobbyController.client.luau")
	has(lobbyUi, 'local RACE_CLOSED_ATTRIBUTE = "' .. SSE.RaceClosed.Attribute .. '"', "the race HUD reads it")
	has(body(lobbyUi, "buttonState"), 'return text("RaceEventClosed"), "Blue", false', "the button (and the gate's sign): closed during the event, no join call")
	local gateUi = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/FlashGateClient.client.luau")
	has(gateUi, 'local RACE_CLOSED_ATTRIBUTE = "' .. SSE.RaceClosed.Attribute .. '"', "the holo board reads it")
	has(body(gateUi, "refreshBoardText"), 'U4.IsOn("Race") and not closedByEvent', "STATUS: CLOSED")
	has(body(gateUi, "refreshBoardText"), 'RaceText.Get("RaceEventClosed", lang)', "and why")
	local FlashGate = require("../src/common/ReplicatedStorage/Shared/FlashGate")
	assert(string.find(FlashGate.StatusLine("Gathering", 0, 0, false, false, "en"), FlashGate.Get("Closed", "en"), 1, true), "the board's CLOSED line")
	local visuals = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RaceArenaVisuals.client.luau")
	has(visuals, 'local EVENT_PHASE_ATTRIBUTE = "' .. SSE.Attributes.Phase .. '"', "the race visuals know the event's phase")
	has(body(visuals, "resetStart"), "if gate and not eventRunning() then", "the StartGate is not closed again locally while the event runs")
	pass("v3 pure pieces: the burn's cadence, ONE wrapping trail, (A) / (X), the jump press, the HUD hold / freeze / invite rules, the beats' black, the race pieces, the crash's pops and fade, the small bar, the 0.7 s charge, the races closed during the event (HUD, sign, board, StartGate)")
end

do
	-- The cinematics (v3): eased spline keys: smooth (no jerks), a gentle FOV, the Entry shot, the Defeat's shot inside
	-- its freeze window, kept clear of a wall between the eye and the target.
	local origin = Vector3.new(6000, 12000, -510)
	local lobby = Vector3.new(280.28, 37467.06, -1781.14)
	local spot = Vector3.new(219, 37472, -1820)
	local plan = SSE.Plan(1000, 12345, spot, nil, nil, nil, lobby)
	for _, kind in { "Intro", "Emeralds", "Outro", "Entry" } do
		local here = if kind == "Intro" then lobby else origin
		local rootPos = here + Vector3.new(6, 3, 10)
		local startCam = CFrame.new(rootPos + Vector3.new(0, 8, 20))
		local t0 = if kind == "Intro" then 1000 elseif kind == "Entry" then 1000 + 7.5 + 1.0 else 1030
		local ctx = {
			startCam = startCam, startFov = 72, endFov = 72,
			root = function()
				return rootPos
			end,
			rootAtStart = rootPos,
			boss = function(t)
				return SSE.BossPosition(origin, t0 + t, plan)
			end,
			spot = spot,
			origin = here,
			floorY = here.Y - 3,
			crash = if kind == "Outro" then origin + Vector3.new(10, 0, -20) else nil,
		}
		local length = Cine.Length(kind)
		local prevP, prevV, prevF = Cine.Frame(kind, 0, ctx, CFrame).Position, nil, 72
		local maxJerk, maxFov = 0, 0
		for step = 1, math.floor(length * 60) do
			local cf, fov = Cine.Frame(kind, step / 60, ctx, CFrame)
			local v = (cf.Position - prevP) * 60
			if prevV then
				maxJerk = math.max(maxJerk, (v - prevV).Magnitude / 60)
			end
			maxFov = math.max(maxFov, math.abs(fov - prevF) * 60)
			prevP, prevV, prevF = cf.Position, v, fov
		end
		assert(maxFov <= Cine.FovRate + 1, ("%s: a gentle FOV (%.1f deg/s)"):format(kind, maxFov))
		assert(maxJerk <= 1.2, ("%s: no jerks (%.2f studs/s a frame)"):format(kind, maxJerk))
		local _, lastFov = Cine.Frame(kind, length, ctx, CFrame)
		near(lastFov, 72, 1e-6, kind .. ": back on the player's own field of view")
	end
	local _, defeatEnd = SSE.FreezeWindow("Defeat")
	assert(Cine.Length("Outro", defeatEnd) <= defeatEnd + 1e-6, "the Defeat's shot fits its freeze window")
	near(Cine.Length("Emeralds"), SSE.FreezeWindows.Emeralds.End, 1e-6, "the emeralds' shot = its freeze window")
	near(Cine.Length("Outro"), SSE.FreezeWindows.Escape.End, 1e-6, "the escape's shot = its freeze window")
	assert(Cine.Length("Entry") <= SSE.Durations.Teleport - SSE.Beats.Teleport.MoveAt, "the entry fits the rest of the Teleport beat")
	-- Kept clear of walls: a wall 10 studs in front of the target on the eye's side; the eye is pulled in front of it
	-- at once and eases back out once it is gone (never popping out).
	local target = Vector3.new(0, 10, 0)
	local eye = Vector3.new(0, 10, 30)
	local state = {}
	local guarded = Cine.Guard(eye, target, 10, state, 1 / 60)
	assert((guarded - target).Magnitude <= 10 - Cine.ClipMargin + 1e-6, "in front of the wall at once")
	local prev = (guarded - target).Magnitude
	for _ = 1, 120 do
		local g = Cine.Guard(eye, target, nil, state, 1 / 60)
		local d = (g - target).Magnitude
		assert(d >= prev - 1e-3 and d - prev <= Cine.ClipGrow / 60 + 1e-3, "easing back out (float32 vectors)")
		prev = d
	end
	near(prev, 30, 1e-3, "back where the shot wants it")
	local clearCtx = {
		startCam = CFrame.new(lobby + Vector3.new(0, 8, 20)), root = function()
			return lobby
		end, rootAtStart = lobby, boss = function(t)
			return SSE.BossPosition(origin, 1000 + t, plan)
		end, spot = spot, origin = lobby, floorY = lobby.Y - 3,
		clear = function(from, to)
			return math.min((to - from).Magnitude, 8)
		end,
	}
	local cf = Cine.Frame("Intro", Cine.Shots.Intro.Establish, clearCtx, CFrame)
	assert(cf ~= nil, "(a shot with walls round his spot)")
	local keys = clearCtx._keys.Intro
	for index = 2, #keys.eyes - 1 do
		local d = (keys.eyes[index].v - keys.looks[index].v).Magnitude
		assert(d <= math.max(Cine.ClipMin, 8 - Cine.ClipMargin) + 1e-3, "every key pulled in front of the walls (" .. d .. ")")
	end
	pass("v3 cinematics: eased spline keys with no jerks and a gentle FOV back to the player's own, the Entry shot, the Defeat's shot inside its freeze window, kept clear of walls (keys and every frame, easing back out)")
end

----------------------------------------------------------------------
-- 7. The real client script running in a small fake Roblox (a fake DataModel, clock, scheduler and
--    services; the real shared modules): a whole event, phase by phase, message by message.
----------------------------------------------------------------------
do
	-- The clock and the scheduler (task.spawn / defer / delay / wait on the fake clock).
	local clockNow = 100
	local SERVER_OFFSET = 5000
	local deferred, sleepers = {}, {}
	local function resume(co, ...)
		local ok, problem = coroutine.resume(co, ...)
		if not ok then
			error("a client thread failed: " .. tostring(problem) .. "\n" .. debug.traceback(co), 0)
		end
	end
	local fakeTask = {}
	function fakeTask.spawn(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
		return co
	end
	function fakeTask.defer(fn, ...)
		table.insert(deferred, { fn = fn, args = table.pack(...) })
	end
	function fakeTask.delay(seconds, fn, ...)
		table.insert(sleepers, { at = clockNow + (seconds or 0), fn = fn, args = table.pack(...) })
	end
	function fakeTask.wait(seconds)
		local co = coroutine.running()
		table.insert(sleepers, { at = clockNow + (seconds or 0), co = co })
		return coroutine.yield()
	end
	local function runScheduler()
		local batch = deferred
		deferred = {}
		for _, item in batch do
			fakeTask.spawn(item.fn, table.unpack(item.args, 1, item.args.n))
		end
		local due = {}
		for index = #sleepers, 1, -1 do
			if sleepers[index].at <= clockNow then
				table.insert(due, table.remove(sleepers, index))
			end
		end
		for _, item in due do
			if item.co then
				if coroutine.status(item.co) == "suspended" then
					resume(item.co)
				end
			else
				fakeTask.spawn(item.fn, table.unpack(item.args, 1, item.args.n))
			end
		end
	end

	-- Signals.
	local function newSignal()
		local s = { handlers = {} }
		function s:Connect(fn)
			local h = { fn = fn, connected = true }
			table.insert(self.handlers, h)
			return { Connected = true, Disconnect = function()
				h.connected = false
			end }
		end
		function s:Once(fn)
			local connection
			connection = self:Connect(function(...)
				connection:Disconnect()
				fn(...)
			end)
			return connection
		end
		function s:Fire(...)
			for _, h in table.clone(self.handlers) do
				if h.connected then
					h.fn(...)
				end
			end
		end
		function s:Wait()
			error("fake Wait")
		end
		function s:Count()
			local n = 0
			for _, h in self.handlers do
				if h.connected then
					n += 1
				end
			end
			return n
		end
		return s
	end

	-- A fake Instance: a property bag with a class chain, children, attributes, tags and signals.
	local CLASS_PARENT = {
		Part = "BasePart", MeshPart = "BasePart", SpawnLocation = "Part", BasePart = "PVInstance", Model = "PVInstance",
		PVInstance = "Instance", Workspace = "Model",
		PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light", Light = "Instance",
		Decal = "FaceInstance", FaceInstance = "Instance",
		TextLabel = "GuiObject", TextButton = "GuiButton", GuiButton = "GuiObject", Frame = "GuiObject", ImageLabel = "GuiObject",
		GuiObject = "GuiBase2d", ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", LayerCollector = "GuiBase2d",
		GuiBase2d = "Instance", Script = "LuaSourceContainer", LocalScript = "Script", ModuleScript = "LuaSourceContainer",
		LuaSourceContainer = "Instance", Shirt = "Clothing", Pants = "Clothing", Clothing = "Instance",
		Weld = "JointInstance", Motor6D = "JointInstance", JointInstance = "Instance", Accessory = "Accoutrement",
		Accoutrement = "Instance",
		-- 2026-09-26 (v2)
		SurfaceGui = "LayerCollector", ViewportFrame = "GuiObject", ColorCorrectionEffect = "PostEffect", PostEffect = "Instance",
		SpecialMesh = "DataModelMesh", DataModelMesh = "Instance",
	}
	local function isA(className, target)
		if target == "Instance" then
			return true
		end
		local c = className
		while c do
			if c == target then
				return true
			end
			c = CLASS_PARENT[c]
		end
		return false
	end
	local DEFAULTS = {
		BasePart = function()
			return { CFrame = CFrame.new(), Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(163, 162, 165), Transparency = 0,
				LocalTransparencyModifier = 0, Anchored = false, CanCollide = true, CanTouch = true, CanQuery = true, Massless = false,
				CastShadow = true, Material = roblox.Enum.Material.Plastic, Reflectance = 0, AssemblyLinearVelocity = Vector3.zero,
				AssemblyAngularVelocity = Vector3.zero, Shape = roblox.Enum.PartType.Block, Archivable = true }
		end,
		Decal = function()
			return { Transparency = 0, LocalTransparencyModifier = 0, Color3 = Color3.new(1, 1, 1) }
		end,
		Humanoid = function()
			return { Health = 100, PlatformStand = false, Sit = false, FloorMaterial = roblox.Enum.Material.Plastic,
				_state = roblox.Enum.HumanoidStateType.Running }
		end,
		GuiObject = function()
			return { Visible = true, Rotation = 0, BackgroundTransparency = 0, TextTransparency = 0 }
		end,
		LayerCollector = function()
			return { Enabled = true }
		end,
		ScreenGui = function()
			return { AbsoluteSize = roblox.Vector2.new(844, 354), IgnoreGuiInset = false }
		end,
		ParticleEmitter = function()
			return { Enabled = true, Rate = 20, _emitted = 0 }
		end,
		Beam = function()
			return { Enabled = true }
		end,
		Trail = function()
			return { Enabled = true }
		end,
		Light = function()
			return { Enabled = true }
		end,
		ProximityPrompt = function()
			return { Enabled = true }
		end,
		Sound = function()
			return { IsPlaying = false, _played = 0 }
		end,
		Model = function()
			return { _scale = 1, Archivable = true }
		end,
		Attachment = function()
			return { CFrame = CFrame.new() }
		end,
		JointInstance = function()
			return { C0 = CFrame.new(), C1 = CFrame.new(), Transform = CFrame.new() }
		end,
	}
	local EVENTS = {
		InputBegan = true, InputEnded = true, ChildAdded = true, AncestryChanged = true, CharacterAdded = true,
		CharacterRemoving = true, PlayerAdded = true, PlayerRemoving = true, Stepped = true, RenderStepped = true,
		Heartbeat = true, OnClientEvent = true, LastInputTypeChanged = true, Event = true, Completed = true, Changed = true,
		-- 2026-09-26 (v3)
		JumpRequest = true, Activated = true, DescendantAdded = true,
	}
	local methods = {}
	local Meta = {}
	local function fakeNew(className, name)
		local props = {}
		for class, make in DEFAULTS do
			if isA(className, class) then
				for key, value in make() do
					props[key] = value
				end
			end
		end
		return setmetatable({
			ClassName = className, Name = name or className, _children = {}, _attrs = {}, _tags = {}, _signals = {},
			_propSignals = {}, _attrSignals = {}, _props = props, _parent = nil,
		}, Meta)
	end
	Meta.__index = function(self, key)
		if key == "Parent" then
			return rawget(self, "_parent")
		end
		local method = methods[key]
		if method then
			return method
		end
		local props = rawget(self, "_props")
		if key == "Position" and isA(rawget(self, "ClassName"), "BasePart") then
			return props.CFrame.Position
		end
		if EVENTS[key] then
			local signals = rawget(self, "_signals")
			signals[key] = signals[key] or newSignal()
			return signals[key]
		end
		return props[key]
	end
	Meta.__newindex = function(self, key, value)
		if key == "Parent" then
			local old = rawget(self, "_parent")
			if old == value then
				return
			end
			if rawget(self, "_destroyed") and value ~= nil then
				error("The Parent property of " .. self.Name .. " is locked (destroyed)")
			end
			if old then
				local list = rawget(old, "_children")
				local index = table.find(list, self)
				if index then
					table.remove(list, index)
				end
			end
			rawset(self, "_parent", value)
			if value then
				table.insert(rawget(value, "_children"), self)
				local signals = rawget(value, "_signals")
				if signals.ChildAdded then
					signals.ChildAdded:Fire(self)
				end
			end
			return
		end
		local props = rawget(self, "_props")
		if key == "Position" and isA(rawget(self, "ClassName"), "BasePart") then
			props.CFrame = CFrame.new(value) * props.CFrame.Rotation
		else
			props[key] = value
		end
		local signal = rawget(self, "_propSignals")[key]
		if signal then
			signal:Fire()
		end
	end
	Meta.__tostring = function(self)
		return "Fake<" .. rawget(self, "ClassName") .. " " .. tostring(rawget(self, "Name")) .. ">"
	end
	function methods:IsA(c)
		return isA(self.ClassName, c)
	end
	function methods:GetChildren()
		return table.clone(rawget(self, "_children"))
	end
	function methods:GetDescendants()
		local out = {}
		local function walk(x)
			for _, child in rawget(x, "_children") do
				table.insert(out, child)
				walk(child)
			end
		end
		walk(self)
		return out
	end
	function methods:FindFirstChild(name, recursive)
		for _, child in (if recursive then self:GetDescendants() else rawget(self, "_children")) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:WaitForChild(name)
		return self:FindFirstChild(name)
	end
	function methods:FindFirstChildOfClass(c)
		for _, child in rawget(self, "_children") do
			if child.ClassName == c then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChildWhichIsA(c, recursive)
		for _, child in (if recursive then self:GetDescendants() else rawget(self, "_children")) do
			if child:IsA(c) then
				return child
			end
		end
		return nil
	end
	function methods:IsDescendantOf(other)
		local node = self.Parent
		while node do
			if node == other then
				return true
			end
			node = node.Parent
		end
		return false
	end
	function methods:Destroy()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		self.Parent = nil
		rawset(self, "_destroyed", true)
	end
	function methods:GetFullName()
		local names = {}
		local node = self
		while node do
			table.insert(names, 1, node.Name)
			node = node.Parent
		end
		return table.concat(names, ".")
	end
	function methods:GetAttribute(name)
		return rawget(self, "_attrs")[name]
	end
	function methods:GetAttributes()
		return table.clone(rawget(self, "_attrs"))
	end
	function methods:SetAttribute(name, value)
		rawget(self, "_attrs")[name] = value
		local signal = rawget(self, "_attrSignals")[name]
		if signal then
			signal:Fire()
		end
	end
	function methods:GetAttributeChangedSignal(name)
		local signals = rawget(self, "_attrSignals")
		signals[name] = signals[name] or newSignal()
		return signals[name]
	end
	function methods:GetPropertyChangedSignal(name)
		local signals = rawget(self, "_propSignals")
		signals[name] = signals[name] or newSignal()
		return signals[name]
	end
	function methods:Clone()
		if self.Archivable == false then
			return nil
		end
		local map = {}
		local function copy(x)
			local c = fakeNew(x.ClassName, x.Name)
			map[x] = c
			for k, v in rawget(x, "_props") do
				rawget(c, "_props")[k] = v
			end
			for k, v in rawget(x, "_attrs") do
				rawget(c, "_attrs")[k] = v
			end
			for k in rawget(x, "_tags") do
				rawget(c, "_tags")[k] = true
			end
			for _, child in rawget(x, "_children") do
				copy(child).Parent = c
			end
			return c
		end
		local root = copy(self)
		-- References inside the copied tree point at the copies (as Roblox's Clone does).
		for original, c in map do
			for k, v in rawget(c, "_props") do
				if type(v) == "table" and map[v] then
					rawget(c, "_props")[k] = map[v]
				end
			end
		end
		return root
	end
	function methods:IsGrounded()
		return true
	end
	function methods:ScaleTo(s)
		rawget(self, "_props")._scale = s
	end
	function methods:GetScale()
		return rawget(self, "_props")._scale or 1
	end
	function methods:GetPivot()
		local primary = self.PrimaryPart or self:FindFirstChildWhichIsA("BasePart", true)
		return if primary then primary.CFrame else CFrame.new()
	end
	function methods:PivotTo(cf)
		local delta = cf * self:GetPivot():Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
	end
	function methods:GetExtentsSize()
		return Vector3.new(4, 4, 4)
	end
	function methods:Emit(n)
		rawget(self, "_props")._emitted += n
	end
	function methods:Play()
		rawget(self, "_props")._played += 1
	end
	-- (v3) Player:RequestStreamAroundAsync: recorded (the beats stream the map in round the trip's end).
	local streams = {}
	function methods:RequestStreamAroundAsync(position)
		table.insert(streams, position)
	end
	function methods:Stop()
		rawget(self, "_props")._stopped = (rawget(self, "_props")._stopped or 0) + 1
	end
	-- RunService:BindToRenderStep (the cinematics' camera): run by frames() after RenderStepped.
	local renderSteps = {}
	function methods:BindToRenderStep(name, priority, fn)
		renderSteps[name] = { priority = priority, fn = fn }
	end
	function methods:UnbindFromRenderStep(name)
		renderSteps[name] = nil
	end
	function methods:GetState()
		return self._state
	end
	function methods:ChangeState(s)
		self._state = s
	end

	-- Lune instances (the imported VFX, the owner's Eggman in his Egg Mobile) as fakes.
	local LUNE_PROPS = { "CFrame", "Size", "Color", "Transparency", "Anchored", "Material", "Reflectance", "C0", "C1", "MeshType",
		"Scale", "Offset", "Enabled", "Rate", "LockedToPart", "Texture", "Shape", "Color3" }
	local function fromLune(root)
		local map = {}
		local function copy(x)
			local c = fakeNew(x.ClassName, x.Name)
			map[x] = c
			for _, prop in LUNE_PROPS do
				local ok, value = pcall(function()
					return x[prop]
				end)
				if ok and value ~= nil then
					rawget(c, "_props")[prop] = value
				end
			end
			for k, v in x:GetAttributes() do
				rawget(c, "_attrs")[k] = v
			end
			for _, child in x:GetChildren() do
				copy(child).Parent = c
			end
			return c
		end
		local fake = copy(root)
		for original, c in map do
			for _, prop in { "Part0", "Part1", "PrimaryPart" } do
				local ok, value = pcall(function()
					return original[prop]
				end)
				if ok and value and map[value] then
					rawget(c, "_props")[prop] = map[value]
				end
			end
		end
		return fake
	end

	-- The DataModel.
	local workspace = fakeNew("Workspace", "Workspace")
	function workspace:GetServerTimeNow()
		return SERVER_OFFSET + clockNow
	end
	local camera = fakeNew("Camera", "Camera")
	camera.ViewportSize = roblox.Vector2.new(844, 390)
	camera.FieldOfView = 70
	workspace.CurrentCamera = camera
	local ORIGIN = Vector3.new(280.28, 37467.06, -1781.14)
	camera.CFrame = CFrame.new(ORIGIN + Vector3.new(0, 8, 20))

	-- The lobby's Eggman in his Egg Mobile (the World 1 place the build wrote), tagged as LobbyNpcs does.
	local place = roblox.deserializePlace(fs.readFile("World1Update3New.rbxl"))
	local lobbyFolder = place:GetService("Workspace"):FindFirstChild("LobbyCharacters")
	assert(lobbyFolder and lobbyFolder:FindFirstChild("Eggman"), "World1Update3New.rbxl: Workspace.LobbyCharacters.Eggman")
	local eggmanSource = lobbyFolder:FindFirstChild("Eggman")
	assert(eggmanSource:FindFirstChild("EggMobile"), "the lobby Eggman has his Egg Mobile")
	local characters = fakeNew("Folder", "LobbyCharacters")
	characters.Parent = workspace
	local lobbyEggman = fromLune(eggmanSource)
	rawget(lobbyEggman, "_tags")["LobbyNpcEggman"] = true
	lobbyEggman:SetAttribute("LobbyNpc", "Eggman")
	lobbyEggman.Parent = characters
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart" -- as the server's PrepareOwnerModel leaves it
		end
	end
	local lobbyBeam = fakeNew("Beam", "EggPlasmaCone") -- what the lobby client adds
	lobbyBeam.Parent = lobbyEggman:FindFirstChild("EggMobile"):FindFirstChild("EggHull")

	-- ReplicatedStorage: the Shared modules, the remote, the event's assets (the imported VFX).
	local replicated = fakeNew("ReplicatedStorage", "ReplicatedStorage")
	local shared = fakeNew("Folder", "Shared")
	shared.Parent = replicated
	local remotes = fakeNew("Folder", "Remotes")
	remotes.Parent = replicated
	local remote = fakeNew("RemoteEvent", "SuperSonicEvent")
	remote.Parent = remotes
	local fired = {}
	function remote:FireServer(...)
		table.insert(fired, table.pack(...))
	end
	local assets = fakeNew("Folder", "SuperSonicEventAssets")
	assets.Parent = replicated
	local vfx = fakeNew("Folder", "VFX")
	vfx.Parent = assets
	fakeNew("Folder", "Meshes").Parent = assets
	for name, file in { BombExplode = "BombExplodeVFX", EggImpact = "EggImpactDefaultVFX", FireTrail = "FireTrailParticlesPart", BurstHatch = "BurstHatchVFX" } do
		local root = roblox.deserializeModel(fs.readFile("assets/vfx_imported/" .. file .. ".rbxm"))[1]
		local fake = fromLune(root)
		fake.Name = name
		fake.Parent = vfx
	end

	-- The fakes of the modules that need the engine.
	local punches = {}
	local CameraPunchFake = {
		Shake = function(duration, strength)
			table.insert(punches, { "Shake", duration, strength })
		end,
		Fov = function(size)
			table.insert(punches, { "Fov", size })
		end,
	}
	local hudVisibility = { Event = newSignal() }
	-- (v3) MenuEvents.SetHUDVisible: recorded, and fired to its listeners as the real one does.
	local hudCalls = {}
	local menuEventsFake = {
		HUDVisibilityChanged = hudVisibility,
		SetHUDVisible = function(visible, menuName)
			table.insert(hudCalls, { visible == true, menuName })
			hudVisibility.Event:Fire(visible == true, menuName)
		end,
	}
	local SSEProxy = setmetatable({
		IsOn = function()
			return workspace:GetAttribute(SSE.KillAttribute) ~= true
		end,
	}, { __index = SSE })
	-- Shared/InterfaceHider needs the engine: a fake that records who holds the interface.
	local hidden = {}
	local InterfaceHiderFake = {
		Hide = function(owner, keep)
			hidden[owner] = keep or {}
		end,
		Show = function(owner)
			hidden[owner] = nil
		end,
		IsHidden = function(except)
			for owner in hidden do
				if owner ~= except then
					return true
				end
			end
			return false
		end,
	}
	local MODULES = {
		SuperSonicEvent = SSEProxy,
		SuperSonicEventFx = Fx,
		SuperSonicLook = Look,
		SuperSonicDialogue = Dialogue,
		SuperSonicCinematic = Cine,
		CinematicFit = CinematicFit,
		InterfaceHider = InterfaceHiderFake,
		CameraPunch = CameraPunchFake,
		RaceFeelTier = require("../src/common/ReplicatedStorage/Shared/RaceFeelTier"),
		HudErgonomics = H,
		EggMobile = require("../src/common/ReplicatedStorage/Shared/EggMobile"),
		LobbyNpcConfig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig"),
		LobbyNpcPose = require("../src/common/ReplicatedStorage/Shared/LobbyNpcPose"),
		LobbyNpcRig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcRig"),
		TutorialText = { ForPlayer = function()
			return "en"
		end, Style = function(label)
			return label
		end },
		Config = { AbilityFlightEnabled = true, IsNewWorld1Map = true },
		MenuEvents = menuEventsFake,
		RaceNoFlight = require("../src/common/ReplicatedStorage/Shared/RaceNoFlight"),
	}
	for name in MODULES do
		local marker = fakeNew("ModuleScript", name)
		marker.Parent = shared
	end
	Look._watch = function(instance, property, callback)
		return instance:GetPropertyChangedSignal(property):Connect(callback)
	end

	-- Players: the local player (the owner's R6 Eggman as a body, wearing an aura) and another player.
	local playersService = fakeNew("Players", "Players")
	local function makePlayer(name, userId, at)
		local p = fakeNew("Player", name)
		p.UserId = userId
		local body = fromLune(eggmanSource)
		body:FindFirstChild("EggMobile"):Destroy()
		body.Name = name
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
			end
		end
		local root = body:FindFirstChild("HumanoidRootPart")
		local delta = CFrame.new(at) * root.CFrame:Inverse()
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		local cosmetics = fakeNew("Folder", "SpeedsterCosmetics")
		local aura = fakeNew("Model", "EquippedAura")
		local holder = fakeNew("Part", "EffectHolder")
		holder.Transparency = 1
		local emitter = fakeNew("ParticleEmitter", "AuraFlame")
		local attachment = fakeNew("Attachment", "AuraAttachment")
		emitter.Parent = attachment
		attachment.Parent = holder
		holder.Parent = aura
		aura.Parent = cosmetics
		cosmetics.Parent = body
		body.Parent = workspace
		p.Character = body
		p.Parent = playersService
		local gui = fakeNew("Folder", "PlayerGui")
		gui.Parent = p
		return p, body, emitter
	end
	local localPlayer, localBody, localAura = makePlayer("Runner", 1001, ORIGIN + Vector3.new(4, 3, 6))
	local otherPlayer, otherBody = makePlayer("Friend", 2002, ORIGIN + Vector3.new(-10, 3, 12))
	playersService.LocalPlayer = localPlayer
	function playersService:GetPlayers()
		return { localPlayer, otherPlayer }
	end
	function playersService:GetPlayerByUserId(id)
		for _, p in { localPlayer, otherPlayer } do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	local playerGui = localPlayer:FindFirstChild("PlayerGui")

	-- Services.
	local tags = { GetTagged = function(_, tag)
		local out = {}
		for _, d in workspace:GetDescendants() do
			if rawget(d, "_tags")[tag] then
				table.insert(out, d)
			end
		end
		return out
	end, GetTags = function(_, instance)
		local out = {}
		for tag in rawget(instance, "_tags") do
			table.insert(out, tag)
		end
		return out
	end, RemoveTag = function(_, instance, tag)
		rawget(instance, "_tags")[tag] = nil
	end }
	local bound = {}
	local cas = {
		BindActionAtPriority = function(_, name, fn, touch, priority, ...)
			bound[name] = { fn = fn, touch = touch, priority = priority, keys = { ... } }
		end,
		UnbindAction = function(_, name)
			bound[name] = nil
		end,
	}
	local runService = fakeNew("RunService", "RunService")
	local uis = fakeNew("UserInputService", "UserInputService")
	uis.TouchEnabled = false
	uis.KeyboardEnabled = true
	function uis:GetFocusedTextBox()
		return nil
	end
	local lastInput = roblox.Enum.UserInputType.Keyboard
	function uis:GetLastInputType()
		return lastInput
	end
	local chat = {}
	local textChat = fakeNew("TextChatService", "TextChatService")
	local channels = fakeNew("Folder", "TextChannels")
	channels.Parent = textChat
	local general = fakeNew("TextChannel", "RBXGeneral")
	general.Parent = channels
	function general:DisplaySystemMessage(text)
		table.insert(chat, text)
	end
	local tweens = 0
	local tweenService = { Create = function(_, instance, _info, goal)
		tweens += 1
		local tween = { Completed = newSignal() }
		function tween:Play()
			for k, v in goal do
				instance[k] = v
			end
			fakeTask.defer(function()
				tween.Completed:Fire()
			end)
		end
		function tween:Cancel() end
		return tween
	end }
	local lighting = fakeNew("Lighting", "Lighting")
	local soundService = fakeNew("SoundService", "SoundService")
	local lobbyMusic = fakeNew("Sound", "SpeedsterBackgroundMusic") -- Audio/BackgroundMusic's playlist
	lobbyMusic.Parent = soundService
	local services = {
		CollectionService = tags, ContextActionService = cas,
		GuiService = { MenuIsOpen = false, GetGuiInset = function()
			return roblox.Vector2.new(0, 36), roblox.Vector2.new(0, 0)
		end },
		Players = playersService, ReplicatedStorage = replicated, RunService = runService, SoundService = soundService,
		TextChatService = textChat, TweenService = tweenService, UserInputService = uis, Workspace = workspace, Lighting = lighting,
	}
	local game = { GetService = function(_, name)
		return (assert(services[name], "fake service " .. tostring(name)))
	end }
	local warnings = {}
	local env = setmetatable({
		game = game,
		workspace = workspace,
		Instance = { new = fakeNew },
		task = fakeTask,
		os = setmetatable({ clock = function()
			return clockNow
		end }, { __index = os }),
		require = function(marker)
			return (assert(MODULES[marker.Name], "fake require " .. tostring(marker)))
		end,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
		TweenInfo = { new = function(...)
			return { ... }
		end },
		Enum = roblox.Enum, Vector3 = Vector3, Vector2 = roblox.Vector2, CFrame = CFrame, Color3 = Color3, UDim = roblox.UDim,
		UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Font = roblox.Font,
	}, { __index = _G })

	-- The camera as the player's own camera scripts leave it.
	local humanoid = localBody:FindFirstChildOfClass("Humanoid")
	camera.CameraType = roblox.Enum.CameraType.Custom
	camera.CameraSubject = humanoid

	-- Run the script (as a LocalScript: on its own thread).
	local chunk = luau.load(client, { debugName = "SuperSonicEventClient", environment = env })
	fakeTask.spawn(chunk)
	assert(#warnings == 0, "no warnings at start: " .. table.concat(warnings, "; "))
	local function frames(count, dt)
		dt = dt or 1 / 60
		for _ = 1, count do
			clockNow += dt
			runScheduler()
			runService.Stepped:Fire(clockNow, dt)
			runService.RenderStepped:Fire(dt)
			for _, step in table.clone(renderSteps) do
				step.fn(dt)
			end
		end
	end
	local function seconds(s)
		frames(math.ceil(s * 60))
	end
	local function now()
		return SERVER_OFFSET + clockNow
	end
	local function send(message)
		remote.OnClientEvent:Fire(message)
	end
	local function runtime()
		return workspace:FindFirstChild(Fx.FolderName)
	end
	local function screen()
		return playerGui:FindFirstChild(Fx.ScreenGuiName)
	end
	local function plan()
		return SSE.PlanFromAttributes(function(name)
			return workspace:GetAttribute(name)
		end)
	end
	-- How many times the sounds of `kind` played (all their voices).
	local function played(kind)
		local n = 0
		for _, child in soundService:GetChildren() do
			if child.Name == "SSE_" .. kind then
				n += child._played
			end
		end
		return n
	end
	local function currentHumanoid()
		local body = localPlayer.Character
		return body and body:FindFirstChildOfClass("Humanoid")
	end
	local function cinematicOn()
		return camera.CameraType == roblox.Enum.CameraType.Scriptable and hidden[Fx.InterfaceOwner] ~= nil
			and localPlayer:GetAttribute(Fx.CinematicAttribute) == true and renderSteps[Fx.RenderName] ~= nil
	end
	local function cameraBack(label)
		assert(camera.CameraType == roblox.Enum.CameraType.Custom, label .. ": the camera's type back (" .. tostring(camera.CameraType) .. ")")
		assert(camera.CameraSubject == currentHumanoid(), label .. ": the camera follows the player's humanoid again")
		assert(hidden[Fx.InterfaceOwner] == nil, label .. ": the interface back")
		assert(renderSteps[Fx.RenderName] == nil, label .. ": the camera step unbound")
		assert(localPlayer:GetAttribute(Fx.CinematicAttribute) == nil, label .. ": the cinematic attribute cleared")
		local s = screen()
		if s then
			assert(s:FindFirstChild("BarTop").Size.Y.Scale == 0, label .. ": the letterbox away")
		end
	end
	local function dialogue()
		local s = screen()
		local holder = s and s:FindFirstChild("Dialogue")
		local box = holder and holder:FindFirstChild("Box")
		return holder, box and box:FindFirstChild("Text")
	end
	local function saying(key)
		local holder, text = dialogue()
		return holder ~= nil and holder.Visible and text.Text == Dialogue.Line("en", key)
	end
	frames(5)
	assert(runtime() == nil and playerGui:FindFirstChild(Fx.GuiName) == nil and screen() == nil, "nothing drawn without an event")

	-- The event starts (the server's attribute order: Origin, EventId, Seed, EventStart, LiftOff, HP, PhaseStart, Phase).
	local function phase(name)
		workspace:SetAttribute(SSE.Attributes.PhaseStart, now())
		workspace:SetAttribute(SSE.Attributes.Phase, name)
	end
	local lobbyHull = lobbyEggman:FindFirstChild("EggMobile"):FindFirstChild("EggHull")
	local LIFT = lobbyHull.Position
	local function startEvent(id)
		workspace:SetAttribute(SSE.Attributes.Origin, ORIGIN)
		workspace:SetAttribute(SSE.Attributes.EventId, id)
		workspace:SetAttribute(SSE.Attributes.Seed, 12345)
		workspace:SetAttribute(SSE.Attributes.EventStart, now())
		workspace:SetAttribute(SSE.Attributes.LiftOff, LIFT)
		workspace:SetAttribute(SSE.Attributes.BossMaxHP, 66)
		workspace:SetAttribute(SSE.Attributes.BossHP, 66)
		phase("Cinematic")
	end
	local function clearEvent()
		for _, name in { "PhaseStart", "EventId", "Seed", "BossHP", "BossMaxHP", "Origin", "EventStart", "LiftOff", "CrashPoint", "LobbyOrigin" } do
			workspace:SetAttribute(SSE.Attributes[name], nil)
		end
		workspace:SetAttribute(SSE.Attributes.Phase, "")
	end
	-- (The steps below are do-blocks: the fake Roblox above already holds many locals.)
	local folder, gui, bossModel, localRoot, torso, torsoBefore, gold, vignette, alert
	local startCam = camera.CFrame
	startEvent(7)
	frames(30)
	do
	folder = runtime()
	assert(folder, "the event's folder")
	bossModel = folder:FindFirstChild("SSE_EggmanBoss")
	assert(bossModel and bossModel:FindFirstChild("EggMobile"), "the boss is the lobby Eggman's clone, ship and all")
	for _, d in bossModel:GetDescendants() do
		assert(not d:IsA("Highlight") and not d:IsA("PointLight") and not d:IsA("ProximityPrompt") and not d:IsA("Script"), "stripped: " .. d:GetFullName())
		assert(next(rawget(d, "_tags")) == nil, "no lobby tag on the clone: " .. d:GetFullName())
		if d:IsA("BasePart") then
			assert(not d.CanCollide and not d.CanQuery and not d.CanTouch, "the boss collides with nothing: " .. d.Name)
			assert(d:GetAttribute("EggCollider") ~= true, "the lobby colliders are gone")
		end
		assert(not (d:IsA("Beam") and d.Name == "EggPlasmaCone"), "the lobby client's beams are not cloned")
	end
	assert(bossModel:GetScale() == Fx.Boss.Scale, "scaled x" .. Fx.Boss.Scale)
	assert(bossModel:FindFirstChild("SSE_CannonBarrel") or bossModel:FindFirstChild("SSE_Cannon"), "a cannon under the hull")
	assert(bossModel:FindFirstChild("SSE_Shield"), "his shield bubble (ForceField)")
	assert(bossModel:FindFirstChild("SSE_Shield").Material == roblox.Enum.Material.ForceField, "a ForceField material, no texture")
	-- He lifts off from his lobby spot: the ship on the contract's plan.
	local root = bossModel:FindFirstChild("HumanoidRootPart")
	local expect = SSE.BossPosition(ORIGIN, now(), plan())
	assert((root.Position - expect).Magnitude < 12, "the boss on the plan's path (" .. (root.Position - expect).Magnitude .. ")")
	assert((SSE.BossPosition(ORIGIN, now() - 0.5, plan()) - LIFT).Magnitude < 1, "the path starts at his lobby spot (SSE_LiftOff)")
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			assert(d.LocalTransparencyModifier == 1, "the lobby Eggman hidden: " .. d.Name)
		end
	end
	assert(lobbyBeam.Enabled == false, "the lobby ship's plasma beam off")
	assert(#chat == 1 and string.find(chat[1], Fx.Text.en.ChatStart, 1, true), "the start line in the chat")
	gui = playerGui:FindFirstChild(Fx.GuiName)
	assert(gui and gui.Enabled, "the HUD")
	assert(gui:FindFirstChild("BossBar").Visible == false, "no HP bar before the Battle")
	assert(bound[Fx.Inputs.Action] == nil, "no homing input before the Battle")
	-- The opening cinematic: the camera is the shot's, the interface away (the screen kept), the letterbox, the shake.
	assert(cinematicOn(), "the intro cinematic has the camera")
	local keep = hidden[Fx.InterfaceOwner]
	assert(keep[1] == screen(), "the cinematic keeps its own screen (the bars, the dialogue)")
	assert(screen():FindFirstChild("BarTop").Size.Y.Scale > 0.04, "the letterbox is in")
	assert((camera.CFrame.Position - startCam.Position).Magnitude > 1, "the camera moves toward him")
	-- The music: "Eggman's Revenge" in its own group, the lobby playlist silenced.
	local music = soundService:FindFirstChild(Fx.Music.SoundName)
	assert(music and music.SoundId == Fx.Music.Id and music.Looped and music._played == 1 and music.SoundGroup and music.SoundGroup.Name == Fx.Music.GroupName,
		"the event's music loops in its own group")
	assert(lobbyMusic:GetAttribute(Fx.Music.SilenceAttribute) == true, "the lobby playlist fades out under it")
	assert(music.Volume > 0 and music.Volume < Fx.Music.Volume, "fading in (" .. tostring(music.Volume) .. ")")
	-- 2026-09-26 (owner, v3): the player stands still through the Intro (its freeze window), the HUD slides away as
	-- for a menu (the topbar is never touched).
	local introRoot = localBody:FindFirstChild("HumanoidRootPart")
	assert(introRoot.Anchored == true and introRoot.AssemblyLinearVelocity == Vector3.zero and localPlayer:GetAttribute(Fx.FreezeAttribute) == true,
		"frozen for the Intro (anchored locally, velocity 0)")
	assert(#hudCalls >= 1 and hudCalls[1][1] == false and hudCalls[1][2] == Fx.HudHide.MenuName, "the HUD held away (MenuEvents.SetHUDVisible(false))")
	hasNot((string.gsub(client, "%-%-[^\n]*", "")), "TopbarPlus", "the topbar is never touched (by the code)")
	-- His lines, on the contract's cues: "Sonic! ..." at 0.8 s, typing out; "revenge!" at 3.9 s.
	seconds(0.4)
	local shook = false
	for _, p in punches do
		if p[1] == "Shake" and p[2] == 0.8 then
			shook = true
		end
	end
	assert(shook, "the lift-off shakes the screen")
	assert(saying("EggmanSonic"), "\"SONIC! ...\" at 0.8 s")
	local _, text = dialogue()
	assert(text.MaxVisibleGraphemes < Dialogue.Graphemes(text.Text), "typing out")
	seconds(3.2)
	assert(saying("EggmanRevenge"), "\"I'll have my REVENGE!\" at 3.9 s")
	assert(cinematicOn(), "still his cinematic")
	seconds(3.5)
	cameraBack("after the intro")
	assert(not saying("EggmanSonic"), "the first line is gone")
	assert(introRoot.Anchored == false and localPlayer:GetAttribute(Fx.FreezeAttribute) == nil, "free again after the window, exactly as before")
	-- The chaos: the grade under Lighting: a light warm one (v3: toned down).
	local grade = lighting:FindFirstChild(Fx.GradeName)
	assert(grade and grade.Enabled and grade.TintColor ~= Color3.new(1, 1, 1) and grade.Saturation <= Fx.Chaos.Grade.Saturation + 1e-9, "the light warm grade")
	-- The dialogue: plain text beside a small round portrait (no box, no name tab).
	local dlg = screen():FindFirstChild("Dialogue")
	local dlgBox = dlg:FindFirstChild("Box")
	assert(dlgBox.BackgroundTransparency == 1 and dlgBox:FindFirstChild("NameTab") == nil and dlgBox:FindFirstChildOfClass("UIStroke") == nil, "no box, no name tab")
	assert(dlgBox:FindFirstChild("Portrait") and dlgBox:FindFirstChild("Portrait").Size.X.Offset <= 48, "a small round portrait")
	end

	-- Bombard: a Parallel salvo announced ("PARALLEL ATTACK!" in his voice), the bombs out of the barrel with a
	-- white muzzle flash, their red zones, the whistle and the alarm; the blast at the impact; the zones fade.
	do
	phase("Bombard")
	frames(2)
	assert(gui:FindFirstChild("Banner") == nil, "(v3) no phase banner")
	assert(saying("EggmanRevenge"), "a cinematic line is never cut short by a lesser one")
	local waited = 0
	while not saying("EggmanBombard") and waited < 180 do
		frames(1)
		waited += 1
	end
	assert(saying("EggmanBombard"), "he laughs the bombs in once his line is over (" .. waited .. " frames)")
	localRoot = localBody:FindFirstChild("HumanoidRootPart")
	frames(10)
	local p = plan()
	local from = SSE.CannonPosition(ORIGIN, now(), p)
	local target = localRoot.Position + Vector3.new(3, -3, 0)
	local flight = SSE.BombFlightTime(from, target)
	local voiceBefore = played("VoiceParallel")
	send({ SSE.Messages.Bomb, 1, from, target, now(), flight, SSE.BombPatterns.Parallel, SSE.Warning.Radius })
	send({ SSE.Messages.Bomb, 2, from, target + Vector3.new(30, 0, 0), now(), flight, SSE.BombPatterns.Parallel, SSE.Warning.Radius })
	frames(3)
	assert(saying("EggmanParallel") and played("VoiceParallel") == voiceBefore + 1, "\"PARALLEL ATTACK!\" with the owner's clip")
	local bombsDrawn, zones = 0, 0
	for _, d in folder:GetChildren() do
		if d.Name == "SSE_Bomb" then
			bombsDrawn += 1
			assert((d.Position - from).Magnitude < Fx.Bomb.BarrelDepth * Fx.Boss.Scale + 1, "the bomb leaves the barrel's mouth")
		elseif d.Name == "SSE_Warning" then
			zones += 1
			near(d.Size.X, SSE.Warning.Radius * 2 * Fx.Warning.Span, 1e-6, "the zone's part spans the blast")
			assert(d:FindFirstChild("SSE_Zone") and d:FindFirstChild("SSE_Zone"):IsA("SurfaceGui"), "the red ring drawn with a SurfaceGui")
		end
	end
	assert(bombsDrawn == 2 and zones == 2, ("2 bombs in the air over their red zones (%d, %d)"):format(bombsDrawn, zones))
	local muzzled = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "SSE_Muzzle" then
			muzzled += d._emitted
			assert(d.Color.Keypoints[1].Value == Color3.new(1, 1, 1), "the muzzle flash is white")
		end
	end
	assert(muzzled > 0, "the white muzzle flash fired")
	assert(played("BombWhistle") >= 1, "the fall's whistle")
	local punchesBefore = #punches
	local ticksBefore = played("AlarmTick")
	frames(math.ceil(flight * 60) + 2)
	assert(played("AlarmTick") >= ticksBefore + 3, "the alarm ticks faster near the impact")
	local emitted = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Parent and string.sub(d.Parent.Parent.Name, 1, 9) == "SSE_Blast" then
			emitted += d._emitted
		end
	end
	assert(emitted > 0, "the blast's emitters fired")
	local burning, fireEmitter, ambient = 0, nil, 0
	for _, d in folder:GetChildren() do
		if d.Name == "FireTrail" then
			local atBlast = Vector3.new(d.Position.X - target.X, 0, d.Position.Z - target.Z).Magnitude <= Fx.Bomb.FirePatchRadius + 0.5
			for _, e in d:GetDescendants() do
				if e:IsA("ParticleEmitter") and e.Enabled then
					if atBlast then
						burning += 1
						fireEmitter = fireEmitter or e
					else
						ambient += 1
					end
				end
			end
		end
	end
	assert(ambient > 0, "(v2) the lobby burns round the fight (ambient patches)")
	assert(burning > 0, "a fire patch burns")
	assert(#punches > punchesBefore and punches[punchesBefore + 1][1] == "Shake", "the camera punch of a blast nearby")
	local fading = 0
	for _, d in folder:GetChildren() do
		assert(d.Name ~= "SSE_Bomb", "the bombs are back in their pool")
		if d.Name == "SSE_Warning" then
			fading += 1
		end
	end
	assert(fading == 2, "the red zones fade out after the blast (still there)")
	frames(30)
	for _, d in folder:GetChildren() do
		assert(d.Name ~= "SSE_Warning", "then back in their pool")
	end
	send({ SSE.Messages.BombHit, 1, target })
	send({ SSE.Messages.BombHit, 55, target + Vector3.new(0, 0, 20) }) -- one this client never saw leave
	-- The fire patches fade before they go out (5 s).
	local baseRate = fireEmitter.Rate
	seconds(SSE.Bombard.FirePatchSeconds - 0.6)
	assert(fireEmitter.Enabled and fireEmitter.Rate < baseRate, "a patch fades (its rate falls) before it goes out")
	seconds(1.4)
	assert(not fireEmitter.Enabled, "then goes out")
	-- 2026-09-26 (owner, v3): the burn: a short one-shot now and then (random gaps of several seconds), never two at
	-- once, never a loop.
	do
		local plays, last = {}, played("Burn")
		for _ = 1, 60 * 45 do
			frames(1)
			local n = played("Burn")
			if n > last then
				table.insert(plays, now())
				last = n
			end
		end
		assert(#plays >= 2 and #plays <= math.ceil(45 / (Fx.Burn.Seconds + Fx.Burn.GapMin)) + 1, "a burn now and then (" .. #plays .. " in 45 s)")
		for index = 2, #plays do
			local gap = plays[index] - plays[index - 1]
			assert(gap >= Fx.Burn.Seconds + Fx.Burn.GapMin - 0.05 and gap <= Fx.Burn.Seconds + Fx.Burn.GapMax + 1.1, ("gaps of several seconds (%.2f)"):format(gap))
		end
		local burnSound = soundService:FindFirstChild("SSE_Burn")
		assert(burnSound and burnSound.Looped == false, "a one-shot, not a loop")
		local voices = 0
		for _, child in soundService:GetChildren() do
			if child.Name == "SSE_Burn" then
				voices += 1
			end
		end
		assert(voices == 1, "one voice: never two at once")
	end
	-- Knock: the victim's own client throws its root.
	send({ SSE.Messages.Knock, Vector3.new(30, 42, -10), 2 })
	assert(localRoot.AssemblyLinearVelocity == Vector3.new(30, 42, -10), "Knock sets the root's velocity")
	localRoot.AssemblyLinearVelocity = Vector3.zero
	end

	-- Emeralds: 7 round the local player (lit, glowing and trailing in their colours), 7 round the other; the
	-- emeralds' cinematic round the local player; the absorption; the camera back.
	do
	phase("Emeralds")
	frames(2)
	assert(saying("EggmanEmeralds"), "\"The Chaos Emeralds?! NO!\"")
	assert(cinematicOn(), "the emeralds' cinematic")
	local gems, lit, trails = 0, 0, 0
	for _, d in folder:GetChildren() do
		if d.Name == "SSE_Emerald" then
			gems += 1
			local light = d:FindFirstChildOfClass("PointLight")
			assert(light and light.Range == 14 and light.Brightness == 2.5, "each gem carries its PointLight")
			if light.Enabled then
				lit += 1
			end
			local trail = d:FindFirstChild("SSE_GemTrail")
			assert(trail, "each gem has its trail")
			if trail.Enabled then
				trails += 1
				assert(trail.Color.Keypoints[2].Value == d.Color, "the trail in the gem's colour")
			end
			local fxAttachment = d:FindFirstChild("SSE_GemFx")
			assert(fxAttachment and #fxAttachment:GetChildren() > 0, "the gem's glow / embers (BurstHatch's)")
		end
	end
	assert(gems == 14 and lit == 7 and trails >= 7, ("7 gems each, the local ones lit and trailing (%d gems, %d lit, %d trails)"):format(gems, lit, trails))
	seconds(SSE.Emeralds.AbsorbAt)
	for _, d in folder:GetChildren() do
		assert(d.Name ~= "SSE_Emerald", "the gems are absorbed")
	end
	assert(gui:FindFirstChild("GoldenFlash"), "the golden flash")
	seconds(Cine.Length("Emeralds") - SSE.Emeralds.AbsorbAt + 0.1)
	cameraBack("after the emeralds")
	end
	-- The server turns both Super; the other wears the game's Super Sonic skin (SSE_Skin): no old glaze on him.
	do
	torso = localBody:FindFirstChild("Torso")
	torsoBefore = torso.Color
	local otherTorso = otherBody:FindFirstChild("Torso")
	local otherBefore = otherTorso.Color
	otherPlayer:SetAttribute(SSE.PlayerAttributes.Skin, "SuperSonicSuit")
	otherPlayer:SetAttribute("SkinOverride", "SuperSonicSuit")
	localPlayer:SetAttribute(SSE.PlayerAttributes.Super, true)
	otherPlayer:SetAttribute(SSE.PlayerAttributes.Super, true)
	frames(2)
	gold = Color3.fromRGB(Fx.Gold[1], Fx.Gold[2], Fx.Gold[3])
	assert(torso.Color == gold, "the local player (no skin) is gold")
	assert(otherTorso.Color == otherBefore, "the skinned player keeps the skin's colours")
	for _, d in otherBody:GetDescendants() do
		assert(d.Name ~= "SSE_Shell" and d.Name ~= "SSE_Eye", "no old glaze or eyes over the skin: " .. d.Name)
	end
	-- He equips a skin of his own: the skin system clears SkinOverride; the old look is drawn again, then the skin back.
	otherPlayer:SetAttribute("SkinOverride", nil)
	frames(1)
	assert(otherTorso.Color == gold, "his own skin: the old gold look")
	otherPlayer:SetAttribute("SkinOverride", "SuperSonicSuit")
	frames(1)
	assert(otherTorso.Color == otherBefore, "the Super Sonic skin again: no gold")
	assert(localAura.Enabled == true and localAura.Parent.Parent.Name == "EffectHolder", "the aura untouched")
	vignette = playerGui:FindFirstChild(Fx.VignetteGuiName)
	assert(vignette and not vignette.Enabled, "no golden vignette before the Battle")
	end

	-- Battle: F / X bound; his shield up in the first Attack window; a charged attack glances off it.
	-- 2026-09-26 (owner, v3): the charge fills in the contract's 0.7 s; ONE trail wraps the ball; the bounce off the
	-- shield is a real knock-back with the zap and his taunt; the damaging hit: the hit-stop, the white flash and
	-- "hit!" exactly when the server's acceptance and the connection meet; the jump's instant attack; "(A)" / "(X)".
	do
	local battleStart = now()
	phase("Battle")
	frames(2)
	assert(bound[Fx.Inputs.Action], "F / X bound in the Battle")
	local keys = {}
	for _, key in bound[Fx.Inputs.Action].keys do
		keys[key.Name] = true
	end
	assert(keys.F and keys.ButtonX and not keys.Space and not keys.ButtonA, "the bound keys: F and X (A stays the jump)")
	local bar = gui:FindFirstChild("BossBar")
	assert(bar.Visible and bar:FindFirstChild("Hp").Text == "66 / 66", "the HP bar")
	assert(saying("EggmanSuper"), "\"S-SUPER SONIC?!\"")
	seconds(0.8)
	assert(vignette.Enabled, "the golden vignette while Super")
	-- The boss bar in the game's HUD style: small, a glass track with the ink outline, no words but his name and HP.
	assert(bar:FindFirstChild("State") == nil and gui:FindFirstChild("Banner") == nil and gui:FindFirstChild("Notice") == nil,
		"no \"SHIELD UP\", no banner, no notice")
	local track = bar:FindFirstChild("Track")
	local ink = Color3.fromRGB(Fx.Style.Ink[1], Fx.Style.Ink[2], Fx.Style.Ink[3])
	assert(track and track:FindFirstChildOfClass("UIStroke").Color == ink and track:FindFirstChildOfClass("UICorner"), "the HUD's ink outline and round corners")
	assert(math.abs(track.BackgroundTransparency - Fx.Style.GlassTransparency) < 1e-4 and bar.Size.Y.Offset <= 40 and bar.Size.X.Scale <= 0.3 + 1e-4,
		"small glass bar at the top")
	assert(bar:FindFirstChild("Title").Text == Fx.Text.en.BossName, "his name over it")
	local cue = bar:FindFirstChild("Cue")
	assert(cue and not cue.Visible, "no \"ATTACK NOW!\" while he attacks")
	alert = playerGui:FindFirstChild("SSE_Alert")
	assert(alert and not alert.Enabled, "no \"!\" while he attacks")
	assert(alert:FindFirstChild("Words") == nil, "(v3) the \"!\" has no words")
	-- Hold F: { Charge, t }, the charge sound, the ball round the player, ONE big trail wrapping it, the ring.
	local fired0 = #fired
	local chargeSound0 = played("ChargeStart")
	local result = bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {})
	assert(result == roblox.Enum.ContextActionResult.Sink, "F held: the charge begins")
	assert(#fired == fired0 + 1 and fired[#fired][1][1] == SSE.Messages.Charge and math.abs(fired[#fired][1][2] - now()) < 1e-6, "{ \"Charge\", clientTime } sent")
	assert(played("ChargeStart") == chargeSound0 + 1, "the charge sound (\"sonicballdashstart\")")
	frames(1)
	assert(localBody:FindFirstChild("Head").LocalTransparencyModifier == 1, "the body inside the spinning ball")
	local ringFrame = screen():FindFirstChild("ChargeRing")
	assert(ringFrame:FindFirstChild("Label") == nil, "the ring has no words")
	local half = SSE.Homing.ChargeSeconds * 0.5
	seconds(half)
	assert(ringFrame.Visible, "the charge ring")
	local litSegments = 0
	for _, seg in ringFrame:GetChildren() do
		if seg.Name == "Segment" and seg.BackgroundTransparency == 0 then
			litSegments += 1
		end
	end
	local expectLit = Fx.ChargeSegments((half + 2 / 60) / SSE.Homing.ChargeSeconds)
	assert(math.abs(litSegments - expectLit) <= 2, ("the ring half full (%d of %d, expected %d)"):format(litSegments, Fx.Charge.RingSegments, expectLit))
	local holderPart = folder:FindFirstChild("SSE_BallHolder")
	local tailPart = folder:FindFirstChild("SSE_BallTail")
	local beams = 0
	for _, piece in { holderPart, tailPart } do
		for _, d in piece:GetDescendants() do
			if d:IsA("Beam") then
				beams += 1
			end
		end
	end
	local trail = holderPart:FindFirstChild("SSE_BallTrail")
	assert(beams == 1 and trail and trail.Enabled and trail.Texture == Fx.Textures.SpeedTrail, "ONE trail (the owner's Beam113) on the ball (" .. beams .. " beams)")
	assert(trail.Width0 >= Fx.Homing.BallSize * 0.6 and trail.CurveSize0 > 0 and trail.CurveSize1 > 0, "wide, curved round the ball")
	assert(trail.Attachment1 and trail.Attachment1.Parent == holderPart, "both ends on the ball while charging (it wraps it)")
	assert(holderPart:FindFirstChild("SSE_SpeedLine") == nil, "no swirl of small speed lines")
	-- Release: { Homing, t, charge01 }, the dash to the intercept; he is shielded: it bounces off.
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {})
	local homing = fired[#fired][1]
	assert(homing[1] == SSE.Messages.Homing and math.abs(homing[2] - now()) < 1e-6 and math.abs(homing[3] - (half + 2 / 60) / SSE.Homing.ChargeSeconds) < 0.08,
		"{ \"Homing\", clientTime, charge01 } sent (" .. tostring(homing[3]) .. ")")
	assert(humanoid.PlatformStand == true and localBody:GetAttribute("SonicBurstDashLocal") == true, "the flight owns the body")
	assert(not ringFrame.Visible, "the ring goes at the release")
	assert(trail.Attachment1 and trail.Attachment1.Parent == tailPart and trail.CurveSize1 == 0, "in flight the trail streams back to the path behind")
	local zaps, shieldVoice, hitsBefore = played("ShieldZap"), played("VoiceShielded"), played("HomingHit")
	local bounced = false
	for _ = 1, 120 do
		frames(1)
		if played("ShieldZap") > zaps then
			bounced = true
			break
		end
	end
	assert(bounced, "the dash reaches his shield")
	local v = localRoot.AssemblyLinearVelocity
	local ship = SSE.BossPosition(ORIGIN, now(), plan())
	near(v.Y, SSE.Shield.KnockUp, 1e-6, "knocked up")
	near(Vector3.new(v.X, 0, v.Z).Magnitude, SSE.Shield.KnockOut, 1e-3, "and back a fair distance (the contract's ShieldKnock)")
	assert(played("HomingHit") == hitsBefore, "no \"hit!\" off the shield")
	assert(saying("EggmanShielded") and played("VoiceShielded") == shieldVoice + 1, "\"What are you doing? I'm right here!\" at the bounce")
	assert(humanoid.PlatformStand == true, "flying free, curled in the ball")
	seconds(Fx.Homing.ShieldKnockSeconds + 0.05)
	assert(humanoid.PlatformStand == false and localBody:FindFirstChild("Head").LocalTransparencyModifier == 0, "then the body back")
	assert(ship ~= nil)
	-- The server's word at its arrival: "Shielded" and the shield's Knock: the same bounce, not a second one.
	localRoot.AssemblyLinearVelocity = Vector3.new(1, 2, 3)
	send({ SSE.Messages.HomingNo, SSE.HomingRefusals.Shielded })
	send({ SSE.Messages.Knock, Vector3.new(50, 30, 0), 0, SSE.KnockKinds.Shield })
	frames(1)
	assert(localRoot.AssemblyLinearVelocity == Vector3.new(1, 2, 3), "the server's shield Knock is the bounce already drawn")
	assert(played("VoiceShielded") == shieldVoice + 1, "one taunt")
	assert(gui:FindFirstChild("Notice") == nil, "no notice on the screen")
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- The Reload window: the cannon in, the small "!" over him, the tiny "ATTACK NOW!" under the bar.
	local stateNow = SSE.BossState(0, 12345)
	assert(stateNow == "Attack", "the Battle opens with an Attack window")
	local firstReload = SSE.BossWindows(12345)[2]
	assert(firstReload.state == "Reload", "then a Reload window")
	while now() - battleStart < firstReload.start + 0.3 do
		frames(1)
	end
	assert(alert.Enabled, "the \"!\" over him while he reloads")
	assert(cue.Visible and cue.Text == Fx.Text.en.Vulnerable, "the tiny \"ATTACK NOW!\" under the bar")
	assert(played("CannonMove") >= 1, "the cannon's clunk")
	-- A full charge (held past ChargeSeconds: released by itself when the charge ends), accepted by the server: the
	-- dash, the hit-stop on the hull with "hit!" at that very moment, the white flash, the snappy bounce.
	local hits = played("HomingHit")
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {})
	seconds(SSE.Homing.ChargeSeconds + 0.05)
	local full = fired[#fired][1]
	assert(full[1] == SSE.Messages.Homing and full[3] == 1, "the charge's end releases it at full charge (" .. SSE.Homing.ChargeSeconds .. " s)")
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {}) -- (the late release: nothing)
	assert(fired[#fired][1] == full, "a release after the auto-release sends nothing")
	send({ SSE.Messages.HomingGo, 1001, localRoot.Position, SSE.BossPosition(ORIGIN, now() + 0.2, plan()), now(), 0.2, 1, 3, false })
	local connected = false
	for _ = 1, 180 do
		frames(1)
		if played("HomingHit") > hits then
			connected = true
			break
		end
	end
	assert(connected and played("HomingHit") == hits + 1, "\"hit!\" exactly when it connects")
	assert(humanoid.PlatformStand == true and localRoot.AssemblyLinearVelocity.Magnitude < 1e-6, "the hit-stop: the ball holds on the hull")
	local flash = gui:FindFirstChild("GoldenFlash")
	assert(flash.Visible and flash.BackgroundColor3 == Color3.new(1, 1, 1), "the white hit flash")
	frames(math.ceil(Fx.Homing.HitStop * 60) + 1)
	assert(humanoid.PlatformStand == false, "the hit-stop is short")
	near(localRoot.AssemblyLinearVelocity.Y, SSE.HomingBounce(Vector3.new(0, 0, -1), 1).Y, 1e-6, "then the snappy bounce (the full charge's)")
	local sawHomingPunch = false
	for _, pn in punches do
		if pn[1] == "Fov" and math.abs(pn[2] - Fx.Charge.Fov[2]) < 1e-6 then
			sawHomingPunch = true
		end
	end
	assert(sawHomingPunch, "the homing hit's punch, as big as the charge")
	-- The server's word: the hit (damage, charge), the reward: the bar moves, no second "hit!".
	workspace:SetAttribute(SSE.Attributes.BossHP, 63)
	send({ SSE.Messages.Hit, 1001, SSE.BossPosition(ORIGIN, now(), plan()), 63, 66, 3, 1, 10 })
	send({ SSE.Messages.Reward, 600, 30000, "hit" })
	frames(2)
	assert(played("HomingHit") == hits + 1, "the server's Hit does not play \"hit!\" again")
	assert(bar:FindFirstChild("Hp").Text == "63 / 66", "HP 63 / 66")
	local popupShown = false
	for _, child in gui:GetChildren() do
		if string.sub(child.Name, 1, 6) == "Reward" and child.Visible and child.Text == "+600 Wins  +30,000 Speed" then
			popupShown = true
		end
	end
	assert(popupShown, "the reward popup")
	-- A quick attack whose acceptance comes late: nothing at the connection, "hit!" when the server agrees.
	seconds(1.1)
	hits = played("HomingHit")
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {})
	frames(4)
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {})
	local stopped = false
	for _ = 1, 120 do
		frames(1)
		if humanoid.PlatformStand == true and localRoot.AssemblyLinearVelocity.Magnitude < 1e-6 then
			stopped = true
			break
		end
	end
	assert(stopped and played("HomingHit") == hits, "a connection the server has not accepted yet: no \"hit!\" yet")
	send({ SSE.Messages.HomingGo, 1001, localRoot.Position, localRoot.Position, now() - 0.1, 0.1, 0.1, 1, false })
	assert(played("HomingHit") == hits + 1, "its acceptance (within the grace): \"hit!\"")
	send({ SSE.Messages.Hit, 1001, SSE.BossPosition(ORIGIN, now(), plan()), 62, 66, 1, 0.1, 3 })
	frames(8)
	assert(played("HomingHit") == hits + 1, "and never twice")
	-- An attack the server says will bounce (shielded): no "hit!", the zap and the knock-back.
	seconds(1.1)
	hits, zaps = played("HomingHit"), played("ShieldZap")
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {})
	frames(4)
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {})
	send({ SSE.Messages.HomingGo, 1001, localRoot.Position, localRoot.Position, now(), 0.1, 0.1, 0, true })
	for _ = 1, 120 do
		frames(1)
		if played("ShieldZap") > zaps then
			break
		end
	end
	assert(played("ShieldZap") == zaps + 1 and played("HomingHit") == hits, "the server's \"shielded\": off the shield, no \"hit!\"")
	seconds(Fx.Homing.ShieldKnockSeconds + 0.05)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- A refused one mid-flight (range): the ball goes at once, silently (no text on the screen).
	seconds(1.2)
	assert(bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {}) == roblox.Enum.ContextActionResult.Sink, "another attack")
	frames(4)
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {})
	frames(1)
	send({ SSE.Messages.HomingNo, SSE.HomingRefusals.Range })
	assert(humanoid.PlatformStand == false and localBody:FindFirstChild("Head").LocalTransparencyModifier == 0, "refused: the body back at once")
	assert(gui:FindFirstChild("Notice") == nil, "no refusal text")
	-- Another player's attack, drawn from HomingGo (to the intercept); their hit from Hit ("hit!" attenuated); their
	-- bounce off the shield from ShieldHit.
	local otherRoot = otherBody:FindFirstChild("HumanoidRootPart")
	send({ SSE.Messages.HomingGo, 2002, otherRoot.Position, SSE.BossPosition(ORIGIN, now() + 0.6, plan()), now(), 0.6, 0.5, 2, false })
	frames(2)
	assert(otherBody:FindFirstChild("Head").LocalTransparencyModifier == 1, "the other player's body behind their ball")
	frames(45)
	assert(otherBody:FindFirstChild("Head").LocalTransparencyModifier == 0, "and back after it")
	hits = played("HomingHit")
	send({ SSE.Messages.Hit, 2002, SSE.BossPosition(ORIGIN, now(), plan()), 61, 66, 2, 0.5, 6 })
	frames(2)
	assert(played("HomingHit") == hits + 1, "another player's damaging hit: \"hit!\" (attenuated)")
	zaps = played("ShieldZap")
	send({ SSE.Messages.ShieldHit, 2002, SSE.BossPosition(ORIGIN, now(), plan()) })
	frames(2)
	assert(played("ShieldZap") == zaps + 1, "their bounce off the shield: the zap")
	-- The other inputs: a click on the interface is nothing; Left Click held in the world charges.
	seconds(1.1)
	local count0 = #fired
	uis.InputBegan:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.Unknown }, true)
	assert(#fired == count0, "a click on the interface is not a homing attack")
	uis.InputBegan:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.Unknown }, false)
	frames(10)
	uis.InputEnded:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.Unknown })
	assert(#fired == count0 + 2 and fired[#fired][1][1] == SSE.Messages.Homing, "Left Click held and released: Charge, then Homing")
	seconds(2.5)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- 2026-09-26 (owner, v3): jump, then JUMP AGAIN in the air = the instant, uncharged attack (Space, gamepad A and
	-- the touch jump button all come as JumpRequest); the jump itself and a held key do nothing.
	local count1 = #fired
	uis.JumpRequest:Fire() -- the jump (on the ground)
	assert(#fired == count1, "the jump itself is not an attack")
	humanoid.FloorMaterial = roblox.Enum.Material.Air
	humanoid:ChangeState(roblox.Enum.HumanoidStateType.Freefall)
	frames(2)
	uis.JumpRequest:Fire() -- (the same key still held: the engine keeps requesting)
	assert(#fired == count1, "a held jump key is one press")
	frames(12)
	uis.JumpRequest:Fire() -- pressed again, in the air
	assert(#fired == count1 + 1 and fired[#fired][1][1] == SSE.Messages.Homing and fired[#fired][1][3] == 0, "{ \"Homing\", t, 0 }: the instant attack")
	assert(fired[#fired - 1][1][1] ~= SSE.Messages.Charge or #fired - 1 <= count1, "no Charge before it")
	assert(humanoid.PlatformStand == true, "the dash at once")
	seconds(2.5)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- The Flight equipped keeps the jump presses where the event does not ground it; the event grounds it here.
	humanoid.FloorMaterial = roblox.Enum.Material.Air
	humanoid:ChangeState(roblox.Enum.HumanoidStateType.Freefall)
	localPlayer:SetAttribute("FlightAbilityOwned", true)
	localPlayer:SetAttribute("FlightAbilityEquipped", true)
	frames(12)
	local count2 = #fired
	uis.JumpRequest:Fire()
	assert(#fired == count2, "the Flight equipped (not grounded by the event): the jump is the flight's")
	localPlayer:SetAttribute("EventFlightBlocked", "SuperSonicEvent")
	frames(12)
	uis.JumpRequest:Fire()
	assert(#fired == count2 + 1 and fired[#fired][1][3] == 0, "the event grounds the Flight: the jump is the homing attack's")
	seconds(2.5)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- The reticle: "(A)" in the air / "(X)" on the ground on a gamepad, nothing on a keyboard.
	lastInput = roblox.Enum.UserInputType.Gamepad1
	uis.LastInputTypeChanged:Fire()
	frames(12)
	local reticle = playerGui:FindFirstChild("SSE_Reticle")
	local prompt = reticle:FindFirstChild("Prompt")
	assert(reticle.Enabled and prompt.Visible and prompt.Text == "(A)", "a gamepad in the air: (A) (" .. tostring(prompt.Text) .. ")")
	humanoid.FloorMaterial = roblox.Enum.Material.Plastic
	humanoid:ChangeState(roblox.Enum.HumanoidStateType.Running)
	frames(12)
	assert(prompt.Visible and prompt.Text == "(X)", "a gamepad on the ground: (X)")
	lastInput = roblox.Enum.UserInputType.Keyboard
	uis.LastInputTypeChanged:Fire()
	frames(12)
	assert(not prompt.Visible and prompt.Text == "", "a keyboard: no prompt, no hint")
	localPlayer:SetAttribute("FlightAbilityOwned", nil)
	localPlayer:SetAttribute("FlightAbilityEquipped", nil)
	localPlayer:SetAttribute("EventFlightBlocked", nil)
	-- The touch button (held to charge).
	uis.TouchEnabled = true
	lastInput = roblox.Enum.UserInputType.Touch
	uis.LastInputTypeChanged:Fire()
	frames(12)
	local button = gui:FindFirstChild("HomingAttack")
	assert(button.Visible, "the touch button shows while locked on (the charge works on the ground)")
	assert(button.Size.X.Offset >= Fx.Button.Min and button.Position.X.Offset > 0, "placed and sized by Fx.HomingButtonRect")
	local count3 = #fired
	local touch = { UserInputType = roblox.Enum.UserInputType.Touch }
	button.InputBegan:Fire(touch)
	frames(10)
	assert(button.Visible, "the button stays while it is held")
	uis.InputEnded:Fire(touch) -- the finger slid off the button
	assert(#fired == count3 + 2 and fired[#fired][1][1] == SSE.Messages.Homing, "the touch button: held and released")
	seconds(2.5)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	-- A menu of the game opened from the topbar: the button makes way; closed: back.
	menuEventsFake.SetHUDVisible(false, "Settings")
	frames(12)
	assert(not button.Visible, "a menu is open: no touch button")
	menuEventsFake.SetHUDVisible(true, nil)
	frames(12)
	assert(button.Visible, "the menu closed: the button again")
	uis.TouchEnabled = false
	lastInput = roblox.Enum.UserInputType.Keyboard
	-- A throw cancels a charge (nothing sent).
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.Begin, {})
	local afterPress = #fired
	send({ SSE.Messages.Knock, Vector3.new(0, 40, 0), 1.2, SSE.KnockKinds.Bomb })
	bound[Fx.Inputs.Action].fn(Fx.Inputs.Action, roblox.Enum.UserInputState.End, {})
	assert(#fired == afterPress and localBody:FindFirstChild("Head").LocalTransparencyModifier == 0, "a throw cancels the charge: nothing launched, the body back")
	assert(localRoot.AssemblyLinearVelocity == Vector3.new(0, 40, 0), "the bomb's throw")
	localRoot.AssemblyLinearVelocity = Vector3.zero
	end

	-- Defeat. 2026-09-26 (owner, v3): THE CRASH: the Egg Mobile dives out of control (the contract's crash path)
	-- trailing smoke and flames, small blasts on the way down, the big chain at the impact with the defeat's punch,
	-- the rings bursting out of the crash point at their burst time ("coinnsdrop"), the wreck fading out; no dialogue;
	-- the outro shot and the freeze inside the Defeat's freeze window, then free to take the rings.
	do
	workspace:SetAttribute(SSE.Attributes.BossHP, 0)
	localRoot.AssemblyLinearVelocity = Vector3.zero
	local crashPoint = ORIGIN + Vector3.new(20, 0, -10)
	workspace:SetAttribute(SSE.Attributes.CrashPoint, crashPoint)
	phase("Defeat")
	local defeatAt = now()
	local times = SSE.CrashTimes(defeatAt)
	send({ SSE.Messages.Defeat, crashPoint, times.impact })
	frames(2)
	assert(cinematicOn(), "the outro cinematic")
	local holder = dialogue()
	assert(holder == nil or not holder.Visible, "no dialogue in the Defeat")
	local p = plan()
	assert(p.crashPoint == crashPoint and p.outcome == "Defeat", "the plan follows the crash (SSE_CrashPoint)")
	local shipRoot = bossModel:FindFirstChild("HumanoidRootPart")
	assert((shipRoot.Position - SSE.BossPosition(ORIGIN, now(), p)).Magnitude < 12, "the ship on the contract's crash path")
	local trailing = 0
	for _, d in bossModel:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Enabled and d.Parent and d.Parent.Name == "SSE_Smoke" then
			trailing += 1
		end
	end
	assert(trailing >= 2, "smoke and flames trailing the dive (" .. trailing .. ")")
	assert(localRoot.Anchored == true and localPlayer:GetAttribute(Fx.FreezeAttribute) == true, "frozen through the crash (its freeze window)")
	-- The rings: they will burst out of the crash point at their burst time.
	local ringSpots = { localRoot.Position + Vector3.new(1.5, 0, 1), ORIGIN + Vector3.new(40, 2.5, 0), ORIGIN + Vector3.new(-40, 2.5, 10) }
	local taken0 = #fired
	send({ SSE.Messages.Rings, 7, ringSpots, times.ringsLand, times.ringsLand + 30, crashPoint + Vector3.new(0, SSE.Crash.RingsUp, 0), {}, times.ringsBurst })
	frames(2)
	local ringsFolder = workspace:FindFirstChild(Fx.RingsFolderName)
	assert(ringsFolder, "the rings' own folder")
	local drawnRings = 0
	for _, d in ringsFolder:GetChildren() do
		if d.Name == "SSE_Ring" then
			drawnRings += 1
		end
	end
	assert(drawnRings == 3, "the rings drawn (" .. drawnRings .. ")")
	local spillSound = soundService:FindFirstChild("SSE_RingsSpill")
	assert(spillSound and spillSound._played == 0 and spillSound.SoundId == Fx.Sounds.RingSpill.Id, "no \"coinnsdrop\" before they burst")
	-- The dive: small blasts on the way down; the impact: the chain and the big punch.
	local booms0 = played("DefeatBoom")
	while now() < times.impact - 0.05 do
		frames(1)
	end
	assert(played("DefeatBoom") > booms0, "small blasts on the way down")
	local sawImpactPunch = false
	for _ = 1, 10 do
		frames(1)
	end
	for _, pn in punches do
		if pn[1] == "Fov" and pn[2] == SSE.Camera.Defeat.Fov then
			sawImpactPunch = true
		end
	end
	assert(sawImpactPunch, "the defeat's punch at the impact")
	near((shipRoot.Position - (crashPoint + Vector3.new(0, SSE.Crash.WreckLift, 0))).Magnitude, 0, 12, "the wreck on the crash point")
	while now() < times.ringsBurst + 0.05 do
		frames(1)
	end
	assert(spillSound._played == 1, "\"coinnsdrop\" as they burst out of the crash point")
	-- The rings have landed; the one at the player's feet is taken once the freeze lets go.
	local _, windowEnd = SSE.FreezeWindow("Defeat")
	local fadeSeen = false
	while now() - defeatAt < windowEnd + 0.3 do
		frames(1)
		local head = bossModel:FindFirstChild("Head")
		if head and head.LocalTransparencyModifier > 0.2 and head.LocalTransparencyModifier < 0.9 then
			fadeSeen = true
		end
	end
	cameraBack("after the outro (inside the Defeat's freeze window)")
	assert(localRoot.Anchored == false and localPlayer:GetAttribute(Fx.FreezeAttribute) == nil, "free again: the rings can be taken")
	seconds(0.3)
	local take = nil
	for index = taken0 + 1, #fired do
		if fired[index][1][1] == SSE.Messages.RingTake then
			take = fired[index]
		end
	end
	assert(take and take[1][1] == SSE.Messages.RingTake and take[1][2] == 1, "{ \"RingTake\", 1 } for the ring touched")
	local collectSound = soundService:FindFirstChild("SSE_RingsCollect")
	assert(collectSound and collectSound.SoundId == Fx.Sounds.RingCollect.Id, "\"coin pickup\"")
	local collected = 0
	for _, child in soundService:GetChildren() do
		if child.Name == "SSE_RingsCollect" then
			collected += child._played
		end
	end
	assert(collected == 1, "played once")
	send({ SSE.Messages.RingGone, 1, 1001 })
	send({ SSE.Messages.RingNo, 2, SSE.RingRefusals.Far })
	send({ SSE.Messages.Reward, 25, 0, "ring" })
	frames(2)
	local ringPopup = false
	for _, child in gui:GetChildren() do
		if string.sub(child.Name, 1, 6) == "Reward" and child.Visible and child.Text == Fx.Text.en.Ring .. "  +25 Wins" then
			ringPopup = true
		end
	end
	assert(ringPopup, "the ring's popup: +1 RING  +25 Wins")
	local defeatLines = 0
	for _, line in chat do
		if string.find(line, Fx.Text.en.ChatDefeat, 1, true) then
			defeatLines += 1
		end
	end
	assert(defeatLines == 1, "the defeat line once in the chat (" .. defeatLines .. ")")
	assert(played("VoiceBeBack") == 0, "no goodbye in the Defeat (the crash speaks for itself)")
	-- The wreck fades out smoothly (never a sudden disappearance), gone by the fade's end.
	while now() < times.fadeEnd + 0.1 do
		frames(1)
		local head = bossModel:FindFirstChild("Head")
		if head and head.LocalTransparencyModifier > 0.2 and head.LocalTransparencyModifier < 0.9 then
			fadeSeen = true
		end
	end
	assert(fadeSeen, "the wreck faded out")
	assert(bossModel:FindFirstChild("Head").LocalTransparencyModifier == 1, "gone by the fade's end")
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") then
			assert(d.LocalTransparencyModifier == 1, "(the lobby Eggman comes back with the Return beat / the end)")
			break
		end
	end
	end

	-- The end (the server's clearing order, Phase "" last), Super off.
	do
	localPlayer:SetAttribute(SSE.PlayerAttributes.Super, nil)
	otherPlayer:SetAttribute(SSE.PlayerAttributes.Super, nil)
	otherPlayer:SetAttribute(SSE.PlayerAttributes.Skin, nil)
	otherPlayer:SetAttribute("SkinOverride", nil)
	for _, name in { "PhaseStart", "EventId", "Seed", "BossHP", "BossMaxHP", "Origin", "EventStart", "LiftOff", "CrashPoint" } do
		workspace:SetAttribute(SSE.Attributes[name], nil)
	end
	assert(runtime() ~= nil, "clearing the attributes before the phase does not restart anything")
	workspace:SetAttribute(SSE.Attributes.Phase, "")
	frames(3)
	assert(runtime() == nil and playerGui:FindFirstChild(Fx.GuiName) == nil and playerGui:FindFirstChild("SSE_Reticle") == nil
		and playerGui:FindFirstChild("SSE_Alert") == nil and screen() == nil and playerGui:FindFirstChild(Fx.VignetteGuiName) == nil, "the event's pieces away at phase \"\"")
	local retiring = workspace:FindFirstChild(Fx.RetiringName)
	assert(retiring, "its folder fades out (its particles die out) instead of vanishing")
	assert(workspace:FindFirstChild(Fx.RingsFolderName), "the rings stay out until their expireTime")
	-- The lobby Eggman fades back in at his spot, each piece to its own value.
	seconds(Fx.Boss.LobbyFadeSeconds / 2)
	local mid = lobbyHull.LocalTransparencyModifier
	assert(mid > 0 and mid < 1, "the lobby Eggman halfway back (" .. tostring(mid) .. ")")
	seconds(Fx.Boss.LobbyFadeSeconds / 2 + 0.2)
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			assert(d.LocalTransparencyModifier == 0, "the lobby Eggman back exactly: " .. d.Name)
		end
	end
	assert(lobbyBeam.Enabled == true, "the lobby ship's beam back")
	assert(torso.Color == torsoBefore, "the local player's colours back")
	for _, d in localBody:GetDescendants() do
		assert(string.sub(d.Name, 1, 4) ~= "SSE_", "nothing of the form left on the player: " .. d:GetFullName())
	end
	assert(bound[Fx.Inputs.Action] == nil, "the input unbound")
	assert(hudCalls[#hudCalls][1] == true, "(v3) the HUD given back")
	assert(localPlayer:GetAttribute(Fx.ChaosZoneAttribute) == nil and localPlayer:GetAttribute(Fx.FreezeAttribute) == nil, "(v3) no zone, no freeze left")
	seconds(3.2)
	assert(workspace:FindFirstChild(Fx.RetiringName) == nil, "the faded folder gone")
	assert(soundService:FindFirstChild(Fx.Music.SoundName) == nil and lobbyMusic:GetAttribute(Fx.Music.SilenceAttribute) == nil, "the music faded out, the lobby playlist back")
	assert(lighting:FindFirstChild(Fx.GradeName) == nil, "the grade gone")
	-- The rings: the last ones are cleared (the server's RingsClear); then nothing is left at all.
	send({ SSE.Messages.RingsClear, 7 })
	frames(2)
	assert(workspace:FindFirstChild(Fx.RingsFolderName) == nil, "RingsClear: every ring gone")
	assert(runService.Stepped:Count() == 0 and runService.RenderStepped:Count() == 0 and next(renderSteps) == nil, "no frame loop left")
	for _, s in soundService:GetChildren() do
		assert(s == lobbyMusic, "a sound left behind: " .. s.Name)
	end
	end

	-- A second event, stopped by the kill switch in the middle of its opening cinematic: the camera, the interface and
	-- everything else back at once.
	do
	startEvent(8)
	frames(20)
	assert(runtime() ~= nil and #chat == 3 and cinematicOn(), "a new event, its start line, its cinematic")
	assert(localBody:FindFirstChild("HumanoidRootPart").Anchored == true, "(v3) frozen in its Intro")
	workspace:SetAttribute(SSE.KillAttribute, true)
	frames(1)
	cameraBack("the kill switch")
	assert(localBody:FindFirstChild("HumanoidRootPart").Anchored == false, "(v3) the kill switch lets the freeze go at once")
	frames(2)
	assert(runtime() == nil and playerGui:FindFirstChild(Fx.GuiName) == nil and screen() == nil, "the kill switch takes it all away, live")
	assert(soundService:FindFirstChild(Fx.Music.SoundName) == nil and lobbyMusic:GetAttribute(Fx.Music.SilenceAttribute) == nil, "the music at once")
	assert(workspace:FindFirstChild(Fx.RetiringName) == nil, "nothing left fading")
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") then
			assert(d.LocalTransparencyModifier == 0, "the lobby Eggman back at once after the kill switch")
		end
	end
	frames(3)
	assert(runService.RenderStepped:Count() == 0 and next(renderSteps) == nil, "no frame loop left after the kill switch")
	workspace:SetAttribute(SSE.KillAttribute, nil)
	clearEvent()
	frames(2)
	end

	-- A third event: a respawn during the opening cinematic hands the camera back to the new body; then the Battle,
	-- a respawn while Super, and an Escape (his outro, the escape lines, the fade), then the end.
	do
	startEvent(9)
	frames(20)
	assert(cinematicOn(), "the third event's cinematic")
	localPlayer.CharacterRemoving:Fire(localBody)
	localBody.Parent = nil -- (the old body goes)
	local newBody = fromLune(eggmanSource)
	newBody:FindFirstChild("EggMobile"):Destroy()
	newBody.Parent = workspace
	for _, d in newBody:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = CFrame.new(ORIGIN + Vector3.new(4, 3, 6)) * (localRoot.CFrame:Inverse() * d.CFrame)
			d.Anchored = false -- (a player's body, as makePlayer's)
		end
	end
	localPlayer.Character = newBody
	localPlayer.CharacterAdded:Fire(newBody)
	frames(1)
	cameraBack("a respawn")
	frames(1)
	assert(newBody:FindFirstChild("HumanoidRootPart").Anchored == true and localRoot.Anchored == false, "(v3) the freeze moves to the new body, the old one let go")
	phase("Bombard")
	frames(5)
	phase("Emeralds")
	frames(5)
	localPlayer:SetAttribute(SSE.PlayerAttributes.Super, true)
	phase("Battle")
	frames(5)
	assert(newBody:FindFirstChild("Torso").Color == gold, "the new body is Super")
	phase("Escape")
	send({ SSE.Messages.Escape })
	frames(2)
	local escapeAt = now()
	assert(cinematicOn(), "the escape's outro")
	local escapeLines = 0
	for _, line in chat do
		if string.find(line, Fx.Text.en.ChatEscape, 1, true) then
			escapeLines += 1
		end
	end
	assert(escapeLines == 1, "the escape line in the chat")
	seconds(0.5)
	assert(saying("EggmanEscape") and played("VoiceCatch") >= 1, "\"HAHAHA! Catch me if you can!\" in his voice")
	while now() - escapeAt < SSE.Durations.Escape do
		frames(1)
	end
	cameraBack("after the escape")
	assert(newBody:FindFirstChild("HumanoidRootPart").Anchored == false, "(v3) free after the escape's window")
	localPlayer:SetAttribute(SSE.PlayerAttributes.Super, nil)
	clearEvent()
	seconds(Fx.Boss.LobbyFadeSeconds + 3.5)
	assert(runtime() == nil and screen() == nil and workspace:FindFirstChild(Fx.RetiringName) == nil, "the escape leaves nothing")
	assert(runService.RenderStepped:Count() == 0 and runService.Stepped:Count() == 0 and next(renderSteps) == nil, "no frame loop left after the escape")
	for _, d in lobbyEggman:GetDescendants() do
		if d:IsA("BasePart") then
			assert(d.LocalTransparencyModifier == 0, "the lobby Eggman back after the escape")
		end
	end
	end

	-- A player who joins in the middle of the Battle: no cinematic, the missed cues skipped.
	workspace:SetAttribute(SSE.Attributes.Origin, ORIGIN)
	workspace:SetAttribute(SSE.Attributes.EventId, 10)
	workspace:SetAttribute(SSE.Attributes.Seed, 12345)
	workspace:SetAttribute(SSE.Attributes.EventStart, now() - 60)
	workspace:SetAttribute(SSE.Attributes.PhaseStart, now() - 36)
	workspace:SetAttribute(SSE.Attributes.Phase, "Battle")
	frames(30)
	assert(runtime() ~= nil and not cinematicOn() and camera.CameraType == roblox.Enum.CameraType.Custom, "joining mid-event: no cinematic")
	clearEvent()
	seconds(4)
	assert(runtime() == nil and runService.RenderStepped:Count() == 0, "and nothing left after it")

	-- A late joiner gets the rings of a finished event: drawn, takeable, gone at their expireTime.
	send({ SSE.Messages.Rings, 10, { ORIGIN + Vector3.new(30, 2.5, 30) }, now() - 5, now() + 1, ORIGIN, {} })
	frames(2)
	assert(workspace:FindFirstChild(Fx.RingsFolderName) and workspace:FindFirstChild(Fx.RingsFolderName):FindFirstChild("SSE_Ring"), "a late joiner sees the rings")
	seconds(1.5)
	assert(workspace:FindFirstChild(Fx.RingsFolderName) == nil and runService.RenderStepped:Count() == 0, "gone at their expireTime, nothing left")

	-- 2026-09-26 (owner, v3): THE RACE MAP. A fifth event with the fight on Workspace.RaceArena (SSE_Origin = the
	-- arena point, SSE_LobbyOrigin = the lobby): the race-only pieces hidden (the rest untouched) and back exactly;
	-- the Cinematic in the lobby (the arena streamed in meanwhile, the lobby's sky normal); the Teleport beat's fade,
	-- held black until the root has arrived, then Eggman's entry on camera; the haze only in the arena; the Return
	-- beat's fade, the lobby streamed in, the lobby Eggman back at his spot; everything given back at the end.
	do
	local ARENA = Vector3.new(6000, 12000, -510)
	local arenaModel = fakeNew("Model", "RaceArena")
	local function piece(className, name, parent, props)
		local x = fakeNew(className, name)
		for k, v in props or {} do
			x[k] = v
		end
		x.Parent = parent
		return x
	end
	local structure = piece("Model", "Structure", arenaModel)
	local gantry = piece("Model", "StartGantry", structure)
	local light1 = piece("Part", "Light1", gantry, { CFrame = CFrame.new(ARENA + Vector3.new(-6, 12, 510)) })
	local stopBar = piece("Part", "StopBar", structure, { Transparency = 1 })
	local pads = piece("Model", "SpeedPads", arenaModel)
	local pad = piece("Part", "SpeedPad", pads, { Transparency = 1, CanCollide = false })
	local spikes = piece("Model", "Spikes", arenaModel)
	local spike = piece("Part", "SpikeTile_1_1_2", spikes)
	spike:SetAttribute("RaceSpikeTile", true)
	local decor = piece("Folder", "GreenHillDecor", arenaModel)
	local padArt = piece("MeshPart", "Kit_SpeedPad", decor)
	local startBeam = piece("Part", "StartBeam", decor)
	local palm = piece("MeshPart", "Kit_PalmA", decor)
	local orb = piece("Part", "RaceOrb", arenaModel, { Transparency = 1 })
	local core = piece("Part", "Core", orb)
	local glow = piece("PointLight", "Glow", core)
	local marker = piece("BillboardGui", "OrbMarker", core)
	local floorModel = piece("Model", "TrackFloor", arenaModel)
	local floorPart = piece("Part", "Floor_001", floorModel)
	local walls = piece("Folder", "Walls", arenaModel)
	local wall = piece("Part", "WallL_1", walls, { Transparency = 1 })
	arenaModel.Parent = workspace
	local body = localPlayer.Character
	local root = body:FindFirstChild("HumanoidRootPart")
	local function moveBody(to)
		local delta = CFrame.new(to) * root.CFrame:Inverse()
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
	end
	moveBody(ORIGIN + Vector3.new(4, 3, 6))
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	table.clear(streams)
	local hudBefore = #hudCalls
	workspace:SetAttribute(SSE.Attributes.LobbyOrigin, ORIGIN)
	workspace:SetAttribute(SSE.Attributes.Origin, ARENA)
	workspace:SetAttribute(SSE.Attributes.EventId, 11)
	workspace:SetAttribute(SSE.Attributes.Seed, 777)
	workspace:SetAttribute(SSE.Attributes.EventStart, now())
	workspace:SetAttribute(SSE.Attributes.LiftOff, LIFT)
	workspace:SetAttribute(SSE.Attributes.BossMaxHP, 40)
	workspace:SetAttribute(SSE.Attributes.BossHP, 40)
	phase("Cinematic")
	frames(20)
	-- The race map as a plain map: the race pieces hidden (and not collidable for this client), the rest untouched.
	for _, x in { light1, stopBar, pad, spike, padArt, startBeam, core } do
		assert(x.LocalTransparencyModifier == 1, "hidden: " .. x.Name)
	end
	assert(light1.CanCollide == false and spike.CanCollide == false, "no invisible bumps")
	assert(glow.Enabled == false and marker.Enabled == false, "the orb's light and sign off")
	assert(floorPart.LocalTransparencyModifier == 0 and floorPart.CanCollide == true, "the track stays")
	assert(wall.LocalTransparencyModifier == 0 and wall.CanCollide == true and palm.LocalTransparencyModifier == 0, "the walls and the decor stay")
	-- A piece streamed in later is hidden too.
	local lateSpike = piece("Part", "SpikeTile_9_9_9", spikes)
	lateSpike:SetAttribute("RaceSpikeTile", true)
	arenaModel.DescendantAdded:Fire(lateSpike)
	assert(lateSpike.LocalTransparencyModifier == 1, "a piece streamed in later: hidden")
	-- The Cinematic plays in the LOBBY; the arena is streamed in meanwhile; the lobby's own sky (no haze there).
	assert(cinematicOn(), "the Intro in the lobby")
	assert(root.Anchored == true, "frozen for the Intro (its window: the lobby)")
	local streamedArena = false
	for _, at in streams do
		if (at - ARENA).Magnitude < 1 then
			streamedArena = true
		end
	end
	assert(streamedArena, "the arena streamed in before the fade")
	assert(localPlayer:GetAttribute(Fx.ChaosZoneAttribute) == nil, "no haze in the lobby")
	assert(#hudCalls > hudBefore and hudCalls[#hudCalls][1] == false and hudCalls[#hudCalls][2] == Fx.HudHide.MenuName, "the HUD held away in the event (the lobby before the trip)")
	seconds(7.2)
	local grade = lighting:FindFirstChild(Fx.GradeName)
	assert(grade == nil or not grade.Enabled, "the lobby looks normal (the grade only in the arena)")
	-- The Teleport beat: the fade to black, held until the root has arrived, then the fade in and his entry.
	phase("Teleport")
	local teleportAt = now()
	frames(2)
	local fadeFrame = screen():FindFirstChild("Fade")
	assert(fadeFrame, "the beats' black")
	while now() - teleportAt < SSE.Beats.Teleport.MoveAt + 0.05 do
		frames(1)
	end
	assert(fadeFrame.Visible and fadeFrame.BackgroundTransparency < 0.01, "black at the move")
	seconds(0.3)
	assert(fadeFrame.BackgroundTransparency < 0.01, "still black: the root has not arrived yet")
	moveBody(ARENA + Vector3.new(3, 3, 0)) -- (the server's move)
	frames(2)
	local arrivedAt = now() - teleportAt
	seconds(0.3)
	assert(fadeFrame.BackgroundTransparency > 0.05 and fadeFrame.BackgroundTransparency < 0.95, "fading back in after the arrival")
	seconds(SSE.Beats.Teleport.FadeIn - SSE.Beats.Teleport.MoveAt + 0.1)
	assert(not fadeFrame.Visible, "the screen back")
	assert(arrivedAt > SSE.Beats.Teleport.MoveAt, "(the arrival after the move)")
	assert(cinematicOn(), "Eggman flies into the arena on camera (the Entry shot)")
	assert(localPlayer:GetAttribute(Fx.ChaosZoneAttribute) == true, "in the arena: the haze zone")
	while now() - teleportAt < SSE.Durations.Teleport do
		frames(1)
	end
	cameraBack("after the entry")
	assert(root.Anchored == false, "free after the Teleport beat's window")
	grade = lighting:FindFirstChild(Fx.GradeName)
	assert(grade and grade.Enabled, "the light warm grade in the arena")
	assert(hudCalls[#hudCalls][1] == false, "the HUD still held away in the arena")
	-- The Return beat: the fade, the trip home (the lobby streamed in), the lobby Eggman back at his spot.
	phase("Escape")
	frames(5)
	table.clear(streams)
	phase("Return")
	local returnAt = now()
	frames(2)
	local streamedLobby = false
	for _, at in streams do
		if (at - ORIGIN).Magnitude < 1 then
			streamedLobby = true
		end
	end
	assert(streamedLobby, "the lobby streamed in for the trip home")
	assert(root.Anchored == true, "frozen for the Return beat (it began in the arena)")
	while now() - returnAt < SSE.Beats.Return.MoveAt + 0.05 do
		frames(1)
	end
	fadeFrame = screen():FindFirstChild("Fade")
	assert(fadeFrame.Visible and fadeFrame.BackgroundTransparency < 0.01, "black for the trip home")
	moveBody(ORIGIN + Vector3.new(4, 3, 6))
	seconds(SSE.Beats.Return.LobbyEggmanFade * 0.5)
	local midLobby = lobbyHull.LocalTransparencyModifier
	assert(midLobby > 0 and midLobby < 1, "the lobby Eggman fading back in at his spot (" .. tostring(midLobby) .. ")")
	seconds(1.2)
	assert(lobbyHull.LocalTransparencyModifier == 0, "back exactly")
	assert(localPlayer:GetAttribute(Fx.ChaosZoneAttribute) == nil, "home: no haze")
	-- The end: every race piece exactly back, the HUD given back, nothing held.
	clearEvent()
	workspace:SetAttribute(SSE.Attributes.LobbyOrigin, nil)
	frames(3)
	for _, x in { light1, spike, core, startBeam, padArt, lateSpike } do
		assert(x.LocalTransparencyModifier == 0 and x.CanCollide == true, "back exactly: " .. x.Name)
	end
	assert(stopBar.LocalTransparencyModifier == 0 and pad.CanCollide == false and pad.LocalTransparencyModifier == 0, "the pads and bars as they were")
	assert(glow.Enabled == true and marker.Enabled == true, "the orb's light and sign back")
	assert(hudCalls[#hudCalls][1] == true, "the HUD given back")
	assert(root.Anchored == false and localPlayer:GetAttribute(Fx.FreezeAttribute) == nil, "nothing frozen")
	seconds(4)
	assert(runtime() == nil and runService.RenderStepped:Count() == 0, "nothing left after the race-map event")
	arenaModel.Parent = nil
	end

	-- 2026-09-26 (owner, v3): THE INVITE. A player far from the event: the world stays normal (no music, no HUD hold, no
	-- freeze, no cinematic), then the optional card: YES sends { "TeleportToEvent", eventId }; NO (or letting it pass)
	-- never asks again for that event; it closes by itself when the player arrives; gamepad-selectable.
	do
	local body = localPlayer.Character
	local root = body:FindFirstChild("HumanoidRootPart")
	local function moveBody(to)
		local delta = CFrame.new(to) * root.CFrame:Inverse()
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
	end
	moveBody(ORIGIN + Vector3.new(2000, 0, 0))
	local hudBefore = #hudCalls
	startEvent(12)
	frames(20)
	assert(not cinematicOn() and root.Anchored == false, "far away: no cinematic, no freeze")
	assert(soundService:FindFirstChild(Fx.Music.SoundName) == nil, "far away: no event music (the world stays normal)")
	assert(#hudCalls == hudBefore, "far away: the HUD stays")
	lastInput = roblox.Enum.UserInputType.Gamepad1
	send({ SSE.Messages.Invite, 12, SSE.InviteReasons.Start })
	frames(2)
	local card = playerGui:FindFirstChild(Fx.InviteGuiName)
	assert(card and card:FindFirstChild("Card"), "the invite card")
	local c = card:FindFirstChild("Card")
	assert(c:FindFirstChild("Title").Text == Fx.Text.en.Invite and Fx.Text.en.Invite == "Dr. Eggman is attacking! Join the event?", "\"Dr. Eggman is attacking! Join the event?\"")
	assert(c:FindFirstChild("Yes"):FindFirstChild("Label").Text == Fx.Text.en.InviteYes and c:FindFirstChild("No"):FindFirstChild("Label").Text == Fx.Text.en.InviteNo, "YES / NO")
	assert(services.GuiService.SelectedObject == c:FindFirstChild("Yes"), "a gamepad: YES selected")
	assert(c:FindFirstChild("Yes").Selectable and c:FindFirstChild("Yes").NextSelectionRight == c:FindFirstChild("No"), "gamepad-selectable")
	local before = #fired
	c:FindFirstChild("Yes").Activated:Fire()
	assert(#fired == before + 1 and fired[#fired][1][1] == SSE.Messages.TeleportToEvent and fired[#fired][1][2] == 12, "YES: { \"TeleportToEvent\", 12 }")
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil and services.GuiService.SelectedObject == nil, "the card goes, the selection with it")
	lastInput = roblox.Enum.UserInputType.Keyboard
	-- Asked again (the trip did not happen): NO this time; never again for this event.
	send({ SSE.Messages.Invite, 12, SSE.InviteReasons.Left })
	frames(2)
	card = playerGui:FindFirstChild(Fx.InviteGuiName)
	assert(card, "asked again")
	card:FindFirstChild("Card"):FindFirstChild("No").Activated:Fire()
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "NO closes it")
	send({ SSE.Messages.Invite, 12, SSE.InviteReasons.Respawn })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "never again after a NO")
	-- Another event: the card closes by itself when the player arrives (and on TeleportGo), and after its time.
	clearEvent()
	frames(3)
	startEvent(13)
	frames(5)
	send({ SSE.Messages.Invite, 13, SSE.InviteReasons.Start })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName), "the card for the new event")
	moveBody(ORIGIN + Vector3.new(4, 3, 6))
	seconds(0.5)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "in the event: the card closes by itself")
	moveBody(ORIGIN + Vector3.new(2000, 0, 0))
	send({ SSE.Messages.Invite, 13, SSE.InviteReasons.Left })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName), "left the area: asked again")
	send({ SSE.Messages.TeleportGo, 13, ORIGIN + Vector3.new(10, 3, 0) })
	frames(1)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "TeleportGo: the card goes")
	send({ SSE.Messages.Invite, 13, SSE.InviteReasons.Left })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName), "asked again")
	seconds(Fx.Invite.Seconds + 0.5)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "it closes by itself after its time")
	send({ SSE.Messages.Invite, 13, SSE.InviteReasons.Left })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "let pass: never again for this event")
	clearEvent()
	frames(3)
	send({ SSE.Messages.Invite, 13, SSE.InviteReasons.Left })
	frames(2)
	assert(playerGui:FindFirstChild(Fx.InviteGuiName) == nil, "no card without a running event")
	moveBody(ORIGIN + Vector3.new(4, 3, 6))
	seconds(4)
	assert(runtime() == nil and runService.RenderStepped:Count() == 0, "nothing left after the invites")
	end

	assert(#warnings == 0, "no warnings: " .. table.concat(warnings, "; "))
	pass(("the real client in a fake Roblox through v2 / v3 events (v3: the freeze windows, the HUD hold, the burn's cadence, the crash, the hit-stop and the shield's knock-back, \"hit!\" only on a damaging connection, the jump's instant attack, (A) / (X), one trail, the race map's beats and pieces, the invite): the intro / emeralds / outro cinematics (camera, interface, letterbox; back after each, after a respawn and the kill switch; none mid-event), his lines on the cues and his voices, the music and the playlist given back, the chaos grade, the red zones and the muzzle flash, the charge (Charge / Homing charge01, the ring, the auto-release, the shield bounce, the Reload window's \"!\" and the full hit), every input held, the skin mode, the ring rain (take, gone, refused, outliving the event, a late joiner), the fade into the horizon, the lobby Eggman fading back (%d tweens)"):format(tweens))
end

print(("test_u4_supersonic_client: %d checks passed"):format(passed))
