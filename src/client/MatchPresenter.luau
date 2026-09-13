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
local MatchAudio = require(script.Parent.MatchAudio)

local Presenter = {}
Presenter.__index = Presenter

type Player = { name: string, number: number, role: string }
type Event = { minute: number, team: Pitch.Team, type: string }
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
	slots: { Vector3 },
	push: number, -- extra shift toward the goal being attacked, in studs
}

type Holder = { team: Pitch.Team, idx: number }
type Flight = { from: Vector3, to: Vector3, t: number, dur: number, arc: number, onArrive: (() -> ())? }

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
local DRIFT_MIN, DRIFT_MAX = 1.5, 3.5 -- seconds between a player picking a new spot

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
	ball.Size = Vector3.new(1.6, 1.6, 1.6)
	ball.Color = Color3.new(1, 1, 1)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Position = centre() + Vector3.new(0, 0.8, 0)
	ball.Parent = parent
	return ball
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
	}, Presenter)

	for _, teamName in { "Home" :: Pitch.Team, "Away" :: Pitch.Team } do
		local data = teamName == "Home" and timeline.home or timeline.away
		local kit = toColor(data.kit)
		local team: Team = {
			kit = kit,
			keeperKit = KEEPER_KITS[teamName],
			squad = data.squad,
			players = {},
			slots = Pitch.formationSlots(teamName, "Balanced"),
			push = 0,
		}
		for idx = 1, #Pitch.ROLES do
			local p = data.squad[idx]
			team.players[idx] = Footballer.new(folder, idx == 1 and team.keeperKit or kit, p.number, p.name, Pitch.TUNNEL)
		end
		self.teams[teamName] = team
	end

	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:step(dt)
	end)
	return self
end

-- Per-frame: move footballers, fly the ball, keep formation.
function Presenter.step(self: Presenter, dt: number)
	if self.mode == "play" then
		self:updateFormationTargets(dt)
	end
	for _, team in self.teams do
		for _, fb in team.players do
			fb:update(dt)
		end
	end

	local flight = self.flight
	if flight then
		flight.t += dt
		local a = math.min(flight.t / flight.dur, 1)
		self.ball.Position = flight.from:Lerp(flight.to, a) + Vector3.new(0, flight.arc * math.sin(a * math.pi), 0)
		if a >= 1 then
			self.flight = nil
			if flight.onArrive then
				flight.onArrive()
			end
		end
	elseif self.holder then
		local fb = self.teams[self.holder.team].players[self.holder.idx]
		if fb then
			local forward = CFrame.Angles(0, fb.yaw, 0).LookVector
			self.ball.Position = fb.position + forward * 1.3 + Vector3.new(0, 0.8, 0)
		end
	end
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

local function clampToPitch(p: Vector3): Vector3
	return Vector3.new(
		math.clamp(p.X, -Pitch.WIDTH / 2 + 6, Pitch.WIDTH / 2 - 6),
		p.Y,
		math.clamp(p.Z, -Pitch.LENGTH / 2 + 8, Pitch.LENGTH / 2 - 8)
	)
end

