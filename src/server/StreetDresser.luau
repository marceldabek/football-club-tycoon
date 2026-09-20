--!strict
-- v1 street maths, kept for the dressers that still read it. The BUILDING half
-- (kit / light terrace rows, lamps, bins, parked cars) was retired by v3 Lane I:
-- HouseAssembler builds the rows and StreetFurniture the props. Note that
-- lampPositions() now describes where v1 lamps WOULD stand; callers only use it
-- to keep trees and wires clear, so it is harmless until stage 2 re-points them
-- at FurniturePlan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local StreetDresser = {}

-- TEMP: districts and streets that get the heavy kit dressing (showpiece only;
-- kit terraces are ~166 parts a row).
local DRESSED = {
	-- xRange: only this stretch gets the kit (the streets were extended to x 900)
	["Mill Street Terraces"] = { streets = { "Mill Street", "Weaver Street" }, xRange = { 0, 400 } },
} :: { [string]: { streets: { string }, xRange: { number }? } }
StreetDresser.DRESSED = DRESSED -- read by TerraceStreetDresser (X11)

-- Every other district gets the low-part TerraceBuilder row and lamp; the
-- kit district's rows away from its kit streets do too. The densified layout
-- has ~300 terraced rows, far too many for kit rows.
local KIT_ROW_RADIUS = 30 -- a kit district's row gets the kit only this close to a kit street
local LIGHT_LAMP_SPACING = 80 -- light streets are many; the kit streets keep 50

local ROW_LENGTH = 128 -- kit row length along its local Z
local PAVEMENT_TOP = 0.45 -- TownBuilder.Y.PAVEMENT
local LAMP_SPACING = 50 -- staggered: each side gets every other one (the kit lamp is 36 parts)
local LAMP_INSET = 1.4 -- from the kerb edge onto the pavement

-- Pure: yaw (radians) and scale for a kit row filling a layout block. The row
-- runs along its local Z, so a block that is long in X turns 90 degrees.
function StreetDresser.rowPlacement(block: TownLayout.Box): (CFrame, number)
	local longX = block.size.X >= block.size.Z
	local length = if longX then block.size.X else block.size.Z
	local yaw = math.rad(block.yaw) + (if longX then math.pi / 2 else 0)
	local scale = math.clamp(length / ROW_LENGTH, 0.7, 1.2)
	return CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, yaw, 0), scale
end

-- Pure: points along a polyline every `spacing`, starting half a gap in, with
-- the unit direction of the segment each point is on.
function StreetDresser.stations(points: { Vector3 }, spacing: number): { { position: Vector3, direction: Vector3 } }
	local out = {}
	local carry = spacing / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length < 1e-6 then
			continue
		end
		local dir = flat / length
		local s = carry
		while s <= length do
			table.insert(out, { position = Vector3.new(a.X, 0, a.Z) + dir * s, direction = dir })
			s += spacing
		end
		carry = s - length
	end
	return out
end

-- Pure: the point halfway along a polyline (by length, in XZ).
function StreetDresser.polylineMidpoint(points: { Vector3 }): Vector3
	local total = 0
	for i = 1, #points - 1 do
		total += Vector3.new(points[i + 1].X - points[i].X, 0, points[i + 1].Z - points[i].Z).Magnitude
	end
	local remaining = total / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length > 0 and remaining <= length then
			return Vector3.new(a.X, 0, a.Z) + flat * (remaining / length)
		end
		remaining -= length
	end
	local first = points[1]
	return Vector3.new(first.X, 0, first.Z)
end

-- Pure: XZ distance from p to a layout block's footprint (0 inside it).
function StreetDresser.distanceToBlock(p: Vector3, block: TownLayout.Box): number
	local cf = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	local q = cf:PointToObjectSpace(Vector3.new(p.X, 0, p.Z))
	local dx = math.max(0, math.abs(q.X) - block.size.X / 2)
	local dz = math.max(0, math.abs(q.Z) - block.size.Z / 2)
	return math.sqrt(dx * dx + dz * dz)
