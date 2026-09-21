--!strict
-- The grassroots clubhouse (docs/CLUBHOUSE_PLAN.md): one small building on the
-- west touchline holding the office, both dressing rooms, a lobby, the corridor
-- the teams walk out of and a kiosk/store room. It replaced three separately
-- clad boxes (office, 94-stud tunnel corridor, dressing rooms) whose only way
-- out was the tunnel mouth.
--
-- Three ways in and out: front double doors (west, car park side), the
-- players' door (east, onto the touchline) and the office side door (south).
--
-- Built in pitch-local coordinates like WorldBuilder (origin pitch centre,
-- +X east toward the pitch, -Z north); WorldBuilder.build moves it into the
-- plot with everything else.
--
--              WEST (x -157)   car park / footpath side
--   z -40        -16                        +16                 +40
--    +--[hatch]---+----====[1] FRONT====-----+----[window]-------+
--    |            D4        LOBBY            D3          (spawn) [3] SIDE DOOR
--    |  KIOSK /   +---------+     +----------+     OFFICE        |   (south wall,
--    |  STORE     |  AWAY   D5   D6   HOME   |                   |    west end)
--    |            |         | COR |          |                   |
--    +------------+---------+=[2]=+----------+-------------------+
--              EAST (x -121)   touchline    PLAYERS' DOOR
--
-- The hatch and the side door keep to the west end of the building because a
-- built-up west stand wing (8+ rows) runs along the rest of the end walls.
--
-- How it is put together, so the exterior pass (phase 2) can re-skin it without
-- touching a room: `Shell` is the outer brick walls, the slab and the ONE roof.
-- Every room then lines its own four walls (LINING thick, in the room's own
-- finish), so a partition is two linings back to back. Openings are listed once
-- in OPENINGS, in world terms; any wall or lining that runs through one is cut.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local KitPlacer = require(script.Parent.KitPlacer)

local Clubhouse = {}

local DECK_Y = Pitch.SURFACE_Y
local GROUND_Y = 0

export type Rect = { x0: number, x1: number, z0: number, z1: number }

-- ------------------------------------------------------------------- layout

-- outer faces. The east face is the west perimeter wall line.
Clubhouse.SHELL = { x0 = -(Pitch.SIDE_EDGE + 36), x1 = -Pitch.SIDE_EDGE, z0 = -40, z1 = 40 } :: Rect
-- half the gap the west stand, its back wall and the perimeter wall leave
Clubhouse.GAP_Z = 41
Clubhouse.FLOOR_Y = DECK_Y + 0.1 -- a touch proud of the paving outside
Clubhouse.HEIGHT = 12 -- clear height of every room
Clubhouse.ROOF_TOP = Clubhouse.FLOOR_Y + Clubhouse.HEIGHT + 1

local SHELL = Clubhouse.SHELL
local FLOOR_Y = Clubhouse.FLOOR_Y
local H = Clubhouse.HEIGHT
local OUTER_T = 0.6 -- brick outer wall
local LINING = 0.4 -- a room's own wall finish
local DOOR_H = 7.5

local IN_X0, IN_X1 = SHELL.x0 + OUTER_T + LINING, SHELL.x1 - OUTER_T - LINING -- -156, -122
local IN_Z0, IN_Z1 = SHELL.z0 + OUTER_T + LINING, SHELL.z1 - OUTER_T - LINING -- -39, 39
local PART_Z = 16 -- store | middle | office partitions, at -PART_Z and +PART_Z
local PART_X = -148 -- lobby | dressing rooms
local COR_HALF = 4 -- corridor is 8 clear
local COR_WALL = COR_HALF + LINING -- centre of the corridor | dressing room wall

-- clear floor rectangles (inner faces of the linings)
Clubhouse.ROOMS = {
	Office = { x0 = IN_X0, x1 = IN_X1, z0 = PART_Z + LINING, z1 = IN_Z1 },
	Store = { x0 = IN_X0, x1 = IN_X1, z0 = IN_Z0, z1 = -PART_Z - LINING },
	Lobby = { x0 = IN_X0, x1 = PART_X - LINING, z0 = -PART_Z + LINING, z1 = PART_Z - LINING },
	Corridor = { x0 = PART_X + LINING, x1 = IN_X1, z0 = -COR_HALF, z1 = COR_HALF }, -- open at both ends
	Home = { x0 = PART_X + LINING, x1 = IN_X1, z0 = COR_WALL + LINING, z1 = PART_Z - LINING },
	Away = { x0 = PART_X + LINING, x1 = IN_X1, z0 = -PART_Z + LINING, z1 = -COR_WALL - LINING },
} :: { [string]: Rect }

