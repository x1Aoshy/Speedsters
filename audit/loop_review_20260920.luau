local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local out = "output/LoopReview_20260920"
fs.writeDir(out)
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local report = { worlds = {}, errors = {}, mismatches = {} }
local compiled = {}
for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
	local raw = fs.readFile(place[2])
	local dm = rb.deserializePlace(raw)
	local count = 0
	for _, obj in dm:GetDescendants() do
		if obj:IsA("LuaSourceContainer") then
			count += 1
			if not compiled[obj.Source] then
				local ok, err = pcall(luau.compile, obj.Source)
				if not ok then table.insert(report.errors, place[1] .. ": " .. obj:GetFullName() .. ": " .. tostring(err)) end
				compiled[obj.Source] = true
			end
		end
	end
	for _, row in manifest.worlds[place[1]].scripts do
		local node = dm
		for _, segment in row.segments do node = node and node:FindFirstChild(segment) end
		if not node then
			table.insert(report.mismatches, { world = place[1], source = row.source, problem = "missing instance" })
		elseif fs.isFile(row.source) and node.Source:gsub("\r\n", "\n") ~= fs.readFile(row.source):gsub("\r\n", "\n") then
			table.insert(report.mismatches, { world = place[1], source = row.source, problem = "source differs" })
		end
	end
	report.worlds[place[1]] = { scripts = count, sha256 = serde.hash("sha256", raw) }
	print(place[1], count, "embedded scripts compiled")
end
fs.writeFile(out .. "/snapshot.json", serde.encode("json", report, true))
print("compile errors", #report.errors, "manifest/source mismatches", #report.mismatches)
for _, err in report.errors do print(err) end
for _, diff in report.mismatches do print(diff.world, diff.problem, diff.source) end
