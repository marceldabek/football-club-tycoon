--!strict
-- Hold Shift to sprint. TEMP: keyboard only; a touch button comes with mobile UI.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local WALK_SPEED = 16
local SPRINT_SPEED = 30

local player = Players.LocalPlayer
local sprinting = false

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply()
	local h = humanoid()
	if h then
		h.WalkSpeed = sprinting and SPRINT_SPEED or WALK_SPEED
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
apply()
