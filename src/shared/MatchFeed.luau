--!strict
-- X336: the minute-by-minute account of a match, as text.
--
-- The whole in-match text layer used to be a 2.5 s "GOAL!" flash and a sub
-- toast, so a player walking round the ground (CLAUDE.md s4) who looked away
-- for ten seconds had no idea what had happened until the summary card - even
-- though the Timeline attribute already carries every chance, its minute and
-- the scorer's slot.
--
-- This is pure: it takes the timeline the client already holds, the subs made
-- so far and the match minute, and returns the lines to show. Rebuilding it
-- from scratch every tick is deliberate, so a player who joins mid-match sees
-- the same feed as somebody who watched from kick-off (X186).
--
-- "Home" in a timeline is always the player's own club, whatever the venue
-- (the away fixture is dressed by AtHome, X310), so these lines can talk about
-- "us" and "them" without asking which side we are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Format)

local MatchFeed = {}

export type Kind = "kickoff" | "goal" | "conceded" | "save" | "miss" | "sub" | "injury" | "halftime" | "fulltime"

export type Line = {
	minute: number,
	text: string,
	kind: Kind,
}

type Player = { name: string, number: number, role: string }
type Event = { minute: number, team: string, type: string, scorer: number? }
type Squad = { name: string, squad: { Player } }
export type Timeline = { events: { Event }, home: Squad, away: Squad }
type Sub = { out: number, ["in"]: number, minute: number?, afterEvent: number? }

MatchFeed.MINUTES = 90 -- a match is always reported as ninety minutes
MatchFeed.HALF_TIME = 45

-- The match minute, exactly as the server's clock loop works it out, so the
-- feed and the scoreboard never disagree about when a goal went in.
function MatchFeed.minute(elapsed: number, duration: number): number
	if duration <= 0 then
		return 0
	end
	local minute = math.floor(elapsed / duration * MatchFeed.MINUTES)
	return math.clamp(minute, 0, MatchFeed.MINUTES)
end

-- A shirt as the feed says it: "9 Rashford-Lee".
local function shirt(p: Player?): string
	if not p then
		return "the substitute"
	end
	return ("%d %s"):format(p.number, Format.surname(p.name))
end

-- X218's rule, read-only: a goal belongs to whoever filled the slot when it
-- went in, so a starter subbed off earlier hands it to the man who replaced
-- him. `index` is the event's place in the timeline, because a goal earlier in
-- the same minute as a substitution is still the starter's.
local function creditedSlot(slot: number, index: number, minute: number, subs: { Sub }): number
	local out = slot
	for _, sub in subs do
		local after = if sub.afterEvent then index > sub.afterEvent else (sub.minute or 0) <= minute
		if sub.out == out and after then
			out = sub["in"]
		end
	end
	return out
end

