--!strict
-- Presentation layer for a match. Receives the sim's timeline (GOAL / MISS /
-- SAVE chances at football minutes) and turns it into block footballers moving
-- between formation zones, scripted pass chains, shots, keeper dives and
-- celebrations. Purely visual: nothing here affects the result.
--
-- Runs entirely on each client, synchronised to the server's KickoffAt time.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Footballer = require(script.Parent.Footballer)
local ClubRef = require(script.Parent.ClubRef)
local MatchAudio = require(script.Parent.MatchAudio)

local Presenter = {}
Presenter.__index = Presenter

type Player = { name: string, number: number, role: string, look: number? }
type Event = { minute: number, team: Pitch.Team, type: string, scorer: number? }
export type Timeline = {
	events: { Event },
	home: { name: string, kit: { number }, squad: { Player } },
	away: { name: string, kit: { number }, squad: { Player } },
}

type Team = {
	kit: Color3,
	keeperKit: Color3,
	squad: { Player },
	players: { [number]: Footballer.Footballer }, -- keyed by formation slot 1..11
	bench: { [number]: Footballer.Footballer }, -- keyed by squad index 12..n
	benchSeats: { [number]: Vector3 }, -- where each of them is sitting
	slots: { Vector3 },
	push: number, -- extra shift toward the goal being attacked, in studs
}

type Holder = { team: Pitch.Team, idx: number }
-- X315: the three people on the pitch nobody had built. `half` is the end an
-- assistant covers (-1 = the Home end), flipped at half-time with the teams.
type Assistant = { fb: Footballer.Footballer, side: number, half: number }
type Officials = { ref: Footballer.Footballer, assistants: { Assistant }, refHoldUntil: number }
-- ground: rolls with ease-out at rest height; air: lofted along an arc.
type Flight = { from: Vector3, to: Vector3, t: number, dur: number, arc: number, kind: "ground" | "air", onArrive: (() -> ())? }

export type Presenter = typeof(setmetatable(
	{} :: {
		folder: Folder,
		teams: { [Pitch.Team]: Team },
		ball: Part,
		flight: Flight?,
		holder: Holder?,
		events: { Event },
		duration: number,
		mode: "walkout" | "play" | "ended",
		heartbeat: RBXScriptConnection?,
		appliedSubs: number,
		swapped: boolean, -- second half: teams attack the opposite ends
		homeTactic: Pitch.Tactic,
		ballRot: CFrame, -- accumulated rolling rotation
		ballPos: Vector3, -- pitch-local ball position (the part itself sits in the plot)
		dribbleT: number, -- time since the carrier last knocked the ball ahead
		settleUntil: number, -- first touch: the ball sits still until this clock time
		officials: Officials?, -- X315: referee and two assistants
	},
	Presenter
))

-- TEMP tuning
local WALK_SPEED = 14
local RUN_SPEED = 22
local PASS_SPEED = 110
local SEQUENCE_LEAD = 4.5 -- seconds before the event minute that its build-up starts
local FILLER_INTERVAL = 1.6
local CELEBRATE_SECONDS = 1.8
local RESET_SECONDS = 1.0
local HALFTIME_SECONDS = 2.0
-- How far each line follows the ball up and down the pitch (fraction of the
-- distance). Defenders hold, forwards chase, so the shape stays a shape.
local ROLE_SHIFT: { [string]: number } = { DEF = 0.1, MID = 0.18, FWD = 0.24 }
local MAX_SHIFT = 22
local DRIBBLE_SPEED = 13 -- the ball carrier keeps moving toward goal
local LEAD_DISTANCE = 7 -- passes go into space ahead of the receiver
-- X315: twenty-two footballers, a whistle in Config.Sounds and nobody in
-- black, so a goal was given by the scoreboard alone. A referee on the usual
-- corner-to-corner diagonal, keeping the ball between him and the nearer
-- assistant, and two assistants on opposite touchlines, one to each half.
-- All TEMP numbers.
local OFFICIAL_BLACK = Color3.fromRGB(26, 28, 32) -- the referee
local OFFICIAL_HI = Color3.fromRGB(206, 228, 62) -- the assistants, fluoro
local REF_SPEED = 19 -- slower than the players, which is the point
local REF_DIAGONAL = 32 -- how far the diagonal swings either side of centre
local REF_TRAIL = 9 -- studs behind the ball, so he is never in the way
local ASSISTANT_SPEED = 17
local ASSISTANT_X = Pitch.WIDTH / 2 + 3 -- just off the touchline, on the turf
local DRIFT_MIN, DRIFT_MAX = 1.5, 3.5 -- seconds between a player picking a new spot
-- Ball (TEMP): a real ball is 0.6 studs at this scale; slightly larger reads better.
local BALL_R = 0.45
local BALL_REST = Pitch.SURFACE_Y + BALL_R
local GROUND_PASS_MAX = 80 -- passes up to this length (~30 m) roll; longer ones are lofted
local GROUND_SPEED = 55 -- studs/s average for a rolled pass
local TOUCH_AHEAD = 1.1 -- how far in front of the carrier's feet the ball sits
local DRIBBLE_KNOCK = 3.5 -- studs the carrier pushes the ball ahead while running
local DRIBBLE_PERIOD = 0.6
local FIRST_TOUCH = 0.15 -- seconds the ball sits still after a pass arrives
local SWITCH_CHANCE = 0.15 -- long diagonal instead of a short pass
local INTERCEPT_CHANCE = 0.2 -- short pass read by the nearest opponent

