--!strict
-- Bus-stop fast travel (backlog E7.2, CLAUDE.md s27 "bus stops that fast-travel
-- to other clubs, the town centre and landmarks").
--
-- Every model under workspace.Town.BusStops (built by TownBuilder.buildBusStop)
-- gets a ProximityPrompt. Triggering it fires BusMenu at the player with the
-- live destination list; picking one fires BusTravel back, which teleports the
-- character to stand in front of the chosen shelter.
--
-- destinationsFor is the pure part: no Instance/workspace access, so it is
-- tested directly (tests/BusServiceTest.luau). BusService.start() is the only
-- function that touches the game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local BusService = {}

export type Kind = "club" | "town"
export type Destination = { name: string, kind: Kind, label: string }

local COOLDOWN = 3 -- seconds per player (backlog E7.2)
local TRIGGER_RANGE = 20 -- studs, anti-teleport-abuse re-check on BusTravel
local STAND_OFFSET = 5 -- studs in front of the shelter, along local -Z
local STAND_Y = 3.5

-- name -> BusStop, built once from pure layout data (no Instance access).
local stopByName: { [string]: TownLayout.BusStop } = {}
for _, stop in TownLayout.BUS_STOPS do
	stopByName[stop.name] = stop
end

-- "Plot 3" -> 3, or nil if `name` is not a plot stop.
local function plotIndexOf(name: string): number?
	local digits = name:match("^Plot (%d+)$")
	return digits and tonumber(digits)
end

local function byLabel(a: Destination, b: Destination): boolean
	return a.label:lower() < b.label:lower()
end

-- Pure: the ordered destination list for a BusMenu opened at `fromName`.
-- clubNames[i] is plot i's current club name (ReplicatedStorage.Clubs.PlotI's
-- ClubName attribute), or nil/empty when the plot is unclaimed. Clubs come
-- first (alphabetical by label), then town stops (alphabetical); `fromName`
-- itself is never included.
function BusService.destinationsFor(fromName: string, clubNames: { [number]: string? }): { Destination }
	local clubs: { Destination } = {}
	local town: { Destination } = {}
	for _, stop in TownLayout.BUS_STOPS do
		if stop.name == fromName then
			continue
		end
		local plot = plotIndexOf(stop.name)
		if plot then
			local owned = clubNames[plot]
			local label = if owned and owned ~= "" then owned else ("%s (for sale)"):format(stop.name)
			table.insert(clubs, { name = stop.name, kind = "club" :: Kind, label = label })
		else
			table.insert(town, { name = stop.name, kind = "town" :: Kind, label = stop.name })
		end
	end
	table.sort(clubs, byLabel)
	table.sort(town, byLabel)
	local out: { Destination } = {}
	for _, d in clubs do
		table.insert(out, d)
	end
	for _, d in town do
		table.insert(out, d)
	end
	return out
end

-- ------------------------------------------------------------------- runtime

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

local function remote(name: string): RemoteEvent
	local remotes = findOrCreate(ReplicatedStorage, "Remotes", "Folder")
	return findOrCreate(remotes, name, "RemoteEvent") :: RemoteEvent
end

local function toast(player: Player, message: string)
	remote("Toast"):FireClient(player, message, false)
end

-- Live club name per plot, read straight from the replicated state folders
-- PlotContext.stateFolder() maintains (ReplicatedStorage.Clubs.PlotN).
local function currentClubNames(): { [number]: string? }
	local names: { [number]: string? } = {}
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	for i = 1, #TownLayout.PLOTS do
		local folder = clubs and clubs:FindFirstChild("Plot" .. i)
		local name = folder and folder:GetAttribute("ClubName")
		names[i] = if type(name) == "string" and name ~= "" then name else nil
	end
	return names
end

-- v3: StreetFurniture snaps each stop's kit shelter onto the nearest pavement, which
-- can be tens of studs from TownLayout.BUS_STOPS' position. Once start() has found
-- the shelters, shelterAt[name] is where the stop really is.
local shelterAt: { [string]: Vector3 } = {}
BusService.SHELTER_SEARCH = 300 -- FurniturePlan slides a shelter up to 240 along its road
BusService.SHELTER_STAND = 3.5 -- studs from the shelter toward the kerb

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Pure: nearest point on any non-lane carriageway centreline to `p` (Y ignored).
function BusService.nearestRoadPoint(p: Vector3, roads: { TownLayout.Road }): Vector3?
	local best: Vector3? = nil
	local bestD = math.huge
	for _, road in roads do
		if road.kind == "lane" then
			continue
		end
		for i = 1, #road.points - 1 do
			local a, b = flat(road.points[i]), flat(road.points[i + 1])
			local ab = b - a
			local len2 = ab:Dot(ab)
			local t = if len2 > 0 then math.clamp((flat(p) - a):Dot(ab) / len2, 0, 1) else 0
			local q = a + ab * t
			local d = (flat(p) - q).Magnitude
			if d < bestD then
				best, bestD = q, d
			end
		end
	end
	return best
end

