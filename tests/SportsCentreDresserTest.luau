--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SportsCentreDresser = require(ServerScriptService.Server.SportsCentreDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.pitchLinesStayInsideTheSlabAndMirror()
	for _, dims in { { 160, 240 }, { 60, 120 }, { 80, 120 } } do
		local width, length = dims[1], dims[2]
		local lines = SportsCentreDresser.pitchLines(width, length)
		assert(#lines == 11, "4 edges, halfway, 3 lines per penalty box: got " .. #lines)
		local sumX, sumZ = 0, 0
		for _, r in lines do
			assert(r.x1 > r.x0 and r.z1 > r.z0, "non-empty rect")
			assert(r.x0 >= -width / 2 and r.x1 <= width / 2 and r.z0 >= -length / 2 and r.z1 <= length / 2, "inside the slab")
			sumX += (r.x0 + r.x1) / 2
			sumZ += (r.z0 + r.z1) / 2
		end
		assert(math.abs(sumX) < 1e-6 and math.abs(sumZ) < 1e-6, "mirror-symmetric about the centre")
	end
end

function T.goalWidthIsClamped()
	assert(SportsCentreDresser.goalWidth(60) == 14, "small pitch floor")
	assert(math.abs(SportsCentreDresser.goalWidth(160) - 19.2) < 1e-6, "12% of 160")
	assert(SportsCentreDresser.goalWidth(400) == 24, "cap")
end

function T.theSportsCentreHasPitchesAndAHall()
	local pitches, halls = 0, 0
	for _, district in TownLayout.DISTRICTS do
		if district.name == "Community Sports Centre" then
			for _, block in district.blocks do
				if block.use == "grass pitch" or block.use == "3G pitch" then
					pitches += 1
				elseif block.use == "sports hall" then
					halls += 1
				end
			end
		end
	end
	assert(pitches >= 2 and halls >= 1, "layout still has the sports centre blocks")
end

function T.carParkRectPicksAClearSideBesideTheHall()
	local o = CFrame.new(5000, 0, 5000)
	local r = SportsCentreDresser.carParkRect(o, 80, 120, 40, {}, {})
	assert(r, "open ground: a car park")
	assert(r.z0 >= 40 + 8 - 1e-3, "beside the +Z wall with a gap")
	assert(math.abs(r.x0 - (-60 - 40)) < 1e-3 and math.abs(r.x1 - 60) < 1e-3, "from the road edge back to the hall's back")
	-- a block on the +Z side sends it to -Z
	local block: TownLayout.Box = { centre = (o * Vector3.new(0, 0, 90)), size = Vector3.new(40, 10, 40), yaw = 0, use = "semis" }
	local other = SportsCentreDresser.carParkRect(o, 80, 120, 40, {}, { block })
	assert(other and other.z1 <= -48 + 1e-3, "moves to the -Z side")
	local both: TownLayout.Box = { centre = (o * Vector3.new(0, 0, -90)), size = Vector3.new(40, 10, 40), yaw = 0, use = "semis" }
	assert(SportsCentreDresser.carParkRect(o, 80, 120, 40, {}, { block, both }) == nil, "no clear side: nil")
end

return T
