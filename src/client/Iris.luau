--!strict
-- Iris-style screen transition: a black circle grows from the centre to cover
-- the screen (close) and shrinks away again (open). No image assets needed.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Iris = {}

local circle: Frame

local function ensure(): Frame
	if circle then
		return circle
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Iris"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(0, 0)
	circle.BackgroundColor3 = Color3.new(0, 0, 0)
	circle.BorderSizePixel = 0
	circle.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = circle
	return circle
end

-- Wide enough to cover the corners of any aspect ratio.
local COVER = UDim2.fromScale(2.6, 2.6)

local function play(size: UDim2, duration: number, style: Enum.EasingStyle)
	local frame = ensure()
	local tween = TweenService:Create(frame, TweenInfo.new(duration, style, Enum.EasingDirection.InOut), { Size = size })
	tween:Play()
	tween.Completed:Wait()
end

-- Both yield until the transition finishes.
function Iris.close(duration: number)
	play(COVER, duration, Enum.EasingStyle.Quad)
end

function Iris.open(duration: number)
	play(UDim2.fromScale(0, 0), duration, Enum.EasingStyle.Quad)
end

return Iris
