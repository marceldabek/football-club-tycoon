--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchFeed = require(ReplicatedStorage.Shared.MatchFeed)

local T = {}

local function squad(): { { name: string, number: number, role: string } }
	local out = {}
	for i = 1, 16 do
		table.insert(out, { name = "Player " .. string.char(64 + i), number = i, role = if i == 1 then "GK" else "MF" })
	end
	return out
end

local function timeline(events): any
	return {
		events = events,
		home = { name = "Dino FC", kit = {}, squad = squad() },
		away = { name = "Marsh Rangers", kit = {}, squad = squad() },
	}
end

local function texts(lines): string
	local out = {}
	for _, l in lines do
		table.insert(out, ("%s %s"):format(MatchFeed.stamp(l), l.text))
	end
	return table.concat(out, " | ")
end

function T.theMinuteMatchesTheServersClock()
	-- the server does math.floor(elapsed / duration * 90)
	assert(MatchFeed.minute(0, 90) == 0, "kick-off is 0'")
	assert(MatchFeed.minute(45, 90) == 45, "half way is 45'")
	assert(MatchFeed.minute(89.9, 90) == 89, "89.9s of 90 is 89'")
	assert(MatchFeed.minute(200, 90) == 90, "and it never runs past 90'")
	assert(MatchFeed.minute(-5, 90) == 0, "nor before kick-off")
	assert(MatchFeed.minute(10, 0) == 0, "a zero-length match does not divide by zero")
end

