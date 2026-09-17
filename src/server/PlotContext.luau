--!strict
-- Which club plot this copy of the club services belongs to (docs/PLOTS.md).
--
-- PlotService clones the per-club modules into ServerScriptService.ClubRuntime.PlotN
-- and stamps the folder with PlotIndex / PlotCFrame. Every clone requires its
-- own sibling copy of this module, so each plot answers "where is my state,
-- my world, my transform" for itself. The un-cloned originals (tests, a place
-- without plots) have no PlotIndex and fall back to the old single-club names
-- and an identity transform.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotContext = {}

local container = script.Parent
local index = container:GetAttribute("PlotIndex") :: number?
local frame = (container:GetAttribute("PlotCFrame") :: CFrame?) or CFrame.identity

PlotContext.index = index
PlotContext.cframe = frame

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

function PlotContext.name(): string
	return if index then "Plot" .. index else "Club"
end

-- The replicated attribute folder the clients read.
function PlotContext.stateFolder(): Folder
	if not index then
		return findOrCreate(ReplicatedStorage, "ClubState", "Folder") :: Folder
	end
	local clubs = findOrCreate(ReplicatedStorage, "Clubs", "Folder")
	local folder = findOrCreate(clubs, "Plot" .. index, "Folder") :: Folder
	folder:SetAttribute("PlotIndex", index)
	folder:SetAttribute("PlotCFrame", frame)
	return folder
end

-- Where this plot's `Club` model lives.
function PlotContext.worldParent(): Instance
	if not index then
		return workspace
	end
	local plots = findOrCreate(workspace, "Plots", "Folder")
	return findOrCreate(plots, "Plot" .. index, "Model")
end

function PlotContext.clubModel(): Model?
	return PlotContext.worldParent():FindFirstChild("Club") :: Model?
end

-- Moves everything under `root` from pitch-local coordinates into the plot.
-- Call it once on each freshly built subtree. Identity plots skip the work.
function PlotContext.place(root: Instance)
	if frame == CFrame.identity then
		return
	end
	local function move(inst: Instance)
		if inst:IsA("BasePart") then
			inst.CFrame = frame * inst.CFrame
		elseif inst:IsA("Model") then
			inst.WorldPivot = frame * inst.WorldPivot
		end
	end
	move(root)
	for _, d in root:GetDescendants() do
		move(d)
	end
end

-- Pitch-local point or CFrame to world.
function PlotContext.toWorld(local_: CFrame): CFrame
	return frame * local_
end

-- True when `player` is the one this plot answers remotes for.
function PlotContext.ownsPlayer(player: Player): boolean
	if not index then
		return true
	end
	return player:GetAttribute("ClubPlot") == index
end

-- Remote handlers: a single-club place connects directly; a plot registers
-- with the global router so each request reaches exactly one plot.
function PlotContext.onRemote(remote: RemoteEvent, handler: (Player, ...any) -> ())
	if not index then
		remote.OnServerEvent:Connect(handler)
		return
	end
	local Router = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RemoteRouter")) :: any
	Router.bind(index, remote, handler)
end

return PlotContext
