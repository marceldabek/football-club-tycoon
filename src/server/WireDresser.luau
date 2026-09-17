--!strict
-- Telegraph poles and overhead phone wires on a few residential streets
-- (backlog X100, the "cables" in WORLD_ROADMAP E10). Runs after the street
-- dressers so it can step round what they placed.
--
-- A pole is a tall wooden post in the kerb side of one pavement with a short
-- cross arm across the street direction; two wires run from arm end to arm end
-- between neighbouring poles, each as two straight halves that sag to a low
-- point mid-span. Poles skip junction mouths, bus stops and lamp posts, and a
-- spot is dropped at build time if anything tall already stands there (tree,
-- sign, shelter). A wire is only strung between poles no more than MAX_SPAN
-- apart, so a dropped pole leaves a gap instead of a long wire.
--
-- Part budget: pole 2, span 4 (two wires x two halves). All of it is decor
-- (Quality hides TelegraphPole / PoleArm / Wire on Low).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local StreetDresser = require(script.Parent.StreetDresser)

local WireDresser = {}

-- TEMP: which streets get poles, on which side (+1 = right of the polyline).
WireDresser.STREETS = {
	{ name = "Weaver Street", side = 1 },
	{ name = "Westdale Avenue", side = -1 },
	{ name = "Westdale Crescent", side = 1 },
	{ name = "Hayfield Close", side = -1 },
}
WireDresser.SPACING = 48
WireDresser.MAX_SPAN = 60
WireDresser.KERB_INSET = 0.7 -- pole centre from the kerb edge (lamps stand at 1.4, trees 2.2)
WireDresser.POLE_H = 18
WireDresser.WIRE_Y = 17.2
WireDresser.SAG = 0.9
WireDresser.ARM_HALF = 1.1 -- wires hang this far either side of the pole
WireDresser.LAMP_CLEAR = 5
WireDresser.JUNCTION_CLEAR = 8
WireDresser.BUS_STOP_CLEAR = 12

local PAVEMENT_WIDTH = TownLayout.PAVEMENT_WIDTH
local POLE_BROWN = Color3.fromRGB(96, 74, 52)
local WIRE_BLACK = Color3.fromRGB(26, 26, 28)

export type PoleSpot = { position: Vector3, direction: Vector3 }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function nearOtherRoad(p: Vector3, road: TownLayout.Road): boolean
	for _, other in TownLayout.ROADS do
		if other.name ~= road.name then
			local reach = other.width / 2 + (if other.kind == "lane" then 0 else PAVEMENT_WIDTH)
			if TownLayout.distanceToPolyline(p, other.points) < reach + WireDresser.JUNCTION_CLEAR then
				return true
			end
		end
	end
	for _, rb in TownLayout.ROUNDABOUTS do
		if (flat(p) - flat(rb.centre)).Magnitude < rb.radius + PAVEMENT_WIDTH + WireDresser.JUNCTION_CLEAR then
			return true
		end
	end
	return false
end

-- Pure: pole spots along one side of a road, clear of junction mouths, bus
-- stops and the given lamp positions.
function WireDresser.poleSpots(road: TownLayout.Road, side: number, lamps: { Vector3 }): { PoleSpot }
	local out: { PoleSpot } = {}
	local lateral = side * (road.width / 2 + WireDresser.KERB_INSET)
	for _, st in StreetDresser.stations(road.points, WireDresser.SPACING) do
		local right = Vector3.new(-st.direction.Z, 0, st.direction.X)
		local p = flat(st.position + right * lateral)
		local clash = nearOtherRoad(p, road)
		for _, stop in TownLayout.BUS_STOPS do
			if clash then
				break
			end
			clash = (flat(stop.position) - p).Magnitude < WireDresser.BUS_STOP_CLEAR
		end
		for _, lamp in lamps do
			if clash then
				break
			end
			clash = (flat(lamp) - p).Magnitude < WireDresser.LAMP_CLEAR
		end
		if not clash then
			table.insert(out, { position = p, direction = st.direction })
		end
	end
	return out
end

-- Pure: the two straight halves of a sagging wire from a to b, as
-- (centre, length) pairs; the halves meet SAG below the straight line.
function WireDresser.wireHalves(a: Vector3, b: Vector3, sag: number): { { CFrame | number } }
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	local out = {}
	for _, pair in { { a, mid }, { mid, b } } do
		local p, q = pair[1], pair[2]
		table.insert(out, { CFrame.lookAt((p + q) / 2, q), (q - p).Magnitude })
	end
	return out
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- True when something taller than a kerb already stands in the pole's footprint.
local function occupied(p: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local box = CFrame.new(p.X, 1 + WireDresser.POLE_H / 2, p.Z)
	return #workspace:GetPartBoundsInBox(box, Vector3.new(1.4, WireDresser.POLE_H - 1, 1.4), params) > 0
end

function WireDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "wires: no town"
	end
	local old = town:FindFirstChild("Wires")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Wires"
	root.Parent = town
	local poles, spans, parts = 0, 0, 0
	for _, spec in WireDresser.STREETS do
		local road: TownLayout.Road? = nil
		for _, r in TownLayout.ROADS do
			if r.name == spec.name then
				road = r
			end
		end
		if not road then
			continue
		end
		local m = Instance.new("Model")
		m.Name = spec.name
		m.Parent = root
		local placed: { PoleSpot } = {}
		for _, spot in WireDresser.poleSpots(road, spec.side, StreetDresser.lampPositions(road)) do
			if occupied(spot.position, { root }) then
				continue
			end
			local base = CFrame.lookAt(spot.position, spot.position + spot.direction)
			part(m, "TelegraphPole", Vector3.new(0.55, WireDresser.POLE_H, 0.55), base * CFrame.new(0, WireDresser.POLE_H / 2, 0), POLE_BROWN, Enum.Material.Wood)
			part(m, "PoleArm", Vector3.new(WireDresser.ARM_HALF * 2 + 0.4, 0.22, 0.22), base * CFrame.new(0, WireDresser.WIRE_Y - 0.14, 0), POLE_BROWN, Enum.Material.Wood)
			poles += 1
			parts += 2
			local prev = placed[#placed]
			if prev and (prev.position - spot.position).Magnitude <= WireDresser.MAX_SPAN then
				local prevBase = CFrame.lookAt(prev.position, prev.position + prev.direction)
				for _, x in { -WireDresser.ARM_HALF, WireDresser.ARM_HALF } do
					local a = prevBase * Vector3.new(x, WireDresser.WIRE_Y, 0)
					local b = base * Vector3.new(x, WireDresser.WIRE_Y, 0)
					for _, half in WireDresser.wireHalves(a, b, WireDresser.SAG) do
						part(m, "Wire", Vector3.new(0.06, 0.06, half[2] :: number), half[1] :: CFrame, WIRE_BLACK, Enum.Material.SmoothPlastic)
						parts += 1
					end
				end
				spans += 1
			end
			table.insert(placed, spot)
		end
	end
	return ("wires: %d poles, %d spans, %d parts"):format(poles, spans, parts)
end

return WireDresser
