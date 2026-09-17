--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DayCycle = require(ReplicatedStorage.Shared.DayCycle)

local T = {}

-- Every field a Look must have, and its expected typeof().
local FIELD_TYPES: { [string]: string } = {
	clock = "number",
	brightness = "number",
	exposure = "number",
	ambient = "Color3",
	outdoorAmbient = "Color3",
	atmosphereDensity = "number",
	atmosphereOffset = "number",
	atmosphereColor = "Color3",
	atmosphereDecay = "Color3",
	atmosphereGlare = "number",
	atmosphereHaze = "number",
	bloomIntensity = "number",
	sunRays = "number",
	gradeBrightness = "number",
	gradeContrast = "number",
	gradeSaturation = "number",
	gradeTint = "Color3",
	floodlights = "boolean",
	streetLights = "boolean",
}

local function approxColorEqual(a: Color3, b: Color3, eps: number): boolean
	return math.abs(a.R - b.R) < eps and math.abs(a.G - b.G) < eps and math.abs(a.B - b.B) < eps
end

local function assertLooksApproxEqual(a: any, b: any, name: string)
	for field, kind in FIELD_TYPES do
		if kind == "Color3" then
			assert(approxColorEqual(a[field], b[field], 0.01), name .. "." .. field .. " colour mismatch")
		elseif kind == "number" then
			assert(math.abs(a[field] - b[field]) < 0.01, name .. "." .. field .. " number mismatch")
		else
			assert(a[field] == b[field], name .. "." .. field .. " mismatch")
		end
	end
end

function T.everyLookHasEveryFieldWithRightType()
	for lookName, look in DayCycle.LOOKS do
		for field, kind in FIELD_TYPES do
			local value = (look :: any)[field]
			assert(value ~= nil, lookName .. " missing field " .. field)
			assert(typeof(value) == kind, lookName .. "." .. field .. " expected " .. kind .. " got " .. typeof(value))
		end
	end
end

function T.lerpEndpointsEqualInputs()
	local a = DayCycle.LOOKS.HeroAfternoon
	local b = DayCycle.LOOKS.Night
	assertLooksApproxEqual(DayCycle.lerpLook(a, b, 0), a, "lerp t=0")
	assertLooksApproxEqual(DayCycle.lerpLook(a, b, 1), b, "lerp t=1")
end

function T.clockWrapsForwardThroughMidnight()
	local base = DayCycle.LOOKS.HeroAfternoon
	local a = table.clone(base)
	a.clock = 22.5
	local b = table.clone(base)
	b.clock = 6.5
	local mid = DayCycle.lerpLook(a, b, 0.5)
	assert(math.abs(mid.clock - 2.5) < 0.01, "expected wrap midpoint 2.5, got " .. tostring(mid.clock))
end

function T.booleansSwitchAtHalfway()
	local a = table.clone(DayCycle.LOOKS.HeroAfternoon)
	local b = table.clone(DayCycle.LOOKS.EveningMatch)
	local justBelow = DayCycle.lerpLook(a, b, 0.49)
	local atHalf = DayCycle.lerpLook(a, b, 0.5)
	assert(justBelow.floodlights == a.floodlights, "should still be A's floodlights just below 0.5")
	assert(atHalf.floodlights == b.floodlights, "should switch to B's floodlights at 0.5")
end

local function assertStrictlyIncreasing(track, label: string)
	for i = 1, #track.keys - 1 do
		assert(track.keys[i].at < track.keys[i + 1].at, label .. " keys not strictly increasing at index " .. i)
	end
	assert(track.keys[#track.keys].at == track.duration, label .. " last key must land on duration")
end

function T.fastForwardMatchShapeAndDuration()
	local track = DayCycle.fastForward("match")
	assertStrictlyIncreasing(track, "match")
	assert(track.duration >= 3.5 and track.duration <= 4.5, "match fast-forward should be ~4s")
	assert(track.keys[1].look == "HeroAfternoon", "match should start on HeroAfternoon by default")
	assert(track.keys[#track.keys].look == "HeroAfternoon", "match should end on HeroAfternoon")
end

function T.fastForwardSeasonShapeAndDuration()
	local track = DayCycle.fastForward("season")
	assertStrictlyIncreasing(track, "season")
	assert(track.duration >= 9 and track.duration <= 11, "season fast-forward should be ~10s")
	assert(track.keys[1].look == "HeroAfternoon", "season should start on HeroAfternoon by default")
	assert(track.keys[#track.keys].look == "HeroAfternoon", "season should end on HeroAfternoon")
end

function T.fastForwardFromEveningStartsThere()
	local track = DayCycle.fastForward("match", true)
	assertStrictlyIncreasing(track, "match fromEvening")
	assert(track.keys[1].look == "EveningMatch", "fromEvening should start on EveningMatch")
	assert(track.keys[#track.keys].look == "HeroAfternoon", "should still end on HeroAfternoon")
end

function T.sampleClampsBeforeStartAndAfterEnd()
	local track = DayCycle.fastForward("match")
	local before = DayCycle.sample(track, -5)
	local afterStart = DayCycle.sample(track, 0)
	assertLooksApproxEqual(before, afterStart, "sample below range should clamp to t=0")
	assertLooksApproxEqual(before, DayCycle.LOOKS[track.keys[1].look], "sample below range should equal first look")

	local after = DayCycle.sample(track, track.duration + 5)
	local atEnd = DayCycle.sample(track, track.duration)
	assertLooksApproxEqual(after, atEnd, "sample above range should clamp to duration")
	assertLooksApproxEqual(after, DayCycle.LOOKS[track.keys[#track.keys].look], "sample above range should equal last look")
end

function T.sampleMidpointIsBetweenNeighbouringKeys()
	local track = DayCycle.fastForward("season")
	local a = track.keys[1]
	local b = track.keys[2]
	local mid = DayCycle.sample(track, (a.at + b.at) / 2)
	local lookA = DayCycle.LOOKS[a.look]
	local lookB = DayCycle.LOOKS[b.look]
	local lo = math.min(lookA.brightness, lookB.brightness)
	local hi = math.max(lookA.brightness, lookB.brightness)
	assert(mid.brightness >= lo - 0.01 and mid.brightness <= hi + 0.01, "midpoint brightness should sit between neighbours")
end

function T.isEveningFixtureNeverForOnboardingMatches()
	assert(DayCycle.isEveningFixture(1) == false, "match 1 must stay afternoon")
	assert(DayCycle.isEveningFixture(2) == false, "match 2 must stay afternoon")
end

function T.isEveningFixtureDeterministicAndRoughlyQuarter()
	local first = DayCycle.isEveningFixture(11)
	local second = DayCycle.isEveningFixture(11)
	assert(first == second, "isEveningFixture must be deterministic")

	local anyTrue = false
	local count = 0
	for i = 1, 100 do
		if DayCycle.isEveningFixture(i) then
			anyTrue = true
			count += 1
		end
	end
	assert(anyTrue, "expected at least some evening fixtures")
	assert(count >= 20 and count <= 30, "expected roughly 25% evening fixtures over 100 matches, got " .. count)
end

return T
