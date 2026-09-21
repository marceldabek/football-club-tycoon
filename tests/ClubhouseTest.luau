--!strict
-- docs/CLUBHOUSE_PLAN.md: one building, one roof, three ways in and out, and
-- every doorway actually open.
local ServerScriptService = game:GetService("ServerScriptService")
local Clubhouse = require(ServerScriptService.Server.Clubhouse)

local T = {}

local function build(): (Model, ProximityPrompt)
	local club = Instance.new("Model")
	club.Name = "Club"
	local prompt = Clubhouse.build(club, {
		addSign = function() end,
		addPrompt = function(target: BasePart, objectText: string, actionText: string): ProximityPrompt
			local p = Instance.new("ProximityPrompt")
			p.ObjectText = objectText
			p.ActionText = actionText
			p.Parent = target
			return p
		end,
	})
	return club, prompt
end

-- world axis-aligned bounds of a part, whatever its rotation
local function bounds(p: BasePart): (Vector3, Vector3)
	local cf, half = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local e = Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	)
	return cf.Position - e, cf.Position + e
end

function T.modelsTheRestOfTheGameLooksUpByName()
	local club = build()
	for _, name in { "Office", "DressingRooms", "Clubhouse", "MatchdayBoard" } do
		assert(club:FindFirstChild(name), name .. " must be a direct child of the club model")
	end
	local house = club:FindFirstChild("Clubhouse") :: Instance
	assert(house:FindFirstChild("Shell") and house:FindFirstChild("Lobby"), "Clubhouse needs Shell and Lobby")
	local rooms = club:FindFirstChild("DressingRooms") :: Instance
	assert(rooms:FindFirstChild("Home") and rooms:FindFirstChild("Away"), "both dressing rooms")
	local office = club:FindFirstChild("Office") :: Instance
	local computer = office:FindFirstChild("Computer", true)
	assert(computer and computer:IsA("BasePart"), "the office computer must be findable by name")
	assert(computer:FindFirstChild("ClubPrompt"), "and carry the club prompt")
	assert(office:FindFirstChild("Lines", true), "fixtures notice label")
end

function T.matchdayBoardCarriesThePlayPrompt()
	local club, prompt = build()
	assert(prompt.Parent == club:FindFirstChild("MatchdayBoard"), "prompt on the board")
	assert(prompt.ActionText == "Play Match", prompt.ActionText)
end

function T.homeDressingRoomHangsAFullEleven()
	local club = build()
	for _, name in { "Home", "Away" } do
		local room = (club:FindFirstChild("DressingRooms") :: Instance):FindFirstChild(name) :: Instance
		local shirts = 0
		for _, c in room:GetChildren() do
			if c.Name == "Shirt" then
				shirts += 1
			end
		end
		assert(shirts >= 11, ("%s room hangs %d shirts, needs 11"):format(name, shirts))
	end
end

function T.threeWaysInAndOut()
	local outside = 0
	local s = Clubhouse.SHELL
	for _, o in Clubhouse.OPENINGS do
		local onShell = if o.axis == "x"
			then math.abs(o.at - s.x0) < 1 or math.abs(o.at - s.x1) < 1
			else math.abs(o.at - s.z0) < 1 or math.abs(o.at - s.z1) < 1
		if onShell and o.sill == 0 then
			outside += 1
		end
	end
	assert(outside >= 3, ("only %d exterior doors"):format(outside))
end

-- A character-sized box (3 wide, 6 tall) through the middle of every doorway,
-- reaching two studs either side of the wall, must be empty.
function T.everyDoorwayIsClear()
	local club = build()
	local floor = Clubhouse.FLOOR_Y
	for _, o in Clubhouse.OPENINGS do
		if o.sill > 0 then
			continue -- a window or a hatch
		end
		local mid = (o.from + o.to) / 2
		local lo, hi
		if o.axis == "x" then
			lo, hi = Vector3.new(o.at - 2, floor + 0.2, mid - 1.5), Vector3.new(o.at + 2, floor + 6, mid + 1.5)
		else
			lo, hi = Vector3.new(mid - 1.5, floor + 0.2, o.at - 2), Vector3.new(mid + 1.5, floor + 6, o.at + 2)
		end
		for _, d in club:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				local a, b = bounds(d)
				local hit = a.X < hi.X and b.X > lo.X and a.Y < hi.Y and b.Y > lo.Y and a.Z < hi.Z and b.Z > lo.Z
				assert(not hit, ("%s is blocked by %s"):format(o.name, d:GetFullName()))
			end
		end
	end
end

function T.spawnIsInsideTheOffice()
	local club = build()
	local spawn = club:FindFirstChild("OfficeSpawn", true)
	assert(spawn and spawn:IsA("SpawnLocation"), "OfficeSpawn")
	assert(not spawn.Enabled, "X278: the spawn is born disabled")
	local p, r = spawn.Position, Clubhouse.OFFICE
	assert(p.X > r.x0 + 2 and p.X < r.x1 - 2 and p.Z > r.z0 + 2 and p.Z < r.z1 - 2, "spawn outside the office floor")
	assert(p.Y > Clubhouse.FLOOR_Y and p.Y < Clubhouse.FLOOR_Y + 2, "spawn not on the floor")
end

