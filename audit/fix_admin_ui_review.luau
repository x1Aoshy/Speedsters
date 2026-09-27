local fs=require('@lune/fs')
local path='src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau'
local s=fs.readFile(path)
local function sub(a,b) local i,j=s:find(a,1,true);assert(i,a);s=s:sub(1,i-1)..b..s:sub(j+1) end
sub('local RunService = game:GetService("RunService")','local RunService = game:GetService("RunService")\nlocal GuiService = game:GetService("GuiService")')
sub('local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))','local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))\nlocal ConsolePanelSupport = require(ReplicatedStorage.Shared:WaitForChild("ConsolePanelSupport"))')
sub('local selectedTarget: any = "All" -- "All" or Player','local selectedTarget: any = "All" -- "All" or numeric UserId; never serialize Player instances.')
sub('local hasAdminPermission = false','local hasAdminPermission = false\nlocal permissionKnown = false\nlocal selectedCommandAction: (() -> ())? = nil')
sub('if hasAdminPermission then return true end','if permissionKnown then return hasAdminPermission end')
-- Toast generation prevents an older timer from hiding newer feedback.
sub('local function showToast(message: string, success: boolean)','local toastGeneration = 0\nlocal function showToast(message: string, success: boolean)\n\ttoastGeneration += 1\n\tlocal generation = toastGeneration')
sub('if toastFrame and toastFrame.Visible then','if generation == toastGeneration and toastFrame and toastFrame.Visible then')
sub('if toastFrame then toastFrame.Visible = false end','if generation == toastGeneration and toastFrame then toastFrame.Visible = false end')
local helper=[=[-- Accept the suffixes shown on the preset chips. Invalid nonempty input never becomes a default grant.
local function parseArgument(text: string): number?
 local cleaned = string.lower(text):gsub("%s", ""):gsub("^%+", "")
 local numberText, suffix = cleaned:match("^(%d*%.?%d+)([kmbxs]?)$")
 local value = tonumber(numberText)
 if not value then return nil end
 local factors = { k = 1e3, m = 1e6, b = 1e9, x = 1, s = 1, [""] = 1 }
 value *= factors[suffix] or 1
 if value ~= value or value <= 0 or value == math.huge then return nil end
 return value
end

local function readArgument(default: number): number?
 local text = commandInputBox and commandInputBox.Text or ""
 if text:match("^%s*$") then return default end
 local value = parseArgument(text)
 if not value then showToast("Cantidad inválida. Usa un número, 1M, 5x o 30s.", false) end
 return value
end

]=]
sub('-- Forward declarations',helper..'-- Forward declarations')
sub('modal.ClipsDescendants = true','modal.ClipsDescendants = true\n\tmodal.Visible = false\n\tmodal.SelectionGroup = true\n\tmodal.SelectionBehaviorUp = Enum.SelectionBehavior.Stop\n\tmodal.SelectionBehaviorDown = Enum.SelectionBehavior.Stop\n\tmodal.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop\n\tmodal.SelectionBehaviorRight = Enum.SelectionBehavior.Stop')
sub('local scale = math.clamp(math.min(vSize.X / (MODAL_WIDTH + 60), vSize.Y / (MODAL_HEIGHT + 60)), 0.65, 1.25)','local scale = math.min(vSize.X / (MODAL_WIDTH + 60), vSize.Y / (MODAL_HEIGHT + 60), 1.25)')
sub('workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)\n\tupdateScale()',[[local cameraConnection
 local function bindCamera()
  if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
  local camera = workspace.CurrentCamera
  if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
  updateScale()
 end
 local changedCamera = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
 screenGui.Destroying:Connect(function()
  changedCamera:Disconnect()
  if cameraConnection then cameraConnection:Disconnect() end
 end)
 bindCamera()]])
