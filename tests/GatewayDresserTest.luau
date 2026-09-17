--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GatewayDresser = require(ServerScriptService.Server.GatewayDresser)
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local T = {}

function T.everyGatewayRoadGetsSignsOffTheRoadFacingTheRightWay()
	local gates = GatewayDresser.gateways()
	assert(#gates == #GatewayDresser.GATEWAYS, ("%d of %d gateways built"):format(#gates, #GatewayDresser.GATEWAYS))
	local centre = TownLayout.SQUARE.centre
	for _, g in gates do
		for _, cf in { g.welcome, g.route } do
			local p = cf.Position
			for _, road in TownLayout.ROADS do
				local reach = road.width / 2 + (if road.kind == "lane" then 0 else TownLayout.PAVEMENT_WIDTH) + 1
				assert(TownLayout.distanceToPolyline(p, road.points) > reach + 3, g.to .. " sign on " .. road.name)
			end
			for i = 1, #TownLayout.PLOTS do
				assert(not TownLayout.pointInPlot(p, i), g.to .. " sign inside plot " .. i)
			end
		end
		-- the welcome sign faces out of town, the route sign into it
		local out = (g.welcome.Position - centre) * Vector3.new(1, 0, 1)
		assert(g.welcome.LookVector:Dot(out.Unit) > 0.3, g.to .. " welcome sign faces out of town")
		assert(g.route.LookVector:Dot(out.Unit) < -0.3, g.to .. " route sign faces into town")
	end
end

return T
