--!strict
-- Pure layout for the ground's neighbourhood growing with its club (backlog
-- X105; WORLD_ROADMAP H1 "club influence tiers"; CLAUDE.md s27: "The
-- neighbourhood around each ground changes for everyone as that club grows").
-- GroundInfluence.client.luau builds these for every claimed plot on every
-- player's screen, from the club folder's Tier.
--
-- All positions are pitch-local (plot frame: pitch centre at the origin, the
-- entrance wall at x = -380, pedestrian gate z -20..-4), matching PlotGrounds.
--   tier >= BANNER_TIER     club banners on the two lamp posts along the
--                           footpath in from the pedestrian gate
--   tier >= HOARDING_TIER   a big club-name hoarding outside the entrance wall,
--                           north of the pedestrian gate, facing the town
--   tier >= FLAG_TIER       flagpoles with club flags on both gate piers
-- TEMP thresholds (Marcel: question 13).

local GroundInfluence = {}

GroundInfluence.BANNER_TIER = 2
GroundInfluence.HOARDING_TIER = 3
GroundInfluence.FLAG_TIER = 4

-- PlotGrounds.pathsideSpots() lamps (GroundInfluenceTest checks they match).
GroundInfluence.PATH_LAMPS = { Vector3.new(-338, 0, -18), Vector3.new(-290, 0, -18) }
GroundInfluence.LAMP_HEIGHT = 12

-- The hoarding stands on two legs just outside the entrance wall's outer face.
GroundInfluence.HOARDING = {
	x = -381.5, -- board centre line (the wall's outer face is x = -380)
	z0 = -70,
	z1 = -34,
	bottom = 1.2,
	top = 8.2,
}

-- Pedestrian gate pier centres (PlotGrounds: piers -380..-378 x, z -22..-20 and -4..-2).
GroundInfluence.GATE_PIERS = { Vector3.new(-379, 4, -21), Vector3.new(-379, 4, -3) }
GroundInfluence.FLAGPOLE_HEIGHT = 12

export type Features = { banners: boolean, hoarding: boolean, flags: boolean }

function GroundInfluence.features(tier: any): Features
	local t = if type(tier) == "number" then tier else 1
	return {
		banners = t >= GroundInfluence.BANNER_TIER,
		hoarding = t >= GroundInfluence.HOARDING_TIER,
		flags = t >= GroundInfluence.FLAG_TIER,
	}
end

return GroundInfluence