-- per-footballer countdown until they drift to a new spot
local driftClock: { [Footballer.Footballer]: number } = setmetatable({}, { __mode = "k" }) :: any
local KEEPER_KITS = { Home = Color3.fromRGB(60, 200, 90), Away = Color3.fromRGB(255, 140, 0) }

local function other(team: Pitch.Team): Pitch.Team
	return team == "Home" and "Away" or "Home"
end

local function attackDir(team: Pitch.Team): number
	return team == "Home" and -1 or 1
end

local function toColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function centre(): Vector3
	return Vector3.new(0, Pitch.SURFACE_Y, 0)
end

local function makeBall(parent: Instance): Part
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(BALL_R * 2, BALL_R * 2, BALL_R * 2)
	ball.Color = Color3.new(1, 1, 1)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = true
	ball.CFrame = ClubRef.presentFrame() * CFrame.new(centre() + Vector3.new(0, BALL_R, 0))
	ball.Parent = parent
	-- dark patches half-sunk into the surface so the roll is visible; they are
	-- unanchored and welded, so they follow the anchored ball's CFrame
	for _, offset in { Vector3.new(0.3, 0.25, 0.2), Vector3.new(-0.25, -0.2, 0.3), Vector3.new(0.05, 0.3, -0.35), Vector3.new(-0.3, -0.1, -0.25) } do
		local patch = Instance.new("Part")
		patch.Name = "Patch"
		patch.Shape = Enum.PartType.Ball
		patch.Size = Vector3.new(0.34, 0.34, 0.34)
		patch.Color = Color3.fromRGB(25, 25, 25)
		patch.Material = Enum.Material.SmoothPlastic
		patch.CanCollide = false
		patch.CanQuery = false
		patch.CanTouch = false
		patch.Massless = true
		patch.CFrame = ball.CFrame * CFrame.new(offset)
		patch.Parent = ball
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ball
		weld.Part1 = patch
		weld.Parent = patch
	end
	return ball
end

local function clampToPitch(p: Vector3): Vector3
	return Vector3.new(
		math.clamp(p.X, -Pitch.WIDTH / 2 + 6, Pitch.WIDTH / 2 - 6),
		p.Y,
		math.clamp(p.Z, -Pitch.LENGTH / 2 + 8, Pitch.LENGTH / 2 - 8)
	)
end

local function restAt(p: Vector3): Vector3
	return Vector3.new(p.X, BALL_REST, p.Z)
end

function Presenter.new(timeline: Timeline, duration: number): Presenter
	local folder = Instance.new("Folder")
	folder.Name = "MatchVisuals"
	folder.Parent = workspace

	local self = setmetatable({
		folder = folder,
		teams = {} :: { [Pitch.Team]: Team },
		ball = makeBall(folder),
		flight = nil,
		holder = nil,
		events = timeline.events,
		duration = duration,
		mode = "walkout" :: "walkout" | "play" | "ended",
		heartbeat = nil,
		appliedSubs = 0,
		swapped = false,
		homeTactic = "Balanced" :: Pitch.Tactic,
		ballRot = CFrame.identity,
		ballPos = centre() + Vector3.new(0, BALL_R, 0), -- pitch-local; the part is in the plot
		dribbleT = 0,
		settleUntil = 0,
	}, Presenter)

	for _, teamName in { "Home" :: Pitch.Team, "Away" :: Pitch.Team } do
		local data = teamName == "Home" and timeline.home or timeline.away
		local kit = toColor(data.kit)
		local team: Team = {
			kit = kit,
			keeperKit = KEEPER_KITS[teamName],
			squad = data.squad,
			players = {},
			bench = {},
			benchSeats = {},
			slots = Pitch.formationSlots(teamName, "Balanced"),
			push = 0,
		}
		for idx = 1, #Pitch.ROLES do
			local p = data.squad[idx]
			team.players[idx] = Footballer.new(folder, idx == 1 and team.keeperKit or kit, p.number, p.name, Pitch.TUNNEL, p.look, idx == 1)
		end
		-- Substitutes sit in the dugout for the whole match, which is what
		-- makes a substitution read: one of them gets up and walks on.
		for idx = #Pitch.ROLES + 1, #data.squad do
			local p = data.squad[idx]
			local seat = Pitch.benchSeat(teamName, idx - #Pitch.ROLES)
			local fb = Footballer.new(folder, kit, p.number, p.name, seat, p.look, false)
			fb:setTagVisible(false)
			fb:face(centre())
			fb:sit()
			team.bench[idx] = fb
			team.benchSeats[idx] = seat
		end
		self.teams[teamName] = team
	end

	self:buildOfficials()

	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end)
	return self
