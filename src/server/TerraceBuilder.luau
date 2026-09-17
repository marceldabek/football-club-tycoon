--!strict
-- Low-part Victorian terraced row and street lamp for town-wide dressing
-- (backlog X12 / X13). The kit TerraceRowVictorian is ~166 parts a row and
-- LampVictorian 36, far too heavy for every street on a mid-range phone, so
-- the rest of town uses these: a row is one brick box wearing tiled facade
-- Textures, two slate WedgeParts, a ridge strip and 1-4 chimney stacks.
--
-- Reference: assets/references/RiveremereWestdale.png and RivermereNorthfields.png
-- (two-storey red-brick terraces, white sashes, stone lintels, coloured doors,
-- grey slate roofs with chimney stacks and pots, black lamp posts).
--
-- Row frame (same convention as the kit row): the row runs along local Z of the
-- CFrame, the street FRONT faces local -X, the BACK faces local +X, and the
-- bottom of the walls is at the CFrame's Y.
--
-- Part budget: row = body 1 + roof wedges 2 + ridge 1 + stacks 2 each (max 4)
-- = 6..12 parts, + 2 for an aerial and 2 for a dish (X99, some rows only).
-- Lamp = 6 parts.
--
-- Textures come from tools/kit/make_facades.py (512x512 PNGs, uploaded with
-- tools/upload_kit.py --images). While an id is still rbxassetid://0 that
-- Texture is simply skipped and the plain Brick / Slate material shows.

local TerraceBuilder = {}

