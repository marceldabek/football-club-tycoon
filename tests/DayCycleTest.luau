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
	-- X327
	rain = "number",
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

-- X321: WORLD_VISION s3 asks for the occasional grey week in the transition.
function T.fastForwardHasAnOccasionalOvercastWeek()
	local wet, dry = 0, 0
	for week = 1, 30 do
		local track = DayCycle.fastForward("match", false, week)
		local grey = false
		local rains = false
		for _, key in track.keys do
			if key.look == "Overcast" or key.look == "Wet" then
				grey = true
			end
			if key.look == "Wet" then
				rains = true
			end
		end
		-- X327: a grey week is a wet one, and it clears before the match
		assert(grey == rains, "a grey week should rain, and a clear week should not")
		if grey then wet += 1 else dry += 1 end
		-- whatever the week, the sweep ends on the look a match is played in
		assert(track.keys[#track.keys].look == "HeroAfternoon", "the sweep must end on the hero afternoon")
		assert(track.keys[#track.keys].at == track.duration, "and end at the end")
	end
	assert(wet > 0 and dry > wet, ("about a third of weeks should be grey: %d wet, %d dry"):format(wet, dry))
	-- Deterministic in the sense that matters: the same seed gives the same
	-- track, key for key, and a different seed is allowed to differ. (The first
	-- version compared isOvercastWeek(4) with itself, which asserts nothing.)
	local a = DayCycle.fastForward("match", false, 4)
	local b = DayCycle.fastForward("match", false, 4)
	assert(#a.keys == #b.keys, "the same week should give the same number of keys")
	for i, key in a.keys do
		assert(key.look == b.keys[i].look and key.at == b.keys[i].at, "the same week must sweep the same way")
	end
	local wetWeek, dryWeek = nil, nil
	for week = 1, 12 do
		if DayCycle.isOvercastWeek(week) then
			wetWeek = wetWeek or week
		else
			dryWeek = dryWeek or week
		end
	end
	assert(wetWeek and dryWeek, "there should be both kinds of week in the first dozen")
	local wetTrack = DayCycle.fastForward("match", false, wetWeek)
	local dryTrack = DayCycle.fastForward("match", false, dryWeek)
	-- a wet week has extra beats, so compare what they have in common too
	local differs = #wetTrack.keys ~= #dryTrack.keys
	for i, key in wetTrack.keys do
		local dry = dryTrack.keys[i]
		if dry and key.look ~= dry.look then
			differs = true
		end
	end
	assert(differs, "a grey week and a clear week should not sweep identically")
	-- and a clear week is exactly what it was before the rain went in (review)
	assert(#dryTrack.keys == 6, "a dry match sweep should still be six keys, got " .. #dryTrack.keys)
	local drySeason = DayCycle.fastForward("season", false, dryWeek)
	assert(#drySeason.keys == 7, "a dry season sweep should still be seven keys, got " .. #drySeason.keys)
	for _, key in dryTrack.keys do
		assert(key.look ~= "Wet" and key.look ~= "Overcast", "a clear week has no grey in it")
	end
	assert(not DayCycle.isOvercastWeek(nil), "no seed means no weather")
	-- X327: the rain is in the looks, and every look says whether it is raining
	assert(DayCycle.LOOKS.Wet.rain == 1, "the wet look should rain")
	assert(DayCycle.LOOKS.HeroAfternoon.rain == 0, "the hero afternoon should not")
	local half = DayCycle.lerpLook(DayCycle.LOOKS.HeroAfternoon, DayCycle.LOOKS.Wet, 0.5)
	assert(math.abs(half.rain - 0.5) < 0.001, "rain should come in gradually, got " .. tostring(half.rain))
	local season = DayCycle.fastForward("season", false, 1)
	assert(season.keys[#season.keys].look == "HeroAfternoon", "the season sweep ends on the hero afternoon too")
end

return T
