--!strict
-- Brick arches under the Lune Viaduct (backlog X20). TownBuilder builds the
-- greybox viaduct (workspace.Town.Bridges["Lune Viaduct"]: deck, parapets,
-- slab piers, rails) from TownLayout.BRIDGES. This fills each span between
-- supports with vertical brick slices whose bottoms follow a segmental arch,
-- so from the river it reads as a Victorian railway viaduct. Piers are
-- re-skinned in brick. ~60 parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local ViaductDresser = {}

local BRICK = Color3.fromRGB(140, 66, 50)
local SPRINGING = 9 -- TEMP: arch springs this high above the ground line
local CROWN_GAP = 1.5 -- brick left above the crown before the deck soffit
local SLICES = 8

export type Span = { s0: number, s1: number }

-- Pure: clear spans between supports along a bridge of `length`, given the
-- distances of pier centres from the `from` end and the pier depth along it.
function ViaductDresser.spans(length: number, pierDistances: { number }, pierDepth: number): { Span }
	local sorted = table.clone(pierDistances)
	table.sort(sorted)
	local out: { Span } = {}
	local last = 0
	for _, s in sorted do
		local a, b = last, s - pierDepth / 2
		if b - a > 1 then
			table.insert(out, { s0 = a, s1 = b })
		end
		last = s + pierDepth / 2
	end
	if length - last > 1 then
		table.insert(out, { s0 = last, s1 = length })
	end
	return out
end

-- Pure: underside height of a segmental arch at offset x from the span centre.
function ViaductDresser.archHeight(x: number, span: number, springing: number, rise: number): number
	local half = span / 2
	local u = math.clamp(x / half, -1, 1)
	return springing + rise * math.sqrt(1 - u * u)
end

function ViaductDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	local bridges = town and town:FindFirstChild("Bridges")
	if not bridges then
		return "viaduct: no bridges"
	end
	local parts = 0
	for _, bridge in TownLayout.BRIDGES do
		if bridge.kind ~= "rail" then
			continue
		end
		local m = bridges:FindFirstChild(bridge.name)
		local deck = m and m:FindFirstChild("Deck")
		if not (m and deck and deck:IsA("BasePart")) then
			continue
		end
		local old = m:FindFirstChild("Arches")
		if old then
			old:Destroy()
		end
		local arches = Instance.new("Model")
		arches.Name = "Arches"

		local dir = Vector3.new(bridge.to.X - bridge.from.X, 0, bridge.to.Z - bridge.from.Z)
		local length = dir.Magnitude
		if length < 1 then
			continue
		end
		dir = dir.Unit
		local rotation = CFrame.lookAt(Vector3.zero, dir)
		local soffit = deck.Position.Y - deck.Size.Y / 2
		local width = deck.Size.X - 2

		local piers: { number } = {}
		local pierDepth = 10
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") and c.Name == "Pier" then
				local rel = c.Position - bridge.from
				table.insert(piers, Vector3.new(rel.X, 0, rel.Z):Dot(dir))
				pierDepth = c.Size.Z
				c.Color = BRICK
				c.Material = Enum.Material.Brick
			end
		end

		for _, span in ViaductDresser.spans(length, piers, pierDepth) do
			local w = span.s1 - span.s0
			local rise = math.max(1, math.min(w / 2, soffit - CROWN_GAP - SPRINGING))
			local slice = w / SLICES
			for k = 1, SLICES do
				local centre = span.s0 + (k - 0.5) * slice
				-- use the lower edge of the slice so neighbouring slices overlap the curve
				local edge = math.abs(centre - (span.s0 + span.s1) / 2) + slice / 2
				local bottom = ViaductDresser.archHeight(edge, w, SPRINGING, rise)
				local h = soffit - bottom
				if h > 0.2 then
					local p = Instance.new("Part")
					p.Name = "Spandrel"
					p.Anchored = true
					p.Size = Vector3.new(width, h, slice)
					local pos = bridge.from + dir * centre
					p.CFrame = CFrame.new(pos.X, bottom + h / 2, pos.Z) * rotation
					p.Color = BRICK
					p.Material = Enum.Material.Brick
					p.TopSurface = Enum.SurfaceType.Smooth
					p.BottomSurface = Enum.SurfaceType.Smooth
					p.Parent = arches
					parts += 1
				end
			end
		end
		arches.Parent = m
	end
	return ("viaduct: %d parts"):format(parts)
end

return ViaductDresser
