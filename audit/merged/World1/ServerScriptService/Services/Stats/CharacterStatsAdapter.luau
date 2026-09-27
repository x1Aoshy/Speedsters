--!strict
local inRoblox = typeof(script) == "Instance"
local StatsService = if inRoblox then require(script.Parent.StatsService) else require("./StatsService")
local Config = if inRoblox then require(game:GetService("ReplicatedStorage").Shared.Config) else {}
local CharacterStatsAdapter = {}

local function setAttributeIfChanged(instance: any, name: string, value: any)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

function CharacterStatsAdapter.GetRules(): any
 return {
  startingSpeed = Config.StartingSpeed or 1,
  maxStoredSpeed = Config.MaxStoredSpeed or 1e50,
  useSmoothRealSpeedFormula = Config.UseSmoothRealSpeedFormula ~= false,
  realWalkSpeedMin = Config.RealWalkSpeedMin or 8,
  referenceDisplayedSpeed = Config.RealWalkSpeedReferenceDisplayedSpeed or 3.37e15,
  walkSpeedAtReference = Config.RealWalkSpeedAtReference or 300,
  curve = Config.RealWalkSpeedCurve or 2,
  baseWalkSpeed = Config.BaseWalkSpeed or 8,
  speedToWalkSpeedMultiplier = Config.SpeedToWalkSpeedMultiplier or 0.08,
  useWalkSpeedCap = Config.UseWalkSpeedCap == true,
  maxWalkSpeed = Config.MaxWalkSpeed or 300,
 }
end

function CharacterStatsAdapter.GetMovementFactors(player: any): any
 local world2 = Config.IsWorld2Place == true or player:GetAttribute("CurrentWorld") == 2
 local world3 = Config.IsWorld3Place == true or player:GetAttribute("CurrentWorld") == 3
 local mode = player:GetAttribute("WalkSpeedMode") or player:GetAttribute("MovementSelectorMode") or "Red"
 local selectors = Config.WalkSpeedSelectorMultipliers or { Green = 0.2, Yellow = 17 / 30, Red = 1 }
 return {
  -- Each world walks a step slower than the last: World 2 a third, World 3 a ninth.
  worldMultiplier = if world3 then (Config.World3WalkSpeedMultiplier or (1 / 9))
   elseif world2 then (Config.World2WalkSpeedMultiplier or (1 / 3))
   else 1,
  selectorMultiplier = selectors[mode] or 1,
  boostMultiplier = Config.BoostWalkSpeedMultiplier or 1.7,
  permanentMultiplier = 1,
  isBoosting = player:GetAttribute("IsBoosting") == true,
  instantMovementControllerEnabled = Config.InstantMovementControllerEnabled ~= false,
  customWalkSpeed = mode == "Custom" and tonumber(player:GetAttribute("CustomWalkSpeed")) or nil,
 }
end

function CharacterStatsAdapter.Update(player: any, rawSpeed: number, customFactors: any?): number?
 local factors = customFactors or CharacterStatsAdapter.GetMovementFactors(player)
 local rules = CharacterStatsAdapter.GetRules()
 local maximum = StatsService.CalculateWalkSpeed(rawSpeed, rules, {
  worldMultiplier = factors.worldMultiplier, selectorMultiplier = 1,
  boostMultiplier = 1, permanentMultiplier = 1,
 })
 if not maximum.ok then return nil end
 local selected = maximum.value * factors.selectorMultiplier
 local custom = factors.customWalkSpeed
 if custom and custom == custom and math.abs(custom) ~= math.huge then
  selected = math.clamp(custom, math.min(rules.realWalkSpeedMin, maximum.value), maximum.value)
 end
 local actual = selected
 if factors.isBoosting and factors.instantMovementControllerEnabled == false then
  actual *= factors.boostMultiplier
 end
 local character = player.Character
 if typeof(character) == "Instance" then
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if humanoid then humanoid.WalkSpeed = actual end
 end
 setAttributeIfChanged(player, "RealWalkSpeedMax", maximum.value)
 setAttributeIfChanged(player, "RealWalkSpeedSelected", selected)
 setAttributeIfChanged(player, "WalkSpeedModeScale", maximum.value > 0 and selected / maximum.value or 1)
 setAttributeIfChanged(player, "WorldMovementSpeedScale", factors.worldMultiplier)
 return actual
end

return CharacterStatsAdapter
