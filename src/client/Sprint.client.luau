--!strict
-- Sprint: hold Shift on a keyboard, or tap the RUN toggle on a touch screen
-- (docs/SOFT_LAUNCH.md SL21 - the town is a long walk on a phone).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent:WaitForChild("Theme"))

local WALK_SPEED = 16
local SPRINT_SPEED = 30

local player = Players.LocalPlayer
local sprinting = false
local runButton: TextButton? = nil

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply()
	local h = humanoid()
	-- always written: a fresh humanoid can read 0 for a moment, and PackOpening
	-- re-pins its freeze whenever this changes the speed
	if h then
		h.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
	end
	local button = runButton
	if button then
		button.BackgroundColor3 = if sprinting then Theme.colors.accent else Theme.colors.bg
		button.TextColor3 = if sprinting then Theme.colors.bg else Theme.colors.text
	end
end

local function isShift(input: InputObject): boolean
	return input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and isShift(input) then
		sprinting = true
		apply()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if isShift(input) then
		sprinting = false
		apply()
	end
end)
player.CharacterAdded:Connect(function()
	task.wait()
	apply()
end)

-- Touch: a toggle rather than a hold, because one thumb is on the stick and the
-- other is turning the camera. It sits directly above Roblox's jump button,
-- which is 70 px at (-95, -90) on a phone and 120 px at (-170, -210) on a tablet.
if UserInputService.TouchEnabled then
	local gui = Theme.screenGui("SprintButton", 1)
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(800, 400)
	local phone = math.min(view.X, view.Y) <= 500
	local size = if phone then 70 else 120
	local jumpX = if phone then -95 else -170
	local jumpY = if phone then -90 else -210

	local button = Instance.new("TextButton")
	button.Name = "Run"
	button.Text = "RUN"
	button.Font = Theme.fonts.bold
	button.TextSize = if phone then 16 else 22
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(size, size)
	button.Position = UDim2.new(1, jumpX, 1, jumpY - size - 14)
	Theme.corner(button, size / 2)
	Theme.stroke(button)
	button.Parent = gui
	runButton = button

	button.Activated:Connect(function()
		sprinting = not sprinting
		apply()
	end)
	-- TEMP: shown whenever there is a character; it does not yet hide behind
	-- fullscreen menus the way Roblox's own touch controls do
	button.Visible = player.Character ~= nil
	player.CharacterAdded:Connect(function()
		button.Visible = true
	end)
	player.CharacterRemoving:Connect(function()
		button.Visible = false
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

apply()
