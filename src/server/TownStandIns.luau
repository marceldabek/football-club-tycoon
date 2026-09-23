--!strict
-- #27: far-away stand-ins for the town's buildings. With StreamingEnabled a
-- client only streams the town near its character (StreamingTargetRadius), so
-- from a ground on the edge of Rivermere the far side of town was empty grass.
--
-- Roblox's own answer, setting Model.LevelOfDetail to StreamingMesh, can't reach this
-- town: the property is Plugin-capability only (a write from Main.server.luau
-- throws "lacking capability Plugin"; RunAll's MCP thread is elevated, so a
-- test there passes and proves nothing), and the streaming mesh is baked from
-- the saved place, while the town is built at server start. See
-- tests/TownStandInsTest.luau, which fails if any source writes the property.
--
-- So this pass builds the low-detail copy itself, once, after the town build:
-- for every Atomic building lot (HouseAssembler lots, TradeAssembler lots) a
-- wall block and a roof slab in plain Parts, in one Persistent model that
-- every client always has. The lot model and its blocks share a StandInId;
-- TownStandIns.client.luau hides a lot's blocks while the real lot is
-- streamed in, and shows them again when it streams out. Nothing is built for
-- lots with no building in them (the trade fronts' paving, forecourts).
--
-- Mobile: two plain anchored Parts per building (~1,600 in all), no
-- collision, queries, touch or shadows, SmoothPlastic, no textures.

local TownStandIns = {}

TownStandIns.MODEL_NAME = "StandIns"
TownStandIns.ATTRIBUTE = "StandInId"
-- The far terrain is drawn as a coarse stand-in a few studs below the real
-- ground (memory streaming-far-terrain-sinks), so a block that stopped at the
-- ground would float over it. Walls reach this far below the lowest wall.
TownStandIns.SINK = 10
-- A roof slab fills this share of the eaves-to-ridge height: a flat block the
-- full ridge height reads as a much taller house from the ground.
TownStandIns.ROOF_FILL = 0.6
-- A building with no separate roof pieces (the one-mesh MEH__House / Office
-- prefabs): its eaves and ridge as shares of its height.
TownStandIns.PREFAB_EAVES = 0.62
TownStandIns.PREFAB_RIDGE = 0.85

export type Palette = { wall: Color3, roof: Color3 }

-- TEMP colours, matched by eye to the kit at a distance (2026-09-23).
TownStandIns.PALETTES = {
	-- plain SmoothPlastic under the blue sky ambient reads cooler than the kit's
	-- brick, so these sit a little warmer than the textures' own average
	dark = { wall = Color3.fromRGB(76, 54, 48), roof = Color3.fromRGB(64, 62, 64) }, -- dark brick sheet
	buff = { wall = Color3.fromRGB(206, 188, 168), roof = Color3.fromRGB(118, 102, 94) }, -- buff/render sheet
	prefab = { wall = Color3.fromRGB(196, 180, 162), roof = Color3.fromRGB(100, 92, 88) }, -- MEH houses, shops, offices
	shed = { wall = Color3.fromRGB(150, 152, 150), roof = Color3.fromRGB(116, 118, 124) }, -- industrial units
} :: { [string]: Palette }

-- The two HOUSE__ masonry sheets, by their SurfaceAppearance's name. Not by
-- ColorMap: a game script can't read ColorMap (Plugin capability, the same
-- trap as LevelOfDetail; memory football-club-tycoon-town-v3).
TownStandIns.SHEET_PALETTE = {
	HouseBrick_ts1 = "dark",
	HouseBrick_ts3 = "buff",
} :: { [string]: string }

export type Role = "body" | "roof"

-- What a direct child of a lot model is, by its name; nil = not part of the
-- building's silhouette (trim, props, fences, garden walls, paving, signs).
function TownStandIns.classify(childName: string): Role?
	if string.find(childName, "__roof", 1, true) or string.sub(childName, 1, 10) == "MEH__Roof_" then
		return "roof"
	end
	if childName == "Core" or childName == "ShopfrontPub" or string.find(childName, "__masonry", 1, true) then
		return "body"
	end
	local prefix = string.sub(childName, 1, 10)
	if prefix == "MEH__House" or prefix == "MEH__Offic" then
		return "body"
	end
	if string.sub(childName, 1, 10) == "MEH__Wall_" and string.sub(childName, 1, 14) ~= "MEH__Wall_Low_" then
		return "body"
	end
	return nil
end

export type Block = { cframe: CFrame, size: Vector3, role: Role }

local function partsOf(inst: Instance, into: { BasePart })
	if inst:IsA("BasePart") then
		table.insert(into, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(into, d)
		end
	end
end

-- A yaw-only frame from the part's most nearly horizontal axis: kit meshes
-- come rotated about X as well, but every building piece is square to its lot.
local function yawFrame(p: BasePart): CFrame
	local cf = p.CFrame
	local best, bestY = cf.LookVector, math.huge
	for _, axis in { cf.RightVector, cf.LookVector, cf.UpVector } do
		if math.abs(axis.Y) < bestY then
			best, bestY = axis, math.abs(axis.Y)
		end
	end
	local flat = Vector3.new(best.X, 0, best.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(cf.Position, cf.Position + flat.Unit)
end

-- Min/max of the parts' corners in `frame`.
local function extents(frame: CFrame, parts: { BasePart }): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local h = p.Size / 2
		for _, s in { Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1) } do
			local q = frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(h * s))
			lo = lo:Min(q)
			hi = hi:Max(q)
		end
	end
	return lo, hi
