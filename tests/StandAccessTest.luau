--!strict
-- #13 / #15: end stairs, rear gates and vomitories (ground plan spec s3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StandAccess = require(ReplicatedStorage.Shared.StandAccess)

local T = {}

-- WorldBuilder's stand numbers: STEP_DEPTH 3, stepHeight 1.5, STAND_X0 0.6, DECK_Y 1
local DEPTH, RISE, X0, DECK = 3, 1.5, 0.6, 1
local ROWS = { 3, 8, 12, 16 }

function T.stairsClimbFromTheGroundToTheBackRowInEasySteps()
	for _, rows in ROWS do
		local steps = StandAccess.stairSteps(rows, DEPTH, RISE, X0, DECK)
		assert(#steps >= rows * 2, "at least two steps a row")
		local prevTop, prevX = 0, X0
		for k, st in steps do
			assert(math.abs(st.x0 - prevX) < 1e-6, "steps abut")
			assert(st.top - prevTop > 0 and st.top - prevTop <= 0.8, ("rows %d step %d rises %g"):format(rows, k, st.top - prevTop))
			prevTop, prevX = st.top, st.x1
		end
		assert(math.abs(prevTop - (DECK + RISE * rows)) < 1e-6, "the top step is level with the back row")
		assert(math.abs(prevX - (X0 + DEPTH * rows)) < 1e-6, "and ends at the back of the terrace")
	end
end

function T.everyEndGetsAStairExceptTheWestWingsClubhouseEnds()
	local east = StandAccess.ends("East", { { -102, 102 } })
	assert(#east == 2 and east[1].kind == "stair" and east[2].kind == "stair", "both east ends")
	assert(east[1].dir == -1 and east[2].dir == 1, "stairs lie outside the terrace")
	local west = StandAccess.ends("West", { { -143, -41 }, { 41, 143 } })
	local rails, stairs = 0, 0
	for _, e in west do
		if e.kind == "rail" then
			rails += 1
			assert(math.abs(e.z) == 41, "the rail is on the clubhouse end")
		else
			stairs += 1
			assert(math.abs(e.z) == 143, "the stair is on the outer end")
		end
	end
	assert(rails == 2 and stairs == 2, "two of each")
end

function T.openingsWhereTheSpecPutsThem()
	assert(#StandAccess.openingCentres("East", 1, { { -32.5, 32.5 } }) == 0, "none on bleachers")
	local east = StandAccess.openingCentres("East", 2, { { -102, 102 } })
	assert(#east == 2 and east[1] == -70 and east[2] == 70, "east at z +-70")
	local north = StandAccess.openingCentres("North", 4, { { -98.5, 98.5 } })
	assert(#north == 2 and north[1] == -40 and north[2] == 40, "ends at +-40")
	local west = StandAccess.openingCentres("West", 3, { { -155, -41 }, { 41, 155 } })
	assert(#west == 2 and west[1] == -98 and west[2] == 98, "each west wing at its centre")
end

-- Under every carried row there is a full head room over the ramp; the rows in
-- front of the mouth are untouched; the ramp comes out level with the mouth row.
function T.vomitoriesLeaveHeadRoomAndMeetTheMouthRow()
	for _, rows in { 8, 12, 16 } do
		local r = StandAccess.ramp(rows, DEPTH, RISE, X0, DECK)
		assert(math.abs(r.hMouth - (DECK + RISE * r.mouthRow)) < 1e-6, "ramp top is the mouth row's top")
		assert(StandAccess.rampFloor(r, r.xBack) == 0, "ramp foot at ground level")
		assert((r.hMouth / (r.xBack - r.xMouth)) < 0.7, "walkable slope")
		local cut = 0
		for i = 1, rows do
			local mode, under = StandAccess.rowOverOpening(i, rows, DEPTH, RISE, X0, DECK)
			if i <= r.mouthRow then
				assert(mode == "none", "front rows untouched")
			elseif mode == "carried" then
				local front = X0 + DEPTH * (i - 1)
				assert(under and under - StandAccess.rampFloor(r, front) >= StandAccess.CLEAR_H - 1e-6, "head room")
				assert(DECK + RISE * i - (under :: number) >= StandAccess.SLAB_MIN - 1e-6, "a real slab")
			else
				assert(mode == "cut", "mode " .. mode)
				cut += 1
			end
		end
		assert(cut >= 1, "the mouth is open behind the mouth row")
		assert(StandAccess.rowOverOpening(rows, rows, DEPTH, RISE, X0, DECK) == "carried", "the back row is carried")
	end
end

return T