end

-- X315: the referee at the edge of the centre circle and an assistant at
-- halfway on each touchline, which is where they stand for the walkout.
function Presenter.buildOfficials(self: Presenter)
	local ref = Footballer.new(self.folder, OFFICIAL_BLACK, 0, "Referee", Vector3.new(10, Pitch.SURFACE_Y, 12), 3, false)
	ref:setTagVisible(false)
	ref.speed = REF_SPEED
	local assistants: { Assistant } = {}
	for i = 1, 2 do
		local side = if i == 1 then 1 else -1
		local fb = Footballer.new(self.folder, OFFICIAL_HI, 0, "Assistant", Vector3.new(side * ASSISTANT_X, Pitch.SURFACE_Y, 0), 6 + i, false)
		fb:setTagVisible(false)
		fb.speed = ASSISTANT_SPEED
		fb:face(centre())
		table.insert(assistants, { fb = fb, side = side, half = if i == 1 then -1 else 1 })
	end
	self.officials = { ref = ref, assistants = assistants, refHoldUntil = 0 }
end

-- Where the referee's diagonal runs at this end of the pitch.
local function diagonalX(z: number): number
	return (z / (Pitch.LENGTH / 2)) * REF_DIAGONAL
end

-- Follows play without joining in: the referee trails the ball along his
-- diagonal, and each assistant keeps level with the ball inside his own half.
function Presenter.updateOfficials(self: Presenter)
	local o = self.officials
	if not o then
		return
	end
	local ball = self.ballPos
	-- Review of X315: after a goal he was told to walk back to the centre spot
	-- and then re-targeted at the ball on the very next frame, so he never went.
	-- The hold is respected here.
	if os.clock() >= o.refHoldUntil then
		-- the trail is toward the half the ball is in, so he is behind play either way
		local trail = if ball.Z > 0 then REF_TRAIL else -REF_TRAIL
		o.ref:setTarget(clampToPitch(Vector3.new(
			diagonalX(ball.Z) * 0.75 + ball.X * 0.2,
			Pitch.SURFACE_Y,
			ball.Z - trail
		)))
	end
	for _, a in o.assistants do
		-- halves swap with the teams at half-time
		local half = if self.swapped then -a.half else a.half
		local lo = if half < 0 then -Pitch.LENGTH / 2 + 6 else -6
		local hi = if half < 0 then 6 else Pitch.LENGTH / 2 - 6
		a.fb:setTarget(Vector3.new(a.side * ASSISTANT_X, Pitch.SURFACE_Y, math.clamp(ball.Z, lo, hi)))
	end
end

-- Per-frame: move footballers, fly the ball, keep formation.
function Presenter.step(self: Presenter, dt: number)
	if self.mode == "play" then
		self:updateFormationTargets(dt)
		self:updateOfficials() -- X315
	end
	for _, team in self.teams do
		for _, fb in team.players do
			fb:update(dt)
		end
		for _, fb in team.bench do
			fb:update(dt)
		end
	end
	-- X315: the officials are not in a team, so they need stepping themselves
	-- (the first version only set their targets, and all three stood still on
	-- their kick-off marks for the whole match)
	local officials = self.officials
	if officials then
		officials.ref:update(dt)
		for _, a in officials.assistants do
			a.fb:update(dt)
		end
	end

	local flight = self.flight
	if flight then
		flight.t += dt
		local a = math.min(flight.t / flight.dur, 1)
		local pos
		if flight.kind == "ground" then
			pos = flight.from:Lerp(flight.to, 1 - (1 - a) ^ 2) -- ease-out: the pass slows as it runs
		else
			pos = flight.from:Lerp(flight.to, a) + Vector3.new(0, flight.arc * math.sin(a * math.pi), 0)
		end
		self:moveBall(pos, if flight.kind == "ground" then 1 else 0.3)
		if a >= 1 then
			self.flight = nil
			if flight.onArrive then
				flight.onArrive()
			end
		end
	elseif self.holder then
		local fb = self.teams[self.holder.team].players[self.holder.idx]
		if fb and os.clock() >= self.settleUntil then
			local look = CFrame.Angles(0, fb.yaw, 0)
			if self.holder.idx == 1 then
				-- keeper carries it in hand
				self:moveBall(fb.position + look.LookVector * 1.0 + Vector3.new(0, 2.4, 0), 0)
			else
				local carrying = fb.velocity.Magnitude > 3
				self.dribbleT += dt
				if carrying and self.dribbleT >= DRIBBLE_PERIOD then
					-- knock it ahead and run onto it; the holder is unchanged
					self.dribbleT = 0
					local ahead = restAt(fb.position + look.LookVector * (TOUCH_AHEAD + DRIBBLE_KNOCK) + look.RightVector * 0.35)
					self.flight = { from = self.ballPos, to = ahead, t = 0, dur = 0.35, arc = 0, kind = "ground" }
				else
					self:moveBall(restAt(fb.position + look.LookVector * TOUCH_AHEAD + look.RightVector * 0.35), 1)
				end
			end
		end
	end