Clubhouse.OFFICE = Clubhouse.ROOMS.Office

-- An opening is a hole through whatever stands on the plane `axis = at`
-- (within a stud), from `from` to `to` along the other axis, `sill` to `top`
-- above the floor.
export type Opening = { name: string, axis: "x" | "z", at: number, from: number, to: number, sill: number, top: number }

Clubhouse.OPENINGS = {
	{ name = "FrontDoors", axis = "x", at = SHELL.x0 + 0.5, from = -4, to = 4, sill = 0, top = DOOR_H },
	{ name = "PlayersDoor", axis = "x", at = SHELL.x1 - 0.5, from = -4, to = 4, sill = 0, top = DOOR_H },
	{ name = "OfficeSideDoor", axis = "z", at = SHELL.z1 - 0.5, from = -155, to = -150, sill = 0, top = DOOR_H },
	{ name = "OfficeLobbyDoor", axis = "z", at = PART_Z, from = -154, to = -149, sill = 0, top = DOOR_H },
	{ name = "StoreLobbyDoor", axis = "z", at = -PART_Z, from = -154, to = -149, sill = 0, top = DOOR_H },
	{ name = "CorridorMouth", axis = "x", at = PART_X, from = -4, to = 4, sill = 0, top = DOOR_H },
	{ name = "HomeDoor", axis = "z", at = COR_WALL, from = -139, to = -134, sill = 0, top = DOOR_H },
	{ name = "AwayDoor", axis = "z", at = -COR_WALL, from = -139, to = -134, sill = 0, top = DOOR_H },
	{ name = "OfficeWindow", axis = "x", at = SHELL.x0 + 0.5, from = 24, to = 34, sill = 3.5, top = 8.5 },
	{ name = "KioskHatch", axis = "x", at = SHELL.x0 + 0.5, from = -34, to = -26, sill = 3.5, top = 7.5 },
} :: { Opening }

-- where PlotService puts the owner: in front of the office side door, looking
-- out of it at daylight
Clubhouse.SPAWN = CFrame.new(-152.5, FLOOR_Y + 0.5, 34) * CFrame.Angles(0, math.pi, 0)

local BRICK = Color3.fromRGB(150, 84, 62) -- WorldBuilder's STAND_BRICK
local ROOF = Color3.fromRGB(70, 70, 70)
local OFFICE_WALL = Color3.fromRGB(170, 160, 135) -- stained beige; dressOffice repaints it
local CONCRETE = Color3.fromRGB(96, 98, 104)
local TILE = Color3.fromRGB(150, 148, 142)
local BULB = Color3.fromRGB(255, 250, 230)

