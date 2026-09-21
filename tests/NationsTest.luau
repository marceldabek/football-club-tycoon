--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nations = require(ReplicatedStorage.Shared.Nations)

local T = {}

function T.everyNationIsComplete()
	assert(#Nations.LIST >= 12, "too few nations to feel like a world")
	local seen = {}
	for _, n in Nations.LIST do
		assert(#n.code == 3 and n.code == n.code:upper(), "bad code " .. n.code)
		assert(not seen[n.code], "duplicate code " .. n.code)
		seen[n.code] = true
		assert(#n.name > 2, n.code .. " has no name")
		assert(#n.first >= 10 and #n.last >= 10, n.code .. " needs at least 10 first and 10 last names")
		assert(n.weight > 0, n.code .. " can never be picked")
		assert(#n.flag.colors >= 1, n.code .. " has no flag colours")
		assert(Nations.get(n.code) == n, "get() does not find " .. n.code)
	end
end

function T.unknownCodeFallsBackToHome()
	assert(Nations.get("ZZZ").code == Nations.HOME, "an unknown code should read as the home nation")
	assert(Nations.get(nil).code == Nations.HOME, "a missing code should read as the home nation")
end

local function foreignShare(reach: number): number
	local rng = Random.new(7)
	local foreign = 0
	for _ = 1, 4000 do
		if not Nations.pick(rng, reach).home then
			foreign += 1
		end
	end
	return foreign / 4000
end

function T.localReachIsMostlyHomeGrown()
	local share = foreignShare(0)
	assert(share > 0.03 and share < 0.2, ("reach 0 found %.0f%% abroad"):format(share * 100))
end

function T.widerReachFindsMoreAbroad()
	local near, mid, far = foreignShare(0), foreignShare(0.5), foreignShare(1)
	assert(near < mid and mid < far, "reach does not widen the net")
	assert(far > 0.45, ("a continental network found only %.0f%% abroad"):format(far * 100))
end

function T.pickIsDeterministic()
	local a, b = Random.new(11), Random.new(11)
	for _ = 1, 50 do
		assert(Nations.pick(a, 0.5).code == Nations.pick(b, 0.5).code, "same seed, different nation")
	end
end

function T.personIsNamedFromTheirNation()
	local rng = Random.new(5)
	for _, n in Nations.LIST do
		local name = Nations.nameFor(rng, n)
		local first, last = name:match("^(%S+) (.+)$")
		assert(first and last, "not a first and last name: " .. name)
		assert(table.find(n.first, first), first .. " is not a " .. n.name .. " first name")
		assert(table.find(n.last, last), last .. " is not a " .. n.name .. " surname")
	end
end

-- saves from before nationality: stable, and spread like a local club
function T.backfillIsStableAndMostlyHome()
	assert(Nations.codeFor(3, "Alfie Abbott") == Nations.codeFor(3, "Alfie Abbott"), "backfill moved")
	local home = 0
	for id = 1, 400 do
		local code = Nations.codeFor(id, "Player " .. id)
		assert(Nations.get(code).code == code, "backfill gave an unknown code")
		if Nations.get(code).home then
			home += 1
		end
	end
	assert(home > 300, ("only %d of 400 old players read as home-grown"):format(home))
end

return T
