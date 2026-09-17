--!strict
-- Stone arch road bridges (backlog X19). Reference:
-- assets/references/RivermereRiverside.png - a pale sandstone bridge of low
-- segmental arches, pointed cutwaters on the piers, a string course under a
-- plain stone parapet with coping.
--
-- TownBuilder builds each road bridge (workspace.Town.Bridges[name]: level
-- Deck, DeckRamp x2, Parapet and Footway per piece, Pier x2) from
-- TownLayout.BRIDGES. The deck is humped (X31, TownLayout.bridgeRise): its
-- soffit is ~8.7 studs above the water (Y.WATER_TOP) over the level middle and
-- drops to ~2.7 at the ends. Each clear span is split into a few narrower
-- arches (<= MAX_ARCH wide) whose feet stand just above the water, tall under
-- the level deck and low under the ramps; each arch is SLICES vertical stone
-- slices whose bottoms follow the arch curve, as in ViaductDresser. Piers are
-- widened to the spandrel face and re-skinned, parapets re-skinned to stone.
-- ~130 parts per bridge (budget 140).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local TownBuilder = require(script.Parent.TownBuilder)
local ViaductDresser = require(script.Parent.ViaductDresser)

local BridgeDresser = {}

local STONE = Color3.fromRGB(196, 182, 156)
local STONE_DARK = Color3.fromRGB(170, 156, 132)
local COPING = Color3.fromRGB(214, 204, 184)

local MAX_ARCH = 24 -- TEMP: widest single arch, studs
local SLICES = 6 -- slices per arch; each slice's underside is a wedge, so the arch is a smooth 6-sided curve (X41)
local SPRING_ABOVE_WATER = 0.15 -- arch feet sit this far above the water surface
local CROWN_GAP = 0.4 -- stone left above the crown before the deck soffit
local SPANDREL_INSET = 0.2 -- spandrel/pier face sits this far inside the deck edge
local CUTWATER_PROJECTION = 5 -- nose length beyond the pier face
local STRING_PROJECTION = 0.5
local STRING_BELOW_SOFFIT = 0.3
local STRING_ABOVE_DECK = 0.4
local COPING_HEIGHT = 0.4
local COPING_OVERHANG = 0.25 -- each side of the parapet

export type Span = ViaductDresser.Span

-- Pure: split a clear span into the fewest equal arches no wider than maxArch.
function BridgeDresser.arches(span: Span, maxArch: number): { Span }
	local w = span.s1 - span.s0
	local n = math.max(1, math.ceil(w / maxArch - 1e-6))
	local out: { Span } = {}
	for k = 0, n - 1 do
		table.insert(out, { s0 = span.s0 + w * k / n, s1 = span.s0 + w * (k + 1) / n })
	end
	return out
end

-- Pure: one half of a pointed cutwater, in the pier's local frame (x across
-- the bridge = along the river, y up, z along the bridge; origin at the pier
-- centre, y = the cutwater's mid height). `s` = +1/-1 picks the pier end (+x
-- or -x), `t` = +1/-1 picks the half (+z or -z). Returns the CFrame and Size
-- for a WedgePart.
--
-- WedgePart cross-section (local YZ): vertices (y=-h/2, z=-l/2),
-- (y=-h/2, z=+l/2), (y=+h/2, z=+l/2); the right angle is at (-h/2, +l/2),
-- one leg runs along local -Z (length l), the other along local +Y (length h);
-- the triangle is extruded along local X. For a plan-view triangle we want:
--   right angle on the pier end face at (x = s*halfWidth, z = 0)
--   local -Z leg -> +s*x (towards the nose), so local Z = (-s, 0, 0), l = projection
--   local +Y leg -> +t*z (along the pier face), so local Y = (0, 0, t), h = halfDepth
--   local X = Y x Z = (0, 0, t) x (-s, 0, 0) = (0, -t*s, 0): vertical, size = height
-- Centre = right angle - Y*(-h/2) - Z*(l/2) = (s*(halfWidth + l/2), 0, t*h/2).
function BridgeDresser.cutwater(s: number, t: number, halfWidth: number, halfDepth: number, projection: number, height: number): (CFrame, Vector3)
	local pos = Vector3.new(s * (halfWidth + projection / 2), 0, t * halfDepth / 2)
	local x = Vector3.new(0, -t * s, 0)
	local y = Vector3.new(0, 0, t)
	local z = Vector3.new(-s, 0, 0)
	return CFrame.fromMatrix(pos, x, y, z), Vector3.new(height, halfDepth, projection)