-- Pure: where a traveller arrives at a kit shelter standing at `shelter`: a few
-- studs toward the road, looking back at the shelter.
function BusService.shelterStand(shelter: Vector3, roads: { TownLayout.Road }): CFrame
	local at = Vector3.new(shelter.X, STAND_Y, shelter.Z)
	local roadPoint = BusService.nearestRoadPoint(shelter, roads)
	local toRoad = if roadPoint then flat(roadPoint - shelter) else Vector3.zero
	if toRoad.Magnitude < 0.01 then
		return CFrame.new(at)
	end
	local stand = at + toRoad.Unit * BusService.SHELTER_STAND
	return CFrame.lookAt(stand, at)
end

-- Pure: the nearest of `shelters` to `stop`, or nil when none is within range.
function BusService.nearestShelter(stop: Vector3, shelters: { Vector3 }, range: number): Vector3?
	local best: Vector3? = nil
	local bestD = range
	for _, s in shelters do
		local d = flat(s - stop).Magnitude
		if d <= bestD then
			best, bestD = s, d
		end
	end
	return best
end

local function stopPosition(stop: TownLayout.BusStop): Vector3
	return shelterAt[stop.name] or stop.position
end

local function nearAnyStop(character: Model, range: number): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, stop in TownLayout.BUS_STOPS do
		if flat(root.Position - stopPosition(stop)).Magnitude <= range then
			return true
		end
	end
	return false
end

-- Standing point 5 studs in front of the shelter (local -Z of the stop frame,
-- the same convention TownBuilder.buildBusStop uses), facing back toward it.
local function travelCFrame(stop: TownLayout.BusStop): CFrame
	local shelter = shelterAt[stop.name]
	if shelter then
		return BusService.shelterStand(shelter, TownLayout.ROADS)
	end
	local frame = CFrame.new(stop.position) * CFrame.Angles(0, math.rad(stop.yaw), 0)
	local standPos = (frame * CFrame.new(0, 0, -STAND_OFFSET)).Position
	local facing = frame.Rotation * CFrame.Angles(0, math.pi, 0)
	return CFrame.new(standPos.X, STAND_Y, standPos.Z) * facing
end

function BusService.start()
	local menuEvent = remote("BusMenu")
	local travelEvent = remote("BusTravel")
	local lastTravel: { [number]: number } = {}

	local function openMenu(player: Player, stopName: string)
		local stop = stopByName[stopName]
		menuEvent:FireClient(player, {
			from = stopName,
			destinations = BusService.destinationsFor(stopName, currentClubNames()),
			-- the client closes the card once the player walks out of travel range
			stopPosition = if stop then stopPosition(stop) else nil,
		})
	end

	local town = workspace:WaitForChild("Town")
	local stops = town:WaitForChild("BusStops")

	-- v3: find the kit shelters StreetFurniture placed and move each stop onto its own
	local shelters: { Vector3 } = {}
	local furniture = town:FindFirstChild("V3Furniture")
	if furniture then
		for _, d in furniture:GetDescendants() do
			if d:IsA("Model") and d.Name == "shelter" then
				table.insert(shelters, d:GetPivot().Position)
			end
		end
	end
	local snapped = 0
	for _, stop in TownLayout.BUS_STOPS do
		local s = BusService.nearestShelter(stop.position, shelters, BusService.SHELTER_SEARCH)
		if s then
			shelterAt[stop.name] = s
			snapped += 1
		else
			warn(("[FCT] BusService: no kit shelter near %q, using its layout position"):format(stop.name))
		end
	end
	print(("[FCT] BusService: %d of %d stops on a kit shelter"):format(snapped, #TownLayout.BUS_STOPS))

	for _, stopModel in stops:GetChildren() do
		if not stopModel:IsA("Model") then
			continue
		end
		local stopName = stopModel:GetAttribute("BusStop")
		if type(stopName) ~= "string" then
			continue
		end
		local signPart = (stopModel:FindFirstChild("Sign") :: BasePart?) or stopModel:FindFirstChildWhichIsA("BasePart")
		if not signPart then
			continue
		end
		local shelter = shelterAt[stopName]
		if shelter then
			signPart.CFrame = CFrame.new(shelter.X, 4, shelter.Z)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Catch the bus"
		prompt.ObjectText = stopName
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = signPart
		prompt.Triggered:Connect(function(player: Player)
			openMenu(player, stopName)
		end)
	end

	travelEvent.OnServerEvent:Connect(function(player: Player, rawDestination: unknown)
		if type(rawDestination) ~= "string" then
			return
		end
		local stop = stopByName[rawDestination]
		if not stop then
			toast(player, "That bus doesn't run there.")
			return
		end
		local character = player.Character
		if not character or not nearAnyStop(character, TRIGGER_RANGE) then
			toast(player, "Get to a bus stop first.")
			return
		end
		local now = os.clock()
		local last = lastTravel[player.UserId]
		if last and now - last < COOLDOWN then
			toast(player, "Wait a moment.")
			return
		end
		lastTravel[player.UserId] = now
		character:PivotTo(travelCFrame(stop))
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastTravel[player.UserId] = nil
	end)
end

return BusService
