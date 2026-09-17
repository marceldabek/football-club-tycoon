--!strict
-- Same-server player trades (backlog I4.1b). Global: never cloned per plot.
-- A club owner proposes from another club's office card; the other owner
-- accepts or declines. On accept the offer is checked again against both
-- clubs as they are now, applied in one step (no yields), and both saved.
-- Rules live in Shared.Trade (TEMP values there).
--
-- Remotes:
--   TradePropose  client -> server  (targetPlot, give {ids}, take {ids}, giveCash, takeCash)
--   TradeRespond  client -> server  (fromUserId, accept)
--   TradeOffer    server -> client  { from, fromName, fromClub, give, take, giveCash, takeCash, seconds }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Trade = require(ReplicatedStorage.Shared.Trade)
local PlotService = require(script.Parent.PlotService)

local TradeService = {}

local book = Trade.newBook()
local LIMITS: Trade.Limits = { squadMin = Config.SquadMin, squadMax = Config.SquadMax }

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

-- Remote input: a short list of whole numbers, else nil.
local function idList(raw: unknown): { number }?
	if type(raw) ~= "table" then
		return nil
	end
	local out = {}
	for i, v in raw :: { any } do
		if type(i) ~= "number" or type(v) ~= "number" or v ~= math.floor(v) or #out >= Trade.MAX_PLAYERS_PER_SIDE + 1 then
			return nil
		end
		table.insert(out, v)
	end
	return out
end

local function cashOf(raw: unknown): number?
	if type(raw) ~= "number" or raw ~= raw then
		return nil
	end
	return raw
end

local function idle(m: { [string]: any }): boolean
	return m.state.get("Phase") == "Manage" and not m.match.isRunning()
end

local function clubName(m: { [string]: any }): string
	local name = m.state.get("ClubName")
	return if type(name) == "string" and name ~= "" then name else "their club"
end

-- What the receiver sees: names and ratings of the players in the offer.
local function describe(squad: { any }, ids: { number }): { any }
	local out = {}
	for _, id in ids do
		for _, p in squad do
			if p.id == id then
				table.insert(out, { name = p.name, role = p.role, overall = p.overall, age = p.age, injured = p.injured })
				break
			end
		end
	end
	return out
end

local function check(offer: Trade.Offer, from: { [string]: any }, to: { [string]: any }): (boolean, string?)
	if not idle(from) or not idle(to) then
		return false, "Trades wait until both clubs are back from matchday."
	end
	return Trade.validate(
		offer,
		from.club.squadCopy(),
		to.club.squadCopy(),
		from.state.get("Cash") :: number,
		to.state.get("Cash") :: number,
		LIMITS
	)
end

local function onPropose(player: Player, rawPlot: unknown, rawGive: unknown, rawTake: unknown, rawGiveCash: unknown, rawTakeCash: unknown, rawOwner: unknown)
	local give, take = idList(rawGive), idList(rawTake)
	local giveCash, takeCash = cashOf(rawGiveCash), cashOf(rawTakeCash)
	if type(rawPlot) ~= "number" or not give or not take or not giveCash or not takeCash then
		return
	end
	local from = PlotService.modulesFor(player.UserId)
	if not from then
		toast(player, "Build your own club before trading.")
		return
	end
	local target = PlotService.clubAt(math.floor(rawPlot))
	local to = target and PlotService.modulesFor(target.UserId)
	if not (target and to) then
		toast(player, "Nobody owns that ground right now.")
		return
	end
	-- X211: refuse if the plot changed hands while the trade screen was open
	if type(rawOwner) == "number" and (target :: Player).UserId ~= rawOwner then
		toast(player, "That ground has a new owner now. Visit their office to trade.")
		return
	end
	local offer: Trade.Offer = {
		from = player.UserId,
		to = target.UserId,
		give = give,
		take = take,
		giveCash = giveCash,
		takeCash = takeCash,
		createdAt = 0,
	}
	local ok, reason = check(offer, from, to)
	if not ok then
		toast(player, reason or "That trade isn't possible.")
		return
	end
	local proposed, why = book:propose(offer, os.clock())
	if not proposed then
		toast(player, why or "That trade isn't possible.")
		return
	end
	remote("TradeOffer"):FireClient(target, {
		from = player.UserId,
		fromName = player.DisplayName,
		fromClub = clubName(from),
		give = describe(from.club.squadCopy(), give),
		take = describe(to.club.squadCopy(), take),
		giveCash = giveCash,
		takeCash = takeCash,
		seconds = Trade.OFFER_SECONDS,
	})
	toast(player, ("Trade offer sent to %s."):format(clubName(to)), true)