-- The lead fills these in after uploading assets/kit/_export/textures/*.png
-- (ids land in assets/kit/_export/asset_ids_textures.json).
TerraceBuilder.TEXTURES = {
	front_a = "rbxassetid://93573179046252", -- terrace_front_a.png  red brick, navy door
	front_b = "rbxassetid://96266284494631", -- terrace_front_b.png  orange-red brick, bottle-green door
	front_c = "rbxassetid://79862245695312", -- terrace_front_c.png  brown brick, burgundy door, bay window
	back = "rbxassetid://77764095380617", -- terrace_back.png
	slate = "rbxassetid://77485834711521", -- slate_roof.png
	brick = "rbxassetid://74174126209346", -- brick_plain.png
} :: { [string]: string }

TerraceBuilder.HOUSE_WIDTH = 16 -- studs per house bay (one facade tile)
TerraceBuilder.MAX_STACKS = 4

local WALL_SHARE = 0.66 -- of the layout block height; the rest is roof pitch
local EAVE = 0.8 -- roof overhang past the front and back walls
local BRICK_TILE = 16 -- brick_plain.png covers 16 x 16 studs, same brick size as the facades
local SLATE_TILE = 12
local STACK_BELOW_RIDGE = 2.5
local STACK_ABOVE_RIDGE = 3
local STACK_SIZE = Vector3.new(2.2, 0, 4.4) -- Y comes from the two numbers above

type Variant = { front: string, body: Color3, tint: Color3 }

-- The back and gable textures are orange-red; tint multiplies them toward the front's palette.
local VARIANTS: { Variant } = {
	{ front = "front_a", body = Color3.fromRGB(150, 60, 44), tint = Color3.new(0.84, 0.66, 0.81) },
	{ front = "front_b", body = Color3.fromRGB(178, 92, 54), tint = Color3.new(1, 1, 1) },
	{ front = "front_c", body = Color3.fromRGB(112, 64, 46), tint = Color3.new(0.62, 0.7, 0.87) },
}

local SLATE = Color3.fromRGB(74, 82, 96)
local RIDGE = Color3.fromRGB(52, 56, 64)
local POTS = Color3.fromRGB(150, 78, 52)
local LAMP_BLACK = Color3.fromRGB(24, 24, 27)
local LAMP_GLOW = Color3.fromRGB(255, 222, 166)

-- Pure: houses in a row of this length (each bay is length / count wide, so the
-- facade tiles a whole number of times).
function TerraceBuilder.houseCount(length: number): number
	return math.max(2, math.floor(length / TerraceBuilder.HOUSE_WIDTH))
end

-- Pure: Z offsets (from the row centre) of chimney stacks. A stack sits on the
-- party wall shared by each pair of houses (walls 1, 3, 5, ...); rows with more
-- than MAX_STACKS pairs keep an evenly spread subset.
function TerraceBuilder.stackPositions(length: number): { number }
	local n = TerraceBuilder.houseCount(length)
	local w = length / n
	local walls: { number } = {}
	for k = 1, n - 1, 2 do
		table.insert(walls, -length / 2 + k * w)
	end
	local max = TerraceBuilder.MAX_STACKS
	if #walls <= max then
		return walls
	end
	local out: { number } = {}
	for i = 1, max do
		table.insert(out, walls[1 + math.round((i - 1) * (#walls - 1) / (max - 1))])
	end
	return out
end

local function hasTexture(name: string): boolean
	local id = TerraceBuilder.TEXTURES[name]
	return id ~= nil and id ~= "" and id ~= "rbxassetid://0"
end

local function texture(p: BasePart, face: Enum.NormalId, name: string, u: number, v: number, tint: Color3?)
	if not hasTexture(name) then
		return
	end
	local t = Instance.new("Texture")
	t.Name = name
	t.Texture = TerraceBuilder.TEXTURES[name]
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

-- X99: TV aerials on some chimney stacks and satellite dishes on some fronts
-- (the WORLD_ROADMAP E10 imperfection list). Seeded from the row's position,
-- not the builder's rng, so every other random choice in town stays the same.
-- TEMP shares; each is 2 parts and Quality Low hides them (Aerial*, Dish*).
TerraceBuilder.AERIAL_SHARE = 0.3
TerraceBuilder.DISH_SHARE = 0.3
-- Clear brick right of the upper-right window on front_a / front_c (u across
-- one house bay, v down from the wall top); front_b is the mirror image.
local DISH_U, DISH_V = 0.84, 0.2

-- Pure: which extras a row at this position gets. Returns the stack index
-- for an aerial (or nil) and the house index 0..houses-1 for a dish (or nil).
function TerraceBuilder.extras(position: Vector3, houses: number, stacks: number): (number?, number?)
	local r = Random.new(math.floor(position.X * 3.1 + position.Z * 7.7) % 2147483647)
	local aerial = if stacks > 0 and r:NextNumber() < TerraceBuilder.AERIAL_SHARE then r:NextInteger(1, stacks) else nil
	local dish = if r:NextNumber() < TerraceBuilder.DISH_SHARE then r:NextInteger(0, houses - 1) else nil
	return aerial, dish
end

-- Pure: row-local (z, y) of a dish centre on the front wall.
function TerraceBuilder.dishSpot(facade: string, house: number, houseWidth: number, length: number, wallHeight: number): (number, number)
	local u = if facade == "front_b" then 1 - DISH_U else DISH_U
	return -length / 2 + (house + u) * houseWidth, wallHeight * (1 - DISH_V)
end

function TerraceBuilder.row(cframe: CFrame, length: number, depth: number, height: number, parent: Instance, rng: Random?): Model
	local r = rng or Random.new()
	local variant = VARIANTS[r:NextInteger(1, #VARIANTS)]
	local wallH = math.floor(height * WALL_SHARE + 0.5)
	local roofH = math.max(2, height - wallH)
	local houses = TerraceBuilder.houseCount(length)
	local houseW = length / houses

	local model = Instance.new("Model")
	model.Name = "TerraceRow"
	model:SetAttribute("Houses", houses)
	model:SetAttribute("Facade", variant.front)

	-- walls: Left (-X) is the street front, Right (+X) the back, Front/Back (Z) the gable ends
	local body = block("Part", "Body", Vector3.new(depth, wallH, length), cframe * CFrame.new(0, wallH / 2, 0), variant.body, Enum.Material.Brick, model, true)
	texture(body, Enum.NormalId.Left, variant.front, houseW, wallH)
	texture(body, Enum.NormalId.Right, "back", houseW, wallH, variant.tint)
	texture(body, Enum.NormalId.Front, "brick", BRICK_TILE, BRICK_TILE, variant.tint)
	texture(body, Enum.NormalId.Back, "brick", BRICK_TILE, BRICK_TILE, variant.tint)
	model.PrimaryPart = body

	-- roof: a WedgePart's slope is its Top face, running from the low edge at
	-- local -Z up to the full-height Back face at +Z. Yaw each wedge so local -Z
	-- points out over its wall and the Back faces meet under the ridge at X = 0.
	-- Wedge bottoms rest exactly on the body top (opposite-facing, no z-fight).
	local half = depth / 2 + EAVE
	local ridgeY = wallH + roofH
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then math.pi / 2 else -math.pi / 2
		local cf = cframe * CFrame.new(side * half / 2, wallH + roofH / 2, 0) * CFrame.Angles(0, yaw, 0)
		local wedge = block("WedgePart", if side < 0 then "RoofFront" else "RoofBack", Vector3.new(length, roofH, half), cf, SLATE, Enum.Material.Slate, model, true)
		texture(wedge, Enum.NormalId.Top, "slate", SLATE_TILE, SLATE_TILE)
		-- the triangular Left/Right faces are the gables above the end walls
		texture(wedge, Enum.NormalId.Left, "brick", BRICK_TILE, BRICK_TILE, variant.tint)
		texture(wedge, Enum.NormalId.Right, "brick", BRICK_TILE, BRICK_TILE, variant.tint)
	end
	local ridge = block("Part", "Ridge", Vector3.new(0.9, 0.6, length + 0.2), cframe * CFrame.new(0, ridgeY, 0), RIDGE, Enum.Material.Slate, model, false)
	ridge.CastShadow = false

	-- chimney stacks straddle the ridge on shared party walls; pots are one darker box
	local stackH = STACK_BELOW_RIDGE + STACK_ABOVE_RIDGE
	local stackColor = variant.body:Lerp(Color3.new(0, 0, 0), 0.12)
	for i, z in TerraceBuilder.stackPositions(length) do
		local stackCf = cframe * CFrame.new(0, ridgeY - STACK_BELOW_RIDGE + stackH / 2, z)
		block("Part", "Stack" .. i, Vector3.new(STACK_SIZE.X, stackH, STACK_SIZE.Z), stackCf, stackColor, Enum.Material.Brick, model, true)
		-- sunk 0.1 into the stack top so the two tops never share a plane
		local pots = block(
			"Part",
			"Pots" .. i,
			Vector3.new(1.2, 1, STACK_SIZE.Z - 1.2),
			cframe * CFrame.new(0, ridgeY + STACK_ABOVE_RIDGE + 0.4, z),
			POTS,
			Enum.Material.SmoothPlastic,
			model,
			false
		)
		pots.CastShadow = false
	end

	local stacks = TerraceBuilder.stackPositions(length)
	local aerialStack, dishHouse = TerraceBuilder.extras(cframe.Position, houses, #stacks)
	if aerialStack then
		-- a mast at the stack's end, clear of the pots, with a cross bar across the ridge
		local z = stacks[aerialStack] + STACK_SIZE.Z / 2 - 0.35
		local mastBottom = ridgeY + STACK_ABOVE_RIDGE - 0.3
		local mast = block("Part", "AerialMast", Vector3.new(0.15, 3.4, 0.15), cframe * CFrame.new(0, mastBottom + 1.7, z), LAMP_BLACK, Enum.Material.Metal, model, false)
		mast.CastShadow = false
		local bar = block("Part", "AerialBar", Vector3.new(2.8, 0.12, 0.12), cframe * CFrame.new(0, mastBottom + 3.1, z), LAMP_BLACK, Enum.Material.Metal, model, false)
		bar.CastShadow = false
	end
	if dishHouse then
		local z, y = TerraceBuilder.dishSpot(variant.front, dishHouse, houseW, length, wallH)
		local front = -depth / 2
		-- bracket from the wall, then the dish turned a little along the street
		local bracket = block("Part", "DishBracket", Vector3.new(0.5, 0.2, 0.2), cframe * CFrame.new(front - 0.25, y - 0.5, z), LAMP_BLACK, Enum.Material.Metal, model, false)
		bracket.CastShadow = false
		local dish = block("Part", "Dish", Vector3.new(0.3, 1.7, 1.7), cframe * CFrame.new(front - 0.75, y - 0.2, z) * CFrame.Angles(0, math.rad(20), math.rad(-10)), Color3.fromRGB(214, 214, 210), Enum.Material.SmoothPlastic, model, false)
		;(dish :: Part).Shape = Enum.PartType.Cylinder
		dish.CastShadow = false
	end

	model.Parent = parent
	return model
end

-- A black Victorian-style post lamp, ~15.3 studs tall, lantern hanging out
-- toward local -Z (StreetDresser points -Z over the carriageway). 6 parts.
function TerraceBuilder.lamp(cframe: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "TerraceLamp"
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y
	local base = block("Part", "Base", Vector3.new(1.6, 1.3, 1.3), cframe * CFrame.new(0, 0.8, 0) * upright, LAMP_BLACK, Enum.Material.SmoothPlastic, model, true)
	base.Shape = Enum.PartType.Cylinder
	local post = block("Part", "Post", Vector3.new(12.6, 0.45, 0.45), cframe * CFrame.new(0, 7.5, 0) * upright, LAMP_BLACK, Enum.Material.SmoothPlastic, model, true)
	post.Shape = Enum.PartType.Cylinder -- 1.2 .. 13.8, bottom buried in the base
	model.PrimaryPart = post
	-- arm 13.15 .. 13.45, from just behind the post to under the lantern centre (ends short of the lantern face)
	block("Part", "Arm", Vector3.new(0.3, 0.3, 2.85), cframe * CFrame.new(0, 13.3, -1.175), LAMP_BLACK, Enum.Material.SmoothPlastic, model, false)
	local lanternY = 14.2 -- 13.4 .. 15.0, sits 0.05 into the arm
	local frame = block("Part", "Lantern", Vector3.new(1.3, 1.6, 1.3), cframe * CFrame.new(0, lanternY, -2.3), LAMP_BLACK, Enum.Material.SmoothPlastic, model, false)
	frame.CastShadow = false
	-- glass pokes 0.04 out of each side of the frame, top and bottom stay inside it
	local glow = block("Part", "Glass", Vector3.new(1.38, 1, 1.38), cframe * CFrame.new(0, lanternY, -2.3), LAMP_GLOW, Enum.Material.Neon, model, false)
	glow.CastShadow = false
	local cap = block("Part", "Cap", Vector3.new(1.8, 0.35, 1.8), cframe * CFrame.new(0, 15.125, -2.3), LAMP_BLACK, Enum.Material.SmoothPlastic, model, false)
	cap.CastShadow = false
	model.Parent = parent
	return model
end

return TerraceBuilder
