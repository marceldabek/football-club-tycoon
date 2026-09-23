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

-- Six lane slots and an exit in each block, the exit at the end nearer
-- halfway, the open lanes the ones facing the approach path.
function T.turnstileBlocksOpenLanesByTier()
	for _, name in { "NWTurnstiles", "SWTurnstiles" } do
		local g = GroundEnvelope.gate(name)
		local approach = GroundEnvelope.APPROACH_Z[name]
		for tier, lanes in Config.TurnstileLanes do
			local slots = GroundEnvelope.blockSlots(g, approach, lanes)
			assert(#slots == GroundEnvelope.LANE_SLOTS + 1, "six slots and an exit")
			local open, exit = 0, nil
			for i, s in slots do
				assert(s.z0 >= g.a0 and s.z1 <= g.a1 and s.z1 - s.z0 > 2, name .. " slot " .. i .. " inside the block, wide enough")
				for j = i + 1, #slots do
					assert(s.z1 <= slots[j].z0 + 1e-6 or slots[j].z1 <= s.z0 + 1e-6, "slots overlap")
				end
				if s.kind == "lane" then
					open += 1
				elseif s.kind == "exit" then
					exit = s
				end
			end
			assert(open == lanes, ("%s tier %d: %d lanes open, want %d"):format(name, tier, open, lanes))
			assert(exit and math.abs((exit.z0 + exit.z1) / 2) < math.abs(approach), name .. " exit at the halfway end")
		end
		-- at two lanes, both face the 8-wide approach path
		for _, s in GroundEnvelope.blockSlots(g, approach, 2) do
			if s.kind == "lane" then
				assert(math.abs((s.z0 + s.z1) / 2 - approach) < 4, name .. " first lanes face the path")
			end
		end
	end
end

-- Huts and toilets clear of each other, the wall, the blocks' thresholds, the
-- full-grown stands (16 rows to x +-170.6 / z +-228.6) and the masts.
function T.hutsStandClearOfWallStandsAndEachOther()
	local E = GroundEnvelope
	local rects: { Rect } = {}
	for _, h in E.HUTS do
		table.insert(rects, { name = h.name, x0 = h.x0, x1 = h.x1, z0 = h.z0, z1 = h.z1 })
	end
	for i in E.TOILETS do
		local h = E.toiletHut(i)
		table.insert(rects, { name = "Toilets" .. i, x0 = h.x0, x1 = h.x1, z0 = h.z0, z1 = h.z1 })
		assert(h.x1 - h.x0 == 18 and h.z1 - h.z0 == 12, "toilets are 18 x 12")
	end
	local runs, piers = E.wallPieces()
	local fixed: { Rect } = {}
	for _, r in runs do
		table.insert(fixed, r)
	end
	for _, p in piers do
		table.insert(fixed, p)
	end
	for _, name in { "NWTurnstiles", "SWTurnstiles" } do
		local g = E.gate(name)
		local x0 = E.X0 - E.BLOCK_D / 2 - E.BLOCK_APRON
		table.insert(fixed, { name = name, x0 = x0, x1 = E.X0 + E.BLOCK_D / 2 + E.BLOCK_APRON, z0 = g.a0, z1 = g.a1 })
	end
	table.insert(fixed, { name = "EastStandL4", x0 = 121, x1 = 170.6, z0 = -145.5, z1 = 145.5 })
	table.insert(fixed, { name = "WestStandL4", x0 = -170.6, x1 = -121, z0 = -155, z1 = 155 })
	for _, sz in { -1, 1 } do
		table.insert(fixed, { name = "EndStandL4", x0 = -98.5, x1 = 98.5, z0 = math.min(sz * 179, sz * 228.6), z1 = math.max(sz * 179, sz * 228.6) })
		for _, sx in { -1, 1 } do
			table.insert(fixed, { name = "Mast", x0 = sx * 140 - 3, x1 = sx * 140 + 3, z0 = sz * 200 - 3, z1 = sz * 200 + 3 })
		end
	end
	for i, a in rects do
		for j = i + 1, #rects do
			assert(not overlaps(a, rects[j]), describe(a) .. " overlaps " .. describe(rects[j]))
		end
		for _, f in fixed do
			assert(not overlaps(a, f), describe(a) .. " overlaps " .. describe(f))
		end
	end
end

function T.groundTierFollowsTheBestStand()
	assert(Config.groundTier({ East = 1 }) == 1, "spawn is tier 1")
	assert(Config.groundTier({ East = 1, West = 2 }) == 2, "a main stand makes tier 2")
	assert(Config.groundTier({ East = 4, West = 0 }) == 3, "a covered grandstand is map tier 3")
	assert(Config.groundTier({}) == 1, "never below 1")
	assert(Config.TurnstileLanes[1] == 2 and Config.TurnstileLanes[4] == 6, "2..6 lanes")
end

return T
