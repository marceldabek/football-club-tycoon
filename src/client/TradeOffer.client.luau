--!strict
-- Trade offers (I4.1c): another club owner has offered this player a trade.
-- Shows what moves each way, a countdown, and Accept / Decline. The server
-- re-checks the trade on accept.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trade = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Trade"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local player = Players.LocalPlayer
local C = Theme.colors
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local offerEvent = remotes:WaitForChild("TradeOffer") :: RemoteEvent
local respondEvent = remotes:WaitForChild("TradeRespond") :: RemoteEvent

local gui = Theme.screenGui("TradeOffer", 9)
local card = Theme.card(gui, "Card", "TRADE OFFER", UDim2.fromOffset(520, 300), UDim2.fromScale(0.5, 0.42))
local accept = card.addButton("Accept", "primary")
local decline = card.addButton("Decline", "secondary")
accept.LayoutOrder = 1
decline.LayoutOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local current: { [string]: any }? = nil
local token = 0

local function hide()
	card.frame.Visible = false
	current = nil
end

local function answer(yes: boolean)
	local offer = current
	if offer then
		respondEvent:FireServer(offer.from, yes)
	end
	hide()
end

accept.Activated:Connect(function()
	answer(true)
end)
decline.Activated:Connect(function()
	answer(false)
end)

offerEvent.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" or type(data.from) ~= "number" then
		return
	end
	-- X209: the other club left
	if data.cancelled == true then
		if current and current.from == data.from then
			hide()
		end
		return
	end
	-- X210: decline an offer the new one replaces, so it doesn't hang unanswerable
	if current and current.from ~= data.from then
		respondEvent:FireServer(current.from, false, true)
	end
	current = data
	token += 1
	local mine = token
	card.frame.Visible = true
	local seconds = if type(data.seconds) == "number" then data.seconds else 60
	task.spawn(function()
		local deadline = os.clock() + seconds
		while token == mine and current == data do
			local left = math.max(0, math.ceil(deadline - os.clock()))
			local lines = {
				Theme.rich(tostring(data.fromClub or "A club"), C.accent, true) .. (" (%s) offers:"):format(tostring(data.fromName or "?")),
				"",
			}
			for _, line in Trade.offerLines(data) do
				table.insert(lines, line)
			end
			table.insert(lines, "")
			table.insert(lines, ("<font transparency=\"0.4\">Answer within %d s</font>"):format(left))
			card.body.Text = table.concat(lines, "\n")
			if left <= 0 then
				hide()
				break
			end
			task.wait(0.5)
		end
	end)
end)