end

local function onRespond(player: Player, rawFrom: unknown, rawAccept: unknown)
	if type(rawFrom) ~= "number" or type(rawAccept) ~= "boolean" then
		return
	end
	local proposer = Players:GetPlayerByUserId(rawFrom)
	local offer = book:take(player.UserId, rawFrom, os.clock())
	local to = PlotService.modulesFor(player.UserId)
	if not offer then
		toast(player, "That trade offer has expired.")
		return
	end
	if not rawAccept then
		toast(proposer, ("%s turned down your trade."):format(if to then clubName(to) else player.DisplayName))
		return
	end
	local from = PlotService.modulesFor(rawFrom)
	if not (from and to and proposer) then
		toast(player, "The other club has left.")
		return
	end
	-- squads or cash may have changed since the offer was made
	local ok, reason = check(offer, from, to)
	if not ok then
		toast(player, "The trade can't go through any more: " .. (reason or "something changed."))
		toast(proposer, "Your trade can't go through any more: " .. (reason or "something changed."))
		return
	end

	-- apply in one step: nothing here yields
	local toReceiver = from.club.tradeAway(offer.give)
	local toProposer = to.club.tradeAway(offer.take)
	to.club.tradeIn(toReceiver)
	from.club.tradeIn(toProposer)
	if offer.giveCash > 0 then
		from.state.addCash(-offer.giveCash)
		to.state.addCash(offer.giveCash)
	elseif offer.takeCash > 0 then
		to.state.addCash(-offer.takeCash)
		from.state.addCash(offer.takeCash)
	end

	task.spawn(from.session.saveNow)
	task.spawn(to.session.saveNow)
	toast(player, ("Trade done with %s."):format(clubName(from)), true)
	toast(proposer, ("%s accepted your trade!"):format(clubName(to)), true)
end

function TradeService.start()
	remote("Toast")
	remote("TradeOffer")
	remote("TradePropose").OnServerEvent:Connect(onPropose)
	remote("TradeRespond").OnServerEvent:Connect(onRespond)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, offer in book:dropUser(player.UserId) do
			local other = Players:GetPlayerByUserId(if offer.from == player.UserId then offer.to else offer.from)
			toast(other, "The trade offer was cancelled: the other club left.")
			-- X209: close the offer card if it was waiting on the player who left
			if other and offer.from == player.UserId then
				remote("TradeOffer"):FireClient(other, { from = offer.from, cancelled = true })
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			for _, offer in book:expire(os.clock()) do
				toast(Players:GetPlayerByUserId(offer.from), "No answer to your trade offer.")
			end
		end
	end)
end

-- Studio check without a second club: trade players out of a club and back in.
function TradeService.debugRoundTrip(userId: number, ids: { number }): (boolean, string?)
	local m = PlotService.modulesFor(userId)
	if not m then
		return false, "no club"
	end
	local before = #m.club.squadCopy()
	local gone = m.club.tradeAway(ids)
	local back = m.club.tradeIn(gone)
	local after = m.club.squadCopy()
	local names = {}
	for _, p in back do
		table.insert(names, ("%s #%d id%d"):format(p.name, p.number, p.id))
	end
	return #after == before and #back == #ids, table.concat(names, ", ")
end

return TradeService
