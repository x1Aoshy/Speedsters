local AdminGlobalEvents = {}

AdminGlobalEvents.TopicName = "SpeedsterEscape_AdminGlobalEvents"
AdminGlobalEvents.Channels = {
	Confetti = 1,
	Disco = 1,
	EventVersion = 1,
}

AdminGlobalEvents.TreadmillFolderName = "AdminSpawnedTreadmills"
AdminGlobalEvents.DiscoBallFolderName = "AdminDiscoBalls"
AdminGlobalEvents.DiscoLightFolderName = "AdminDiscoLights"

AdminGlobalEvents.DEFAULT_DISCO = {
	Brightness = 0.35,
	ClockTime = 18,
	Ambient = Color3.fromRGB(25, 25, 38),
	AmbientStrength = 0.6,
	Saturation = 0.35,
	Contrast = 0.1,
	BeamIntervalSeconds = 2.0,
	BeamCount = 12,
	BallCount = 1,
}

AdminGlobalEvents.DEFAULT_CONFETTI = {
	Duration = 8,
	Count = 40,
	FallHeight = 140,
	FallRange = 90,
	SpeedMult = 2,
	WinMult = 2,
	BoostDuration = 5,
}

AdminGlobalEvents.DEFAULT_TREADMILL = {
	SpeedMult = 5,
	WinMult = 2,
	WinBase = 200,
}

AdminGlobalEvents.DEFAULT_RAINING_TACOS = {
	Duration = 60,
	SpeedMult = 2.5,
	WinMult = 2,
	MusicId = "rbxassetid://142376088",
	TacoRainRate = 40,
}

return AdminGlobalEvents