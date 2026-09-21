--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CardStats = require(ReplicatedStorage.Shared.CardStats)

local T = {}

local function player(role: string, overall: number, look: number)
	return { id = 1, role = role, overall = overall, look = look }
end

local function value(stats, label: string): number
	for _, s in stats do
		if s.label == label then
			return s.value
		end
	end
	error("no stat " .. label)
end

function T.sixStatsInRange()
	for _, role in { "GK", "DEF", "MID", "FWD" } do
		for _, overall in { 30, 45, 70, 99 } do
			local stats = CardStats.of(player(role, overall, 1234))
			assert(#stats == 6, "expected six stats")
			for _, s in stats do
				assert(s.value >= 1 and s.value <= 99, s.label .. " out of range")
				assert(#s.label == 3, "labels are three letters")
			end
		end
	end
end

function T.deterministic()
	local a = CardStats.of(player("MID", 60, 777))
	local b = CardStats.of(player("MID", 60, 777))
	for i = 1, 6 do
		assert(a[i].value == b[i].value and a[i].label == b[i].label, "not deterministic")
	end
end

function T.shapedByRole()
	for look = 1, 50 do
		local fwd = CardStats.of(player("FWD", 60, look))
		assert(value(fwd, "SHO") > value(fwd, "DEF"), "a forward shoots better than he defends")
		local def = CardStats.of(player("DEF", 60, look))
		assert(value(def, "DEF") > value(def, "SHO"), "a defender defends better than he shoots")
	end
end

function T.keeperHasKeeperLabels()
	local gk = CardStats.of(player("GK", 60, 5))
	assert(gk[1].label == "DIV" and gk[2].label == "HAN", "keeper labels")
end

function T.risesWithOverall()
	for look = 1, 50 do
		local low = CardStats.of(player("MID", 50, look))
		local high = CardStats.of(player("MID", 56, look))
		for i = 1, 6 do
			assert(high[i].value >= low[i].value, "a stat fell as the player improved")
		end
	end
end

return T
