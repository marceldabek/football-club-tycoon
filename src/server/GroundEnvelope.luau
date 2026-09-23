--!strict
-- The ground's fixed envelope (docs/superpowers/specs/2026-09-22-ground-plan-design.md
-- s2, playtest #15): one perimeter wall round the stands and concourse, the same
-- at every tier, with the ways in and out set into it. Inside the wall is the
-- ticketed ground; the car park, club shop and street side are public.
--
-- Pitch-local studs like PlotGrounds (origin pitch centre, +X east, -X the
-- street, -Z north). PlotGrounds.build calls GroundEnvelope.build before it
-- moves the whole Grounds model into the plot.
--
--   thing                 where
--   perimeter wall        lines x -201 / 201, z -259 / 259 (WALL_T thick, centred)
--   main entrance gate    west wall, z -16..16   (players, staff, owner, directors)
--   NW turnstile block    west wall, z -200..-175
--   SW turnstile block    west wall, z 175..200
--   north exit gate       north wall, x -20..20
--   east exit gate        east wall, z -20..20
--   service gate          south wall, x 176..192 (tractor, ambulance; kept shut)
--
-- The open gates' leaves fold back flat against the wall's outer face, so the
-- opening stays clear and nothing lies on the paving inside.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ClubCrest = require(ReplicatedStorage.Shared.ClubCrest)
local PlotContext = require(script.Parent.PlotContext)

local function crest(): ClubCrest.Spec
	return ClubCrest.forFolder(PlotContext.findStateFolder())
end
local function clubPaint<T>(inst: T, role: string?, darken: number?): T
	return ClubCrest.paint(inst, crest(), role or "kit", darken)
end

local GroundEnvelope = {}

-- ------------------------------------------------------------------ layout

GroundEnvelope.X0, GroundEnvelope.X1 = -201, 201
GroundEnvelope.Z0, GroundEnvelope.Z1 = -259, 259
GroundEnvelope.WALL_T = 1.2
GroundEnvelope.WALL_H = 8 -- TEMP: about 2.9 m, over a character's jump
GroundEnvelope.PIER_W = 2.4 -- square gate piers, proud of both faces

export type Side = "N" | "S" | "E" | "W"
-- `a0..a1` is the opening along the wall (z on the west/east walls, x on the
-- north/south ones). `kind`: "open" (leaves folded back), "shut", or "block"
-- (a turnstile block fills it; no piers).
export type Gate = { name: string, side: Side, a0: number, a1: number, kind: string, sign: string? }

GroundEnvelope.GATES = {
	{ name = "MainGate", side = "W", a0 = -16, a1 = 16, kind = "open", sign = "MAIN ENTRANCE" },
	{ name = "NWTurnstiles", side = "W", a0 = -200, a1 = -175, kind = "block" },
	{ name = "SWTurnstiles", side = "W", a0 = 175, a1 = 200, kind = "block" },
	{ name = "NorthExit", side = "N", a0 = -20, a1 = 20, kind = "open", sign = "EXIT" },
	{ name = "EastExit", side = "E", a0 = -20, a1 = 20, kind = "open", sign = "EXIT" },
	{ name = "ServiceGate", side = "S", a0 = 176, a1 = 192, kind = "shut", sign = "SERVICE GATE - KEEP CLEAR" },
} :: { Gate }

export type Rect = { name: string, x0: number, x1: number, z0: number, z1: number }

-- The line a side's wall is centred on, and how far its runs reach along it.
-- North and south run the full width; west and east fit between them.
local function sideLine(side: Side): (number, number, number)
	local E = GroundEnvelope
	local t = E.WALL_T / 2
	if side == "N" then
		return E.Z0, E.X0 - t, E.X1 + t
	elseif side == "S" then
		return E.Z1, E.X0 - t, E.X1 + t
	elseif side == "W" then
		return E.X0, E.Z0 + t, E.Z1 - t
	end
	return E.X1, E.Z0 + t, E.Z1 - t
end

-- A rectangle `a0..a1` along a side, `across` thick, centred on its line.
local function along(name: string, side: Side, a0: number, a1: number, across: number): Rect
	local line = sideLine(side)
	if side == "N" or side == "S" then
		return { name = name, x0 = a0, x1 = a1, z0 = line - across / 2, z1 = line + across / 2 }
	end
	return { name = name, x0 = line - across / 2, x1 = line + across / 2, z0 = a0, z1 = a1 }
end

