--!strict
-- The Community Sports Centre (RivermereAImap.png): TownBuilder leaves its
-- "grass pitch" / "3G pitch" blocks as flat green slabs and its "sports hall"
-- as a white box. This dresser (runs after TownBuilder) turns them into:
--   pitches   the greybox slab recoloured (grass or darker 3G), white
--             markings (touchlines, goal lines, halfway, penalty boxes, an
--             8-chord centre circle) and two goals: ~25 parts a pitch
--   3G        plus a green ball-stop fence and four floodlight masts: +12
--   hall      metal-clad body and roof in place of the greybox, a navy fascia
--             with the centre's name and a glazed entrance on the road side
-- Heights: pitch slab top 0.30; lines 0.30..0.36; circle chords alternate
-- 0.37 / 0.39 tall so no two tops share a plane where they cross the halfway line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local EstateDresser = require(script.Parent.EstateDresser)

local SportsCentreDresser = {}

local DISTRICT = "Community Sports Centre"
local SLAB_TOP = 0.3
local LINE_W = 1
local LINE_TOP = 0.36
local INSET = 5 -- markings in from the slab edge
local GOAL_H = 7
local CIRCLE_CHORDS = 8
local WHITE = Color3.fromRGB(245, 245, 240)
local GRASS = Color3.fromRGB(86, 146, 64)
local TURF_3G = Color3.fromRGB(52, 122, 72)
local FENCE_GREEN = Color3.fromRGB(34, 70, 44)
local MAST_GREY = Color3.fromRGB(170, 172, 176)
local CLAD = Color3.fromRGB(176, 186, 196)
local ROOF_GREY = Color3.fromRGB(96, 100, 108)
local NAVY = Color3.fromRGB(24, 38, 72)

export type Rect = { x0: number, x1: number, z0: number, z1: number }

-- Pure: marking rectangles for a pitch `width` (local X) by `length` (local Z,
-- the long axis) centred on the origin: touchlines, goal lines, halfway line
-- and two penalty boxes (3 lines each). Everything sits INSET inside the slab.
function SportsCentreDresser.pitchLines(width: number, length: number): { Rect }
	local x0, x1 = -width / 2 + INSET, width / 2 - INSET
	local z0, z1 = -length / 2 + INSET, length / 2 - INSET
	local w = LINE_W
	local lines: { Rect } = {
		{ x0 = x0, x1 = x0 + w, z0 = z0, z1 = z1 }, -- touchlines run the full length
		{ x0 = x1 - w, x1 = x1, z0 = z0, z1 = z1 },
		{ x0 = x0 + w, x1 = x1 - w, z0 = z0, z1 = z0 + w }, -- goal lines between them
		{ x0 = x0 + w, x1 = x1 - w, z0 = z1 - w, z1 = z1 },
		{ x0 = x0 + w, x1 = x1 - w, z0 = -w / 2, z1 = w / 2 }, -- halfway
	}
	local boxHalf = (x1 - x0) * 0.22
	local boxDepth = (z1 - z0) * 0.16
	for _, side in { -1, 1 } do
		local goalLine = if side < 0 then z0 + w else z1 - w
		local front = goalLine - side * boxDepth
		local lo, hi = math.min(goalLine, front), math.max(goalLine, front)
		table.insert(lines, { x0 = -boxHalf, x1 = -boxHalf + w, z0 = lo, z1 = hi })
		table.insert(lines, { x0 = boxHalf - w, x1 = boxHalf, z0 = lo, z1 = hi })
		local fz = if side < 0 then hi - w else lo
		table.insert(lines, { x0 = -boxHalf + w, x1 = boxHalf - w, z0 = fz, z1 = fz + w })
	end
	return lines
end

-- Pure: goal width for a pitch `width` across: 12% of it, between 14 and 24.
function SportsCentreDresser.goalWidth(width: number): number
	return math.clamp(width * 0.12, 14, 24)
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, collide: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Parent = parent
	return p
end

