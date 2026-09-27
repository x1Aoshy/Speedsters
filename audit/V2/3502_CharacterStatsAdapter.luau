--!strict
local inRoblox = typeof(script) == "Instance"
local StatsService = if inRoblox then require(script.Parent.StatsService) else require("./StatsService")
local Config = if inRoblox then require(game:GetService("ReplicatedStorage").Shared.Config) else {}
local CharacterStatsAdapter = {}

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
 local mode = player:GetAttribute("WalkSpeedMode") or player:GetAttribute("MovementSelectorMode") or "Red"
 local selectors = Config.WalkSpeedSelectorMultipliers or { Green = 0.2, Yellow = 17 / 30, Red = 1 }
 return {
  worldMultiplier = world2 and (Config.World2WalkSpeedMultiplier or 1) or 1,
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
 player:SetAttribute("RealWalkSpeedMax", maximum.value)
 player:SetAttribute("RealWalkSpeedSelected", selected)
 player:SetAttribute("WalkSpeedModeScale", maximum.value > 0 and selected / maximum.value or 1)
 player:SetAttribute("WorldMovementSpeedScale", factors.worldMultiplier)
 return actual
end

return CharacterStatsAdapter