-- Wall runs and gate piers, pure. Runs stop at the piers (or at a block's
-- ends), so no two pieces share volume.
function GroundEnvelope.wallPieces(): ({ Rect }, { Rect })
	local E = GroundEnvelope
	local runs: { Rect } = {}
	local piers: { Rect } = {}
	for _, side in { "N", "S", "W", "E" } :: { Side } do
		local _, from, to = sideLine(side)
		local gaps = {}
		for _, g in E.GATES do
			if g.side == side then
				local pad = if g.kind == "block" then 0 else E.PIER_W
				table.insert(gaps, { g.a0 - pad, g.a1 + pad, g })
				if g.kind ~= "block" then
					table.insert(piers, along(g.name .. "Pier", side, g.a0 - E.PIER_W, g.a0, E.PIER_W))
					table.insert(piers, along(g.name .. "Pier", side, g.a1, g.a1 + E.PIER_W, E.PIER_W))
				end
			end
		end
		table.sort(gaps, function(a, b)
			return a[1] < b[1]
		end)
		local a = from
		for _, gap in gaps do
			if gap[1] > a then
				table.insert(runs, along("Wall" .. side, side, a, gap[1], E.WALL_T))
			end
			a = gap[2]
		end
		if to > a then
			table.insert(runs, along("Wall" .. side, side, a, to, E.WALL_T))
		end
	end
	return runs, piers
end

-- Everything the envelope puts on the ground, for PlotGrounds.plantingKeepOut:
-- the walled ground itself (with its wall) and a clear apron outside every
-- gate, so no tree grows across a way in.
function GroundEnvelope.keepOut(): { { name: string, x0: number, x1: number, z0: number, z1: number, solid: boolean } }
	local E = GroundEnvelope
	local t = E.WALL_T / 2 + E.PIER_W
	local out = {
		{ name = "Ground", x0 = E.X0 - t, x1 = E.X1 + t, z0 = E.Z0 - t, z1 = E.Z1 + t, solid = true },
	}
	for _, g in E.GATES do
		-- the leaves fold back along the outside of the wall, a gate's width each side
		local w = g.a1 - g.a0
		local r = along(g.name .. "Apron", g.side, g.a0 - w / 2 - E.PIER_W, g.a1 + w / 2 + E.PIER_W, 2 * 12)
		table.insert(out, { name = r.name, x0 = r.x0, x1 = r.x1, z0 = r.z0, z1 = r.z1, solid = false })
	end
	-- the huts outside the wall, and the turnstile blocks' lamp posts
	for _, hut in E.HUTS do
		if hut.x1 < E.X0 then
			table.insert(out, { name = hut.name, x0 = hut.x0 - 1, x1 = hut.x1 + 1, z0 = hut.z0 - 1, z1 = hut.z1 + 1, solid = true })
		end
	end
	for _, z in { -204, 204 } do
		table.insert(out, { name = "TurnstileLamp", x0 = -211, x1 = -207, z0 = z - 5, z1 = z + 5, solid = true })
	end
	return out
end

-- ------------------------------------------------------------------- build

local BRICK = Color3.fromRGB(150, 82, 62) -- PlotGrounds' boundary brick
local PIER = Color3.fromRGB(128, 70, 54)
local COPING = Color3.fromRGB(206, 196, 176)
local IRON = Color3.fromRGB(28, 30, 32)
local COPING_H, COPING_OUT = 0.5, 0.2

