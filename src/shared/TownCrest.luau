--!strict
-- The town's crest as GUI frames (X254): the Lune Bridge over the river, after
-- the arched-bridge-and-waves badge on the Rivermere reference images (the
-- riverside banners, the station banners, the estate banners). A deck on two
-- piers over two waves, drawn in scale units so one drawing works at any size.
-- Frames only, so a banner gains a crest without adding parts.
--
-- Shared/ClubCrest is the *club* crest (the crest builder); this is
-- the town's, and it is drawn flat, with no shield behind it.

local TownCrest = {}

local function bar(parent: Instance, name: string, x: number, y: number, w: number, h: number, colour: Color3)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.fromScale(0.5 + x / 42, y / 42)
	f.Size = UDim2.fromScale(w / 42, h / 42)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- `size` is the crest's box (square); `colour` is the ink, e.g. the banner's text colour.
function TownCrest.draw(parent: Instance, colour: Color3, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "TownCrest"
	holder.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = size
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = holder
	-- parapet, then the deck it sits on
	bar(holder, "Parapet", 0, 8, 34, 3, colour)
	bar(holder, "Deck", 0, 11, 34, 4, colour)
	-- two piers leaving an arch between them, and the abutments at the ends
	bar(holder, "Pier", -8, 15, 5, 11, colour)
	bar(holder, "Pier", 8, 15, 5, 11, colour)
	bar(holder, "Abutment", -15, 15, 4, 11, colour)
	bar(holder, "Abutment", 15, 15, 4, 11, colour)
	-- the river under it
	bar(holder, "Wave", 0, 29, 34, 3, colour)
	bar(holder, "Wave", 0, 35, 26, 3, colour)
	return holder
end

return TownCrest
