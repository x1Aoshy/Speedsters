local conveyor = script.Parent
local beam = conveyor:FindFirstChild("Beam")
local speed = script.Parent.Speed.Value

conveyor.Velocity = script.Parent.CFrame.LookVector * speed
conveyor.FrontSurface = "Studs"
script:Remove()

beam.TextureSpeed = speed / beam.TextureLength
