--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Planting = require(ServerScriptService.Server.Planting)

local T = {}

function T.flowerHeadsStayInsideTheBed()
	for _, size in { Vector2.new(8.6, 3.6), Vector2.new(5.6, 3.6), Vector2.new(3.6, 3.6), Vector2.new(1.3, 1.3) } do
		local spots = Planting.headSpots(size.X, size.Y, Random.new(7))
		assert(#spots >= 1, "at least one flower")
		for _, p in spots do
			assert(math.abs(p.X) + Planting.HEAD / 2 <= size.X / 2 + 1e-6, ("head over the x edge in %s"):format(tostring(size)))
			assert(math.abs(p.Y) + Planting.HEAD / 2 <= size.Y / 2 + 1e-6, ("head over the z edge in %s"):format(tostring(size)))
		end
	end
	assert(#Planting.headSpots(8.6, 3.6, Random.new(1)) >= 6, "a big bed gets a good few heads")
end

function T.bloomBuildsDecorBallsOfOneSize()
	local holder = Instance.new("Folder")
	Planting.bloom(holder, CFrame.new(), 5.6, 3.6, Color3.new(1, 0, 0), Random.new(3))
	local balls = 0
	for _, p in holder:GetChildren() do
		assert(p.Name == "Flowers", "every part is decor-named")
		if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
			balls += 1
			assert(p.Size.X == p.Size.Y and p.Size.Y == p.Size.Z, "round heads")
		end
	end
	assert(balls >= 4, "balls " .. balls)
	holder:Destroy()
end

return T
