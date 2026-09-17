--!strict
-- Which club this client is looking at: the local player's own plot
-- (player attribute ClubPlot -> ReplicatedStorage.Clubs.PlotN), or the old
-- single ReplicatedStorage.ClubState in a place without plots. Also the plot's
-- transform, so presentation code can keep working in pitch-local space and
-- only convert when it writes a world CFrame (docs/PLOTS.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubRef = {}

local player = Players.LocalPlayer
local cached: Folder? = nil

-- The club folder once the player has a plot. Yields until then.
function ClubRef.waitState(): Folder
	while true do
		local folder = ClubRef.state()
		if folder then
			return folder
		end
		task.wait(0.2)
	end
end

-- The club folder right now, or nil while the player has no plot.
function ClubRef.state(): Folder?
	if cached and cached.Parent then
		return cached
	end
	cached = nil
	local plot = player:GetAttribute("ClubPlot")
	if type(plot) == "number" then
		local clubs = ReplicatedStorage:FindFirstChild("Clubs")
		local folder = clubs and clubs:FindFirstChild("Plot" .. plot)
		if folder and folder:IsA("Folder") then
			cached = folder
		end
	else
		local legacy = ReplicatedStorage:FindFirstChild("ClubState")
		if legacy and legacy:IsA("Folder") and not ReplicatedStorage:FindFirstChild("Clubs") then
			cached = legacy
		end
	end
	return cached
end

-- Pitch-local to world for the player's club (identity without plots).
-- Cached per folder: a plot never moves, and footballers ask every frame.
local frameFor: Folder? = nil
local frameCache = CFrame.identity
function ClubRef.frame(): CFrame
	local folder = ClubRef.state()
	if folder ~= frameFor then
		frameFor = folder
		local cf = folder and folder:GetAttribute("PlotCFrame")
		frameCache = if typeof(cf) == "CFrame" then cf else CFrame.identity
	end
	return frameCache
end

-- The player's club model in the workspace, if built.
function ClubRef.clubModel(): Model?
	local plot = player:GetAttribute("ClubPlot")
	if type(plot) == "number" then
		local plots = workspace:FindFirstChild("Plots")
		local model = plots and plots:FindFirstChild("Plot" .. plot)
		return model and model:FindFirstChild("Club") :: Model?
	end
	return workspace:FindFirstChild("Club") :: Model?
end

return ClubRef
