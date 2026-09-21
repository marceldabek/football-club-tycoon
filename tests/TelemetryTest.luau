--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Telemetry = require(ReplicatedStorage.Shared.Telemetry)

local T = {}

local fakePlayer = ({ UserId = 42 } :: any) :: Player

local function capture(run: () -> ()): { Telemetry.Sent }
	local sent: { Telemetry.Sent } = {}
	local before = Telemetry.sink
	Telemetry.sink = function(record)
		table.insert(sent, record)
	end
	local ok, err = pcall(run)
	Telemetry.sink = before
	assert(ok, tostring(err))
	return sent
end

function T.stepNumbersAreUniqueAndContiguous()
	local seen: { [number]: string } = {}
	local count = 0
	for name, number in Telemetry.STEPS do
		assert(seen[number] == nil, ("steps %s and %s share number %d"):format(name, tostring(seen[number]), number))
		seen[number] = name
		count += 1
	end
	for i = 1, count do
		assert(seen[i], ("no step numbered %d"):format(i))
	end
end

function T.stepSendsItsNumber()
	local sent = capture(function()
		Telemetry.step(fakePlayer, "ClubFounded")
	end)
	assert(#sent == 1 and sent[1].kind == "step", "one step record")
	assert(sent[1].value == Telemetry.STEPS.ClubFounded and sent[1].userId == 42, "number and user")
end

function T.unknownStepAndMissingPlayerSendNothing()
	local sent = capture(function()
		Telemetry.step(fakePlayer, "NoSuchStep")
		Telemetry.step(nil, "Joined")
		Telemetry.event(nil, "Anything")
		Telemetry.cash(nil, 100, 100, "gate")
	end)
	assert(#sent == 0, "nothing should be sent")
end

function T.matchFinishedMapsOnlyTheFunnelMatches()
	local sent = capture(function()
		for played = 1, 6 do
			Telemetry.matchFinished(fakePlayer, played)
		end
	end)
	assert(#sent == 3, "matches 1, 2 and 5 are funnel steps")
	assert(sent[1].name == "Match1Finished" and sent[2].name == "Match2Finished" and sent[3].name == "Match5Finished", "in order")
end

function T.cashSplitsSourceAndSinkAndSkipsZero()
	local sent = capture(function()
		Telemetry.cash(fakePlayer, 250, 250, "gate")
		Telemetry.cash(fakePlayer, -100, 150, "wages")
		Telemetry.cash(fakePlayer, 0, 150, "upkeep")
	end)
	assert(#sent == 2, "a zero move is not an event")
	assert(sent[1].name == "Source" and sent[1].value == 250 and sent[1].extra == "gate", "income")
	assert(sent[2].name == "Sink" and sent[2].value == 100 and sent[2].extra == "wages", "spend is sent positive")
end

return T
