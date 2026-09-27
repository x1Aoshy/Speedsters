-- Pure rules for when the "your first aura" guide is owed (UI/FirstTimeTutorial).
-- Until 2026-09-20 the guide only started at the instant the server's Step 2 (touch the
-- first Win pad) ended WITH the pad claimed. Step 2 times out after 1.7 minutes, so a new
-- player who trained long enough to rebirth before walking to the pad never got the guide.
-- Now the guide is owed from the moment the pad is claimed, whenever that happens in the
-- session the first-time tutorial ran in, and it comes back if a respawn tore it down.
local Flow = {}

-- state: SawTutorial, ClaimedStage, WinStage, EquipDone, Dismissed
function Flow.WantsAuraGuide(state)
	if state.EquipDone == true or state.Dismissed == true then
		return false
	end
	if state.SawTutorial ~= true then
		return false
	end
	return (tonumber(state.ClaimedStage) or 0) >= (tonumber(state.WinStage) or 1)
end

-- state: TutorialActive, GuideOpen, CharacterAlive, HudReady
function Flow.CanShowNow(state)
	return state.TutorialActive ~= true
		and state.GuideOpen ~= true
		and state.CharacterAlive == true
		and state.HudReady == true
end

return Flow
