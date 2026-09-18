--!strict
-- X341: most of Rivermere's streets were anonymous. Name plates were built
-- only for the terraced streets TerraceStreetDresser dresses, and one name wall
-- per estate entrance, so roughly forty of the fifty-one named roads in
-- TownLayout - Ring Road, High Street, Station Road, Church Lane, Bridge
-- Street, every close in Northfields - had no sign at all. None of the ten
-- named roundabouts had a fingerpost either, so nothing at a junction told you
-- which way the town centre, the station or the grounds were.
--
-- This runs after the street and estate dressers and fills in what they left:
-- it reads the plates already standing in the world, so a street that has one
-- never gets a second, and the two passes cannot drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TerraceStreetDresser = require(script.Parent.TerraceStreetDresser)
local SquareDresser = require(script.Parent.SquareDresser)

local SignDresser = {}

-- TEMP: about 1% of the town. 150 of it is plates (50 roads at 3 parts), and
-- the ten roundabout fingerposts take the 80 that leaves. SignDresserTest
-- fails if the two ever stop adding up - which is how 220 was caught.
SignDresser.PART_BUDGET = 240
-- the plates take what they need out of that and the fingerposts keep the
-- rest, so a town with fifty unsigned roads still gets its junction signs
SignDresser.PLATE_BUDGET = 150
SignDresser.VERGE = 7 -- a fingerpost stands this far beyond a roundabout's pavement
SignDresser.PLATES_PER_ROAD = 1 -- one end is enough; the terrace streets sign both
SignDresser.MIN_BLADE_DISTANCE = 220 -- pointing at something 50 studs away is noise

-- The bus stop names a fingerpost can send you to, nearest-plot last so a
-- driver reads "Town Centre / Station / Plot 2" down the post.
SignDresser.DESTINATIONS = { "Town Centre", "Station" }

export type Plate = { road: string, frame: CFrame }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Pure: the named roads with no plate yet. `signed` is the set of road names
-- already carrying one (from the world, or a test's own table).
function SignDresser.unsigned(signed: { [string]: boolean }): { TownLayout.Road }
	local out: { TownLayout.Road } = {}
	for _, road in TownLayout.ROADS do
		if signed[road.name] or #road.points < 2 then
			continue
		end
		table.insert(out, road)
	end
	return out
end

-- Pure: where a road's plate goes. The junction spots the terrace streets use
-- come first (a plate belongs on a corner); a road that meets nothing - the
-- three roads out of town - takes one near its town end instead, set back on
-- the pavement and facing the carriageway.
function SignDresser.plateSpots(road: TownLayout.Road, roads: { TownLayout.Road }): { CFrame }
	local spots = TerraceStreetDresser.signSpots(road, roads)
	if #spots > 0 then
		return spots
	end
	local a, b = road.points[1], road.points[2]
	local along = flat(b - a)
	if along.Magnitude < 1e-3 then
		return {}
	end
	local dir = along.Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local lateral = road.width / 2 + TownLayout.PAVEMENT_WIDTH - TerraceStreetDresser.SIGN_BACK
	local at = flat(a) + dir * math.min(40, along.Magnitude / 2) + right * lateral
	return { CFrame.lookAt(at, at - right) }
end

-- Pure: where a fingerpost stands at a roundabout - on the verge outside the
-- island, in whichever direction is furthest from every carriageway, so it
-- never ends up in a road mouth. Returns nil if the roundabout is so busy with
-- arms that there is no gap wide enough (or the spot lands in the river).
function SignDresser.fingerSpot(roundabout: TownLayout.Roundabout, roads: { TownLayout.Road }): Vector3?
	local reach = roundabout.radius + TownLayout.PAVEMENT_WIDTH + SignDresser.VERGE
	local best: Vector3? = nil
	local bestClear = 0
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local p = roundabout.centre + Vector3.new(math.cos(a) * reach, 0, math.sin(a) * reach)
		local clear = math.huge
		for _, road in roads do
			local d = TownLayout.distanceToPolyline(p, road.points) - road.width / 2 - TownLayout.PAVEMENT_WIDTH
			clear = math.min(clear, d)
		end
		local riverGap = TownLayout.distanceToPolyline(p, TownLayout.RIVER.points) - TownLayout.RIVER.width / 2
		if riverGap < 20 then
			continue
		end
		if clear > bestClear then
			best, bestClear = p, clear
		end
	end
	return if bestClear >= 3 then best else nil
end

-- Pure: what a roundabout's blades point at - the town centre, the station and
-- the nearest club ground, dropping anything already on the doorstep so a post
-- outside the station does not point at the station.
export type Blade = { name: string, position: Vector3 }
function SignDresser.blades(roundabout: TownLayout.Roundabout): { Blade }
	local out: { Blade } = {}
	for _, name in SignDresser.DESTINATIONS do
		local at = SquareDresser.destination(name)
		if at and (flat(at - roundabout.centre)).Magnitude >= SignDresser.MIN_BLADE_DISTANCE then
			table.insert(out, { name = name, position = at :: Vector3 })
		end
	end
	local nearest: Blade? = nil
	local nearestGap = math.huge
	for _, plot in TownLayout.PLOTS do
		local gap = (flat(plot.busStop - roundabout.centre)).Magnitude
		if gap < nearestGap then
			nearest = { name = plot.name .. " Ground", position = plot.busStop }
			nearestGap = gap
		end
	end
	if nearest then
		table.insert(out, nearest :: Blade)
	end
	return out
end

-- The road names already carrying a plate or a name wall, read from the world.
local function alreadySigned(town: Instance): { [string]: boolean }
	local signed: { [string]: boolean } = {}
	for _, d in town:GetDescendants() do
		if d:IsA("Model") and (d.Name == "StreetSign" or d.Name == "NameWall") then
			local road = d:GetAttribute("Road")
			if type(road) == "string" then
				signed[road] = true
			end
		end
	end
	return signed
end

function SignDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "signs: no town"
	end
	local old = town:FindFirstChild("Signs")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Signs"
	root.Parent = town

	local signed = alreadySigned(town)
	local parts = 0
	local plated, skipped = 0, 0
	for _, road in SignDresser.unsigned(signed) do
		local spots = SignDresser.plateSpots(road, TownLayout.ROADS)
		if #spots == 0 then
			skipped += 1
			continue
		end
		local made = 0
		for _, cf in spots do
			if made >= SignDresser.PLATES_PER_ROAD or parts + 3 > SignDresser.PLATE_BUDGET then
				break
			end
			TerraceStreetDresser.streetSign(root, cf, road.name)
			parts += 3
			made += 1
		end
		if made > 0 then
			plated += 1
		else
			skipped += 1
		end
	end

	local posts = 0
	for _, roundabout in TownLayout.ROUNDABOUTS do
		local blades = SignDresser.blades(roundabout)
		local cost = 2 + #blades * 2
		if #blades == 0 or parts + cost > SignDresser.PART_BUDGET then
			continue
		end
		local at = SignDresser.fingerSpot(roundabout, TownLayout.ROADS)
		if not at then
			continue
		end
		SquareDresser.fingerPost(root, at, 0, blades :: { SquareDresser.FingerDestination })
		parts += cost
		posts += 1
	end

	return ("signs: %d street plates (%d roads with no corner), %d roundabout fingerposts, %d parts"):format(
		plated, skipped, posts, parts)
end

return SignDresser
