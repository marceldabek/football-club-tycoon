--!strict
-- Friendly challenges (I3.1c): another club owner has challenged this player's
-- club. Shows who, a countdown, and Accept / Decline. The match itself is run
-- by the server at this player's ground.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent:WaitForChild("Theme"))

local player = Players.LocalPlayer
local C = Theme.colors
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inviteEvent = remotes:WaitForChild("FriendlyInvite") :: RemoteEvent
local respondEvent = remotes:WaitForChild("FriendlyRespond") :: RemoteEvent

local gui = Theme.screenGui("FriendlyInvite", 9)
local card = Theme.card(gui, "Card", "FRIENDLY CHALLENGE", UDim2.fromOffset(440, 280), UDim2.fromScale(0.5, 0.4))
local accept = card.addButton("Accept", "primary")
local decline = card.addButton("Decline", "secondary")
accept.LayoutOrder = 1
decline.LayoutOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

-- one invite on screen at a time; a newer one replaces it
local current: { from: number, fromName: string, fromClub: string, seconds: number }? = nil
local token = 0

local function hide()
	card.frame.Visible = false
	current = nil
end

local function answer(yes: boolean)
	local invite = current
	if invite then
		respondEvent:FireServer(invite.from, yes)
	end
	hide()
end

accept.Activated:Connect(function()
	answer(true)
end)
decline.Activated:Connect(function()
	answer(false)
end)

inviteEvent.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" or type(data.from) ~= "number" then
		return
	end
	-- X209: the challenger left
	if data.cancelled == true then
		if current and current.from == data.from then
			hide()
		end
		return
	end
	-- X210: a newer challenge replaces the card, so decline the old one rather
	-- than leaving it live on the server with no way to answer
	if current and current.from ~= data.from then
		respondEvent:FireServer(current.from, false)
	end
	local invite = {
		from = data.from,
		fromName = tostring(data.fromName or "Someone"),
		fromClub = tostring(data.fromClub or "their club"),
		seconds = if type(data.seconds) == "number" then data.seconds else 45,
	}
	current = invite
	token += 1
	local mine = token
	card.frame.Visible = true
	task.spawn(function()
		local deadline = os.clock() + invite.seconds
		while token == mine and current == invite do
			local left = math.max(0, math.ceil(deadline - os.clock()))
			card.body.Text = table.concat({
				Theme.rich(invite.fromClub, C.accent, true) .. (" (%s)"):format(invite.fromName),
				"wants a friendly at your ground.",
				"",
				"No injuries and no league points. You keep a share of the gate.",
				("<font transparency=\"0.4\">Answer within %d s</font>"):format(left),
			}, "\n")
			if left <= 0 then
				hide()
				break
			end
			task.wait(0.5)
		end
	end)
end)
