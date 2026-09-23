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

function GroundEnvelope.build(grounds: Instance): Model
	local envelope = Instance.new("Model")
	envelope.Name = "GroundEnvelope"
	envelope.Parent = grounds
	buildWall(envelope)
	return envelope
end

return GroundEnvelope