-- Every line for a match that has reached `minute`, oldest first. `injury` is
-- the InjuryNews text if somebody has gone down (it is not a timeline event by
-- design, X334), and `injuryMinute` is when it happened.
function MatchFeed.build(
	timeline: Timeline,
	subs: { Sub },
	minute: number,
	opts: { injury: string?, injuryMinute: number?, finished: boolean?, atHome: boolean? }?
): { Line }
	local o = opts or {}
	local us = timeline.home
	local them = timeline.away
	local lines: { Line } = {}
	local ours, theirs = 0, 0

	-- X344: the scoreboard names the hosts first (X310), so the feed under it
	-- has to as well, score included - on an away fixture the two used to
	-- disagree about who was playing whom and who was winning.
	local hosts, visitors = us, them
	local away = o.atHome == false
	if away then
		hosts, visitors = them, us
	end
	local function score(): string
		return if away then ("%d-%d"):format(theirs, ours) else ("%d-%d"):format(ours, theirs)
	end

	table.insert(lines, {
		minute = 0,
		kind = "kickoff" :: Kind,
		text = ("Kick-off  ·  %s v %s"):format(hosts.name, visitors.name),
	})

	local halfTimeShown = false
	local function halfTime(upTo: number)
		if not halfTimeShown and upTo >= MatchFeed.HALF_TIME and minute >= MatchFeed.HALF_TIME then
			halfTimeShown = true
			table.insert(lines, { minute = MatchFeed.HALF_TIME, kind = "halftime" :: Kind, text = ("Half time  ·  %s"):format(score()) })
		end
	end

	-- substitutions and the casualty come in on their own minutes, between the
	-- chances, so the feed reads in order
	local extras: { Line } = {}
	for _, sub in subs do
		local at = sub.minute or 0
		if at <= minute then
			table.insert(extras, {
				minute = at,
				kind = "sub" :: Kind,
				text = ("Sub  ·  %s on for %s"):format(shirt(us.squad[sub["in"]]), shirt(us.squad[sub.out])),
			})
		end
	end
	if o.injury and o.injury ~= "" then
		local at = o.injuryMinute or minute
		if at <= minute then
			table.insert(extras, { minute = at, kind = "injury" :: Kind, text = o.injury })
		end
	end
	table.sort(extras, function(a, b)
		if a.minute ~= b.minute then
			return a.minute < b.minute
		end
		-- X344: a forced substitution carries the same minute as the injury
		-- that caused it, and the tie used to be broken by insertion order, so
		-- the feed read "14 Naylor on for 9 Ives" and then "9 Ives is down".
		return a.kind == "injury" and b.kind ~= "injury"
	end)

	local nextExtra = 1
	local function drainExtras(upTo: number)
		while extras[nextExtra] and extras[nextExtra].minute <= upTo do
			halfTime(extras[nextExtra].minute)
			table.insert(lines, extras[nextExtra])
			nextExtra += 1
		end
	end

	for index, ev in timeline.events do
		if ev.minute > minute then
			break
		end
		drainExtras(ev.minute)
		halfTime(ev.minute)
		local ourChance = ev.team == "Home"
		if ev.type == "GOAL" then
			if ourChance then
				ours += 1
				local slot = ev.scorer
				local man = if slot then us.squad[creditedSlot(slot, index, ev.minute, subs)] else nil
				table.insert(lines, {
					minute = ev.minute,
					kind = "goal" :: Kind,
					text = if man
						then ("GOAL!  %s  ·  %s"):format(shirt(man), score())
						else ("GOAL!  ·  %s"):format(score()),
				})
			else
				theirs += 1
				table.insert(lines, {
					minute = ev.minute,
					kind = "conceded" :: Kind,
					text = ("%s score  ·  %s"):format(them.name, score()),
				})
			end
		elseif ev.type == "SAVE" then
			-- the sim names a scorer for our goals only, so a save or a miss
			-- stays about the two sides rather than inventing a shooter
			table.insert(lines, {
				minute = ev.minute,
				kind = "save" :: Kind,
				text = if ourChance
					then "Saved  ·  their keeper gets a hand to it"
					-- our keeper, or whoever replaced him
					else ("Saved!  ·  %s keeps them out"):format(shirt(us.squad[creditedSlot(1, index, ev.minute, subs)])),
			})
		elseif ev.type == "MISS" then
			table.insert(lines, {
				minute = ev.minute,
				kind = "miss" :: Kind,
				text = if ourChance then "Over the bar  ·  so close" else "Wide  ·  a let-off",
			})
		end
	end
	drainExtras(minute)
	halfTime(minute)

	if o.finished or minute >= MatchFeed.MINUTES then
		table.insert(lines, {
			minute = MatchFeed.MINUTES,
			kind = "fulltime" :: Kind,
			text = ("Full time  ·  %s %s %s"):format(hosts.name, score(), visitors.name),
		})
	end
	return lines
end

-- The last `count` lines, newest first, which is the order the HUD stacks them
-- in so a new line appears at the top and the oldest one drops off.
function MatchFeed.latest(lines: { Line }, count: number): { Line }
	local out: { Line } = {}
	for i = #lines, math.max(#lines - count + 1, 1), -1 do
		table.insert(out, lines[i])
	end
	return out
end

-- "12'", and "0'" reads better as kick-off's own stamp.
function MatchFeed.stamp(line: Line): string
	return ("%d'"):format(line.minute)
end

return MatchFeed
