--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLifeMath = require(ReplicatedStorage.Shared.TownLifeMath)

local T = {}

local EPS = 1e-4

function T.bannerTextKeepsNamesAt12CharsOrLess()
	assert(TownLifeMath.bannerText("Rivermere FC") == "Rivermere FC", "12-char name should be kept whole")
	assert(TownLifeMath.bannerText("Your Club") == "Your Club", "short name should be kept whole")
end

function T.bannerTextAbbreviatesLongerNames()
	assert(TownLifeMath.bannerText("Bramblewick Rovers") == "BR", "expected initials BR")
	assert(TownLifeMath.bannerText("Oakhollow United") == "OU", "expected initials OU")
end

function T.bannerTextHandlesASingleLongWord()
	assert(TownLifeMath.bannerText("Superlongclubname") == "S", "single-word initials should be its first letter")
end

function T.stationsAlongMatchesStreetDresserSemantics()
	local points = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0), Vector3.new(100, 0, 100) }
	local st = TownLifeMath.stationsAlong(points, 40)
	assert(#st == 5, "expected 5 stations, got " .. #st)
	assert((st[1].position - Vector3.new(20, 0, 0)).Magnitude < EPS, "first station")
	assert((st[3].position - Vector3.new(100, 0, 0)).Magnitude < EPS, "third station at the corner")
	assert((st[4].position - Vector3.new(100, 0, 40)).Magnitude < EPS, "fourth station on the second leg")
	assert(st[4].direction.Z > 0.99, "direction follows the second leg")
end

function T.stationsAlongSkipsZeroLengthSegments()
	local points = { Vector3.new(0, 0, 0), Vector3.new(0, 5, 0), Vector3.new(60, 0, 0) }
	local st = TownLifeMath.stationsAlong(points, 60)
	assert(#st == 1, "expected the degenerate first segment to be skipped, got " .. #st)
	assert((st[1].position - Vector3.new(30, 0, 0)).Magnitude < EPS, "station " .. tostring(st[1].position))
end

function T.bladeCFrameRotatesAboutWorldXThroughTheHub()
	local hub = Vector3.new(5, 0, 0)
	local offset = CFrame.new(0, 10, 0)
	-- rotating (0, 10, 0) a quarter turn about X sends it to (0, 0, 10)
	local cf = TownLifeMath.bladeCFrame(hub, offset, math.pi / 2)
	assert((cf.Position - Vector3.new(5, 0, 10)).Magnitude < EPS, "position " .. tostring(cf.Position))
end

function T.bladeCFrameAtZeroAngleIsJustTheOffsetAtTheHub()
	local hub = Vector3.new(2, 0, 0)
	local offset = CFrame.new(1, 0, 0)
	local cf = TownLifeMath.bladeCFrame(hub, offset, 0)
	assert((cf.Position - Vector3.new(3, 0, 0)).Magnitude < EPS, "position " .. tostring(cf.Position))
end

return T
