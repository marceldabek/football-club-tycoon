--!strict
-- Club history: one record per completed season plus derived honours.
-- Pure and JSON-safe. HistoryService owns the table on the server.

local History = {}

export type SeasonRecord = {
	season: number,
	tier: number,
	division: string,
	position: number,
	outcome: string, -- League.Outcome
	played: number,
	won: number,
	drawn: number,
	lost: number,
	gf: number,
	ga: number,
	points: number,
	prize: number,
}

-- X288: a retirement (X277) used to be announced once on the season card and
-- then be gone for ever, so a twelve-season favourite with 300 appearances left
-- no trace anywhere in the club. The club keeps its servants.
export type Servant = {
	name: string,
	age: number, -- the age they retired at
	apps: number,
	goals: number,
	season: number, -- the season they retired at the end of
}

export type History = { seasons: { SeasonRecord }, servants: { Servant } }

export type Honours = {
	seasons: number,
	titles: number,
	promotions: number,
	relegations: number,
	bestTier: number,
}

-- TEMP cap: the list goes in the save, so keep it to the ones worth remembering.
History.MAX_SERVANTS = 8

function History.new(): History
	return { seasons = {}, servants = {} }
end

-- Most appearances first; a tie goes to goals, then to the later season, so a
-- new arrival never displaces an equal servant who came before.
function History.recordRetirement(history: History, servant: Servant)
	table.insert(history.servants, table.clone(servant))
	table.sort(history.servants, function(a, b)
		if a.apps ~= b.apps then
			return a.apps > b.apps
		end
		if a.goals ~= b.goals then
			return a.goals > b.goals
		end
		return a.season > b.season
	end)
	-- Review of X288: dropping the tail by appearances alone could evict the
	-- club's all-time top scorer, so the leading scorer is always kept.
	while #history.servants > History.MAX_SERVANTS do
		local topScorer, dropAt = 1, #history.servants
		for i, s in history.servants do
			if s.goals > history.servants[topScorer].goals then
				topScorer = i
			end
		end
		if dropAt == topScorer then
			dropAt -= 1
		end
		table.remove(history.servants, dropAt)
	end
end

-- A title is finishing first in any division. TEMP decision (M5 spec).
function History.isTitle(record: SeasonRecord): boolean
	return record.position == 1
end

function History.recordSeason(history: History, record: SeasonRecord)
	table.insert(history.seasons, table.clone(record))
end

function History.honours(history: History): Honours
	local h: Honours = { seasons = 0, titles = 0, promotions = 0, relegations = 0, bestTier = 0 }
	for _, r in history.seasons do
		h.seasons += 1
		if History.isTitle(r) then
			h.titles += 1
		end
		if r.outcome == "Promoted" then
			h.promotions += 1
		elseif r.outcome == "Relegated" then
			h.relegations += 1
		end
		h.bestTier = math.max(h.bestTier, r.tier)
	end
	return h
end

return History
