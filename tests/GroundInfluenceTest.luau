--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroundInfluence = require(ReplicatedStorage.Shared.GroundInfluence)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local PlotGrounds = require(ServerScriptService.Server.PlotGrounds)

local T = {}

function T.featuresUnlockInTierOrder()
	local seen = { banners = false, hoarding = false, flags = false }
	for tier = 1, 6 do
		local f = GroundInfluence.features(tier)
		for key, was in seen do
			assert(not was or (f :: any)[key], key .. " switched off again at tier " .. tier)
			seen[key] = (f :: any)[key]
		end
	end
	local base = GroundInfluence.features(nil)
	assert(not base.banners and not base.hoarding and not base.flags, "a club with no tier yet shows nothing")
	assert(seen.banners and seen.hoarding and seen.flags, "everything is on by tier 6")
end

function T.bannerLampsAreThePathsideLamps()
	local _, lamps = PlotGrounds.pathsideSpots()
	assert(#lamps == #GroundInfluence.PATH_LAMPS, ("%d lamps, influence knows %d"):format(#lamps, #GroundInfluence.PATH_LAMPS))
	for i, p in lamps do
		assert((p - GroundInfluence.PATH_LAMPS[i]).Magnitude < 1e-3, "lamp " .. i .. " moved: " .. tostring(p))
	end
end

function T.hoardingStandsOutsideTheWallClearOfRoadsAndStopsAtEveryPlot()
	local h = GroundInfluence.HOARDING
	assert(h.x < -380 - 0.5, "outside the entrance wall")
	for i = 1, #TownLayout.PLOTS do
		local cf = TownLayout.plotCFrame(i)
		for _, z in { h.z0, (h.z0 + h.z1) / 2, h.z1 } do
			local p = cf * Vector3.new(h.x, 0, z)
			for _, road in TownLayout.ROADS do
				local reach = road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH) + 1
				assert(TownLayout.distanceToPolyline(p, road.points) > reach, ("plot %d: hoarding on %s"):format(i, road.name))
			end
			for _, stop in TownLayout.BUS_STOPS do
				local flat = Vector3.new(stop.position.X, p.Y, stop.position.Z)
				assert((flat - p).Magnitude > 12, ("plot %d: hoarding at the %s bus stop"):format(i, stop.name))
			end
		end
	end
end

return T
