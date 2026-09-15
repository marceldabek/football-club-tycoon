--!strict
-- Everything outside the club that makes it look like a place: lighting and
-- post-effects, terrain hills, clouds, trees, a distant town and the
-- floodlight masts. Built once per server (idempotent), independent of the
-- Club model that WorldBuilder rebuilds on reload. No assets, all procedural.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Assets = require(script.Parent.Assets)

local Scenery = {}

local GROUND_Y = 0
local DAY_CLOCK = 16.4 -- warm late afternoon while managing
local MATCH_CLOCK = 17.6 -- dusk on matchday so the floodlights read

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- ------------------------------------------------------------------ lighting

local function setupLighting()
	Lighting.ClockTime = DAY_CLOCK
	Lighting.GeographicLatitude = 48
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 145)
	Lighting.Ambient = Color3.fromRGB(70, 75, 85)
	Lighting.FogEnd = 100000

	findOrCreate(Lighting, "Sky", "Sky") -- default skybox textures, nothing to load

	local atmosphere = findOrCreate(Lighting, "Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(205, 210, 225)
	atmosphere.Decay = Color3.fromRGB(120, 110, 130)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.6

	local rays = findOrCreate(Lighting, "SunRays", "SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.7

	local bloom = findOrCreate(Lighting, "Bloom", "BloomEffect") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 28
	bloom.Threshold = 0.95

	local color = findOrCreate(Lighting, "Grade", "ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Brightness = 0.02
	color.Contrast = 0.1
	color.Saturation = 0.12
	color.TintColor = Color3.fromRGB(255, 248, 238)

	-- Technology (Future / ShadowMap) is not scriptable; set it once in Studio.
end

-- ------------------------------------------------------------------- terrain

local function setupTerrain()
	local terrain = workspace.Terrain
	if terrain:GetAttribute("FCTScenery") then
		return
	end
	terrain:SetAttribute("FCTScenery", true)

	-- terrain is the ground everywhere (top exactly at GROUND_Y); the template
	-- baseplate would show as a flat square against it, so it goes
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	-- LeafyGrass: the plain Grass material grows blade decoration that renders in a
	-- circle round the camera and pokes through floors; the property that turns it
	-- off is not scriptable here (Terrain > Decoration in the Properties panel)
	-- Terrain renders its surface ~2 studs above the top of a filled voxel row, so
	-- the fill stops at GROUND_Y - 2 to put the walkable surface exactly at GROUND_Y
	-- (measured: a fill to 0 gave a surface at 2, cutting through the pitch and office).
	terrain:FillBlock(CFrame.new(0, GROUND_Y - 10, 0), Vector3.new(4200, 16, 4200), Enum.Material.LeafyGrass)

	-- rolling hills: grass balls mostly below ground, poking up at the horizon
	local rng = Random.new(7)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = rng:NextNumber(750, 1150)
		local radius = rng:NextNumber(220, 380)
		local peak = rng:NextNumber(50, 130)
		local centre = Vector3.new(math.cos(angle) * dist, GROUND_Y - radius + peak, math.sin(angle) * dist)
		terrain:FillBall(centre, radius, Enum.Material.LeafyGrass)
		if rng:NextNumber() < 0.4 then
			-- rocky crown on some of them
			terrain:FillBall(centre + Vector3.new(0, 4, 0), radius * 0.45, Enum.Material.Rock)
			terrain:FillBall(centre, radius * 0.44, Enum.Material.LeafyGrass)
		end
	end

	-- a pond off to the south-west
	terrain:FillBlock(CFrame.new(-380, GROUND_Y - 5, 420), Vector3.new(160, 6, 120), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(-380, GROUND_Y - 6, 420), Vector3.new(160, 4, 120), Enum.Material.Water)

	local clouds = findOrCreate(terrain, "Clouds", "Clouds") :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.3
	clouds.Color = Color3.fromRGB(245, 240, 235)
end

-- --------------------------------------------------------------------- props

local function tree(parent: Instance, pos: Vector3, rng: Random)
	local scale = rng:NextNumber(0.8, 1.5)
	local trunkH = 9 * scale
	local trunk = part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 1.4 * scale, 1.4 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(95, 70, 45),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local greens = { Color3.fromRGB(60, 120, 50), Color3.fromRGB(75, 135, 55), Color3.fromRGB(50, 105, 45) }
	local green = greens[rng:NextInteger(1, #greens)]
	part({
		Name = "Canopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (11 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH + 3 * scale, 0)),
		Color = green,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	part({
		Name = "CanopyTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (7.5 * scale),
		CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), trunkH + 8 * scale, rng:NextNumber(-2, 2))),
		Color = green:Lerp(Color3.new(1, 1, 1), 0.08),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	trunk.CanCollide = true
end

local function setupTrees(parent: Instance)
	local rng = Random.new(21)
	local fenceX = Pitch.WIDTH / 2 + 5
	local fenceZ = Pitch.LENGTH / 2 + 12
	local kinds = Assets.list("Trees") -- Creator Store low-poly trees when the place has them
	local placed = 0
	while placed < 46 do
		local x = rng:NextNumber(-520, 520)
		local z = rng:NextNumber(-520, 520)
		-- keep clear of the club footprint (pitch, stand to the east, office to the west)
		local insideClub = math.abs(x) < fenceX + 110 and math.abs(z) < fenceZ + 40
		if insideClub then
			continue
		end
		local pos = Vector3.new(x, GROUND_Y, z)
		local done = false
		if #kinds > 0 then
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local placedTree = Assets.place("Trees." .. kind, pos, parent, {
				height = rng:NextNumber(18, 34),
				lookAt = pos + Vector3.new(math.cos(rng:NextNumber(0, 6.28)), 0, math.sin(rng:NextNumber(0, 6.28))),
				name = "Tree",
			})
			done = placedTree ~= nil
		end
		if not done then
			tree(parent, pos, rng)
		end
		placed += 1
	end
	-- a hedge line along the north end behind the goal, with a gap for the eye
	for i = -6, 6 do
		if i == 0 then
			continue
		end
		part({
			Name = "Hedge",
			Size = Vector3.new(24, 4, 3),
			CFrame = CFrame.new(i * 26, GROUND_Y + 2, -(fenceZ + 30)),
			Color = Color3.fromRGB(55, 110, 50),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

-- Distant town to the north-east: blocks in muted colours, a spire, chimneys.
local function setupTown(parent: Instance)
	local rng = Random.new(33)
	local palette = {
		Color3.fromRGB(180, 160, 140),
		Color3.fromRGB(150, 120, 100),
		Color3.fromRGB(200, 190, 175),
		Color3.fromRGB(120, 110, 105),
		Color3.fromRGB(170, 90, 80),
	}
	local cx, cz = 520, -720
	for i = 1, 34 do
		local w = rng:NextNumber(18, 40)
		local d = rng:NextNumber(18, 40)
		local h = rng:NextNumber(12, 42)
		local x = cx + rng:NextNumber(-260, 260)
		local z = cz + rng:NextNumber(-140, 140)
		local building = part({
			Name = "Building",
			Size = Vector3.new(w, h, d),
			CFrame = CFrame.new(x, GROUND_Y + h / 2, z),
			Color = palette[rng:NextInteger(1, #palette)],
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		-- pitched roof on the smaller ones
		if h < 24 then
			part({
				Name = "Roof",
				Shape = Enum.PartType.Wedge,
				Size = Vector3.new(w, 8, d),
				CFrame = CFrame.new(x, GROUND_Y + h + 4, z),
				Color = Color3.fromRGB(90, 60, 50),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		elseif rng:NextNumber() < 0.5 then
			part({
				Name = "Chimney",
				Size = Vector3.new(4, 12, 4),
				CFrame = CFrame.new(x + w / 3, GROUND_Y + h + 6, z),
				Color = Color3.fromRGB(110, 90, 80),
				Material = Enum.Material.Brick,
				Parent = parent,
			})
		end
		building.CastShadow = false
	end
	-- church tower and spire
	part({
		Name = "Tower",
		Size = Vector3.new(16, 50, 16),
		CFrame = CFrame.new(cx, GROUND_Y + 25, cz),
		Color = Color3.fromRGB(190, 180, 160),
		Material = Enum.Material.Cobblestone,
		Parent = parent,
	})
	local spire = Instance.new("CornerWedgePart")
	spire.Anchored = true
	spire.Size = Vector3.new(16, 34, 16)
	spire.CFrame = CFrame.new(cx, GROUND_Y + 67, cz)
	spire.Color = Color3.fromRGB(80, 80, 90)
	spire.Material = Enum.Material.Slate
	spire.Parent = parent
end

-- Four masts outside the corners. Heads are Neon so they read from anywhere;
-- real lights only reach 60 studs so the sun does the actual lighting.
local floodHeads: { Part } = {}
local function setupFloodlights(parent: Instance)
	table.clear(floodHeads)
	-- clear of the corners even when every plot is a full-depth grandstand
	local x = Pitch.SIDE_EDGE + 66
	local z = Pitch.END_EDGE + 66
	local mastH = 60
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = Vector3.new(sx * x, GROUND_Y, sz * z)
			-- Creator Store mast when the place has one: its lamp parts are named StadiumLight
			local placed = Assets.place("Floodlight", base, parent, { height = mastH + 6, lookAt = Vector3.new(0, GROUND_Y, 0), name = "Floodlight" })
			if placed then
				-- lamps only. The store model ships with a light source in every lamp,
				-- which washes the pole; real lights only reach 60 studs anyway.
				for _, d in placed.model:GetDescendants() do
					if d:IsA("Light") then
						d:Destroy()
					elseif d:IsA("BasePart") and d.Name == "StadiumLight" then
						d.CastShadow = false
						table.insert(floodHeads, d)
					end
				end
				continue
			end
			part({
				Name = "Mast",
				Size = Vector3.new(2, mastH, 2),
				CFrame = CFrame.new(base + Vector3.new(0, mastH / 2, 0)),
				Color = Color3.fromRGB(130, 135, 140),
				Material = Enum.Material.DiamondPlate,
				Parent = parent,
			})
			-- head frame angled at the pitch centre
			local headPos = base + Vector3.new(0, mastH + 2, 0)
			local look = CFrame.lookAt(headPos, Vector3.new(0, GROUND_Y, 0))
			part({
				Name = "HeadFrame",
				Size = Vector3.new(14, 8, 1.2),
				CFrame = look,
				Color = Color3.fromRGB(60, 60, 65),
				Material = Enum.Material.Metal,
				Parent = parent,
			})
			local head = part({
				Name = "HeadLamps",
				Size = Vector3.new(12.5, 6.5, 0.6),
				CFrame = look * CFrame.new(0, 0, -0.6),
				Color = Color3.fromRGB(120, 120, 110),
				Material = Enum.Material.SmoothPlastic,
				CastShadow = false,
				Parent = parent,
			})
			table.insert(floodHeads, head)
		end
	end
end

function Scenery.setFloodlights(on: boolean)
	for _, head in floodHeads do
		head.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		head.Color = if on then Color3.fromRGB(255, 250, 225) else Color3.fromRGB(150, 145, 125)
	end
end

local clockTween: Tween? = nil
local function tweenClock(target: number, seconds: number)
	if clockTween then
		clockTween:Cancel()
	end
	clockTween = TweenService:Create(Lighting, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ClockTime = target })
	;(clockTween :: Tween):Play()
end

-- Dusk and floodlights on for the match; back to the afternoon afterwards.
function Scenery.setMatchday(on: boolean)
	tweenClock(if on then MATCH_CLOCK else DAY_CLOCK, if on then 6 else 4)
	Scenery.setFloodlights(on)
end

function Scenery.setup()
	setupLighting()
	setupTerrain()
	local model = workspace:FindFirstChild("Scenery")
	if model then
		model:Destroy()
	end
	model = Instance.new("Model")
	model.Name = "Scenery"
	model.Parent = workspace
	local trees = Instance.new("Model")
	trees.Name = "Trees"
	trees.Parent = model
	setupTrees(trees)
	local town = Instance.new("Model")
	town.Name = "Town"
	town.Parent = model
	setupTown(town)
	local floods = Instance.new("Model")
	floods.Name = "Floodlights"
	floods.Parent = model
	setupFloodlights(floods)
	Scenery.setFloodlights(false)
end

return Scenery
