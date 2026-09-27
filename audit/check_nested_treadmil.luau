local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local ws = place:GetService("Workspace")
local nw1 = ws:FindFirstChild("neworld1")

print("Checking treadmills in neworld1:")
for _, name in {"Basic", "Golden", "Candy", "Diamond", "Needoh", "Admin", "Hacker"} do
    local tm = nw1 and nw1:FindFirstChild(name)
    if tm then
        local belt = tm:FindFirstChild("Treadmil", true)
        print("  Treadmill:", name, "found, nested Treadmil:", belt ~= nil)
        if not belt then
            print("    children of", name, ":")
            for _, c in tm:GetChildren() do
                print("      ", c.Name, c.ClassName)
                for _, sub in c:GetChildren() do
                    print("        ", sub.Name, sub.ClassName)
                end
            end
        end
    else
        print("  Treadmill:", name, "NOT found in neworld1")
    end
end
