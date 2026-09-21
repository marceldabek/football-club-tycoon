--!strict
-- The six numbers on a player card. Display only: the match sim reads
-- `overall` and nothing here (CLAUDE.md s22). Nothing is stored either - the
-- stats are worked out from the overall, the role and the look seed each time,
-- so they rise as the player develops and an old save needs no migration.

local CardStats = {}

export type Stat = { label: string, value: number }

-- Offsets from the overall, in card order. TEMP weights.
local OUTFIELD = { "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }
local KEEPER = { "DIV", "HAN", "KIC", "REF", "SPD", "POS" }
local SHAPE: { [string]: { number } } = {
	FWD = { 3, 5, -4, 3, -30, -2 },
	MID = { -1, -4, 5, 3, -8, -3 },
	DEF = { -3, -25, -6, -10, 5, 4 },
	GK = { 2, 0, -6, 3, -20, 1 },
}
local JITTER = 4 -- each stat moves this far either way, fixed for the player's life

function CardStats.of(p: { overall: number, role: string, look: number?, id: number }): { Stat }
	local shape = SHAPE[p.role] or SHAPE.MID
	local labels = if p.role == "GK" then KEEPER else OUTFIELD
	local seed = p.look or p.id
	local out: { Stat } = {}
	for i = 1, 6 do
		local wobble = Random.new(seed + i * 7919):NextInteger(-JITTER, JITTER)
		out[i] = { label = labels[i], value = math.clamp(p.overall + shape[i] + wobble, 1, 99) }
	end
	return out
end

return CardStats
