--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrowdSeats = require(ReplicatedStorage.Shared.CrowdSeats)

local T = {}

-- #6a: every fan's full width sits inside a seat block, never over the aisle
-- steps between blocks, for stand lengths from the smallest to the biggest.
function T.fansNeverSitInTheAisles()
	for len = 20, 260, 7 do
		local z0, z1 = -len / 2, len / 2
		local blocks = CrowdSeats.sections(z0, z1, true)
		for _, nudge in { 0, 0.9, 2.2 } do
			for _, block in blocks do
				for _, z in CrowdSeats.seatsIn(block[1], block[2], nudge) do
					local half = CrowdSeats.FAN_WIDTH / 2
					assert(z - half >= block[1] - 1e-6 and z + half <= block[2] + 1e-6,
						("fan at %.2f spills out of block %.2f..%.2f (len %d)"):format(z, block[1], block[2], len))
				end
			end
		end
		-- the aisles themselves: between consecutive blocks, AISLE_W wide
		for i = 2, #blocks do
			local gap = blocks[i][1] - blocks[i - 1][2]
			assert(math.abs(gap - CrowdSeats.AISLE_W) < 1e-6, "aisle width")
		end
	end
end

-- #6b: neighbours never touch at the shoulder.
function T.neighboursNeverClip()
	assert(CrowdSeats.SPACING > CrowdSeats.FAN_WIDTH, "spacing wider than a fan")
	local seats = CrowdSeats.seatsIn(0, 100, 0.5)
	for i = 2, #seats do
		assert(seats[i] - seats[i - 1] >= CrowdSeats.FAN_WIDTH, "gap between fans")
	end
end

function T.bleachersAreOneBenchWithNoAisles()
	local blocks = CrowdSeats.sections(-30, 30, false)
	assert(#blocks == 1 and blocks[1][1] == -29 and blocks[1][2] == 29, "one bench, 1 in from each end")
end

function T.seatsRoundTripThroughTheAttribute()
	local seats: { CrowdSeats.Seat } = {
		{ position = Vector3.new(1189.26, 4.5, -1318.9), yaw = -1.571, shirt = Color3.fromRGB(200, 30, 40), seed = 123456789 },
		{ position = Vector3.new(-3, 7.25, 12), yaw = 3.142, shirt = Color3.fromRGB(0, 255, 16), seed = 7 },
	}
	local back = CrowdSeats.decode(CrowdSeats.encode(seats))
	assert(#back == 2, "two seats back")
	for i, s in seats do
		local b = back[i]
		assert((b.position - s.position).Magnitude < 0.01, "position")
		assert(math.abs(b.yaw - s.yaw) < 0.001, "yaw")
		assert(b.seed == s.seed, "seed")
		assert(math.abs(b.shirt.R - s.shirt.R) < 0.005 and math.abs(b.shirt.G - s.shirt.G) < 0.005, "shirt")
	end
	assert(#CrowdSeats.decode(nil) == 0 and #CrowdSeats.decode("") == 0, "empty")
end

-- A growing crowd only ever adds fans on a phone's smaller budget: whether a
-- seat is kept depends on the seat alone, not on how many others there are.
function T.budgetKeepsAStableShare()
	local kept, total = 0, 5000
	for seed = 1, total do
		if CrowdSeats.keep(seed * 7919, 160) then
			kept += 1
		end
	end
	local share = kept / total
	assert(math.abs(share - 160 / CrowdSeats.MAX_FANS) < 0.03, ("share %.3f"):format(share))
	assert(CrowdSeats.keep(12345, CrowdSeats.MAX_FANS), "a full budget keeps everyone")
end

return T
