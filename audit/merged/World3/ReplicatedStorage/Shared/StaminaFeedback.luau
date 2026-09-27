--!strict
-- StaminaFeedback.luau
-- One client-side signal for "the player tried to run or fly with an empty bar".
--
-- Movement scripts only report the attempt (SpeedsterClient for sprint, the World
-- flight clients for flight). How it looks belongs to the HUD, which owns the bar
-- (Mainhud.SpeedsterBar in MainHUDController).

local StaminaFeedback = {}

export type Kind = "run" | "fly"

StaminaFeedback.Messages = {
	run = "NO STAMINA TO RUN",
	fly = "NO STAMINA TO FLY",
}

-- Holding a key, or tapping it over and over, should read as one message rather
-- than a strobe.
StaminaFeedback.RepeatSeconds = 1.1

local attempted = Instance.new("BindableEvent")
StaminaFeedback.Attempted = attempted.Event

local lastAt: { [string]: number } = {}

function StaminaFeedback.Notify(kind: Kind)
	if StaminaFeedback.Messages[kind] == nil then
		return
	end
	local now = os.clock()
	if now - (lastAt[kind] or -math.huge) < StaminaFeedback.RepeatSeconds then
		return
	end
	lastAt[kind] = now
	attempted:Fire(kind)
end

return StaminaFeedback
