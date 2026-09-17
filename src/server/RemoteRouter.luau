--!strict
-- One OnServerEvent connection per remote for the whole server; each request
-- goes to the plot the sending player owns (player attribute ClubPlot).
-- Players without a plot (still picking, or just visiting) get a toast.
-- Never cloned per plot: PlotContext requires this original by path.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteRouter = {}

type Handler = (Player, ...any) -> ()

local handlers: { [RemoteEvent]: { [number]: Handler } } = {}

local function toast(player: Player, message: string)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("Toast")
	if event and event:IsA("RemoteEvent") then
		event:FireClient(player, message, false)
	end
end

function RemoteRouter.bind(plot: number, remote: RemoteEvent, handler: Handler)
	local byPlot = handlers[remote]
	if not byPlot then
		byPlot = {}
		handlers[remote] = byPlot
		remote.OnServerEvent:Connect(function(player: Player, ...)
			local owned = player:GetAttribute("ClubPlot")
			local fn = type(owned) == "number" and (byPlot :: any)[owned]
			if fn then
				fn(player, ...)
			else
				toast(player, "Pick a ground to run first.")
			end
		end)
	end
	byPlot[plot] = handler
end

-- Called when a plot's club despawns.
function RemoteRouter.unbindPlot(plot: number)
	for _, byPlot in handlers do
		byPlot[plot] = nil
	end
end

return RemoteRouter
