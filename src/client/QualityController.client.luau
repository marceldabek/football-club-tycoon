--!strict
-- Quality toggle (backlog C3.2). Picks a default level, publishes it as the
-- LocalPlayer attribute "Quality" (read by Traffic / TownLife for their
-- budgets), adds a "Quality: High/Low" button under the Music toggle, and on
-- Low hides decorative props (Shared.Quality.isDecorative) and the seamless
-- filler textures in the town and backdrop. Everything is local to this
-- player's screen; lighting stays with Sky.luau.
--
-- StreamingEnabled is on, so parts come and go at any time (and a model's
-- parts can arrive after the model): every descendant of Town / Backdrop,
-- now and later, goes through a queue that is worked through a few hundred
-- instances per frame, so neither streaming nor a toggle causes a hitch.
--
-- TEMP: nothing is saved; the default is picked again every session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Quality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quality"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local ROOTS = { "Town", "Backdrop" } -- workspace children to scan
local PER_FRAME = 800 -- instances processed per Heartbeat
local ROOT_POLL_SECONDS = 2

local level: Quality.Level = Quality.defaultFor(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
player:SetAttribute(Quality.ATTRIBUTE, level)

-- ---------------------------------------------------------------- tracking

-- No instance-keyed tables: Luau can collect an Instance's wrapper from a
-- weak table while the Instance still exists (seen in Studio: Low hid nothing).
-- A toggle rescans the roots instead, and a texture's builder Transparency is
-- kept in an attribute.
local ORIGINAL_T = "QualityOriginalTransparency"
local roots: { [string]: Instance } = {}

local queue: { Instance } = {}
local head = 1

local function push(inst: Instance)
	table.insert(queue, inst)
end

local function applyPart(p: BasePart)
	p.LocalTransparencyModifier = if level == "Low" then 1 else 0
end

local function applyTexture(t: Texture)
	local original = t:GetAttribute(ORIGINAL_T)
	if level == "Low" then
		if type(original) ~= "number" then
			t:SetAttribute(ORIGINAL_T, t.Transparency)
		end
		t.Transparency = 1
	elseif type(original) == "number" then
		t.Transparency = original
	end
end

local function process(inst: Instance)
	if inst.Parent == nil then
		return -- streamed out or destroyed while queued
	end
	if inst:IsA("BasePart") then
		if Quality.isDecorative(inst) then
			applyPart(inst)
		end
	elseif Quality.isFillerTexture(inst) then
		applyTexture(inst :: Texture)
	end
end

RunService.Heartbeat:Connect(function()
	local stop = math.min(#queue, head + PER_FRAME - 1)
	for i = head, stop do
		process(queue[i])
	end
	head = stop + 1
	if head > #queue then
		table.clear(queue)
		head = 1
	elseif head > 4096 then
		-- streaming keeps adding while we work: drop the processed prefix
		local rest = #queue - head + 1
		table.move(queue, head, #queue, 1)
		for i = #queue, rest + 1, -1 do
			queue[i] = nil
		end
		head = 1
	end
end)

local function watchRoot(name: string)
	local found = workspace:FindFirstChild(name)
	while not found do
		task.wait(ROOT_POLL_SECONDS)
		found = workspace:FindFirstChild(name)
	end
	local root = found :: Instance
	roots[name] = root
	root.DescendantAdded:Connect(push)
	for _, d in root:GetDescendants() do
		push(d)
	end
	-- the builders replace the root folder on a rebuild; follow the new one
	root.AncestryChanged:Connect(function()
		if root.Parent == nil then
			task.spawn(watchRoot, name)
		end
	end)
end

for _, name in ROOTS do
	task.spawn(watchRoot, name)
end

-- Re-apply to everything currently streamed in; the queue spreads the work.
local function setLevel(newLevel: Quality.Level)
	if newLevel == level then
		return
	end
	level = newLevel
	player:SetAttribute(Quality.ATTRIBUTE, level)
	table.clear(queue)
	head = 1
	for _, root in roots do
		if root.Parent then
			for _, d in root:GetDescendants() do
				push(d)
			end
		end
	end
end

-- -------------------------------------------------------------------- HUD

-- The HUD only exists once a plot is claimed (HUD.client.luau waits for the
-- club), so wait for it rather than making a second ScreenGui. Sits directly
-- under the Music toggle, same size and style.
task.spawn(function()
	local hud = player:WaitForChild("PlayerGui"):WaitForChild("TycoonHUD")
	local button = Theme.button(hud, "", "ghost", {
		Name = "QualityToggle",
		Size = UDim2.fromOffset(130, 34),
		Position = UDim2.new(1, -20, 0, 92),
		AnchorPoint = Vector2.new(1, 0),
	})
	local function refresh()
		button.Text = "Quality: " .. level
		button.TextColor3 = if level == "High" then Theme.colors.text else Theme.colors.muted
	end
	button.Activated:Connect(function()
		setLevel(Quality.other(level))
		refresh()
	end)
	refresh()
end)
