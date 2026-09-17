--!strict
-- Low-part shops, flats-above-shops, blocks of flats and civic buildings for
-- the town centre, high street and corner shops (backlog E2.1). Same idea as
-- TerraceBuilder: one brick body wearing tiled Textures, plus a few thin
-- facade parts so each ground-floor bay can show a DIFFERENT shopfront.
--
-- Reference: assets/references/RivermereCenter.png (painted timber shopfronts
-- with fascia signs, 2-3 storeys of brick with sash windows above, slate roofs
-- and chimney stacks) and RiveremereWestdale.png (Westdale Stores, dark green).
--
-- Frame (same as TerraceBuilder): the building runs along local Z of the
-- CFrame, the street FRONT faces local -X, the BACK faces +X, and the bottom of
-- the walls is at the CFrame's Y.
--
-- Heights: the ground floor is 12 studs; the rest of the layout block's height
-- is upper storeys of ~10 (see ShopBuilder.storeys). One upper storey = a
-- two-storey block with a shallow slate wedge roof; two or more = flat roof
-- behind a stone coping.
--
-- Part budget per shop row: body 1 + upper facade 1 + one 0.2-thick facade
-- part per bay + roof (coping 1, or 2 wedges) + 1 chimney stack = bays + 4..5.
-- flats = 3 parts, civic = 6 parts.
--
-- Textures come from tools/kit/make_shopfronts.py (upload list
-- assets/kit/_export/upload_shops.txt). While an id is rbxassetid://0 that
-- Texture is skipped and the part's plain colour shows (facade parts are
-- coloured like their fascia, so an un-textured street still reads).

local ShopBuilder = {}

-- The lead fills these in after uploading (ids land in assets/kit/_export/asset_ids_textures.json).
ShopBuilder.TEXTURES = {
	shop_front_cafe = "rbxassetid://0", -- The Daily Bean, navy
	shop_front_deli = "rbxassetid://0", -- The Little Deli, cream
	shop_front_estate = "rbxassetid://0", -- Hollis & Co., bottle green
	shop_front_pharmacy = "rbxassetid://0", -- Lune Pharmacy, teal
	shop_front_bakery = "rbxassetid://0", -- Rivermere Bakery, burgundy
	shop_front_butcher = "rbxassetid://0", -- Fletcher's Butchers, black
	shop_front_barber = "rbxassetid://0", -- Sharp Cuts, charcoal
	shop_front_charity = "rbxassetid://0", -- Rivermere Hospice Shop, plum
	shop_front_newsagent = "rbxassetid://0", -- Corner News, red
	shop_front_pub = "rbxassetid://0", -- The Riverside Arms
	shop_front_corner = "rbxassetid://0", -- Westdale Stores
	shop_front_corner2 = "rbxassetid://0", -- Northfields Stores
	shop_front_supermarket = "rbxassetid://0", -- Lune Fresh (1024x512)
	upper_floors_a = "rbxassetid://0", -- red brick, one storey repeated twice
	upper_floors_b = "rbxassetid://0", -- buff brick
	flats_facade = "rbxassetid://0",
	civic_facade = "rbxassetid://0",
	brick = "rbxassetid://0", -- orange-red brick_plain.png from make_facades.py (same image as TerraceBuilder.TEXTURES.brick)
	brick_buff = "rbxassetid://0", -- brick_buff.png
	slate = "rbxassetid://0", -- slate_roof.png from make_facades.py (same image as TerraceBuilder.TEXTURES.slate)
} :: { [string]: string }

ShopBuilder.GROUND_FLOOR = 12
ShopBuilder.STOREY = 10
ShopBuilder.BAY_WIDTH = 20
ShopBuilder.SUPERMARKET_WIDTH = 60
local SUPERMARKET_SIDE_MIN = 14 -- side bays next to the supermarket need at least this much room each

-- The ordinary shops, in the order the rng shuffles them, with fallback colours.
ShopBuilder.SHOP_FRONTS = {
	"shop_front_cafe",
	"shop_front_deli",
	"shop_front_estate",
	"shop_front_pharmacy",
	"shop_front_bakery",
	"shop_front_butcher",
	"shop_front_barber",
	"shop_front_charity",
	"shop_front_newsagent",
}