end

-- Pure: like rowPlacement (row along the block's long side = local Z), but
-- turned 180 degrees when needed so the front (local -X) faces the nearest road.
function StreetDresser.lightRowPlacement(block: TownLayout.Box): CFrame
	local cf = StreetDresser.rowPlacement(block)
	local depth = math.min(block.size.X, block.size.Z)
	local front = cf:VectorToWorldSpace(Vector3.new(-1, 0, 0))
	local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
	local function nearestRoad(p: Vector3): number
		local best = math.huge
		for _, road in TownLayout.ROADS do
			best = math.min(best, TownLayout.distanceToPolyline(p, road.points))
		end
		return best
	end
	if nearestRoad(centre - front * depth) < nearestRoad(centre + front * depth) then
		cf *= CFrame.Angles(0, math.pi, 0)
	end
	return cf
end

local function roadNamed(name: string): TownLayout.Road?
	for _, road in TownLayout.ROADS do
		if road.name == name then
			return road
		end
	end
	return nil
end

local function lampSpot(road: TownLayout.Road, i: number, st: { position: Vector3, direction: Vector3 }): (CFrame, Vector3, Vector3, number)
	local side = if i % 2 == 0 then 1 else -1
	local right = Vector3.new(-st.direction.Z, 0, st.direction.X)
	local lateral = side * (road.width / 2 + LAMP_INSET)
	local pos = st.position + right * lateral + Vector3.new(0, PAVEMENT_TOP, 0)
	return CFrame.lookAt(pos, pos - right * side), pos, right, side
end

-- True when a block fronts one of the named streets (kit showpiece rows).
local function nearStreets(block: TownLayout.Box, streets: { string }): boolean
	for _, name in streets do
		local road = roadNamed(name)
		if road then
			local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
			local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH + math.min(block.size.X, block.size.Z) / 2 + KIT_ROW_RADIUS
			if TownLayout.distanceToPolyline(centre, road.points) <= reach then
				return true
			end
		end
	end
	return false
end

local function inRange(x: number, range: { number }?): boolean
	return range == nil or (x >= range[1] and x <= range[2])
end

-- Pure: true when StreetDresser gives this district's "terraced row" block the
-- kit row (inside a DRESSED district's xRange and fronting one of its streets).
function StreetDresser.isKitRow(districtName: string, block: TownLayout.Box): boolean
	local spec = DRESSED[districtName]
	return spec ~= nil and block.use == "terraced row" and inRange(block.centre.X, spec.xRange) and nearStreets(block, spec.streets)
end

-- Pure: XZ positions (Y = 0) of every lamp post StreetDresser can put on this
-- street: the kit streets' staggered 50-stud stations (only every other one
-- beyond the showpiece stretch), otherwise the light 80-stud stations. A light
-- street that ends up unlit just gets a few spots avoided for nothing.
function StreetDresser.lampPositions(road: TownLayout.Road): { Vector3 }
	local out: { Vector3 } = {}
	local xRange: { number }? = nil
	local kit = false
	for _, spec in DRESSED do
		if table.find(spec.streets, road.name) then
			kit, xRange = true, spec.xRange
		end
	end
	for i, st in StreetDresser.stations(road.points, if kit then LAMP_SPACING else LIGHT_LAMP_SPACING) do
		if kit and not inRange(st.position.X, xRange) and i % 2 ~= 0 then
			continue
		end
		local _, pos = lampSpot(road, i, st)
		table.insert(out, Vector3.new(pos.X, 0, pos.Z))
	end
	return out
end

-- v3 (Lane I): StreetDresser.build is retired. Terrace rows are HouseAssembler's,
-- lamps, bins and parked cars are StreetFurniture's. What is left above is the
-- pure street maths other dressers still read (stations, lampPositions, DRESSED,
-- row placements); stage 2 re-points those at TownFrontage / FurniturePlan.

return StreetDresser
