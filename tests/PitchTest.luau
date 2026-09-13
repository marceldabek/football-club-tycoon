--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pitch = require(ReplicatedStorage.Shared.Pitch)

local T = {}

local function insidePitch(p: Vector3): boolean
	return math.abs(p.X) <= Pitch.WIDTH / 2 and math.abs(p.Z) <= Pitch.LENGTH / 2
end

function T.elevenSlotsInsidePitch()
	for _, team in { "Home", "Away" } do
		local slots = Pitch.formationSlots(team :: any, "Balanced")
		assert(#slots == 11, team .. " has " .. #slots .. " slots")
		for i, p in slots do
			assert(insidePitch(p), ("%s slot %d outside pitch: %s"):format(team, i, tostring(p)))
		end
	end
end

function T.keeperNearestOwnGoalForwardsNearestOpponentGoal()
	local slots = Pitch.formationSlots("Home", "Balanced")
	local ownGoal = Pitch.goalZ("Away") -- the goal Home defends is the one Away attacks
	local attackGoal = Pitch.goalZ("Home")
	local gk = slots[1]
	for i = 2, 11 do
		assert(math.abs(slots[i].Z - ownGoal) > math.abs(gk.Z - ownGoal), "keeper is not the deepest player")
	end
	local fwdDist = math.abs(slots[10].Z - attackGoal)
	for i = 1, 9 do
		assert(math.abs(slots[i].Z - attackGoal) > fwdDist, "forward is not the most advanced player")
	end
end

function T.awayMirrorsHome()
	local home = Pitch.formationSlots("Home", "Balanced")
	local away = Pitch.formationSlots("Away", "Balanced")
	for i = 1, 11 do
		assert(math.abs(home[i].Z + away[i].Z) < 0.01, "slot " .. i .. " Z is not mirrored")
	end
end

function T.attackPushesOutfieldForwardDefendPullsBack()
	local balanced = Pitch.formationSlots("Home", "Balanced")
	local attack = Pitch.formationSlots("Home", "Attack")
	local defend = Pitch.formationSlots("Home", "Defend")
	local goal = Pitch.goalZ("Home")
	for i = 2, 11 do
		assert(math.abs(attack[i].Z - goal) < math.abs(balanced[i].Z - goal), "attack did not push slot " .. i)
		assert(math.abs(defend[i].Z - goal) > math.abs(balanced[i].Z - goal), "defend did not pull slot " .. i)
	end
	assert(balanced[1].Z == attack[1].Z and balanced[1].Z == defend[1].Z, "keeper should not move with tactic")
end

function T.rolesMatchSlots()
	assert(#Pitch.ROLES == 11, "expected 11 roles")
	assert(Pitch.ROLES[1] == "GK" and Pitch.ROLES[10] == "FWD" and Pitch.ROLES[11] == "FWD", "role order")
end

return T
