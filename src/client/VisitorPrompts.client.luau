--!strict
-- Visitors see other clubs read-only: prompts inside plots the local player
-- doesn't own are disabled on this client only. The server toggles Enabled
-- between Manage and matchday, so the rule is reapplied whenever it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotVisit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlotVisit"))

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots", math.huge) :: Instance

-- prompt -> the Enabled value the server last set
local serverEnabled: { [ProximityPrompt]: boolean } = {}
local applying = false

local function apply(prompt: ProximityPrompt)
	local hide = PlotVisit.hidePrompt(PlotVisit.plotOf(prompt, plots), player:GetAttribute("ClubPlot"))
	local want = if hide then false else serverEnabled[prompt]
	if prompt.Enabled ~= want then
		applying = true
		prompt.Enabled = want
		applying = false
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or serverEnabled[inst] ~= nil then
		return
	end
	local prompt = inst :: ProximityPrompt
	serverEnabled[prompt] = prompt.Enabled
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if applying then
			return
		end
		serverEnabled[prompt] = prompt.Enabled
		apply(prompt)
	end)
	prompt.Destroying:Connect(function()
		serverEnabled[prompt] = nil
	end)
	apply(prompt)
end

for _, inst in plots:GetDescendants() do
	track(inst)
end
plots.DescendantAdded:Connect(track)
plots.DescendantRemoving:Connect(function(inst)
	if inst:IsA("ProximityPrompt") then
		serverEnabled[inst] = nil
	end
end)

player:GetAttributeChangedSignal("ClubPlot"):Connect(function()
	for prompt in serverEnabled do
		apply(prompt)
	end
end)
