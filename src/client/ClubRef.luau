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

-- The club the match presentation follows: the player's own, or another club
-- whose match they are watching from its stands (I2.1). Presentation code
-- (presenter, footballers, crowd) reads these; HUD/town code keeps frame().
local presented: Folder? = nil

function ClubRef.setPresented(folder: Folder?)
	presented = folder
end

local presentedFor: Folder? = nil
local presentedCache = CFrame.identity
function ClubRef.presentFrame(): CFrame
	local folder = presented
	if not folder then
		return ClubRef.frame()
	end
	if folder ~= presentedFor then
		presentedFor = folder
		local cf = folder:GetAttribute("PlotCFrame")
		presentedCache = if typeof(cf) == "CFrame" then cf else CFrame.identity
	end
	return presentedCache
end

function ClubRef.presentModel(): Model?
	local folder = presented
	if folder then
		local plot = folder:GetAttribute("PlotIndex")
		local plots = workspace:FindFirstChild("Plots")
		local model = plots and type(plot) == "number" and plots:FindFirstChild("Plot" .. plot)
		return model and model:FindFirstChild("Club") :: Model?
	end
	return ClubRef.clubModel()
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
