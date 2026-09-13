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
		self:updateFormationTargets()
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

function Presenter.updateFormationTargets(self: Presenter)
	local ballPos = self.ball.Position
	for teamName, team in self.teams do
		local dir = attackDir(teamName)
		for idx, fb in team.players do
			if fb.busy then
				continue
			end
			if self.holder and self.holder.team == teamName and self.holder.idx == idx then
				fb:setTarget(nil)
				continue
			end
			local base = team.slots[idx]
			if idx == 1 then
				fb:setTarget(base + Vector3.new(math.clamp(ballPos.X * 0.2, -7, 7), 0, 0))
			else
				local shift = math.clamp((ballPos.Z - base.Z) * 0.25, -30, 30) + dir * team.push
				fb:setTarget(base + Vector3.new(0, 0, shift) + fb.jitter)
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
		fb:setTarget(self.teams[teamName].slots[idx])
	end)
end

function Presenter.setTactic(self: Presenter, tactic: Pitch.Tactic)
	self.teams.Home.slots = Pitch.formationSlots("Home", tactic)
end

-- Kicks the ball from the current holder (or wherever it is) to a player.
function Presenter.pass(self: Presenter, toTeam: Pitch.Team, toIdx: number, arcOverride: number?)
	local receiver = self.teams[toTeam].players[toIdx]
	local from = self.ball.Position
	local to = receiver.position + Vector3.new(0, 0.8, 0)
	local holder = self.holder
	if holder then
		local kicker = self.teams[holder.team].players[holder.idx]
		kicker:face(receiver.position)
		kicker:kick()
	end
	receiver:setTarget(receiver.position)
	receiver.busy = true
	receiver:face(from)
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

-- Idle possession: short passes around, with the odd turnover.
function Presenter.fillerPass(self: Presenter)
	local holder = self.holder
	if not holder then
		self.holder = { team = "Home", idx = 7 }
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
	local dir = attackDir(team)
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

	local goalZ = Pitch.goalZ(team)
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
	self:resetToFormation()
	self.ball.Position = centre() + Vector3.new(0, 0.8, 0)
	self.holder = { team = "Home", idx = 7 }

	task.spawn(function()
		local secondsPerMinute = self.duration / 90
		local nextEvent = 1
		local fillerAt = 1.0
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
			if ev and t >= ev.minute * secondsPerMinute - SEQUENCE_LEAD then
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