end

-- Moves the ball and rolls it by the ground distance covered. `roll` scales
-- the spin (1 on the grass, less in the air, 0 when carried).
function Presenter.moveBall(self: Presenter, pos: Vector3, roll: number)
	local moved = pos - self.ballPos
	local flat = Vector3.new(moved.X, 0, moved.Z)
	if roll > 0 and flat.Magnitude > 1e-4 then
		local axis = Vector3.yAxis:Cross(flat.Unit)
		self.ballRot = CFrame.fromAxisAngle(axis, flat.Magnitude / BALL_R * roll) * self.ballRot
	end
	self.ballPos = pos
	self.ball.CFrame = ClubRef.presentFrame() * CFrame.new(pos) * self.ballRot
end

function Presenter.placeBall(self: Presenter, pos: Vector3)
	self.flight = nil
	self.ballPos = restAt(pos)
	self.ball.CFrame = ClubRef.presentFrame() * CFrame.new(self.ballPos) * self.ballRot
end

-- Which end a team attacks. In the second half the teams swap, so Home uses
-- Away's geometry and vice versa.
function Presenter.geom(self: Presenter, team: Pitch.Team): Pitch.Team
	return self.swapped and other(team) or team
end

function Presenter.refreshSlots(self: Presenter)
	self.teams.Home.slots = Pitch.formationSlots(self:geom("Home"), self.homeTactic)
	self.teams.Away.slots = Pitch.formationSlots(self:geom("Away"), "Balanced")
end

function Presenter.updateFormationTargets(self: Presenter, dt: number)
	local ballPos = self.ballPos
	for teamName, team in self.teams do
		local dir = attackDir(self:geom(teamName))
		for idx, fb in team.players do
			if fb.busy then
				continue
			end
			local isHolder = self.holder and self.holder.team == teamName and self.holder.idx == idx
			if isHolder then
				if idx == 1 then
					fb:setTarget(nil) -- keeper holds it
				else
					-- carry the ball toward goal with a little weave
					fb.speed = DRIBBLE_SPEED
					local weave = math.sin(os.clock() * 1.7 + idx) * 5
					fb:setTarget(clampToPitch(fb.position + Vector3.new(weave, 0, dir * 14)))
				end
				continue
			end
			fb.speed = RUN_SPEED

			-- every few seconds pick a new spot to drift to, so nobody stands still
			local clock = (driftClock[fb] or 0) - dt
			if clock <= 0 then
				fb.jitter = Vector3.new(math.random() * 12 - 6, 0, math.random() * 14 - 7)
				clock = DRIFT_MIN + math.random() * (DRIFT_MAX - DRIFT_MIN)
			end
			driftClock[fb] = clock

			local base = team.slots[idx]
			if idx == 1 then
				fb:setTarget(base + Vector3.new(math.clamp(ballPos.X * 0.2, -7, 7), 0, 0))
			else
				local follow = ROLE_SHIFT[Pitch.ROLES[idx]] or 0.18
				local shift = math.clamp((ballPos.Z - base.Z) * follow, -MAX_SHIFT, MAX_SHIFT) + dir * team.push
				local sway = math.clamp((ballPos.X - base.X) * 0.08, -6, 6)
				fb:setTarget(clampToPitch(base + Vector3.new(sway, 0, shift) + fb.jitter))
			end
		end
	end
end

local function setAll(self: Presenter, fn: (Pitch.Team, number, Footballer.Footballer) -> ())
	for teamName, team in self.teams do
		for idx, fb in team.players do
			fn(teamName, idx, fb)
		end
	end
end

-- Teams line up outside the tunnel, walk to the centre, then run to their
-- positions. Yields for `seconds`; ends early if start() is called.
function Presenter.walkout(self: Presenter, seconds: number)
	self.mode = "walkout"
	setAll(self, function(teamName, idx, fb)
		local side = teamName == "Home" and -2.5 or 2.5
		fb:teleport(Pitch.TUNNEL + Vector3.new(-4 * idx, 0, side))
		fb:setTagVisible(false) -- 22 tags in a line just overlap; shown at kickoff
		fb.speed = WALK_SPEED
		fb:setTarget(Vector3.new(-36 + 6 * (idx - 1), Pitch.SURFACE_Y, side * 1.6))
	end)
	local t0 = os.clock()
	while self.mode == "walkout" and os.clock() - t0 < seconds * 0.6 do
		task.wait(0.1)
	end
	setAll(self, function(teamName, idx, fb)
		fb.speed = RUN_SPEED
		fb:setTarget(self.teams[teamName].slots[idx])
	end)
	while self.mode == "walkout" and os.clock() - t0 < seconds do
		task.wait(0.1)
	end
