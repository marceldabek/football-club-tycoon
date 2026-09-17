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
-- Part budget: semiPair <= 14 (body 1, attic wedges 2, roof slabs 2, ridge 1,
-- chimney 2, garden wall <= 3 segments, hedge <= 3 segments) against a
-- target of <= 16. shed ~15-16 (body 1, roof 2, sign 1, yard 1,
-- fence 7, pallets 2-3, +1 sand heap for "builders yard") against <= 25.

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
local MIN_SEGMENT = 1 -- garden wall / hedge stubs shorter than this are left out
local HEDGE_GAP_EXTRA = 0.4

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
EstateBuilder.GARDEN_OUT = 6 -- garden wall distance out from the front wall

export type Segment = { z0: number, z1: number }

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
	-- with a gate gap in each where a house's front path comes through (X29)
	local wallX = -(depth / 2 + EstateBuilder.GARDEN_OUT)
	local doors = { EstateBuilder.doorZ(width, frontName, 0), EstateBuilder.doorZ(width, frontName, 1) }
	for _, seg in EstateBuilder.splitAroundGaps(-width / 2, width / 2, doors, EstateBuilder.GATE_WIDTH, MIN_SEGMENT) do
		block("Part", "GardenWall", Vector3.new(1, 1.2, seg.z1 - seg.z0), cframe * CFrame.new(wallX, 0.6, (seg.z0 + seg.z1) / 2), WALL_STONE, Enum.Material.Concrete, model, true)
	end
	-- the hedge overlaps the wall's front 0.2 studs, so its gaps are HEDGE_GAP_EXTRA
	-- wider: the segment end faces never share a plane with the wall's
	for _, seg in EstateBuilder.splitAroundGaps(-width / 2 + 1, width / 2 - 1, doors, EstateBuilder.GATE_WIDTH + HEDGE_GAP_EXTRA, MIN_SEGMENT) do
		local hedge = block("Part", "Hedge", Vector3.new(1.4, 1.8, seg.z1 - seg.z0), cframe * CFrame.new(wallX - 1, 0.9, (seg.z0 + seg.z1) / 2), HEDGE_GREEN, Enum.Material.Grass, model, false)
		hedge.CastShadow = false
	end

	model.Parent = parent
	return model
end

-- A metal-clad shed for warehouse / workshop / trade counter / builders yard
-- blocks: roller-shutter front, shallow pitched roof, a unit sign, a yard
-- slab with a low mesh fence, a couple of pallets and (builders yard only) a
-- sand heap. `size` is (frontage along local Z, height, front-to-back depth
-- along local X), matching EstateDresser's placement.
function EstateBuilder.shed(cframe: CFrame, size: Vector3, parent: Instance, rng: Random?, kind: string?): Model
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
		block("Part", "Post" .. i, Vector3.new(0.3, fenceY * 2, 0.3), cframe * CFrame.new(c.X, fenceY, c.Z), FENCE_POST_COLOUR, Enum.Material.Metal, model, false)
	end
	for _, spec in {
		{ name = "FenceLeft", size = Vector3.new(YARD_DEPTH, fenceY, 0.15), offset = Vector3.new(-depth / 2 - YARD_DEPTH / 2, fenceY / 2, -hw) },
		{ name = "FenceRight", size = Vector3.new(YARD_DEPTH, fenceY, 0.15), offset = Vector3.new(-depth / 2 - YARD_DEPTH / 2, fenceY / 2, hw) },
		{ name = "FenceFront", size = Vector3.new(0.15, fenceY, width), offset = Vector3.new(-depth / 2 - YARD_DEPTH, fenceY / 2, 0) },
	} do
		local panel = block("Part", spec.name, spec.size, cframe * CFrame.new(spec.offset), FENCE_PANEL_COLOUR, Enum.Material.SmoothPlastic, model, false)
		panel.Transparency = 0.4
		panel.CastShadow = false
	end

	-- a couple of pallets tucked against the yard fence
	for i = 1, r:NextInteger(2, 3) do
		local px = -depth / 2 - 3 - i * 3.4
		local pz = -hw + 3 + i * (width - 6) / 4
		block("Part", "Pallet" .. i, Vector3.new(3.5, 1.2, 3.5), cframe * CFrame.new(px, 0.7, pz), PALLET_COLOUR, Enum.Material.WoodPlanks, model, true)
	end

	if kind == "builders yard" then
		local heap = block("Part", "SandHeap", Vector3.new(6, 2.4, 6), cframe * CFrame.new(-depth / 2 - YARD_DEPTH + 5, 1.1, hw - 5), SAND_COLOUR, Enum.Material.Sand, model, false)
		heap.Shape = Enum.PartType.Ball
	end

	model.Parent = parent
	return model
end

return EstateBuilder