end

local function box(frame: CFrame, lo: Vector3, hi: Vector3, role: Role): Block
	return { cframe = frame * CFrame.new((lo + hi) / 2), size = hi - lo, role = role }
end

-- The stand-in blocks for one lot model (empty when it holds no building),
-- plus the palette key. Walls reach TownStandIns.SINK below the lowest wall.
function TownStandIns.blocksFor(lot: Instance): ({ Block }, string)
	local body: { BasePart } = {}
	local roof: { BasePart } = {}
	local paletteKey = "prefab"
	for _, child in lot:GetChildren() do
		local role = TownStandIns.classify(child.Name)
		if role == "body" then
			partsOf(child, body)
		elseif role == "roof" then
			partsOf(child, roof)
		end
		if string.sub(child.Name, 1, 17) == "MEH__Wall_Garage_" then
			paletteKey = "shed"
		end
	end
	if #body == 0 then
		return {}, paletteKey
	end
	-- the biggest wall piece sets the frame
	local largest = body[1]
	for _, p in body do
		if p.Size.X * p.Size.Y * p.Size.Z > largest.Size.X * largest.Size.Y * largest.Size.Z then
			largest = p
		end
		if paletteKey == "prefab" then
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			local key = sa and TownStandIns.SHEET_PALETTE[sa.Name]
			if key then
				paletteKey = key
			end
		end
	end
	local frame = yawFrame(largest)
	local lo, hi = extents(frame, body)
	local height = hi.Y - lo.Y
	local eaves, ridge
	local roofLo, roofHi = lo, hi
	if #roof > 0 then
		roofLo, roofHi = extents(frame, roof)
		eaves = math.clamp(roofLo.Y, lo.Y + 1, hi.Y)
		ridge = math.max(roofHi.Y, eaves + 0.5)
	else
		eaves = lo.Y + height * TownStandIns.PREFAB_EAVES
		ridge = lo.Y + height * TownStandIns.PREFAB_RIDGE
	end
	local blocks = {
		box(frame, Vector3.new(lo.X, lo.Y - TownStandIns.SINK, lo.Z), Vector3.new(hi.X, eaves, hi.Z), "body"),
	}
	local slabTop = eaves + (ridge - eaves) * TownStandIns.ROOF_FILL
	if slabTop - eaves >= 0.5 then
		-- the roof pieces' footprint (eaves overhang) when there are any
		local fx0, fz0 = math.min(lo.X, roofLo.X), math.min(lo.Z, roofLo.Z)
		local fx1, fz1 = math.max(hi.X, roofHi.X), math.max(hi.Z, roofHi.Z)
		if #roof == 0 then
			fx0, fz0, fx1, fz1 = lo.X, lo.Z, hi.X, hi.Z
		end
		table.insert(blocks, box(frame, Vector3.new(fx0, eaves, fz0), Vector3.new(fx1, slabTop, fz1), "roof"))
	end
	return blocks, paletteKey
end

local function isLot(m: Instance): boolean
	return m:IsA("Model") and m.ModelStreamingMode == Enum.ModelStreamingMode.Atomic
end

-- Builds workspace.Town.StandIns (replacing an old one). Returns the model and
-- an `[FCT]` summary.
function TownStandIns.build(town: Instance): (Model, string)
	local old = town:FindFirstChild(TownStandIns.MODEL_NAME)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = TownStandIns.MODEL_NAME
	-- every client always has the whole low-detail town; it is hidden lot by lot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local nextId, parts, lots, failed = 0, 0, 0, 0
	for _, lot in town:GetDescendants() do
		if not isLot(lot) or lot:FindFirstAncestor(TownStandIns.MODEL_NAME) then
			continue
		end
		lots += 1
		-- one odd lot must never take the town build down with it
		local ok, blocks, paletteKey = pcall(TownStandIns.blocksFor, lot)
		if not ok then
			failed += 1
			warn(("[FCT] StandIns: skipped %s: %s"):format(lot:GetFullName(), tostring(blocks)))
			continue
		end
		if #blocks == 0 then
			continue
		end
		nextId += 1
		lot:SetAttribute(TownStandIns.ATTRIBUTE, nextId)
		local palette = TownStandIns.PALETTES[paletteKey]
		for _, b in blocks do
			local p = Instance.new("Part")
			p.Name = if b.role == "roof" then "StandInRoof" else "StandInWall"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Locked = true
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Color = if b.role == "roof" then palette.roof else palette.wall
			p.Size = b.size
			p.CFrame = b.cframe
			p:SetAttribute(TownStandIns.ATTRIBUTE, nextId)
			p.Parent = model
			parts += 1
		end
		if nextId % 200 == 0 then
			task.wait() -- the town build is long; keep each resume under Studio's script timeout
		end
	end
	model.Parent = town
	return model, ("StandIns: %d buildings of %d lots, %d parts, %d failed (#27)"):format(nextId, lots, parts, failed)
end

return TownStandIns