end

-- Snap everyone into formation (late joiners / after a goal).
-- X264 (review): a celebrate pose outlives CELEBRATE_SECONDS, and the pose keeps
-- the idle track playing, so a player retargeted mid-pose slid across the pitch
-- with his feet still. Clearing the pose here puts him back on the run cycle.
function Presenter.resetToFormation(self: Presenter)
	setAll(self, function(teamName, idx, fb)
		fb.busy = false
		fb.speed = RUN_SPEED
		fb:setTagVisible(true)
		fb:stand() -- drops a celebrate pose, so nobody slides back feet-still
		fb:setTarget(self.teams[teamName].slots[idx])
	end)
end

function Presenter.setTactic(self: Presenter, tactic: Pitch.Tactic)
	self.homeTactic = tactic
	self:refreshSlots()
end

-- Whistle, everyone stops, teams are placed straight at the opposite ends and
-- Away restarts. No transition: it wasn't worth the pause. Yields ~2s.
function Presenter.halftime(self: Presenter)
	MatchAudio.whistle()
	self.holder = nil
	self.flight = nil
	setAll(self, function(_, _, fb)
		fb.busy = true
		fb:setTarget(nil)
	end)
	task.wait(1.0)
	self.swapped = true
	self:refreshSlots()
	setAll(self, function(teamName, idx, fb)
		fb:teleport(self.teams[teamName].slots[idx])
		fb:face(centre())
	end)
	self:placeBall(centre())
	self:resetToFormation()
	task.wait(HALFTIME_SECONDS - 1.0)
	self.holder = { team = "Away", idx = 7 }
end

-- Kicks the ball from the current holder (or wherever it is) to a player.
function Presenter.pass(self: Presenter, toTeam: Pitch.Team, toIdx: number, arcOverride: number?)
	local receiver = self.teams[toTeam].players[toIdx]
	local from = self.ballPos
	-- play it into space ahead of the receiver so they run onto it
	local dir = attackDir(self:geom(toTeam))
	local landing = clampToPitch(receiver.position + Vector3.new(math.random() * 6 - 3, 0, dir * LEAD_DISTANCE))
	local to = restAt(landing)
	local holder = self.holder
	if holder then
		local kicker = self.teams[holder.team].players[holder.idx]
		kicker:face(landing)
		kicker:kick()
	end
	receiver.speed = RUN_SPEED
	receiver:setTarget(landing)
	receiver.busy = true
	local dist = (to - from).Magnitude
	self.holder = nil
	-- short passes roll along the grass; long switches are lofted
	local lofted = arcOverride ~= nil or dist > GROUND_PASS_MAX
	self.flight = {
		from = from,
		to = to,
		t = 0,
		dur = if lofted then math.clamp(dist / PASS_SPEED, 0.3, 1.0) else math.clamp(dist / GROUND_SPEED, 0.3, 1.3),
		arc = if lofted then (arcOverride or math.min(dist * 0.06, 5)) else 0,
		kind = if lofted then "air" else "ground",
		onArrive = function()
			receiver.busy = false
			self.holder = { team = toTeam, idx = toIdx }
			self.dribbleT = 0
			self.settleUntil = os.clock() + FIRST_TOUCH -- first touch: the ball sits for a beat
		end,
	}
end

function Presenter.waitForBall(self: Presenter)
	while self.flight do
		task.wait()
	end
end

