--!strict
-- Local friendlies between clubs on this server (backlog I3.1b). Global: never
-- cloned per plot. A visitor challenges a club from its office card; that
-- club's owner gets an invite and accepts or declines; the match is played at
-- the challenged club's ground against the challenger's current side.
-- Invite rules and the payout live in Shared.Friendly (TEMP values there).
--
-- Remotes:
--   FriendlyChallenge  client -> server  (targetPlot: number)
--   FriendlyRespond    client -> server  (fromUserId: number, accept: boolean)
--   FriendlyInvite     server -> client  { from, fromName, fromClub, seconds }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Friendly = require(ReplicatedStorage.Shared.Friendly)
local PlotService = require(script.Parent.PlotService)

local FriendlyService = {}

local book = Friendly.new()

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

local function toast(player: Player?, message: string, ok: boolean?)
	if player and player.Parent then
		remote("Toast"):FireClient(player, message, ok)
	end
end

local function clubFolder(plot: number): Folder?
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	return clubs and clubs:FindFirstChild("Plot" .. plot) :: Folder?
end

local function clubName(plot: number): string
	local folder = clubFolder(plot)
	local name = folder and folder:GetAttribute("ClubName")
	return if type(name) == "string" and name ~= "" then name else "their club"
end

-- Idle = owns a loaded club that is in Manage with no match running.
local function isIdle(plot: number?, match: any): boolean
	local folder = plot and clubFolder(plot)
	return match ~= nil and folder ~= nil and folder:GetAttribute("Phase") == "Manage" and not match.isRunning()
end

local function onChallenge(player: Player, rawPlot: unknown, rawOwner: unknown)
	if type(rawPlot) ~= "number" then
		return
	end
	local fromPlot, _, fromMatch = PlotService.clubOf(player.UserId)
	if not fromPlot then
		toast(player, "Build your own club before challenging anyone.")
		return
	end
	local targetPlot = math.floor(rawPlot)
	local target, targetMatch = PlotService.clubAt(targetPlot)
	if not target then
		toast(player, "Nobody owns that ground right now.")
		return
	end
	-- X211: the club the player was looking at may have left and the plot been re-claimed
	if type(rawOwner) == "number" and target.UserId ~= rawOwner then
		toast(player, "That ground has a new owner now. Visit their office to challenge them.")
		return
	end
	local ok, reason = book:challenge(
		player.UserId,
		target.UserId,
		os.clock(),
		isIdle(fromPlot, fromMatch),
		isIdle(targetPlot, targetMatch)
	)
	if not ok then
		toast(player, reason or "Can't challenge them right now.")
		return
	end
	remote("FriendlyInvite"):FireClient(target, {
		from = player.UserId,
		fromName = player.DisplayName,
		fromClub = clubName(fromPlot),
		seconds = Friendly.INVITE_SECONDS,
	})
	toast(player, ("Challenge sent to %s. Waiting for an answer…"):format(clubName(targetPlot)), true)
end

local function onRespond(player: Player, rawFrom: unknown, rawAccept: unknown)
	if type(rawFrom) ~= "number" or type(rawAccept) ~= "boolean" then
		return
	end
	local challenger = Players:GetPlayerByUserId(rawFrom)
	local invite, reason = book:respond(player.UserId, rawFrom, rawAccept, os.clock())
	local homePlot, _, homeMatch = PlotService.clubOf(player.UserId)
	if not invite then
		if reason == "declined" then
			toast(challenger, ("%s turned down your friendly."):format(if homePlot then clubName(homePlot) else player.DisplayName))
		else
			toast(player, reason or "That challenge has expired.")
		end
		return
	end
	local awayPlot, _, awayMatch = PlotService.clubOf(rawFrom)
	if not (challenger and homePlot and awayPlot) then
		toast(player, "The other club has left.")
		return
	end
	if not isIdle(homePlot, homeMatch) or not isIdle(awayPlot, awayMatch) then
		toast(player, "One of the clubs is busy with a match.")
		toast(challenger, "The friendly couldn't start: one of the clubs is busy with a match.")
		return
	end

	local away = awayMatch.awayTeam()
	local homeName = clubName(homePlot)
	toast(challenger, ("%s accepted! The friendly is at their ground. Take the bus to watch."):format(homeName), true)
	task.spawn(function()
		local started, homeGoals, awayGoals = homeMatch.playFriendly(away)
		if not started then
			toast(player, "The friendly couldn't start.")
			toast(challenger, "The friendly couldn't start.")
			return
		end
		toast(challenger, ("Friendly result: %s %d - %d %s"):format(homeName, homeGoals, awayGoals, away.name), true)
	end)
end

function FriendlyService.start()
	remote("Toast")
	remote("FriendlyInvite")
	remote("FriendlyChallenge").OnServerEvent:Connect(onChallenge)
	remote("FriendlyRespond").OnServerEvent:Connect(onRespond)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, invite in book:dropUser(player.UserId) do
			local other = Players:GetPlayerByUserId(if invite.from == player.UserId then invite.to else invite.from)
			toast(other, "The friendly challenge was cancelled: the other club left.")
			-- X209: close the invite card if it was waiting on the player who left
			if other and invite.from == player.UserId then
				remote("FriendlyInvite"):FireClient(other, { from = invite.from, cancelled = true })
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			for _, invite in book:expire(os.clock()) do
				toast(Players:GetPlayerByUserId(invite.from), "No answer to your friendly challenge.")
			end
		end
	end)
end

return FriendlyService