local function rectPart(parent: Instance, name: string, f: CFrame, r: Rect, y0: number, y1: number, colour: Color3, material: Enum.Material): BasePart
	return part(parent, name, Vector3.new(r.x1 - r.x0, y1 - y0, r.z1 - r.z0), f * CFrame.new((r.x0 + r.x1) / 2, (y0 + y1) / 2, (r.z0 + r.z1) / 2), colour, material, false)
end

-- Frame at the block centre, ground level, with local Z along the long side.
local function pitchFrame(block: TownLayout.Box): (CFrame, number, number)
	local base = CFrame.new(block.centre.X, 0, block.centre.Z) * CFrame.Angles(0, math.rad(block.yaw), 0)
	if block.size.X > block.size.Z then
		return base * CFrame.Angles(0, math.pi / 2, 0), block.size.Z, block.size.X
	end
	return base, block.size.X, block.size.Z
end

local function buildPitch(parent: Instance, block: TownLayout.Box, is3G: boolean)
	local m = Instance.new("Model")
	m.Name = if is3G then "Pitch3G" else "GrassPitch"
	m.Parent = parent
	local f, width, length = pitchFrame(block)
	local lineParts = 0
	for _, r in SportsCentreDresser.pitchLines(width, length) do
		rectPart(m, "Line", f, r, SLAB_TOP - 0.02, LINE_TOP, WHITE, Enum.Material.SmoothPlastic).CastShadow = false
		lineParts += 1
	end
	-- centre circle: chords tangent to a ring, heights alternating
	local radius = math.min(width, length) * 0.12
	local chord = 2 * radius * math.sin(math.pi / CIRCLE_CHORDS)
	for k = 0, CIRCLE_CHORDS - 1 do
		local a = (k + 0.5) * 2 * math.pi / CIRCLE_CHORDS
		local top = if k % 2 == 0 then 0.37 else 0.39
		local r = radius * math.cos(math.pi / CIRCLE_CHORDS)
		local cf = f * CFrame.new(math.cos(a) * r, (SLAB_TOP - 0.02 + top) / 2, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		part(m, "CentreCircle", Vector3.new(LINE_W, top - SLAB_TOP + 0.02, chord + LINE_W * 0.5), cf, WHITE, Enum.Material.SmoothPlastic, false).CastShadow = false
	end
	-- goals on the goal lines
	local goalHalf = SportsCentreDresser.goalWidth(width) / 2
	for _, side in { -1, 1 } do
		local z = side * (length / 2 - INSET - LINE_W / 2)
		for _, sx in { -1, 1 } do
			part(m, "GoalPost", Vector3.new(0.5, GOAL_H, 0.5), f * CFrame.new(sx * (goalHalf + 0.25), SLAB_TOP + GOAL_H / 2, z), WHITE, Enum.Material.SmoothPlastic, true)
		end
		part(m, "Crossbar", Vector3.new(goalHalf * 2, 0.5, 0.5), f * CFrame.new(0, SLAB_TOP + GOAL_H - 0.25, z), WHITE, Enum.Material.SmoothPlastic, true)
	end
	if is3G then
		-- ball-stop fence just outside the slab, and a floodlight mast at each corner
		local hw, hl = width / 2 + 1, length / 2 + 1
		local fenceH = 10
		for _, spec in {
			{ size = Vector3.new(width + 2.4, fenceH, 0.2), offset = Vector3.new(0, fenceH / 2, -hl) },
			{ size = Vector3.new(width + 2.4, fenceH, 0.2), offset = Vector3.new(0, fenceH / 2, hl) },
			{ size = Vector3.new(0.2, fenceH, length + 2), offset = Vector3.new(-hw, fenceH / 2, 0) },
			{ size = Vector3.new(0.2, fenceH, length + 2), offset = Vector3.new(hw, fenceH / 2, 0) },
		} do
			local panel = part(m, "BallStopFence", spec.size, f * CFrame.new(spec.offset), FENCE_GREEN, Enum.Material.SmoothPlastic, true)
			panel.Transparency = 0.55
			panel.CastShadow = false
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local base = f * CFrame.new(sx * (hw + 2), 0, sz * (hl + 2))
				part(m, "Mast", Vector3.new(0.8, 30, 0.8), base * CFrame.new(0, 15, 0), MAST_GREY, Enum.Material.Metal, true)
				part(m, "LampHead", Vector3.new(4, 2.2, 1), base * CFrame.new(0, 30.6, 0), MAST_GREY, Enum.Material.Metal, false).CastShadow = false
			end
		end
	end
end

local function buildHall(parent: Instance, block: TownLayout.Box)
	local m = Instance.new("Model")
	m.Name = "SportsHall"
	m.Parent = parent
	-- local -X faces the nearest road (EstateBuilder's convention)
	local cf, width, depth = EstateDresser.placement(block, TownLayout.ROADS)
	local h = block.size.Y
	part(m, "Body", Vector3.new(depth, h, width), cf * CFrame.new(0, h / 2, 0), CLAD, Enum.Material.Metal, true)
	part(m, "Roof", Vector3.new(depth + 1.2, 0.8, width + 1.2), cf * CFrame.new(0, h + 0.4, 0), ROOF_GREY, Enum.Material.Metal, true)
	-- fascia band along the top of the road face, 0.4 proud of the wall
	local fascia = part(m, "Fascia", Vector3.new(0.4, 4, width * 0.8), cf * CFrame.new(-depth / 2 - 0.2, h - 3, 0), NAVY, Enum.Material.SmoothPlastic, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.8
	gui.Parent = fascia
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "RIVERMERE COMMUNITY SPORTS CENTRE"
	label.Parent = gui
	-- glazed entrance in the middle of the road face
	local glass = part(m, "Entrance", Vector3.new(0.3, 10, 18), cf * CFrame.new(-depth / 2 - 0.15, 5, 0), Color3.fromRGB(60, 80, 100), Enum.Material.Glass, false)
	glass.Transparency = 0.2
	part(m, "Canopy", Vector3.new(6, 0.5, 22), cf * CFrame.new(-depth / 2 - 3, 10.5, 0), NAVY, Enum.Material.Metal, false)
end

-- Returns a summary line for the server log.
function SportsCentreDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "sports centre: no town"
	end
	local old = town:FindFirstChild("SportsCentre")
	if old then
		old:Destroy()
	end
	local districts = town:FindFirstChild("Districts")
	local greybox = districts and districts:FindFirstChild(DISTRICT)
	local root = Instance.new("Model")
	root.Name = "SportsCentre"
	local pitches, halls = 0, 0
	for _, district in TownLayout.DISTRICTS do
		if district.name ~= DISTRICT then
			continue
		end
		for _, block in district.blocks do
			if block.use == "grass pitch" or block.use == "3G pitch" then
				local is3G = block.use == "3G pitch"
				-- recolour the greybox slab in place (no new part for the surface)
				if greybox then
					for _, p in greybox:GetChildren() do
						if p:IsA("BasePart") and p.Name == block.use and math.abs(p.Position.X - block.centre.X) <= 0.5 and math.abs(p.Position.Z - block.centre.Z) <= 0.5 then
							p.Color = if is3G then TURF_3G else GRASS
							p.Material = if is3G then Enum.Material.Fabric else Enum.Material.Grass
						end
					end
				end
				buildPitch(root, block, is3G)
				pitches += 1
			elseif block.use == "sports hall" then
				if greybox then
					for _, p in greybox:GetChildren() do
						if p:IsA("BasePart") and (p.Name == block.use or p.Name == block.use .. " roof") and math.abs(p.Position.X - block.centre.X) <= 0.5 and math.abs(p.Position.Z - block.centre.Z) <= 0.5 then
							p:Destroy()
						end
					end
				end
				buildHall(root, block)
				halls += 1
			end
		end
	end
	root.Parent = town
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("sports centre: %d pitches, %d halls, %d parts"):format(pitches, halls, parts)
end

return SportsCentreDresser
