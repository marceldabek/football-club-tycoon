--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamGen = require(ReplicatedStorage.Shared.TeamGen)
local Pitch = require(ReplicatedStorage.Shared.Pitch)

local T = {}

function T.generatesSixteenNumberedPlayers()
	local squad = TeamGen.generate(1)
	assert(#squad == 16, "expected 16 players, got " .. #squad)
	for i, p in squad do
		assert(p.number == i, ("player %d has number %d"):format(i, p.number))
		assert(type(p.name) == "string" and #p.name > 3, "bad name for player " .. i)
	end
end

function T.startersFollowFormationRoles()
	local squad = TeamGen.generate(2)
	for i = 1, 11 do
		assert(squad[i].role == Pitch.ROLES[i], ("starter %d role %s, expected %s"):format(i, squad[i].role, Pitch.ROLES[i]))
	end
	for i = 12, 16 do
		assert(squad[i].role ~= "GK", "bench should be outfield players only")
	end
end

function T.namesUniqueWithinSquad()
	for seed = 1, 20 do
		local seen = {}
		for _, p in TeamGen.generate(seed) do
			assert(not seen[p.name], "duplicate name " .. p.name .. " in seed " .. seed)
			seen[p.name] = true
		end
	end
end

function T.deterministicBySeed()
	local a, b = TeamGen.generate(99), TeamGen.generate(99)
	for i = 1, 16 do
		assert(a[i].name == b[i].name, "seed 99 gave different squads")
	end
	assert(TeamGen.generate(1)[1].name ~= TeamGen.generate(2)[1].name, "different seeds gave the same keeper")
end

return T
