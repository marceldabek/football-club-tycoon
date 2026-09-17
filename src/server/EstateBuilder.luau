--!strict
-- Low-part 1930s semi-detached pairs and industrial-estate sheds for town-wide
-- dressing (backlog E4.1 / E5.1). A pair is one brick-and-render body wearing
-- two facade Textures (one image tiled twice: EstateDresser.build() and
-- StreetDresser use the same "kit is a placeholder until uploaded" pattern as
-- TerraceBuilder), a gable roof with brick gable ends, a party-wall chimney
-- and a low front garden wall + hedge with a gate gap at each door. A shed is a metal-clad box with a roller-shutter
-- front, a shallow pitched roof, a unit sign, a yard slab, a mesh fence and a
-- couple of pallets (a sand heap too, for "builders yard").
--
-- Reference: assets/references/RivermereNorthfields.png (1930s semis,
-- pebble-dash render over brick, gabled clay-tile roofs with brick gable
-- ends, low front garden walls and hedges) and assets/references/rivermer.industrialestate.png
-- (grey/blue profiled-metal sheds, roller shutters, yards, pallets, unit
-- signage).
--
-- Frame convention (same as TerraceBuilder): the unit's local -X is the
-- street FRONT, +X is the back, and the bottom of the walls sits at the
-- CFrame's Y. A semis block's width runs along local Z (multiple pairs sit
-- side by side); a shed's width (frontage) also runs along local Z.
--
-- Textures come from tools/kit/make_buildings.py (512x512 / 512x128 PNGs,
-- uploaded with tools/upload_kit.py --images). While an id is still
-- rbxassetid://0 that Texture is simply skipped and the plain material shows.
--
-- Part budget: semiPair <= 16 (body 1, attic wedges 2, roof slabs 2, ridge 1,
-- chimney 2, garden wall <= 3 segments, hedge <= 3 segments, porch hoods 2) against a
-- target of <= 16. driveway <= 3 (slab 1, optional parked car body + cabin 2).
-- shed body 1, roof 2, sign 1, yard 1, fence 4 posts + palisade sections
-- (1 per side, width / 20 across the front; 3 mesh panels if the union
-- fails), and either a lorry (X55),
-- pallets 2-3, or (every third unit) a forklift 8 + pallets 1-2, +1 sand heap
-- for "builders yard"; kept <= 30.
--
-- Plot layout (backlog X30): a semis block is split into rowLayout slots,
-- each pair centred in its slot with a SIDE_GAP driveway strip between
-- neighbours, and fitPair pushes the house back so the whole front garden
-- (wall + hedge) sits inside the block instead of on the public pavement.

local GeometryService = game:GetService("GeometryService")
local KitPlacer = require(script.Parent.KitPlacer)

local EstateBuilder = {}

