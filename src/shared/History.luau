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

export type History = { seasons: { SeasonRecord } }

export type Honours = {
	seasons: number,
	titles: number,
	promotions: number,
	relegations: number,
	bestTier: number,
}

function History.new(): History
	return { seasons = {} }
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