function T.nothingHasHappenedYetButKickOff()
	local lines = MatchFeed.build(timeline({}), {}, 0, nil)
	assert(#lines == 1, "one line, got " .. #lines)
	assert(lines[1].kind == "kickoff", "and it is kick-off")
	assert(lines[1].text:find("Dino FC v Marsh Rangers", 1, true) ~= nil, "naming both sides: " .. lines[1].text)
end

function T.aChanceInTheFutureIsNotReportedYet()
	local tl = timeline({
		{ minute = 12, team = "Home", type = "GOAL", scorer = 9 },
		{ minute = 70, team = "Away", type = "GOAL" },
	})
	local lines = MatchFeed.build(tl, {}, 30, nil)
	assert(#lines == 2, "kick-off and the goal, got " .. texts(lines))
	assert(lines[2].kind == "goal" and lines[2].minute == 12, texts(lines))
	-- and once the clock reaches it
	local later = MatchFeed.build(tl, {}, 75, nil)
	assert(#later == 4, "kick-off, goal, half time, equaliser: " .. texts(later))
	assert(later[4].kind == "conceded" and later[4].text:find("Marsh Rangers score", 1, true) ~= nil, texts(later))
end

function T.theScoreRunsAlongWithTheGoals()
	local tl = timeline({
		{ minute = 10, team = "Home", type = "GOAL", scorer = 9 },
		{ minute = 20, team = "Away", type = "GOAL" },
		{ minute = 30, team = "Home", type = "GOAL", scorer = 10 },
	})
	local lines = MatchFeed.build(tl, {}, 40, nil)
	assert(lines[2].text:find("1-0", 1, true) ~= nil, "first goal: " .. lines[2].text)
	assert(lines[3].text:find("1-1", 1, true) ~= nil, "equaliser: " .. lines[3].text)
	assert(lines[4].text:find("2-1", 1, true) ~= nil, "winner: " .. lines[4].text)
end

function T.aGoalNamesTheManInTheShirt()
	local lines = MatchFeed.build(timeline({ { minute = 10, team = "Home", type = "GOAL", scorer = 9 } }), {}, 20, nil)
	assert(lines[2].text:find("9 I", 1, true) ~= nil, "shirt number and surname: " .. lines[2].text)
end

function T.aGoalAfterASubBelongsToTheSubstitute()
	-- X218's rule: slot 9 came off at 60', so the goal at 70' is the new man's
	local tl = timeline({
		{ minute = 40, team = "Home", type = "GOAL", scorer = 9 },
		{ minute = 70, team = "Home", type = "GOAL", scorer = 9 },
	})
	local subs = { { out = 9, ["in"] = 14, minute = 60, afterEvent = 1 } }
	local lines = MatchFeed.build(tl, subs, 80, nil)
	local first, second = nil, nil
	for _, l in lines do
		if l.kind == "goal" then
			if first == nil then
				first = l.text
			else
				second = l.text
			end
		end
	end
	assert(first and first:find("9 I", 1, true) ~= nil, "the starter keeps his: " .. tostring(first))
	assert(second and second:find("14 N", 1, true) ~= nil, "the substitute gets the second: " .. tostring(second))
end

function T.substitutionsAndTheCasualtyReadInOrder()
	local tl = timeline({
		{ minute = 20, team = "Home", type = "SAVE" },
		{ minute = 80, team = "Away", type = "MISS" },
	})
	local subs = { { out = 5, ["in"] = 12, minute = 60, afterEvent = 1 } }
	local lines = MatchFeed.build(tl, subs, 85, { injury = "5 Evans is down, and cannot carry on.", injuryMinute = 59 })
	local kinds = {}
	for _, l in lines do
		table.insert(kinds, l.kind)
	end
	local order = table.concat(kinds, ",")
	assert(order == "kickoff,save,halftime,injury,sub,miss", "got " .. order .. " (" .. texts(lines) .. ")")
end

function T.somethingThatHasNotHappenedYetStaysOff()
	local lines = MatchFeed.build(timeline({}), { { out = 5, ["in"] = 12, minute = 60 } }, 30, { injury = "down", injuryMinute = 70 })
	assert(#lines == 1, "only kick-off before either happens: " .. texts(lines))
end

function T.halfTimeArrivesOnceAndInThePastTense()
	local tl = timeline({ { minute = 30, team = "Home", type = "GOAL", scorer = 9 } })
	local before = MatchFeed.build(tl, {}, 44, nil)
	for _, l in before do
		assert(l.kind ~= "halftime", "no half time at 44'")
	end
	local after = MatchFeed.build(tl, {}, 46, nil)
	local seen = 0
	for _, l in after do
		if l.kind == "halftime" then
			seen += 1
			assert(l.text:find("1-0", 1, true) ~= nil, "with the score at the break: " .. l.text)
		end
	end
	assert(seen == 1, "exactly one half time line, got " .. seen)
end

function T.theKeeperIsNamedWhenHeSavesOne()
	local lines = MatchFeed.build(timeline({ { minute = 10, team = "Away", type = "SAVE" } }), {}, 20, nil)
	assert(lines[2].kind == "save" and lines[2].text:find("1 A", 1, true) ~= nil, "our keeper: " .. lines[2].text)
	-- our own shot saved is about their keeper, and names nobody
	local ours = MatchFeed.build(timeline({ { minute = 10, team = "Home", type = "SAVE" } }), {}, 20, nil)
	assert(ours[2].text:find("their keeper", 1, true) ~= nil, "theirs: " .. ours[2].text)
end

function T.fullTimeClosesTheFeedWithTheResult()
	local tl = timeline({ { minute = 10, team = "Home", type = "GOAL", scorer = 9 } })
	local lines = MatchFeed.build(tl, {}, 90, nil)
	local last = lines[#lines]
	assert(last.kind == "fulltime", "the last line is full time, got " .. last.kind)
	assert(last.text == "Full time  ·  Dino FC 1-0 Marsh Rangers", "got " .. last.text)
	-- and a match cut short still gets one when it is told the match is over
	local early = MatchFeed.build(tl, {}, 70, { finished = true })
	assert(early[#early].kind == "fulltime", "a finished match always ends on full time")
end

function T.latestTakesTheNewestFirstAndNeverOverruns()
	local lines = MatchFeed.build(timeline({
		{ minute = 10, team = "Home", type = "SAVE" },
		{ minute = 20, team = "Away", type = "MISS" },
		{ minute = 30, team = "Home", type = "GOAL", scorer = 9 },
	}), {}, 40, nil)
	local latest = MatchFeed.latest(lines, 2)
	assert(#latest == 2, "two rows, got " .. #latest)
	assert(latest[1].minute == 30 and latest[2].minute == 20, "newest first: " .. texts(latest))
	assert(#MatchFeed.latest(lines, 50) == #lines, "asking for more than there are gives all of them")
	assert(#MatchFeed.latest({}, 4) == 0, "and none of nothing")
end

return T