-- The lead fills these in after uploading assets/kit/_export/textures/*.png
-- (ids land in assets/kit/_export/asset_ids_textures.json).
EstateBuilder.TEXTURES = {
	semi_front_a = "rbxassetid://86227648157444", -- semi_front_a.png cream render, red door, bay window
	semi_front_b = "rbxassetid://96244530243715", -- semi_front_b.png white render, blue door, mirrored layout
	semi_side = "rbxassetid://81200911777912", -- semi_side.png plain seamless brick (gable ends)
	roof_tiles = "rbxassetid://107062786945119", -- roof_tiles.png red-brown clay tiles, seamless
	shed_cladding = "rbxassetid://91306351376128", -- shed_cladding.png grey-blue profiled metal, seamless
	shed_door = "rbxassetid://94659629504751", -- shed_door.png roller shutter + personnel door + blank sign fascia
	shed_sign_a = "rbxassetid://110260477425803", -- shed_sign_a.png "LUNE LOGISTICS"
	shed_sign_b = "rbxassetid://87492718476432", -- shed_sign_b.png "RIVERMERE PLANT HIRE"
	shed_sign_c = "rbxassetid://90435262795416", -- shed_sign_c.png "MILL LANE MOTORS"
} :: { [string]: string }

local FRONT_VARIANTS = { "semi_front_a", "semi_front_b" }
local RENDER_COLOURS: { [string]: Color3 } = {
	semi_front_a = Color3.fromRGB(222, 214, 192), -- cream
	semi_front_b = Color3.fromRGB(232, 230, 224), -- white
}
local SIGN_TEXTURES = { "shed_sign_a", "shed_sign_b", "shed_sign_c" }

local BRICK = Color3.fromRGB(150, 62, 46)
local ROOF_RED = Color3.fromRGB(140, 70, 46)
local STACK_COLOUR = Color3.fromRGB(120, 66, 52)
local WALL_STONE = Color3.fromRGB(196, 188, 170)
local HEDGE_GREEN = Color3.fromRGB(46, 92, 44)

local CLAD_COLOUR = Color3.fromRGB(150, 162, 172)
local ROOF_GREY = Color3.fromRGB(180, 184, 190)
local YARD_COLOUR = Color3.fromRGB(150, 150, 148)
local FENCE_POST_COLOUR = Color3.fromRGB(70, 70, 74)
local FENCE_PANEL_COLOUR = Color3.fromRGB(120, 130, 138)
local PALLET_COLOUR = Color3.fromRGB(160, 128, 84)
local SAND_COLOUR = Color3.fromRGB(198, 176, 132)

local WALL_SHARE = 0.62 -- of the pair's height; the rest is roof pitch
local EAVE = 0.6 -- roof overhang past the front and back walls
local CLAD_TILE = 8 -- shed_cladding.png tile size in studs
local SHED_DOOR_TILE = 30 -- one shed_door.png image per this many studs of frontage
local YARD_DEPTH = 20
EstateBuilder.YARD_DEPTH = YARD_DEPTH
local MIN_SEGMENT = 1 -- garden wall / hedge stubs shorter than this are left out
local HEDGE_GAP_EXTRA = 0.4
local GARDEN_WALL_T = 1
local DRIVE_TOP = 0.35 -- differs by 0.05 from lawns (0.30) and forecourt paths (0.40), 0.10 under the pavement (0.45)
local DRIVE_UNDER = 0.1 -- a driveway runs this far under a neighbouring house body (no shared face with the gable)
local DRIVE_INSET = 0.05 -- ...and stops this far inside the block's edges
local TARMAC = Color3.fromRGB(62, 62, 66)
local GRAVEL = Color3.fromRGB(168, 160, 146)
local CAR_COLOURS = {
	Color3.fromRGB(40, 48, 62), -- navy
	Color3.fromRGB(150, 152, 156), -- silver
	Color3.fromRGB(128, 28, 30), -- red
	Color3.fromRGB(236, 236, 232), -- white
}

-- Pure: pairs of semis a block of this length should hold. A block 40-50
-- long is one pair; a longer block gets floor(length / 48) pairs (matches a
-- ~24-stud house bay either side of a shared party wall).
function EstateBuilder.pairCount(length: number): number
	return math.max(1, math.floor(length / 48))
end

-- Front doors (shared with ForecourtDresser's front paths). semi_front_a has
-- its door at 40..126 px of 512 from the image's left edge; semi_front_b is
-- mirrored (tools/kit/make_buildings.py). On the body's Left (-X) face the
-- image's left edge is the -Z end of each tile. Fraction across one house.
EstateBuilder.DOOR_U = { semi_front_a = 83 / 512, semi_front_b = 1 - 83 / 512 } :: { [string]: number }
EstateBuilder.GATE_WIDTH = 4 -- gap in the garden wall per door (front paths are 3 wide)
-- door head height as a share of the front wall and door width as a share of
-- one house: make_buildings.py draws the door at y 290..490 of 512 (top down)
-- and x 40..126 (X57)
EstateBuilder.DOOR_TOP_SHARE = (512 - 290) / 512
EstateBuilder.DOOR_WIDTH_SHARE = 86 / 512
EstateBuilder.GARDEN_OUT = 6 -- garden wall (centre line) distance out from the front wall
-- how far the front garden reaches out from the front wall: the wall's outer
-- face (the hedge stands behind the wall, on the house side)
EstateBuilder.GARDEN_REACH = EstateBuilder.GARDEN_OUT + GARDEN_WALL_T / 2
EstateBuilder.PLOT_MARGIN = 0.5 -- the garden wall stays this far inside the block's road-facing edge
EstateBuilder.MIN_HOUSE_DEPTH = 14 -- TEMP
EstateBuilder.MAX_HOUSE_DEPTH = 24 -- TEMP: a block whose short side faces the road keeps a back garden instead of a 40-deep house
EstateBuilder.SIDE_GAP = 10 -- TEMP driveway strip between neighbouring pairs (half of it at each block end)

export type Segment = { z0: number, z1: number }
export type PairSlot = { z: number, width: number }

-- Pure: house depth and house-centre offset along local X (+ = away from the
-- road) for a semis block `blockDepth` deep, framed at the block centre with
-- the road-facing edge at x = -blockDepth / 2. The front garden (`gardenOut`
-- from the front wall to its outermost face) starts PLOT_MARGIN inside that
-- edge and the house front stands right behind it. The house takes whatever
-- depth is left, clamped to [minDepth, maxDepth] (maxDepth defaults to
-- MAX_HOUSE_DEPTH): on a normal block its back sits on the block's back
-- edge; on a deep block the rest is back garden; if even minDepth does not
-- fit, the garden still stays inside the road edge and the house back runs
-- past the block's back edge instead (no current block is that shallow).
function EstateBuilder.fitPair(blockDepth: number, gardenOut: number, minDepth: number, maxDepth: number?): (number, number)
	local front = -blockDepth / 2 + EstateBuilder.PLOT_MARGIN + gardenOut
	local available = blockDepth - EstateBuilder.PLOT_MARGIN - gardenOut
	local houseDepth = math.max(minDepth, math.min(available, maxDepth or EstateBuilder.MAX_HOUSE_DEPTH))
	return houseDepth, front + houseDepth / 2
end

-- Pure: pair slots and driveway slabs along a semis block `blockWidth` wide
-- (local Z, centred on 0). Each of pairCount(blockWidth) slots holds one pair
-- centred in it, narrowed by the side gap (sideGap, but at most a quarter of
-- the slot). Driveway slabs fill every gap: a full gap between neighbours,
-- half a gap at each block end. Each slab runs DRIVE_UNDER under the house
-- bodies beside it and stops DRIVE_INSET inside the block's ends. Sorted by z.
function EstateBuilder.rowLayout(blockWidth: number, sideGap: number): ({ PairSlot }, { Segment })
	local n = EstateBuilder.pairCount(blockWidth)
	local step = blockWidth / n
	local gap = math.clamp(sideGap, 0, step * 0.25)
	local slots: { PairSlot } = {}
	for i = 1, n do
		table.insert(slots, { z = -blockWidth / 2 + (i - 0.5) * step, width = step - gap })
	end
	local drives: { Segment } = {}
	if gap > 0 then
		for i = 0, n do
			local b = -blockWidth / 2 + i * step
			-- the block ends (i = 0, i = n) have houses on one side only
			local z0 = if i == 0 then b + DRIVE_INSET else b - gap / 2 - DRIVE_UNDER
			local z1 = if i == n then b - DRIVE_INSET else b + gap / 2 + DRIVE_UNDER
			if z1 - z0 > DRIVE_UNDER + DRIVE_INSET then
				table.insert(drives, { z0 = z0, z1 = z1 })
			end
		end
	end
	return slots, drives
end

-- Pure: local Z of house `house` (0 = the -Z house, 1 = the +Z house) front
-- door, for a pair `width` wide centred on Z = 0 wearing front `frontName`.
-- An unknown front puts the door mid-house.
function EstateBuilder.doorZ(width: number, frontName: string?, house: number): number
	local u = 0.5
	if frontName then
		u = EstateBuilder.DOOR_U[frontName] or 0.5
	end
	return -width / 2 + (house + u) * width / 2
end

-- Pure: the parts of [z0, z1] left after cutting a gap `gapWidth` wide
-- centred on each of `centres` (gaps may overlap or run off either end).
-- Pieces shorter than `minLength` are dropped. Sorted by z0.
function EstateBuilder.splitAroundGaps(z0: number, z1: number, centres: { number }, gapWidth: number, minLength: number): { Segment }
	local gaps: { Segment } = {}
	for _, c in centres do
		table.insert(gaps, { z0 = c - gapWidth / 2, z1 = c + gapWidth / 2 })
	end
	table.sort(gaps, function(a: Segment, b: Segment): boolean
		return a.z0 < b.z0
	end)
	local out: { Segment } = {}
	local cursor = z0
	for _, g in gaps do
		if g.z0 > cursor then
			local e = math.min(g.z0, z1)
			if e - cursor >= minLength then
				table.insert(out, { z0 = cursor, z1 = e })
			end
		end
		cursor = math.max(cursor, g.z1)
		if cursor >= z1 then
			break
		end
	end
	if z1 - cursor >= minLength then
		table.insert(out, { z0 = cursor, z1 = z1 })
	end
	return out
end

local function hasTexture(name: string): boolean
	local id = EstateBuilder.TEXTURES[name]
	return id ~= nil and id ~= "" and id ~= "rbxassetid://0"
end

local function texture(p: BasePart, face: Enum.NormalId, name: string, u: number, v: number, tint: Color3?)
	if not hasTexture(name) then
		return
	end
	local t = Instance.new("Texture")
	t.Name = name
	t.Texture = EstateBuilder.TEXTURES[name]
	t.Face = face
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	if tint then
		t.Color3 = tint
	end
	t.Parent = p
end

local function block(
	className: string,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	collide: boolean
): BasePart
	local p = (Instance.new(className) :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- X55: black steel palisade (rivermer.industrialestate.png yard fences). One
-- PALISADE_SECTION-long section of pointed pales on two rails is unioned once
-- per server with GeometryService and cloned along each fence, so a section
-- costs 1 part instead of ~15. If the union fails (or yields where it can't),
-- palisadeTemplate stays nil and callers keep the old translucent mesh panel.
EstateBuilder.FORKLIFT_KIT = "ForkliftYellow" -- ServerStorage.Kit.Vehicles (X114)
EstateBuilder.PALISADE_SECTION = 20
EstateBuilder.PALISADE_H = 4.5 -- about 1.6 m
local PALISADE_PALES = 22
local PALISADE_COLOUR = Color3.fromRGB(34, 36, 40)
local palisadeTemplate: BasePart? = nil
local palisadeTried = false

local function palisadeSection(): BasePart?
	if palisadeTried then
		return palisadeTemplate
	end
	palisadeTried = true
	local L, H = EstateBuilder.PALISADE_SECTION, EstateBuilder.PALISADE_H
	local pieces: { BasePart } = {}
	local function piece(size: Vector3, cf: CFrame)
		local q = Instance.new("Part")
		q.Anchored = true
		q.Size = size
		q.CFrame = cf
		table.insert(pieces, q)
	end
	local tipSide = 0.16
	for i = 1, PALISADE_PALES do
		local x = -L / 2 + (i - 0.5) * L / PALISADE_PALES
		piece(Vector3.new(0.22, H - tipSide, 0.08), CFrame.new(x, -tipSide / 2, 0))
		-- a small square turned 45 degrees makes the pointed top
		piece(Vector3.new(tipSide, tipSide, 0.08), CFrame.new(x, H / 2 - tipSide * 0.9, 0) * CFrame.Angles(0, 0, math.rad(45)))
	end
	for _, y in { -H / 2 + 0.5, H / 2 - 0.6 } do
		piece(Vector3.new(L, 0.14, 0.1), CFrame.new(0, y, 0.09))
	end
	local ok, result = pcall(function()
		return GeometryService:UnionAsync(pieces[1], { table.unpack(pieces, 2) }, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
			SplitApart = false,
		})
	end)
	for _, q in pieces do
		q:Destroy()
	end
	if ok and result and result[1] and result[1]:IsA("BasePart") then
		local u = result[1] :: BasePart
		u.Name = "Palisade"
		u.Anchored = true
		u.CanCollide = false
		u.CanTouch = false
		u.CanQuery = false
		u.CastShadow = false
		u.Material = Enum.Material.Metal
		u.Color = PALISADE_COLOUR
		if u:IsA("UnionOperation") then
			u.UsePartColor = true
		end
		palisadeTemplate = u
	end
	return palisadeTemplate
end

-- Sections needed for a fence of `length` (each stretched a little to fit).
function EstateBuilder.palisadeSections(length: number): number
	return math.max(1, math.ceil(length / EstateBuilder.PALISADE_SECTION - 1e-6))
end

-- A palisade run centred on `cf` (bottom at cf's Y) along cf's local X.
-- Returns false when no template could be made, so the caller can fall back.
function EstateBuilder.palisade(cf: CFrame, length: number, parent: Instance): boolean
	local template = palisadeSection()
	if not template then
		return false
	end
	local count = EstateBuilder.palisadeSections(length)
	local each = length / count
	for i = 1, count do
		local section = template:Clone()
		section.Size = Vector3.new(each, template.Size.Y, template.Size.Z)
		section.CFrame = cf * CFrame.new(-length / 2 + (i - 0.5) * each, template.Size.Y / 2, 0)
		section.Parent = parent
	end
	return true
end

-- A pair of semis sharing a party wall: one body wearing the chosen front
-- Texture tiled twice (StudsPerTileU = width / 2), a gable roof, a chimney
-- on the party wall, and a low front garden wall + hedge GARDEN_OUT studs
-- out, split round a gate gap at each front door.
function EstateBuilder.semiPair(cframe: CFrame, width: number, depth: number, height: number, parent: Instance, rng: Random?): Model
	local r = rng or Random.new()
	local frontName = FRONT_VARIANTS[r:NextInteger(1, #FRONT_VARIANTS)]
	local renderColour = RENDER_COLOURS[frontName] or BRICK
	local wallH = math.max(6, math.floor(height * WALL_SHARE + 0.5))
	local roofH = math.max(2, height - wallH)

	local model = Instance.new("Model")
	model.Name = "SemiPair"
	model:SetAttribute("Front", frontName)

	-- walls: Left (-X) is the street front, Right (+X) the back, Front/Back
	-- (Z) are the pair's exposed gable ends
	local body = block("Part", "Body", Vector3.new(depth, wallH, width), cframe * CFrame.new(0, wallH / 2, 0), renderColour, Enum.Material.SmoothPlastic, model, true)
	texture(body, Enum.NormalId.Left, frontName, width / 2, wallH)
	texture(body, Enum.NormalId.Front, "semi_side", depth, wallH)
	texture(body, Enum.NormalId.Back, "semi_side", depth, wallH)
	model.PrimaryPart = body

	-- Gable roof (backlog X25). The old hipped roof put two end WedgeParts of
	-- size (depth, roofH, endInset) at each end. A WedgePart is a prism: its
	-- slope (Top face) rises along local Z only, and its cross-section is the
	-- same at every local X. So an end wedge spanning the full depth is full
	-- height (roofH) along its whole inner edge, while the long pitches beside
	-- it drop from roofH at the ridge to 0 at the eaves. The part of that
	-- inner rectangle above the long pitches' slopes stood proud as two tall
	-- triangles either side of the ridge. A true hip needs CornerWedgeParts
	-- (the slope must fall along X and Z at once), and the reference
	-- (RivermereNorthfields.png) shows gable roofs with brick gable ends, so
	-- the pair now gets a plain gable roof instead:
	--
	--   attic   two brick WedgeParts (width, roofH, depth / 2), yawed so local
	--           +Z (the full-height Back face) points at the ridge line x = 0.
	--           Together they are the triangular prism under the roof; their
	--           Left/Right faces (local X = the building's Z) are the brick
	--           gable triangles, flush with the body's end walls.
	--   pitches two thin tiled slabs lying on the attic slopes. With run
	--           a = depth / 2 and rise roofH, the pitch angle is
	--           theta = atan(roofH / a) and the slope length L = sqrt(a^2 + roofH^2).
	--           For side s (-1 front, +1 back) the down-slope direction in
	--           the (x, y) plane is d = (s cos theta, -sin theta) and the
	--           outward normal is n = (s sin theta, cos theta). A box rotated
	--           about Z by phi = -s * theta has its local X along +-d and its
	--           local Y along n (check: s = +1, phi = -theta gives
	--           X = (cos theta, -sin theta) = d, Y = (sin theta, cos theta) = n;
	--           s = -1, phi = theta gives X = -d, Y = n). The slab runs from
	--           the ridge (t = 0) down past the wall by EAVE horizontally,
	--           i.e. to t = L + EAVE / cos theta, so its centre is
	--           ridge + d * (span / 2) + n * (GAP + T / 2): lifted GAP off the
	--           attic slope so the two surfaces are never coplanar.
	--   ridge   a capping strip over the small notch where the slabs meet.
	local ridgeY = wallH + roofH
	local run = depth / 2
	local theta = math.atan2(roofH, run)
	local slopeLength = math.sqrt(run * run + roofH * roofH)
	local slabT = 0.4
	local slabGap = 0.05
	local verge = 0.6 -- roof overhang past each gable end
	local span = slopeLength + EAVE / math.cos(theta)
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then math.pi / 2 else -math.pi / 2
		local attic = block(
			"WedgePart",
			if side < 0 then "AtticFront" else "AtticBack",
			Vector3.new(width, roofH, run),
			cframe * CFrame.new(side * run / 2, wallH + roofH / 2, 0) * CFrame.Angles(0, yaw, 0),
			BRICK,
			Enum.Material.Brick,
			model,
			true
		)
		texture(attic, Enum.NormalId.Left, "semi_side", depth, wallH)
		texture(attic, Enum.NormalId.Right, "semi_side", depth, wallH)

		local dx, dy = side * math.cos(theta), -math.sin(theta)
		local nx, ny = side * math.sin(theta), math.cos(theta)
		local lift = slabGap + slabT / 2
		local cx = dx * span / 2 + nx * lift
		local cy = ridgeY + dy * span / 2 + ny * lift
		local slab = block(
			"Part",
			if side < 0 then "RoofFront" else "RoofBack",
			Vector3.new(span, slabT, width + verge * 2),
			cframe * CFrame.new(cx, cy, 0) * CFrame.Angles(0, 0, -side * theta),
			ROOF_RED,
			Enum.Material.Slate,
			model,
			true
		)
		texture(slab, Enum.NormalId.Top, "roof_tiles", 8, 8)
	end
	-- the slabs' outer surfaces, extended, meet (GAP + T) / cos theta above
	-- ridgeY at x = 0 and drop tan theta per stud either side. A strip w wide
	-- centred there must be >= w * tan theta tall so its bottom corners sink
	-- into both slabs (no sliver of sky under it). It runs 0.1 past the slab
	-- ends so no end plane is shared.
	local ridgeTop = ridgeY + (slabGap + slabT) / math.cos(theta)
	local ridgeW = 0.9
	local ridgeH = 0.3 + ridgeW * math.tan(theta)
	local ridge = block("Part", "Ridge", Vector3.new(ridgeW, ridgeH, width + verge * 2 + 0.2), cframe * CFrame.new(0, ridgeTop, 0), ROOF_RED:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Slate, model, false)
	ridge.CastShadow = false

	-- chimney straddles the ridge on the shared party wall (pair centre); its
	-- foot sinks into the attic so no gap shows under it on either slope
	block("Part", "Stack", Vector3.new(2, 4.5, 1.6), cframe * CFrame.new(0, ridgeY + 1, 0), STACK_COLOUR, Enum.Material.Brick, model, true)
	local pots = block("Part", "Pots", Vector3.new(1, 0.8, 1.2), cframe * CFrame.new(0, ridgeY + 3.4, 0), STACK_COLOUR:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic, model, false)
	pots.CastShadow = false

	-- low front garden wall + hedge, GARDEN_OUT studs out from the front (-X),
	-- with a gate gap in each where a house's front path comes through (X29).
	-- Nothing reaches further out than GARDEN_REACH (the wall's outer face), so
	-- fitPair can keep the garden inside the block.
	local wallX = -(depth / 2 + EstateBuilder.GARDEN_OUT)
	local doors = { EstateBuilder.doorZ(width, frontName, 0), EstateBuilder.doorZ(width, frontName, 1) }
	for _, seg in EstateBuilder.splitAroundGaps(-width / 2, width / 2, doors, EstateBuilder.GATE_WIDTH, MIN_SEGMENT) do
		block("Part", "GardenWall", Vector3.new(GARDEN_WALL_T, 1.2, seg.z1 - seg.z0), cframe * CFrame.new(wallX, 0.6, (seg.z0 + seg.z1) / 2), WALL_STONE, Enum.Material.Concrete, model, true)
	end
	-- the hedge stands behind the wall (house side; X30: it used to stand in
	-- front and reach 1.2 further out) overlapping the wall's back 0.2 studs,
	-- so its gaps are HEDGE_GAP_EXTRA wider: the segment end faces never share
	-- a plane with the wall's
	for _, seg in EstateBuilder.splitAroundGaps(-width / 2 + 1, width / 2 - 1, doors, EstateBuilder.GATE_WIDTH + HEDGE_GAP_EXTRA, MIN_SEGMENT) do
		local hedge = block("Part", "Hedge", Vector3.new(1.4, 1.8, seg.z1 - seg.z0), cframe * CFrame.new(wallX + 1, 0.9, (seg.z0 + seg.z1) / 2), HEDGE_GREEN, Enum.Material.Grass, model, false)
		hedge.CastShadow = false
	end

	-- X57: a porch hood over each front door (RivermereNorthfields.png): a thin
	-- slate slab standing off the front wall
	local hoodW = EstateBuilder.DOOR_WIDTH_SHARE * width / 2 + 1
	for _, z in doors do
		local hoodY = wallH * EstateBuilder.DOOR_TOP_SHARE + 0.35
		-- one part per door keeps the pair inside its 16-part budget (brackets cost 4 more)
		block("Part", "PorchHood", Vector3.new(1.8, 0.3, hoodW), cframe * CFrame.new(-depth / 2 - 0.9, hoodY, z), ROOF_RED, Enum.Material.Slate, model, false)
	end

	model.Parent = parent
	return model
end

-- X57: a flower border under each house's front window (RivermereNorthfields.png
-- shows planted fronts, not bare lawn). One part per house, on the longer side
-- of its door path, standing just off the front wall of a semiPair built with
-- the same cframe / width / depth / front. Tagged Decor so Quality "Low" hides
-- them; kept out of semiPair's 16-part budget.
EstateBuilder.BED_DEPTH = 1.4
local BED_HEIGHT = 1.1 -- shows over the 1.8 hedge from the pavement; 0.6 hid behind it
local BED_WALL_GAP = 0.05
local BED_END_INSET = 0.6
local BED_COLOURS = {
	Color3.fromRGB(206, 96, 140), -- pink
	Color3.fromRGB(140, 110, 186), -- lavender
	Color3.fromRGB(236, 170, 190), -- pale pink (white read as gravel)
	Color3.fromRGB(222, 176, 60), -- yellow
	Color3.fromRGB(190, 56, 60), -- red
}

function EstateBuilder.flowerBeds(cframe: CFrame, width: number, depth: number, frontName: string?, parent: Instance, rng: Random): { BasePart }
	local beds = {}
	for house = 0, 1 do
		local z0, z1 = -width / 2 + house * width / 2 + BED_END_INSET, house * width / 2 - BED_END_INSET
		local door = EstateBuilder.doorZ(width, frontName, house)
		local before = { z0 = z0, z1 = door - EstateBuilder.GATE_WIDTH / 2 }
		local after = { z0 = door + EstateBuilder.GATE_WIDTH / 2, z1 = z1 }
		local seg = if before.z1 - before.z0 >= after.z1 - after.z0 then before else after
		if seg.z1 - seg.z0 >= MIN_SEGMENT then
			local bed = block(
				"Part",
				"FlowerBed",
				Vector3.new(EstateBuilder.BED_DEPTH, BED_HEIGHT, seg.z1 - seg.z0),
				cframe * CFrame.new(-depth / 2 - BED_WALL_GAP - EstateBuilder.BED_DEPTH / 2, BED_HEIGHT / 2, (seg.z0 + seg.z1) / 2),
				BED_COLOURS[rng:NextInteger(1, #BED_COLOURS)],
				Enum.Material.LeafyGrass,
				parent,
				false
			)
			bed.CastShadow = false
			bed:SetAttribute("Decor", true)
			table.insert(beds, bed)
		end
	end
	return beds
end

-- A driveway strip beside a semi pair (X30): one tarmac or gravel slab
-- `width` wide (local Z) and `length` long (local X), top at DRIVE_TOP, with
-- an optional parked car block (body + cabin) near the road end when the
-- strip is at least 5 wide. The frame is the slab's centre at ground level,
-- local -X toward the road. <= 3 parts.
function EstateBuilder.driveway(cframe: CFrame, width: number, length: number, parent: Instance, withCar: boolean, rng: Random?): Model
	local r = rng or Random.new()
	local model = Instance.new("Model")
	model.Name = "Driveway"
	local gravel = r:NextNumber() < 0.4
	local slab = block(
		"Part",
		"Drive",
		Vector3.new(length, DRIVE_TOP, width),
		cframe * CFrame.new(0, DRIVE_TOP / 2, 0),
		if gravel then GRAVEL else TARMAC,
		if gravel then Enum.Material.Pebble else Enum.Material.Asphalt,
		model,
		true
	)
	slab.CastShadow = false
	model.PrimaryPart = slab

	local carL, carW, bodyH, sink = 8, 4, 1.8, 0.1
	if withCar and width >= 5 and length >= carL + 2 then
		local colour = CAR_COLOURS[r:NextInteger(1, #CAR_COLOURS)]
		-- the nose sits 1 stud inside the road end; the body sinks `sink` into
		-- the slab and the cabin `sink` into the body (no shared faces)
		local cx = -length / 2 + 1 + carL / 2
		local bodyBottom = DRIVE_TOP - sink
		block("Part", "CarBody", Vector3.new(carL, bodyH, carW), cframe * CFrame.new(cx, bodyBottom + bodyH / 2, 0), colour, Enum.Material.SmoothPlastic, model, true)
		local cabinH = 1.4
		local cabin = block(
			"Part",
			"CarCabin",
			Vector3.new(carL * 0.55, cabinH, carW - 0.4),
			cframe * CFrame.new(cx + 0.6, bodyBottom + bodyH - sink + cabinH / 2, 0),
			colour:Lerp(Color3.new(0, 0, 0), 0.35),
			Enum.Material.Glass,
			model,
			false
		)
		cabin.CastShadow = false
	end

	model.Parent = parent
	return model
end

-- A metal-clad shed for warehouse / workshop / trade counter / builders yard
-- blocks: roller-shutter front, shallow pitched roof, a unit sign, a yard
-- slab with a low mesh fence, a couple of pallets and (builders yard only) a
-- sand heap. `size` is (frontage along local Z, height, front-to-back depth
-- along local X), matching EstateDresser's placement.
local PLINTH_BRICK = Color3.fromRGB(146, 82, 60)
local UNIT_NAVY = Color3.fromRGB(28, 42, 74)

-- Pure (X64): body depth and body-centre offset along local X (+ = away from
-- the road) for a shed on a block `blockDepth` deep framed at the block centre,
-- so the yard in front of it ends PLOT_MARGIN inside the block's road-facing
-- edge instead of running onto the pavement. The body keeps at least 10.
function EstateBuilder.shedFit(blockDepth: number): (number, number)
	local bodyDepth = math.max(10, blockDepth - YARD_DEPTH - EstateBuilder.PLOT_MARGIN)
	local front = -blockDepth / 2 + EstateBuilder.PLOT_MARGIN + YARD_DEPTH
	return bodyDepth, front + bodyDepth / 2
end

function EstateBuilder.shed(cframe: CFrame, size: Vector3, parent: Instance, rng: Random?, kind: string?, unit: number?): Model
	local r = rng or Random.new()
	local width, height, depth = size.X, size.Y, size.Z

	local model = Instance.new("Model")
	model.Name = "Shed"
	model:SetAttribute("Kind", kind or "shed")

	local body = block("Part", "Body", Vector3.new(depth, height, width), cframe * CFrame.new(0, height / 2, 0), CLAD_COLOUR, Enum.Material.Metal, model, true)
	texture(body, Enum.NormalId.Right, "shed_cladding", CLAD_TILE, CLAD_TILE)
	texture(body, Enum.NormalId.Front, "shed_cladding", CLAD_TILE, CLAD_TILE)
	texture(body, Enum.NormalId.Back, "shed_cladding", CLAD_TILE, CLAD_TILE)
	-- the front (-X) gets exactly one door image per SHED_DOOR_TILE studs
	texture(body, Enum.NormalId.Left, "shed_door", SHED_DOOR_TILE, math.min(height, SHED_DOOR_TILE))
	model.PrimaryPart = body

	-- shallow pitched roof
	local roofH = math.max(1.5, height * 0.12)
	local half = depth / 2 + 0.8
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then math.pi / 2 else -math.pi / 2
		local cf = cframe * CFrame.new(side * half / 2, height + roofH / 2, 0) * CFrame.Angles(0, yaw, 0)
		block("WedgePart", if side < 0 then "RoofFront" else "RoofBack", Vector3.new(width, roofH, half), cf, ROOF_GREY, Enum.Material.Metal, model, true)
	end

	-- unit sign mounted beside the door, on the front wall
	local signName = SIGN_TEXTURES[r:NextInteger(1, #SIGN_TEXTURES)]
	local signWidth = math.min(width * 0.6, 30)
	local sign = block("Part", "Sign", Vector3.new(0.3, signWidth * 0.25, signWidth), cframe * CFrame.new(-depth / 2 - 0.2, height * 0.8, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, model, false)
	sign.CastShadow = false
	texture(sign, Enum.NormalId.Left, signName, signWidth, signWidth * 0.25)

	-- X55: a brick plinth course round the sides and back (the front keeps its
	-- full-height roller doors), 0.15 proud of the cladding, as in
	-- rivermer.industrialestate.png
	local plinthH = math.min(3, height * 0.3)
	for _, spec in {
		{ size = Vector3.new(depth + 0.3, plinthH, 0.15), offset = Vector3.new(0.15, 0, -width / 2 - 0.075) },
		{ size = Vector3.new(depth + 0.3, plinthH, 0.15), offset = Vector3.new(0.15, 0, width / 2 + 0.075) },
		{ size = Vector3.new(0.15, plinthH, width), offset = Vector3.new(depth / 2 + 0.075, 0, 0) },
	} do
		block("Part", "Plinth", spec.size, cframe * CFrame.new(spec.offset.X, plinthH / 2 - 0.05, spec.offset.Z), PLINTH_BRICK, Enum.Material.Brick, model, false)
	end
	-- unit number plate on the front, at the far end from the sign
	if unit and width >= 26 then
		local plate = block("Part", "UnitNumber", Vector3.new(0.3, 4, 4), cframe * CFrame.new(-depth / 2 - 0.2, height * 0.8, width / 2 - 3), UNIT_NAVY, Enum.Material.SmoothPlastic, model, false)
		plate.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.8, 0.8)
		label.Position = UDim2.fromScale(0.1, 0.1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = tostring(unit)
		label.Parent = gui
	end

	-- yard slab out to YARD_DEPTH studs in front, with a low mesh fence
	block("Part", "Yard", Vector3.new(YARD_DEPTH, 0.2, width), cframe * CFrame.new(-depth / 2 - YARD_DEPTH / 2, 0.1, 0), YARD_COLOUR, Enum.Material.Concrete, model, false)

	local hw = width / 2
	local fenceY = 1.4
	local corners = {
		Vector3.new(-depth / 2, 0, -hw),
		Vector3.new(-depth / 2, 0, hw),
		Vector3.new(-depth / 2 - YARD_DEPTH, 0, hw),
		Vector3.new(-depth / 2 - YARD_DEPTH, 0, -hw),
	}
	for i, c in corners do
		block("Part", "Post" .. i, Vector3.new(0.3, EstateBuilder.PALISADE_H + 0.3, 0.3), cframe * CFrame.new(c.X, (EstateBuilder.PALISADE_H + 0.3) / 2, c.Z), FENCE_POST_COLOUR, Enum.Material.Metal, model, false)
	end
	-- X55: steel palisade on the two yard sides and the front, clear of the
	-- corner posts by 0.2 at each end
	local sideLength = YARD_DEPTH - 0.5
	local yardMidX = -depth / 2 - YARD_DEPTH / 2
	local palisaded = EstateBuilder.palisade(cframe * CFrame.new(yardMidX, 0, -hw), sideLength, model)
		and EstateBuilder.palisade(cframe * CFrame.new(yardMidX, 0, hw), sideLength, model)
		and EstateBuilder.palisade(cframe * CFrame.new(-depth / 2 - YARD_DEPTH, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), width - 0.5, model)
	for _, spec in if palisaded then {} else {
		{ name = "FenceLeft", size = Vector3.new(YARD_DEPTH, fenceY, 0.15), offset = Vector3.new(-depth / 2 - YARD_DEPTH / 2, fenceY / 2, -hw) },
		{ name = "FenceRight", size = Vector3.new(YARD_DEPTH, fenceY, 0.15), offset = Vector3.new(-depth / 2 - YARD_DEPTH / 2, fenceY / 2, hw) },
		{ name = "FenceFront", size = Vector3.new(0.15, fenceY, width), offset = Vector3.new(-depth / 2 - YARD_DEPTH, fenceY / 2, 0) },
	} do
		local panel = block("Part", spec.name, spec.size, cframe * CFrame.new(spec.offset), FENCE_PANEL_COLOUR, Enum.Material.SmoothPlastic, model, false)
		panel.Transparency = 0.4
		panel.CastShadow = false
	end

	-- X55: warehouses wide enough get an articulated lorry parked along the
	-- yard (RIVERSIDE LOGISTICS, like the reference); other yards keep pallets
	if kind == "warehouse" and width >= 40 then
		local lx = -depth / 2 - YARD_DEPTH / 2 - 0.5
		local trailerL, cabL = 24, 7
		local startZ = -(trailerL + cabL + 1) / 2
		local trailer = block("Part", "Trailer", Vector3.new(7.4, 8, trailerL), cframe * CFrame.new(lx, 1.8 + 4, startZ + trailerL / 2), Color3.fromRGB(236, 238, 242), Enum.Material.SmoothPlastic, model, true)
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.Parent = trailer
			local label = Instance.new("TextLabel")
			label.BackgroundColor3 = UNIT_NAVY
			label.BorderSizePixel = 0
			label.Size = UDim2.fromScale(0.9, 0.5)
			label.Position = UDim2.fromScale(0.05, 0.25)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "RIVERSIDE LOGISTICS"
			label.Parent = gui
		end
		local cabZ = startZ + trailerL + 1 + cabL / 2
		block("Part", "Cab", Vector3.new(7.4, 7, cabL), cframe * CFrame.new(lx, 1.8 + 3.5, cabZ), UNIT_NAVY, Enum.Material.SmoothPlastic, model, true)
		local glass = block("Part", "Windscreen", Vector3.new(6.6, 2.6, 0.2), cframe * CFrame.new(lx, 1.8 + 5.2, cabZ + cabL / 2 + 0.05), Color3.fromRGB(40, 50, 60), Enum.Material.Glass, model, false)
		glass.CastShadow = false
		-- chassis under both, sunk into the yard slab
		block("Part", "Chassis", Vector3.new(5, 1, trailerL + cabL + 1), cframe * CFrame.new(lx, 1.3, startZ + (trailerL + cabL + 1) / 2), Color3.fromRGB(34, 34, 36), Enum.Material.Metal, model, false)
		for _, wz in { startZ + 4, startZ + trailerL - 4, cabZ } do
			-- a cylinder's axis is its local X, which already runs across the lorry
			local axle = block("Part", "Wheels", Vector3.new(7.8, 1.8, 1.8), cframe * CFrame.new(lx, 0.95, wz), Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic, model, false)
			axle.Shape = Enum.PartType.Cylinder
		end
	end

	-- X55: every third yard without a lorry (by unit number, TEMP for the part
	-- budget) gets a forklift facing the shed door, on the +Z side clear of the
	-- pallets (which stop at z = 0) and the sand heap
	local hasLorry = kind == "warehouse" and width >= 40
	local hasForklift = not hasLorry and (unit or 1) % 3 == 1
	if hasForklift and KitPlacer.find(EstateBuilder.FORKLIFT_KIT) then
		-- X114: the free Creator Store forklift mesh (MANIFEST), 7 long with its
		-- forks at its local -Z; turned so the forks point at the shed like the
		-- primitive one, centred where the primitive's body and forks were
		local fork = cframe * CFrame.new(-depth / 2 - 9, 0, hw - 5)
		KitPlacer.place(EstateBuilder.FORKLIFT_KIT, fork * CFrame.new(1, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), model)
	elseif hasForklift then
		local fork = cframe * CFrame.new(-depth / 2 - 9, 0, hw - 5) -- local +X toward the shed
		local orange, dark = Color3.fromRGB(226, 118, 32), Color3.fromRGB(38, 38, 42)
		block("Part", "ForkliftBody", Vector3.new(3.4, 1.8, 2.4), fork * CFrame.new(0, 1.4, 0), orange, Enum.Material.SmoothPlastic, model, true)
		block("Part", "ForkliftSeat", Vector3.new(1, 0.9, 1.2), fork * CFrame.new(-0.4, 2.75, 0), dark, Enum.Material.Fabric, model, false)
		block("Part", "ForkliftGuardPost", Vector3.new(0.2, 2, 2.2), fork * CFrame.new(-1.35, 3.3, 0), dark, Enum.Material.Metal, model, false)
		block("Part", "ForkliftGuardRoof", Vector3.new(3.2, 0.15, 2.4), fork * CFrame.new(0.15, 4.3, 0), dark, Enum.Material.Metal, model, false)
		block("Part", "ForkliftMast", Vector3.new(0.3, 4.4, 2), fork * CFrame.new(1.85, 2.4, 0), dark, Enum.Material.Metal, model, false)
		block("Part", "ForkliftForks", Vector3.new(2.8, 0.15, 1.6), fork * CFrame.new(3.4, 0.35, 0), dark, Enum.Material.Metal, model, false)
		for _, wx in { -1.1, 1.1 } do
			-- a cylinder's axis is its local X: turn it across the forklift
			local wheels = block("Part", "ForkliftWheels", Vector3.new(2.6, 1.2, 1.2), fork * CFrame.new(wx, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic, model, false)
			wheels.Shape = Enum.PartType.Cylinder
		end
	end

	-- a few pallets tucked against the yard fence (one fewer beside a forklift)
	local pallets = if hasLorry then 0 elseif hasForklift then r:NextInteger(1, 2) else r:NextInteger(2, 3)
	for i = 1, pallets do
		local px = -depth / 2 - 3 - i * 3.4
		local pz = -hw + 3 + i * (width - 6) / 4
		block("Part", "Pallet" .. i, Vector3.new(3.5, 1.2, 3.5), cframe * CFrame.new(px, 0.7, pz), PALLET_COLOUR, Enum.Material.WoodPlanks, model, true)
	end

	if kind == "builders yard" then
		-- X70: a Ball's diameter is its smallest axis, so a 6 x 2.4 x 6 "mound" was a
		-- 2.4 ball; a 5-stud ball sunk to y -0.5 shows a 4.8-wide heap, 1.8 above the yard
		local heap = block("Part", "SandHeap", Vector3.new(5, 5, 5), cframe * CFrame.new(-depth / 2 - YARD_DEPTH + 5, -0.5, hw - 5), SAND_COLOUR, Enum.Material.Sand, model, false)
		heap.Shape = Enum.PartType.Ball
	end

	model.Parent = parent
	return model
end

return EstateBuilder