-- ------------------------------------------------------------------ helpers

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- a box from its extents: nothing here is given as centre + size, so it is easy
-- to see that no two parts share a volume
local function slab(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, colour: Color3, material: Enum.Material?): Part
	return part({
		Name = name,
		Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Color = colour,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- One straight run of wall, cut by every opening it passes through. `axis` is
-- the axis the wall's plane is constant on; c0..c1 is its thickness on that
-- axis and a0..a1 its run along the other. Returns the pieces, longest first.
local function wall(parent: Instance, name: string, axis: "x" | "z", c0: number, c1: number, a0: number, a1: number, y0: number, y1: number, colour: Color3, material: Enum.Material): { Part }
	local function piece(pieceName: string, b0: number, b1: number, py0: number, py1: number): Part
		if axis == "x" then
			return slab(parent, pieceName, c0, c1, py0, py1, b0, b1, colour, material)
		end
		return slab(parent, pieceName, b0, b1, py0, py1, c0, c1, colour, material)
	end

	local cuts: { Opening } = {}
	for _, o in Clubhouse.OPENINGS do
		if o.axis == axis and math.abs(o.at - (c0 + c1) / 2) < 1 and o.to > a0 and o.from < a1 then
			table.insert(cuts, o)
		end
	end
	table.sort(cuts, function(p, q)
		return p.from < q.from
	end)

	local pieces: { Part } = {}
	local cursor = a0
	for _, o in cuts do
		if o.from > cursor then
			table.insert(pieces, piece(name, cursor, o.from, y0, y1))
		end
		if FLOOR_Y + o.top < y1 then
			piece(name .. "Header", o.from, o.to, FLOOR_Y + o.top, y1)
		end
		if o.sill > 0 then
			piece(name .. "Sill", o.from, o.to, y0, FLOOR_Y + o.sill)
		end
		cursor = o.to
	end
	if a1 > cursor then
		table.insert(pieces, piece(name, cursor, a1, y0, y1))
	end
	table.sort(pieces, function(p, q)
		return p.Size.Magnitude > q.Size.Magnitude
	end)
	return pieces
end

-- A room's own finish: a floor covering and a lining on each of the sides
-- named in `sides` (a corridor has no ends). Wall parts are named WallN/S/E/W.
local function lineRoom(parent: Instance, r: Rect, sides: string, wallColour: Color3, wallMat: Enum.Material, floorColour: Color3, floorMat: Enum.Material): { [string]: { Part } }
	local t = LINING
	local y0, y1 = FLOOR_Y, FLOOR_Y + H
	-- the covering runs under the linings, so doorways have a floor in them
	slab(parent, "Floor", r.x0 - t, r.x1 + t, DECK_Y, FLOOR_Y, r.z0 - t, r.z1 + t, floorColour, floorMat)
	local walls: { [string]: { Part } } = {}
	if sides:find("N") then
		walls.N = wall(parent, "WallN", "z", r.z0 - t, r.z0, r.x0 - t, r.x1 + t, y0, y1, wallColour, wallMat)
	end
	if sides:find("S") then
		walls.S = wall(parent, "WallS", "z", r.z1, r.z1 + t, r.x0 - t, r.x1 + t, y0, y1, wallColour, wallMat)
	end
	if sides:find("W") then
		walls.W = wall(parent, "WallW", "x", r.x0 - t, r.x0, r.z0, r.z1, y0, y1, wallColour, wallMat)
	end
	if sides:find("E") then
		walls.E = wall(parent, "WallE", "x", r.x1, r.x1 + t, r.z0, r.z1, y0, y1, wallColour, wallMat)
	end
	return walls
end

local function bulb(parent: Instance, x: number, z: number, sx: number, sz: number, brightness: number, range: number): Part
	local b = slab(parent, "Bulb", x - sx / 2, x + sx / 2, FLOOR_Y + H - 0.4, FLOOR_Y + H - 0.1, z - sz / 2, z + sz / 2, BULB, Enum.Material.Neon)
	b.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = Color3.fromRGB(255, 245, 225)
	light.Parent = b
	return b
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- -------------------------------------------------------------------- shell

local function buildShell(parent: Instance)
	local shell = model("Shell", parent)
	local y0, y1 = DECK_Y, FLOOR_Y + H -- walls stand on the slab and stop under the roof
	-- the slab everything stands on; room floor coverings lie on top of it
	slab(shell, "Slab", SHELL.x0, SHELL.x1, GROUND_Y, DECK_Y, SHELL.z0, SHELL.z1, Color3.fromRGB(130, 128, 122), Enum.Material.Concrete)
	-- the long walls run corner to corner, the short ones fit between them
	wall(shell, "WallW", "x", SHELL.x0, SHELL.x0 + OUTER_T, SHELL.z0, SHELL.z1, y0, y1, BRICK, Enum.Material.Brick)
	wall(shell, "WallE", "x", SHELL.x1 - OUTER_T, SHELL.x1, SHELL.z0, SHELL.z1, y0, y1, BRICK, Enum.Material.Brick)
	wall(shell, "WallN", "z", SHELL.z0, SHELL.z0 + OUTER_T, SHELL.x0 + OUTER_T, SHELL.x1 - OUTER_T, y0, y1, BRICK, Enum.Material.Brick)
	wall(shell, "WallS", "z", SHELL.z1 - OUTER_T, SHELL.z1, SHELL.x0 + OUTER_T, SHELL.x1 - OUTER_T, y0, y1, BRICK, Enum.Material.Brick)
	-- one roof over the lot, a little proud of the walls all round
	slab(shell, "Roof", SHELL.x0 - 0.5, SHELL.x1 + 0.5, FLOOR_Y + H, Clubhouse.ROOF_TOP, SHELL.z0 - 0.5, SHELL.z1 + 0.5, ROOF, Enum.Material.Slate)

	-- the office window and the kiosk shutter fill their openings
	local glass = slab(shell, "OfficeWindowGlass", SHELL.x0 + 0.2, SHELL.x0 + 0.4, FLOOR_Y + 3.5, FLOOR_Y + 8.5, 24, 34,
		Color3.fromRGB(170, 205, 225), Enum.Material.Glass)
	glass.Transparency = 0.5
	slab(shell, "KioskShutter", SHELL.x0 + 0.2, SHELL.x0 + 0.4, FLOOR_Y + 3.5, FLOOR_Y + 7.5, -34, -26,
		Color3.fromRGB(120, 124, 130), Enum.Material.DiamondPlate)
	slab(shell, "KioskCounter", SHELL.x0 - 1.2, SHELL.x0, FLOOR_Y + 3.2, FLOOR_Y + 3.5, -34.5, -25.5, Color3.fromRGB(206, 196, 176), Enum.Material.Concrete)

	-- a paved apron outside each public door, level with the slab, so nobody
	-- steps up off the grass into a doorway. PlotGrounds brings the paths here.
	local paving = Color3.fromRGB(196, 176, 148)
	slab(shell, "FrontApron", SHELL.x0 - 12, SHELL.x0, GROUND_Y, DECK_Y, -16, 16, paving, Enum.Material.Pavement)
	slab(shell, "SideApron", SHELL.x0, -147, GROUND_Y, DECK_Y, SHELL.z1, SHELL.z1 + 6, paving, Enum.Material.Pavement)

	-- club-colour header over the players' door, carrying the club's name the
	-- way the tunnel mouth did (WorldBuilder.setClubName finds "ClubName")
	local header = slab(shell, "PlayersHeader", SHELL.x1, SHELL.x1 + 0.4, FLOOR_Y + DOOR_H, FLOOR_Y + DOOR_H + 3, -7, 7, Config.HomeKit)
	-- and a plain name board over the front doors; styled in the exterior pass
	local front = slab(shell, "FrontSign", SHELL.x0 - 0.4, SHELL.x0, FLOOR_Y + DOOR_H + 0.5, FLOOR_Y + DOOR_H + 3.5, -9, 9, Config.HomeKit)
	for _, sign in { { header, Enum.NormalId.Right }, { front, Enum.NormalId.Left } } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = sign[2] :: Enum.NormalId
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.25
		gui.Parent = sign[1] :: Part
		local label = Instance.new("TextLabel")
		label.Name = "ClubName"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "CLUB"
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.15, 0)
		pad.PaddingBottom = UDim.new(0.15, 0)
		pad.Parent = label
	end
end

-- ---------------------------------------------------- lobby, corridor, store

local function buildLobby(parent: Instance, addSign: (BasePart, string, { Enum.NormalId }?) -> ())
	local lobby = model("Lobby", parent)
	local floorColour = Color3.fromRGB(130, 128, 122)
	local rooms = Clubhouse.ROOMS
	lineRoom(model("Hall", lobby), rooms.Lobby, "NSEW", CONCRETE, Enum.Material.Concrete, floorColour, Enum.Material.Concrete)
	lineRoom(model("Corridor", lobby), rooms.Corridor, "NS", CONCRETE, Enum.Material.Concrete, floorColour, Enum.Material.Concrete)
	local store = model("Store", lobby)
	lineRoom(store, rooms.Store, "NSEW", CONCRETE, Enum.Material.Concrete, floorColour, Enum.Material.Concrete)

	bulb(lobby, (rooms.Lobby.x0 + rooms.Lobby.x1) / 2, 0, 1.6, 5, 1.5, 30)
	for _, x in { -141, -129 } do
		bulb(lobby, x, 0, 5, 1.6, 1.6, 26)
	end
	bulb(store, -139, (rooms.Store.z0 + rooms.Store.z1) / 2, 5, 1.6, 1.2, 34)

	-- X312: the way out is signed. Over the corridor mouth, facing the lobby,
	-- and over the office side door, facing the room.
	local green = Color3.fromRGB(26, 92, 48)
	local toPitch = slab(lobby, "PitchSign", rooms.Lobby.x1 - 0.3, rooms.Lobby.x1, FLOOR_Y + 8.2, FLOOR_Y + 10.4, -3.5, 3.5, green)
	addSign(toPitch, "TO THE PITCH", { Enum.NormalId.Left })
	local office = Clubhouse.OFFICE
	local toCars = slab(lobby, "CarParkSign", -155.5, -149.5, FLOOR_Y + 8.2, FLOOR_Y + 10.2, office.z1 - 0.3, office.z1, green)
	addSign(toCars, "CAR PARK", { Enum.NormalId.Front })

	-- a few things in the store so the hatch has something behind it
	local function prop(name: string, at: Vector3, yaw: number, size: Vector3)
		KitPlacer.place("PH__" .. name, CFrame.new(at) * CFrame.Angles(0, yaw, 0), store, {
			fallbackSize = size,
			fallbackColor = Color3.fromRGB(120, 110, 100),
		})
	end
	prop("cardboard_box_01", Vector3.new(-126, FLOOR_Y, -36), 0.3, Vector3.new(1.1, 0.9, 1.4))
	prop("cardboard_box_01", Vector3.new(-127.6, FLOOR_Y, -37), -0.5, Vector3.new(1.1, 0.9, 1.4))
	prop("cardboard_box_01", Vector3.new(-126.6, FLOOR_Y + 0.9, -36.6), 1.1, Vector3.new(1.1, 0.9, 1.4))
	prop("wooden_ladder", Vector3.new(-123.2, FLOOR_Y, -20), math.pi / 2, Vector3.new(1.4, 6.0, 0.6))
end

-- ----------------------------------------------------------- dressing rooms

-- Home (south of the corridor) and away (north). No mechanics: they are a
-- place, and the team walks out past them. WorldBuilder.dressDressingRooms
-- hangs names on the parts called "Shirt" and rewrites the "TacticsBoard".
local function buildDressingRooms(parent: Instance, addSign: (BasePart, string, { Enum.NormalId }?) -> ())
	local rooms = model("DressingRooms", parent)
	local door: Opening? = nil
	for _, o in Clubhouse.OPENINGS do
		if o.name == "HomeDoor" then
			door = o
		end
	end
	assert(door, "HomeDoor opening missing")

	for _, zSign in { 1, -1 } do
		local home = zSign > 0
		local r = if home then Clubhouse.ROOMS.Home else Clubhouse.ROOMS.Away
		local room = model(if home then "Home" else "Away", rooms)
		lineRoom(room, r, "NSEW", CONCRETE, Enum.Material.Concrete, TILE, Enum.Material.Concrete)
		local kit = if home then Config.HomeKit else Color3.fromRGB(150, 150, 155)

		-- z given as a distance from the pitch's long axis and mirrored onto this
		-- side, so both rooms are built from one set of numbers
		local inner = math.min(math.abs(r.z0), math.abs(r.z1))
		local outer = math.max(math.abs(r.z0), math.abs(r.z1))
		local function piece(name: string, x0: number, x1: number, y0: number, y1: number, zNear: number, zFar: number, colour: Color3, material: Enum.Material): Part
			local za, zb = zSign * zNear, zSign * zFar
			return slab(room, name, x0, x1, FLOOR_Y + y0, FLOOR_Y + y1, math.min(za, zb), math.max(za, zb), colour, material)
		end

		-- Benches down both long sides with a peg rail and a hung shirt above
		-- each place. The corridor side is broken either side of the doorway.
		local sides = {
			{ name = "Outer", wallZ = outer, dir = -1, runs = { { r.x0 + 2, r.x1 - 2 } } },
			{ name = "Inner", wallZ = inner, dir = 1, runs = { { r.x0 + 2, door.from - 1 }, { door.to + 1, r.x1 - 2 } } },
		}
		for _, side in sides do
			local function span(a: number, b: number): (number, number)
				local za, zb = side.wallZ + side.dir * a, side.wallZ + side.dir * b
				return math.min(za, zb), math.max(za, zb)
			end
			for _, run in side.runs do
				if run[2] - run[1] < 4 then
					continue
				end
				local b0, b1 = span(0, 3.2)
				piece("Bench" .. side.name, run[1], run[2], 1.6, 2.1, b0, b1, Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
				local l0, l1 = span(2.0, 2.8)
				piece("BenchLeg" .. side.name, run[1], run[2], 0, 1.6, l0, l1, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
				local p0, p1 = span(0, 0.4)
				piece("PegRail" .. side.name, run[1], run[2], 6.4, 6.8, p0, p1, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
				-- shirts on the pegs: narrow enough that the two sides hold a
				-- full eleven between them
				local places = math.max(1, math.floor((run[2] - run[1]) / 2.8))
				local step = (run[2] - run[1]) / places
				for i = 1, places do
					local sx = run[1] + step * (i - 0.5)
					local s0, s1 = span(0.4, 0.8)
					local shirt = piece("Shirt", sx - 1.2, sx + 1.2, 3.4, 6.4, s0, s1, kit, Enum.Material.Fabric)
					shirt.CanCollide = false
				end
			end
		end

		-- tactics board flat on the far end wall, between the benches
		local board = piece("TacticsBoard", r.x0, r.x0 + 0.4, 3.5, 8.5, inner + 3.4, outer - 3.4, Color3.fromRGB(35, 70, 45), Enum.Material.SmoothPlastic)
		addSign(board, if home then "HOME" else "AWAY", { Enum.NormalId.Right })
		bulb(room, (r.x0 + r.x1) / 2, zSign * (inner + outer) / 2, 6, 2, 1.5, 30)
	end
end

-- ------------------------------------------------------------------- office

local function buildOffice(parent: Instance, addPrompt: (BasePart, string, string) -> ProximityPrompt)
	local office = model("Office", parent)
	local r = Clubhouse.OFFICE
	local walls = lineRoom(office, r, "NSEW", OFFICE_WALL, Enum.Material.Concrete, Color3.fromRGB(95, 80, 60), Enum.Material.WoodPlanks)

	-- X170: the early office is rundown (CLAUDE.md s5): damp stains on the walls
	-- and a curling fixtures notice, drawn with SurfaceGuis (no parts).
	-- dressOffice hides the "Damp" frames once the club can afford paint.
	local function wallGui(target: BasePart, face: Enum.NormalId): SurfaceGui
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Wear"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 1
		gui.Parent = target
		return gui
	end
	local function stain(gui: SurfaceGui, x: number, y: number, sw: number, sh: number)
		local f = Instance.new("Frame")
		f.Name = "Damp"
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(sw, sh)
		f.BackgroundColor3 = Color3.fromRGB(110, 96, 70)
		f.BackgroundTransparency = 0.72
		f.BorderSizePixel = 0
		f.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	-- the east wall is the only unbroken one: it carries the notice. The north
	-- wall's long piece (east of the lobby door) takes the rest of the damp.
	local eastGui = wallGui(walls.E[1], Enum.NormalId.Left) -- -X, into the room
	stain(eastGui, 0.02, 0.62, 0.22, 0.34)
	stain(eastGui, 0.1, 0.8, 0.3, 0.2)
	stain(eastGui, 0.8, 0.0, 0.18, 0.2)
	local northGui = wallGui(walls.N[1], Enum.NormalId.Back) -- +Z, into the room
	stain(northGui, 0.0, 0.0, 0.16, 0.24)
	stain(northGui, 0.86, 0.7, 0.14, 0.3)
	local notice = Instance.new("Frame")
	notice.Name = "FixturesNotice"
	notice.AnchorPoint = Vector2.new(0.5, 0.5)
	notice.Position = UDim2.fromScale(0.5, 0.42)
	notice.Size = UDim2.fromOffset(60, 76)
	notice.Rotation = -4
	notice.BackgroundColor3 = Color3.fromRGB(236, 228, 204)
	notice.BorderSizePixel = 0
	notice.Parent = eastGui
	local noticeText = Instance.new("TextLabel")
	noticeText.BackgroundTransparency = 1
	noticeText.Size = UDim2.fromScale(0.86, 0.9)
	noticeText.Position = UDim2.fromScale(0.07, 0.05)
	noticeText.Font = Enum.Font.PatrickHand
	noticeText.TextScaled = true
	noticeText.TextColor3 = Color3.fromRGB(40, 40, 46)
	noticeText.Name = "Lines"
	-- X301: filled from the real fixture list by SeasonService; this is only
	-- what the notice says before a season exists
	noticeText.Text = "FIXTURES\n(none yet)"
	noticeText.Parent = notice

	-- X373: furnished from the Poly Haven kit, every prop at real scale. Anything
	-- the kit is missing falls back to a grey block inside KitPlacer, so a clone
	-- with no uploads still builds an office you can walk around.
	local function prop(name: string, at: Vector3, yaw: number, size: Vector3): BasePart?
		local m = KitPlacer.place("PH__" .. name, CFrame.new(at) * CFrame.Angles(0, yaw, 0), office, {
			fallbackSize = size,
			fallbackColor = Color3.fromRGB(120, 110, 100),
		})
		return m and m:FindFirstChildWhichIsA("BasePart", true)
	end

	local floor = FLOOR_Y
	-- The desk sits in front of the window with the chair's back to it, the way
	-- it sat in front of the old office's end wall: desk length along Z, the
	-- working side facing the chair at -X.
	local west = r.x0
	local deskX, deskZ = west + 6, 29
	prop("metal_office_desk", Vector3.new(deskX, floor, deskZ), math.pi / 2, Vector3.new(2.5, 2.2, 5.5))
	local DESK_TOP = floor + 2.2
	prop("modern_arm_chair_01", Vector3.new(west + 2.2, floor, deskZ), math.pi / 2, Vector3.new(2.3, 2.8, 2.7))

	-- the laptop IS the club computer: it carries the screen and the prompt.
	-- Named so dressOffice and the HUD's hint beacon can find it (it had no name
	-- after X373 and both looked for "Computer" in vain).
	local computer = prop("classic_laptop", Vector3.new(deskX, DESK_TOP, deskZ), -math.pi / 2, Vector3.new(1.8, 1.3, 1.3)) :: BasePart
	computer.Name = "Computer"
	prop("office_notepads", Vector3.new(deskX - 0.2, DESK_TOP, deskZ - 1.6), 0.4, Vector3.new(0.6, 0.1, 0.8))
	prop("stationery_supplies", Vector3.new(deskX + 0.3, DESK_TOP, deskZ + 1.5), -0.2, Vector3.new(0.5, 0.2, 0.2))

	-- along the west wall either side of the window
	-- along the west wall north of the window; the south end is the side door's
	prop("wooden_bookshelf_worn", Vector3.new(west + 1.2, floor, 18.6), math.pi / 2, Vector3.new(1.6, 5.7, 3.8))
	prop("stationery_supplies", Vector3.new(west + 1.4, floor + 5.7, 18.6), math.pi / 2, Vector3.new(0.5, 0.2, 0.2))
	local cabinet = prop("drawer_cabinet", Vector3.new(west + 1.1, floor, 22.3), math.pi / 2, Vector3.new(1.3, 5.2, 3.1))
	if cabinet then
		-- a small telly on top of the cabinet, turned into the room
		prop("Television_01", Vector3.new(west + 1.1, floor + 5.2, 22.3), math.pi / 2, Vector3.new(1.3, 1.3, 1.6))
	end

	-- the odds and ends of a rundown grassroots office: for a club this size a
	-- pair of boots and a spare ball say more than filing cabinets do
	local east = r.x1
	prop("painted_wooden_bench", Vector3.new(-132.5, floor, r.z1 - 1), math.pi, Vector3.new(3.2, 2.4, 1.4))
	prop("korean_fire_extinguisher_01", Vector3.new(east - 0.8, floor, 25), 0, Vector3.new(0.8, 1.8, 1.0))
	prop("wooden_ladder", Vector3.new(east - 1.2, floor, r.z0 + 1.2), math.pi / 2, Vector3.new(1.4, 6.0, 0.6))
	prop("rubber_boots", Vector3.new(east - 1.6, floor, 31), -0.5, Vector3.new(1.2, 1.2, 1.6))
	prop("cardboard_box_01", Vector3.new(-127.5, floor, r.z1 - 1.6), 0.6, Vector3.new(1.1, 0.9, 1.4))
	prop("football", Vector3.new(-129.2, floor, r.z1 - 1), 0, Vector3.new(0.6, 0.6, 0.6))
	prop("dirty_football", Vector3.new(-128.6, floor, r.z1 - 2.2), 0, Vector3.new(0.6, 0.6, 0.6))
	prop("cardboard_box_01", Vector3.new(-132, floor, r.z0 + 1.4), -0.4, Vector3.new(1.1, 0.9, 1.4))
	prop("cardboard_box_01", Vector3.new(-131.2, floor + 0.9, r.z0 + 1.6), 0.8, Vector3.new(1.1, 0.9, 1.4))
	-- the tyre is modelled standing on its edge (1.6 x 1.7 x 0.5), so it is
	-- tipped a quarter turn about X to lie flat on the floor like training kit
	KitPlacer.place("PH__old_tyre", CFrame.new(-127, floor, r.z0 + 1.6) * CFrame.Angles(math.pi / 2, 0.3, 0), office, {
		fallbackSize = Vector3.new(1.6, 0.5, 1.6),
		fallbackColor = Color3.fromRGB(30, 30, 32),
	})
	-- a bin beside the desk, from the street kit (base and lid are separate meshes)
	KitPlacer.place("UKSP__TrachCan__TrashcanBase", CFrame.new(deskX + 3.4, floor, deskZ - 3.2), office, {
		fallbackSize = Vector3.new(2.1, 2.8, 1.9),
		fallbackColor = Color3.fromRGB(60, 62, 66),
	})
	KitPlacer.place("UKSP__TrachCan__TrashcanLid", CFrame.new(deskX + 3.4, floor + 2.8, deskZ - 3.2), office, {
		fallbackSize = Vector3.new(2.0, 0.5, 2.0),
		fallbackColor = Color3.fromRGB(60, 62, 66),
	})

	-- X169: an old green-screen monitor facing the chair (-X)
	local screen = Instance.new("SurfaceGui")
	screen.Name = "Screen"
	screen.Face = Enum.NormalId.Left
	screen.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screen.PixelsPerStud = 60
	screen.LightInfluence = 0
	screen.Parent = computer
	local glass = Instance.new("TextLabel")
	glass.Name = "Display"
	glass.Position = UDim2.fromScale(0.08, 0.1)
	glass.Size = UDim2.fromScale(0.84, 0.66)
	glass.BackgroundColor3 = Color3.fromRGB(12, 30, 16)
	glass.BorderSizePixel = 0
	glass.Font = Enum.Font.Code
	glass.TextScaled = true
	glass.TextXAlignment = Enum.TextXAlignment.Left
	glass.TextColor3 = Color3.fromRGB(90, 230, 110)
	glass.Text = " CLUB OFFICE\n > _"
	glass.Parent = screen
	-- Club management lives on the office computer. The client opens the panel
	-- when this prompt fires (ProximityPromptService.PromptTriggered).
	local clubPrompt = addPrompt(computer, "Club Office", "Manage squad, scouting & staff")
	clubPrompt.Name = "ClubPrompt"
	clubPrompt.HoldDuration = 0

	local light = bulb(office, (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, 1, 1, 1.2, 40)
	local glow = light:FindFirstChildOfClass("PointLight") :: PointLight
	glow.Color = Color3.fromRGB(255, 235, 200) -- a bare warm bulb; dressOffice improves it

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OfficeSpawn"
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = Clubhouse.SPAWN
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	-- X278: born disabled. Owners are always placed by PlotService.sendHome, and
	-- an enabled neutral spawn during the club's load (a yielding store read plus
	-- the world build) dropped anyone joining or respawning into a stranger's
	-- office; a later rebuild (reload/wipe) used to re-enable it for good.
	spawn.Enabled = false
	spawn.Parent = office
end

-- -------------------------------------------------------------------- build

export type Helpers = {
	addSign: (BasePart, string, { Enum.NormalId }?) -> (),
	addPrompt: (BasePart, string, string) -> ProximityPrompt,
}

-- Builds the clubhouse under `club` and returns the matchday board's prompt.
-- `Office` and `DressingRooms` stay direct children of the club model: the
-- server's dressers, the HUD's indoors check and the audio ducking all look
-- them up there by name. Everything else is under `Clubhouse`.
function Clubhouse.build(club: Instance, helpers: Helpers): ProximityPrompt
	local house = model("Clubhouse", club)
	buildShell(house)
	buildLobby(house, helpers.addSign)
	buildDressingRooms(club, helpers.addSign)
	buildOffice(club, helpers.addPrompt)

	-- The matchday board, on the lobby wall facing the front doors: the first
	-- thing seen coming in, and on the way from the office to the pitch.
	local lobby = Clubhouse.ROOMS.Lobby
	local home = Clubhouse.ROOMS.Home
	local zc = (home.z0 + home.z1) / 2
	local board = slab(club, "MatchdayBoard", lobby.x1 - 0.4, lobby.x1, FLOOR_Y + 2, FLOOR_Y + 7, zc - 4.5, zc + 4.5,
		Color3.fromRGB(30, 60, 30), Enum.Material.Wood)
	helpers.addSign(board, "MATCHDAY", { Enum.NormalId.Left })
	return helpers.addPrompt(board, "Matchday Board", "Play Match")
end

return Clubhouse
