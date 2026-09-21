--!strict
-- Draws a Nations.Flag out of Frames: stripes, then at most one emblem. No
-- images, so eighteen flags cost nothing to load.
--
-- Rotated bars (the saltire, the diamond) are NOT clipped by an ancestor's
-- ClipsDescendants, so anything rotated is sized to land inside the box on its
-- own. The saltire assumes the roughly 10:7 flag box the cards use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nations = require(ReplicatedStorage.Shared.Nations)

local FlagView = {}

-- a 10:7 box has a diagonal 1.22 times its width, at 35 degrees
local SALTIRE_LENGTH, SALTIRE_ANGLE = 1.22, 35

local function bar(parent: Instance, color: Color3, pos: UDim2, size: UDim2, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.Rotation = rotation or 0
	f.Parent = parent
	return f
end

function FlagView.draw(parent: GuiObject, flag: Nations.Flag): Frame
	local root = Instance.new("Frame")
	root.Name = "Flag"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = flag.colors[1]
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = parent

	local total = 0
	for i = 1, #flag.colors do
		total += if flag.sizes then flag.sizes[i] else 1
	end
	local at = 0
	for i, color in flag.colors do
		local share = (if flag.sizes then flag.sizes[i] else 1) / total
		local mid = at + share / 2
		if flag.dir == "v" then
			bar(root, color, UDim2.fromScale(mid, 0.5), UDim2.fromScale(share, 1))
		else
			bar(root, color, UDim2.fromScale(0.5, mid), UDim2.fromScale(1, share))
		end
		at += share
	end

	local ink = flag.emblemColor or Color3.new(1, 1, 1)
	local centre = UDim2.fromScale(0.5, 0.5)
	if flag.emblem == "cross" then
		bar(root, ink, centre, UDim2.fromScale(1, 0.2))
		bar(root, ink, centre, UDim2.fromScale(0.13, 1))
	elseif flag.emblem == "saltire" then
		bar(root, ink, centre, UDim2.fromScale(SALTIRE_LENGTH, 0.16), SALTIRE_ANGLE)
		bar(root, ink, centre, UDim2.fromScale(SALTIRE_LENGTH, 0.16), -SALTIRE_ANGLE)
	elseif flag.emblem == "disc" or flag.emblem == "diamond" then
		local d = bar(root, ink, centre, UDim2.fromScale(0.34, 0.34), if flag.emblem == "diamond" then 45 else 0)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = d
		if flag.emblem == "disc" then
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = d
		end
	elseif flag.emblem == "canton" then
		bar(root, ink, UDim2.fromScale(0.2, 0.25), UDim2.fromScale(0.4, 0.5))
	end
	return root
end

return FlagView
