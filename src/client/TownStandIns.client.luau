--!strict
-- #27: shows the server's low-detail town (workspace.Town.StandIns, always
-- loaded) only where the real buildings aren't streamed in. A lot model and
-- its stand-in blocks share a StandInId attribute (TownStandIns.luau); an
-- Atomic lot streams in and out as one piece, so when it arrives its blocks
-- are hidden, and when it leaves they come back.

local ATTRIBUTE = "StandInId"

local town = workspace:WaitForChild("Town", math.huge)

local blocks: { [number]: { BasePart } } = {}
local present: { [number]: number } = {} -- lot models streamed in, by id

local function apply(id: number)
	local hidden = (present[id] or 0) > 0
	for _, p in blocks[id] or {} do
		p.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

local function addBlock(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local id = inst:GetAttribute(ATTRIBUTE)
	if type(id) ~= "number" then
		return
	end
	local list = blocks[id]
	if not list then
		list = {}
		blocks[id] = list
	end
	table.insert(list, inst)
	apply(id)
end

local function lotId(inst: Instance): number?
	if not inst:IsA("Model") then
		return nil
	end
	local id = inst:GetAttribute(ATTRIBUTE)
	return if type(id) == "number" then id else nil
end

local function lotAdded(inst: Instance)
	local id = lotId(inst)
	if id then
		present[id] = (present[id] or 0) + 1
		apply(id)
	end
end

local function lotRemoving(inst: Instance)
	local id = lotId(inst)
	if id then
		present[id] = math.max(0, (present[id] or 0) - 1)
		apply(id)
	end
end

town.DescendantAdded:Connect(lotAdded)
town.DescendantRemoving:Connect(lotRemoving)
for _, d in town:GetDescendants() do
	lotAdded(d)
end

-- The stand-ins are built after the town, so they may arrive after this runs.
local function watch(model: Instance)
	model.ChildAdded:Connect(addBlock)
	for _, p in model:GetChildren() do
		addBlock(p)
	end
end
local existing = town:FindFirstChild("StandIns")
if existing then
	watch(existing)
else
	local conn: RBXScriptConnection
	conn = town.ChildAdded:Connect(function(child)
		if child.Name == "StandIns" then
			conn:Disconnect()
			watch(child)
		end
	end)
end
