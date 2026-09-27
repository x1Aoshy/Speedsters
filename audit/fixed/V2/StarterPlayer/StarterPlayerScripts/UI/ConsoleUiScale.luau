-- Console safe area only. Studio-authored desktop/mobile layout is unchanged.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local isConsole = GuiService:IsTenFootInterface()
local function configure(gui)
 if not gui:IsA("ScreenGui") then return end
 if isConsole then
  gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
  gui.ClipToDeviceSafeArea = true
 end
end
for _, gui in ipairs(playerGui:GetChildren()) do configure(gui) end
playerGui.ChildAdded:Connect(configure)
if isConsole or UserInputService.GamepadEnabled then GuiService.AutoSelectGuiEnabled = true end
UserInputService.GamepadConnected:Connect(function() GuiService.AutoSelectGuiEnabled = true end)