s=s:gsub('%.MouseButton1Click:Connect','%.Activated:Connect')
sub('closeBtn.Parent = header','closeBtn.Parent = header\n\tConsolePanelSupport.Bind(screenGui, modal, closeBtn, closeBtn, function() closePanel() end)')
sub('tb.ClearTextOnFocus = false','tb.ClearTextOnFocus = false\n\ttb.Text = ""\n\ttb.Selectable = true')
sub('selectedCommandName = id','selectedCommandName = id\n\t\t\tselectedCommandAction = onClick')
s=s:gsub('local val = tonumber%(commandInputBox and commandInputBox.Text%) or 2','local val = readArgument(2)\n\t\tif not val then return end')
s=s:gsub('local dur = tonumber%(commandInputBox and commandInputBox.Text%) or 5','local dur = readArgument(5)\n\t\tif not dur then return end')
s=s:gsub('local amt = tonumber%(commandInputBox and commandInputBox.Text%) or (%d+)','local amt = readArgument(%1)\n\t\tif not amt then return end')
sub([[AdminPanelAction:FireServer({
			action = "UnragdollPlayers",
			target = selectedTarget,
		})
		AdminPanelAction:FireServer({
			action = "ResetScale",
			target = selectedTarget,
		})]],[[AdminPanelAction:FireServer({ action = "RestorePlayers", target = selectedTarget })]])