local function extents(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number,
	color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = name
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function sign(target: BasePart, face: Enum.NormalId, text: string, textColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.25 -- X270: still reads at an evening fixture
	gui.MaxDistance = 260
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(0.92, 0.72)
	label.Position = UDim2.fromScale(0.04, 0.14)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return label
end

-- One iron leaf from `a0` to `a1` along a side, standing `off` out from the
-- wall's centre line: two rails and uprights. `solid` leaves (a shut gate) get
-- an invisible collider so nobody squeezes between the bars.
local function leaf(parent: Instance, side: Side, a0: number, a1: number, off: number, h: number, solid: boolean)
	local line = sideLine(side)
	local c = line + (if side == "N" or side == "W" then -off else off)
	local function bar(name: string, b0: number, b1: number, y0: number, y1: number, thick: number)
		local r = along(name, side, b0, b1, thick)
		local p
		if side == "N" or side == "S" then
			p = extents(name, r.x0, r.x1, y0, y1, c - thick / 2, c + thick / 2, IRON, Enum.Material.Metal, parent)
		else
			p = extents(name, c - thick / 2, c + thick / 2, y0, y1, r.z0, r.z1, IRON, Enum.Material.Metal, parent)
		end
		p.CanCollide = solid
		p.CastShadow = false
		return p
	end
	bar("GateRail", a0, a1, 0.4, 0.65, 0.2)
	bar("GateRail", a0, a1, h - 0.25, h, 0.2)
	local count = math.max(2, math.floor((a1 - a0) / 2))
	local step = (a1 - a0) / count
	for i = 0, count do
		local a = math.clamp(a0 + i * step, a0 + 0.08, a1 - 0.08)
		bar("GateBar", a - 0.08, a + 0.08, 0.65, h - 0.25, 0.15)
	end
	if solid then
		local r = along("GateCollider", side, a0, a1, 0.4)
		local collider = extents("GateCollider", r.x0, r.x1, 0, h, r.z0, r.z1, IRON, Enum.Material.Metal, parent)
		collider.Transparency = 1
		collider.CastShadow = false
	end
end

local function buildWall(parent: Instance)
	local E = GroundEnvelope
	local wall = Instance.new("Model")
	wall.Name = "PerimeterWall"
	wall.Parent = parent
	local runs, piers = E.wallPieces()
	local h = E.WALL_H
	for _, r in runs do
		extents(r.name, r.x0, r.x1, 0, h, r.z0, r.z1, BRICK, Enum.Material.Brick, wall)
		-- coping overhangs both faces, not the run's ends (PlotGrounds X255)
		local acrossZ = r.name == "WallN" or r.name == "WallS"
		local ox = if acrossZ then 0 else COPING_OUT
		local oz = if acrossZ then COPING_OUT else 0
		extents("Coping", r.x0 - ox, r.x1 + ox, h, h + COPING_H, r.z0 - oz, r.z1 + oz, COPING, Enum.Material.Concrete, wall)
	end
	local pierH = h + 1.5
	for _, p in piers do
		extents("GatePier", p.x0, p.x1, 0, pierH, p.z0, p.z1, PIER, Enum.Material.Brick, wall)
		extents("PierCap", p.x0 - COPING_OUT, p.x1 + COPING_OUT, pierH, pierH + COPING_H, p.z0 - COPING_OUT, p.z1 + COPING_OUT,
			COPING, Enum.Material.Concrete, wall)
	end

	-- gate leaves and signs
	local signDark = Config.HomeKit:Lerp(Color3.new(0, 0, 0), 0.45) -- repainted: clubPaint(x, "kit", 0.45)
	for _, g in E.GATES do
		if g.kind == "block" then
			continue
		end
		local gate = Instance.new("Model")
		gate.Name = g.name
		gate.Parent = wall
		local mid = (g.a0 + g.a1) / 2
		local leafH = h - 1
		if g.kind == "open" then
			-- folded back flat against the outside face, hinged at each pier
			local w = (g.a1 - g.a0) / 2
			local off = E.WALL_T / 2 + E.PIER_W / 2 + 0.3
			leaf(gate, g.side, g.a0 - E.PIER_W - w, g.a0 - E.PIER_W, off, leafH, false)
			leaf(gate, g.side, g.a1 + E.PIER_W, g.a1 + E.PIER_W + w, off, leafH, false)
		else
			leaf(gate, g.side, g.a0, mid, 0, leafH, true)
			leaf(gate, g.side, mid, g.a1, 0, leafH, true)
		end
		if g.sign then
			-- a board across the top of the opening, on the piers' caps: both faces
			local y0 = h + 1.5 + COPING_H
			local r = along("GateSign", g.side, g.a0 - E.PIER_W, g.a1 + E.PIER_W, 0.4)
			local board = clubPaint(extents("GateSign", r.x0, r.x1, y0, y0 + 2.2, r.z0, r.z1, signDark, Enum.Material.SmoothPlastic, gate), "kit", 0.45)
			local faces = if g.side == "N" or g.side == "S"
				then { Enum.NormalId.Front, Enum.NormalId.Back }
				else { Enum.NormalId.Left, Enum.NormalId.Right }
			for _, face in faces do
				sign(board, face, g.sign)
			end
		end
	end
end

-- ---------------------------------------------------------- turnstile blocks
--
-- #15/#14: a brick block straddling the west wall at each end of the ground,
-- in the style of the old corner turnstiles (RivermereTurnstileEntrance.png:
-- brick piers, a club-colour fascia with the name and crest, slogan plaques,
-- a lamp post flying a banner). Six lane slots and an exit gate at the end
-- nearer halfway; the slots nearest the approach path open first, the rest
-- have their shutters down until the ground tier opens them (spec s2, free).
GroundEnvelope.BLOCK_D = 8 -- across the wall, centred on it
GroundEnvelope.BLOCK_APRON = 4 -- concrete threshold either side of the block
GroundEnvelope.LANE_SLOTS = 6
local END_PIER, DIVIDER, EXIT_W = 1.2, 0.8, 4.4
local BLOCK_OPEN_H, BLOCK_H = 8, 11

export type Slot = { z0: number, z1: number, kind: string, number: number? }

-- The block's lane slots and exit, pure. `approachZ` is the centre line of the
-- path the fans walk up; the lanes nearest it open first.
function GroundEnvelope.blockSlots(g: Gate, approachZ: number, lanes: number): { Slot }
	local zi0, zi1 = g.a0 + END_PIER, g.a1 - END_PIER
	local laneW = ((zi1 - zi0) - EXIT_W - DIVIDER * GroundEnvelope.LANE_SLOTS) / GroundEnvelope.LANE_SLOTS
	-- the exit is at the end nearer halfway (z = 0)
	local exitHigh = math.abs(g.a1) < math.abs(g.a0)
	local slots: { Slot } = {}
	local z = if exitHigh then zi0 else zi1
	local dir = if exitHigh then 1 else -1
	for _ = 1, GroundEnvelope.LANE_SLOTS do
		local a, b = z, z + dir * laneW
		table.insert(slots, { z0 = math.min(a, b), z1 = math.max(a, b), kind = "shut" })
		z = b + dir * DIVIDER
	end
	local a, b = z, z + dir * EXIT_W
	local order = table.clone(slots)
	table.sort(order, function(p, q)
		return math.abs((p.z0 + p.z1) / 2 - approachZ) < math.abs((q.z0 + q.z1) / 2 - approachZ)
	end)
	for i = 1, math.min(lanes, #order) do
		order[i].kind = "lane"
	end
	-- numbered along the block, north to south
	table.sort(slots, function(p, q)
		return p.z0 < q.z0
	end)
	for i, slot in slots do
		slot.number = i
	end
	table.insert(slots, { z0 = math.min(a, b), z1 = math.max(a, b), kind = "exit" })
	return slots
end

-- the paths the fans walk up to each block (PlotGrounds / MatchdayRoutes)
GroundEnvelope.APPROACH_Z = { NWTurnstiles = -187, SWTurnstiles = 187 }
GroundEnvelope.SLOGANS = { "PRIDE\nPEOPLE\nRIVERMERE", "MATCH DAYS\nBRING PEOPLE\nTOGETHER" }

function GroundEnvelope.gate(name: string): Gate
	for _, g in GroundEnvelope.GATES do
		if g.name == name then
			return g
		end
	end
	error("no gate " .. name)
end

local function clubName(): string
	local state = PlotContext.findStateFolder()
	local name = state and state:GetAttribute("ClubName")
	return string.upper(if type(name) == "string" then name else Config.ClubName)
end

local function buildLamp(parent: Instance, x: number, z: number, banner: number)
	local black = Color3.fromRGB(24, 26, 30)
	extents("LampBase", x - 0.6, x + 0.6, 0, 1.2, z - 0.6, z + 0.6, black, Enum.Material.Metal, parent)
	extents("LampPost", x - 0.25, x + 0.25, 1.2, 16.6, z - 0.25, z + 0.25, black, Enum.Material.Metal, parent)
	extents("Lantern", x - 0.5, x + 0.5, 16.6, 18.2, z - 0.5, z + 0.5, Color3.fromRGB(250, 236, 196), Enum.Material.Glass, parent)
	extents("LanternCap", x - 0.7, x + 0.7, 18.2, 18.6, z - 0.7, z + 0.7, black, Enum.Material.Metal, parent)
	-- the arm reaches away from the block so the banner hangs clear of the post
	local armEnd = z + banner * 3.85
	extents("BannerArm", x - 0.125, x + 0.125, 14.3, 14.55, math.min(z, armEnd), math.max(z, armEnd), black, Enum.Material.Metal, parent).CanCollide = false
	local bz = z + banner * 2.3
	local flag = clubPaint(extents("LampBanner", x - 0.075, x + 0.075, 7.3, 14.3, bz - 1.5, bz + 1.5, Config.HomeKit, Enum.Material.Fabric, parent))
	flag.CanCollide = false
	flag.CastShadow = false
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.25
		gui.Parent = flag
		local name = Instance.new("TextLabel")
		name.Name = "ClubName" -- WorldBuilder.setClubName repaints it
		name.Size = UDim2.fromScale(0.86, 0.3)
		name.Position = UDim2.fromScale(0.07, 0.06)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBlack
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = clubName()
		name.Parent = gui
		local motto = Instance.new("TextLabel")
		motto.Name = "Motto"
		motto.Size = UDim2.fromScale(0.8, 0.26)
		motto.Position = UDim2.fromScale(0.1, 0.62)
		motto.BackgroundTransparency = 1
		motto.Font = Enum.Font.GothamBold
		motto.TextScaled = true
		motto.TextColor3 = Color3.new(1, 1, 1)
		motto.Text = "OUR TOWN\nOUR GAME"
		motto.Parent = gui
		ClubCrest.badge(gui, crest(), UDim2.fromScale(0.5, 0.21), UDim2.fromScale(0.5, 0.49))
	end
end

local function buildBlock(parent: Instance, g: Gate, lanes: number)
	local E = GroundEnvelope
	local block = Instance.new("Model")
	block.Name = g.name
	block.Parent = parent
	local bx0, bx1 = E.X0 - E.BLOCK_D / 2, E.X0 + E.BLOCK_D / 2
	local zi0, zi1 = g.a0 + END_PIER, g.a1 - END_PIER
	local signDark = Config.HomeKit:Lerp(Color3.new(0, 0, 0), 0.45) -- repainted: clubPaint(x, "kit", 0.45)
	local slots = E.blockSlots(g, E.APPROACH_Z[g.name] or (g.a0 + g.a1) / 2, lanes)
	block:SetAttribute("Lanes", lanes)

	-- the concrete threshold the lanes stand on, level with the paths
	extents("Threshold", bx0 - E.BLOCK_APRON, bx1 + E.BLOCK_APRON, 0, 0.34, zi0, zi1, Color3.fromRGB(150, 148, 142), Enum.Material.Concrete, block)
	for _, z in { { g.a0, zi0 }, { zi1, g.a1 } } do
		extents("EndPier", bx0, bx1, 0, BLOCK_H, z[1], z[2], PIER, Enum.Material.Brick, block)
	end
	extents("Lintel", bx0, bx1, BLOCK_OPEN_H, BLOCK_H, zi0, zi1, BRICK, Enum.Material.Brick, block)
	extents("Roof", bx0 - 1, bx1 + 1, BLOCK_H, BLOCK_H + 0.5, g.a0 - 0.5, g.a1 + 0.5, Color3.fromRGB(60, 60, 65), Enum.Material.Metal, block)
	-- dividers between the slots
	table.sort(slots, function(p, q)
		return p.z0 < q.z0
	end)
	for i = 1, #slots - 1 do
		extents("Divider", bx0, bx1, 0.34, BLOCK_OPEN_H, slots[i].z1, slots[i + 1].z0, BRICK, Enum.Material.Brick, block)
	end
	for _, slot in slots do
		if slot.kind == "lane" then
			-- a waist-high drum on one side of the lane and its arm across it
			local drum = extents("Drum", E.X0 - 0.4, E.X0 + 0.4, 0.34, 3.5, slot.z0 + 0.05, slot.z0 + 0.75, Color3.fromRGB(150, 150, 155), Enum.Material.Metal, block)
			drum.CanCollide = false
			local arm = extents("Arm", E.X0 - 0.06, E.X0 + 0.06, 3.0, 3.12, slot.z0 + 0.75, slot.z1 - 0.1, Color3.fromRGB(190, 190, 195), Enum.Material.Metal, block)
			arm.CanCollide = false
		elseif slot.kind == "shut" then
			extents("Shutter", bx0 - 0.2, bx0, 0.34, BLOCK_OPEN_H, slot.z0, slot.z1, Color3.fromRGB(96, 98, 104), Enum.Material.DiamondPlate, block)
		end
	end

	-- the fascia over the lanes: the club's name between two crests, and a strip
	-- of lane numbers under it (closed lanes blank, the exit marked)
	local fascia = clubPaint(extents("Fascia", bx0 - 0.4, bx0, BLOCK_OPEN_H + 0.2, BLOCK_H - 0.2, zi0, zi1, Config.HomeKit, Enum.Material.SmoothPlastic, block))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- -X, the street side; GUI +x runs along +Z
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.25
	gui.Parent = fascia
	local label = Instance.new("TextLabel")
	label.Name = "ClubName"
	label.Size = UDim2.new(1, -110, 0.6, 0)
	label.Position = UDim2.new(0, 55, 0.04, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = clubName()
	label.Parent = gui
	for _, anchorX in { 0, 1 } do
		ClubCrest.badge(gui, crest(), UDim2.fromOffset(40, 40), UDim2.new(anchorX, if anchorX == 0 then 8 else -8, 0.34, 0), Vector2.new(anchorX, 0.5))
	end
	local span = zi1 - zi0
	for _, slot in slots do
		local cell = Instance.new("TextLabel")
		cell.Name = "Lane"
		cell.AnchorPoint = Vector2.new(0.5, 0)
		cell.Position = UDim2.fromScale(((slot.z0 + slot.z1) / 2 - zi0) / span, 0.66)
		cell.Size = UDim2.fromScale((slot.z1 - slot.z0) / span * 0.9, 0.3)
		cell.BackgroundTransparency = 1
		cell.Font = Enum.Font.GothamBold
		cell.TextScaled = true
		cell.TextColor3 = Color3.fromRGB(240, 240, 240)
		cell.Text = if slot.kind == "lane" then tostring(slot.number) elseif slot.kind == "exit" then "EXIT ONLY" else ""
		cell.Parent = gui
	end
	-- and "EXIT" over the way out on the ground side
	local exitSlot = if slots[1].kind == "exit" then slots[1] else slots[#slots]
	local exitSign = clubPaint(extents("ExitSign", bx1, bx1 + 0.2, BLOCK_OPEN_H + 0.3, BLOCK_OPEN_H + 2, exitSlot.z0, exitSlot.z1, signDark, Enum.Material.SmoothPlastic, block), "kit", 0.45)
	sign(exitSign, Enum.NormalId.Right, "EXIT")

	-- slogan plaques on the street-side end faces of the end piers (X84)
	for i, slogan in E.SLOGANS do
		local z = if i == 1 then g.a0 else g.a1
		local out = if i == 1 then -1 else 1
		local plaque = clubPaint(extents("Plaque", bx0 + 0.1, bx0 + 3.1, 3, 6.4, math.min(z, z + out * 0.15), math.max(z, z + out * 0.15), signDark, Enum.Material.SmoothPlastic, block), "kit", 0.45)
		plaque.CanCollide = false
		local pg = Instance.new("SurfaceGui")
		pg.Face = if out < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		pg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		pg.PixelsPerStud = 50
		pg.Parent = plaque
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.86, 0.6)
		t.Position = UDim2.fromScale(0.07, 0.06)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(240, 240, 240)
		t.Text = slogan
		t.Parent = pg
		ClubCrest.badge(pg, crest(), UDim2.fromScale(0.5, 0.26), UDim2.fromScale(0.5, 0.68), Vector2.new(0.5, 0))
	end
	-- a lamp post outside the far end, flying the club banner (X53)
	local farZ = if math.abs(g.a0) > math.abs(g.a1) then g.a0 - 4 else g.a1 + 4
	buildLamp(block, bx0 - 4, farZ, if farZ < 0 then -1 else 1)
end

-- ------------------------------------------------------------------- huts
--
-- The small buildings the spec (s2) fixes round the envelope: ticket offices
-- and programme huts outside each turnstile block, the stewards' control hut
-- and first aid inside the north-west corner, the groundsman's shed in his
-- compound by the service gate, and (from ground tier 2) toilet blocks round
-- the concourse. `face` is the side with the window, door and sign: N = -Z,
-- S = +Z, E = +X, W = -X. Primitive boxes, ~5 parts each.
export type Hut = { name: string, x0: number, x1: number, z0: number, z1: number, h: number, face: string, sign: string, style: string }

GroundEnvelope.HUTS = {
	{ name = "TicketOfficeNW", x0 = -223, x1 = -207, z0 = -228, z1 = -212, h = 10, face = "S", sign = "TICKET OFFICE", style = "brick" },
	{ name = "TicketOfficeSW", x0 = -223, x1 = -207, z0 = 212, z1 = 228, h = 10, face = "N", sign = "TICKET OFFICE", style = "brick" },
	{ name = "ProgrammesNW", x0 = -217, x1 = -207, z0 = -165, z1 = -157, h = 8, face = "N", sign = "PROGRAMMES", style = "timber" },
	{ name = "ProgrammesSW", x0 = -217, x1 = -207, z0 = 157, z1 = 165, h = 8, face = "S", sign = "PROGRAMMES", style = "timber" },
	{ name = "Stewards", x0 = -197, x1 = -183, z0 = -224, z1 = -212, h = 9, face = "E", sign = "STEWARDS - CONTROL", style = "cabin" },
	{ name = "FirstAid", x0 = -197, x1 = -183, z0 = -248, z1 = -236, h = 9, face = "E", sign = "+ FIRST AID", style = "firstaid" },
	{ name = "GroundsmansShed", x0 = 175, x1 = 191, z0 = 236, z1 = 246, h = 9, face = "N", sign = "GROUNDSMAN", style = "timber" },
} :: { Hut }

-- 18 x 12 toilet blocks from ground tier 2 (Config.ToiletsFromTier), facing the pitch
GroundEnvelope.TOILETS = {
	{ x = 186, z = -222, face = "W" },
	{ x = -170, z = 250, face = "N" },
	{ x = 60, z = 250, face = "N" },
	{ x = -60, z = -250, face = "S" },
}

-- the groundsman's compound in the south-east corner: gravel inside a mesh
-- fence, the service gate in the ground wall at its back
GroundEnvelope.COMPOUND = { x0 = 172, x1 = 199, z0 = 232, z1 = 257 }

function GroundEnvelope.toiletHut(i: number): Hut
	local t = GroundEnvelope.TOILETS[i]
	return { name = "Toilets", x0 = t.x - 9, x1 = t.x + 9, z0 = t.z - 6, z1 = t.z + 6, h = 9, face = t.face, sign = "TOILETS", style = "brick" }
end

local HUT_STYLE = {
	brick = { wall = BRICK, material = Enum.Material.Brick, roof = Color3.fromRGB(60, 62, 68) },
	timber = { wall = Color3.fromRGB(46, 84, 58), material = Enum.Material.WoodPlanks, roof = Color3.fromRGB(52, 54, 58) },
	cabin = { wall = Color3.fromRGB(214, 214, 206), material = Enum.Material.SmoothPlastic, roof = Color3.fromRGB(120, 122, 126) },
	firstaid = { wall = Color3.fromRGB(236, 236, 230), material = Enum.Material.SmoothPlastic, roof = Color3.fromRGB(120, 122, 126) },
}

-- A slab `t` thick on the outside of face `face` of the box, from `a0..a1`
-- along it (fractions of the face's width) and `y0..y1` up.
local function onFace(name: string, hut: Hut, f0: number, f1: number, y0: number, y1: number, t: number,
	color: Color3, material: Enum.Material, parent: Instance): Part
	if hut.face == "N" or hut.face == "S" then
		local a0, a1 = hut.x0 + (hut.x1 - hut.x0) * f0, hut.x0 + (hut.x1 - hut.x0) * f1
		local z0, z1 = if hut.face == "N" then hut.z0 - t else hut.z1, if hut.face == "N" then hut.z0 else hut.z1 + t
		return extents(name, a0, a1, y0, y1, z0, z1, color, material, parent)
	end
	local a0, a1 = hut.z0 + (hut.z1 - hut.z0) * f0, hut.z0 + (hut.z1 - hut.z0) * f1
	local x0, x1 = if hut.face == "W" then hut.x0 - t else hut.x1, if hut.face == "W" then hut.x0 else hut.x1 + t
	return extents(name, x0, x1, y0, y1, a0, a1, color, material, parent)
end

local FACE_NORMAL = { N = Enum.NormalId.Front, S = Enum.NormalId.Back, E = Enum.NormalId.Right, W = Enum.NormalId.Left }

local function buildHut(parent: Instance, hut: Hut)
	local style = HUT_STYLE[hut.style] or HUT_STYLE.brick
	local m = Instance.new("Model")
	m.Name = hut.name
	m.Parent = parent
	extents("Body", hut.x0, hut.x1, 0, hut.h, hut.z0, hut.z1, style.wall, style.material, m)
	extents("Roof", hut.x0 - 0.5, hut.x1 + 0.5, hut.h, hut.h + 0.4, hut.z0 - 0.5, hut.z1 + 0.5, style.roof, Enum.Material.Metal, m)
	local width = if hut.face == "N" or hut.face == "S" then hut.x1 - hut.x0 else hut.z1 - hut.z0
	local glass = Color3.fromRGB(40, 55, 70)
	if width >= 12 then
		-- a window and a door
		local window = onFace("Window", hut, 0.12, 0.55, 3, 6.2, 0.1, glass, Enum.Material.Glass, m)
		window.CastShadow = false
		onFace("Door", hut, 0.68, 0.68 + 3.2 / width, 0, 7, 0.1, Color3.fromRGB(58, 60, 66), Enum.Material.SmoothPlastic, m)
	else
		-- a serving hatch with its counter
		onFace("Hatch", hut, 0.2, 0.8, 3, 5.6, 0.1, glass, Enum.Material.Glass, m).CastShadow = false
		onFace("Counter", hut, 0.18, 0.82, 2.8, 3, 1, Color3.fromRGB(190, 186, 176), Enum.Material.Concrete, m)
	end
	local board = onFace("SignBoard", hut, 0.08, 0.92, hut.h - 1.9, hut.h - 0.3, 0.15, Color3.fromRGB(236, 232, 214), Enum.Material.SmoothPlastic, m)
	local text = if hut.style == "firstaid" then Color3.fromRGB(20, 130, 60) else Color3.fromRGB(40, 44, 52)
	sign(board, FACE_NORMAL[hut.face], hut.sign, text)
end

local function buildCompound(parent: Instance)
	local c = GroundEnvelope.COMPOUND
	local m = Instance.new("Model")
	m.Name = "GroundsmansCompound"
	m.Parent = parent
	local inner = GroundEnvelope.Z1 - GroundEnvelope.WALL_T / 2 -- the south wall's inside face
	local gravel = extents("Gravel", c.x0, c.x1, 0, 0.2, c.z0, inner, Color3.fromRGB(150, 140, 122), Enum.Material.Pebble, m)
	gravel.CastShadow = false
	-- mesh fence on three sides (the ground wall is the fourth). The shed stands
	-- square in front of the service gate, so the tractor goes round its east
	-- side: the gap out toward the pitch is at that end of the north fence.
	local mesh = Color3.fromRGB(40, 90, 50)
	local function panel(x0: number, x1: number, z0: number, z1: number)
		local p = extents("Fence", x0, x1, 0.2, 6, z0, z1, mesh, Enum.Material.Metal, m)
		p.Transparency = 0.45
		p.CastShadow = false
	end
	local shed = GroundEnvelope.HUTS[#GroundEnvelope.HUTS]
	panel(c.x0 - 0.1, c.x0 + 0.1, c.z0, inner)
	panel(c.x1 - 0.1, c.x1 + 0.1, c.z0, inner)
	panel(c.x0 - 0.1, shed.x1, c.z0 - 0.1, c.z0 + 0.1)
	-- a sit-on mower parked beside the shed, out of the tractor's way
	local green = Color3.fromRGB(46, 110, 60)
	extents("MowerBody", 172.3, 174.8, 0.2, 2.2, 249, 254, green, Enum.Material.SmoothPlastic, m)
	extents("MowerSeat", 172.8, 174.3, 2.2, 3.4, 252, 253.4, Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic, m)
end

-- -------------------------------------------------------------- tier fittings

-- The ground tier from the club's stand levels (Config.groundTier), 1 without a club.
local function currentTier(): number
	local state = PlotContext.findStateFolder()
	if not state then
		return 1
	end
	local levels: { [string]: number } = {}
	for _, plot in Config.StandPlots do
		levels[plot.key] = (state:GetAttribute("Stand_" .. plot.key) :: number?) or 0
	end
	return Config.groundTier(levels)
end

-- Everything that grows with the ground tier for free (spec s1.5). Rebuilt
-- whenever the tier changes.
local function buildTiered(envelope: Instance, tier: number, place: boolean)
	local old = envelope:FindFirstChild("TierFittings")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "TierFittings"
	local lanes = Config.TurnstileLanes[math.clamp(tier, 1, #Config.TurnstileLanes)]
	for _, name in { "NWTurnstiles", "SWTurnstiles" } do
		buildBlock(model, GroundEnvelope.gate(name), lanes)
	end
	if tier >= Config.ToiletsFromTier then
		for i in GroundEnvelope.TOILETS do
			buildHut(model, GroundEnvelope.toiletHut(i))
		end
	end
	envelope:SetAttribute("GroundTier", tier)
	if place then
		PlotContext.place(model)
	end
	model.Parent = envelope
end

local tierConnections: { RBXScriptConnection } = {}

local function bindTier(envelope: Instance)
	for _, c in tierConnections do
		c:Disconnect()
	end
	table.clear(tierConnections)
	local state = PlotContext.findStateFolder()
	if not state then
		return
	end
	local function refresh()
		if not envelope.Parent then
			return
		end
		local tier = currentTier()
		if envelope:GetAttribute("GroundTier") ~= tier then
			buildTiered(envelope, tier, true)
		end
	end
	for _, plot in Config.StandPlots do
		table.insert(tierConnections, state:GetAttributeChangedSignal("Stand_" .. plot.key):Connect(refresh))
	end
end

-- Builds the envelope in pitch-local coordinates under `grounds`; the caller
-- places the whole Grounds model into the plot afterwards.
function GroundEnvelope.build(grounds: Instance): Model
	local envelope = Instance.new("Model")
	envelope.Name = "GroundEnvelope"
	envelope.Parent = grounds
	buildWall(envelope)
	for _, hut in GroundEnvelope.HUTS do
		buildHut(envelope, hut)
	end
	buildCompound(envelope)
	buildTiered(envelope, currentTier(), false)
	bindTier(envelope)
	return envelope
end

return GroundEnvelope
