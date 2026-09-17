--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubCard = require(ReplicatedStorage.Shared.ClubCard)

local T = {}

function T.starsSortByOverallThenGoals()
	local stars = ClubCard.stars({
		{ id = 1, name = "A", role = "GK", overall = 50, goals = 0 },
		{ id = 2, name = "B", role = "FWD", overall = 55, goals = 1 },
		{ id = 3, name = "C", role = "FWD", overall = 55, goals = 7 },
		{ id = 4, name = "D", role = "MID", overall = 40 },
	}, 3)
	assert(#stars == 3, "capped at 3")
	assert(stars[1].name == "C" and stars[2].name == "B" and stars[3].name == "A", "order")
	assert(stars[3].goals == 0 and stars[1].apps == 0, "defaults")
end

function T.starsIgnoreJunk()
	assert(#ClubCard.stars(nil) == 0, "nil")
	assert(#ClubCard.stars({ 5, { overall = 60 }, { name = "Ok" } }) == 1, "only named rows")
end

function T.summaryMidSeason()
	local s = ClubCard.summary({
		ClubName = "Lune Albion",
		DivisionName = "County League",
		Season = 3,
		Round = 8,
		Rounds = 10,
		Position = 2,
		MatchesPlayed = 27,
		Wins = 12,
		Draws = 8,
		Losses = 7,
		Capacity = 900,
		Stand_North = 2,
		Stand_East = 1,
	}, { players = { { id = 1, name = "Kit", role = "MID", overall = 60, goals = 4, apps = 20 } } })
	assert(s.clubName == "Lune Albion", s.clubName)
	assert(s.league == "County League · Season 3", s.league)
	assert(s.standing == "2nd after 8 of 10 matches", s.standing)
	assert(s.record == "27 played · 12 W · 8 D · 7 L", s.record)
	assert(s.ground == "Capacity 900 · 3 stand upgrades", s.ground)
	assert(#s.stars == 1 and s.stars[1].name == "Kit", "stars")
end

function T.summaryFreshClub()
	local s = ClubCard.summary({ Stand_West = 1 }, nil)
	assert(s.clubName == "A Rivermere club", s.clubName)
	assert(s.standing == "A new season is about to start.", s.standing)
	assert(s.ground == "Capacity 0 · 1 stand upgrade", s.ground)
	assert(#s.stars == 0, "no players")
end

function T.ordinalTeens()
	local s = ClubCard.summary({ Round = 1, Position = 11 }, nil)
	assert(s.standing:sub(1, 4) == "11th", s.standing)
	s = ClubCard.summary({ Round = 1, Position = 3 }, nil)
	assert(s.standing:sub(1, 3) == "3rd", s.standing)
end

function T.watchingLineShowsScoreAndMinute()
	local line = ClubCard.watchingLine({
		ClubName = "Lune Albion",
		Opponent = "Brindle Heath",
		HomeGoals = 1,
		AwayGoals = 0,
		MatchDuration = 90,
		TimeLeft = 30,
	})
	assert(line == "Watching  Lune Albion 1 - 0 Brindle Heath  ·  60'", line)
	local kickoff = ClubCard.watchingLine({ MatchDuration = 60, TimeLeft = 60 })
	assert(kickoff == "Watching  Home 0 - 0 Away  ·  0'", kickoff)
	local over = ClubCard.watchingLine({ MatchDuration = 60, TimeLeft = -5 })
	assert(over:sub(-3) == "90'", over)
end

return T
