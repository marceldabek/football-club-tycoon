--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BackYards = require(ReplicatedStorage.Shared.BackYards)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownFrontage = require(ReplicatedStorage.Shared.TownFrontage)

local T = {}

local ALLEY = { { name = "Back Test Street", kind = "alley", points = { Vector3.new(0, 0, 0), Vector3.new(200, 0, 0) } } }

function T.aHouseBackingOntoAnAlleyGetsAYardUpToItsEdge()
	-- house north of the alley (z = -20 back edge), doors facing north (-Z)
	local depth = BackYards.depthBehind(Vector3.new(100, 0, -20), Vector3.new(0, 0, -1), ALLEY)
	assert(depth and math.abs(depth - (20 - BackYards.alleyHalfWidth() - BackYards.WALL_SETBACK)) < 1e-6, "yard depth " .. tostring(depth))
end

function T.noYardWhenTheAlleyIsInFrontBesideOrTooFar()
	assert(BackYards.depthBehind(Vector3.new(100, 0, -20), Vector3.new(0, 0, 1), ALLEY) == nil, "alley is in front of the doors")
	assert(BackYards.depthBehind(Vector3.new(260, 0, -20), Vector3.new(0, 0, -1), ALLEY) == nil, "alley stops before this house")
	assert(BackYards.depthBehind(Vector3.new(100, 0, -60), Vector3.new(0, 0, -1), ALLEY) == nil, "alley is too far behind")
	assert(BackYards.depthBehind(Vector3.new(100, 0, -12), Vector3.new(0, 0, -1), ALLEY) == nil, "strip too shallow for a yard")
	assert(BackYards.depthBehind(Vector3.new(100, 0, -20), Vector3.new(-1, 0, 0), ALLEY) == nil, "row is square on to the alley")
end

function T.everyTownAlleyHasYardsOnBothSides()
	local lots = TownFrontage.generate()
	for _, road in TownLayout.ROADS do
		if road.kind == "alley" then
			local sides: { [number]: number } = { [1] = 0, [-1] = 0 }
			local dir = (road.points[2] - road.points[1]).Unit
			local normal = Vector3.new(-dir.Z, 0, dir.X)
			for _, lot in lots do
				if lot.use == "terraced row" then
					local back = lot.centre - lot.front * (lot.size.Z / 2)
					if BackYards.depthBehind(back, lot.front, { road } :: any) then
						local side = if (back - road.points[1]):Dot(normal) > 0 then 1 else -1
						sides[side] += 1
					end
				end
			end
			assert(sides[1] > 0 and sides[-1] > 0, ("%s has yards on %d / %d rows"):format(road.name, sides[1], sides[-1]))
		end
	end
end

return T
