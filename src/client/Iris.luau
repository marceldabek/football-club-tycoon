--!strict
-- Iris transition: the visible circle shrinks to black from the edges inward
-- (close) and grows back out (open). Built from a transparent circular frame
-- with a huge black UIStroke, so the black is *outside* the circle and no
-- image assets are needed.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Iris = {}

local hole: Frame

-- Diameter (in screen widths) at which the hole is fully off screen.
local OPEN = UDim2.fromScale(2.6, 2.6)
local CLOSED = UDim2.fromScale(0, 0)

local function ensure(): Frame
	if hole and hole.Parent then
		return hole
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Iris"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	hole = Instance.new("Frame")
	hole.Name = "Hole"
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = OPEN
	hole.BackgroundTransparency = 1
	hole.BorderSizePixel = 0
	hole.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = hole
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = hole
	-- thick enough to reach every screen corner even when the hole is a point
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 6000
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = hole
	return hole
end

local function play(size: UDim2, duration: number)
	local frame = ensure()
	local tween = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = size })
	tween:Play()
	tween.Completed:Wait()
end

-- Both yield until the transition finishes.
function Iris.close(duration: number)
	play(CLOSED, duration)
end

function Iris.open(duration: number)
	play(OPEN, duration)
end

return Iris
