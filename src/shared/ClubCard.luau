--!strict
-- The read-only club card a visitor sees in another club's office (I1.1).
-- Pure: takes the club folder's attributes (already replicated to every
-- client) and the decoded Club JSON, returns what to show.

local ClubCard = {}

export type PlayerRow = { name: string, role: string, overall: number, goals: number, apps: number }

export type Summary = {
	clubName: string,
	league: string, -- "County League · Season 3"
	standing: string, -- "5th after 8 of 10 matches" / "A new season is about to start."
	record: string, -- "27 played · 12 W · 8 D · 7 L"
	ground: string, -- "Capacity 150 · 1 stand upgrade"
	stars: { PlayerRow },
}

local STAR_COUNT = 5

local function ordinal(n: number): string
	local last, lastTwo = n % 10, n % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return n .. "th"
	end
	return n .. (if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

local function num(v: unknown, default: number): number
	return if type(v) == "number" then v else default
end

local function str(v: unknown, default: string): string
	return if type(v) == "string" and v ~= "" then v else default
end

-- Best players first: overall, then goals, then shirt order. Injured players
-- still count; a visitor is looking at the club, not picking a team.
function ClubCard.stars(players: unknown, count: number?): { PlayerRow }
	local rows: { PlayerRow & { id: number } } = {}
	if type(players) == "table" then
		for _, p in players :: { any } do
			if type(p) == "table" and type(p.name) == "string" then
				table.insert(rows, {
					id = num(p.id, 0),
					name = p.name,
					role = str(p.role, "?"),
					overall = num(p.overall, 0),
					goals = num(p.goals, 0),
					apps = num(p.apps, 0),
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.overall ~= b.overall then
			return a.overall > b.overall
		end
		if a.goals ~= b.goals then
			return a.goals > b.goals
		end
		return a.id < b.id
	end)
	local out: { PlayerRow } = {}
	for i = 1, math.min(count or STAR_COUNT, #rows) do
		local r = rows[i]
		table.insert(out, { name = r.name, role = r.role, overall = r.overall, goals = r.goals, apps = r.apps })
	end
	return out
end

function ClubCard.summary(attrs: { [string]: any }, club: any): Summary
	local round, rounds = num(attrs.Round, 0), num(attrs.Rounds, 10)
	local played = num(attrs.MatchesPlayed, 0)
	local standUps = 0
	for _, side in { "North", "East", "South", "West" } do
		standUps += num(attrs["Stand_" .. side], 0)
	end
	return {
		clubName = str(attrs.ClubName, "A Rivermere club"),
		league = ("%s · Season %d"):format(str(attrs.DivisionName, "League"), num(attrs.Season, 1)),
		standing = if round > 0
			then ("%s after %d of %d matches"):format(ordinal(num(attrs.Position, 1)), round, rounds)
			else "A new season is about to start.",
		record = ("%d played · %d W · %d D · %d L"):format(
			played,
			num(attrs.Wins, 0),
			num(attrs.Draws, 0),
			num(attrs.Losses, 0)
		),
		ground = ("Capacity %d · %d stand upgrade%s"):format(
			num(attrs.Capacity, 0),
			standUps,
			if standUps == 1 then "" else "s"
		),
		stars = ClubCard.stars(if type(club) == "table" then club.players else nil),
	}
end

return ClubCard
