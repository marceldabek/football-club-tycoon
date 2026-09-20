--!strict
-- People sitting on park benches (backlog X185, RivermereRiverside.png's
-- benches in use). Client-only, like CafeSitters: of the kit park benches
-- ("UKSP__ParkBenches__ParkBench01") within RADIUS of the camera, the nearest
-- MAX_BENCHES are considered and about half get one or two sitters, chosen
-- stably from the bench's position. Off on Quality "Low". Figures and pose
-- maths are Shared.Townsfolk's (X371): no more block people.
--
-- The kit bench is one MeshPart: its seat faces the model pivot's LookVector
-- and the seat top is about SEAT_Y above the pivot (ground level).

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

local BENCH_KIT = "UKSP__ParkBenches__ParkBench01"
local RADIUS = 200 -- TEMP
local MAX_BENCHES = 8 -- TEMP benches considered at once
local RECHECK = 2
local SEAT_Y = 1.45
local SEAT_Z = 0.15 -- seat centre forward of the pivot, towards the view
-- Two-sitter spacing (X371): a real R6 figure is ~4 studs shoulder-to-shoulder
-- (Townsfolk.ARM_X + half Townsfolk.ARM_SIZE.X either side of centre), wider
-- than the old 6-part figure it replaces. The old +-1.6 spots (3.2 apart)
-- overlapped by about 0.8 studs; +-2.2 (4.4 apart) clears them with room.
local PAIR_SPOT = 2.2

local folder = Instance.new("Folder")
folder.Name = "BenchSitters"
folder.Parent = workspace

local benches: { [Model]: boolean } = {}
local seated: { [Model]: Model } = {}

local function consider(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("Kit") == BENCH_KIT then
		benches[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)

-- nil when this bench stays empty
local function seatSitters(bench: Model): Model?
	local pivot = bench:GetPivot()
	local rng = Random.new(math.floor(math.abs(pivot.X) * 7 + math.abs(pivot.Z) * 13))
	if rng:NextNumber() < 0.5 then
		return nil
	end
	local spots = if rng:NextNumber() < 0.4 then { -PAIR_SPOT, PAIR_SPOT } else { rng:NextNumber(-1.8, 1.8) }
	local m = Instance.new("Model")
	m.Name = "Sitters"
	for _, x in spots do
		-- Townsfolk.poseSeated wants -Z facing the view: the bench pivot's own -Z
		local seat = pivot * CFrame.new(x, SEAT_Y, -SEAT_Z)
		local fig = Townsfolk.build(m, {
			skin = Townsfolk.pick(Townsfolk.SKIN, rng),
			shirt = Townsfolk.pick(Townsfolk.SHIRTS, rng),
			trousers = Townsfolk.pick(Townsfolk.TROUSERS, rng),
		})
		if fig then
			Townsfolk.poseSeated(fig, seat)
		end
	end
	m.Parent = folder
	return m
end

local empty: { [Model]: boolean } = {} -- benches already rolled empty

local function refresh()
	local low = player:GetAttribute("Quality") == "Low"
	local camera = workspace.CurrentCamera
	local cam = if camera then camera.CFrame.Position else Vector3.zero
	local ranked = {}
	if not low then
		for bench in benches do
			if not bench.Parent then
				benches[bench] = nil
			else
				local d = (bench:GetPivot().Position - cam).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { bench = bench, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
	end
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(MAX_BENCHES, #ranked) do
		keep[ranked[i].bench] = true
	end
	for bench in empty do
		if not keep[bench] then
			empty[bench] = nil
		end
	end
	for bench, m in seated do
		if not keep[bench] then
			m:Destroy()
			seated[bench] = nil
		end
	end
	for bench in keep do
		if not seated[bench] and not empty[bench] then
			local m = seatSitters(bench)
			if m then
				seated[bench] = m
			else
				empty[bench] = true
			end
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