function T.oneRoofInsideAParapet()
	local club = build()
	local shell = (club:FindFirstChild("Clubhouse") :: Instance):FindFirstChild("Shell") :: Instance
	local roofs = {}
	for _, c in shell:GetChildren() do
		if c.Name == "Roof" then
			table.insert(roofs, c)
		end
	end
	assert(#roofs == 1, ("%d roofs"):format(#roofs))
	-- the felt sits inside the parapet, so it covers every room but not the
	-- thickness of the outer walls
	local lo, hi = bounds(roofs[1] :: BasePart)
	for name, r in Clubhouse.ROOMS do
		assert(lo.X <= r.x0 and hi.X >= r.x1 and lo.Z <= r.z0 and hi.Z >= r.z1, "roof does not cover " .. name)
	end
	assert(math.abs(lo.Y - (Clubhouse.FLOOR_Y + Clubhouse.HEIGHT)) < 0.01, "roof is not sitting on the rooms")
	-- nothing built into the shell rises above the coping (kit props may)
	local highest = -math.huge
	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") then
			local _, top = bounds(d)
			highest = math.max(highest, top.Y)
		end
	end
	assert(math.abs(highest - Clubhouse.ROOF_TOP) < 0.01, ("ROOF_TOP %.2f but the shell tops out at %.2f"):format(Clubhouse.ROOF_TOP, highest))
end

-- Nothing the wall builder emits may share a volume with another wall piece:
-- coincident faces flicker (the no-interpenetration rule from world pass 2).
function T.wallsAndFloorsDoNotInterpenetrate()
	local club = build()
	local pieces: { BasePart } = {}
	for _, d in club:GetDescendants() do
		if d:IsA("BasePart") and (d.Name:sub(1, 4) == "Wall" or d.Name == "Floor" or d.Name == "Slab" or d.Name == "Roof") then
			table.insert(pieces, d)
		end
	end
	assert(#pieces > 20, "expected the shell and room linings")
	local eps = 0.001
	for i = 1, #pieces do
		local a0, a1 = bounds(pieces[i])
		for j = i + 1, #pieces do
			local b0, b1 = bounds(pieces[j])
			local hit = a0.X < b1.X - eps and b0.X < a1.X - eps and a0.Y < b1.Y - eps and b0.Y < a1.Y - eps and a0.Z < b1.Z - eps and b0.Z < a1.Z - eps
			assert(not hit, ("%s overlaps %s"):format(pieces[i]:GetFullName(), pieces[j]:GetFullName()))
		end
	end
end

function T.everyWindowIsGlazedAndFramed()
	local club = build()
	local shell = (club:FindFirstChild("Clubhouse") :: Instance):FindFirstChild("Shell") :: Instance
	local windows = 0
	for _, o in Clubhouse.OPENINGS do
		if o.glazed then
			windows += 1
			assert(shell:FindFirstChild(o.name .. "Glass"), o.name .. " has no glass")
			assert(shell:FindFirstChild(o.name .. "Frame"), o.name .. " has no frame")
		end
	end
	assert(windows >= 4, "expected the office window, two sidelights and the dressing room slots")
end

-- Every doorway (not the open corridor mouth) has a frame and at least one leaf,
-- and each leaf's bounding box touches a frame piece: no floating doors.
function T.everyDoorIsHungOnItsFrame()
	local club = build()
	local shell = (club:FindFirstChild("Clubhouse") :: Instance):FindFirstChild("Shell") :: Instance
	for _, o in Clubhouse.OPENINGS do
		if o.sill > 0 or o.name == "CorridorMouth" then
			continue
		end
		local frames, leaves = {}, {}
		for _, c in shell:GetChildren() do
			if c.Name == o.name .. "Frame" then
				table.insert(frames, c)
			elseif c.Name == o.name .. "Leaf" then
				table.insert(leaves, c)
			end
		end
		assert(#frames == 3, o.name .. " has no frame")
		assert(#leaves >= 1, o.name .. " has no leaf")
		for _, leaf in leaves do
			local p = leaf:FindFirstChildWhichIsA("BasePart", true) :: BasePart
			assert(not p.CanCollide, o.name .. " leaf would block the doorway")
			local a0, a1 = bounds(p)
			local touching = false
			for _, f in frames do
				local b0, b1 = bounds(f :: BasePart)
				local eps = 0.01
				if a0.X <= b1.X + eps and b0.X <= a1.X + eps and a0.Y <= b1.Y + eps and b0.Y <= a1.Y + eps and a0.Z <= b1.Z + eps and b0.Z <= a1.Z + eps then
					touching = true
				end
			end
			assert(touching, o.name .. " leaf is not touching its frame")
		end
	end
end

-- The exterior is kit dressing: it must never block a doorway (everyDoorwayIsClear
-- covers that) and must survive a place with no kit installed.
function T.exteriorDressingIsPlaced()
	local club = build()
	local ext = (club:FindFirstChild("Clubhouse") :: Instance):FindFirstChild("Exterior")
	assert(ext and #ext:GetChildren() >= 8, "exterior props missing")
	local s = Clubhouse.SHELL
	for _, m in (ext :: Instance):GetChildren() do
		if m:IsA("Model") then
			local cf, size = m:GetBoundingBox()
			local p = cf.Position
			local inside = p.X > s.x0 + 1 and p.X < s.x1 - 1 and p.Z > s.z0 + 1 and p.Z < s.z1 - 1
			assert(not inside, m.Name .. " ended up inside the building")
			assert(size.Magnitude < 20, m.Name .. " is implausibly large")
		end
	end
end

return T

