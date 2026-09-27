local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")

local playerModule = playerScripts:WaitForChild("PlayerModule")
local cameraModule = playerModule:WaitForChild("CameraModule")
local mouseLockController = cameraModule:WaitForChild("MouseLockController")
local boundKeys = mouseLockController:WaitForChild("BoundKeys")
boundKeys.Value = "LeftControl"