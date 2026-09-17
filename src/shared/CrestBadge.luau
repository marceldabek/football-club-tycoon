--!strict
-- The Rivermere club crest as GUI frames (X236/X243/X244): a dark shield with
-- a white outline, a battlemented wall and two river waves, after the badges
-- on RivermereTurnstileEntrance.png. Frames only, so a sign gains a crest
-- without adding parts. Everything inside is in scale units, so one drawing
-- works at any size; the shield keeps its 42:52 shape.

local CrestBadge = {}

local WHITE = Color3.new(1, 1, 1)

local function bar(parent: Instance, name: string, x: number, y: number, w: number, h: number)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.fromScale(0.5 + x / 42, y / 52)
	f.Size = UDim2.fromScale(w / 42, h / 52)
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	f.Parent = parent
end

-- `size` is the shield's size (height wins; width follows the 42:52 shape).
function CrestBadge.draw(parent: Instance, fill: Color3, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local badge = Instance.new("Frame")
	badge.Name = "CrestBadge"
	badge.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	badge.Position = position
	badge.Size = size
	badge.BackgroundColor3 = fill
	badge.BorderSizePixel = 0
	badge.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 42 / 52
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = badge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.19, 0)
	corner.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 2
	stroke.Parent = badge
	bar(badge, "Wall", 0, 14, 24, 8)
	for m = -1, 1 do
		bar(badge, "Merlon", m * 9, 9, 6, 6)
	end
	for wave = 1, 2 do
		bar(badge, "Wave", 0, 28 + (wave - 1) * 7, 24, 2)
	end
	return badge
end

return CrestBadge