function Presenter.updateFormationTargets(self: Presenter, dt: number)
	local ballPos = self.ball.Position
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
function Presenter.resetToFormation(self: Presenter)
	setAll(self, function(teamName, idx, fb)
		fb.busy = false
		fb.speed = RUN_SPEED
		fb:setTagVisible(true)
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
	self.ball.Position = centre() + Vector3.new(0, 0.8, 0)
	self:resetToFormation()
	task.wait(HALFTIME_SECONDS - 1.0)
	self.holder = { team = "Away", idx = 7 }
end

-- Kicks the ball from the current holder (or wherever it is) to a player.
function Presenter.pass(self: Presenter, toTeam: Pitch.Team, toIdx: number, arcOverride: number?, throw: boolean?)
	local receiver = self.teams[toTeam].players[toIdx]
	local from = self.ball.Position
	-- play it into space ahead of the receiver so they run onto it
	local dir = attackDir(self:geom(toTeam))
	local landing = clampToPitch(receiver.position + Vector3.new(math.random() * 6 - 3, 0, dir * LEAD_DISTANCE))
	local to = landing + Vector3.new(0, 0.8, 0)
	local holder = self.holder
	if holder then
		local kicker = self.teams[holder.team].players[holder.idx]
		kicker:face(landing)
		if throw then
			kicker:throw()
		else
			kicker:kick()
		end
	end
	receiver.speed = RUN_SPEED
	receiver:setTarget(landing)
	receiver.busy = true
	local dist = (to - from).Magnitude
	self.holder = nil
	self.flight = {
		from = from,
		to = to,
		t = 0,
		dur = math.clamp(dist / PASS_SPEED, 0.3, 1.0),
		arc = arcOverride or math.min(dist * 0.06, 5),
		onArrive = function()
			receiver.busy = false
			self.holder = { team = toTeam, idx = toIdx }
		end,
	}
end

function Presenter.waitForBall(self: Presenter)
	while self.flight do
		task.wait()
	end
end

-- Kicks the ball to a point with nobody waiting for it (out of play, corners).
function Presenter.kickTo(self: Presenter, to: Vector3, arc: number, dur: number?)
	local from = self.ball.Position
	local holder = self.holder
	if holder then
		local kicker = self.teams[holder.team].players[holder.idx]
		kicker:face(to)
		kicker:kick()
	end
	self.holder = nil
	self.flight = { from = from, to = to, t = 0, dur = dur or math.clamp((to - from).Magnitude / PASS_SPEED, 0.35, 1.2), arc = arc }
end

-- Moves a footballer to a spot and yields until they are close (or timeout).
local function runTo(fb: Footballer.Footballer, spot: Vector3, timeout: number)
	fb.busy = true
	fb.speed = RUN_SPEED
	fb:setTarget(spot)
	local t0 = os.clock()
	while (Vector3.new(fb.position.X, 0, fb.position.Z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude > 2.5 and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
end

-- The holder overhits a pass across the touchline; the other side throws it in.
function Presenter.throwIn(self: Presenter)
	local holder = self.holder
	if not holder or holder.idx == 1 then
		return
	end
	local kicker = self.teams[holder.team].players[holder.idx]
	local side = kicker.position.X >= 0 and 1 or -1
	local outSpot = Vector3.new(side * (Pitch.WIDTH / 2 + 3), Pitch.SURFACE_Y + 0.8,
		math.clamp(kicker.position.Z + math.random() * 30 - 15, -Pitch.LENGTH / 2 + 15, Pitch.LENGTH / 2 - 15))
	self:kickTo(outSpot, 3)
	self:waitForBall()
	task.wait(0.4)

	local throwTeam = other(holder.team)
	local throwerIdx = math.random(2, 9)
	local thrower = self.teams[throwTeam].players[throwerIdx]
	runTo(thrower, Vector3.new(side * (Pitch.WIDTH / 2 + 1), Pitch.SURFACE_Y, outSpot.Z), 3)
	self.holder = { team = throwTeam, idx = throwerIdx }
	thrower:face(centre())
	task.wait(0.4)

	local receiver = math.random(2, 11)
	if receiver == throwerIdx then
		receiver = receiver == 11 and 10 or receiver + 1
	end
	self:pass(throwTeam, receiver, 6, true)
	self:waitForBall()
	thrower.busy = false
end

-- Corner: the attacking side swings it into the box; the defence deals with it.
function Presenter.corner(self: Presenter, team: Pitch.Team)
	local opp = other(team)
	local dir = attackDir(self:geom(team))
	local goalZ = Pitch.goalZ(self:geom(team))
	local side = math.random() < 0.5 and -1 or 1
	local flag = Vector3.new(side * (Pitch.WIDTH / 2 - 2), Pitch.SURFACE_Y, goalZ - dir * 2)
	self.ball.Position = flag + Vector3.new(0, 0.8, 0)

	local takerIdx = math.random(6, 9)
	local taker = self.teams[team].players[takerIdx]
	runTo(taker, flag + Vector3.new(side * 2, 0, -dir * 2), 4)
	self.holder = { team = team, idx = takerIdx }
	-- attackers crowd the box while the taker sets up
	self.teams[team].push = 40
	task.wait(1.0)

	local boxSpot = Vector3.new(math.random() * 16 - 8, Pitch.SURFACE_Y + 1.5, goalZ - dir * (14 + math.random() * 10))
	self:kickTo(boxSpot, 9, 1.1)
	self:waitForBall()
	taker.busy = false
	self.teams[team].push = 0

	if math.random() < 0.5 then
		-- keeper claims it
		local keeper = self.teams[opp].players[1]
		keeper:setTarget(Vector3.new(boxSpot.X, Pitch.SURFACE_Y, boxSpot.Z))
		task.wait(0.5)
		self.holder = { team = opp, idx = 1 }
	else
		-- headed clear by a defender
		local defIdx = math.random(2, 5)
		self.holder = { team = opp, idx = defIdx }
		task.wait(0.3)
		self:pass(opp, math.random(6, 9), 5)
		self:waitForBall()
	end
end

-- Idle possession: short passes around, with the odd turnover or throw-in.
function Presenter.fillerPass(self: Presenter)
	local holder = self.holder
	if not holder then
		self.holder = { team = "Home", idx = 7 }
		return
	end
	if holder.idx ~= 1 and math.random() < 0.1 then
		self:throwIn()
		return
	end
	local team = holder.team
	if math.random() < 0.2 then
		team = other(team)
	end
	local idx = math.random(2, 11)
	if team == holder.team and idx == holder.idx then
		idx = idx == 11 and 10 or idx + 1
	end
	self:pass(team, idx)
end

local function crowdReact()
	MatchAudio.goalCheer()
	local club = workspace:FindFirstChild("Club")
	local stand = club and club:FindFirstChild("Stand")
	local crowd = stand and stand:FindFirstChild("Crowd")
	if not crowd then
		return
	end
	for _, fan in crowd:GetChildren() do
		if fan:IsA("BasePart") then
			task.delay(math.random() * 0.35, function()
				TweenService:Create(fan, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true),
					{ Position = fan.Position + Vector3.new(0, 1.5, 0) }):Play()
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
	local from = self.ball.Position
	self.holder = nil
	self.flight = {
		from = from,
		to = target,
		t = 0,
		dur = math.clamp(remaining(), 0.4, 1.2),
		arc = 1.5,
	}
	self:waitForBall()
	shooter.busy = false
	T.push = 0

	if ev.type == "GOAL" then
		shooter:celebrate()
		if team == "Home" then
			crowdReact()
		end
		task.wait(CELEBRATE_SECONDS)
		self:resetToFormation()
		self.ball.Position = centre() + Vector3.new(0, 0.8, 0)
		task.wait(RESET_SECONDS)
		self.holder = { team = opp, idx = 7 }
	elseif ev.type == "SAVE" then
		task.wait(0.9)
		keeper.busy = false
		self.holder = { team = opp, idx = 1 }
		task.wait(0.8)
	elseif math.random() < 0.4 then
		-- deflected wide: corner
		task.wait(0.8)
		self:corner(team)
	else
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
	self.ball.Position = centre() + Vector3.new(0, 0.8, 0)
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
function Presenter.applySubs(self: Presenter, subs: { { out: number, ["in"]: number } })
	local team = self.teams.Home
	for i = self.appliedSubs + 1, #subs do
		local sub = subs[i]
		local outgoing = team.players[sub.out]
		local incoming = team.squad[sub["in"]]
		if outgoing and incoming then
			outgoing.busy = true
			outgoing.speed = WALK_SPEED
			outgoing:setTarget(Pitch.TUNNEL)
			task.delay(8, function()
				outgoing:destroy()
			end)
			local fb = Footballer.new(self.folder, team.kit, incoming.number, incoming.name, Pitch.TUNNEL)
			fb:setTarget(team.slots[sub.out])
			team.players[sub.out] = fb
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
	self.folder:Destroy()
end

return Presenter