end

-- Pure: the WedgePart under one arch slice (X41). Along the bridge (from
-- `base` in direction `dir`), the slice's underside runs from `outer`, where
-- the arch is lower (`yOuter`), to `inner` (`yInner`, higher, where the
-- slice's block ends). The wedge fills the triangle above that line and below
-- yInner, so the arch soffit reads as a smooth curve instead of steps.
-- Returns the CFrame and Size (width across the bridge, height, length).
--
-- WedgePart: right angle at local (y = -h/2, z = +l/2), slope on top. The
-- frame is turned upside down (local Y = world down) so the right angle sits at
-- the top of the outer edge and the slope faces the water.
function BridgeDresser.sliceWedge(base: Vector3, dir: Vector3, outer: number, inner: number, yOuter: number, yInner: number, width: number): (CFrame, Vector3)
	local h = yInner - yOuter
	local l = math.abs(inner - outer)
	local mid = base + dir * ((outer + inner) / 2)
	local pos = Vector3.new(mid.X, (yOuter + yInner) / 2, mid.Z)
	local zAxis = dir * (if outer > inner then 1 else -1)
	local yAxis = Vector3.new(0, -1, 0)
	local xAxis = yAxis:Cross(zAxis)
	return CFrame.fromMatrix(pos, xAxis, yAxis, zAxis), Vector3.new(width, h, l)
end

local function stone(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, className: string?): BasePart
	local p = (Instance.new :: any)(className or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.Sandstone
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function dressBridge(bridge: TownLayout.Bridge, m: Instance): number
	local deck = m:FindFirstChild("Deck")
	if not (deck and deck:IsA("BasePart")) then
		return 0
	end
	local old = m:FindFirstChild("Dressing")
	if old then
		old:Destroy()
	end
	local dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	local parts = 0

	local dir = Vector3.new(bridge.to.X - bridge.from.X, 0, bridge.to.Z - bridge.from.Z)
	local length = dir.Magnitude
	if length < 1 then
		return 0
	end
	dir = dir.Unit
	local rotation = CFrame.lookAt(Vector3.zero, dir)
	local deckWidth = deck.Size.X
	-- the level Deck's underside; ramps drop it back towards street level
	local levelSoffit = deck.Position.Y - deck.Size.Y / 2
	local function soffitAt(along: number): number
		return levelSoffit - TownLayout.BRIDGE_RISE + TownLayout.bridgeRise(bridge, along)
	end
	local faceWidth = deckWidth - 2 * SPANDREL_INSET
	local springing = TownBuilder.Y.WATER_TOP + SPRING_ABOVE_WATER

	-- piers: widen to the spandrel face, re-skin, add pointed cutwaters both ends
	local piers: { number } = {}
	local pierDepth = 8
	for _, c in m:GetChildren() do
		if not (c:IsA("BasePart") and c.Name == "Pier") then
			continue
		end
		c.Size = Vector3.new(faceWidth, c.Size.Y, c.Size.Z)
		c.Color = STONE_DARK
		c.Material = Enum.Material.Sandstone
		pierDepth = c.Size.Z
		local rel = c.Position - bridge.from
		local pierAlong = Vector3.new(rel.X, 0, rel.Z):Dot(dir)
		table.insert(piers, pierAlong)

		-- from just above the pier foot to below the string course (no shared planes)
		local bottom = c.Position.Y - c.Size.Y / 2 + 0.5
		local top = soffitAt(pierAlong) - STRING_BELOW_SOFFIT - 0.15
		local height = top - bottom
		if height > 0.5 then
			local mid = CFrame.new(0, (top + bottom) / 2 - c.Position.Y, 0)
			for _, s in { -1, 1 } do
				for _, t in { -1, 1 } do
					local cf, size = BridgeDresser.cutwater(s, t, faceWidth / 2, c.Size.Z / 2, CUTWATER_PROJECTION, height)
					stone(dressing, "Cutwater", size, c.CFrame * mid * cf, STONE_DARK, "WedgePart")
					parts += 1
				end
			end
		end
	end

	-- arch spandrels: the slices' side faces are flush with the widened piers
	for _, span in ViaductDresser.spans(length, piers, pierDepth) do
		for _, arch in BridgeDresser.arches(span, MAX_ARCH) do
			-- the deck profile is piecewise straight, so its lowest point over
			-- an arch is at one of the arch's ends
			local rise = math.max(0.5, math.min(soffitAt(arch.s0), soffitAt(arch.s1)) - CROWN_GAP - springing)
			local w = arch.s1 - arch.s0
			local slice = w / SLICES
			local centreOfArch = (arch.s0 + arch.s1) / 2
			for k = 1, SLICES do
				local centre = arch.s0 + (k - 0.5) * slice
				local offset = centre - centreOfArch
				local outwards = if offset > 0 then 1 else -1
				-- the block stops at the slice's higher (inner) corner; a wedge
				-- carries the curve down to the outer corner
				local yInner = ViaductDresser.archHeight(math.abs(offset) - slice / 2, w, springing, rise)
				local yOuter = ViaductDresser.archHeight(math.abs(offset) + slice / 2, w, springing, rise)
				-- up to the higher side of a sloping soffit: no sliver of daylight
				local h = math.max(soffitAt(centre - slice / 2), soffitAt(centre + slice / 2)) - yInner
				if h > 0.2 then
					local pos = bridge.from + dir * centre
					stone(dressing, "Spandrel", Vector3.new(faceWidth, h, slice), CFrame.new(pos.X, yInner + h / 2, pos.Z) * rotation, STONE)
					parts += 1
				end
				if yInner - yOuter > 0.05 then
					local cf, size = BridgeDresser.sliceWedge(
						bridge.from,
						dir,
						centre + outwards * slice / 2,
						centre - outwards * slice / 2,
						yOuter,
						yInner,
						faceWidth
					)
					stone(dressing, "ArchWedge", size, cf, STONE, "WedgePart")
					parts += 1
				end
			end
		end
	end

	-- string course: a projecting band along each deck edge of every deck
	-- piece (level and ramps), covering the asphalt side and the parapet foot
	for _, piece in m:GetChildren() do
		if not (piece:IsA("BasePart") and (piece.Name == "Deck" or piece.Name == "DeckRamp")) then
			continue
		end
		local bandBottom = -piece.Size.Y / 2 - STRING_BELOW_SOFFIT
		local bandTop = piece.Size.Y / 2 + STRING_ABOVE_DECK
		for _, side in { -1, 1 } do
			local cf = piece.CFrame * CFrame.new(side * (deckWidth / 2 + STRING_PROJECTION / 2), (bandTop + bandBottom) / 2, 0)
			stone(dressing, "StringCourse", Vector3.new(STRING_PROJECTION, bandTop - bandBottom, piece.Size.Z + 0.4), cf, COPING)
			parts += 1
		end
	end

	-- parapets: stone, with a coping that overhangs both faces and the ends
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and c.Name == "Parapet" then
			c.Color = STONE
			c.Material = Enum.Material.Sandstone
			local size = Vector3.new(c.Size.X + 2 * COPING_OVERHANG, COPING_HEIGHT, c.Size.Z + 0.4)
			stone(dressing, "Coping", size, c.CFrame * CFrame.new(0, c.Size.Y / 2 + COPING_HEIGHT / 2, 0), COPING)
			parts += 1
		end
	end

	dressing.Parent = m
	return parts
end

function BridgeDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	local bridges = town and town:FindFirstChild("Bridges")
	if not bridges then
		return "bridges: no bridges"
	end
	local total, count, most = 0, 0, 0
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "road" then
			continue
		end
		local m = bridges:FindFirstChild(bridge.name)
		if m then
			local n = dressBridge(bridge, m)
			total += n
			count += 1
			most = math.max(most, n)
		end
	end
	return ("bridges: %d road bridges, %d parts (max %d per bridge)"):format(count, total, most)
end

return BridgeDresser
