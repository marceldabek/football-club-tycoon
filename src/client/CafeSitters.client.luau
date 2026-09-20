--!strict
-- Cafe sitters (roadmap F3, backlog F3.2): a few people sitting at the cafe
-- tables ForecourtDresser puts outside cafes and pubs, all day, near the
-- camera only. Client-only; off on Quality "Low". Figures and pose maths are
-- Shared.Townsfolk's (X371): no more block people.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local town = workspace:WaitForChild("Town", math.huge)
local Townsfolk = require(script.Parent:WaitForChild("Townsfolk"))

local RADIUS = 200 -- TEMP studs from the camera
local MAX_SETS = 5 -- TEMP cafe sets with sitters at once
local RECHECK = 2 -- seconds

local folder = Instance.new("Folder")
folder.Name = "CafeSitters"
folder.Parent = workspace

local sets: { [Model]: boolean } = {}
local seated: { [Model]: Model } = {} -- cafe set -> its sitters

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "CafeSet" then
		sets[inst] = true
	end
end
for _, d in town:GetDescendants() do
	consider(d)
end
town.DescendantAdded:Connect(consider)
town.DescendantRemoving:Connect(function(inst)
	if inst:IsA("Model") and inst.Name == "CafeSet" then
		sets[inst] = nil
		local m = seated[inst]
		if m then
			m:Destroy()
			seated[inst] = nil
		end
	end
end)

local function seatSitters(set: Model): Model?
	local table_ = set:FindFirstChild("TableTop")
	if not (table_ and table_:IsA("BasePart")) then
		return nil
	end
	local rng = Random.new(math.floor(table_.Position.X * 7 + table_.Position.Z * 13))
	local m = Instance.new("Model")
	m.Name = "Sitters"
	local placed = 0
	for _, seatPart in set:GetChildren() do
		if not (seatPart:IsA("BasePart") and seatPart.Name == "Seat") then
			continue
		end
		-- one in three seats stays empty, but every set gets at least one person
		if placed > 0 and rng:NextNumber() < 0.34 then
			continue
		end
		local top = seatPart.Position + Vector3.new(0, seatPart.Size.Y / 2, 0)
		local toTable = Vector3.new(table_.Position.X - top.X, 0, table_.Position.Z - top.Z)
		if toTable.Magnitude < 1e-3 then
			continue
		end
		-- Townsfolk.poseSeated wants -Z facing the view: seat's own -Z faces the table
		local seat = CFrame.lookAt(top, top + toTable.Unit)
		local fig = Townsfolk.build(m, {
			skin = Townsfolk.pick(Townsfolk.SKIN, rng),
			shirt = Townsfolk.pick(Townsfolk.SHIRTS, rng),
			trousers = Townsfolk.pick(Townsfolk.TROUSERS, rng),
		})
		if fig then
			Townsfolk.poseSeated(fig, seat)
			placed += 1
		end
	end
	m.Parent = folder
	return m
end

local function refresh()
	local low = player:GetAttribute("Quality") == "Low"
	local cam = workspace.CurrentCamera.CFrame.Position
	local ranked = {}
	if not low then
		for set in sets do
			local t = set:FindFirstChild("TableTop")
			if set.Parent and t and t:IsA("BasePart") then
				local d = (t.Position - cam).Magnitude
				if d <= RADIUS then
					table.insert(ranked, { set = set, d = d })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.d < b.d
		end)
	end
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(MAX_SETS, #ranked) do
		keep[ranked[i].set] = true
	end
	for set, m in seated do
		if not keep[set] then
			m:Destroy()
			seated[set] = nil
		end
	end
	for set in keep do
		if not seated[set] then
			local m = seatSitters(set)
			if m then
				seated[set] = m
			end
		end
	end
end

while true do
	refresh()
	task.wait(RECHECK)
end
