--!strict
-- Where the stand fans sit, and how the server tells the clients (#6).
-- Pure: no services, so tests can check the layout.
--
-- The server (WorldBuilder.buildCrowd) decides WHICH seats are taken and in
-- what shirt, because it owns the stand geometry and the attendance. It no
-- longer builds the fans: it writes one packed string per stand to the Crowd
-- folder's "Seats" attribute, and every client builds the fans from it with
-- the shared avatar rig (client Townsfolk, via StandCrowd). That is what lets
-- the stand crowd be the same HumanoidDescription avatars as every other NPC
-- (#6c) without replicating thousands of parts.
--
-- Seats only ever sit inside a seat block, never on the aisle steps between
-- blocks (#6a), and at SPACING apart so shoulders never meet (#6b).

local CrowdSeats = {}

-- Seat blocks and the aisles between them. WorldBuilder.buildPlot lays the
-- seats and aisle treads from these same numbers.
CrowdSeats.SECTION_LEN = 26
CrowdSeats.AISLE_W = 3

-- #6b: an R6 avatar is 4 studs across the arms (torso 2 + an arm each side),
-- so fans closer than that met at the shoulder. 0.4 of air between them.
CrowdSeats.FAN_WIDTH = 4
CrowdSeats.SPACING = 4.4

-- TEMP: the most fans the server ever seats across a whole ground. The client
-- builds at most its Quality budget (Quality.BUDGETS.standFans) of these; High
-- matches this so a sell-out on High shows every seat the server picked.
CrowdSeats.MAX_FANS = 420

-- Hips above the step the fan's feet rest on: the seat cushion on a seated
-- stand, the plank bench on the level-1 bleachers (WorldBuilder.buildPlot).
CrowdSeats.SEAT_DROP = 1.1
CrowdSeats.BENCH_DROP = 0.4
-- Hips this far in front of the back edge of the step: the torso's back then
-- touches the seat back (0.3 deep at the back of the step).
CrowdSeats.HIP_FROM_BACK = 0.8

-- The seat blocks along one run of terrace from z0 to z1, as { a, b } spans.
-- `seated` is false on the level-1 bleachers: one plank bench, 1 stud in from
-- each end, no aisles.
function CrowdSeats.sections(z0: number, z1: number, seated: boolean): { { number } }
	if not seated then
		return { { z0 + 1, z1 - 1 } }
	end
	local runLen = z1 - z0
	local w, len = CrowdSeats.AISLE_W, CrowdSeats.SECTION_LEN
	local count = math.max(1, math.floor((runLen + w) / (len + w) + 0.5))
	local secLen = (runLen - (count - 1) * w) / count
	local spans = {}
	for s = 1, count do
		local a = z0 + (s - 1) * (secLen + w)
		table.insert(spans, { a, a + secLen })
	end
	return spans
end

-- Seat centres along one block from a to b, `nudge` in from `a` (rows are
-- offset a little so seats never line up into columns). Every fan's full
-- width stays inside the block.
function CrowdSeats.seatsIn(a: number, b: number, nudge: number, spacing: number?): { number }
	local step = spacing or CrowdSeats.SPACING
	local out = {}
	local n = math.floor((b - a - nudge) / step)
	for i = 1, n do
		table.insert(out, a + nudge + step * (i - 0.5))
	end
	return out
end

-- Whether a client with `budget` fans to spend builds the seat with this
-- `seed`. A fixed fraction of MAX_FANS rather than of today's crowd, so a
-- growing crowd (the three-stage fill) only ever adds fans on screen.
function CrowdSeats.keep(seed: number, budget: number): boolean
	if budget >= CrowdSeats.MAX_FANS then
		return true
	end
	return (seed % 1009) / 1009 < budget / CrowdSeats.MAX_FANS
end

-- ------------------------------------------------------------------- codec

export type Seat = {
	position: Vector3, -- the hips, on the seat
	yaw: number, -- radians about Y; the fan faces the pitch
	shirt: Color3,
	seed: number, -- stable per seat: which fans a budget keeps, and their look
}

local function hex(c: Color3): string
	return string.format("%02x%02x%02x", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- "x,y,z,yaw,rrggbb,seed" per seat, ";" between seats. About 40 bytes a fan.
function CrowdSeats.encode(seats: { Seat }): string
	local parts = table.create(#seats)
	for i, s in seats do
		parts[i] = string.format("%.2f,%.2f,%.2f,%.3f,%s,%d", s.position.X, s.position.Y, s.position.Z, s.yaw, hex(s.shirt), s.seed)
	end
	return table.concat(parts, ";")
end

function CrowdSeats.decode(text: string?): { Seat }
	local out: { Seat } = {}
	if type(text) ~= "string" or text == "" then
		return out
	end
	for x, y, z, yaw, colour, seed in string.gmatch(text, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),(%x%x%x%x%x%x),(%d+)") do
		table.insert(out, {
			position = Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number),
			yaw = tonumber(yaw) :: number,
			shirt = Color3.fromHex(colour),
			seed = tonumber(seed) :: number,
		})
	end
	return out
end

return CrowdSeats
