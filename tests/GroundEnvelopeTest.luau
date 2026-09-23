--!strict
-- #15: the ground plan's fixed envelope (docs/superpowers/specs/2026-09-22-ground-plan-design.md s2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Config = require(ReplicatedStorage.Shared.Config)
local GroundEnvelope = require(ServerScriptService.Server.GroundEnvelope)

local T = {}

type Rect = { name: string, x0: number, x1: number, z0: number, z1: number }

local function overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 - 1e-6 and b.x0 < a.x1 - 1e-6 and a.z0 < b.z1 - 1e-6 and b.z0 < a.z1 - 1e-6
end

local function describe(r: Rect): string
	return ("%s x %g..%g z %g..%g"):format(r.name, r.x0, r.x1, r.z0, r.z1)
end

function T.envelopeMatchesTheSpec()
	assert(GroundEnvelope.X0 == -201 and GroundEnvelope.X1 == 201, "x +-201")
	assert(GroundEnvelope.Z0 == -259 and GroundEnvelope.Z1 == 259, "z +-259")
	local want = {
		MainGate = { "W", -16, 16 },
		NWTurnstiles = { "W", -200, -175 },
		SWTurnstiles = { "W", 175, 200 },
		NorthExit = { "N", -20, 20 },
		EastExit = { "E", -20, 20 },
		ServiceGate = { "S", 176, 192 },
	}
	local seen = 0
	for _, g in GroundEnvelope.GATES do
		local w = want[g.name]
		assert(w, "unexpected gate " .. g.name)
		assert(g.side == w[1] and g.a0 == w[2] and g.a1 == w[3], "gate " .. g.name .. " off the spec")
		seen += 1
	end
	assert(seen == 6, "six ways through the wall")
end

-- The wall is one closed loop apart from the gates: along every side the runs,
-- piers and openings tile the whole length with no gaps and no overlaps.
function T.wallClosesEverythingButTheGates()
	local runs, piers = GroundEnvelope.wallPieces()
	local all: { Rect } = {}
	for _, r in runs do
		table.insert(all, r)
	end
	for _, p in piers do
		table.insert(all, p)
	end
	for i = 1, #all do
		for j = i + 1, #all do
			assert(not overlaps(all[i], all[j]), describe(all[i]) .. " overlaps " .. describe(all[j]))
		end
	end
	local E = GroundEnvelope
	for _, side in { "N", "S", "W", "E" } do
		local covered = 0
		for _, r in runs do
			if r.name == "Wall" .. side then
				covered += if side == "N" or side == "S" then r.x1 - r.x0 else r.z1 - r.z0
			end
		end
		for _, g in E.GATES do
			if g.side == side then
				covered += (g.a1 - g.a0) + (if g.kind == "block" then 0 else 2 * E.PIER_W)
			end
		end
		local full = if side == "N" or side == "S" then (E.X1 - E.X0) + E.WALL_T else (E.Z1 - E.Z0) - E.WALL_T
		assert(math.abs(covered - full) < 1e-6, ("side %s covers %g of %g"):format(side, covered, full))
	end
	-- and no run crosses an opening
	for _, g in E.GATES do
		for _, r in runs do
			local a0, a1 = if g.side == "N" or g.side == "S" then r.x0 else r.z0, if g.side == "N" or g.side == "S" then r.x1 else r.z1
			if r.name == "Wall" .. g.side then
				assert(a1 <= g.a0 + 1e-6 or a0 >= g.a1 - 1e-6, describe(r) .. " runs across " .. g.name)
			end
		end
	end
end

function T.keepOutCoversTheWalledGround()
	local ground
	for _, r in GroundEnvelope.keepOut() do
		if r.name == "Ground" then
			ground = r
		end
	end
	assert(ground and ground.solid, "a solid Ground rect")
	assert(ground.x0 < -201 and ground.x1 > 201 and ground.z0 < -259 and ground.z1 > 259, "reaches past the wall")
end

function T.groundTierFollowsTheBestStand()
	assert(Config.groundTier({ East = 1 }) == 1, "spawn is tier 1")
	assert(Config.groundTier({ East = 1, West = 2 }) == 2, "a main stand makes tier 2")
	assert(Config.groundTier({ East = 4, West = 0 }) == 3, "a covered grandstand is map tier 3")
	assert(Config.groundTier({}) == 1, "never below 1")
	assert(Config.TurnstileLanes[1] == 2 and Config.TurnstileLanes[4] == 6, "2..6 lanes")
end

return T
