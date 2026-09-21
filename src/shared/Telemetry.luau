--!strict
-- Soft-launch analytics (docs/SOFT_LAUNCH.md SL23-SL25): a thin, fail-safe
-- wrapper over AnalyticsService. Server only; every call is a no-op on a client.
-- Lives in Shared, not beside the services, so the per-plot clones reach one
-- copy without joining PlotService.PER_CLUB.
-- Nothing here may ever break the game: every send is pcall'd and deferred.
-- Studio sends nothing; tests read what would have been sent through `sink`.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Telemetry = {}

-- The onboarding funnel. Only steps every player passes in this order belong
-- here; things a player may do at any point (first upgrade, first pack, first
-- signing) are custom events, or a skipped step would muddy the funnel.
-- Never renumber a step once the place is public - add new ones at the end.
Telemetry.STEPS = {
	Joined = 1,
	GroundClaimed = 2,
	ClubFounded = 3,
	Match1Started = 4,
	Match1Finished = 5,
	Match2Finished = 6,
	Match5Finished = 7,
	Season1Finished = 8,
}

local STEP_LABELS: { [string]: string } = {
	Joined = "Joined",
	GroundClaimed = "Ground claimed",
	ClubFounded = "Club founded",
	Match1Started = "Match 1 started",
	Match1Finished = "Match 1 finished",
	Match2Finished = "Match 2 finished",
	Match5Finished = "Match 5 finished",
	Season1Finished = "Season 1 finished",
}

export type Sent = { kind: string, userId: number, name: string, value: number?, extra: string? }

-- tests set this to capture what would be sent; nil in the live game
Telemetry.sink = nil :: ((Sent) -> ())?

local live = RunService:IsServer() and not RunService:IsStudio()

local function send(record: Sent, call: () -> ())
	if not RunService:IsServer() then
		return
	end
	local sink = Telemetry.sink
	if sink then
		sink(record)
	end
	if not live then
		return
	end
	task.defer(function()
		local ok, err = pcall(call)
		if not ok then
			warn("[FCT] telemetry failed: " .. tostring(err))
		end
	end)
end

function Telemetry.step(player: Player?, step: string)
	local number = (Telemetry.STEPS :: { [string]: number })[step]
	if not player or not number then
		return
	end
	send({ kind = "step", userId = player.UserId, name = step, value = number }, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, number, STEP_LABELS[step])
	end)
end

-- The step a finished match stands for, if any. `played` is the club's
-- MatchesPlayed after the match was counted.
function Telemetry.matchFinished(player: Player?, played: number)
	if played == 1 then
		Telemetry.step(player, "Match1Finished")
	elseif played == 2 then
		Telemetry.step(player, "Match2Finished")
	elseif played == 5 then
		Telemetry.step(player, "Match5Finished")
	end
end

-- Keep names few and fixed (Roblox limits how many distinct ones it charts).
function Telemetry.event(player: Player?, name: string, value: number?)
	if not player then
		return
	end
	send({ kind = "event", userId = player.UserId, name = name, value = value }, function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

-- `moved` is signed, as ClubState.addCash reports it; `category` is a Finance
-- category and becomes the item SKU.
function Telemetry.cash(player: Player?, moved: number, balance: number, category: string)
	if not player or moved == 0 then
		return
	end
	local income = moved > 0
	send({
		kind = "cash",
		userId = player.UserId,
		name = if income then "Source" else "Sink",
		value = math.abs(moved),
		extra = category,
	}, function()
		AnalyticsService:LogEconomyEvent(
			player,
			if income then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Cash",
			math.abs(moved),
			balance,
			if income
				then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
				else Enum.AnalyticsEconomyTransactionType.Shop.Name,
			category
		)
	end)
end

return Telemetry