local FASCIA: { [string]: Color3 } = {
	shop_front_cafe = Color3.fromRGB(30, 44, 74),
	shop_front_deli = Color3.fromRGB(236, 230, 212),
	shop_front_estate = Color3.fromRGB(24, 72, 52),
	shop_front_pharmacy = Color3.fromRGB(22, 110, 116),
	shop_front_bakery = Color3.fromRGB(110, 30, 42),
	shop_front_butcher = Color3.fromRGB(22, 22, 24),
	shop_front_barber = Color3.fromRGB(58, 60, 66),
	shop_front_charity = Color3.fromRGB(88, 44, 108),
	shop_front_newsagent = Color3.fromRGB(170, 32, 32),
	shop_front_pub = Color3.fromRGB(18, 46, 34),
	shop_front_corner = Color3.fromRGB(24, 64, 50),
	shop_front_corner2 = Color3.fromRGB(24, 64, 50),
	shop_front_supermarket = Color3.fromRGB(206, 208, 206),
}

type Brick = { upper: string, side: string, body: Color3, tint: Color3? }

-- brick_plain is orange-red: the red variant tints it toward upper_floors_a's red
local BRICKS: { Brick } = {
	{ upper = "upper_floors_a", side = "brick", body = Color3.fromRGB(150, 60, 44), tint = Color3.new(0.84, 0.66, 0.81) },
	{ upper = "upper_floors_b", side = "brick_buff", body = Color3.fromRGB(196, 164, 112), tint = nil },
}

local BRICK_TILE = 16
local SLATE = Color3.fromRGB(74, 82, 96)
local COPING = Color3.fromRGB(214, 204, 182)
local CIVIC_STONE = Color3.fromRGB(214, 206, 188)
local FLATS_BRICK = Color3.fromRGB(132, 78, 56)
local FLATS_TINT = Color3.new(0.74, 0.85, 1) -- brick_plain toward flats_facade's brown
local FACADE_T = 0.2 -- facade parts stand this far proud of the body
local EAVE = 0.8

export type Bay = { centre: number, width: number, wide: boolean }

-- Pure: shop bays along a frontage of this length (about BAY_WIDTH each, at least one).
function ShopBuilder.bayCount(length: number): number
	return math.max(1, math.floor(length / ShopBuilder.BAY_WIDTH + 0.5))
end

-- Pure: upper storeys, wall height and roof height for a layout block height.
-- One upper storey gets a pitched roof (roofH > 0); two or more a flat roof (roofH 0).
function ShopBuilder.storeys(height: number): (number, number, number)
	local g = ShopBuilder.GROUND_FLOOR
	local floors = math.max(0, math.floor((height - g) / ShopBuilder.STOREY + 1e-6))
	if floors == 1 then
		local wallH = g + ShopBuilder.STOREY
		return floors, wallH, math.max(3, height - wallH)
	end
	return floors, math.max(g, height), 0
end

-- Pure: ground-floor bays along local Z (centre offsets from the middle of the
-- row). A supermarket takes one wide centre bay with ordinary bays either side
-- when there is room.
function ShopBuilder.bays(length: number, kind: string): { Bay }
	local out: { Bay } = {}
	local function run(z0: number, z1: number)
		local n = ShopBuilder.bayCount(z1 - z0)
		local w = (z1 - z0) / n
		for i = 1, n do
			table.insert(out, { centre = z0 + (i - 0.5) * w, width = w, wide = false })
		end
	end
	if kind == "supermarket" then
		local sw = ShopBuilder.SUPERMARKET_WIDTH
		if length - sw < 2 * SUPERMARKET_SIDE_MIN then
			table.insert(out, { centre = 0, width = length, wide = true })
			return out
		end
		run(-length / 2, -sw / 2)
		table.insert(out, { centre = 0, width = sw, wide = true })
		run(sw / 2, length / 2)
		return out
	end
	run(-length / 2, length / 2)
	return out
end

