--!strict
-- X320: the town's board schools (X59) were red-brick blocks with a name board
-- and nothing else - no railings, no gate, no playground, no bike shed, and no
-- zig-zags on the road outside. A British school shows all of that to the
-- street, and these stand in districts that otherwise got the imperfection
-- pass, so they read as unfinished from the pavement.
--
-- One pass over every `use == "school"` block in TownLayout:
--   railings + gate      on the side facing the nearest road
--   SCHOOL KEEP CLEAR    two white bars on the carriageway outside the gate
--   playground           tarmac behind the building, with painted markings
--   bike shed            against the playground's far edge
-- Roughly a dozen parts a school. Everything is probed before it is placed, so
-- a school hemmed in by houses simply gets less.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local SchoolDresser = {}

local RAIL_H = 4.2
local RAIL_COLOUR = Color3.fromRGB(28, 44, 36) -- municipal dark green
local TARMAC = Color3.fromRGB(78, 80, 84)
local PAINT = Color3.fromRGB(236, 236, 232)
local PAINT_YELLOW = Color3.fromRGB(236, 200, 60)
local GATE_GAP = 14
local PLAYGROUND_DEPTH = 46
local PROBE_Y0, PROBE_Y1 = 0.7, 5.0

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = material ~= nil
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function probeClear(at: Vector3, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.MaxParts = 4
	local centre = Vector3.new(at.X, (PROBE_Y0 + PROBE_Y1) / 2, at.Z)
	return #workspace:GetPartBoundsInBox(CFrame.new(centre), Vector3.new(size.X, PROBE_Y1 - PROBE_Y0, size.Z), params) == 0
end

export type School = { centre: Vector3, size: Vector3, toRoad: Vector3, roadDistance: number }

-- Pure: every school block with the direction of the nearest road from it.
function SchoolDresser.schools(): { School }
	local out: { School } = {}
	for _, district in TownLayout.DISTRICTS do
		for _, block in district.blocks do
			if block.use ~= "school" then
				continue
			end
			local centre = Vector3.new(block.centre.X, 0, block.centre.Z)
			local best, bestD = Vector3.new(0, 0, 1), math.huge
			for _, axis in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
				local half = if math.abs(axis.X) > 0.5 then block.size.X / 2 else block.size.Z / 2
				local edge = centre + axis * (half + 10)
				for _, road in TownLayout.ROADS do
					local d = TownLayout.distanceToPolyline(edge, road.points)
					if d < bestD then
						bestD, best = d, axis
					end
				end
			end
			table.insert(out, {
				centre = centre,
				size = Vector3.new(block.size.X, block.size.Y, block.size.Z),
				toRoad = best,
				roadDistance = bestD,
			})
		end
	end
	return out
end

local function dress(school: School, root: Instance): number
	local model = Instance.new("Model")
	model.Name = "School"
	model:SetAttribute("Decor", true)
	model.Parent = root
	local ignore: { Instance } = { model }

	local toRoad = school.toRoad
	local along = Vector3.new(-toRoad.Z, 0, toRoad.X)
	local halfOut = if math.abs(toRoad.X) > 0.5 then school.size.X / 2 else school.size.Z / 2
	local halfAlong = if math.abs(toRoad.X) > 0.5 then school.size.Z / 2 else school.size.X / 2
	local centre = school.centre
	local frontage = halfAlong + 6

	-- the railings along the street frontage, with a gap for the gate
	local railZ = centre + toRoad * (halfOut + 10)
	local function railRun(from: number, to: number, name: string)
		local length = to - from
		if length < 3 then
			return
		end
		local mid = railZ + along * ((from + to) / 2)
		local size = Vector3.new(
			if math.abs(along.X) > 0.5 then length else 0.5,
			RAIL_H,
			if math.abs(along.X) > 0.5 then 0.5 else length
		)
		if not probeClear(mid, Vector3.new(size.X + 1, 0, size.Z + 1), ignore) then
			return
		end
		local rail = part(model, name, size, CFrame.new(mid.X, RAIL_H / 2, mid.Z), RAIL_COLOUR, Enum.Material.Metal)
		rail.Transparency = 0.15 -- railings, not a wall
		-- a low wall the railings stand on, the way a board school has
		part(model, name .. "Wall", Vector3.new(size.X + 0.4, 1.2, size.Z + 0.4), CFrame.new(mid.X, 0.6, mid.Z), Color3.fromRGB(150, 76, 58), Enum.Material.Brick)
	end
	railRun(-frontage, -GATE_GAP / 2, "RailingA")
	railRun(GATE_GAP / 2, frontage, "RailingB")

	-- the gate: two piers and a pair of leaves, and the school's own sign
	for _, side in { -1, 1 } do
		local at = railZ + along * (side * GATE_GAP / 2)
		part(model, "GatePier", Vector3.new(2, 6, 2), CFrame.new(at.X, 3, at.Z), Color3.fromRGB(150, 76, 58), Enum.Material.Brick)
		local leafAt = railZ + along * (side * GATE_GAP / 4)
		local leaf = part(model, "GateLeaf", Vector3.new(
			if math.abs(along.X) > 0.5 then GATE_GAP / 2 - 1 else 0.3,
			4.4,
			if math.abs(along.X) > 0.5 then 0.3 else GATE_GAP / 2 - 1
		), CFrame.new(leafAt.X, 2.4, leafAt.Z), RAIL_COLOUR, Enum.Material.Metal)
		leaf.Transparency = 0.2
	end

	-- SCHOOL KEEP CLEAR on the carriageway, if the road is close enough to mark
	if school.roadDistance < 26 then
		local roadAt = centre + toRoad * (halfOut + 10 + school.roadDistance + 4)
		local markSize = Vector3.new(
			if math.abs(along.X) > 0.5 then 40 else 2.2,
			0.12,
			if math.abs(along.X) > 0.5 then 2.2 else 40
		)
		for _, side in { -1, 1 } do
			local at = roadAt + toRoad * (side * 5)
			part(model, "KeepClear", markSize, CFrame.new(at.X, 0.26, at.Z), PAINT, Enum.Material.SmoothPlastic).CanCollide = false
		end
		local words = part(model, "KeepClearWords", Vector3.new(
			if math.abs(along.X) > 0.5 then 30 else 7,
			0.1,
			if math.abs(along.X) > 0.5 then 7 else 30
		), CFrame.new(roadAt.X, 0.27, roadAt.Z), TARMAC, Enum.Material.SmoothPlastic)
		words.CanCollide = false
		words.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 16
		gui.LightInfluence = 0.4
		gui.MaxDistance = 260
		gui.Parent = words
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Rotation = if math.abs(along.X) > 0.5 then 0 else 90
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = PAINT
		label.Text = "SCHOOL KEEP CLEAR"
		label.Parent = gui
	end

	-- the playground behind the building: tarmac, a painted court and a
	-- hopscotch, plus a bike shed against its far edge
	local yardCentre = centre - toRoad * (halfOut + PLAYGROUND_DEPTH / 2 + 4)
	local yardSize = Vector3.new(
		if math.abs(toRoad.X) > 0.5 then PLAYGROUND_DEPTH else halfAlong * 1.6,
		0.3,
		if math.abs(toRoad.X) > 0.5 then halfAlong * 1.6 else PLAYGROUND_DEPTH
	)
	if probeClear(yardCentre, Vector3.new(yardSize.X - 6, 0, yardSize.Z - 6), ignore) then
		part(model, "Playground", yardSize, CFrame.new(yardCentre.X, 0.35, yardCentre.Z), TARMAC, Enum.Material.Asphalt)
		-- a court: four lines and a centre circle
		local courtX = math.min(yardSize.X, 30) - 6
		local courtZ = math.min(yardSize.Z, 30) - 6
		local function line(name: string, size: Vector3, offset: Vector3)
			local p = part(model, name, size, CFrame.new(yardCentre.X + offset.X, 0.52, yardCentre.Z + offset.Z), PAINT, Enum.Material.SmoothPlastic)
			p.CanCollide = false
		end
		line("CourtLine", Vector3.new(courtX, 0.05, 0.4), Vector3.new(0, 0, -courtZ / 2))
		line("CourtLine", Vector3.new(courtX, 0.05, 0.4), Vector3.new(0, 0, courtZ / 2))
		line("CourtLine", Vector3.new(0.4, 0.05, courtZ), Vector3.new(-courtX / 2, 0, 0))
		line("CourtLine", Vector3.new(0.4, 0.05, courtZ), Vector3.new(courtX / 2, 0, 0))
		local circle = part(model, "CourtCircle", Vector3.new(7, 0.06, 7), CFrame.new(yardCentre.X, 0.52, yardCentre.Z), PAINT, Enum.Material.SmoothPlastic)
		circle.Shape = Enum.PartType.Cylinder
		circle.CFrame = CFrame.new(yardCentre.X, 0.52, yardCentre.Z) * CFrame.Angles(0, 0, math.pi / 2)
		circle.CanCollide = false
		circle.Transparency = 0.25
		-- hopscotch in the corner, in yellow
		for i = 1, 4 do
			local p = part(model, "Hopscotch", Vector3.new(2.6, 0.05, 2.6), CFrame.new(
				yardCentre.X + yardSize.X / 2 - 8,
				0.52,
				yardCentre.Z - yardSize.Z / 2 + 6 + (i - 1) * 3
			), PAINT_YELLOW, Enum.Material.SmoothPlastic)
			p.CanCollide = false
		end
		-- bike shed on the far edge
		local shedAt = yardCentre - toRoad * (yardSize.Magnitude * 0 + PLAYGROUND_DEPTH / 2 - 5)
		if probeClear(shedAt, Vector3.new(14, 0, 8), ignore) then
			for _, side in { -1, 1 } do
				local postAt = shedAt + along * (side * 5)
				part(model, "ShedPost", Vector3.new(0.5, 6, 0.5), CFrame.new(postAt.X, 3, postAt.Z), RAIL_COLOUR, Enum.Material.Metal)
			end
			part(model, "ShedRoof", Vector3.new(
				if math.abs(along.X) > 0.5 then 14 else 6,
				0.4,
				if math.abs(along.X) > 0.5 then 6 else 14
			), CFrame.new(shedAt.X, 6.2, shedAt.Z), Color3.fromRGB(120, 124, 130), Enum.Material.Metal)
			part(model, "BikeRack", Vector3.new(
				if math.abs(along.X) > 0.5 then 10 else 0.4,
				1.4,
				if math.abs(along.X) > 0.5 then 0.4 else 10
			), CFrame.new(shedAt.X, 0.9, shedAt.Z), Color3.fromRGB(150, 152, 158), Enum.Material.Metal)
		end
	end

	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts
end

function SchoolDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "schools: no town"
	end
	local old = town:FindFirstChild("Schools")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Schools"
	root:SetAttribute("Decor", true)
	root.Parent = town
	local parts, count = 0, 0
	for _, school in SchoolDresser.schools() do
		parts += dress(school, root)
		count += 1
	end
	return ("schools: %d dressed, %d parts"):format(count, parts)
end

return SchoolDresser
