-- Shared presentation for runtime menus, using the game's authored Settings art.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local StudUi=require(script.Parent.StudUi)
local Style={Ink=Color3.fromRGB(11,27,45),CardColor=Color3.fromRGB(50,78,111),Green=Color3.fromRGB(70,210,85)}
function Style.Outline(object,width)
 local stroke=object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
 stroke.Color=Style.Ink;stroke.Thickness=width or 2;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=object
 local corner=object:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,12);corner.Parent=object
end
function Style.Text(label)
 label.Font=Enum.Font.FredokaOne
 label.TextColor3=Color3.fromRGB(255,255,255)
 label.TextStrokeColor3=Style.Ink;label.TextStrokeTransparency=0.35
end
function Style.Button(button)
 Style.Outline(button,2)
 button.Selectable=true
 StudUi.StyleButton(button,10)
end
function Style.Card(card)
 card.BackgroundColor3=Style.CardColor;card.BorderSizePixel=0
 Style.Outline(card,2)
end
function Style.Panel(gui,panel,header,width,height,adaptive)
 gui.DisplayOrder=120;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true
 panel.BackgroundColor3=Color3.fromRGB(24,38,68);panel.BackgroundTransparency=0
 panel.Size=UDim2.fromOffset(width,height);panel.ZIndex=2;panel.ClipsDescendants=true
 Style.Outline(panel,4)
 local old=panel:FindFirstChild("UIStudSurface");if old then old:Destroy() end
 local settings=Players.LocalPlayer.PlayerGui:FindFirstChild("Settings")
 local authored=settings and settings:FindFirstChild("Settings")
 local background=authored and authored:FindFirstChild("Background")
 if background and background:IsA("ImageLabel") then
  local art=background:Clone();art.Name="AuthoredMenuBackground";art.Size=UDim2.fromScale(1,1);art.Position=UDim2.fromScale(0,0)
  art.ZIndex=2;art.Active=false;art.Selectable=false;art.Parent=panel
 end
 for _,child in panel:GetChildren() do
  if child:IsA("GuiObject") and child.Name~="AuthoredMenuBackground" then child.ZIndex=4 end
 end
 header.BackgroundColor3=Color3.fromRGB(40,123,206);header.ZIndex=4
 StudUi.AddSurface(header,4,12,12,2)
 for _,child in header:GetChildren() do if child:IsA("GuiObject") and child.Name~="UIStudSurface" then child.ZIndex=6 end end
 local scale=panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale");scale.Parent=panel
 local connection
 local function resize()
  local camera=Workspace.CurrentCamera
  local view=camera and camera.ViewportSize or Vector2.new(1280,720)
  if adaptive then
   panel.Size=UDim2.fromOffset(math.min(width,math.max(200,view.X-24)),math.min(height,math.max(200,view.Y-64)))
   scale.Scale=1
  else
   scale.Scale=math.min(1,math.max(0.1,(view.X-24)/width),math.max(0.1,(view.Y-64)/height))
  end
 end
 local function bind()
  if connection then connection:Disconnect() end
  local camera=Workspace.CurrentCamera
  if camera then connection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
  resize()
 end
 Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind);bind()
end

-- The designer's window, as the Settings, Rebirth and Shop panels are drawn: a white frame
-- over the blocky background art, a dark outline, the title sitting on the top edge and
-- the round close button on the top-right corner.
Style.BlockyBackground="rbxassetid://106477372921851"
Style.CloseImage="rbxassetid://110882579806743"
Style.TitleFont=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)

-- The window keeps `width` x `height` and shrinks to fit the screen (never grows), with
-- `marginX` / `marginY` pixels left around it. Returns the window and its close button.
-- The art is named "Background", which ModalJuice leaves alone (it animates other images
-- placed straight in a window as header icons).
function Style.BlockyWindow(gui,options)
 local width,height=options.Width,options.Height
 local window=Instance.new("Frame")
 window.Name=options.Name or "Window"
 window.AnchorPoint=Vector2.new(0.5,0.5)
 window.Position=UDim2.fromScale(0.5,0.52)
 window.Size=UDim2.fromOffset(width,height)
 window.BackgroundColor3=Color3.fromRGB(255,255,255)
 window.BackgroundTransparency=0.15
 window.BorderSizePixel=0
 window.Active=true
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,22);corner.Parent=window
 local stroke=Instance.new("UIStroke");stroke.Color=Style.Ink;stroke.Thickness=5;stroke.Parent=window
 local art=Instance.new("ImageLabel")
 art.Name="Background";art.BackgroundTransparency=1;art.Size=UDim2.fromScale(1,1)
 art.Image=Style.BlockyBackground;art.ImageTransparency=0.15;art.ScaleType=Enum.ScaleType.Stretch
 art.ZIndex=0;art.Active=false;art.Parent=window
 local artCorner=Instance.new("UICorner");artCorner.CornerRadius=UDim.new(0,22);artCorner.Parent=art
 local title=Instance.new("TextLabel")
 title.Name="Title";title.AnchorPoint=Vector2.new(0.5,0.5);title.Position=UDim2.fromScale(0.5,0)
 title.Size=UDim2.fromOffset(math.floor(width*0.66),options.TitleHeight or 64)
 title.BackgroundTransparency=1;title.Text=options.Title or "";title.TextScaled=true
 title.FontFace=Style.TitleFont;title.TextColor3=Color3.fromRGB(255,255,255);title.ZIndex=3
 local titleStroke=Instance.new("UIStroke");titleStroke.Color=Style.Ink;titleStroke.Thickness=4;titleStroke.Parent=title
 title.Parent=window
 local close=Instance.new("ImageButton")
 close.Name="Close";close.AnchorPoint=Vector2.new(0.5,0.5);close.Position=UDim2.new(1,-30,0,18)
 close.Size=UDim2.fromOffset(72,72);close.BackgroundTransparency=1;close.Image=Style.CloseImage;close.ZIndex=5
 local square=Instance.new("UIAspectRatioConstraint");square.AspectRatio=1;square.Parent=close
 close.Parent=window
 local fit=Instance.new("UIScale");fit.Name="FitScale";fit.Parent=window
 local marginX,marginY=options.MarginX or 24,options.MarginY or 72
 local connection
 local function resize()
  local camera=Workspace.CurrentCamera
  local view=camera and camera.ViewportSize or Vector2.new(1280,720)
  fit.Scale=math.min(1,math.max(0.3,(view.X-marginX)/width),math.max(0.3,(view.Y-marginY)/height))
 end
 local function bind()
  if connection then connection:Disconnect() end
  local camera=Workspace.CurrentCamera
  if camera then connection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
  resize()
 end
 Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind);bind()
 window.Parent=gui
 return window,close
end
return Style
