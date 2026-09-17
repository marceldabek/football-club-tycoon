--!strict
-- Low-part 1930s semi-detached pairs and industrial-estate sheds for town-wide
-- dressing (backlog E4.1 / E5.1). A pair is one brick-and-render body wearing
-- two facade Textures (one image tiled twice: EstateDresser.build() and
-- StreetDresser use the same "kit is a placeholder until uploaded" pattern as
-- TerraceBuilder), a hipped WedgePart roof, a party-wall chimney and a low
-- front garden wall + hedge. A shed is a metal-clad box with a roller-shutter
-- front, a shallow pitched roof, a unit sign, a yard slab, a mesh fence and a
-- couple of pallets (a sand heap too, for "builders yard").
--
-- Reference: assets/references/RivermereNorthfields.png (1930s semis,
-- pebble-dash render over brick, hipped clay-tile roofs, low front garden
-- walls and hedges) and assets/references/rivermer.industrialestate.png
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
-- Part budget: semiPair ~10 (body 1, roof 5, chimney 2, garden wall 1, hedge
-- 1) against a target of <= 14. shed ~15-16 (body 1, roof 2, sign 1, yard 1,
-- fence 7, pallets 2-3, +1 sand heap for "builders yard") against <= 25.

local EstateBuilder = {}

-- The lead fills these in after uploading assets/kit/_export/textures/*.png
-- (ids land in assets/kit/_export/asset_ids_textures.json).
EstateBuilder.TEXTURES = {
	semi_front_a = "rbxassetid://0", -- semi_front_a.png cream render, red door, bay window
	semi_front_b = "rbxassetid://0", -- semi_front_b.png white render, blue door, mirrored layout
	semi_side = "rbxassetid://0", -- semi_side.png plain seamless brick (gable ends)
	roof_tiles = "rbxassetid://0", -- roof_tiles.png red-brown clay tiles, seamless
	shed_cladding = "rbxassetid://0", -- shed_cladding.png grey-blue profiled metal, seamless
	shed_door = "rbxassetid://0", -- shed_door.png roller shutter + personnel door + blank sign fascia
	shed_sign_a = "rbxassetid://0", -- shed_sign_a.png "LUNE LOGISTICS"
	shed_sign_b = "rbxassetid://0", -- shed_sign_b.png "RIVERMERE PLANT HIRE"
	shed_sign_c = "rbxassetid://0", -- shed_sign_c.png "MILL LANE MOTORS"
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

-- Pure: pairs of semis a block of this length should hold. A block 40-50
-- long is one pair; a longer block gets floor(length / 48) pairs (matches a
-- ~24-stud house bay either side of a shared party wall).
function EstateBuilder.pairCount(length: number): number
	return math.max(1, math.floor(length / 48))
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
-- Texture tiled twice (StudsPerTileU = width / 2), a hipped roof, a chimney
-- on the party wall, and a low front garden wall + hedge 6 studs out.
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

	-- hipped roof: two long pitches over the front/back walls, two short
	-- pitches hipping the gable ends, and a short ridge between them
	local half = depth / 2 + EAVE
	local ridgeY = wallH + roofH
	local endInset = math.min(width * 0.28, depth + EAVE)
	local ridgeLength = math.max(1, width - endInset * 2)
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then math.pi / 2 else -math.pi / 2
		local cf = cframe * CFrame.new(side * half / 2, wallH + roofH / 2, 0) * CFrame.Angles(0, yaw, 0)
		local wedge = block("WedgePart", if side < 0 then "RoofFront" else "RoofBack", Vector3.new(ridgeLength, roofH, half), cf, ROOF_RED, Enum.Material.Slate, model, true)
		texture(wedge, Enum.NormalId.Top, "roof_tiles", 8, 8)
	end
	-- the hip-end wedges' slope runs along their local Z (low at the outer
	-- gable edge, high toward the ridge), so the flat dimension perpendicular
	-- to that (the wedge's local X) must be the building's depth, not the
	-- short endInset run -- the opposite axis order from the long pitches above
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then 0 else math.pi
		local cf = cframe * CFrame.new(0, wallH + roofH / 2, side * (width / 2 - endInset / 2)) * CFrame.Angles(0, yaw, 0)
		local wedge = block("WedgePart", if side < 0 then "RoofLeftEnd" else "RoofRightEnd", Vector3.new(depth + EAVE * 2, roofH, endInset), cf, ROOF_RED, Enum.Material.Slate, model, true)
		texture(wedge, Enum.NormalId.Top, "roof_tiles", 8, 8)
	end
	local ridge = block("Part", "Ridge", Vector3.new(0.8, 0.5, ridgeLength), cframe * CFrame.new(0, ridgeY, 0), ROOF_RED:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Slate, model, false)
	ridge.CastShadow = false

	-- chimney straddles the ridge on the shared party wall (pair centre)
	block("Part", "Stack", Vector3.new(2, 3.5, 1.6), cframe * CFrame.new(0, ridgeY + 1.5, 0), STACK_COLOUR, Enum.Material.Brick, model, true)
	local pots = block("Part", "Pots", Vector3.new(1, 0.8, 1.2), cframe * CFrame.new(0, ridgeY + 3.4, 0), STACK_COLOUR:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic, model, false)
	pots.CastShadow = false

	-- low front garden wall + hedge, 6 studs out from the front (-X)
	local wallX = -(depth / 2 + 6)
	block("Part", "GardenWall", Vector3.new(1, 1.2, width), cframe * CFrame.new(wallX, 0.6, 0), WALL_STONE, Enum.Material.Concrete, model, true)
	local hedge = block("Part", "Hedge", Vector3.new(1.4, 1.8, math.max(1, width - 2)), cframe * CFrame.new(wallX - 1, 0.9, 0), HEDGE_GREEN, Enum.Material.Grass, model, false)
	hedge.CastShadow = false

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
