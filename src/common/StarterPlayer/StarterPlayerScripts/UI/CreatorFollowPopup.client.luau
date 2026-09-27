-- Retired: events no longer display creator promotion.
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("CreatorFollowGui")
if old then old:Destroy() end