local a=assert(s:find('\t-- Connect Execute Button',1,true));local b=assert(s:find('\n\t-- Initial populate',a,true))
s=s:sub(1,a-1)..[=[	-- Apply a scalar to the selected card; manual commands choose their own explicit action.
 execBtn.Activated:Connect(function()
  playClickSound()
  local text = commandInputBox and commandInputBox.Text or ""
  if text:match("^%s*$") then
   if selectedCommandAction then selectedCommandAction() end
   return
  end
  if parseArgument(text) then
   if selectedCommandAction then selectedCommandAction()
   else showToast("Selecciona primero el comando para esta cantidad.", false) end
   return
  end
  local lower = text:lower():gsub("^%s*;?", ""):gsub("%s+$", "")
  local cmd, rawArg = lower:match("^(%S+)%s*(.*)$")
  local arg = rawArg ~= "" and parseArgument(rawArg) or nil
  if rawArg ~= "" and not arg then showToast("Argumento inválido: " .. rawArg, false); return end
  if cmd == "ragdoll" then
   AdminPanelAction:FireServer({ action = "RagdollPlayers", target = selectedTarget, duration = arg or 5 })
  elseif cmd == "tiny" then
   AdminPanelAction:FireServer({ action = "TinyPlayers", target = selectedTarget, scale = 0.5, duration = arg or 30 })
  elseif cmd == "unragdoll" then
   AdminPanelAction:FireServer({ action = "UnragdollPlayers", target = selectedTarget })
  elseif cmd == "restore" then
   AdminPanelAction:FireServer({ action = "RestorePlayers", target = selectedTarget })
  elseif cmd == "treadmill" then
   AdminPanelAction:FireServer({ action = "ToggleAdminTreadmill" })
  elseif cmd == "speed" or cmd == "givespeed" then
   AdminPanelAction:FireServer({ action = "GiveStats", stat = "Speed", amount = arg or 1000000, target = selectedTarget })
  elseif cmd == "wins" or cmd == "givewins" then
   AdminPanelAction:FireServer({ action = "GiveStats", stat = "Wins", amount = arg or 100000, target = selectedTarget })
  elseif cmd == "boost" or cmd == "speedboost" then
   AdminPanelAction:FireServer({ action = "ServerBoost", statType = "Speed", multiplier = arg or 2, minutes = 30 })
  elseif cmd == "winsboost" then
   AdminPanelAction:FireServer({ action = "ServerBoost", statType = "Wins", multiplier = arg or 2, minutes = 30 })
  elseif cmd == "gekkoh" then
   AdminPanelAction:FireServer({ action = "GekoFlyGiveaway", target = selectedTarget, minutes = 20 })
  else showToast("Comando no reconocido: " .. text, false) end
 end)
]=]..s:sub(b)
-- Preserve gamepad focus when cards rebuild (selection or player join/removal).
sub('updateProfilesList = function()','updateProfilesList = function(removedPlayer: Player?)')
sub('if not profilesListFrame then return end','if not profilesListFrame then return end\n\tlocal previousSelection = GuiService.SelectedObject\n\tlocal focusWasInList = previousSelection and previousSelection:IsDescendantOf(profilesListFrame)\n\tlocal focusName = previousSelection and previousSelection.Name')
sub('serverCard.AutoButtonColor = false','serverCard.AutoButtonColor = false\n\tserverCard.LayoutOrder = 0')
sub('for _, p in ipairs(Players:GetPlayers()) do','for index, p in ipairs(Players:GetPlayers()) do\n\t\tif p == removedPlayer then continue end')
sub('local isSel = (selectedTarget == p or selectedTarget == p.UserId)','local isSel = selectedTarget == p.UserId')
sub('pCard.AutoButtonColor = false','pCard.AutoButtonColor = false\n\t\tpCard.LayoutOrder = index')
sub('selectedTarget = p\n','selectedTarget = p.UserId\n')
sub('\nend\n\n-- Open / Close Animation','\n\tif focusWasInList then\n\t\tGuiService.SelectedObject = profilesListFrame:FindFirstChild(focusName) or profilesListFrame:FindFirstChild("Profile_" .. tostring(selectedTarget)) or serverCard\n\tend\nend\n\n-- Open / Close Animation')
sub('if isOpen or isClosing then return end','if not checkAdminImmediate() or isOpen or isClosing then return end\n\tMenuEvents.CloseAll:Fire("Admin")')
sub('dim.Visible = true\n\t\tdim.BackgroundTransparency','screenGui.Enabled = true\n\t\tdim.Visible = true\n\t\tmainFrame.Visible = true\n\t\tdim.BackgroundTransparency')
sub('if dim then dim.Visible = false end\n\t\tisOpen','if dim then dim.Visible = false end\n\t\tif mainFrame then mainFrame.Visible = false end\n\t\tisOpen')
sub('if dim then dim.Visible = false end\n\t\tisOpen','if dim then dim.Visible = false end\n\t\tif mainFrame then mainFrame.Visible = false end\n\t\tisOpen')
sub('if payload.kind == "Permission" then\n\t\tif payload.allowed == true then\n\t\t\thasAdminPermission = true','if payload.kind == "Permission" then\n\t\tpermissionKnown = true\n\t\thasAdminPermission = payload.allowed == true\n\t\tif not hasAdminPermission then closePanel(true) end\n\t\tif hasAdminPermission then')
s=s:gsub('hasAdminPermission = true\n\t\topenPanel','permissionKnown = true\n\t\thasAdminPermission = true\n\t\topenPanel')
s=s:gsub('hasAdminPermission = true\n\t\ttogglePanel','permissionKnown = true\n\t\thasAdminPermission = true\n\t\ttogglePanel')
sub('if selectedTarget == player then\n\t\tselectedTarget = "All"\n\tend\n\tif isOpen then updateProfilesList() end','if selectedTarget == player.UserId then\n\t\tselectedTarget = LocalPlayer.UserId\n\t\tshowToast("El objetivo salió. Ahora estás seleccionado tú.", false)\n\tend\n\tif isOpen then updateProfilesList(player) end')
-- Duplicate chat notifications and the server OpenUI must be idempotent.
sub('if checkAdminImmediate() then\n\t\t\ttogglePanel()\n\t\tend\n\tend\nend\n\nLocalPlayer.Chatted','if checkAdminImmediate() then\n\t\t\topenPanel()\n\t\tend\n\tend\nend\n\nLocalPlayer.Chatted')
sub('if LocalPlayer:GetAttribute("AdminCommands") == true then\n\t\thasAdminPermission = true\n\t\tbuildAdminUI()\n\tend','permissionKnown = true\n\thasAdminPermission = LocalPlayer:GetAttribute("AdminCommands") == true\n\tif hasAdminPermission then buildAdminUI() else closePanel(true) end')
fs.writeFile(path,s)
local m='src/common/ReplicatedStorage/Shared/MenuEvents.luau';s=fs.readFile(m):gsub('Admin = "SpeedsterAdminMiniPanel"','Admin = "SpeedsterAdminPanelGui"');fs.writeFile(m,s)
