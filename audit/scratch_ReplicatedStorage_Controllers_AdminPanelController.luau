--Made by FaypleStudios (https://discord.gg/fayplestudios)
--If you can't find us via link , find us in YouTube !
local l_ReplicatedStorage_0 = game:GetService("ReplicatedStorage")
local l_Players_0 = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local _ = require(l_ReplicatedStorage_0.Packages.Synchronizer)
local v3 = require(l_ReplicatedStorage_0.Packages.TopbarPlus)
local v4 = require(l_ReplicatedStorage_0.Packages.Timer)
local v5 = require(l_ReplicatedStorage_0.Packages.Trove)
local v6 = require(l_ReplicatedStorage_0.Packages.Net)
local v7 = require(l_ReplicatedStorage_0.Datas.AdminCommands)
local _ = require(l_ReplicatedStorage_0.Datas.ServerData)
local v9 = require(l_ReplicatedStorage_0.Controllers.InterfaceController)
local v10 = require(l_ReplicatedStorage_0.Classes.AnimatedButton)

local l_LocalPlayer_0 = l_Players_0.LocalPlayer
local l_PlayerGui_0 = l_LocalPlayer_0.PlayerGui

local RobuxShopData = require(l_ReplicatedStorage_0.Datas.RobuxShopData)
local ADMIN_GAMEPASS_ID = RobuxShopData.GetId("AdminPanel")

local v13 = v3.new():setImage(102554277994487, "Selected"):setImage(95529031547606, "Deselected"):setImageScale(0.7):setImageRatio(2):setOrder(2):setEnabled(false)
local l_AdminPanel_0 = l_PlayerGui_0:WaitForChild("AdminPanel").AdminPanel
local l_Content_0 = l_AdminPanel_0.Content
local l_Close_0 = l_AdminPanel_0.Header.Close
local l_Profiles_0 = l_AdminPanel_0.Profiles
local l_ScrollingFrame_0 = l_Profiles_0.ScrollingFrame
local l_Template_0 = l_ScrollingFrame_0.Template
local l_ScrollingFrame_1 = l_Content_0.ScrollingFrame
local l_Template_1 = l_ScrollingFrame_1.Template

local v22 = v6:RemoteEvent("AdminPanelService/PlaceCooldownFromChat")
local v23 = v6:RemoteEvent("AdminPanelService/ExecuteCommand")
local v24 = v6:RemoteEvent("AdminPanelService/DealWithThis")
local v25 = v6:RemoteEvent("AdminPanelService/OpenUI")

local v26 = {}
local v27 = nil
local v28 = nil

local function hasAccess()
	return l_LocalPlayer_0:GetAttribute("AdminCommands") == true
end

local function promptPurchase()
	MarketplaceService:PromptGamePassPurchase(l_LocalPlayer_0, ADMIN_GAMEPASS_ID)
end

local function closePanel()
	v9:SetState("AdminPanel", false)
	task.defer(function()
		v13:deselect()
	end)
end

local function v33(v29)
	if v29 == "" then return nil end
	local v30 = v29:lower()
	for _, v32 in ipairs(l_Players_0:GetPlayers()) do
		if v32.Name:sub(1, #v29):lower() == v30 then
			return v32
		end
	end
	return nil
end

local function v39(v34, v35)
	if v34:GetAttribute("OnCooldown") then return end
	v34:SetAttribute("OnCooldown", true)
	local v36 = v5.new()
	local l_v35_0 = v35
	local l_Timer_0 = v34:FindFirstChild("Timer")
	l_Timer_0.Visible = true
	v34.CooldownFrame.Visible = true
	v36:Add(function()
		l_Timer_0.Visible = false
		v34.CooldownFrame.Visible = false
		v34:SetAttribute("OnCooldown", false)
	end)
	v36:Add(v4.Simple(1, function()
		l_v35_0 = l_v35_0 - 1
		l_Timer_0.Text = tostring(l_v35_0) .. "s"
		if l_v35_0 <= 0 then
			v36:Destroy()
		end
	end))
end

local function v44()
	v27 = nil
	v28 = nil
	for _, v41 in ipairs(l_Profiles_0.ScrollingFrame:GetChildren()) do
		if v41:IsA("ImageButton") and v41.Name ~= "Template" then
			v41.UIStroke.Color = Color3.new(0, 0, 0)
			v41.UIStroke.Thickness = 1.5
		end
	end
	for _, v43 in ipairs(l_ScrollingFrame_1:GetChildren()) do
		if v43:IsA("ImageButton") and v43.Name ~= "Template" then
			v43.UIStroke.Color = Color3.new(0, 0, 0)
			v43.UIStroke.Thickness = 1.5
		end
	end
end

local function v49(v45)
	v28 = v45 and v45.Name or nil
	for _, v47 in ipairs(l_ScrollingFrame_1:GetChildren()) do
		if v47:IsA("ImageButton") and v47.Name ~= "Template" then
			local v48 = v47 == v45
			v47.UIStroke.Color = v48 and Color3.new(1, 1, 0) or Color3.new(0, 0, 0)
			v47.UIStroke.Thickness = v48 and 3 or 1.5
		end
	end
end

local function v54(v50)
	v27 = v50 and l_Players_0:FindFirstChild(v50.Name) or nil
	for _, v52 in ipairs(l_Profiles_0.ScrollingFrame:GetChildren()) do
		if v52:IsA("ImageButton") and v52.Name ~= "Template" then
			local v53 = v52 == v50
			v52.UIStroke.Color = v53 and Color3.new(1, 1, 0) or Color3.new(0, 0, 0)
			v52.UIStroke.Thickness = v53 and 3 or 1.5
		end
	end
end

local function v62()
	for _, v56 in ipairs(l_ScrollingFrame_1:GetChildren()) do
		if v56:IsA("ImageButton") and v56.Name ~= "Template" then
			v56:Destroy()
		end
	end

	for v57, v58 in v7 do
		local v59 = l_Template_1:Clone()
		v59.Name = v57
		v59.Command.Text = ";" .. v58.name
		v59.Icon.Image = v58.icon or v59.Icon.Image
		v59.Timer.Text = v58.cooldown .. "s"
		v59.Timer.Visible = false
		local v60 = v10.new(v59)
		v60:Animate()
		v60.OnActivated:Connect(function()
			if not hasAccess() then
				promptPurchase()
				closePanel()
				return
			end
			v49(v59)
			if v27 then
				v23:FireServer(v27, v57)
				v39(v59, v58.cooldown)
				v44()
			end
		end)
		v59.Visible = true
		v59.Parent = l_ScrollingFrame_1
	end

	local v61 = v9:Register("AdminPanel", l_AdminPanel_0, "TopQuint")
	v61:AttachCloseButton(l_Close_0)
	v61:Close()

	v13.selected:Connect(function()
		if hasAccess() then
			v9:SetState("AdminPanel", true)
		else
			promptPurchase()
			task.defer(function()
				v13:deselect()
			end)
		end
	end)

	v13.deselected:Connect(function()
		v9:SetState("AdminPanel", false)
	end)

	v13:setEnabled(true)

	v61.OnOpen:Connect(function()
		if not hasAccess() then
			closePanel()
			promptPurchase()
			return
		end
		v13:select()
	end)

	v61.OnClose:Connect(function()
		v13:deselect()
	end)
end

local function createPlayerButton(player)
	local v67 = l_Template_0:Clone()
	v67.Name = player.Name
	v67.playerName.Text = player.Name
	v67.playerPhoto.Image = ("rbxthumb://type=AvatarHeadShot&id=%*&w=100&h=100"):format(player.UserId)
	local v68 = v10.new(v67)
	v68:Animate()
	v68.OnActivated:Connect(function()
		if not hasAccess() then
			promptPurchase()
			closePanel()
			return
		end
		v54(v67)
		if v28 then
			v23:FireServer(v27, v28)
			local l_l_ScrollingFrame_1_FirstChild_0 = l_ScrollingFrame_1:FindFirstChild(v28)
			v39(l_l_ScrollingFrame_1_FirstChild_0, v7[v28].cooldown)
			v44()
		end
	end)
	v67.Visible = true
	v67.Parent = l_Profiles_0.ScrollingFrame
end

local function v70()
	for _, v64 in ipairs(l_Profiles_0.ScrollingFrame:GetChildren()) do
		if v64:IsA("ImageButton") and v64.Name ~= "Template" then
			v64:Destroy()
		end
	end
	for _, v66 in ipairs(l_Players_0:GetPlayers()) do
		createPlayerButton(v66)
	end
end

v26.Start = function(_)
	local v72 = false

	v25.OnClientEvent:Connect(function()
		if hasAccess() then
			v9:SetState("AdminPanel", true)
		else
			promptPurchase()
		end
	end)

	v22.OnClientEvent:Connect(function(v73)
		local l_l_ScrollingFrame_1_FirstChild_1 = l_ScrollingFrame_1:FindFirstChild(v73)
		v39(l_l_ScrollingFrame_1_FirstChild_1, v7[v73].cooldown)
		v44()
	end)

	v24.OnClientEvent:Connect(function(v75, v76, v77)
		local v78 = v7[v75]
		if not v78 then return end
		local l_effects_0 = v78.effects
		local v80 = l_effects_0 and l_effects_0[v76]
		if not v80 then return end
		task.spawn(v80, v77)
	end)

	l_LocalPlayer_0:GetAttributeChangedSignal("AdminCommands"):Connect(function()
		if not hasAccess() then
			closePanel()
		end
	end)

	task.spawn(function()
		v72 = true
		v70()
		v62()
	end)

	l_Players_0.PlayerAdded:Connect(function(player)
		if v72 then createPlayerButton(player) end
	end)

	l_Players_0.PlayerRemoving:Connect(function(player)
		if v72 then
			local btn = l_Profiles_0.ScrollingFrame:FindFirstChild(player.Name)
			if btn then btn:Destroy() end
		end
	end)

	local function v87(v81)
		local v82 = v81:lower():gsub("^;", "")
		local v83 = string.split(v82, " ")
		local v84 = v83[1] or ""
		local v85 = v83[2] or ""
		v49(l_ScrollingFrame_1:FindFirstChild(v84))
		if v85 ~= "" then
			local v86 = v33(v85)
			v54(v86 and l_ScrollingFrame_0:FindFirstChild(v86.Name) or nil)
		else
			v54(nil)
		end
	end

	local l_TextBox_0 = l_AdminPanel_0.CommandBox:FindFirstChild("TextBox")
	l_TextBox_0:GetPropertyChangedSignal("Text"):Connect(function()
		v87(l_TextBox_0.Text)
	end)

	l_TextBox_0.FocusLost:Connect(function(v89)
		if not hasAccess() then
			promptPurchase()
			l_TextBox_0.Text = ""
			closePanel()
			return
		end
		if v89 and v28 and v27 then
			v23:FireServer(v27, v28)
			local l_l_ScrollingFrame_1_FirstChild_2 = l_ScrollingFrame_1:FindFirstChild(v28)
			v39(l_l_ScrollingFrame_1_FirstChild_2, v7[v28].cooldown)
			l_TextBox_0.Text = ""
			v44()
		end
	end)
end

return v26