-- Idle possession as build-up play: short passes to a nearby teammate with a
-- forward bias, the odd long switch to the far side, and turnovers by the
-- nearest opponent reading a pass.
function Presenter.fillerPass(self: Presenter)
	local holder = self.holder
	if not holder then
		self.holder = { team = "Home", idx = 7 }
		return
	end
	local team = self.teams[holder.team]
	local from = team.players[holder.idx]
	local dir = attackDir(self:geom(holder.team))

	if holder.idx ~= 1 and math.random() < SWITCH_CHANCE then
		local far: { number } = {}
		for idx = 6, 11 do
			if idx ~= holder.idx then
				table.insert(far, idx)
			end
		end
		table.sort(far, function(a, b)
			return math.abs(team.players[a].position.X - from.position.X) > math.abs(team.players[b].position.X - from.position.X)
		end)
		self:pass(holder.team, far[1], 6)
		return
	end

	local cands: { { idx: number, score: number } } = {}
	for idx = 2, 11 do
		if idx ~= holder.idx then
			local p = team.players[idx]
			local d = (p.position - from.position).Magnitude
			local forward = (p.position.Z - from.position.Z) * dir
			table.insert(cands, { idx = idx, score = d - math.max(forward, 0) * 0.6 })
		end
	end
	table.sort(cands, function(a, b)
		return a.score < b.score
	end)
	local to = cands[math.random(1, math.min(3, #cands))].idx

	if holder.idx ~= 1 and math.random() < INTERCEPT_CHANCE then
		local oppTeam = other(holder.team)
		local mid = (from.position + team.players[to].position) / 2
		local best, bestD = 7, math.huge
		for idx = 2, 11 do
			local d = (self.teams[oppTeam].players[idx].position - mid).Magnitude
			if d < bestD then
				best, bestD = idx, d
			end
		end
		self:pass(oppTeam, best)
		return
	end
	self:pass(holder.team, to)
end

-- WorldBuilder.buildFan's part offsets from the seat frame (keep in step)
local FAN_PART_OFFSETS: { [string]: Vector3 } = {
	Torso = Vector3.new(0, 2, 0),
	ArmL = Vector3.new(-1.5, 2, 0),
	ArmR = Vector3.new(1.5, 2, 0),
	Legs = Vector3.new(0, 0.5, -1),
	Head = Vector3.new(0, 3.6, 0),
	Hair = Vector3.new(0, 4.375, 0),
}

-- X297: `away` hops the visiting end instead of the home stands. An away goal
-- used to be met by a still, silent ground; now the one pocket wearing their
-- colours goes up while the rest of the ground sits.
local function crowdReact(away: boolean?)
	if away then
		MatchAudio.nearMiss() -- the home groan still carries the moment
	else
		MatchAudio.goalCheer()
	end
	local club = ClubRef.presentModel()
	local stands = club and club:FindFirstChild("Stands")
	if not stands then
		return
	end
	local fans = {}
	for _, stand in stands:GetChildren() do
		local crowd = stand:FindFirstChild("Crowd")
		if crowd and (crowd:GetAttribute("AwayEnd") == true) == (away == true) then
			for _, fan in crowd:GetChildren() do
				table.insert(fans, fan)
			end
		end
	end
	-- X176: a crowd fan is 5-6 loose parts (WorldBuilder.buildFan), so every
	-- part of one fan must hop together: recover the seat from the part's known
	-- offset and give each seat one delay
	local seatDelay: { [Vector3]: number } = {}
	for _, fan in fans do
		if fan:IsA("BasePart") then
			local offset = FAN_PART_OFFSETS[fan.Name] or Vector3.zero
			-- the resting position, remembered on the first hop so a hop that
			-- starts mid-hop doesn't leave the part floating
			local rest = fan:GetAttribute("RestPosition")
			if typeof(rest) ~= "Vector3" then
				rest = fan.Position
				fan:SetAttribute("RestPosition", rest)
			end
			local restPos = rest :: Vector3
			local seat = (CFrame.new(restPos) * fan.CFrame.Rotation * CFrame.new(-offset)).Position
			local key = Vector3.new(math.round(seat.X * 2), math.round(seat.Y * 2), math.round(seat.Z * 2))
			local delay = seatDelay[key]
			if not delay then
				delay = math.random() * 0.35
				seatDelay[key] = delay
			end
			task.delay(delay, function()
				fan.Position = restPos
				TweenService:Create(fan, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true),
					{ Position = restPos + Vector3.new(0, 1.5, 0) }):Play()
			end)
		end
	end
end

-- Build-up, shot and outcome for one chance. `shotAt` is the server time at
-- which the server registers the event; the build-up is trimmed to fit so the
-- ball hits the net on the minute even if the director is running late.
function Presenter.playSequence(self: Presenter, ev: Event, shotAt: number)
	local team = ev.team
	local opp = other(team)
	local T = self.teams[team]
	local dir = attackDir(self:geom(team))
	T.push = 22

	local function remaining(): number
		return shotAt - workspace:GetServerTimeNow()
	end

	-- DEF -> MID -> FWD, dropping the early passes when time is short.
	local chain = {
		{ idx = math.random(2, 5), needs = 3.2 },
		{ idx = math.random(6, 9), needs = 1.9 },
		{ idx = math.random(10, 11), needs = 0 },
	}
	-- the sim names the scorer for home goals; that slot takes the shot
	if ev.scorer and T.players[ev.scorer] then
		chain[3].idx = ev.scorer
	end
	local fwd = chain[3].idx
	for _, link in chain do
		if remaining() < link.needs then
			continue
		end
		local holder = self.holder
		if not (holder and holder.team == team and holder.idx == link.idx) then
			self:pass(team, link.idx)
			self:waitForBall()
			task.wait(0.1)
		end
	end

	-- forward drives at goal with the ball if there is time
	local shooter = T.players[fwd]
	shooter.busy = true
	local driveTime = math.min(0.6, remaining() - 0.9)
	if driveTime > 0.15 then
		shooter:setTarget(shooter.position + Vector3.new(0, 0, dir * 22 * (driveTime / 0.6)))
		task.wait(driveTime)
	end
	shooter:setTarget(nil)

	local goalZ = Pitch.goalZ(self:geom(team))
	local keeper = self.teams[opp].players[1]
	local target: Vector3
	local side = math.random() < 0.5 and -1 or 1
	-- X238: square up to the shooter first, so dive left/right is relative to him
	keeper:face(shooter.position)
	if ev.type == "GOAL" then
		target = Vector3.new(side * (2 + math.random() * 6), 1.5 + math.random() * 4, goalZ + dir * 3)
		keeper:dive(-side * dir) -- wrong way
	elseif ev.type == "SAVE" then
		target = Vector3.new(side * (2 + math.random() * 5), 1.5 + math.random() * 3, goalZ - dir * 4)
		keeper.busy = true
		keeper:setTarget(Vector3.new(target.X, Pitch.SURFACE_Y, goalZ - dir * 5))
		keeper:dive(side * dir)
	else
		target = Vector3.new(side * (Pitch.GOAL_WIDTH / 2 + 5 + math.random() * 10), 2 + math.random() * 7, goalZ + dir * 14)
		keeper:dive(side * dir)
	end

	shooter:face(target)
	shooter:kick()
	local from = self.ballPos
	self.holder = nil
	self.flight = {
		from = from,
		to = target,
		t = 0,
		dur = math.clamp(remaining(), 0.4, 1.2),
		arc = 1.5,
		kind = "air",
	}
	self:waitForBall()
	shooter.busy = false
	T.push = 0

	if ev.type == "GOAL" then
		-- X315: somebody gives the goal. The whistle, then the referee jogs back
		-- to the centre spot for the restart while the scorer is celebrating.
		MatchAudio.whistle()
		local officials = self.officials
		if officials then
			-- back to the centre spot for the restart, and stay there while the
			-- scorer is celebrating
			officials.ref:setTarget(Vector3.new(6, Pitch.SURFACE_Y, 8))
			officials.refHoldUntil = os.clock() + CELEBRATE_SECONDS + 0.8
		end
		shooter:celebrate()
		-- X264: the two nearest teammates run in and celebrate with the scorer,
		-- so a goal isn't one player waving while ten others jog to their spots
		local mates = {}
		for idx, mate in T.players do
			if mate ~= shooter and idx > 1 then
				table.insert(mates, { idx = idx, d = (mate.position - shooter.position).Magnitude })
			end
		end
		table.sort(mates, function(a, b)
			return a.d < b.d
		end)
		local joined = {}
		for i = 1, math.min(2, #mates) do
			local mate = T.players[mates[i].idx]
			table.insert(joined, mate)
			mate.busy = true
			-- beside the scorer and a little behind him, in his team's own terms,
			-- and kept on the grass
			local spot = clampToPitch(shooter.position + Vector3.new(if i == 1 then -4 else 4, 0, -dir * 3))
			mate:setTarget(spot)
			-- celebrate when he could plausibly have got there, not on a fixed beat
			local travel = math.clamp((spot - mate.position).Magnitude / 22, 0.3, CELEBRATE_SECONDS - 0.5)
			task.delay(travel, function()
				if self.mode == "play" then
					mate:celebrate()
				end
			end)
		end
		-- X264/X297: an away goal was silent and nothing moved; the away end
		-- celebrates it and the home crowd groans.
		crowdReact(team ~= "Home")
		task.wait(CELEBRATE_SECONDS)
		if self.mode ~= "play" then
			return -- full time arrived during the celebration; finish() owns them now
		end
		for _, mate in joined do
			mate.busy = false
			mate:setTarget(nil)
		end
		self:resetToFormation()
		self:placeBall(centre())
		task.wait(RESET_SECONDS)
		self.holder = { team = opp, idx = 7 }
	elseif ev.type == "SAVE" then
		if team == "Home" then
			MatchAudio.nearMiss() -- X183
		end
		task.wait(0.9)
		keeper.busy = false
		self.holder = { team = opp, idx = 1 }
		task.wait(0.8)
	else
		if team == "Home" then
			MatchAudio.nearMiss() -- X183
		end
		task.wait(1.2)
		self.holder = { team = opp, idx = 1 }
		task.wait(0.6)
	end
end

-- Starts the match director; playback is synced to the server's kickoff time.
function Presenter.start(self: Presenter, kickoffAt: number)
	if self.mode == "play" then
		return
	end
	self.mode = "play"
	-- late joiner in the second half: ends are already swapped
	if workspace:GetServerTimeNow() - kickoffAt >= self.duration / 2 then
		self.swapped = true
	end
	self:refreshSlots()
	self:resetToFormation()
	self:placeBall(centre())
	self.holder = { team = self.swapped and "Away" or "Home", idx = 7 }

	task.spawn(function()
		local secondsPerMinute = self.duration / 90
		local nextEvent = 1
		local fillerAt = 1.0
		local halfDone = self.swapped
		-- skip anything a late joiner has already missed
		while self.events[nextEvent] and self.events[nextEvent].minute * secondsPerMinute < workspace:GetServerTimeNow() - kickoffAt do
			nextEvent += 1
		end
		while self.mode == "play" do
			local t = workspace:GetServerTimeNow() - kickoffAt
			if t >= self.duration then
				break
			end
			local ev = self.events[nextEvent]
			if not halfDone and t >= self.duration / 2 then
				halfDone = true
				self:halftime()
				fillerAt = workspace:GetServerTimeNow() - kickoffAt + 0.8
			elseif ev and t >= ev.minute * secondsPerMinute - SEQUENCE_LEAD then
				nextEvent += 1
				self:playSequence(ev, kickoffAt + ev.minute * secondsPerMinute)
				fillerAt = workspace:GetServerTimeNow() - kickoffAt + 0.8
			elseif t >= fillerAt then
				self:fillerPass()
				fillerAt = t + FILLER_INTERVAL
			end
			task.wait(0.1)
		end
	end)
end

-- Applies any substitutions not yet shown. `subs` is the server's full list.
-- The replacement is the footballer already sitting in the dugout: they stand
-- up and run on, and the player coming off walks over and takes their seat.
function Presenter.applySubs(self: Presenter, subs: { { out: number, ["in"]: number } })
	local team = self.teams.Home
	for i = self.appliedSubs + 1, #subs do
		local sub = subs[i]
		local outgoing = team.players[sub.out]
		local fb = team.bench[sub["in"]]
		local incoming = team.squad[sub["in"]]
		if not fb and incoming then
			-- no seat for them (a squad shorter than the bench): come out of the tunnel
			fb = Footballer.new(self.folder, team.kit, incoming.number, incoming.name, Pitch.TUNNEL, incoming.look, false)
		end
		if outgoing and fb then
			local seat = team.benchSeats[sub["in"]]
			outgoing.busy = true
			outgoing.speed = WALK_SPEED
			outgoing:setTarget(seat or Pitch.TUNNEL)
			if seat then
				task.delay(10, function()
					-- X188: full time may have sent everyone to the tunnel since
					if self.mode ~= "play" then
						return
					end
					outgoing:teleport(seat)
					outgoing:face(centre())
					outgoing:sit()
				end)
			else
				task.delay(8, function()
					outgoing:destroy()
				end)
			end
			fb:stand()
			fb:setTagVisible(true)
			fb.busy = false
			fb.speed = RUN_SPEED
			-- out to the touchline first, so they do not run through the dugout
			local slot = team.slots[sub.out]
			fb:setTarget(Vector3.new(-(Pitch.WIDTH / 2 - 3), Pitch.SURFACE_Y, (seat or slot).Z))
			task.delay(2, function()
				if self.mode == "play" then
					fb:setTarget(slot)
				end
			end)
			-- they swap places: the bench slot now belongs to the player who
			-- came off, which also keeps them in the per-frame update
			team.players[sub.out] = fb
			team.bench[sub["in"]] = if seat then outgoing else nil
		end
	end
	self.appliedSubs = #subs
end

-- Full time: everyone heads for the tunnel, then the visuals are removed.
function Presenter.finish(self: Presenter)
	self.mode = "ended"
	self.holder = nil
	self.flight = nil
	setAll(self, function(_, _, fb)
		fb.busy = true
		fb.speed = WALK_SPEED
		fb:setTarget(Pitch.TUNNEL)
	end)
	-- X315: the officials walk off as well, rather than standing there alone
	local officials = self.officials
	if officials then
		officials.ref.speed = WALK_SPEED
		officials.ref:setTarget(Pitch.TUNNEL)
		for _, a in officials.assistants do
			a.fb.speed = WALK_SPEED
			a.fb:setTarget(Pitch.TUNNEL)
		end
	end
	-- the bench gets up and goes in too
	for _, team in self.teams do
		for _, fb in team.bench do
			fb:stand()
			fb.speed = WALK_SPEED
			fb:setTarget(Pitch.TUNNEL)
		end
	end
	task.delay(6, function()
		self:destroy()
	end)
end

function Presenter.destroy(self: Presenter)
	if self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
	self.mode = "ended"
	local officials = self.officials
	if officials then
		officials.ref:destroy()
		for _, a in officials.assistants do
			a.fb:destroy()
		end
		self.officials = nil
	end
	self.folder:Destroy()
end

return Presenter