-- Texture key for each ordinary (not wide) bay, in order.
-- shops / shops with flats: distinct fronts shuffled by the rng (cycling past 9)
-- pub / pub and cafes: pub, cafe, then shuffled others
-- park cafe: cafe, bakery, deli...   corner shop: the district's stores, then others
-- supermarket: the side bays get shuffled others (the wide bay is the supermarket)
function ShopBuilder.frontsFor(kind: string, count: number, rng: Random, district: string?): { string }
	local pool = table.clone(ShopBuilder.SHOP_FRONTS)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local first: { string } = {}
	if kind == "pub" or kind == "pub and cafes" then
		first = { "shop_front_pub", "shop_front_cafe" }
	elseif kind == "park cafe" then
		first = { "shop_front_cafe", "shop_front_bakery", "shop_front_deli" }
	elseif kind == "corner shop" then
		first = { if district == "Northfields" then "shop_front_corner2" else "shop_front_corner" }
	end
	local seq: { string } = {}
	local used: { [string]: boolean } = {}
	for _, key in first do
		table.insert(seq, key)
		used[key] = true
	end
	for _, key in pool do
		if not used[key] then
			table.insert(seq, key)
		end
	end
	local out: { string } = {}
	for i = 1, count do
		out[i] = seq[(i - 1) % #seq + 1]
	end
	return out
end

local function hasTexture(name: string): boolean
	local id = ShopBuilder.TEXTURES[name]
	return id ~= nil and id ~= "" and id ~= "rbxassetid://0"
end

local function texture(p: BasePart, face: Enum.NormalId, name: string, u: number, v: number, tint: Color3?)
	if not hasTexture(name) then
		return
	end
	local t = Instance.new("Texture")
	t.Name = name
	t.Texture = ShopBuilder.TEXTURES[name]
	t.Face = face
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	if tint then
		t.Color3 = tint
	end
	t.Parent = p
end

local function block(className: string, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance, collide: boolean): BasePart
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

-- Brick body with textured back and ends.
local function body(cframe: CFrame, depth: number, wallH: number, length: number, color: Color3, side: string, tint: Color3?, model: Model): BasePart
	local b = block("Part", "Body", Vector3.new(depth, wallH, length), cframe * CFrame.new(0, wallH / 2, 0), color, Enum.Material.Brick, model, true)
	texture(b, Enum.NormalId.Right, side, BRICK_TILE, BRICK_TILE, tint)
	texture(b, Enum.NormalId.Front, side, BRICK_TILE, BRICK_TILE, tint)
	texture(b, Enum.NormalId.Back, side, BRICK_TILE, BRICK_TILE, tint)
	model.PrimaryPart = b
	return b
end

-- Stone coping round a flat roof: overhangs every wall (and the facade parts) by EAVE.
local function coping(cframe: CFrame, depth: number, wallH: number, length: number, color: Color3, model: Model)
	local extra = 2 * (EAVE + FACADE_T)
	block("Part", "Coping", Vector3.new(depth + extra, 1.6, length + extra), cframe * CFrame.new(0, wallH + 0.4, 0), color, Enum.Material.Concrete, model, true)
end

local function stack(cframe: CFrame, x: number, y0: number, h: number, z: number, color: Color3, model: Model)
	block("Part", "Stack", Vector3.new(2.2, h, 4.4), cframe * CFrame.new(x, y0 + h / 2, z), color, Enum.Material.Brick, model, true)
end

-- Two slate wedges meeting over the middle of the body (as TerraceBuilder.row).
local function pitchedRoof(cframe: CFrame, depth: number, wallH: number, roofH: number, length: number, model: Model)
	local half = depth / 2 + EAVE + FACADE_T
	for _, side in { -1, 1 } do
		local yaw = if side < 0 then math.pi / 2 else -math.pi / 2
		local cf = cframe * CFrame.new(side * half / 2, wallH + roofH / 2, 0) * CFrame.Angles(0, yaw, 0)
		local w = block("WedgePart", if side < 0 then "RoofFront" else "RoofBack", Vector3.new(length + 2 * EAVE, roofH, half), cf, SLATE, Enum.Material.Slate, model, true)
		texture(w, Enum.NormalId.Top, "slate", 12, 12)
	end
end

-- A row of shops (kind = the layout block's use). `district` picks the corner shop's name.
function ShopBuilder.shopRow(cframe: CFrame, length: number, depth: number, height: number, parent: Instance, rng: Random?, kind: string?, district: string?): Model
	local r = rng or Random.new()
	local k = kind or "shops"
	local brick = BRICKS[r:NextInteger(1, #BRICKS)]
	local floors, wallH, roofH = ShopBuilder.storeys(height)
	local g = ShopBuilder.GROUND_FLOOR

	local model = Instance.new("Model")
	model.Name = "ShopRow"
	model:SetAttribute("Kind", k)

	local b = body(cframe, depth, wallH, length, brick.body, brick.side, brick.tint, model)
	local frontX = -depth / 2 - FACADE_T / 2

	-- ground floor: one thin facade part per bay
	local bays = ShopBuilder.bays(length, k)
	local ordinary = 0
	for _, bay in bays do
		if not bay.wide then
			ordinary += 1
		end
	end
	local fronts = ShopBuilder.frontsFor(k, ordinary, r, district)
	local used: { string } = {}
	local nextFront = 1
	for i, bay in bays do
		local key: string
		if bay.wide then
			key = "shop_front_supermarket"
		else
			key = fronts[nextFront]
			nextFront += 1
		end
		table.insert(used, key)
		local p = block("Part", "Shopfront" .. i, Vector3.new(FACADE_T, g, bay.width), cframe * CFrame.new(frontX, g / 2, bay.centre), FASCIA[key], Enum.Material.SmoothPlastic, model, true)
		p:SetAttribute("Front", key)
		texture(p, Enum.NormalId.Left, key, bay.width, g)
	end
	model:SetAttribute("Fronts", table.concat(used, ","))

	-- upper storeys: one facade part, a window tile per ordinary bay width
	local upperH = wallH - g
	if floors >= 1 then
		local u = length / ShopBuilder.bayCount(length)
		local p = block("Part", "Upper", Vector3.new(FACADE_T, upperH, length), cframe * CFrame.new(frontX, g + upperH / 2, 0), brick.body, Enum.Material.Brick, model, true)
		texture(p, Enum.NormalId.Left, brick.upper, u, 2 * upperH / floors)
	else
		-- a single-storey building: the strip above the fascia is plain brick
		texture(b, Enum.NormalId.Left, brick.side, BRICK_TILE, BRICK_TILE, brick.tint)
	end

	-- roof and one chimney stack on the party wall nearest the middle
	local stackColor = brick.body:Lerp(Color3.new(0, 0, 0), 0.12)
	local n = #bays
	local stackZ = if n >= 2 then bays[math.floor(n / 2)].centre + bays[math.floor(n / 2)].width / 2 else 0
	if roofH > 0 then
		pitchedRoof(cframe, depth, wallH, roofH, length, model)
		stack(cframe, 0, wallH + roofH - 2.5, 5.5, stackZ, stackColor, model)
	else
		coping(cframe, depth, wallH, length, COPING, model)
		if floors >= 1 then
			stack(cframe, depth / 4, wallH + 1, 4.5, stackZ, stackColor, model)
		end
	end

	model.Parent = parent
	return model
end

-- A block of flats. size = (depth, height, length) in the frame's local axes. 3 parts.
function ShopBuilder.flats(cframe: CFrame, size: Vector3, parent: Instance): Model
	local depth, wallH, length = size.X, size.Y, size.Z
	local model = Instance.new("Model")
	model.Name = "Flats"
	local b = body(cframe, depth, wallH, length, FLATS_BRICK, "brick", FLATS_TINT, model)
	-- the facade replaces the back's plain brick: flats have windows front and back
	for _, t in b:GetChildren() do
		if t:IsA("Texture") and t.Face == Enum.NormalId.Right then
			t:Destroy()
		end
	end
	texture(b, Enum.NormalId.Left, "flats_facade", 24, wallH)
	texture(b, Enum.NormalId.Right, "flats_facade", 24, wallH)
	coping(cframe, depth, wallH, length, Color3.fromRGB(198, 194, 184), model)
	stack(cframe, depth / 4, wallH + 1, 4.5, 0, FLATS_BRICK:Lerp(Color3.new(0, 0, 0), 0.12), model)
	model.Parent = parent
	return model
end

-- A town hall / school: pale stone, a portico with a pediment and a doorway
-- on the front. size = (depth, height, length) in local axes. 6 parts.
function ShopBuilder.civic(cframe: CFrame, size: Vector3, parent: Instance): Model
	local depth, wallH, length = size.X, size.Y, size.Z
	local model = Instance.new("Model")
	model.Name = "Civic"
	local b = block("Part", "Body", Vector3.new(depth, wallH, length), cframe * CFrame.new(0, wallH / 2, 0), CIVIC_STONE, Enum.Material.Limestone, model, true)
	model.PrimaryPart = b
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back } do
		texture(b, face, "civic_facade", 16, wallH)
	end
	coping(cframe, depth, wallH, length, Color3.fromRGB(228, 222, 206), model)

	local porticoW = math.min(28, length * 0.4)
	local porticoD = 4
	local porticoH = math.min(wallH - 8, 20)
	local px = -depth / 2 - porticoD / 2
	local stone = Color3.fromRGB(232, 226, 210)
	block("Part", "Portico", Vector3.new(porticoD, porticoH, porticoW), cframe * CFrame.new(px, porticoH / 2, 0), stone, Enum.Material.Limestone, model, true)
	-- pediment: two wedges, each rising toward the middle (a wedge's high Back face is at local +Z)
	local pedH = 6
	for _, side in { -1, 1 } do
		local cf = cframe * CFrame.new(px, porticoH + pedH / 2, side * porticoW / 4) * (if side < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0))
		block("WedgePart", "Pediment", Vector3.new(porticoD, pedH, porticoW / 2), cf, stone, Enum.Material.Limestone, model, true)
	end
	local door = block("Part", "Doorway", Vector3.new(0.2, 10, 7), cframe * CFrame.new(px - porticoD / 2 - 0.1, 5, 0), Color3.fromRGB(46, 36, 30), Enum.Material.Wood, model, false)
	door.CastShadow = false
	model.Parent = parent
	return model
end

return ShopBuilder
